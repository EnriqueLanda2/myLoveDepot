#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Modelado Procedural 3D: Smartphone y Soporte de Escritorio (75°)
================================================================
Genera mallas 3D 100% limpias, sólidas (manifold/watertight) y libres de
artefactos de extrusión escalonada lateral (gradas / staircasing).

Estructura de fases implementada:
- FASE 1: Descomposición geométrica (Primitivas analíticas: smartphone delgado con
          esquinas redondeadas y base con ranura a ~75°).
- FASE 2: Definición topológica (Mallas cerradas tipo quad-dominant / tris optimizados,
          aristas biseladas suaves, sin caras coplanares ni vértices sueltos).
- FASE 3: Mapeo y materiales (Mapeo UV frontal rectangular plano en [0,1]x[0,1] para
          el protector de pantalla; material PBR mate rugoso para el soporte).
- FASE 4: Exportación de malla (Formatos .glb / .gltf y .obj, con auditoría topológica).

Uso:
    blender -b -P generate_phone_stand_blender.py -- --output-dir ./output --format all --render
    o ejecutar directamente desde el editor de Scripting de Blender.
"""

import os
import sys
import math
import argparse
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector, Matrix


# =============================================================================
# UTILIDADES DE ESCENA
# =============================================================================
def reset_scene():
    """Limpia la escena eliminando mallas, materiales y texturas anteriores."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for block in bpy.data.meshes:
        bpy.data.meshes.remove(block)
    for block in bpy.data.materials:
        bpy.data.materials.remove(block)
    for block in bpy.data.images:
        bpy.data.images.remove(block)


