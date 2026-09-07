/**
 * Viewer3D — Photorealistic 3D Product Viewer
 * ==============================================
 * Main module: Three.js scene setup, GLB loading, PBR materials,
 * post-processing pipeline, and UI integration.
 *
 * Stack: Three.js r170+ (ES Modules) | glTF 2.0 | PBR metallic-roughness
 * License: MIT
 */

import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { DRACOLoader } from 'three/addons/loaders/DRACOLoader.js';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { ShaderPass } from 'three/addons/postprocessing/ShaderPass.js';
import { FXAAShader } from 'three/addons/shaders/FXAAShader.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';

import { createPBREnvironment, createStudioLighting, createContactShadow } from './pbr-environment.js';
import { PerformanceManager, RenderOnDemand } from './performance-manager.js';

// ─── Vignette Shader (custom, lightweight) ───────────────────────────────────
const VignetteShader = {
  name: 'VignetteShader',
  uniforms: {
    tDiffuse: { value: null },
    offset: { value: 1.0 },
    darkness: { value: 1.2 },
  },
  vertexShader: /* glsl */ `
    varying vec2 vUv;
    void main() {
      vUv = uv;
      gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
    }
  `,
  fragmentShader: /* glsl */ `
    uniform sampler2D tDiffuse;
    uniform float offset;
    uniform float darkness;
    varying vec2 vUv;
    void main() {
      vec4 texel = texture2D(tDiffuse, vUv);
      vec2 uv = (vUv - vec2(0.5)) * vec2(offset);
      float vignette = 1.0 - dot(uv, uv);
      texel.rgb *= smoothstep(0.0, 1.0, pow(vignette, darkness));
      gl_FragColor = texel;
    }
  `,
};

// ─── Main Viewer Class ───────────────────────────────────────────────────────

export class PhotorealisticViewer {
  /**
   * @param {HTMLElement} container — DOM element to mount the canvas
   * @param {object} options
   * @param {string} options.modelUrl       — URL to the GLB model
   * @param {string} options.environmentPreset — 'studio' | 'sunset' | 'neutral'
   * @param {boolean} options.autoRotate    — Enable turntable animation
   * @param {string} options.forceTier      — Force quality tier: 'high' | 'medium' | 'low' | 'auto'
   */
  constructor(container, options = {}) {
    this.container = container;
    this.options = {
      modelUrl: options.modelUrl || '',
      environmentPreset: options.environmentPreset || 'studio',
      autoRotate: options.autoRotate !== false,
      forceTier: options.forceTier || 'auto',
    };

    // State
    this._model = null;
    this._modelInfo = { triangles: 0, vertices: 0, materials: 0, meshes: 0 };
    this._animationId = null;
    this._disposed = false;
    this._clock = new THREE.Clock();

    // Setup
    this._initRenderer();
    this._initScene();
    this._initCamera();
    this._initControls();
    this._initPerformance();
    this._initEnvironment();
    this._initLighting();
    this._initPostProcessing();
    this._initEventListeners();

    // Start render loop
    this._animate();
  }

  // ─── Initialization ──────────────────────────────────────────────────────

  _initRenderer() {
    this.renderer = new THREE.WebGLRenderer({
      antialias: true,
      alpha: false,
      powerPreference: 'high-performance',
      stencil: false,
    });

    this.renderer.setSize(window.innerWidth, window.innerHeight);
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.0;
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;

    this.container.appendChild(this.renderer.domElement);
  }

  _initScene() {
    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color(0x0b0d12);
    // A subtle fog adds depth
    this.scene.fog = new THREE.FogExp2(0x0b0d12, 0.08);
  }

  _initCamera() {
    const aspect = window.innerWidth / window.innerHeight;
    this.camera = new THREE.PerspectiveCamera(40, aspect, 0.01, 100);
    this.camera.position.set(2.5, 1.8, 3.0);
  }

  _initControls() {
    this.controls = new OrbitControls(this.camera, this.renderer.domElement);
    this.controls.enableDamping = true;
    this.controls.dampingFactor = 0.06;
    this.controls.rotateSpeed = 0.8;
    this.controls.zoomSpeed = 1.0;
    this.controls.panSpeed = 0.6;
    this.controls.minDistance = 0.5;
    this.controls.maxDistance = 20;
    this.controls.maxPolarAngle = Math.PI * 0.85;
    this.controls.target.set(0, 0.3, 0);
    this.controls.autoRotate = this.options.autoRotate;
    this.controls.autoRotateSpeed = 1.5;

    // Render on demand when controls change
    this.controls.addEventListener('change', () => {
      this._renderOnDemand.invalidate();
    });
  }

