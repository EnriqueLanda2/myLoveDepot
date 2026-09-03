import sys
import argparse
import bpy
import math
from mathutils import Vector

def setup_scene(input_file, output_file):
    # Clear all existing objects
    bpy.ops.wm.read_factory_settings(use_empty=True)

    # Import GLB
    bpy.ops.import_scene.gltf(filepath=input_file)

    # Get imported objects
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
    if not meshes:
        print("No meshes found in GLB")
        sys.exit(1)

    # Calculate bounding box
    bbox_corners = []
    for obj in meshes:
        for corner in obj.bound_box:
            bbox_corners.append(obj.matrix_world @ Vector(corner))

    min_corner = Vector((min([v.x for v in bbox_corners]),
                         min([v.y for v in bbox_corners]),
                         min([v.z for v in bbox_corners])))
    max_corner = Vector((max([v.x for v in bbox_corners]),
                         max([v.y for v in bbox_corners]),
                         max([v.z for v in bbox_corners])))

    center = (min_corner + max_corner) / 2.0
    dimensions = max_corner - min_corner
    max_dim = max(dimensions.x, dimensions.y, dimensions.z)

    # Setup Camera
    cam_data = bpy.data.cameras.new("Camera")
    cam_obj = bpy.data.objects.new("Camera", cam_data)
    bpy.context.collection.objects.link(cam_obj)
    bpy.context.scene.camera = cam_obj

    # Position camera to frame the object
    cam_distance = max_dim * 2.5
    cam_obj.location = center + Vector((cam_distance * 0.7, -cam_distance * 0.7, cam_distance * 0.5))
    
    # Point camera at center
    direction = center - cam_obj.location
    rot_quat = direction.to_track_quat('-Z', 'Y')
    cam_obj.rotation_euler = rot_quat.to_euler()

    # Setup Lighting (3-point)
    # Key light
    key_light_data = bpy.data.lights.new(name="KeyLight", type='AREA')
    key_light_data.energy = 500 * (max_dim ** 2)
    key_light_data.size = max_dim * 2
    key_light_obj = bpy.data.objects.new(name="KeyLight", object_data=key_light_data)
    bpy.context.collection.objects.link(key_light_obj)
    key_light_obj.location = center + Vector((-max_dim * 2, -max_dim * 2, max_dim * 2))
    key_light_obj.rotation_euler = (center - key_light_obj.location).to_track_quat('-Z', 'Y').to_euler()

    # Fill light
    fill_light_data = bpy.data.lights.new(name="FillLight", type='AREA')
    fill_light_data.energy = 200 * (max_dim ** 2)
    fill_light_data.size = max_dim * 3
    fill_light_obj = bpy.data.objects.new(name="FillLight", object_data=fill_light_data)
    bpy.context.collection.objects.link(fill_light_obj)
    fill_light_obj.location = center + Vector((max_dim * 2, -max_dim, max_dim))
    fill_light_obj.rotation_euler = (center - fill_light_obj.location).to_track_quat('-Z', 'Y').to_euler()

    # Rim light
    rim_light_data = bpy.data.lights.new(name="RimLight", type='AREA')
    rim_light_data.energy = 800 * (max_dim ** 2)
    rim_light_data.size = max_dim * 2
    rim_light_obj = bpy.data.objects.new(name="RimLight", object_data=rim_light_data)
    bpy.context.collection.objects.link(rim_light_obj)
    rim_light_obj.location = center + Vector((0, max_dim * 3, max_dim))
    rim_light_obj.rotation_euler = (center - rim_light_obj.location).to_track_quat('-Z', 'Y').to_euler()

    # Create a shadow catcher floor
    floor_data = bpy.data.meshes.new("Floor")
    floor_obj = bpy.data.objects.new("Floor", floor_data)
    bpy.context.collection.objects.link(floor_obj)
    bpy.ops.mesh.primitive_plane_add(size=max_dim * 10, location=(center.x, center.y, min_corner.z))
    floor_obj = bpy.context.active_object
    # Eevee shadow catcher requires specific material setup or use Cycles
    
    # We will use Eevee for speed but set a white background
    bpy.context.scene.render.engine = 'BLENDER_EEVEE_NEXT' if hasattr(bpy.types, 'EEVEE_NEXT_light') else 'BLENDER_EEVEE'
    bpy.context.scene.render.resolution_x = 1080
    bpy.context.scene.render.resolution_y = 1080
    bpy.context.scene.render.film_transparent = True
    
    # World background
    world = bpy.context.scene.world
    if world is None:
        world = bpy.data.worlds.new("World")
        bpy.context.scene.world = world
    world.use_nodes = True
    bg_node = world.node_tree.nodes.get("Background")
    if bg_node:
        bg_node.inputs[0].default_value = (1.0, 1.0, 1.0, 1.0) # White

    # Render settings
    bpy.context.scene.render.filepath = output_file
    bpy.ops.render.render(write_still=True)

def main():
    argv = sys.argv
    if "--" not in argv:
        print("Use -- to pass arguments to the script: blender -b -P render_studio.py -- --input in.glb --output out.png")
        sys.exit(1)
        
    argv = argv[argv.index("--") + 1:]
    
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', required=True, help="Input GLB file")
    parser.add_argument('--output', required=True, help="Output PNG file")
    args = parser.parse_args(argv)

    setup_scene(args.input, args.output)

if __name__ == "__main__":
    main()
