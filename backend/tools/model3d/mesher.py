"""Casco visual (shape from silhouette) y extracción de su superficie.

Cada silueta se extruye a lo largo del eje desde el que fue fotografiada y el
volumen del producto es la intersección de todas esas extrusiones. Con vistas
ortogonales el contorno resultante es exacto y no se inventa nada: se obtiene el
volumen más pequeño compatible con las fotos. Lo que este método no puede
recuperar son las concavidades, porque ninguna silueta las delata.

La superficie se extrae utilizando el algoritmo de Marching Cubes sobre un
campo de distancia suavizado (Gaussian Filter) para erradicar el escalonado.
"""

from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter
from skimage.measure import marching_cubes

from silhouette import View


@dataclass(frozen=True)
class Projection:
    """Cómo caen los píxeles de una foto sobre los ejes del modelo."""

    horizontal: tuple[int, int]
    vertical: tuple[int, int]


# Sistema de la derecha, como en glTF: X a la derecha, Y arriba, Z hacia el
# observador. `horizontal` avanza con la columna del píxel y `vertical` con la
# fila, que baja en la imagen.
PROJECTIONS = {
    0: Projection(horizontal=(0, 1), vertical=(1, -1)),   # Frente
    1: Projection(horizontal=(0, -1), vertical=(1, -1)),  # Atrás
    2: Projection(horizontal=(2, 1), vertical=(1, -1)),   # Izquierda
    3: Projection(horizontal=(2, -1), vertical=(1, -1)),  # Derecha
    4: Projection(horizontal=(0, 1), vertical=(2, 1)),    # Arriba
}

# Qué fotografía mira de frente a cada orientación de cara. La base no se
# fotografía, así que sus caras reciben el relleno neutro del atlas.
FACE_VIEWS: dict[tuple[int, int], int | None] = {
    (2, 1): 0, (2, -1): 1, (0, -1): 2, (0, 1): 3, (1, 1): 4, (1, -1): None,
}

MIN_CELLS = 6
SILHOUETTE_LEVEL = 96


@dataclass
class Geometry:
    positions: np.ndarray = field(default_factory=lambda: np.zeros((0, 3), np.float32))
    normals: np.ndarray = field(default_factory=lambda: np.zeros((0, 3), np.float32))
    uvs: np.ndarray = field(default_factory=lambda: np.zeros((0, 2), np.float32))
    indices: np.ndarray = field(default_factory=lambda: np.zeros(0, np.uint32))


def carve(views: list[View], extents: tuple[float, float, float],
          resolution: int) -> tuple[np.ndarray, tuple[int, int, int]]:
    """Interseca las siluetas extruidas sobre una rejilla de vóxeles."""
    dims = tuple(max(MIN_CELLS, round(resolution * value)) for value in extents)
    occupancy = np.ones(dims, dtype=bool)
    for view in views:
        occupancy &= _extrusion(view, dims)
    if not occupancy.any():
        # Siluetas incompatibles entre sí (encuadres muy distintos): es
        # preferible una caja con las proporciones medidas que nada.
        occupancy = np.ones(dims, dtype=bool)
    return occupancy, dims


def surface(occupancy: np.ndarray, dims: tuple[int, int, int],
            extents: tuple[float, float, float], atlas,
            smoothing: int = 2) -> Geometry:
    """Convierte los vóxeles ocupados en una malla continua y texturizada usando Marching Cubes."""
    # Convertir ocupación booleana a campo continuo [0, 1] y suavizar
    # El radio de desenfoque gaussiano elimina la naturaleza de "bloques"
    sigma = max(0.5, smoothing * 0.4)
    field_data = gaussian_filter(occupancy.astype(np.float32), sigma=sigma)

    try:
        # Extraer superficie isosuperficie suave
        verts, faces, normals, values = marching_cubes(field_data, level=0.5)
    except ValueError:
        # Si el campo es uniforme (ej. falla total), devolver malla vacía
        return Geometry()

    # Mapear de [0, dims-1] a [-half_extents, +half_extents]
    # Marching cubes da coordenadas entre 0 y dims-1
    half = [extents[0]*0.5, extents[1]*0.5, extents[2]*0.5]
    scaled_verts = np.zeros_like(verts)
    for i in range(3):
        # Escalar mapeando 0 a -half y dims a +half
        scaled_verts[:, i] = -half[i] + (verts[:, i] / dims[i]) * extents[i]

    # Re-triangular para permitir costuras UV netas
    final_positions = []
    final_normals = []
    final_uvs = []
    final_indices = []

    vertex_count = 0

    for face in faces:
        v0, v1, v2 = face
        p0 = scaled_verts[v0]
        p1 = scaled_verts[v1]
        p2 = scaled_verts[v2]
        
        n0 = normals[v0]
        n1 = normals[v1]
        n2 = normals[v2]
        tri_normal = n0 + n1 + n2
        norm = np.linalg.norm(tri_normal)
        if norm > 0:
            tri_normal /= norm
        
        axis = int(np.argmax(np.abs(tri_normal)))
        sign = 1 if tri_normal[axis] >= 0 else -1
        
        slot = atlas.slot_for(FACE_VIEWS.get((axis, sign)))
        
        uv0 = slot.coordinates(p0, half)
        uv1 = slot.coordinates(p1, half)
        uv2 = slot.coordinates(p2, half)
        
        final_positions.extend([p0, p1, p2])
        final_normals.extend([n0, n1, n2])
        final_uvs.extend([uv0, uv1, uv2])
        
        final_indices.extend([vertex_count, vertex_count+1, vertex_count+2])
        vertex_count += 3

    return Geometry(
        positions=np.asarray(final_positions, dtype=np.float32),
        normals=np.asarray(final_normals, dtype=np.float32),
        uvs=np.asarray(final_uvs, dtype=np.float32),
        indices=np.asarray(final_indices, dtype=np.uint32),
    )


def _extrusion(view: View, dims: tuple[int, int, int]) -> np.ndarray:
    projection = PROJECTIONS[view.index]
    horizontal_axis, horizontal_sign = projection.horizontal
    vertical_axis, vertical_sign = projection.vertical
    silhouette = _resample(view.mask, dims[horizontal_axis], dims[vertical_axis])
    if horizontal_sign < 0:
        silhouette = silhouette[::-1, :]
    if vertical_sign < 0:
        silhouette = silhouette[:, ::-1]

    order = [horizontal_axis, vertical_axis]
    order.append(next(axis for axis in range(3) if axis not in order))
    return np.transpose(silhouette[:, :, None], np.argsort(order))


def _resample(mask: np.ndarray, columns: int, rows: int) -> np.ndarray:
    """Reescala la máscara y la reindexa como [horizontal, vertical]."""
    source = Image.fromarray(mask.T.astype(np.uint8) * 255, mode='L')
    return np.asarray(source.resize((rows, columns), Image.BILINEAR)) >= SILHOUETTE_LEVEL
