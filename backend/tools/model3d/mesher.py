"""Casco visual (shape from silhouette) y extracción de su superficie.

Cada silueta se extruye a lo largo del eje desde el que fue fotografiada y el
volumen del producto es la intersección de todas esas extrusiones. Con vistas
ortogonales el contorno resultante es exacto y no se inventa nada: se obtiene el
volumen más pequeño compatible con las fotos. Lo que este método no puede
recuperar son las concavidades, porque ninguna silueta las delata.

La superficie sale de los vóxeles como una escalera, así que se relaja con un
suavizado de Taubin antes de escribirla.
"""

from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np
from PIL import Image

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

# Suavizado de Taubin: una pasada que encoge y otra que expande, de modo que la
# escalera de vóxeles se redondea sin que el modelo adelgace.
SHRINK = 0.55
INFLATE = -0.58


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
    """Convierte los vóxeles ocupados en una malla texturizada y suavizada."""
    half = [value * 0.5 for value in extents]
    corners: list[list[float]] = []
    slots: list = []
    quads: list[list[int]] = []
    for axis in range(3):
        for sign in (1, -1):
            _emit(corners, slots, quads, occupancy, dims, half, atlas, axis, sign)
    if not quads:
        return Geometry()

    raw = np.asarray(corners, dtype=np.float64)
    joints, seams = np.unique(raw.round(6), axis=0, return_inverse=True)
    seams = seams.reshape(-1)
    faces = seams[np.asarray(quads, dtype=np.int64)]

    joints = _relax(joints, faces, smoothing)
    joint_normals = _normals(joints, faces)
    return _assemble(joints, joint_normals, seams, slots, quads, half)


def _emit(corners: list, slots: list, quads: list, occupancy: np.ndarray,
          dims: tuple[int, int, int], half: list[float], atlas,
          axis: int, sign: int) -> None:
    exposed = occupancy & ~_neighbour(occupancy, axis, sign)
    if not exposed.any():
        return

    first, second = (axis + 1) % 3, (axis + 2) % 3
    slot = atlas.slot_for(FACE_VIEWS[(axis, sign)])
    cells = np.argwhere(exposed)
    for cell in cells:
        layer = int(cell[axis])
        step_a, step_b = int(cell[first]), int(cell[second])
        depth = _coordinate(axis, layer + (1 if sign > 0 else 0), dims, half)
        square = [(step_a, step_b), (step_a + 1, step_b),
                  (step_a + 1, step_b + 1), (step_a, step_b + 1)]
        if sign < 0:
            square.reverse()
        base = len(corners)
        for offset_a, offset_b in square:
            point = [0.0, 0.0, 0.0]
            point[axis] = depth
            point[first] = _coordinate(first, offset_a, dims, half)
            point[second] = _coordinate(second, offset_b, dims, half)
            corners.append(point)
            slots.append(slot)
        quads.append([base, base + 1, base + 2, base + 3])


def _assemble(joints: np.ndarray, joint_normals: np.ndarray, seams: np.ndarray,
              slots: list, quads: list, half: list[float]) -> Geometry:
    """Suelda los vértices que comparten posición y fotografía."""
    lookup: dict[tuple[int, int], int] = {}
    positions: list[np.ndarray] = []
    normals: list[np.ndarray] = []
    uvs: list[tuple[float, float]] = []
    indices: list[int] = []

    for quad in quads:
        merged = []
        for corner in quad:
            joint = int(seams[corner])
            slot = slots[corner]
            key = (joint, id(slot))
            index = lookup.get(key)
            if index is None:
                index = len(positions)
                lookup[key] = index
                point = joints[joint]
                positions.append(point)
                normals.append(joint_normals[joint])
                uvs.append(slot.coordinates(point, half))
            merged.append(index)
        indices.extend([merged[0], merged[1], merged[2],
                        merged[0], merged[2], merged[3]])

    return Geometry(
        positions=np.asarray(positions, dtype=np.float32),
        normals=np.asarray(normals, dtype=np.float32),
        uvs=np.asarray(uvs, dtype=np.float32),
        indices=np.asarray(indices, dtype=np.uint32),
    )


def _relax(points: np.ndarray, faces: np.ndarray, iterations: int) -> np.ndarray:
    if iterations <= 0:
        return points
    owners, others, counts = _adjacency(len(points), faces)
    for _ in range(iterations):
        for factor in (SHRINK, INFLATE):
            summed = np.zeros_like(points)
            np.add.at(summed, owners, points[others])
            points = points + factor * (summed / counts[:, None] - points)
    return points


def _adjacency(count: int, faces: np.ndarray):
    edges = np.concatenate([faces[:, [step, (step + 1) % 4]] for step in range(4)])
    pairs = np.unique(np.concatenate([edges, edges[:, ::-1]]), axis=0)
    degrees = np.bincount(pairs[:, 0], minlength=count).astype(np.float64)
    degrees[degrees == 0] = 1.0
    return pairs[:, 0], pairs[:, 1], degrees


def _normals(points: np.ndarray, faces: np.ndarray) -> np.ndarray:
    # Newell sobre cada quad: funciona aunque el suavizado lo haya dejado alabeado.
    accumulated = np.zeros_like(points)
    facets = np.cross(
        points[faces[:, 2]] - points[faces[:, 0]],
        points[faces[:, 3]] - points[faces[:, 1]],
    )
    for corner in range(4):
        np.add.at(accumulated, faces[:, corner], facets)
    lengths = np.linalg.norm(accumulated, axis=1, keepdims=True)
    lengths[lengths == 0] = 1.0
    return accumulated / lengths


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


def _neighbour(occupancy: np.ndarray, axis: int, sign: int) -> np.ndarray:
    shifted = np.roll(occupancy, -sign, axis=axis)
    edge: list = [slice(None)] * 3
    edge[axis] = -1 if sign > 0 else 0
    shifted[tuple(edge)] = False
    return shifted


def _coordinate(axis: int, index: int, dims: tuple[int, int, int],
                half: list[float]) -> float:
    return -half[axis] + 2 * half[axis] * index / dims[axis]