# =============================================================================
# FASE 3: MATERIALES PBR
# =============================================================================
def create_pbr_materials(screen_image_path=None):
    """
    Configura y devuelve los tres materiales PBR requeridos:
    1. Mat_Phone_Screen: Pantalla frontal plana con rugosidad vítrea, IOR 1.52,
       emisión configurable y textura proyectada en el mapa UV [0,1]x[0,1].
    2. Mat_Phone_Body: Chasis de titanio / aluminio pulido (metálico 0.92, rugosidad 0.18).
    3. Mat_Stand_Matte: Material mate rugoso para el soporte de escritorio
       (polímero / silicona / arenado, metálico 0.02, rugosidad 0.88).
    """
    materials = {}

    # ---------------------------------------------------------
    # 1. Material Pantalla (Mat_Phone_Screen)
    # ---------------------------------------------------------
    mat_screen = bpy.data.materials.new(name="Mat_Phone_Screen")
    mat_screen.use_nodes = True
    nodes_s = mat_screen.node_tree.nodes
    links_s = mat_screen.node_tree.links
    nodes_s.clear()

    out_s = nodes_s.new(type="ShaderNodeOutputMaterial")
    out_s.location = (450, 0)
    bsdf_s = nodes_s.new(type="ShaderNodeBsdfPrincipled")
    bsdf_s.location = (100, 0)

    # Propiedades físicas del cristal de pantalla
    bsdf_s.inputs["Roughness"].default_value = 0.04
    bsdf_s.inputs["Metallic"].default_value = 0.0
    bsdf_s.inputs["IOR"].default_value = 1.52

    if screen_image_path and os.path.isfile(screen_image_path):
        try:
            img = bpy.data.images.load(screen_image_path)
            uv_node = nodes_s.new(type="ShaderNodeUVMap")
            uv_node.uv_map = "UVMap"
            uv_node.location = (-480, 0)

            tex_node = nodes_s.new(type="ShaderNodeTexImage")
            tex_node.image = img
            tex_node.location = (-240, 0)

            # Conexión UV explícita sin distorsión
            links_s.new(uv_node.outputs["UV"], tex_node.inputs["Vector"])
            links_s.new(tex_node.outputs["Color"], bsdf_s.inputs["Base Color"])
            links_s.new(tex_node.outputs["Color"], bsdf_s.inputs["Emission Color"])
            bsdf_s.inputs["Emission Strength"].default_value = 0.85
        except Exception as err:
            print(f"[Aviso] No se pudo cargar la imagen de pantalla ({err}). Usando tono OLED.")
            bsdf_s.inputs["Base Color"].default_value = (0.012, 0.015, 0.022, 1.0)
            bsdf_s.inputs["Emission Color"].default_value = (0.04, 0.06, 0.10, 1.0)
            bsdf_s.inputs["Emission Strength"].default_value = 0.2
    else:
        # Pantalla activa OLED oscura con brillo sutil
        bsdf_s.inputs["Base Color"].default_value = (0.012, 0.015, 0.022, 1.0)
        bsdf_s.inputs["Emission Color"].default_value = (0.03, 0.05, 0.09, 1.0)
        bsdf_s.inputs["Emission Strength"].default_value = 0.2

    links_s.new(bsdf_s.outputs["BSDF"], out_s.inputs["Surface"])
    materials["screen"] = mat_screen

    # ---------------------------------------------------------
    # 2. Material Chasis Smartphone (Mat_Phone_Body)
    # ---------------------------------------------------------
    mat_body = bpy.data.materials.new(name="Mat_Phone_Body")
    mat_body.use_nodes = True
    nodes_b = mat_body.node_tree.nodes
    links_b = mat_body.node_tree.links
    nodes_b.clear()

    out_b = nodes_b.new(type="ShaderNodeOutputMaterial")
    out_b.location = (300, 0)
    bsdf_b = nodes_b.new(type="ShaderNodeBsdfPrincipled")
    bsdf_b.location = (0, 0)

    # Titanio oscuro espacial
    bsdf_b.inputs["Base Color"].default_value = (0.05, 0.05, 0.06, 1.0)
    bsdf_b.inputs["Metallic"].default_value = 0.92
    bsdf_b.inputs["Roughness"].default_value = 0.18
    links_b.new(bsdf_b.outputs["BSDF"], out_b.inputs["Surface"])
    materials["phone_body"] = mat_body

    # ---------------------------------------------------------
    # 3. Material Mate del Soporte (Mat_Stand_Matte)
    # ---------------------------------------------------------
    mat_stand = bpy.data.materials.new(name="Mat_Stand_Matte")
    mat_stand.use_nodes = True
    nodes_st = mat_stand.node_tree.nodes
    links_st = mat_stand.node_tree.links
    nodes_st.clear()

    out_st = nodes_st.new(type="ShaderNodeOutputMaterial")
    out_st.location = (300, 0)
    bsdf_st = nodes_st.new(type="ShaderNodeBsdfPrincipled")
    bsdf_st.location = (0, 0)

    # Acabado mate rugoso de alta absorción (grafito/pizarra mate)
    bsdf_st.inputs["Base Color"].default_value = (0.06, 0.06, 0.07, 1.0)
    bsdf_st.inputs["Metallic"].default_value = 0.02
    bsdf_st.inputs["Roughness"].default_value = 0.88
    links_st.new(bsdf_st.outputs["BSDF"], out_st.inputs["Surface"])
    materials["stand"] = mat_stand

    return materials


