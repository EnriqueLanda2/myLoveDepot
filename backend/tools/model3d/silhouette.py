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
from PIL import Image, ImageOps
from scipy.ndimage import (
    binary_closing, binary_erosion, binary_fill_holes, binary_opening,
    distance_transform_edt, gaussian_filter, label
)
from skimage import exposure
from skimage.color import rgb2gray
from skimage.filters import sobel

# La silueta se calcula sobre una copia reducida: el tallado trabaja con rejillas
# de ~70 vóxeles por lado, así que más resolución solo costaría tiempo.
WORK_SIZE = 384
BORDER_FRACTION = 0.05
MIN_DISTANCE = 12.0
MIN_COVERAGE = 0.015
ALPHA_THRESHOLD = 16

# Qué par de ejes del modelo mide cada vista: (eje del ancho, eje del alto).
# 0 Frente, 1 Atrás, 2 Izquierda, 3 Derecha, 4 Arriba. X=0, Y=1, Z=2.
MEASURED_AXES = {0: (0, 1), 1: (0, 1), 2: (2, 1), 3: (2, 1), 4: (0, 2)}


@dataclass(frozen=True)
class View:
    """Una fotografía ya recortada al contorno del producto."""

    index: int
    mask: np.ndarray
    crop: Image.Image
    p: float = 4.0
    is_round: bool = False
    is_cube: bool = False

    @property
    def aspect(self) -> float:
        return self.mask.shape[1] / self.mask.shape[0]


def _profile_shape(mask: np.ndarray) -> tuple[float, bool, bool]:
    """Analiza la silueta para clasificar si es cubo, lámina/cartera/caja o redondo."""
    y_idx, x_idx = np.where(mask)
    if len(y_idx) == 0:
        return 4.0, False, False
    h_min, h_max = int(y_idx.min()), int(y_idx.max())
    w_min, w_max = int(x_idx.min()), int(x_idx.max())
    h = max(1, h_max - h_min + 1)
    w = max(1, w_max - w_min + 1)
    aspect = w / float(h)
    solidity = mask.sum() / float(w * h)

    # Analiza la variación de ancho en el 60% central
    mid_s = int(h_min + 0.2 * h)
    mid_e = int(h_min + 0.8 * h)
    mid_w = []
    for y in range(mid_s, mid_e):
        row = mask[y, :]
        if row.any():
            xs = np.where(row)[0]
            mid_w.append(xs.max() - xs.min() + 1)
    mid_w = np.array(mid_w, dtype=float) if mid_w else np.array([w], dtype=float)
    mid_std = float(np.std(mid_w) / (np.mean(mid_w) + 1e-5))

    # Criterios geométricos:
    # 1. Cubo / caja cuadrada: relación de aspecto cercana a 1:1, laterales rectos y solidez alta
    is_cube = (0.84 <= aspect <= 1.18) and (mid_std < 0.06) and (solidity >= 0.80)
    # 2. Lámina / caja / cartera / libro (prismas rectangulares): laterales rectos y alta solidez
    is_flat_slab = not is_cube and (solidity >= 0.74) and (mid_std < 0.08)
    # 3. Redondo / cilíndrico (vasos, tazas, botellas, esferas): siluetas con curvatura o variaciones
    is_round = not is_flat_slab and not is_cube

    if is_flat_slab:
        return 4.5, False, False
    elif is_cube:
        return 4.0, False, True
    elif is_round:
        return 2.0, True, False
    else:
        return 3.5, False, False


