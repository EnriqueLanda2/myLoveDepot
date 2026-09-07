"""Quick test to verify the full 3D pipeline works end-to-end."""

import sys
import time
from pathlib import Path

# Add model3d to path
sys.path.insert(0, str(Path(__file__).resolve().parent / 'backend' / 'tools' / 'model3d'))

import numpy as np
from PIL import Image, ImageDraw

def create_test_mug_image(path: Path, size=(512, 512)):
    """Creates a synthetic mug-like image on a light background."""
    img = Image.new('RGB', size, (240, 235, 230))
    draw = ImageDraw.Draw(img)
    
    cx, cy = size[0] // 2, size[1] // 2
    # Mug body (dark brown ellipse)
    body_left = cx - 100
    body_right = cx + 100
    body_top = cy - 120
    body_bottom = cy + 100
    draw.ellipse([body_left, body_top, body_right, body_bottom], fill=(80, 40, 30))
    
    # Make it more rectangular (like a mug)
    draw.rectangle([body_left, cy - 80, body_right, body_bottom - 20], fill=(80, 40, 30))
    
    # Mug handle (arc on the right)
    handle_left = body_right - 20
    handle_top = cy - 50
    handle_right = body_right + 50
    handle_bottom = cy + 50
    draw.arc([handle_left, handle_top, handle_right, handle_bottom], start=-90, end=90, fill=(80, 40, 30), width=15)
    
    # Lighter top rim
    draw.ellipse([body_left + 5, body_top - 5, body_right - 5, body_top + 30], fill=(200, 190, 180))
    
    img.save(path)
    return img


def create_test_box_image(path: Path, size=(512, 512)):
    """Creates a synthetic box/cube image on a light background."""
    img = Image.new('RGB', size, (240, 235, 230))
    draw = ImageDraw.Draw(img)
    
    cx, cy = size[0] // 2, size[1] // 2
    # Box
    draw.rectangle([cx - 110, cy - 100, cx + 110, cy + 100], fill=(60, 80, 120))
    # Highlight band
    draw.rectangle([cx - 110, cy - 30, cx + 110, cy + 10], fill=(80, 100, 150))
    
    img.save(path)
    return img


def run_test(test_name, create_fn, view_indices=[0]):
    """Runs the pipeline on a test image and checks output."""
    test_dir = Path(__file__).resolve().parent / 'output_model_test' / test_name
    test_dir.mkdir(parents=True, exist_ok=True)
    
    # Create test images
    for idx in view_indices:
        img_path = test_dir / f'view-{idx}.png'
        create_fn(img_path)
    
    output_path = test_dir / 'output.glb'
    
    print(f"\n{'='*50}")
    print(f"TEST: {test_name}")
    print(f"{'='*50}")
    
    from build_model import build
    
    start = time.time()
    try:
        report = build(test_dir, output_path, resolution=96, smoothing=3)
        elapsed = time.time() - start
        
        print(f"  Success in {elapsed:.1f}s")
        print(f"  Views used: {report['views']}")
        print(f"  Grid: {report['grid']}")
        print(f"  Extents: {report['extents']}")
        print(f"  Triangles: {report['triangles']}")
        print(f"  File size: {report['bytes'] / 1024:.1f} KB")
        
        if report['triangles'] < 100:
            print(f"  WARNING: Very few triangles ({report['triangles']})")
        if report['bytes'] < 1000:
            print(f"  WARNING: File very small ({report['bytes']} bytes)")
            
        return True
    except Exception as e:
        elapsed = time.time() - start
        print(f"  FAILED in {elapsed:.1f}s: {e}")
        import traceback
        traceback.print_exc()
        return False


if __name__ == '__main__':
    results = []
    
    results.append(('Mug (front only)', run_test('mug_front', create_test_mug_image, [0])))
    results.append(('Box (front only)', run_test('box_front', create_test_box_image, [0])))
    
    print(f"\n{'='*50}")
    print("RESULTS SUMMARY")
    print(f"{'='*50}")
    for name, passed in results:
        status = "PASS" if passed else "FAIL"
        print(f"  {status}: {name}")
    
    all_passed = all(r[1] for r in results)
    print(f"\n{'All tests passed!' if all_passed else 'Some tests FAILED!'}")
    sys.exit(0 if all_passed else 1)