# =============================================================================
# FASE 1 Y 2: DESCOMPOSICIÓN GEOMÉTRICA Y DEFINICIÓN TOPOLÓGICA
# =============================================================================
def build_smartphone(width=0.075, height=0.160, thickness=0.008,
                     corner_radius=0.008, screen_margin=0.0035,
                     corner_segments=10, bevel_width=0.0008, materials=None):
    """
    FASE 1: Smartphone delgado con cantos biselados y esquinas redondeadas.
    FASE 2: Malla cerrada (watertight/manifold) sin caras superpuestas ni gradas laterales.
    FASE 3: Mapeo UV ortográfico frontal en [0,1]x[0,1] en la pantalla activa.

    Dimensiones estándar en metros:
    - Ancho (X): 75 mm (0.075 m)
    - Alto (Z): 160 mm (0.160 m)
    - Grosor (Y): 8 mm (0.008 m)
    - Pantalla orientada hacia el frente (-Y).
    """
    mesh = bpy.data.meshes.new("Smartphone_Mesh")
    obj = bpy.data.objects.new("Smartphone", mesh)
    bpy.context.collection.objects.link(obj)

    # Asignación de slots de materiales
    if materials:
        obj.data.materials.append(materials["phone_body"]) # Slot 0: Chasis
        obj.data.materials.append(materials["screen"])     # Slot 1: Pantalla

    bm = bmesh.new()

    # Cálculo analítico de centros de esquinas en el plano XZ
    dx = width / 2.0 - corner_radius
    dz = height / 2.0 - corner_radius

    # 4 cuadrantes de arcos en sentido antihorario (CCW)
    quadrants = [
        (dx, -dz, -math.pi/2, 0.0),            # Inferior Derecha
        (dx, dz, 0.0, math.pi/2),             # Superior Derecha
        (-dx, dz, math.pi/2, math.pi),        # Superior Izquierda
        (-dx, -dz, math.pi, 3*math.pi/2)      # Inferior Izquierda
    ]

    half_t = thickness / 2.0
    front_outer_verts = []
    back_outer_verts = []

    # Generación analítica de la envolvente perimetral
    for cx, cz, a_start, a_end in quadrants:
        for i in range(corner_segments):
            angle = a_start + (a_end - a_start) * (i / corner_segments)
            x = cx + corner_radius * math.cos(angle)
            z = cz + corner_radius * math.sin(angle)
            # Frente en -Y (mirando al usuario), Trasera en +Y (apoyo)
            front_outer_verts.append(bm.verts.new((x, -half_t, z)))
            back_outer_verts.append(bm.verts.new((x, half_t, z)))

    bm.verts.ensure_lookup_table()
    num_pts = len(front_outer_verts)

    # 1. Paredes laterales continuas (quads continuos, elimina el escalonado lateral)
    for i in range(num_pts):
        next_i = (i + 1) % num_pts
        f = bm.faces.new([
            front_outer_verts[i],
            back_outer_verts[i],
            back_outer_verts[next_i],
            front_outer_verts[next_i]
        ])
        f.material_index = 0
        f.smooth = True

    # 2. Tapa trasera sólida en +Y
    back_face = bm.faces.new(back_outer_verts)
    back_face.material_index = 0
    back_face.smooth = False

    # 3. Contorno de la pantalla plana (inset perimetral limpio en -half_t)
    sw = width - 2.0 * screen_margin
    sh = height - 2.0 * screen_margin
    sr = max(0.002, corner_radius - screen_margin)
    sdx = sw / 2.0 - sr
    sdz = sh / 2.0 - sr

    screen_verts = []
    for cx, cz, a_start, a_end in [
        (sdx, -sdz, -math.pi/2, 0.0),
        (sdx, sdz, 0.0, math.pi/2),
        (-sdx, sdz, math.pi/2, math.pi),
        (-sdx, -sdz, math.pi, 3*math.pi/2)
    ]:
        for i in range(corner_segments):
            angle = a_start + (a_end - a_start) * (i / corner_segments)
            x = cx + sr * math.cos(angle)
            z = cz + sr * math.sin(angle)
            screen_verts.append(bm.verts.new((x, -half_t, z)))

    bm.verts.ensure_lookup_table()

    # 4. Marco frontal (anillo de quads entre bisel exterior y pantalla)
    for i in range(num_pts):
        next_i = (i + 1) % num_pts
        f = bm.faces.new([
            front_outer_verts[i],
            front_outer_verts[next_i],
            screen_verts[next_i],
            screen_verts[i]
        ])
        f.material_index = 0
        f.smooth = False

    # 5. Cara plana frontal de la pantalla activa (normal exterior hacia -Y)
    screen_face = bm.faces.new(screen_verts)
    screen_face.material_index = 1
    screen_face.smooth = False

    # -------------------------------------------------------------
    # FASE 3: MAPEO UV SIN DISTORSIÓN
    # -------------------------------------------------------------
    uv_layer = bm.loops.layers.uv.new("UVMap")

    min_x = -sw / 2.0
    max_x = sw / 2.0
    min_z = -sh / 2.0
    max_z = sh / 2.0

    # Despliegue ortográfico exacto en [0, 1] x [0, 1] para la pantalla
    for loop in screen_face.loops:
        vx = loop.vert.co.x
        vz = loop.vert.co.z
        u = (vx - min_x) / (max_x - min_x)
        v = (vz - min_z) / (max_z - min_z)
        loop[uv_layer].uv = (u, v)

    # UVs para el marco frontal y chasis (despliegue regular)
    for face in bm.faces:
        if face == screen_face:
            continue
        for loop in face.loops:
            co = loop.vert.co
            u = (co.x + width / 2.0) / width
            v = (co.z + height / 2.0) / height
            loop[uv_layer].uv = (u, v)

    # Recálculo de normales orientadas hacia el exterior
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()

    mesh.update()

    # Modificador Bevel para aristas redondeadas suaves
    bev = obj.modifiers.new("Bevel", type='BEVEL')
    bev.width = bevel_width
    bev.segments = 3
    bev.limit_method = 'ANGLE'
    bev.angle_limit = math.radians(40)

    return obj