def load_view(index: int, path: Path) -> View | None:
    """Devuelve una vista recortada, usando primero el alfa generado por rembg.

    La segmentación estadística antigua queda como compatibilidad para entradas
    RGB y para ``--no-rembg``. Una imagen RGBA válida nunca vuelve a pasar por
    las reglas históricas que rellenaban bocas o eliminaban bases finas.
    """
    with Image.open(path) as opened:
        oriented = ImageOps.exif_transpose(opened)
        rgba = oriented.convert('RGBA')
        image = oriented.convert('RGB')
    reduced = image.copy()
    reduced.thumbnail((WORK_SIZE, WORK_SIZE), Image.LANCZOS)

    alpha = rgba.getchannel('A')
    alpha.thumbnail(reduced.size, Image.LANCZOS)
    alpha_values = np.asarray(alpha, dtype=np.uint8)
    has_foreground_alpha = (
        alpha_values.min() < 250
        and MIN_COVERAGE <= (alpha_values >= ALPHA_THRESHOLD).mean() <= 0.985
    )
    if has_foreground_alpha:
        mask = _clean_alpha_mask(alpha_values)
    else:
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
    cropped_mask = mask[top:bottom, left:right]

    # Sangrado de bordes (Edge Bleeding) con EDT:
    # Reemplaza cualquier píxel del fondo (fuera de la máscara) por el color del borde del producto.
    # Así, si el producto fue fotografiado sobre una manta azul, mantel o madera,
    # el color del fondo NUNCA aparecerá en los bordes del modelo 3D.
    mask_full = np.asarray(Image.fromarray((cropped_mask * 255).astype(np.uint8)).resize(crop.size, Image.BILINEAR)) > 128
    eroded_mask = binary_erosion(mask_full, structure=np.ones((5, 5)))
    if eroded_mask.any():
        crop_arr = np.asarray(crop)
        _, nearest_idx = distance_transform_edt(~eroded_mask, return_indices=True)
        clean_arr = crop_arr[nearest_idx[0], nearest_idx[1]]
        crop = Image.fromarray(clean_arr)

    p, is_round, is_cube = _profile_shape(cropped_mask)
    return View(
        index=index,
        mask=cropped_mask,
        crop=crop,
        p=p,
        is_round=is_round,
        is_cube=is_cube,
    )


def estimate_extents(views: list[View]) -> tuple[float, float, float]:
    """Resuelve X:Y:Z con todas las razones de aspecto independientes.

    En log-espacio, cada foto aporta la ecuación
    ``log(extent_width) - log(extent_height) = log(aspect)``. Con dos
    orientaciones distintas el sistema determina las tres dimensiones. Cuando
    solo existe una orientación, el eje invisible sigue siendo un prior y se
    marca como aproximado en el reporte del orquestador.
    """
    front_views = [v for v in views if v.index in (0, 1)]
    primary = front_views[0] if front_views else views[0]
    independent_pairs = {MEASURED_AXES.get(view.index, (0, 1)) for view in views}

    if len(independent_pairs) >= 2:
        equations: list[list[float]] = []
        targets: list[float] = []
        for view in views:
            wide_axis, tall_axis = MEASURED_AXES.get(view.index, (0, 1))
            row = [0.0, 0.0, 0.0]
            row[wide_axis] = 1.0
            row[tall_axis] = -1.0
            equations.append(row)
            targets.append(float(np.log(np.clip(view.aspect, 0.05, 20.0))))
        # Fija la escala global sin sesgar ninguna dimensión.
        equations.append([1.0, 1.0, 1.0])
        targets.append(0.0)
        solution, *_ = np.linalg.lstsq(
            np.asarray(equations, dtype=np.float64),
            np.asarray(targets, dtype=np.float64),
            rcond=None,
        )
        extents = np.exp(solution)
    else:
        wide_axis, tall_axis = MEASURED_AXES.get(primary.index, (0, 1))
        extents = np.ones(3, dtype=np.float64)
        extents[wide_axis] = primary.aspect
        extents[tall_axis] = 1.0
        hidden_axis = next(
            axis for axis in range(3) if axis not in (wide_axis, tall_axis)
        )
        if primary.is_round or primary.is_cube:
            depth_factor = 1.0
        elif primary.p >= 4.2:
            depth_factor = 0.20 if primary.aspect < 0.70 else 0.28
        else:
            depth_factor = float(np.clip(
                0.22 + 0.78 * ((primary.aspect - 0.45) / 0.35),
                0.22,
                1.0,
            ))
        extents[hidden_axis] = (
            min(extents[wide_axis], extents[tall_axis]) * depth_factor
        )
    return tuple(float(value) for value in extents / extents.max())


