"""Escritor de glTF 2.0 binario (.glb) con la textura embebida.

Se escribe a mano en lugar de arrastrar una librería de mallas: el archivo tiene
una sola malla, un material y una imagen, y el formato cabe en este módulo.
"""

from __future__ import annotations

import json
import struct
from pathlib import Path

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


def write_glb(path: Path, geometry, texture: bytes, mime: str,
              roughness_factor: float = 0.24,
              metallic_factor: float = 0.04) -> int:
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

    document = {
        'asset': {'version': '2.0', 'generator': 'My Love Depot · casco visual'},
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
        'materials': [{
            'name': 'fotografias',
            'doubleSided': True,
            'pbrMetallicRoughness': {
                'baseColorTexture': {'index': 0},
                'metallicFactor': float(metallic_factor),
                'roughnessFactor': float(roughness_factor),
            },
        }],
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