def build_desk_stand(stand_width=0.088, angle_deg=75.0, bevel_width=0.0012, materials=None):
    """
    FASE 1: Soporte de escritorio con ranura de descanso y respaldo inclinado a ~75°.
    FASE 2: Malla sólida cerrada (manifold) extruida a lo largo de X con biseles en aristas.
    FASE 3: UVs uniformes y material mate rugoso.
    """
    mesh = bpy.data.meshes.new("Stand_Mesh")
    obj = bpy.data.objects.new("DeskStand", mesh)
    bpy.context.collection.objects.link(obj)

    if materials:
        obj.data.materials.append(materials["stand"])

    bm = bmesh.new()

    angle_rad = math.radians(angle_deg)
    tan_a = math.tan(angle_rad)
    cos_a = math.cos(angle_rad)

    # Geometría de la ranura y el bloque de soporte
    slot_bottom_z = 0.008      # Altura del suelo de la ranura (8 mm sobre la mesa)
    lip_height = 0.020         # Altura del labio frontal de retención (20 mm)
    lip_front_y = -0.042       # Cara frontal del soporte
    lip_back_y = -0.026        # Pared frontal interior de la ranura
    slot_width = 0.012         # Ancho de la ranura (12 mm, holgura óptima para 8 mm)

    backrest_bottom_y = lip_back_y + slot_width * cos_a
    backrest_bottom_z = slot_bottom_z

    backrest_top_z = 0.065     # Altura máxima del respaldo
    dz_backrest = backrest_top_z - backrest_bottom_z
    backrest_top_y = backrest_bottom_y + dz_backrest / tan_a

    # Polígono 2D del perfil en el plano YZ (sección lateral)
    profile_2d = [
        # (Y, Z)
        (lip_front_y, 0.0),                        # 0: Apoyo frontal en mesa
        (lip_front_y, lip_height - 0.003),         # 1: Frente vertical del labio
        (lip_front_y + 0.003, lip_height),         # 2: Cima biselada del labio
        (lip_back_y, lip_height),                  # 3: Borde superior de la ranura
        (lip_back_y, slot_bottom_z + 0.003),       # 4: Pared interior de la ranura
        (lip_back_y + 0.002, slot_bottom_z),       # 5: Fondo frontal de la ranura
        (backrest_bottom_y, slot_bottom_z),        # 6: Fondo posterior de la ranura
        (backrest_top_y, backrest_top_z),          # 7: Cima del respaldo a 75°
        (backrest_top_y + 0.007, backrest_top_z),  # 8: Canto superior trasero
        (0.048, 0.016),                            # 9: Brazo posterior de soporte
        (0.052, 0.006),                            # 10: Caída trasera
        (0.052, 0.0)                               # 11: Apoyo trasero en mesa
    ]

    half_w = stand_width / 2.0
    left_verts = []
    right_verts = []

    # Extrusión limpia lateral a lo largo del eje X
    for y, z in profile_2d:
        left_verts.append(bm.verts.new((-half_w, y, z)))
        right_verts.append(bm.verts.new((half_w, y, z)))

    bm.verts.ensure_lookup_table()
    n_pts = len(profile_2d)

    # Caras longitudinales de cierre
    for i in range(n_pts):
        next_i = (i + 1) % n_pts
        f = bm.faces.new([
            left_verts[i],
            right_verts[i],
            right_verts[next_i],
            left_verts[next_i]
        ])
        f.material_index = 0
        f.smooth = False

    # Tapas laterales izquierda y derecha (malla cerrada manifold)
    f_left = bm.faces.new(left_verts)
    f_right = bm.faces.new(list(reversed(right_verts)))
    f_left.material_index = 0
    f_right.material_index = 0

    # Mapeo UV uniforme para el soporte
    uv_layer = bm.loops.layers.uv.new("UVMap")
    for face in bm.faces:
        for loop in face.loops:
            co = loop.vert.co
            u = (co.y - lip_front_y) / (0.052 - lip_front_y)
            v = co.z / backrest_top_z
            loop[uv_layer].uv = (u, v)

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()

    mesh.update()

    # Modificador Bevel para suavizar bordes duros
    bev = obj.modifiers.new("Bevel", type='BEVEL')
    bev.width = bevel_width
    bev.segments = 2
    bev.limit_method = 'ANGLE'
    bev.angle_limit = math.radians(35)

    return obj, {
        "angle_deg": angle_deg,
        "slot_bottom_z": slot_bottom_z,
        "backrest_bottom_y": backrest_bottom_y
    }


