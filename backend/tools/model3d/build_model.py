"""Construye el modelo 3D de un producto a partir de sus fotografías.

Uso:
    python build_model.py --input <carpeta> --output <archivo.glb>

La carpeta debe contener las vistas nombradas `view-0.*` … `view-4.*`, en el
mismo orden que el formulario de la app: Frente, Atrás, Izquierda, Derecha y
Arriba. Basta con una; cuantas más haya, más ajustado sale el contorno.

Al terminar imprime un resumen JSON en la salida estándar para que la API pueda
registrar qué vistas se aprovecharon.
"""

from __future__ import annotations

import argparse
import io
import json
import sys
from pathlib import Path

from atlas import Atlas
from glb import write_glb
from mesher import carve, surface
from silhouette import estimate_extents, load_view

VIEW_COUNT = 5
DEFAULT_RESOLUTION = 96
DEFAULT_SMOOTHING = 3
JPEG_QUALITY = 90


def build(source: Path, destination: Path, resolution: int,
          smoothing: int) -> dict:
    views = []
    skipped = []
    for index in range(VIEW_COUNT):
        candidates = sorted(source.glob(f'view-{index}.*'))
        if not candidates:
            continue
        view = load_view(index, candidates[0])
        if view is None:
            skipped.append(index)
        else:
            views.append(view)

    if not views:
        raise SystemExit(
            'Ninguna foto permitió separar el producto del fondo. '
            'Usa un fondo liso y que contraste con el producto.',
        )

    extents = estimate_extents(views)
    occupancy, dims = carve(views, extents, resolution)
    atlas = Atlas(views)
    geometry = surface(occupancy, dims, extents, atlas, smoothing, views=views)

    import subprocess

    texture = io.BytesIO()
    atlas.image.save(texture, format='JPEG', quality=JPEG_QUALITY, optimize=True)

    is_any_round = any(getattr(v, 'is_round', False) for v in views)
    is_any_cube = any(getattr(v, 'is_cube', False) for v in views)
    is_any_slab = any(getattr(v, 'p', 4.0) >= 4.2 and not getattr(v, 'is_round', False) and not getattr(v, 'is_cube', False) for v in views)

    if is_any_round:
        # Cerámica, vidrio: suave y ligeramente brillante
        roughness = 0.42
        metallic = 0.0
    elif is_any_cube:
        # Cajas, cubos: mate suave
        roughness = 0.55
        metallic = 0.0
    elif is_any_slab:
        # Carteras, teléfonos, libros, cajas: acabado natural mate con suave brillo difuso
        roughness = 0.62
        metallic = 0.0
    else:
        roughness = 0.55
        metallic = 0.0

    size = write_glb(destination, geometry, texture.getvalue(), 'image/jpeg',
                     roughness_factor=roughness, metallic_factor=metallic)

    render_path = destination.with_name('render.png')
    
    try:
        subprocess.run([
            'blender', '-b', '-P', str(Path(__file__).parent / 'render_studio.py'),
            '--', '--input', str(destination), '--output', str(render_path)
        ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        render_size = render_path.stat().st_size if render_path.exists() else 0
    except (subprocess.CalledProcessError, FileNotFoundError):
        render_size = 0

    return {
        'views': [view.index for view in views],
        'skippedViews': skipped,
        'grid': list(dims),
        'extents': [round(value, 4) for value in extents],
        'triangles': len(geometry.indices) // 3,
        'bytes': size,
        'render_bytes': render_size,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--resolution', type=int, default=DEFAULT_RESOLUTION)
    parser.add_argument('--smooth', type=int, default=DEFAULT_SMOOTHING,
                        help='pasadas de suavizado sobre la malla de vóxeles')
    arguments = parser.parse_args()

    if not arguments.input.is_dir():
        raise SystemExit(f'No existe la carpeta de vistas: {arguments.input}')
    arguments.output.parent.mkdir(parents=True, exist_ok=True)

    report = build(
        arguments.input,
        arguments.output,
        max(16, min(160, arguments.resolution)),
        max(0, min(8, arguments.smooth)),
    )
    json.dump(report, sys.stdout)
    sys.stdout.write('\n')


if __name__ == '__main__':
    main()
