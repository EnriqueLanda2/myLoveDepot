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
    """Resuelve las proporciones X:Y:Z a partir de las razones de aspecto y perfil geométrico."""
    front_views = [v for v in views if v.index in (0, 1)]
    primary = front_views[0] if front_views else views[0]
    wide_axis, tall_axis = MEASURED_AXES.get(primary.index, (0, 1))

    extents = np.ones(3, dtype=np.float64)
    extents[wide_axis] = primary.aspect
    extents[tall_axis] = 1.0
    hidden_axis = next(axis for axis in range(3) if axis not in (wide_axis, tall_axis))

    # Si el usuario subió vista lateral (2: Izquierda o 3: Derecha), medir profundidad real:
    side_views = [v for v in views if v.index in (2, 3)]
    if side_views:
        # La vista lateral mide (Z, Y): su aspecto es directamente el espesor relativo Z / Y
        depth_factor = float(np.clip(side_views[0].aspect, 0.12, 1.2))
    elif primary.is_round:
        depth_factor = 1.0
    elif primary.is_cube:
        depth_factor = 1.0
    elif primary.p >= 4.2: # slab / cartera / teléfono
        if primary.aspect < 0.70:
            depth_factor = 0.20 # Teléfono
        else:
            depth_factor = float(np.clip(0.28, 0.18, 0.40)) # Cartera / libreta / caja
    else:
        depth_factor = float(np.clip(0.22 + 0.78 * ((primary.aspect - 0.45) / 0.35), 0.22, 1.0))

    extents[hidden_axis] = min(extents[wide_axis], extents[tall_axis]) * depth_factor
    return tuple(float(value) for value in extents / extents.max())


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

    # 5. Preservación topológica de orificios reales (asas de tazas, anillas) vs cavidades:
    # Solo se conservan orificios en altura media (20% a 80%), con color de fondo (d2 < 12)
    # y tamaño moderado (0.8% a 16%), como el asa de una taza.
    fg_filled = binary_fill_holes(fg)
    holes = fg_filled & (~fg)
    hole_labels, num_holes = label(holes)
    hole_counts = np.bincount(hole_labels.ravel())
    total_area = max(1, fg_filled.sum())

    keep_open = np.zeros_like(holes)
    fg_x_coords = np.where(fg_filled)[1]
    fg_x_min, fg_x_max = (float(fg_x_coords.min()), float(fg_x_coords.max())) if len(fg_x_coords) else (0.0, float(width))
    fg_w = max(1.0, fg_x_max - fg_x_min)

    for h_id in range(1, num_holes + 1):
        ratio = hole_counts[h_id] / float(total_area)
        coords = np.where(hole_labels == h_id)
        y_mean = float(np.mean(coords[0])) / float(height)
        x_mean = float(np.mean(coords[1]))
        # Un asa de taza o anilla está situada en los flancos laterales del objeto (al menos 30% lejos del centro)
        x_rel = (x_mean - fg_x_min) / fg_w
        is_outer_flank = (x_rel < 0.28 or x_rel > 0.72)
        hole_d2 = d2[coords]
        if is_outer_flank and 0.008 <= ratio <= 0.16 and np.median(hole_d2) < 12.0 and (0.18 <= y_mean <= 0.82):
            keep_open |= (hole_labels == h_id)

    mask = fg_filled & (~keep_open)

    # 6. Limpieza de bordes: sellado de cavidad superior (boca de taza) y supresión de reflejo en base
    valid = np.where(mask.any(axis=1))[0]
    if len(valid) > 20:
        top_row, bottom_row = int(valid.min()), int(valid.max())
        H_obj = bottom_row - top_row

        # Rellenar cavidad de la boca superior si es un cuerpo continuo debajo
        check_offset = min(25, max(8, int(0.12 * H_obj)))
        for r in range(top_row, int(top_row + 0.20 * H_obj)):
            cols = np.where(mask[r])[0]
            if len(cols) > 1:
                diffs = np.diff(cols)
                gap_idxs = np.where(diffs > 1)[0]
                for g_i in gap_idxs:
                    x1 = cols[g_i] + 1
                    x2 = cols[g_i + 1] - 1
                    gap_w = x2 - x1 + 1
                    mid_gap = (x1 + x2) // 2
                    below_r = min(height - 1, r + check_offset)
                    if gap_w < width * 0.40 and mask[below_r, mid_gap]:
                        if mask[below_r, x1:x2 + 1].all():
                            mask[r, x1:x2 + 1] = True

        # Eliminar patas y puntas de reflejo especular de mesa debajo de la base sólida
        widths = [mask[r].sum() for r in range(top_row, bottom_row + 1)]
        base_ref = float(np.median(widths[-20:-10])) if len(widths) >= 20 else float(widths[-1])
        for r in range(bottom_row, max(top_row, bottom_row - 20), -1):
            cols = np.where(mask[r])[0]
            if len(cols) == 0:
                continue
            span = cols[-1] - cols[0] + 1
            density = len(cols) / float(span)
            if mask[r].sum() < 0.35 * base_ref or density < 0.65:
                mask[r, :] = False
            else:
                break

    mask = binary_closing(mask, structure=np.ones((5, 5)))
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