def dock_phone_in_stand(phone_obj, stand_params, phone_thickness=0.008, phone_height=0.160):
    """
    Posiciona el smartphone de forma precisa dentro de la ranura inclinada a ~75°:
    - Espalda apoyada sobre el respaldo inclinado a 75° (+Y).
    - Pantalla frontal orientada hacia adelante (-Y) para visualización óptima.
    - Despeje milimétrico (0.4 mm) para garantizar estanqueidad y evitar Z-fighting / caras coplanares.
    """
    angle_deg = stand_params["angle_deg"]
    tilt_rad = math.radians(90.0 - angle_deg) # 15° de rotación hacia atrás

    slot_bottom_z = stand_params["slot_bottom_z"]
    backrest_bottom_y = stand_params["backrest_bottom_y"]

    clearance = 0.0004 # 0.4 mm de tolerancia

    cos_t = math.cos(tilt_rad)
    sin_t = math.sin(tilt_rad)
    half_t = phone_thickness / 2.0
    half_h = phone_height / 2.0

    # Punto posterior-inferior del móvil en su marco local: (0, +half_t, -half_h)
    rot_y = half_t * cos_t + (-half_h) * sin_t
    rot_z = -half_t * sin_t + (-half_h) * cos_t

    target_y = backrest_bottom_y + clearance * cos_t
    target_z = slot_bottom_z + clearance * sin_t

    trans_y = target_y - rot_y
    trans_z = target_z - rot_z

    phone_obj.rotation_euler = (-tilt_rad, 0.0, 0.0)
    phone_obj.location = (0.0, trans_y, trans_z)


# =============================================================================
# FASE 4: AUDITORÍA TOPOLÓGICA Y EXPORTACIÓN
# =============================================================================
def audit_mesh_quality(obj):
    """
    Verifica los requisitos técnicos de la malla:
    - Estado Manifold (estanqueidad / watertight).
    - Inexistencia de vértices huérfanos o aristas no-manifold.
    """
    depsgraph = bpy.context.evaluated_depsgraph_get()
    eval_obj = obj.evaluated_get(depsgraph)
    bm = bmesh.new()
    bm.from_mesh(eval_obj.to_mesh())

    non_manifold_edges = [e for e in bm.edges if not e.is_manifold]
    loose_verts = [v for v in bm.verts if len(v.link_edges) == 0]

    report = {
        "name": obj.name,
        "vertices": len(bm.verts),
        "faces": len(bm.faces),
        "non_manifold_edges": len(non_manifold_edges),
        "loose_vertices": len(loose_verts),
        "is_watertight": (len(non_manifold_edges) == 0 and len(loose_verts) == 0)
    }
    bm.free()
    eval_obj.to_mesh_clear()
    return report