def _clean_alpha_mask(alpha: np.ndarray) -> np.ndarray | None:
    """Limpia ruido diminuto sin inventar ni rellenar huecos del objeto."""
    mask = alpha >= ALPHA_THRESHOLD
    labels, num = label(mask)
    if num:
        counts = np.bincount(labels.ravel())
        largest = int(counts[1:].max())
        minimum = max(16, round(largest * 0.01))
        keep = [component for component in range(1, num + 1)
                if counts[component] >= minimum]
        mask = np.isin(labels, keep)
    mask = binary_closing(mask, structure=np.ones((3, 3)))
    return mask if mask.mean() >= MIN_COVERAGE else None


def _segment(pixels: np.ndarray) -> np.ndarray | None:
    height, width, _ = pixels.shape
    band = max(4, round(min(height, width) * BORDER_FRACTION))
    # Muestrear el fondo de los bordes superior, izquierdo y derecho (evitando el borde inferior
    # donde suelen acumularse reflejos especulares de mesas lacadas o de cristal)
    border = np.concatenate([
        pixels[:band, :].reshape(-1, 3),
        pixels[:, :band].reshape(-1, 3),
        pixels[:, -band:].reshape(-1, 3),
    ])

    # 1. Modelo estadístico de fondo con matriz de covarianza (distancia de Mahalanobis).
    # Elimina reflejos tenues de mesa (d2 ~ 5) y soporta baja iluminación.
    bg_mean = np.median(border, axis=0)
    bg_cov = np.cov(border.T) + np.eye(3) * 5.0
    inv_cov = np.linalg.inv(bg_cov)
    diff = pixels.astype(np.float64) - bg_mean
    d2 = np.einsum('ijk,kl,ijl->ij', diff, inv_cov, diff)

    # 2. Detección de bordes con CLAHE para fotos oscuras o grano de sensor
    gray = rgb2gray(pixels / 255.0)
    smooth_gray = gaussian_filter(gray, sigma=1.0)
    enhanced_gray = exposure.equalize_adapthist(smooth_gray, clip_limit=0.03)
    edges = sobel(enhanced_gray)
    edge_barrier = edges > np.percentile(edges, 85)

    # 3. Identificación directa de primer plano:
    # El soporte de bordes SOLO actúa donde haya una discrepancia de color perceptible (d2 >= 6.0)
    # Evita absolutamente que texturas de fondo (telas, mantas, vetas de madera) se conviertan en objeto.
    edge_support = edge_barrier & (d2 >= 6.0)
    fg = (d2 >= 16.0) | edge_support
    fg = binary_opening(fg, structure=np.ones((3, 3)))
    fg = binary_closing(fg, structure=np.ones((5, 5)))

    # 4. Filtrado multi-componente inteligente:
    # Conserva tanto la pieza principal como accesorios o wands/aplicadores desconectados (>= 12% del mayor)
    labels, num = label(fg)
    counts = np.bincount(labels.ravel())
    if num > 0:
        max_c = counts[1:].max()
        keep = [i for i in range(1, num + 1) if counts[i] >= 0.12 * max_c]
        fg = np.isin(labels, keep)

    # 5. Limpieza generalista. No se rellenan cavidades ni se recortan bases:
    # esas reglas históricas favorecían tazas y destruían patas, ranuras y asas
    # de otras categorías. Los huecos grandes compatibles con el fondo quedan
    # abiertos y solo se cierran discontinuidades de pocos píxeles.
    mask = binary_closing(fg, structure=np.ones((5, 5)))
    mask = binary_opening(mask, structure=np.ones((3, 3)))

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
