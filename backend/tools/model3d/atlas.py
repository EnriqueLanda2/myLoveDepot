"""Empaqueta las vistas recortadas en una sola textura y resuelve sus UV.

Cada cara del modelo se texturiza con la fotografía que la mira de frente,
proyectada ortogonalmente. Como la foto viene recortada al contorno y la rejilla
de vóxeles abarca ese mismo contorno, la proyección es una regla de tres: no hace
falta calibrar cámara ni estimar pose.
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np
from PIL import Image

from mesher import PROJECTIONS, Projection
from silhouette import View

TILE = 512
COLUMNS = 3
ROWS = 2
NEUTRAL_COLUMN, NEUTRAL_ROW = 2, 1
FALLBACK_COLOUR = (168, 162, 154)


@dataclass(frozen=True)
class _PhotoSlot:
    """Celda del atlas ocupada por una fotografía real."""

    column: int
    row: int
    projection: Projection

    def coordinates(self, point: list[float], half: list[float]) -> tuple[float, float]:
        return (
            _atlas_axis(self.column, _fraction(point, half, self.projection.horizontal),
                        COLUMNS),
            _atlas_axis(self.row, _fraction(point, half, self.projection.vertical),
                        ROWS),
        )


@dataclass(frozen=True)
class _NeutralSlot:
    """Celda de color liso para las caras que ninguna foto llegó a ver."""

    def coordinates(self, _point: list[float], _half: list[float]) -> tuple[float, float]:
        return (
            (NEUTRAL_COLUMN + 0.5) / COLUMNS,
            (NEUTRAL_ROW + 0.5) / ROWS,
        )


class Atlas:
    def __init__(self, views: list[View]) -> None:
        self.image = Image.new(
            'RGB', (COLUMNS * TILE, ROWS * TILE), _average_colour(views),
        )
        self._neutral = _NeutralSlot()
        self._slots: dict[int, _PhotoSlot] = {}
        for view in views:
            column, row = view.index % COLUMNS, view.index // COLUMNS
            self.image.paste(
                view.crop.resize((TILE, TILE), Image.LANCZOS),
                (column * TILE, row * TILE),
            )
            self._slots[view.index] = _PhotoSlot(
                column=column, row=row, projection=PROJECTIONS[view.index],
            )

    def slot_for(self, view_index: int | None):
        if view_index is None:
            return self._neutral
        return self._slots.get(view_index, self._neutral)


def _fraction(point: list[float], half: list[float], spec: tuple[int, int]) -> float:
    axis, sign = spec
    value = (point[axis] + half[axis]) / (2 * half[axis])
    return 1.0 - value if sign < 0 else value


def _atlas_axis(cell: int, fraction: float, cells: int) -> float:
    # Medio téxel de margen a cada lado para que el filtrado bilineal nunca
    # muestree la celda vecina.
    return (cell * TILE + 0.5 + fraction * (TILE - 1)) / (cells * TILE)


def _average_colour(views: list[View]) -> tuple[int, int, int]:
    samples = []
    for view in views:
        pixels = np.asarray(
            view.crop.resize((64, 64), Image.BILINEAR), dtype=np.float32,
        )
        shape = Image.fromarray(view.mask.astype(np.uint8) * 255, mode='L')
        inside = np.asarray(shape.resize((64, 64), Image.BILINEAR)) > 127
        if inside.any():
            samples.append(pixels[inside].mean(axis=0))
    if not samples:
        return FALLBACK_COLOUR
    return tuple(int(round(channel)) for channel in np.mean(samples, axis=0))
