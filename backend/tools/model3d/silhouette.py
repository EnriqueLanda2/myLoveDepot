"""Separa el producto del fondo en cada fotografía y deduce sus proporciones.

Una foto ortogonal no contiene profundidad, pero sí contiene una silueta: el
contorno exacto del producto visto desde ese lado. Esa silueta es la única
información geométrica real que aporta la imagen, y es la que alimenta el
tallado del casco visual en `mesher`.
"""

from __future__ import annotations

from collections import deque
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image

# La silueta se calcula sobre una copia reducida: el tallado trabaja con rejillas
# de ~70 vóxeles por lado, así que más resolución solo costaría tiempo.
WORK_SIZE = 256
BORDER_FRACTION = 0.05
MIN_DISTANCE = 12.0
MIN_COVERAGE = 0.015

# Qué par de ejes del modelo mide cada vista: (eje del ancho, eje del alto).
# 0 Frente, 1 Atrás, 2 Izquierda, 3 Derecha, 4 Arriba. X=0, Y=1, Z=2.
MEASURED_AXES = {0: (0, 1), 1: (0, 1), 2: (2, 1), 3: (2, 1), 4: (0, 2)}


@dataclass(frozen=True)
class View:
    """Una fotografía ya recortada al contorno del producto."""

    index: int
    mask: np.ndarray
    crop: Image.Image

    @property
    def aspect(self) -> float:
        return self.mask.shape[1] / self.mask.shape[0]


def load_view(index: int, path: Path) -> View | None:
    """Devuelve la vista recortada al producto, o None si no se pudo separar."""
    with Image.open(path) as opened:
        image = opened.convert('RGB')
    reduced = image.copy()
    reduced.thumbnail((WORK_SIZE, WORK_SIZE), Image.LANCZOS)
    mask = _segment(np.asarray(reduced, dtype=np.float32))
    if mask is None:
        return None

    rows = np.flatnonzero(mask.any(axis=1))
    columns = np.flatnonzero(mask.any(axis=0))
    top, bottom = int(rows[0]), int(rows[-1]) + 1
    left, right = int(columns[0]), int(columns[-1]) + 1
    crop = image.crop((
        round(left / mask.shape[1] * image.width),
        round(top / mask.shape[0] * image.height),
        round(right / mask.shape[1] * image.width),
        round(bottom / mask.shape[0] * image.height),
    ))
    return View(index=index, mask=mask[top:bottom, left:right], crop=crop)


def estimate_extents(views: list[View]) -> tuple[float, float, float]:
    """Resuelve las proporciones X:Y:Z a partir de las razones de aspecto.

    Cada vista aporta una ecuación del tipo `log(ancho) - log(alto) = log(aspecto)`
    sobre dos de los tres ejes. Con dos o más vistas el sistema queda determinado;
    con menos, la regularización lo empuja hacia un cubo.
    """
    if len(views) == 1:
        # Una sola silueta no aporta profundidad. En vez de dejar que la
        # regularización fabrique un bloque casi cúbico, se usa una profundidad
        # conservadora proporcional al lado menor. Es una aproximación honesta
        # y estable para el avatar giratorio; vistas extra sustituyen esta regla.
        view = views[0]
        wide_axis, tall_axis = MEASURED_AXES[view.index]
        extents = np.ones(3, dtype=np.float64)
        extents[wide_axis] = view.aspect
        extents[tall_axis] = 1.0
        hidden_axis = next(axis for axis in range(3)
                           if axis not in (wide_axis, tall_axis))
        extents[hidden_axis] = min(extents[wide_axis], extents[tall_axis]) * 0.38
        return tuple(float(value) for value in extents / extents.max())

    equations: list[list[float]] = []
    targets: list[float] = []
    for view in views:
        wide_axis, tall_axis = MEASURED_AXES[view.index]
        equation = [0.0, 0.0, 0.0]
        equation[wide_axis] = 1.0
        equation[tall_axis] = -1.0
        equations.append(equation)
        targets.append(float(np.log(view.aspect)))
    for axis in range(3):
        equation = [0.0, 0.0, 0.0]
        equation[axis] = 0.05
        equations.append(equation)
        targets.append(0.0)

    solution, *_ = np.linalg.lstsq(
        np.array(equations), np.array(targets), rcond=None,
    )
    extents = np.exp(solution)
    return tuple(float(value) for value in extents / extents.max())