def export_models(output_dir, base_name="phone_desk_stand", export_formats=("glb", "obj")):
    """Exporta las mallas completas a formatos estándar .glb / .gltf y .obj."""
    os.makedirs(output_dir, exist_ok=True)
    exported = {}

    if "glb" in export_formats or "all" in export_formats:
        glb_path = os.path.join(output_dir, f"{base_name}.glb")
        bpy.ops.export_scene.gltf(
            filepath=glb_path,
            export_format='GLB',
            export_apply=True,
            export_yup=True
        )
        exported["glb"] = glb_path
        print(f"[Export] GLB generado: {glb_path} ({os.path.getsize(glb_path)} bytes)")

    if "gltf" in export_formats or "all" in export_formats:
        gltf_path = os.path.join(output_dir, f"{base_name}.gltf")
        bpy.ops.export_scene.gltf(
            filepath=gltf_path,
            export_format='GLTF_SEPARATE',
            export_apply=True,
            export_yup=True
        )
        exported["gltf"] = gltf_path
        print(f"[Export] GLTF generado: {gltf_path} ({os.path.getsize(gltf_path)} bytes)")

    if "obj" in export_formats or "all" in export_formats:
        obj_path = os.path.join(output_dir, f"{base_name}.obj")
        if hasattr(bpy.ops.wm, 'obj_export'):
            bpy.ops.wm.obj_export(
                filepath=obj_path,
                export_selected_objects=False,
                apply_modifiers=True,
                export_uv=True,
                export_normals=True,
                export_materials=True
            )
        else:
            bpy.ops.export_scene.obj(
                filepath=obj_path,
                use_mesh_modifiers=True,
                use_uvs=True,
                use_normals=True,
                use_materials=True
            )
        exported["obj"] = obj_path
        print(f"[Export] OBJ generado: {obj_path} ({os.path.getsize(obj_path)} bytes)")

    return exported


def setup_studio_and_render(output_image_path):
    """Configura iluminación de estudio de 3 puntos calibrada y renderiza una vista de confirmación."""
    cam_data = bpy.data.cameras.new("StudioCamera")
    cam_data.lens = 52
    cam_obj = bpy.data.objects.new("StudioCamera", cam_data)
    bpy.context.collection.objects.link(cam_obj)
    bpy.context.scene.camera = cam_obj

    cam_obj.location = (0.24, -0.32, 0.16)
    target = Vector((0.0, -0.01, 0.070))
    direction = target - cam_obj.location
    cam_obj.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()

    # 1. Luz Principal (Key Light)
    key_data = bpy.data.lights.new("KeyLight", type='AREA')
    key_data.energy = 4.0
    key_data.size = 0.25
    key_data.color = (1.0, 0.98, 0.95)
    key_obj = bpy.data.objects.new("KeyLight", key_data)
    key_obj.location = (0.28, -0.22, 0.26)
    key_obj.rotation_euler = (target - key_obj.location).to_track_quat('-Z', 'Y').to_euler()
    bpy.context.collection.objects.link(key_obj)

    # 2. Luz de Relleno (Fill Light)
    fill_data = bpy.data.lights.new("FillLight", type='AREA')
    fill_data.energy = 1.8
    fill_data.size = 0.35
    fill_data.color = (0.85, 0.92, 1.0)
    fill_obj = bpy.data.objects.new("FillLight", fill_data)
    fill_obj.location = (-0.24, -0.20, 0.16)
    fill_obj.rotation_euler = (target - fill_obj.location).to_track_quat('-Z', 'Y').to_euler()
    bpy.context.collection.objects.link(fill_obj)

    # 3. Luz de Contorno (Rim Light)
    rim_data = bpy.data.lights.new("RimLight", type='POINT')
    rim_data.energy = 3.0
    rim_obj = bpy.data.objects.new("RimLight", rim_data)
    rim_obj.location = (0.0, 0.22, 0.20)
    bpy.context.collection.objects.link(rim_obj)

    # Ajustes de render
    bpy.context.scene.render.resolution_x = 960
    bpy.context.scene.render.resolution_y = 720
    bpy.context.scene.render.image_settings.file_format = 'PNG'
    bpy.context.scene.render.filepath = output_image_path

    world = bpy.data.worlds.new("StudioWorld")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg_node = world.node_tree.nodes.get("Background")
    if bg_node:
        bg_node.inputs["Color"].default_value = (0.07, 0.08, 0.09, 1.0)
        bg_node.inputs["Strength"].default_value = 0.5

    bpy.ops.render.render(write_still=True)
    print(f"[Render] Vista previa guardada en: {output_image_path}")


