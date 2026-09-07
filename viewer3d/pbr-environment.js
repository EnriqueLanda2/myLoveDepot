/**
 * PBR Environment Module — Procedural HDRI & Studio Lighting
 * ===========================================================
 * Generates photorealistic environment maps procedurally (zero external downloads)
 * and configures a professional studio lighting rig for product visualization.
 *
 * Features:
 * - Procedural equirectangular HDRI via canvas (gradient sky + soft lights)
 * - PMREMGenerator integration for proper PBR reflections
 * - 4-point studio lighting rig (key, fill, rim, top)
 * - Contact shadow plane for grounding
 * - Optional external HDRI loading (Poly Haven CC0)
 *
 * 100% Open Source — MIT License (Three.js), CC0 (HDRI presets)
 */

import * as THREE from 'three';

// ─── Procedural HDRI Generator ───────────────────────────────────────────────

/**
 * Creates a procedural equirectangular environment map on a canvas.
 * This avoids any HDRI download while producing realistic soft reflections.
 *
 * @param {number} width  — Canvas width (default 1024 for quality/perf balance)
 * @param {number} height — Canvas height (default 512)
 * @param {string} preset — Lighting preset: 'studio' | 'sunset' | 'neutral'
 * @returns {THREE.CanvasTexture}
 */
export function createProceduralHDRI(width = 1024, height = 512, preset = 'studio') {
  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext('2d');

  const presets = {
    studio: {
      skyTop: [18, 22, 32],
      skyMid: [35, 40, 55],
      skyBottom: [55, 58, 68],
      groundColor: [22, 24, 28],
      lights: [
        { x: 0.25, y: 0.35, radius: 0.12, color: [255, 248, 238], intensity: 0.9 },  // Key
        { x: 0.75, y: 0.40, radius: 0.18, color: [220, 232, 255], intensity: 0.5 },  // Fill
        { x: 0.50, y: 0.15, radius: 0.08, color: [255, 255, 255], intensity: 0.7 },  // Rim/top
        { x: 0.10, y: 0.55, radius: 0.25, color: [200, 210, 225], intensity: 0.2 },  // Ambient bounce
      ],
    },
    sunset: {
      skyTop: [15, 12, 28],
      skyMid: [120, 55, 30],
      skyBottom: [200, 120, 60],
      groundColor: [30, 22, 18],
      lights: [
        { x: 0.20, y: 0.50, radius: 0.15, color: [255, 180, 100], intensity: 1.0 },
        { x: 0.80, y: 0.35, radius: 0.20, color: [180, 200, 255], intensity: 0.3 },
        { x: 0.50, y: 0.10, radius: 0.10, color: [255, 220, 180], intensity: 0.4 },
      ],
    },
    neutral: {
      skyTop: [42, 44, 50],
      skyMid: [65, 68, 75],
      skyBottom: [80, 82, 88],
      groundColor: [35, 36, 40],
      lights: [
        { x: 0.30, y: 0.30, radius: 0.20, color: [255, 255, 255], intensity: 0.6 },
        { x: 0.70, y: 0.40, radius: 0.22, color: [240, 245, 255], intensity: 0.4 },
        { x: 0.50, y: 0.20, radius: 0.15, color: [255, 252, 248], intensity: 0.3 },
      ],
    },
  };

  const p = presets[preset] || presets.studio;

  // 1. Sky gradient (vertical)
  const skyGrad = ctx.createLinearGradient(0, 0, 0, height * 0.55);
  skyGrad.addColorStop(0.0, `rgb(${p.skyTop.join(',')})`);
  skyGrad.addColorStop(0.5, `rgb(${p.skyMid.join(',')})`);
  skyGrad.addColorStop(1.0, `rgb(${p.skyBottom.join(',')})`);
  ctx.fillStyle = skyGrad;
  ctx.fillRect(0, 0, width, height * 0.55);

  // 2. Ground gradient
  const groundGrad = ctx.createLinearGradient(0, height * 0.55, 0, height);
  groundGrad.addColorStop(0.0, `rgb(${p.skyBottom.join(',')})`);
  groundGrad.addColorStop(0.3, `rgb(${p.groundColor.join(',')})`);
  groundGrad.addColorStop(1.0, `rgb(${p.groundColor.map(c => Math.max(0, c - 10)).join(',')})`);
  ctx.fillStyle = groundGrad;
  ctx.fillRect(0, height * 0.55, width, height * 0.45);

  // 3. Soft light sources (radial gradients simulating area lights)
  for (const light of p.lights) {
    const cx = light.x * width;
    const cy = light.y * height;
    const r = light.radius * Math.max(width, height);

    const grad = ctx.createRadialGradient(cx, cy, 0, cx, cy, r);
    const [lr, lg, lb] = light.color;
    const intensity = light.intensity;
    grad.addColorStop(0.0, `rgba(${lr}, ${lg}, ${lb}, ${intensity})`);
    grad.addColorStop(0.3, `rgba(${lr}, ${lg}, ${lb}, ${intensity * 0.5})`);
    grad.addColorStop(0.7, `rgba(${lr}, ${lg}, ${lb}, ${intensity * 0.1})`);
    grad.addColorStop(1.0, `rgba(${lr}, ${lg}, ${lb}, 0)`);

    ctx.globalCompositeOperation = 'lighter';
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, width, height);
  }

  ctx.globalCompositeOperation = 'source-over';

  // 4. Subtle noise for realism (breaks banding)
  const imageData = ctx.getImageData(0, 0, width, height);
  const data = imageData.data;
  for (let i = 0; i < data.length; i += 4) {
    const noise = (Math.random() - 0.5) * 4;
    data[i] = Math.max(0, Math.min(255, data[i] + noise));
    data[i + 1] = Math.max(0, Math.min(255, data[i + 1] + noise));
    data[i + 2] = Math.max(0, Math.min(255, data[i + 2] + noise));
  }
  ctx.putImageData(imageData, 0, 0);

  const texture = new THREE.CanvasTexture(canvas);
  texture.mapping = THREE.EquirectangularReflectionMapping;
  texture.colorSpace = THREE.SRGBColorSpace;

  return texture;
}

