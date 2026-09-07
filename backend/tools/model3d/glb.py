"""Escritura y postproceso de glTF 2.0 binario (GLB).

El generador ligero sigue escribiendo su malla directamente. Los reconstructores
externos (por ejemplo Pixal3D) también pasan por :func:`inject_pbr_metadata`, de
modo que todos los archivos publicados exponen el mismo contrato PBR estándar.
"""

from __future__ import annotations

import json
import math
import struct
from pathlib import Path
from typing import Any, Mapping

import numpy as np

FLOAT = 5126
UNSIGNED_INT = 5125
ARRAY_BUFFER = 34962
ELEMENT_ARRAY_BUFFER = 34963
LINEAR = 9729
LINEAR_MIPMAP_LINEAR = 9987
CLAMP_TO_EDGE = 33071

GLB_MAGIC = 0x46546C67
JSON_CHUNK = 0x4E4F534A
BINARY_CHUNK = 0x004E4942


def _unit(value: Any, fallback: float) -> float:
    """Convierte un factor PBR a un número finito dentro de ``[0, 1]``."""
    try:
        result = float(value)
    except (TypeError, ValueError):
        return fallback
    if not math.isfinite(result):
        return fallback
    return min(1.0, max(0.0, result))


def _material_pbr(pbr: Mapping[str, Any] | None) -> dict[str, Any]:
    values = pbr or {}
    return {
        'roughness': _unit(values.get('roughness'), 0.55),
        'metalness': _unit(values.get('metalness'), 0.0),
        'clearcoat': _unit(values.get('clearcoat'), 0.0),
        'clearcoatRoughness': _unit(
            values.get('clearcoatRoughness', values.get('clearcoat_roughness')),
            0.2,
        ),
        'confidence': _unit(values.get('confidence'), 0.0),
        'materialFamily': str(values.get('materialFamily', 'unknown'))[:64],
        'source': str(values.get('source', 'fallback'))[:64],
        'model': str(values.get('model', 'none'))[:128],
    }


def write_glb(path: Path, geometry, texture: bytes, mime: str,
              roughness_factor: float = 0.55,
              metallic_factor: float = 0.0,
              clearcoat_factor: float = 0.0,
              clearcoat_roughness_factor: float = 0.2,
              pbr_metadata: Mapping[str, Any] | None = None) -> int:
    positions = np.asarray(geometry.positions, dtype=np.float32)
    normals = np.asarray(geometry.normals, dtype=np.float32)
    uvs = np.asarray(geometry.uvs, dtype=np.float32)
    indices = np.asarray(geometry.indices, dtype=np.uint32)

    payload = bytearray()
    views: list[dict] = []

    def add_view(data: bytes, target: int | None = None) -> int:
        while len(payload) % 4:
            payload.append(0)
        views.append({
            'buffer': 0,
            'byteOffset': len(payload),
            'byteLength': len(data),
            **({'target': target} if target is not None else {}),
        })
        payload.extend(data)
        return len(views) - 1

    position_view = add_view(positions.tobytes(), ARRAY_BUFFER)
    normal_view = add_view(normals.tobytes(), ARRAY_BUFFER)
    uv_view = add_view(uvs.tobytes(), ARRAY_BUFFER)
    index_view = add_view(indices.tobytes(), ELEMENT_ARRAY_BUFFER)
    texture_view = add_view(texture)
    while len(payload) % 4:
        payload.append(0)

    inferred = _material_pbr({
        **(pbr_metadata or {}),
        'roughness': roughness_factor,
        'metalness': metallic_factor,
        'clearcoat': clearcoat_factor,
        'clearcoatRoughness': clearcoat_roughness_factor,
    })
    material: dict[str, Any] = {
        'name': 'fotografias',
        'doubleSided': False,
        'pbrMetallicRoughness': {
            'baseColorTexture': {'index': 0},
            'metallicFactor': inferred['metalness'],
            'roughnessFactor': inferred['roughness'],
        },
        'extras': {'myLoveDepotPBR': inferred},
    }
    extensions_used: list[str] = []
    if inferred['clearcoat'] > 0.0:
        extensions_used.append('KHR_materials_clearcoat')
        material['extensions'] = {
            'KHR_materials_clearcoat': {
                'clearcoatFactor': inferred['clearcoat'],
                'clearcoatRoughnessFactor': inferred['clearcoatRoughness'],
            },
        }

    document: dict[str, Any] = {
        'asset': {
            'version': '2.0',
            'generator': 'My Love Depot volumetric pipeline v2',
        },
        'scene': 0,
        'scenes': [{'nodes': [0]}],
        'nodes': [{'mesh': 0, 'name': 'producto'}],
        'meshes': [{
            'name': 'producto',
            'primitives': [{
                'attributes': {'POSITION': 0, 'NORMAL': 1, 'TEXCOORD_0': 2},
                'indices': 3,
                'material': 0,
            }],
        }],
        'materials': [material],
        'textures': [{'sampler': 0, 'source': 0}],
        'images': [{'bufferView': texture_view, 'mimeType': mime}],
        'samplers': [{
            'magFilter': LINEAR,
            'minFilter': LINEAR_MIPMAP_LINEAR,
            'wrapS': CLAMP_TO_EDGE,
            'wrapT': CLAMP_TO_EDGE,
        }],
        'accessors': [
            {
                'bufferView': position_view, 'componentType': FLOAT,
                'count': len(positions), 'type': 'VEC3',
                'min': positions.min(axis=0).tolist(),
                'max': positions.max(axis=0).tolist(),
            },
            {
                'bufferView': normal_view, 'componentType': FLOAT,
                'count': len(normals), 'type': 'VEC3',
            },
            {
                'bufferView': uv_view, 'componentType': FLOAT,
                'count': len(uvs), 'type': 'VEC2',
            },
            {
                'bufferView': index_view, 'componentType': UNSIGNED_INT,
                'count': len(indices), 'type': 'SCALAR',
            },
        ],
        'bufferViews': views,
        'buffers': [{'byteLength': len(payload)}],
    }
    if extensions_used:
        document['extensionsUsed'] = extensions_used

    encoded = json.dumps(document, separators=(',', ':')).encode('utf8')
    encoded += b' ' * (-len(encoded) % 4)
    total = 12 + 8 + len(encoded) + 8 + len(payload)
    with path.open('wb') as target_file:
        target_file.write(struct.pack('<III', GLB_MAGIC, 2, total))
        target_file.write(struct.pack('<II', len(encoded), JSON_CHUNK))
        target_file.write(encoded)
        target_file.write(struct.pack('<II', len(payload), BINARY_CHUNK))
        target_file.write(payload)
    return total