  _initPerformance() {
    this.perfManager = new PerformanceManager(this.renderer, {
      autoAdjust: this.options.forceTier === 'auto',
    });

    if (this.options.forceTier !== 'auto') {
      this.perfManager.setTier(this.options.forceTier);
    }

    this._renderOnDemand = new RenderOnDemand();
    if (this.options.autoRotate) {
      this._renderOnDemand.startAnimation();
    }

    // Listen for tier changes to rebuild post-processing
    this.perfManager.onChange((tier, settings) => {
      this._rebuildPostProcessing();
      this._updateUI();
    });
  }

  _initEnvironment() {
    const resolution = this.perfManager.settings.envMapResolution;
    const { envMap, dispose } = createPBREnvironment(
      this.renderer,
      this.options.environmentPreset,
      resolution,
    );

    this._envMapDispose = dispose;
    this.scene.environment = envMap;
    // Don't set scene.background = envMap — we keep the dark solid background
  }

  _initLighting() {
    this._lighting = createStudioLighting(this.scene, {
      scale: 1.0,
      tier: this.perfManager.currentTier,
      enableShadows: this.perfManager.settings.enableShadows,
    });

    this._contactShadow = createContactShadow(this.scene, 12, 0);
  }

  _initPostProcessing() {
    const { settings } = this.perfManager;
    const size = this.renderer.getSize(new THREE.Vector2());

    this.composer = new EffectComposer(this.renderer);

    // 1. Scene render
    const renderPass = new RenderPass(this.scene, this.camera);
    this.composer.addPass(renderPass);

    // 2. Bloom (subtle, only on high/medium)
    if (settings.enableBloom) {
      this._bloomPass = new UnrealBloomPass(
        new THREE.Vector2(size.x, size.y),
        0.15,   // strength (subtle)
        0.8,    // radius
        0.85,   // threshold
      );
      this.composer.addPass(this._bloomPass);
    }

    // 3. FXAA
    if (settings.enableFXAA) {
      this._fxaaPass = new ShaderPass(FXAAShader);
      const pixelRatio = this.renderer.getPixelRatio();
      this._fxaaPass.material.uniforms['resolution'].value.x = 1 / (size.x * pixelRatio);
      this._fxaaPass.material.uniforms['resolution'].value.y = 1 / (size.y * pixelRatio);
      this.composer.addPass(this._fxaaPass);
    }

    // 4. Vignette (atmospheric depth)
    if (settings.enableVignette) {
      this._vignettePass = new ShaderPass(VignetteShader);
      this._vignettePass.uniforms['offset'].value = 1.0;
      this._vignettePass.uniforms['darkness'].value = 1.3;
      this.composer.addPass(this._vignettePass);
    }

    // 5. Output pass (color space conversion)
    this.composer.addPass(new OutputPass());
  }

  _rebuildPostProcessing() {
    // Dispose existing composer
    if (this.composer) {
      this.composer.passes.forEach(p => { if (p.dispose) p.dispose(); });
    }
    this._initPostProcessing();
  }

  // ─── Model Loading ────────────────────────────────────────────────────────

  /**
   * Load a GLB/GLTF model from URL.
   * @param {string} url
   * @param {Function} onProgress — Progress callback(0-100)
   * @returns {Promise<THREE.Group>}
   */
  async loadModel(url, onProgress = () => {}) {
    return new Promise((resolve, reject) => {
      const loader = new GLTFLoader();

      // Configure Draco decoder (Google CDN, Apache 2.0)
      const dracoLoader = new DRACOLoader();
      dracoLoader.setDecoderPath('https://www.gstatic.com/draco/versioned/decoders/1.5.7/');
      dracoLoader.setDecoderConfig({ type: 'js' }); // JS decoder for max compatibility
      loader.setDRACOLoader(dracoLoader);

      loader.load(
        url,
        (gltf) => {
          // Remove previous model
          if (this._model) {
            this.scene.remove(this._model);
            this._disposeModel(this._model);
          }

          const model = gltf.scene;
          this._model = model;

          // ── Center and scale model to fit the scene ──────────────────────
          const box = new THREE.Box3().setFromObject(model);
          const center = box.getCenter(new THREE.Vector3());
          const size = box.getSize(new THREE.Vector3());
          const maxDim = Math.max(size.x, size.y, size.z);

          // Normalize to ~2 units
          const scale = 2.0 / maxDim;
          model.scale.setScalar(scale);

          // Center horizontally, place on ground
          model.position.sub(center.multiplyScalar(scale));
          const newBox = new THREE.Box3().setFromObject(model);
          model.position.y -= newBox.min.y; // Ground the model

          // ── Enhance materials for PBR ────────────────────────────────────
          this._enhanceMaterials(model);

          // ── Enable shadows on all meshes ─────────────────────────────────
          model.traverse((child) => {
            if (child.isMesh) {
              child.castShadow = true;
              child.receiveShadow = true;
            }
          });

          // ── Collect model info ───────────────────────────────────────────
          this._collectModelInfo(model);

          // ── Update contact shadow position ──────────────────────────────
          this._contactShadow.setPosition(0);

          // ── Frame camera on model ────────────────────────────────────────
          this._frameModel(model);

          this.scene.add(model);
          this._renderOnDemand.invalidate();

          dracoLoader.dispose();
          resolve(model);
        },
        (progress) => {
          if (progress.total > 0) {
            onProgress(Math.round((progress.loaded / progress.total) * 100));
          }
        },
        (error) => {
          dracoLoader.dispose();
          reject(error);
        },
      );
    });
  }

