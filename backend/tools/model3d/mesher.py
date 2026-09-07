"""Casco visual (shape from silhouette) y extracción de su superficie.

Cada silueta se extruye a lo largo del eje desde el que fue fotografiada y el
volumen del producto es la intersección de todas esas extrusiones. Con vistas
ortogonales el contorno resultante es exacto y no se inventa nada: se obtiene el
volumen más pequeño compatible con las fotos. Lo que este método no puede
recuperar son las concavidades, porque ninguna silueta las delata.

La superficie se extrae utilizando el algoritmo de Marching Cubes sobre un
campo de distancia suavizado (SDF continuo + Gaussian Filter) para erradicar
el escalonado. Operaciones totalmente vectorizadas con numpy.
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

MIN_CELLS = 8
SILHOUETTE_LEVEL = 96


@dataclass
class Geometry:
    positions: np.ndarray = field(default_factory=lambda: np.zeros((0, 3), np.float32))
    normals: np.ndarray = field(default_factory=lambda: np.zeros((0, 3), np.float32))
    uvs: np.ndarray = field(default_factory=lambda: np.zeros((0, 2), np.float32))
    indices: np.ndarray = field(default_factory=lambda: np.zeros(0, np.uint32))


def carve(views: list[View], extents: tuple[float, float, float],
          resolution: int, semantic_category: str = 'unknown') -> tuple[np.ndarray, tuple[int, int, int]]:
    """Interseca las siluetas disponibles en un casco visual continuo.

    Cada orientación aporta una restricción independiente. La versión anterior
    solo extruía la primera foto, de modo que subir laterales o una vista
    superior no cambiaba la geometría. Si únicamente hay una orientación,
    añadimos el prior de profundidad conservador de ``_extrusion_sdf`` porque
    esa dimensión no puede observarse en una sola fotografía.
    """
    if not views:
        raise ValueError('Se necesita al menos una vista para tallar el volumen')
    dims = tuple(max(MIN_CELLS, round(resolution * value)) for value in extents)
    primary = next((v for v in views if v.index == 0), views[0])
    fields = [_silhouette_sdf(view, dims) for view in views]
    independent_pairs = {MEASURED_AXES[view.index] for view in views}
    if len(independent_pairs) < 2:
        fields.append(_extrusion_sdf(primary, dims))
    occupancy = np.minimum.reduce(fields)
    
    # Semantic Carving: Excavar concavidades lógicas según el objeto
    if "taza" in semantic_category or "vaso" in semantic_category or "maceta" in semantic_category:
        W, H, D = dims[0], dims[1], dims[2]
        # El centro del objeto (ejes X y Z en matriz transpuesta)
        cx, cz = W / 2.0, D / 2.0
        # Radio del hueco interior
        radius = min(W, D) * 0.35
        # Grosor de la base
        base_thickness = int(H * 0.15)
        
        # Ocupancy shape = (W, H, D). Eje Y=H es arriba (por _extrusion_sdf).
        # Generar meshgrid (X, Y, Z)
        x = np.arange(W)[:, np.newaxis, np.newaxis]
        y = np.arange(H)[np.newaxis, :, np.newaxis]
        z = np.arange(D)[np.newaxis, np.newaxis, :]
        
        # Distancia al centro en X,Z
        dist2d = np.sqrt((x - cx)**2 + (z - cz)**2)
        
        # Si estamos dentro del cilindro y arriba del fondo de la taza
        is_hole = (dist2d < radius) & (y > base_thickness)
        
        # Aplicamos suavizado en los bordes para Marching Cubes
        # is_hole es un booleano, calculamos la distancia al borde del agujero para SDF suave
        # dist2d va desde 0 hasta >radius
        # margin: valores positivos = dentro de la pared de la taza, negativos = dentro del hueco
        margin_hole = (dist2d - radius) / 2.0 
        # Forzar 0.0 donde el margin es muy negativo y y > base_thickness
        hole_sdf = np.clip(margin_hole + 0.5, 0.0, 1.0)
        
        # Combinar el SDF del hueco con la ocupancia general (solo si estamos arriba de la base)
        # Donde y <= base_thickness, se mantiene 1.0 (no afecta)
        # Donde y > base_thickness, aplica hole_sdf recorta el cilindro
        modifier = np.where(y > base_thickness, hole_sdf, 1.0)
        
        occupancy = np.minimum(occupancy, modifier)
        
    elif "anillo" in semantic_category:
        W, H, D = dims[0], dims[1], dims[2]
        cx, cy = W / 2.0, H / 2.0
        # Anillo se talla como un donut, perforando en Z (si el anillo está de frente) o en Y si está acostado
        # Suponemos que el frente es la vista 0 y el anillo está de cara.
        radius = min(W, H) * 0.38
        x = np.arange(W)[:, np.newaxis, np.newaxis]
        y = np.arange(H)[np.newaxis, :, np.newaxis]
        dist2d = np.sqrt((x - cx)**2 + (y - cy)**2)
        
        margin_hole = (dist2d - radius) / 2.0
        hole_sdf = np.clip(margin_hole + 0.5, 0.0, 1.0)
        occupancy = np.minimum(occupancy, hole_sdf)
        
    return occupancy, dims


def surface(occupancy: np.ndarray, dims: tuple[int, int, int],
            extents: tuple[float, float, float], atlas,
            smoothing: int = 2,
            views: list[View] | None = None) -> Geometry:
    """Convierte el campo SDF en una malla continua y texturizada con Marching Cubes."""
    pad_occ = np.pad(occupancy, 2, mode='constant', constant_values=0.0)

    # Un filtro isotrópico conserva las restricciones de todas las categorías.
    # Los perfiles especiales anteriores favorecían cilindros/tazas y podían
    # redondear cajas, libros o cosméticos aunque su silueta fuera recta.
    sigma = max(0.55, smoothing * 0.30)
    field_data = gaussian_filter(pad_occ, sigma=sigma)

    # Nivel de isosuperficie adaptativo
    mc_level = 0.45

    # El fallback se genera con detalle completo. El visor crea después LODs
    # reales y decide qué nivel dibujar según el presupuesto de frame.
    step = 1 if max(dims) <= 96 else 2

    try:
        verts, faces, normals, _values = marching_cubes(field_data, level=mc_level, step_size=step)
    except (ValueError, RuntimeError):
        return Geometry()

    if len(verts) == 0:
        return Geometry()

    # Compensar el padding de 2 (las coordenadas de MC ya están en unidades de vóxel)
    verts = verts - 2.0

    # Un paso leve elimina ruido de voxel sin borrar asas, patas ni relieves.
    iterations = 1 if smoothing > 0 else 0
    verts = _laplacian_smooth(verts, faces, iterations=iterations, factor=0.18)

    # Recalcular normales suavizadas después del Laplaciano
    normals = _compute_smooth_normals(verts, faces)

    # Escalar a coordenadas del modelo
    half = [extents[0] * 0.5, extents[1] * 0.5, extents[2] * 0.5]
    scaled_verts = np.zeros_like(verts)
    for i in range(3):
        scaled_verts[:, i] = -half[i] + (verts[:, i] / max(1, dims[i])) * extents[i]

    # Construir la geometría final con asignación de UV por cara
    has_side_views = views is not None and any(v.index in (2, 3) for v in views)
    has_top_view = views is not None and any(v.index == 4 for v in views)

    final_positions = []
    final_normals = []
    final_uvs = []
    final_indices = []
    vertex_count = 0

    for face in faces:
        p0, p1, p2 = scaled_verts[face[0]], scaled_verts[face[1]], scaled_verts[face[2]]
        n0, n1, n2 = normals[face[0]], normals[face[1]], normals[face[2]]

        face_normal = (n0 + n1 + n2) / 3.0
        nl = np.linalg.norm(face_normal)
        if nl > 1e-8:
            face_normal /= nl
        nx, ny, nz = float(face_normal[0]), float(face_normal[1]), float(face_normal[2])
        abs_x, abs_y, abs_z = abs(nx), abs(ny), abs(nz)

        # Asignación de vista según la orientación de la normal
        if abs_z >= abs_x and abs_z >= abs_y:
            view_idx = 0 if nz >= 0 else 1
        elif abs_x > abs_y and has_side_views:
            view_idx = 2 if nx < 0 else 3
        elif ny > abs_x and ny > abs_z and has_top_view:
            view_idx = 4
        elif ny < -abs_x and ny < -abs_z:
            view_idx = None  # Base: color neutro
        else:
            centroid_z = (p0[2] + p1[2] + p2[2]) / 3.0
            view_idx = 0 if centroid_z >= 0 else 1

        slot = atlas.slot_for(view_idx)
        uv0 = slot.coordinates(p0, half)
        uv1 = slot.coordinates(p1, half)
        uv2 = slot.coordinates(p2, half)

        final_positions.extend([p0, p1, p2])
        final_normals.extend([n0, n1, n2])
        final_uvs.extend([uv0, uv1, uv2])

        final_indices.extend([vertex_count, vertex_count + 1, vertex_count + 2])
        vertex_count += 3

    return Geometry(
        positions=np.asarray(final_positions, dtype=np.float32),
        normals=np.asarray(final_normals, dtype=np.float32),
        uvs=np.asarray(final_uvs, dtype=np.float32),
        indices=np.asarray(final_indices, dtype=np.uint32),
    )


def _laplacian_smooth(verts: np.ndarray, faces: np.ndarray,
                      iterations: int = 3, factor: float = 0.35) -> np.ndarray:
    """Suavizado Laplaciano: mueve cada vértice hacia la media de sus vecinos.

    Elimina facetas angulares residuales del marching cubes sin perder volumen.
    """
    num_verts = len(verts)
    # Construir lista de adyacencia
    neighbors: list[list[int]] = [[] for _ in range(num_verts)]
    for f in faces:
        for i in range(3):
            a, b = int(f[i]), int(f[(i + 1) % 3])
            neighbors[a].append(b)
            neighbors[b].append(a)

    # Deduplicar vecinos
    for i in range(num_verts):
        neighbors[i] = list(set(neighbors[i]))

    smoothed = verts.copy()
    for _ in range(iterations):
        new_verts = smoothed.copy()
        for i in range(num_verts):
            nbrs = neighbors[i]
            if len(nbrs) == 0:
                continue
            avg = smoothed[nbrs].mean(axis=0)
            new_verts[i] = smoothed[i] + factor * (avg - smoothed[i])
        smoothed = new_verts

    return smoothed


def _compute_smooth_normals(verts: np.ndarray, faces: np.ndarray) -> np.ndarray:
    """Calcula normales suavizadas ponderadas por área de cada triángulo."""
    normals = np.zeros_like(verts)
    for face in faces:
        v0, v1, v2 = verts[face[0]], verts[face[1]], verts[face[2]]
        edge1 = v1 - v0
        edge2 = v2 - v0
        face_normal = np.cross(edge1, edge2)
        normals[face[0]] += face_normal
        normals[face[1]] += face_normal
        normals[face[2]] += face_normal

    lengths = np.linalg.norm(normals, axis=1, keepdims=True)
    lengths = np.maximum(lengths, 1e-8)
    normals = normals / lengths
    return normals


def _extrusion_sdf(view: View, dims: tuple[int, int, int]) -> np.ndarray:
    """Genera un campo de distancia continuo (SDF) — totalmente vectorizado.

    En lugar de un volumen booleano discreto, genera valores flotantes [0.0, 1.0]
    donde 1.0 = interior sólido y 0.0 = exterior. Los valores intermedios en los
    bordes producen isosuperficies perfectamente lisas con Marching Cubes.
    """
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

    # EDT 2D sobre la silueta: distancia de cada píxel al borde más cercano
    edt = distance_transform_edt(silhouette).astype(np.float64)
    max_d = max(float(edt.max()), 1.0)

    p = getattr(view, 'p', 4.0)
    is_round = getattr(view, 'is_round', False)
    is_cube = getattr(view, 'is_cube', False)
    is_slab = (p >= 4.2 and not is_round and not is_cube)

    # Centro del eje de profundidad
    zc = (D - 1) / 2.0
    scale_z = D / float(max(W, 1))

    # Coordenadas Z como array 1D
    z_coords = np.arange(D, dtype=np.float64)
    z_dist = np.abs(z_coords - zc)  # shape: (D,)

    # Calcular max_dz para cada (x, y) — vectorizado sobre la silueta completa
    if is_cube:
        u = np.minimum(1.0, edt / (max_d * 0.22))
        bevel = np.sin(u * (np.pi * 0.5))
        max_dz_2d = bevel * ((D - 1) * 0.48)
    elif is_slab:
        u = np.minimum(1.0, edt / (max_d * 0.20))
        bevel = np.sin(u * (np.pi * 0.5))
        max_dz_2d = bevel * ((D - 1) * 0.48)
    elif is_round:
        u = np.minimum(1.0, edt / (max_d * 0.50))
        circ = np.sqrt(np.maximum(0.0, u * (2.0 - u)))
        max_dz_2d = np.minimum(circ * (edt * scale_z * 1.05), (D - 1) * 0.48)
    else:
        norm_d = np.minimum(1.0, edt / (max_d * 0.45))
        max_dz_2d = np.power(np.maximum(norm_d, 1e-12), 1.0 / p) * (D * 0.48)

    # Campo SDF 3D continuo — broadcast: max_dz_2d[W, H, 1] vs z_dist[1, 1, D]
    # margin = max_dz - |z - zc| : positivo = interior, negativo = exterior
    margin = max_dz_2d[:, :, np.newaxis] - z_dist[np.newaxis, np.newaxis, :]

    # Normalizar a [0, 1] con transición suave de ~1.5 vóxeles
    transition_width = 1.5
    sdf = np.clip(margin / transition_width + 0.5, 0.0, 1.0)

    # Enmascarar píxeles fuera de la silueta
    sdf[~silhouette[:, :, np.newaxis].repeat(D, axis=2)] = 0.0

    # Suavizar el borde de la silueta: aplicar un falloff en los 2 vóxeles periféricos
    edge_falloff = np.minimum(edt / 2.0, 1.0)
    sdf *= edge_falloff[:, :, np.newaxis]

    # Reordenar ejes al orden (X, Y, Z) del modelo
    order = [horizontal_axis, vertical_axis, depth_axis]
    return np.transpose(sdf, np.argsort(order))


def _silhouette_sdf(view: View, dims: tuple[int, int, int]) -> np.ndarray:
    """Extruye una silueta por todo su eje oculto para tallado multivista."""
    projection = PROJECTIONS[view.index]
    horizontal_axis, horizontal_sign = projection.horizontal
    vertical_axis, vertical_sign = projection.vertical
    depth_axis = next(
        axis for axis in range(3)
        if axis not in (horizontal_axis, vertical_axis)
    )

    silhouette = _resample(
        view.mask, dims[horizontal_axis], dims[vertical_axis],
    )
    if horizontal_sign < 0:
        silhouette = silhouette[::-1, :]
    if vertical_sign < 0:
        silhouette = silhouette[:, ::-1]

    inside = distance_transform_edt(silhouette)
    outside = distance_transform_edt(~silhouette)
    signed_distance = inside - outside
    field_2d = np.clip(0.5 + signed_distance / 2.0, 0.0, 1.0)
    field = np.repeat(
        field_2d[:, :, np.newaxis], dims[depth_axis], axis=2,
    )
    order = [horizontal_axis, vertical_axis, depth_axis]
    return np.transpose(field, np.argsort(order))


def _resample(mask: np.ndarray, columns: int, rows: int) -> np.ndarray:
    """Reescala la máscara y la reindexa como [horizontal, vertical]."""
    source = Image.fromarray(mask.T.astype(np.uint8) * 255, mode='L')
    return np.asarray(source.resize((rows, columns), Image.BILINEAR)) >= SILHOUETTE_LEVEL