def inject_pbr_metadata(path: Path, pbr: Mapping[str, Any],
                        *, preserve_texture_maps: bool = True) -> int:
    """Inyecta PBR en cualquier GLB sin tocar sus buffers binarios.

    Los mapas metallic/roughness generados por un reconstructor son información
    por píxel de mayor resolución que un único valor inferido por un VLM. Por eso
    se conservan sus multiplicadores cuando ``preserve_texture_maps`` es cierto;
    la inferencia completa siempre queda registrada en ``extras``.
    """
    raw = path.read_bytes()
    if len(raw) < 20:
        raise ValueError(f'GLB truncado: {path}')
    magic, version, declared_size = struct.unpack_from('<III', raw, 0)
    if magic != GLB_MAGIC or version != 2 or declared_size != len(raw):
        raise ValueError(f'GLB 2.0 inválido: {path}')

    chunks: list[tuple[int, bytes]] = []
    offset = 12
    while offset < len(raw):
        if offset + 8 > len(raw):
            raise ValueError(f'Cabecera de chunk GLB truncada: {path}')
        length, kind = struct.unpack_from('<II', raw, offset)
        offset += 8
        end = offset + length
        if end > len(raw):
            raise ValueError(f'Chunk GLB truncado: {path}')
        chunks.append((kind, raw[offset:end]))
        offset = end

    json_index = next(
        (index for index, (kind, _data) in enumerate(chunks)
         if kind == JSON_CHUNK),
        None,
    )
    if json_index is None:
        raise ValueError(f'El GLB no contiene un chunk JSON: {path}')

    document = json.loads(chunks[json_index][1].rstrip(b' \t\r\n\0'))
    inferred = _material_pbr(pbr)
    materials = document.setdefault('materials', [])
    if not materials:
        materials.append({'name': 'material-inferido'})
        for mesh in document.get('meshes', []):
            for primitive in mesh.get('primitives', []):
                primitive.setdefault('material', 0)

    uses_clearcoat = False
    for material in materials:
        metallic_roughness = material.setdefault('pbrMetallicRoughness', {})
        has_map = 'metallicRoughnessTexture' in metallic_roughness
        if not (preserve_texture_maps and has_map):
            metallic_roughness['metallicFactor'] = inferred['metalness']
            metallic_roughness['roughnessFactor'] = inferred['roughness']

        extras = material.setdefault('extras', {})
        extras['myLoveDepotPBR'] = inferred

        if inferred['clearcoat'] > 0.0:
            uses_clearcoat = True
            extensions = material.setdefault('extensions', {})
            extensions['KHR_materials_clearcoat'] = {
                'clearcoatFactor': inferred['clearcoat'],
                'clearcoatRoughnessFactor': inferred['clearcoatRoughness'],
            }

    if uses_clearcoat:
        extensions_used = document.setdefault('extensionsUsed', [])
        if 'KHR_materials_clearcoat' not in extensions_used:
            extensions_used.append('KHR_materials_clearcoat')

    asset = document.setdefault('asset', {'version': '2.0'})
    asset_extras = asset.setdefault('extras', {})
    asset_extras['myLoveDepotPipeline'] = {
        'version': 2,
        'pbrSource': inferred['source'],
        'pbrModel': inferred['model'],
    }

    encoded = json.dumps(document, separators=(',', ':')).encode('utf8')
    encoded += b' ' * (-len(encoded) % 4)
    chunks[json_index] = (JSON_CHUNK, encoded)

    total = 12 + sum(8 + len(data) for _kind, data in chunks)
    rebuilt = bytearray(struct.pack('<III', GLB_MAGIC, 2, total))
    for kind, data in chunks:
        rebuilt.extend(struct.pack('<II', len(data), kind))
        rebuilt.extend(data)
    path.write_bytes(rebuilt)
    return total