// ─── PMREM Environment Map from Procedural HDRI ─────────────────────────────

/**
 * Generates a pre-filtered environment map suitable for PBR reflections.
 * Uses PMREMGenerator to convert the procedural HDRI into mip levels
 * that MeshStandardMaterial and MeshPhysicalMaterial use for specular IBL.
 *
 * @param {THREE.WebGLRenderer} renderer
 * @param {string} preset — 'studio' | 'sunset' | 'neutral'
 * @param {number} resolution — HDRI canvas width (512 for mobile, 1024 for desktop)
 * @returns {{ envMap: THREE.Texture, dispose: Function }}
 */
export function createPBREnvironment(renderer, preset = 'studio', resolution = 1024) {
  const pmremGenerator = new THREE.PMREMGenerator(renderer);
  pmremGenerator.compileEquirectangularShader();

  const hdriTexture = createProceduralHDRI(resolution, resolution / 2, preset);
  const envMap = pmremGenerator.fromEquirectangular(hdriTexture).texture;

  hdriTexture.dispose();
  pmremGenerator.dispose();

  return {
    envMap,
    dispose() {
      envMap.dispose();
    },
  };
}

// ─── Studio Lighting Rig ─────────────────────────────────────────────────────

/**
 * Creates a professional 4-point studio lighting rig for product visualization.
 *
 * @param {THREE.Scene} scene
 * @param {object} options
 * @param {number} options.scale           — Scene scale factor (default 1.0)
 * @param {string} options.tier            — Quality tier: 'high' | 'medium' | 'low'
 * @param {boolean} options.enableShadows  — Whether to enable shadow casting
 * @returns {{ lights: THREE.Light[], dispose: Function }}
 */
