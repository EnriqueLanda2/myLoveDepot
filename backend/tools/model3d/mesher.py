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
from scipy.ndimage import distance_transform_edt, gaussian_filter
from skimage.measure import marching_cubes

from silhouette import MEASURED_AXES, View


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
    single_view = (len(views) == 1)
    for view in views:
        occupancy &= _extrusion(view, dims, apply_radial_profile=single_view)
    if not occupancy.any():
        # Siluetas incompatibles entre sí (encuadres muy distintos): es
        # preferible una caja con las proporciones medidas que nada.
        occupancy = np.ones(dims, dtype=bool)
    return occupancy, dims


def surface(occupancy: np.ndarray, dims: tuple[int, int, int],
            extents: tuple[float, float, float], atlas,
            smoothing: int = 2,
            views: list[View] | None = None) -> Geometry:
    """Convierte los vóxeles ocupados en una malla continua y texturizada usando Marching Cubes."""
    pad_occ = np.pad(occupancy, 1, mode='constant', constant_values=False)

    sigma_val = max(0.5, smoothing * 0.4)
    is_any_round = any(getattr(v, 'is_round', False) for v in views) if views else False

    if is_any_round:
        field_data = gaussian_filter(pad_occ.astype(np.float32), sigma=sigma_val)
    elif views is not None and len(views) == 1:
        view = views[0]
        wide_axis, tall_axis = MEASURED_AXES.get(view.index, (0, 1))
        depth_axis = next(axis for axis in range(3) if axis not in (wide_axis, tall_axis))
        sigma = [sigma_val, sigma_val, sigma_val]
        sigma[depth_axis] = 0.25
        field_data = gaussian_filter(pad_occ.astype(np.float32), sigma=tuple(sigma))
    else:
        field_data = gaussian_filter(pad_occ.astype(np.float32), sigma=sigma_val)

    try:
        verts, faces, normals, values = marching_cubes(field_data, level=0.5)
    except ValueError:
        return Geometry()

    half = [extents[0]*0.5, extents[1]*0.5, extents[2]*0.5]
    scaled_verts = np.zeros_like(verts)
    for i in range(3):
        scaled_verts[:, i] = -half[i] + ((verts[:, i] - 1.0) / max(1, dims[i])) * extents[i]

    final_positions = []
    final_normals = []
    final_uvs = []
    final_indices = []
    vertex_count = 0

    single_view = views is not None and len(views) == 1

    for face in faces:
        p0, p1, p2 = scaled_verts[face[0]], scaled_verts[face[1]], scaled_verts[face[2]]
        n0, n1, n2 = normals[face[0]], normals[face[1]], normals[face[2]]
        
        if single_view:
            # En vista única (solo foto frontal), proyectar de forma continua desde el frente
            # para z >= 0 y desde atrás (espejado) para z < 0, evitando saltos bruscos a 45°
            face_z = (p0[2] + p1[2] + p2[2]) / 3.0
            slot = atlas.slot_for(0 if face_z >= 0 else 1)
        else:
            face_normal = (n0 + n1 + n2) / 3.0
            axis = int(np.argmax(np.abs(face_normal)))
            sign = 1 if face_normal[axis] >= 0 else -1
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


def _extrusion(view: View, dims: tuple[int, int, int], apply_radial_profile: bool = False) -> np.ndarray:
    projection = PROJECTIONS[view.index]
    horizontal_axis, horizontal_sign = projection.horizontal
    vertical_axis, vertical_sign = projection.vertical
    depth_axis = next(axis for axis in range(3) if axis not in (horizontal_axis, vertical_axis))

    silhouette = _resample(view.mask, dims[horizontal_axis], dims[vertical_axis])
    if horizontal_sign < 0:
        silhouette = silhouette[::-1, :]
    if vertical_sign < 0:
        silhouette = silhouette[:, ::-1]

    W, H = silhouette.shape
    D = dims[depth_axis]

    if not apply_radial_profile:
        order = [horizontal_axis, vertical_axis, depth_axis]
        return np.transpose(silhouette[:, :, None] * np.ones((1, 1, D), dtype=bool), np.argsort(order))

    # Transformada de distancia euclidiana (EDT) 2D:
    # Garantiza una superficie 100% continua en todas direcciones,
    # eliminando saltos bruscos entre filas ("dientes de sierra" o grietas).
    edt = distance_transform_edt(silhouette)
    zc = (D - 1) / 2.0
    scale_z = D / float(W)

    p = getattr(view, 'p', 4.0)
    is_round = getattr(view, 'is_round', False)
    max_d = edt.max() if edt.max() > 0 else 1.0

    vol_slice = np.zeros((W, H, D), dtype=bool)

    for x in range(W):
        for y in range(H):
            d = edt[x, y]
            if d <= 0:
                continue

            if is_round:
                # Perfil circular / revolución continuo
                max_dz = d * scale_z
            else:
                # Perfil superelíptico / caja / plano (ej. teléfonos o cubos)
                norm_d = min(1.0, d / (max_d * 0.45))
                max_dz = (norm_d ** (1.0 / p)) * (D * 0.48)

            for z in range(D):
                if abs(z - zc) <= max_dz:
                    vol_slice[x, y, z] = True

    order = [horizontal_axis, vertical_axis, depth_axis]
    return np.transpose(vol_slice, np.argsort(order))


def _resample(mask: np.ndarray, columns: int, rows: int) -> np.ndarray:
    """Reescala la máscara y la reindexa como [horizontal, vertical]."""
    source = Image.fromarray(mask.T.astype(np.uint8) * 255, mode='L')
    return np.asarray(source.resize((rows, columns), Image.BILINEAR)) >= SILHOUETTE_LEVEL