# =============================================================================
# EJECUCIÓN PRINCIPAL
# =============================================================================
def parse_arguments():
    """Parsea argumentos de línea de comandos si se ejecuta con: blender -b -P script.py -- [args]"""
    argv = sys.argv
    if "--" in argv:
        args_to_parse = argv[argv.index("--") + 1:]
    else:
        args_to_parse = []

    parser = argparse.ArgumentParser(
        description="Generador Procedural 3D de Smartphone y Soporte de Escritorio"
    )
    parser.add_argument("--output-dir", default="./output", help="Carpeta de salida para los modelos")
    parser.add_argument("--format", default="all", choices=["glb", "gltf", "obj", "all"],
                        help="Formato de exportación (glb, gltf, obj o all)")
    parser.add_argument("--screen-image", default=None,
                        help="Ruta a textura de imagen para proyectar en la pantalla")
    parser.add_argument("--stand-angle", type=float, default=75.0,
                        help="Ángulo de inclinación del soporte respecto a la horizontal (por defecto: 75°)")
    parser.add_argument("--undocked", action="store_true",
                        help="Si se activa, deja el smartphone vertical junto al soporte en lugar de acoplarlo")
    parser.add_argument("--render", action="store_true",
                        help="Renderiza una vista previa en estudio a formato PNG")

    return parser.parse_args(args_to_parse)


def main():
    args = parse_arguments()
    output_dir = os.path.abspath(args.output_dir)
    os.makedirs(output_dir, exist_ok=True)

    print("=================================================================")
    print(" MODELADO PROCEDURAL 3D: SMARTPHONE Y SOPORTE DE ESCRITORIO (75°)")
    print("=================================================================")
    reset_scene()

    # Fase 3: Materiales PBR
    materials = create_pbr_materials(screen_image_path=args.screen_image)

    # Fase 1 y 2: Construcción geométrica sólida
    phone = build_smartphone(materials=materials)
    stand, stand_params = build_desk_stand(angle_deg=args.stand_angle, materials=materials)

    # Posicionamiento: Acoplar en ranura a 75° o mantener vertical
    if not args.undocked:
        dock_phone_in_stand(phone, stand_params)
    else:
        # Colocar teléfono erguido a un costado
        phone.location = (-0.09, 0.0, 0.08)

    # Auditoría Topológica
    rep_phone = audit_mesh_quality(phone)
    rep_stand = audit_mesh_quality(stand)

    print("\n--- REPORTE DE AUDITORÍA TOPOLÓGICA ---")
    print(f"1. Smartphone:")
    print(f"   - Vértices: {rep_phone['vertices']} | Caras: {rep_phone['faces']}")
    print(f"   - Aristas No-Manifold: {rep_phone['non_manifold_edges']}")
    print(f"   - Sólido Estanco (Watertight): {'SÍ' if rep_phone['is_watertight'] else 'NO'}")
    print(f"2. Soporte de Escritorio:")
    print(f"   - Vértices: {rep_stand['vertices']} | Caras: {rep_stand['faces']}")
    print(f"   - Aristas No-Manifold: {rep_stand['non_manifold_edges']}")
    print(f"   - Sólido Estanco (Watertight): {'SÍ' if rep_stand['is_watertight'] else 'NO'}")

    # Fase 4: Exportación
    formats = [args.format] if args.format != "all" else ["glb", "gltf", "obj"]
    export_models(output_dir, "phone_desk_stand", formats)

    # Render opcional
    if args.render:
        preview_path = os.path.join(output_dir, "phone_desk_stand_preview.png")
        setup_studio_and_render(preview_path)

    print("\n[Éxito] Generación procedural finalizada correctamente.")


if __name__ == "__main__":
    main()
