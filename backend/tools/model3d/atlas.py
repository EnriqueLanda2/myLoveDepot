"""Empaqueta las vistas recortadas en una sola textura y resuelve sus UV.

Cada cara del modelo se texturiza con la fotografía que la mira de frente,
proyectada ortogonalmente. Si falta alguna vista (por ejemplo, si el usuario solo
subió la foto frontal), la vista faltante se sintetiza inteligentemente usando la
vista frontal o la opuesta volteada, y los bordes neutros se rellenan con el color
dominante del producto para evitar caras grises.
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np
from PIL import Image, ImageEnhance

from mesher import PROJECTIONS, Projection
from silhouette import View

TILE = 1024
COLUMNS = 3
ROWS = 2
NEUTRAL_COLUMN, NEUTRAL_ROW = 2, 1
FALLBACK_COLOUR = (225, 215, 210)
PADDING = 4  # Px de padding para evitar costuras de textura


def _enhance_texture(image: Image.Image) -> Image.Image:
    """Mejora adaptativa de brillo, contraste, viveza y nitidez para texturas 3D."""
    gray = image.resize((32, 32)).convert('L')
    avg_luma = float(np.mean(np.asarray(gray)))
    enhanced = image
    if avg_luma < 165:
        boost = min(1.22, max(1.04, 1.0 + (160.0 - avg_luma) / 450.0))
        enhanced = ImageEnhance.Brightness(enhanced).enhance(boost)
    enhanced = ImageEnhance.Contrast(enhanced).enhance(1.08)
    enhanced = ImageEnhance.Color(enhanced).enhance(1.10)
    enhanced = ImageEnhance.Sharpness(enhanced).enhance(1.15)
    return enhanced


@dataclass(frozen=True)
class _PhotoSlot:
    """Celda del atlas ocupada por una fotografía real o sintetizada."""

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
    """Celda de color liso con el color dominante del producto para caras sin foto."""

    def coordinates(self, _point: list[float], _half: list[float]) -> tuple[float, float]:
        return (
            (NEUTRAL_COLUMN + 0.5) / COLUMNS,
            (NEUTRAL_ROW + 0.5) / ROWS,
        )


class Atlas:
    def __init__(self, views: list[View]) -> None:
        dominant_color = _dominant_colour(views)
        self.image = Image.new(
            'RGB', (COLUMNS * TILE, ROWS * TILE), dominant_color,
        )
        self._neutral = _NeutralSlot()
        self._slots: dict[int, _PhotoSlot] = {}

        view_by_index: dict[int, View] = {view.index: view for view in views}
        primary_view = views[0] if views else None

        # Para cada una de las 5 vistas posibles (0:Frente, 1:Atrás, 2:Izq, 3:Der, 4:Arriba)
        for view_idx in range(5):
            column, row = view_idx % COLUMNS, view_idx // COLUMNS
            crop_to_use: Image.Image | None = None

            if view_idx in view_by_index:
                crop_to_use = view_by_index[view_idx].crop
            elif view_idx == 1 and 0 in view_by_index:
                # Atrás: si falta, usar la frontal volteada horizontalmente
                crop_to_use = view_by_index[0].crop.transpose(Image.FLIP_LEFT_RIGHT)
            elif view_idx == 2 and 3 in view_by_index:
                # Izquierda: si falta, usar derecha
                crop_to_use = view_by_index[3].crop.transpose(Image.FLIP_LEFT_RIGHT)
            elif view_idx == 3 and 2 in view_by_index:
                # Derecha: si falta, usar izquierda
                crop_to_use = view_by_index[2].crop.transpose(Image.FLIP_LEFT_RIGHT)
            elif primary_view is not None:
                # Cualquier otra vista faltante: usar la vista principal
                crop_to_use = primary_view.crop

            if crop_to_use is not None:
                enhanced_crop = _enhance_texture(crop_to_use)
                resized = enhanced_crop.resize((TILE, TILE), Image.LANCZOS)
                # Aplicar padding: replicar bordes para evitar costuras de textura
                padded = _apply_tile_padding(resized)
                self.image.paste(padded, (column * TILE, row * TILE))
                self._slots[view_idx] = _PhotoSlot(
                    column=column, row=row, projection=PROJECTIONS[view_idx],
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
    # Inset UVs ligeramente para evitar muestrear pixeles del tile vecino
    inset = PADDING + 0.5
    return (cell * TILE + inset + fraction * (TILE - 2 * inset)) / (cells * TILE)


def _apply_tile_padding(tile: Image.Image) -> Image.Image:
    """Extiende los píxeles del borde hacia afuera para evitar costuras UV.

    Replica la fila/columna más externa en cada dirección por PADDING píxeles.
    Así, cuando el muestreador bilineal de la GPU toma texels más allá del borde,
    obtiene el color del borde del producto en vez del color del tile vecino.
    """
    arr = np.asarray(tile)
    h, w = arr.shape[:2]
    # Limitar el padding al tamaño del tile
    p = min(PADDING, h // 4, w // 4)
    if p <= 0:
        return tile
    result = arr.copy()
    # Replicar bordes hacia adentro (sobrescribir las franjas periféricas)
    # Borde superior: copiar fila p hacia las filas 0..p-1
    for i in range(p):
        result[i, :] = arr[p, :]
    # Borde inferior: copiar fila h-p-1 hacia las filas h-p..h-1
    for i in range(p):
        result[h - 1 - i, :] = arr[h - 1 - p, :]
    # Borde izquierdo
    for i in range(p):
        result[:, i] = result[:, p]
    # Borde derecho
    for i in range(p):
        result[:, w - 1 - i] = result[:, w - 1 - p]
    return Image.fromarray(result)


def _dominant_colour(views: list[View]) -> tuple[int, int, int]:
    """Calcula el color dominante del producto buscando la mediana de los píxeles internos."""
    samples = []
    for view in views:
        pixels = np.asarray(
            view.crop.resize((64, 64), Image.BILINEAR), dtype=np.float32,
        )
        shape = Image.fromarray(view.mask.astype(np.uint8) * 255, mode='L')
        # Reducir la máscara un poco para evitar sombras o bordes del fondo
        inside = np.asarray(shape.resize((64, 64), Image.BILINEAR)) > 200
        if inside.any():
            product_pixels = pixels[inside]
            samples.append(product_pixels)

    if not samples:
        return FALLBACK_COLOUR

    all_pixels = np.vstack(samples)
    # Mediana para evitar outliers oscuros o reflejos brillantes
    median_color = np.median(all_pixels, axis=0)
    return tuple(int(round(channel)) for channel in median_color)