  /**
   * Upgrade imported materials to MeshPhysicalMaterial for premium PBR.
   * @param {THREE.Object3D} model
   */
  _enhanceMaterials(model) {
    const tier = this.perfManager.currentTier;

    model.traverse((child) => {
      if (!child.isMesh || !child.material) return;

      const mats = Array.isArray(child.material) ? child.material : [child.material];

      for (let i = 0; i < mats.length; i++) {
        const mat = mats[i];

        // On high tier, upgrade to MeshPhysicalMaterial for clearcoat etc.
        if (tier === 'high' && mat.isMeshStandardMaterial && !mat.isMeshPhysicalMaterial) {
          const physical = new THREE.MeshPhysicalMaterial();

          // Copy all standard properties
          physical.map = mat.map;
          physical.normalMap = mat.normalMap;
          physical.roughnessMap = mat.roughnessMap;
          physical.metalnessMap = mat.metalnessMap;
          physical.aoMap = mat.aoMap;
          physical.emissiveMap = mat.emissiveMap;
          physical.color.copy(mat.color);
          physical.roughness = mat.roughness;
          physical.metalness = mat.metalness;
          physical.emissive.copy(mat.emissive);
          physical.emissiveIntensity = mat.emissiveIntensity;
          physical.side = mat.side;
          physical.transparent = mat.transparent;
          physical.opacity = mat.opacity;
          physical.alphaMap = mat.alphaMap;
          physical.name = mat.name;

          // Add physical properties for photorealism
          physical.clearcoat = 0.05;
          physical.clearcoatRoughness = 0.3;
          physical.envMapIntensity = 1.2;

          if (Array.isArray(child.material)) {
            child.material[i] = physical;
          } else {
            child.material = physical;
          }

          mat.dispose();
        }

        // Ensure environment map is applied
        const currentMat = Array.isArray(child.material) ? child.material[i] : child.material;
        if (currentMat.envMap === null && this.scene.environment) {
          currentMat.envMapIntensity = tier === 'high' ? 1.2 : 0.8;
          currentMat.needsUpdate = true;
        }
      }
    });
  }

  /**
   * Count model statistics.
   * @param {THREE.Object3D} model
   */
  _collectModelInfo(model) {
    let triangles = 0;
    let vertices = 0;
    let materials = new Set();
    let meshes = 0;

    model.traverse((child) => {
      if (child.isMesh) {
        meshes++;
        const geo = child.geometry;
        if (geo.index) {
          triangles += geo.index.count / 3;
        } else if (geo.attributes.position) {
          triangles += geo.attributes.position.count / 3;
        }
        if (geo.attributes.position) {
          vertices += geo.attributes.position.count;
        }
        const mats = Array.isArray(child.material) ? child.material : [child.material];
        mats.forEach(m => materials.add(m.uuid));
      }
    });

    this._modelInfo = {
      triangles: Math.round(triangles),
      vertices,
      materials: materials.size,
      meshes,
    };
  }

  /**
   * Position camera to frame the loaded model nicely.
   * @param {THREE.Object3D} model
   */
  _frameModel(model) {
    const box = new THREE.Box3().setFromObject(model);
    const center = box.getCenter(new THREE.Vector3());
    const size = box.getSize(new THREE.Vector3());
    const maxDim = Math.max(size.x, size.y, size.z);

    const fov = this.camera.fov * (Math.PI / 180);
    let cameraZ = (maxDim / 2) / Math.tan(fov / 2);
    cameraZ *= 1.8; // Add some padding

    this.camera.position.set(
      center.x + cameraZ * 0.6,
      center.y + cameraZ * 0.35,
      center.z + cameraZ * 0.7,
    );

    this.controls.target.copy(center);
    this.controls.update();
  }

