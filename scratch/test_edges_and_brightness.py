import sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageEnhance, ImageFilter
from scipy.ndimage import distance_transform_edt, gaussian_filter, gaussian_filter1d
# Matplotlib not needed

from skimage.measure import marching_cubes

sys.path.insert(0, r'c:\Users\fcere\OneDrive\Desktop\jan\myLoveDepot\backend\tools\model3d')
from silhouette import load_view, estimate_extents, MEASURED_AXES
from atlas import Atlas
from glb import write_glb
from mesher import Geometry, _resample

scratch = Path(r'C:\Users\fcere\.gemini\antigravity-ide\brain\729d5a64-16ef-41e2-bd70-922f34c71078\scratch')

def test_extrusion_and_mesh(view_path, item_name):
    view = load_view(0, view_path)
    extents = estimate_extents([view])
    resolution = 64
    dims = tuple(max(6, round(resolution * v)) for v in extents)
    W, H, D = dims[0], dims[1], dims[2]

    sil = _resample(view.mask, W, H)
    edt = distance_transform_edt(sil)
    zc = (D - 1) / 2.0
    scale_z = D / float(W)

    vol = np.zeros((W, H, D), dtype=bool)

    # Identificar tipo de item y configurar bordes
    if view.is_cube:
        item_type = 'cube'
        bevel = max(1.5, min(4.0, W * 0.05))
        max_z_val = (D - 1) * 0.48
        for x in range(W):
            for y in range(H):
                d = edt[x, y]
                if d <= 0:
                    continue
                if d >= bevel:
                    max_dz = max_z_val
                else:
                    u = d / bevel
                    max_dz = max_z_val * (0.75 + 0.25 * np.sin(u * np.pi * 0.5))
                for z in range(D):
                    if abs(z - zc) <= max_dz:
                        vol[x, y, z] = True

        sigma = (0.4, 0.4, 0.4)
        roughness = 0.32
        metallic = 0.02

    elif view.p >= 4.2 and not view.is_round:
        # Smartphone / slab plano
        item_type = 'slab'
        bevel = max(1.2, min(3.0, W * 0.04))
        max_z_val = (D - 1) * 0.48
        for x in range(W):
            for y in range(H):
                d = edt[x, y]
                if d <= 0:
                    continue
                if d >= bevel:
                    max_dz = max_z_val
                else:
                    u = d / bevel
                    max_dz = max_z_val * (0.65 + 0.35 * np.sin(u * np.pi * 0.5))
                for z in range(D):
                    if abs(z - zc) <= max_dz:
                        vol[x, y, z] = True

        sigma = (0.5, 0.5, 0.25)
        roughness = 0.18
        metallic = 0.12

    else:
        # Redondo (vaso, taza, botella, cosmeticos)
        item_type = 'round'
        # Calcular radio local por fila suavemente para capturar asas y varillas
        row_max = np.zeros(H, dtype=float)
        for y in range(H):
            row_d = edt[:, y]
            if row_d.any():
                row_max[y] = row_d.max()
        row_max_smooth = gaussian_filter1d(row_max, sigma=1.5)
        row_max_smooth = np.maximum(1.0, row_max_smooth)

        for x in range(W):
            for y in range(H):
                d = edt[x, y]
                if d <= 0:
                    continue
                r_loc = row_max_smooth[y]
                u = min(1.0, d / r_loc)
                # Arco de revolución circular real: sqrt(u * (2 - u))
                circ = np.sqrt(max(0.0, u * (2.0 - u)))
                max_dz = circ * (r_loc * scale_z)

                for z in range(D):
                    if abs(z - zc) <= max_dz:
                        vol[x, y, z] = True

        # Anisotrópico: suave en circunferencia (X, Z), pero borde superior e inferior nítidos (Y)
        sigma = (1.2, 0.45, 1.2)
        roughness = 0.24
        metallic = 0.04

    # Extraer superficie
    pad_occ = np.pad(vol, 1, mode='constant', constant_values=False)
    field_data = gaussian_filter(pad_occ.astype(np.float32), sigma=sigma)
    verts, faces, normals, values = marching_cubes(field_data, level=0.5)

    # Renderizar vista 3D con Phong Shading (difuso + brillo especular) para validar bordes y brillo
    img_size = 400
    img = np.full((img_size, img_size, 3), 245, dtype=np.float32)
    z_buffer = np.full((img_size, img_size), -1e9, dtype=np.float32)

    # Rotar 30 grados en Y y 15 en X para ver volumen, bordes y caras
    rad_y = np.radians(35)
    rad_x = np.radians(-15)
    Ry = np.array([[np.cos(rad_y), 0, np.sin(rad_y)], [0, 1, 0], [-np.sin(rad_y), 0, np.cos(rad_y)]])
    Rx = np.array([[1, 0, 0], [0, np.cos(rad_x), -np.sin(rad_x)], [0, np.sin(rad_x), np.cos(rad_x)]])
    R = Rx @ Ry

    rot_v = verts @ R.T
    rot_n = normals @ R.T

    # Bounding box y centrado
    c_min = rot_v.min(axis=0)
    c_max = rot_v.max(axis=0)
    center = (c_min + c_max) / 2.0
    scale = (img_size * 0.75) / max(1e-5, (c_max - c_min).max())

    proj = (rot_v - center) * scale + (img_size / 2.0)
    # Dirección de luz (desde arriba a la izquierda y frontal)
    light_dir = np.array([0.4, -0.6, 0.7], dtype=np.float32)
    light_dir /= np.linalg.norm(light_dir)
    view_dir = np.array([0, 0, 1.0], dtype=np.float32)

    # Shading por triángulo
    for face in faces:
        pts = proj[face]
        # Bounding box 2D del triángulo
        min_x = max(0, int(np.floor(pts[:, 0].min())))
        max_x = min(img_size - 1, int(np.ceil(pts[:, 0].max())))
        min_y = max(0, int(np.floor(pts[:, 1].min())))
        max_y = min(img_size - 1, int(np.ceil(pts[:, 1].max())))
        if min_x > max_x or min_y > max_y:
            continue

        p0, p1, p2 = pts[0], pts[1], pts[2]
        # Coordenadas baricéntricas
        area = (p1[0] - p0[0]) * (p2[1] - p0[1]) - (p1[1] - p0[0]) * (p2[0] - p0[0])
        if abs(area) < 1e-5:
            continue

        fn = rot_n[face].mean(axis=0)
        norm_len = np.linalg.norm(fn)
        if norm_len > 1e-5:
            fn /= norm_len

        # Difuso
        diff = max(0.0, float(np.dot(fn, light_dir)))
        # Brillo especular (Blinn-Phong)
        half_vec = light_dir + view_dir
        half_vec /= np.linalg.norm(half_vec)
        spec_power = 64.0 if item_type in ('round', 'slab') else 32.0
        spec = max(0.0, float(np.dot(fn, half_vec))) ** spec_power

        # Color base según item
        if item_type == 'cube':
            base_col = np.array([120, 150, 210], dtype=np.float32)
        elif item_type == 'slab':
            base_col = np.array([45, 50, 60], dtype=np.float32)
        else:
            base_col = np.array([210, 195, 185], dtype=np.float32)

        # Iluminación ambiental + difusa + brillo especular intenso en los bordes y caras
        lit = base_col * (0.35 + 0.65 * diff) + np.array([255, 255, 255], dtype=np.float32) * (spec * (1.0 - roughness) * 1.5)
        lit = np.clip(lit, 0, 255)

        # Rasterización rápida
        avg_z = pts[:, 2].mean()
        for py in range(min_y, max_y + 1):
            for px in range(min_x, max_x + 1):
                w0 = ((p1[0] - px) * (p2[1] - py) - (p1[1] - py) * (p2[0] - px)) / area
                w1 = ((p2[0] - px) * (p0[1] - py) - (p2[1] - py) * (p0[0] - px)) / area
                w2 = 1.0 - w0 - w1
                if w0 >= 0 and w1 >= 0 and w2 >= 0:
                    pz = w0 * p0[2] + w1 * p1[2] + w2 * p2[2]
                    if pz > z_buffer[py, px]:
                        z_buffer[py, px] = pz
                        img[py, px] = lit

    out_img = Image.fromarray(img.astype(np.uint8))
    out_path = scratch / f'preview_{item_name}.png'
    out_img.save(out_path)
    print(f"Saved preview: {out_path}")

    return item_type, verts, faces

for name in ['test_single_mug', 'test_cube', 'test_pure']:
    v_path = scratch / name / 'view-0.png'
    test_extrusion_and_mesh(v_path, name)
