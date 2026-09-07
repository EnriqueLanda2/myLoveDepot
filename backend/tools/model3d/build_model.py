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
import os
from pathlib import Path
from typing import Optional, Dict, Any

from atlas import Atlas
from glb import write_glb
from mesher import carve, surface
from silhouette import estimate_extents, load_view

try:
    import rembg
    HAS_REMBG = True
except BaseException as e:
    print(f"rembg import failed: {e}", file=sys.stderr)
    HAS_REMBG = False

try:
    import google.generativeai as genai
    from pydantic import BaseModel, Field
    HAS_GEMINI = True
    
    class PBRMaterial(BaseModel):
        category: str = Field(description="Categoría del material (ej. ceramica, plastico, tela, metal)")
        object_type: str = Field(description="Tipo de objeto físico (ej. taza, vaso, maceta, anillo, caja, telefono)")
        metalness: float = Field(description="Nivel de metalness de 0.0 a 1.0")
        roughness: float = Field(description="Nivel de rugosidad de 0.0 a 1.0")
        clearcoat: float = Field(description="Nivel de barniz/esmalte (clearcoat) de 0.0 a 1.0")
        transmission: float = Field(description="Nivel de transparencia/transmisión de 0.0 a 1.0")
        
except Exception as e:
    print(f"gemini import failed: {e}", file=sys.stderr)
    HAS_GEMINI = False


VIEW_COUNT = 5
DEFAULT_RESOLUTION = 96
DEFAULT_SMOOTHING = 3
JPEG_QUALITY = 90


def extract_pbr_with_gemini(image_data: bytes) -> Dict[str, Any]:
    """Envía la imagen a Gemini 1.5 Pro para extraer parámetros PBR estructurados."""
    if not HAS_GEMINI:
        return {}
    
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        print("GEMINI_API_KEY no encontrada. Omitiendo inferencia PBR por IA.", file=sys.stderr)
        return {}
        
    try:
        genai.configure(api_key=api_key)
        model = genai.GenerativeModel('gemini-1.5-pro')
        
        prompt = (
            "Analiza esta fotografía de producto. Identifica el objeto y sus materiales físicos. "
            "Devuelve los siguientes valores para un material PBR: 'metalness' (0.0 a 1.0), "
            "'roughness' (0.0 a 1.0), 'clearcoat' (0.0 a 1.0), 'transmission' (para vidrio/plástico "
            "transparente, 0.0 a 1.0), 'category' (ej. ceramica_vidriada, tela, metal) "
            "y 'object_type' (ej. taza, anillo, telefono)."
        )
        
        # Preparar la imagen para Gemini
        blob = {
            "mime_type": "image/png",
            "data": image_data
        }
        
        response = model.generate_content(
            [prompt, blob],
            generation_config=genai.GenerationConfig(
                response_mime_type="application/json",
                response_schema=PBRMaterial
            )
        )
        
        data = json.loads(response.text)
        return {
            "metalness": data.get("metalness", 0.0),
            "roughness": data.get("roughness", 0.5),
            "clearcoat": data.get("clearcoat", 0.0),
            "transmission": data.get("transmission", 0.0),
            "source": "gemini-1.5-pro",
            "materialFamily": data.get("category", "unknown"),
            "objectType": data.get("object_type", "unknown")
        }
    except Exception as e:
        print(f"Error inferiendo PBR con Gemini: {e}", file=sys.stderr)
        return {}

def isolate_background(image_path: Path) -> Path:
    """Usa rembg para aislar perfectamente el producto y guarda un PNG con alpha."""
    if not HAS_REMBG:
        return image_path
        
    try:
        with open(image_path, "rb") as f:
            input_data = f.read()
            
        # Usar u2netp (el modelo ligero de 4.7MB) en vez del u2net normal (170MB)
        # y desactivar alpha_matting que usa pymatting (calcula grandes matrices en RAM)
        session = rembg.new_session("u2netp")
        output_data = rembg.remove(
            input_data, 
            session=session,
            alpha_matting=False
        )
        
        out_path = image_path.with_suffix('.isolated.png')
        with open(out_path, "wb") as f:
            f.write(output_data)
        return out_path
    except Exception as e:
        print(f"Error en rembg para {image_path}: {e}", file=sys.stderr)
        return image_path

def build(source: Path, destination: Path, resolution: int,
          smoothing: int) -> dict:
    views = []
    skipped = []
    for index in range(VIEW_COUNT):
        candidates = sorted(source.glob(f'view-{index}.*'))
        if not candidates:
            continue
            
        # Omitir archivos ya procesados si se corre varias veces
        candidates = [c for c in candidates if not c.name.endswith('.isolated.png')]
        if not candidates:
            continue
            
        original_path = candidates[0]
        
        # Aislar objeto con IA antes de cargar
        isolated_path = isolate_background(original_path)
        
        view = load_view(index, isolated_path)
        if view is None:
            skipped.append(index)
        else:
            views.append(view)

    if not views:
        raise SystemExit(
            'Ninguna foto permitió separar el producto del fondo. '
            'Usa un fondo liso y que contraste con el producto.',
        )

    # Inferencia PBR Inteligente y Semántica (Director de Arte)
    # Extraer características antes del tallado para guiar la geometría (Semantic Carving)
    pbr_metadata = {}
    if views and HAS_GEMINI:
        try:
            primary_view_img = io.BytesIO()
            views[0].crop.save(primary_view_img, format='PNG')
            pbr_metadata = extract_pbr_with_gemini(primary_view_img.getvalue())
            print(f"Gemini Semantic Inference: {pbr_metadata}", file=sys.stderr)
        except Exception as e:
            print(f"Fallo en orquestación semántica: {e}", file=sys.stderr)

    semantic_category = pbr_metadata.get('objectType', 'unknown').lower()

    extents = estimate_extents(views)
    occupancy, dims = carve(views, extents, resolution, semantic_category=semantic_category)
    atlas = Atlas(views)
    geometry = surface(occupancy, dims, extents, atlas, smoothing, views=views)

    import subprocess

    texture = io.BytesIO()
    atlas.image.save(texture, format='JPEG', quality=JPEG_QUALITY, optimize=True)

    # La inferencia ya se realizó antes del tallado.

    # Fallback heurístico si falla Gemini
    is_any_round = any(getattr(v, 'is_round', False) for v in views)
    is_any_cube = any(getattr(v, 'is_cube', False) for v in views)
    is_any_slab = any(getattr(v, 'p', 4.0) >= 4.2 and not getattr(v, 'is_round', False) and not getattr(v, 'is_cube', False) for v in views)

    roughness = pbr_metadata.get('roughness', 0.55)
    metallic = pbr_metadata.get('metalness', 0.0)
    clearcoat = pbr_metadata.get('clearcoat', 0.0)
    
    if not pbr_metadata:
        if is_any_round:
            roughness = 0.42
            metallic = 0.0
        elif is_any_cube:
            roughness = 0.55
            metallic = 0.0
        elif is_any_slab:
            roughness = 0.62
            metallic = 0.0
        else:
            roughness = 0.55
            metallic = 0.0

    size = write_glb(
        destination, geometry, texture.getvalue(), 'image/jpeg',
        roughness_factor=roughness, 
        metallic_factor=metallic,
        clearcoat_factor=clearcoat,
        pbr_metadata=pbr_metadata
    )

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