  // ─── Render Loop ───────────────────────────────────────────────────────────

  _animate() {
    if (this._disposed) return;
    this._animationId = requestAnimationFrame(() => this._animate());

    this.perfManager.tick();
    this.controls.update();

    // Render only when needed (or always during auto-rotate)
    if (this._renderOnDemand.shouldRender() || this.controls.autoRotate) {
      if (this.composer && this.composer.passes.length > 1) {
        this.composer.render();
      } else {
        this.renderer.render(this.scene, this.camera);
      }
    }
  }

  // ─── Public API ────────────────────────────────────────────────────────────

  /** Resize to fit container */
  resize() {
    const w = window.innerWidth;
    const h = window.innerHeight;

    this.camera.aspect = w / h;
    this.camera.updateProjectionMatrix();

    this.renderer.setSize(w, h);

    if (this.composer) {
      this.composer.setSize(w, h);
    }

    if (this._fxaaPass) {
      const pixelRatio = this.renderer.getPixelRatio();
      this._fxaaPass.material.uniforms['resolution'].value.set(
        1 / (w * pixelRatio),
        1 / (h * pixelRatio),
      );
    }

    this._renderOnDemand.invalidate();
  }

  /** Get current model info */
  get modelInfo() {
    return { ...this._modelInfo };
  }

  /** Get performance diagnostics */
  get diagnostics() {
    return this.perfManager.getDiagnostics();
  }

  /** Set quality tier manually */
  setQuality(tier) {
    this.perfManager.setTier(tier);
    this._renderOnDemand.invalidate();
  }

  /** Set environment preset */
  setEnvironment(preset) {
    if (this._envMapDispose) this._envMapDispose();

    const resolution = this.perfManager.settings.envMapResolution;
    const { envMap, dispose } = createPBREnvironment(this.renderer, preset, resolution);
    this._envMapDispose = dispose;
    this.scene.environment = envMap;
    this._renderOnDemand.invalidate();
  }

  /** Toggle auto-rotate */
  setAutoRotate(enabled) {
    this.controls.autoRotate = enabled;
    if (enabled) {
      this._renderOnDemand.startAnimation();
    } else {
      this._renderOnDemand.stopAnimation();
    }
  }

  /** Toggle wireframe mode */
  setWireframe(enabled) {
    if (this._model) {
      this._model.traverse((child) => {
        if (child.isMesh) {
          const mats = Array.isArray(child.material) ? child.material : [child.material];
          mats.forEach(m => { m.wireframe = enabled; });
        }
      });
      this._renderOnDemand.invalidate();
    }
  }

  /** Set renderer exposure */
  setExposure(value) {
    this.renderer.toneMappingExposure = value;
    this._renderOnDemand.invalidate();
  }

  /** Capture a screenshot */
  captureScreenshot(filename = 'render_3d.png') {
    // Force a render
    if (this.composer && this.composer.passes.length > 1) {
      this.composer.render();
    } else {
      this.renderer.render(this.scene, this.camera);
    }

    const dataUrl = this.renderer.domElement.toDataURL('image/png');
    const link = document.createElement('a');
    link.download = filename;
    link.href = dataUrl;
    link.click();

    return dataUrl;
  }

  /** Reset camera to default position */
  resetCamera() {
    if (this._model) {
      this._frameModel(this._model);
    }
    this._renderOnDemand.invalidate();
  }

  /** Dispose all resources */
  dispose() {
    this._disposed = true;
    if (this._animationId) cancelAnimationFrame(this._animationId);

    this.controls.dispose();
    if (this._envMapDispose) this._envMapDispose();
    if (this._lighting) this._lighting.dispose();
    if (this._contactShadow) this._contactShadow.dispose();
    if (this._model) this._disposeModel(this._model);

    if (this.composer) {
      this.composer.passes.forEach(p => { if (p.dispose) p.dispose(); });
    }

    this.renderer.dispose();
    this.renderer.domElement.remove();
  }

  _disposeModel(obj) {
    obj.traverse((child) => {
      if (child.isMesh) {
        child.geometry.dispose();
        const mats = Array.isArray(child.material) ? child.material : [child.material];
        mats.forEach(m => {
          Object.values(m).forEach(v => {
            if (v instanceof THREE.Texture) v.dispose();
          });
          m.dispose();
        });
      }
    });
  }

  // ─── Event Listeners ──────────────────────────────────────────────────────

  _initEventListeners() {
    this._resizeHandler = () => this.resize();
    window.addEventListener('resize', this._resizeHandler);
  }

  // ─── UI update callback (set by index.html) ───────────────────────────────
  _updateUI() {
    if (this.onUIUpdate) this.onUIUpdate();
  }
}
