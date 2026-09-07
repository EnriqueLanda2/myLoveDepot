/**
 * Viewer3D — Photorealistic 3D Product Viewer
 * ==============================================
 * Main module: Three.js scene setup, GLB loading, PBR materials,
 * post-processing pipeline, and UI integration.
 *
 * Stack: Three.js r185 (ES Modules) | glTF 2.0 | PBR metallic-roughness
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
import { MeshoptDecoder } from 'meshoptimizer/decoder';
import { MeshoptSimplifier } from 'meshoptimizer/simplifier';

import { createPBREnvironment, createStudioLighting, createContactShadow } from './pbr-environment.js';
import { PerformanceManager, QUALITY_PRESETS, RenderOnDemand } from './performance-manager.js';

const LOD_LEVELS = [
  { name: 'high', distance: 0, ratio: 1.0, error: 0.001 },
  { name: 'medium', distance: 6, ratio: 0.55, error: 0.005 },
  { name: 'low', distance: 10, ratio: 0.25, error: 0.015 },
];
const MIN_LOD_TRIANGLES = 1500;

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
    this._modelInfo = {
      triangles: 0,
      vertices: 0,
      materials: 0,
      meshes: 0,
      lodTriangles: { high: 0, medium: 0, low: 0 },
    };
    this._lods = [];
    this._animationId = null;
    this._disposed = false;
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
    const { width, height } = this._getViewportSize();
    this.renderer = new THREE.WebGLRenderer({
      // FXAA is applied in the composer. Requesting default-framebuffer MSAA as
      // well wastes fill-rate on mobile without improving the composed image.
      antialias: false,
      alpha: false,
      powerPreference: 'high-performance',
      stencil: false,
    });

    this.renderer.setSize(width, height);
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
    const { width, height } = this._getViewportSize();
    const aspect = width / height;
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

    // A tier affects every expensive subsystem, not only post-processing.
    this.perfManager.onChange((tier, settings) => {
      this._applyQualityTier(tier, settings);
      this._updateUI();
    });
  }

  _initEnvironment() {
    this._rebuildEnvironment();
  }

  _rebuildEnvironment() {
    if (this._envMapDispose) this._envMapDispose();

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
    this._rebuildLighting();
  }

  _rebuildLighting() {
    if (this._lighting) this._lighting.dispose();

    this._lighting = createStudioLighting(this.scene, {
      scale: 1.0,
      tier: this.perfManager.currentTier,
      enableShadows: this.perfManager.settings.enableShadows,
    });

    if (!this._contactShadow) {
      this._contactShadow = createContactShadow(this.scene, 12, 0);
    }
    this._contactShadow.mesh.visible = this.perfManager.settings.enableShadows;
  }

  _initPostProcessing() {
    const { settings } = this.perfManager;
    const { width, height } = this._getViewportSize();

    this._bloomPass = null;
    this._fxaaPass = null;
    this._vignettePass = null;

    this.composer = new EffectComposer(this.renderer);
    this.composer.setSize(width, height);

    // 1. Scene render
    const renderPass = new RenderPass(this.scene, this.camera);
    this.composer.addPass(renderPass);

    // 2. Bloom (subtle, only on high/medium)
    if (settings.enableBloom) {
      this._bloomPass = new UnrealBloomPass(
        new THREE.Vector2(width, height),
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
      this._fxaaPass.material.uniforms['resolution'].value.x = 1 / (width * pixelRatio);
      this._fxaaPass.material.uniforms['resolution'].value.y = 1 / (height * pixelRatio);
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
    this._disposePostProcessing();
    this._initPostProcessing();
  }

  _disposePostProcessing() {
    if (!this.composer) return;
    this.composer.passes.forEach((pass) => pass.dispose?.());
    this.composer.dispose();
    this.composer = null;
    this._bloomPass = null;
    this._fxaaPass = null;
    this._vignettePass = null;
  }

  _applyQualityTier() {
    this.resize();
    this._rebuildEnvironment();
    this._rebuildLighting();
    this._rebuildPostProcessing();
    this._applyMaterialQuality();
    this._updateLODs();
    this._renderOnDemand.invalidate();
  }

  // ─── Model Loading ────────────────────────────────────────────────────────

  /**
   * Load a GLB/GLTF model from URL.
   * @param {string} url
   * @param {Function} onProgress — Progress callback(0-100)
   * @returns {Promise<THREE.Group>}
   */
  async loadModel(url, onProgress = () => {}) {
    const loader = new GLTFLoader();
    const dracoLoader = new DRACOLoader();
    dracoLoader.setDecoderPath('https://www.gstatic.com/draco/versioned/decoders/1.5.7/');
    dracoLoader.setDecoderConfig({ type: 'js' });
    loader.setDRACOLoader(dracoLoader);
    loader.setMeshoptDecoder(MeshoptDecoder);

    let model = null;
    try {
      const gltf = await loader.loadAsync(url, (progress) => {
        if (progress.total > 0) {
          onProgress(Math.round((progress.loaded / progress.total) * 100));
        }
      });
      model = gltf.scene;

      // ── Center and scale model to fit the scene ──────────────────────────
      const box = new THREE.Box3().setFromObject(model);
      const center = box.getCenter(new THREE.Vector3());
      const size = box.getSize(new THREE.Vector3());
      const maxDim = Math.max(size.x, size.y, size.z);
      if (!Number.isFinite(maxDim) || maxDim <= 0) {
        throw new Error('El GLB no contiene una malla con dimensiones válidas.');
      }

      const scale = 2.0 / maxDim;
      model.scale.setScalar(scale);
      model.position.sub(center.multiplyScalar(scale));
      const newBox = new THREE.Box3().setFromObject(model);
      model.position.y -= newBox.min.y;

      // GLTFLoader already materializes pbrMetallicRoughness and
      // KHR_materials_clearcoat. Only legacy materials carrying the explicit
      // extras.myLoveDepotPBR contract are upgraded here.
      this._enhanceMaterials(model);
      this._collectModelInfo(model);
      await this._prepareLODs(model, gltf.animations.length > 0);

      model.traverse((child) => {
        if (child.isMesh) {
          child.castShadow = true;
          child.receiveShadow = true;
        }
      });

      this._contactShadow.setPosition(0);
      this._frameModel(model);

      const previousModel = this._model;
      this._model = model;
      this.scene.add(model);
      if (previousModel) {
        this.scene.remove(previousModel);
        this._disposeModel(previousModel);
      }
      this._updateLODs();
      this._renderOnDemand.invalidate();
      return model;
    } catch (error) {
      if (model && model !== this._model) this._disposeModel(model);
      throw error;
    } finally {
      dracoLoader.dispose();
    }
  }

  /**
   * Upgrade imported materials to MeshPhysicalMaterial for premium PBR.
   * @param {THREE.Object3D} model
   */
  _enhanceMaterials(model) {
    const replacements = new Map();

    model.traverse((child) => {
      if (!child.isMesh || !child.material) return;
      const source = Array.isArray(child.material) ? child.material : [child.material];
      const enhanced = source.map((material) => {
        if (replacements.has(material)) return replacements.get(material);

        let result = material;
        const metadata = material.userData?.myLoveDepotPBR;
        if (
          metadata &&
          typeof metadata === 'object' &&
          material.isMeshStandardMaterial &&
          !material.isMeshPhysicalMaterial
        ) {
          result = new THREE.MeshPhysicalMaterial();
          // MeshPhysicalMaterial extends MeshStandardMaterial. Calling the
          // standard copy routine preserves every standard field and texture,
          // while keeping the physical shader defines created by its constructor.
          THREE.MeshStandardMaterial.prototype.copy.call(result, material);
          result.roughness = this._unitValue(metadata.roughness, material.roughness);
          result.metalness = this._unitValue(metadata.metalness, material.metalness);
          result.clearcoat = this._unitValue(metadata.clearcoat, 0);
          result.clearcoatRoughness = this._unitValue(metadata.clearcoatRoughness, 0.1);
        }

        replacements.set(material, result);
        return result;
      });

      child.material = Array.isArray(child.material) ? enhanced : enhanced[0];
    });

    for (const [source, replacement] of replacements) {
      if (source !== replacement) source.dispose();
    }
    this._applyMaterialQuality(model);
  }

  _unitValue(value, fallback) {
    const numeric = Number(value);
    return Number.isFinite(numeric) ? THREE.MathUtils.clamp(numeric, 0, 1) : fallback;
  }

  _applyMaterialQuality(model = this._model) {
    if (!model) return;
    const intensity = this.perfManager.currentTier === 'high' ? 1.2 : 0.85;
    const materials = new Set();
    model.traverse((child) => {
      if (!child.isMesh || !child.material) return;
      const list = Array.isArray(child.material) ? child.material : [child.material];
      list.forEach((material) => materials.add(material));
    });
    materials.forEach((material) => {
      if ('envMapIntensity' in material) material.envMapIntensity = intensity;
      material.needsUpdate = true;
    });
  }

  async _prepareLODs(model, hasAnimations) {
    this._lods = [];
    const allMeshes = [];
    model.traverse((child) => {
      if (child.isMesh) allMeshes.push(child);
    });

    const originalTriangles = allMeshes.reduce(
      (sum, mesh) => sum + this._triangleCount(mesh.geometry),
      0,
    );
    this._modelInfo.lodTriangles = {
      high: originalTriangles,
      medium: originalTriangles,
      low: originalTriangles,
    };

    // Replacing animated/skinned nodes would invalidate animation bindings.
    if (hasAnimations) return;

    const candidates = allMeshes.filter((mesh) => {
      const geometry = mesh.geometry;
      return (
        !mesh.isSkinnedMesh &&
        !mesh.morphTargetInfluences?.length &&
        geometry?.index &&
        geometry.attributes?.position &&
        geometry.groups.length <= 1 &&
        this._triangleCount(geometry) >= MIN_LOD_TRIANGLES
      );
    });
    if (candidates.length === 0) return;

    await MeshoptSimplifier.ready;
    if (!MeshoptSimplifier.supported) return;

    const eligibleTriangles = candidates.reduce(
      (sum, mesh) => sum + this._triangleCount(mesh.geometry),
      0,
    );
    const fixedTriangles = originalTriangles - eligibleTriangles;
    const ratios = Object.fromEntries(LOD_LEVELS.map((level) => {
      const remainingBudget = Math.max(
        0,
        QUALITY_PRESETS[level.name].maxTriangles - fixedTriangles,
      );
      const budgetRatio = eligibleTriangles > 0 ? remainingBudget / eligibleTriangles : 1;
      return [level.name, Math.min(level.ratio, budgetRatio, 1)];
    }));
    const totals = {
      high: fixedTriangles,
      medium: fixedTriangles,
      low: fixedTriangles,
    };

    for (const mesh of candidates) {
      const sourceGeometry = mesh.geometry;
      const levelGeometries = {};
      for (const level of LOD_LEVELS) {
        levelGeometries[level.name] = this._simplifyGeometry(
          sourceGeometry,
          ratios[level.name],
          level.error,
          level.name,
        );
        totals[level.name] += this._triangleCount(levelGeometries[level.name]);
      }
      this._replaceMeshWithLOD(mesh, levelGeometries);

      // Yield between meshes so a complex product does not monopolize the UI
      // thread for the entire simplification pass.
      await new Promise((resolve) => requestAnimationFrame(resolve));
    }

    this._modelInfo.lodTriangles = totals;
  }

  _simplifyGeometry(source, ratio, targetError, levelName) {
    const sourceIndex = source.index;
    const targetCount = Math.max(
      3,
      Math.floor((sourceIndex.count * ratio) / 3) * 3,
    );
    if (targetCount >= sourceIndex.count) return source;

    const indices = Uint32Array.from(sourceIndex.array);
    const positions = this._attributeToFloat32(source.attributes.position, 3);
    const { attributes, stride, weights } = this._simplificationAttributes(source);
    let simplified;
    let achievedError;
    try {
      [simplified, achievedError] = stride > 0
        ? MeshoptSimplifier.simplifyWithAttributes(
          indices,
          positions,
          3,
          attributes,
          stride,
          weights,
          null,
          targetCount,
          targetError,
          ['LockBorder'],
        )
        : MeshoptSimplifier.simplify(
          indices,
          positions,
          3,
          targetCount,
          targetError,
          ['LockBorder'],
        );
    } catch (error) {
      console.warn(`[Viewer3D] No se pudo crear LOD ${levelName}:`, error);
      return source;
    }

    if (simplified.length >= sourceIndex.count) return source;
    const geometry = new THREE.BufferGeometry();
    for (const [name, attribute] of Object.entries(source.attributes)) {
      geometry.setAttribute(name, attribute);
    }
    geometry.morphAttributes = source.morphAttributes;
    geometry.morphTargetsRelative = source.morphTargetsRelative;
    geometry.setIndex(new THREE.BufferAttribute(simplified, 1));
    if (source.groups.length === 1) {
      geometry.addGroup(0, simplified.length, source.groups[0].materialIndex);
    }
    geometry.name = `${source.name || 'geometry'}_${levelName}`;
    geometry.userData = {
      ...source.userData,
      myLoveDepotLOD: {
        level: levelName,
        sourceTriangles: sourceIndex.count / 3,
        triangles: simplified.length / 3,
        error: achievedError,
      },
    };
    geometry.boundingBox = source.boundingBox?.clone() ?? null;
    geometry.boundingSphere = source.boundingSphere?.clone() ?? null;
    return geometry;
  }

  _simplificationAttributes(geometry) {
    const specs = [
      ['normal', 3, 0.5],
      ['uv', 2, 1.0],
      ['color', Math.min(geometry.attributes.color?.itemSize ?? 0, 4), 0.5],
    ].filter(([name, components]) => (
      components > 0 && geometry.attributes[name]?.count === geometry.attributes.position.count
    ));
    const stride = specs.reduce((sum, [, components]) => sum + components, 0);
    if (stride === 0) return { attributes: new Float32Array(), stride: 0, weights: [] };

    const vertexCount = geometry.attributes.position.count;
    const attributes = new Float32Array(vertexCount * stride);
    const weights = [];
    let componentOffset = 0;
    for (const [name, components, weight] of specs) {
      const source = geometry.attributes[name];
      for (let component = 0; component < components; component++) weights.push(weight);
      for (let vertex = 0; vertex < vertexCount; vertex++) {
        for (let component = 0; component < components; component++) {
          attributes[vertex * stride + componentOffset + component] =
            source.getComponent(vertex, component);
        }
      }
      componentOffset += components;
    }
    return { attributes, stride, weights };
  }

  _attributeToFloat32(attribute, components) {
    const values = new Float32Array(attribute.count * components);
    for (let vertex = 0; vertex < attribute.count; vertex++) {
      for (let component = 0; component < components; component++) {
        values[vertex * components + component] = attribute.getComponent(vertex, component);
      }
    }
    return values;
  }

  _replaceMeshWithLOD(mesh, geometries) {
    const parent = mesh.parent;
    if (!parent) return;

    const lod = new THREE.LOD();
    lod.name = `${mesh.name || 'mesh'}_LOD`;
    lod.userData = { ...mesh.userData, myLoveDepotLOD: true };
    lod.position.copy(mesh.position);
    lod.quaternion.copy(mesh.quaternion);
    lod.scale.copy(mesh.scale);
    lod.matrix.copy(mesh.matrix);
    lod.matrixAutoUpdate = mesh.matrixAutoUpdate;
    lod.visible = mesh.visible;
    lod.layers.mask = mesh.layers.mask;
    lod.autoUpdate = false;

    // Node children are not geometry levels; keep them attached to the LOD
    // transform so their hierarchy remains visible at every quality level.
    const persistentChildren = [...mesh.children];
    persistentChildren.forEach((child) => {
      mesh.remove(child);
      lod.add(child);
    });

    mesh.position.set(0, 0, 0);
    mesh.quaternion.identity();
    mesh.scale.set(1, 1, 1);
    mesh.matrix.identity();
    mesh.matrixAutoUpdate = true;
    mesh.visible = true;
    mesh.geometry = geometries.high;
    lod.addLevel(mesh, LOD_LEVELS[0].distance);

    for (const level of LOD_LEVELS.slice(1)) {
      const levelMesh = mesh.clone(false);
      levelMesh.name = `${mesh.name || 'mesh'}_${level.name}`;
      levelMesh.geometry = geometries[level.name];
      levelMesh.userData = { ...mesh.userData, myLoveDepotLODLevel: level.name };
      lod.addLevel(levelMesh, level.distance);
    }

    parent.remove(mesh);
    parent.add(lod);
    this._lods.push(lod);
  }

  _triangleCount(geometry) {
    if (!geometry) return 0;
    if (geometry.index) return Math.floor(geometry.index.count / 3);
    return Math.floor((geometry.attributes.position?.count ?? 0) / 3);
  }

  _updateLODs() {
    if (!this.camera || this._lods.length === 0) return;
    const floor = this.perfManager.settings.lodFloor;
    this.camera.updateMatrixWorld();
    for (const lod of this._lods) {
      lod.updateMatrixWorld();
      lod.update(this.camera);
      const selected = lod.levels.findIndex((level) => level.object.visible);
      const enforced = Math.max(selected < 0 ? 0 : selected, floor);
      lod.levels.forEach((level, index) => {
        level.object.visible = index === enforced;
      });
    }
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

  _animate(timestamp = performance.now()) {
    if (this._disposed) return;
    this._animationId = requestAnimationFrame((nextTimestamp) => this._animate(nextTimestamp));

    this.controls.update();

    // Render only when needed (or always during auto-rotate)
    if (this._renderOnDemand.shouldRender() || this.controls.autoRotate) {
      this._updateLODs();
      if (this.composer && this.composer.passes.length > 1) {
        this.composer.render();
      } else {
        this.renderer.render(this.scene, this.camera);
      }
      // Only rendered frames are meaningful for adaptive quality. Counting idle
      // requestAnimationFrame callbacks would report 60 FPS even when no draw ran.
      this.perfManager.tick(timestamp);
    }
  }

  // ─── Public API ────────────────────────────────────────────────────────────

  /** Resize to fit container */
  resize() {
    const { width: w, height: h } = this._getViewportSize();

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
    this.options.environmentPreset = preset;
    this._rebuildEnvironment();
    this._applyMaterialQuality();
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
    this.perfManager.resetMonitoring();
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
    this._resizeObserver?.disconnect();
    window.removeEventListener('resize', this._resizeHandler);
    if (this._envMapDispose) this._envMapDispose();
    if (this._lighting) this._lighting.dispose();
    if (this._contactShadow) this._contactShadow.dispose();
    if (this._model) this._disposeModel(this._model);

    this._disposePostProcessing();

    this.renderer.dispose();
    this.renderer.domElement.remove();
  }

  _disposeModel(obj) {
    const geometries = new Set();
    const materials = new Set();
    const textures = new Set();
    obj.traverse((child) => {
      if (child.isMesh) {
        geometries.add(child.geometry);
        const mats = Array.isArray(child.material) ? child.material : [child.material];
        mats.forEach(m => {
          materials.add(m);
          Object.values(m).forEach(v => {
            if (v instanceof THREE.Texture && v !== this.scene.environment) textures.add(v);
          });
        });
      }
    });
    textures.forEach((texture) => texture.dispose());
    materials.forEach((material) => material.dispose());
    geometries.forEach((geometry) => geometry.dispose());
  }

  // ─── Event Listeners ──────────────────────────────────────────────────────

  _initEventListeners() {
    this._resizeHandler = () => this.resize();
    if ('ResizeObserver' in window) {
      this._resizeObserver = new ResizeObserver(this._resizeHandler);
      this._resizeObserver.observe(this.container);
    } else {
      window.addEventListener('resize', this._resizeHandler);
    }
  }

  _getViewportSize() {
    const bounds = this.container.getBoundingClientRect();
    return {
      width: Math.max(1, Math.round(bounds.width || this.container.clientWidth || window.innerWidth)),
      height: Math.max(1, Math.round(bounds.height || this.container.clientHeight || window.innerHeight)),
    };
  }

  // ─── UI update callback (set by index.html) ───────────────────────────────
  _updateUI() {
    if (this.onUIUpdate) this.onUIUpdate();
  }
}