export function createStudioLighting(scene, options = {}) {
  const {
    scale = 1.0,
    tier = 'high',
    enableShadows = true,
  } = options;

  const lights = [];

  // Shadow map resolution by tier
  const shadowRes = tier === 'high' ? 2048 : tier === 'medium' ? 1024 : 512;

  // ── Key Light (main directional — warm) ────────────────────────────────────
  const keyLight = new THREE.DirectionalLight(0xfff4e6, 2.8);
  keyLight.position.set(2.5 * scale, 3.5 * scale, -2.0 * scale);
  keyLight.castShadow = enableShadows;
  if (enableShadows) {
    keyLight.shadow.mapSize.width = shadowRes;
    keyLight.shadow.mapSize.height = shadowRes;
    keyLight.shadow.camera.near = 0.1 * scale;
    keyLight.shadow.camera.far = 15 * scale;
    keyLight.shadow.camera.left = -3 * scale;
    keyLight.shadow.camera.right = 3 * scale;
    keyLight.shadow.camera.top = 3 * scale;
    keyLight.shadow.camera.bottom = -3 * scale;
    keyLight.shadow.bias = -0.0003;
    keyLight.shadow.normalBias = 0.02;
    keyLight.shadow.radius = tier === 'high' ? 3 : 1;
  }
  scene.add(keyLight);
  lights.push(keyLight);

  // ── Fill Light (soft, cool, opposite side) ─────────────────────────────────
  const fillLight = new THREE.DirectionalLight(0xd4e4ff, 1.2);
  fillLight.position.set(-2.2 * scale, 2.0 * scale, -1.5 * scale);
  fillLight.castShadow = false; // Fill lights don't cast shadows
  scene.add(fillLight);
  lights.push(fillLight);

  // ── Rim/Back Light (strong, defines edges) ─────────────────────────────────
  const rimLight = new THREE.DirectionalLight(0xffffff, 1.8);
  rimLight.position.set(0, 2.5 * scale, 3.0 * scale);
  rimLight.castShadow = false;
  scene.add(rimLight);
  lights.push(rimLight);

  // ── Top Light (ambient fill from above) ────────────────────────────────────
  const topLight = new THREE.DirectionalLight(0xfff8f0, 0.8);
  topLight.position.set(0, 4.0 * scale, 0);
  topLight.castShadow = false;
  scene.add(topLight);
  lights.push(topLight);

  // ── Hemisphere Light (ground bounce) ───────────────────────────────────────
  const hemiLight = new THREE.HemisphereLight(0xc8d4e8, 0x2a2a30, 0.5);
  scene.add(hemiLight);
  lights.push(hemiLight);

  return {
    lights,
    keyLight,
    dispose() {
      for (const light of lights) {
        if (light.shadow && light.shadow.map) {
          light.shadow.map.dispose();
        }
        scene.remove(light);
        light.dispose();
      }
    },
  };
}

// ─── Contact Shadow Plane ────────────────────────────────────────────────────

/**
 * Creates a shadow-catching floor plane that grounds the model visually.
 *
 * @param {THREE.Scene} scene
 * @param {number} size  — Plane dimension
 * @param {number} yPos  — Vertical position (bottom of model)
 * @returns {{ mesh: THREE.Mesh, dispose: Function }}
 */
export function createContactShadow(scene, size = 8, yPos = 0) {
  const geometry = new THREE.PlaneGeometry(size, size);
  const material = new THREE.ShadowMaterial({
    opacity: 0.35,
    color: 0x000000,
  });

  const mesh = new THREE.Mesh(geometry, material);
  mesh.rotation.x = -Math.PI / 2;
  mesh.position.y = yPos;
  mesh.receiveShadow = true;
  mesh.name = 'ContactShadow';
  scene.add(mesh);

  return {
    mesh,
    setPosition(y) {
      mesh.position.y = y;
    },
    dispose() {
      scene.remove(mesh);
      geometry.dispose();
      material.dispose();
    },
  };
}

// ─── External HDRI Loader (optional — Poly Haven CC0) ───────────────────────

/**
 * Loads an external .hdr file and creates a PBR environment map.
 * Falls back to procedural HDRI on failure.
 *
 * @param {THREE.WebGLRenderer} renderer
 * @param {string} url — URL to .hdr file
 * @returns {Promise<{ envMap: THREE.Texture, dispose: Function }>}
 */
export async function loadExternalHDRI(renderer, url) {
  try {
    const { RGBELoader } = await import('three/addons/loaders/RGBELoader.js');
    const loader = new RGBELoader();

    return new Promise((resolve, reject) => {
      loader.load(
        url,
        (texture) => {
          const pmremGenerator = new THREE.PMREMGenerator(renderer);
          const envMap = pmremGenerator.fromEquirectangular(texture).texture;
          texture.dispose();
          pmremGenerator.dispose();
          resolve({
            envMap,
            dispose() { envMap.dispose(); },
          });
        },
        undefined,
        (error) => {
          console.warn('[PBR-Env] HDRI load failed, using procedural fallback:', error);
          resolve(createPBREnvironment(renderer));
        },
      );
    });
  } catch {
    console.warn('[PBR-Env] RGBELoader unavailable, using procedural HDRI');
    return createPBREnvironment(renderer);
  }
}