def _segment(pixels: np.ndarray) -> np.ndarray | None:
    height, width, _ = pixels.shape
    band = max(2, round(min(height, width) * BORDER_FRACTION))
    border = np.concatenate([
        pixels[:band].reshape(-1, 3), pixels[-band:].reshape(-1, 3),
        pixels[:, :band].reshape(-1, 3), pixels[:, -band:].reshape(-1, 3),
    ])
    background = np.median(border, axis=0)
    distance = np.linalg.norm(pixels - background, axis=2)

    # Todo lo que se parece al color del borde y además conecta con el borde es
    # fondo. Lo que queda encerrado pertenece al producto, aunque su color se
    # parezca al fondo, así que los huecos interiores se rellenan solos.
    free = distance < max(_otsu(distance), MIN_DISTANCE)
    mask = _largest_blob(~_reachable_from_border(free))
    return mask if mask.mean() >= MIN_COVERAGE else None


def _otsu(values: np.ndarray) -> float:
    histogram, edges = np.histogram(values, bins=256)
    total = int(histogram.sum())
    if total == 0:
        return 0.0
    centers = (edges[:-1] + edges[1:]) / 2
    below = np.cumsum(histogram)
    above = total - below
    weighted = np.cumsum(histogram * centers)
    usable = (below > 0) & (above > 0)
    if not usable.any():
        return float(centers[len(centers) // 2])
    separation = np.zeros_like(centers)
    separation[usable] = (
        below[usable] * above[usable]
        * (weighted[usable] / below[usable]
           - (weighted[-1] - weighted[usable]) / above[usable]) ** 2
    )
    return float(centers[int(np.argmax(separation))])


def _reachable_from_border(free: np.ndarray) -> np.ndarray:
    height, width = free.shape
    open_pixels = free.ravel().tolist()
    seen = [False] * len(open_pixels)
    pending: deque[int] = deque()
    border = (
        [column for column in range(width)]
        + [(height - 1) * width + column for column in range(width)]
        + [row * width for row in range(height)]
        + [row * width + width - 1 for row in range(height)]
    )
    for index in border:
        if open_pixels[index] and not seen[index]:
            seen[index] = True
            pending.append(index)
    _spread(pending, open_pixels, seen, width)
    return np.array(seen, dtype=bool).reshape(height, width)


def _largest_blob(mask: np.ndarray) -> np.ndarray:
    height, width = mask.shape
    solid = mask.ravel().tolist()
    labels = [0] * len(solid)
    current = 0
    largest_label, largest_size = 0, 0
    for start in range(len(solid)):
        if not solid[start] or labels[start]:
            continue
        current += 1
        labels[start] = current
        size = _spread_labelled(deque([start]), solid, labels, width, current)
        if size > largest_size:
            largest_label, largest_size = current, size
    if largest_label == 0:
        return mask
    return np.array(labels, dtype=np.int64).reshape(height, width) == largest_label


def _spread(pending: deque[int], open_pixels: list[bool],
            seen: list[bool], width: int) -> None:
    total = len(open_pixels)
    while pending:
        index = pending.popleft()
        column = index % width
        for neighbour in (
            index - width, index + width,
            index - 1 if column else -1,
            index + 1 if column + 1 < width else -1,
        ):
            if 0 <= neighbour < total and open_pixels[neighbour] and not seen[neighbour]:
                seen[neighbour] = True
                pending.append(neighbour)


def _spread_labelled(pending: deque[int], solid: list[bool], labels: list[int],
                     width: int, label: int) -> int:
    total = len(solid)
    size = 0
    while pending:
        index = pending.popleft()
        size += 1
        column = index % width
        for neighbour in (
            index - width, index + width,
            index - 1 if column else -1,
            index + 1 if column + 1 < width else -1,
        ):
            if 0 <= neighbour < total and solid[neighbour] and not labels[neighbour]:
                labels[neighbour] = label
                pending.append(neighbour)
    return size
