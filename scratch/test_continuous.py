import sys
from pathlib import Path
import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt, gaussian_filter
from skimage.measure import marching_cubes

sys.path.insert(0, r'c:\Users\fcere\OneDrive\Desktop\jan\myLoveDepot\backend\tools\model3d')
from silhouette import load_view, estimate_extents
from mesher import _resample

scratch = Path(r'C:\Users\fcere\.gemini\antigravity-ide\brain\729d5a64-16ef-41e2-bd70-922f34c71078\scratch')

def render_preview(verts, normals, faces, out_path, color=(200, 200, 200), roughness=0.25):
    img_size = 400
    img = np.full((img_size, img_size, 3), 245, dtype=np.float32)
    z_buffer = np.full((img_size, img_size), -1e9, dtype=np.float32)

    rad_y = np.radians(35)
    rad_x = np.radians(-15)
    Ry = np.array([[np.cos(rad_y), 0, np.sin(rad_y)], [0, 1, 0], [-np.sin(rad_y), 0, np.cos(rad_y)]])
    Rx = np.array([[1, 0, 0], [0, np.cos(rad_x), -np.sin(rad_x)], [0, np.sin(rad_x), np.cos(rad_x)]])
    R = Rx @ Ry

    rot_v = verts @ R.T
    rot_n = normals @ R.T

    c_min = rot_v.min(axis=0)
    c_max = rot_v.max(axis=0)
    center = (c_min + c_max) / 2.0
    scale = (img_size * 0.72) / max(1e-5, (c_max - c_min).max())
    proj = (rot_v - center) * scale + (img_size / 2.0)

    light_dir = np.array([0.4, -0.6, 0.7], dtype=np.float32)
    light_dir /= np.linalg.norm(light_dir)
    view_dir = np.array([0, 0, 1.0], dtype=np.float32)
    half_vec = light_dir + view_dir
    half_vec /= np.linalg.norm(half_vec)

    base_col = np.array(color, dtype=np.float32)

    for face in faces:
        pts = proj[face]
        min_x = max(0, int(np.floor(pts[:, 0].min())))
        max_x = min(img_size - 1, int(np.ceil(pts[:, 0].max())))
        min_y = max(0, int(np.floor(pts[:, 1].min())))
        max_y = min(img_size - 1, int(np.ceil(pts[:, 1].max())))
        if min_x > max_x or min_y > max_y:
            continue

        p0, p1, p2 = pts[0], pts[1], pts[2]
        area = (p1[0] - p0[0]) * (p2[1] - p0[1]) - (p1[1] - p0[0]) * (p2[0] - p0[0])
        if abs(area) < 1e-5:
            continue

        fn = rot_n[face].mean(axis=0)
        norm_len = np.linalg.norm(fn)
        if norm_len > 1e-5:
            fn /= norm_len

        diff = max(0.0, float(np.dot(fn, light_dir)))
        spec = max(0.0, float(np.dot(fn, half_vec))) ** 48.0
        lit = base_col * (0.35 + 0.65 * diff) + np.array([255, 255, 255], dtype=np.float32) * (spec * (1.0 - roughness) * 1.8)
        lit = np.clip(lit, 0, 255)

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

    Image.fromarray(img.astype(np.uint8)).save(out_path)
    print(f"Generated: {out_path.name}")

def test_smooth_model(item_name, color):
    v_path = scratch / item_name / 'view-0.png'
    view = load_view(0, v_path)
    extents = estimate_extents([view])
    resolution = 64
    dims = tuple(max(6, round(resolution * v)) for v in extents)
    W, H, D = dims[0], dims[1], dims[2]

    sil = _resample(view.mask, W, H)
    edt = distance_transform_edt(sil)
    zc = (D - 1) / 2.0
    scale_z = D / float(W)
    max_d = edt.max() if edt.max() > 0 else 1.0

    # Campo escalar continuo 3D
    field_3d = np.zeros((W, H, D), dtype=np.float32)

    if view.is_cube:
        item_type = 'cube'
        roughness = 0.30
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
                    max_dz = max_z_val * (0.65 + 0.35 * np.sin(u * np.pi * 0.5))

                for z in range(D):
                    # Distancia al límite en Z: > 0 si está dentro, < 0 si está fuera
                    dist_to_surf = max_dz - abs(z - zc)
                    field_3d[x, y, z] = np.clip(0.5 + dist_to_surf * 0.8, 0.0, 1.0)
        sigma = (0.5, 0.5, 0.5)

    elif view.p >= 4.2 and not view.is_round:
        item_type = 'slab'
        roughness = 0.18
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
                    dist_to_surf = max_dz - abs(z - zc)
                    field_3d[x, y, z] = np.clip(0.5 + dist_to_surf * 0.8, 0.0, 1.0)
        sigma = (0.6, 0.6, 0.3)

    else:
        item_type = 'round'
        roughness = 0.22
        for x in range(W):
            for y in range(H):
                d = edt[x, y]
                if d <= 0:
                    continue
                # Perfil continuo 2D
                # En un objeto redondo, d define la distancia al borde de la silueta.
                # Para evitar aristas en la cresta central, suavizamos con curvatura continua:
                norm_d = min(1.0, d / (max_d * 0.48))
                # Curva superelíptica suave p=2.2 (redonda pero sin cúspide triangular)
                max_dz = (norm_d ** (1.0 / 2.2)) * (d * scale_z)
                # Limitar por la profundidad total
                max_dz = min(max_dz, (D - 1) * 0.48)

                for z in range(D):
                    dist_to_surf = max_dz - abs(z - zc)
                    field_3d[x, y, z] = np.clip(0.5 + dist_to_surf * 0.8, 0.0, 1.0)
        sigma = (0.9, 0.5, 0.9)

    pad_field = np.pad(field_3d, 1, mode='constant', constant_values=0.0)
    smoothed = gaussian_filter(pad_field, sigma=sigma)
    verts, faces, normals, values = marching_cubes(smoothed, level=0.5)

    out_path = scratch / f'continuous_{item_name}.png'
    render_preview(verts, normals, faces, out_path, color=color, roughness=roughness)

test_smooth_model('test_cube', (110, 150, 220))
test_smooth_model('test_pure', (45, 50, 60))
test_smooth_model('test_single_mug', (220, 215, 205))
