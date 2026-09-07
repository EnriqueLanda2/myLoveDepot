/**
 * Performance Manager — Adaptive Quality & LOD System
 * =====================================================
 * Detects GPU capability and dynamically adjusts rendering quality
 * to maintain 60 FPS across PC, tablets, and smartphones.
 *
 * Features:
 * - GPU tier detection (WebGL introspection)
 * - Adaptive pixel ratio scaling
 * - LOD level management
 * - Real-time FPS monitoring with quality auto-adjustment
 * - Shadow map resolution scaling
 * - Post-processing tier management
 *
 * 100% Open Source — MIT License
 */

import * as THREE from 'three';

// ─── GPU Tier Detection ──────────────────────────────────────────────────────

/**
 * @typedef {'high' | 'medium' | 'low'} QualityTier
 */

/**
 * @typedef {Object} GPUInfo
 * @property {string} renderer   — GPU renderer string
 * @property {string} vendor     — GPU vendor string
 * @property {number} maxTexSize — Maximum texture dimension
 * @property {boolean} isMobile  — Whether the device is mobile
 * @property {number} memoryGB   — Estimated device memory
 * @property {number} cores      — Logical CPU cores
 * @property {QualityTier} tier  — Detected quality tier
 */

/**
 * Detects GPU capabilities by inspecting WebGL context and device properties.
 *
 * @param {THREE.WebGLRenderer} renderer
 * @returns {GPUInfo}
 */
export function detectGPU(renderer) {
  const gl = renderer.getContext();
  const debugInfo = gl.getExtension('WEBGL_debug_renderer_info');

  const gpuRenderer = debugInfo
    ? gl.getParameter(debugInfo.UNMASKED_RENDERER_WEBGL)
    : 'Unknown';
  const gpuVendor = debugInfo
    ? gl.getParameter(debugInfo.UNMASKED_VENDOR_WEBGL)
    : 'Unknown';

  const maxTexSize = gl.getParameter(gl.MAX_TEXTURE_SIZE);
  const maxRenderbufferSize = gl.getParameter(gl.MAX_RENDERBUFFER_SIZE);
  const maxViewportDims = gl.getParameter(gl.MAX_VIEWPORT_DIMS);

  const isMobile = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(
    navigator.userAgent,
  );

  const memoryGB = navigator.deviceMemory || 4;
  const cores = navigator.hardwareConcurrency || 4;

  // ── Tier Classification Logic ──────────────────────────────────────────────
  let tier = 'medium';

  // Low-end mobile GPUs
  const lowEndGPUs = /Adreno\s?[234]\d{2}|Mali-[GT]?\d{2,3}(?!0)|PowerVR|Apple GPU|SwiftShader/i;
  const highEndGPUs = /RTX|GTX\s?[12]\d{3}|RX\s?[567]\d{3}|Radeon\s?Pro|Apple\s?M[1-4]|Adreno\s?7\d{2}|Mali-G7[1-9]/i;

  if (highEndGPUs.test(gpuRenderer) && !isMobile && memoryGB >= 4 && maxTexSize >= 8192) {
    tier = 'high';
  } else if (lowEndGPUs.test(gpuRenderer) || (isMobile && memoryGB <= 3) || maxTexSize < 4096) {
    tier = 'low';
  } else if (!isMobile && maxTexSize >= 8192 && memoryGB >= 8) {
    tier = 'high';
  } else if (isMobile && memoryGB >= 4 && maxTexSize >= 4096) {
    tier = 'medium';
  }

  return {
    renderer: gpuRenderer,
    vendor: gpuVendor,
    maxTexSize,
    maxRenderbufferSize,
    maxViewportDims,
    isMobile,
    memoryGB,
    cores,
    tier,
  };
}

// ─── Quality Presets ─────────────────────────────────────────────────────────

/**
 * @typedef {Object} QualitySettings
 * @property {number} pixelRatio         — Device pixel ratio cap
 * @property {number} shadowMapSize      — Shadow map resolution
 * @property {boolean} enableShadows     — Whether shadows are enabled
 * @property {boolean} enableSSAO        — Screen-space ambient occlusion
 * @property {boolean} enableBloom       — Bloom post-effect
 * @property {boolean} enableFXAA        — Fast anti-aliasing
 * @property {boolean} enableVignette    — Vignette effect
 * @property {number} maxTriangles       — Max triangle count before LOD decimation
 * @property {number} textureMaxSize     — Max texture dimension
 * @property {number} envMapResolution   — Procedural HDRI resolution
 * @property {boolean} enableAutoRotate  — Turntable animation
 * @property {string} toneMapping        — Tone mapping algorithm
 */

/** @type {Record<QualityTier, QualitySettings>} */
export const QUALITY_PRESETS = {
  high: {
    pixelRatio: 2,
    shadowMapSize: 2048,
    enableShadows: true,
    enableSSAO: true,
    enableBloom: true,
    enableFXAA: true,
    enableVignette: true,
    maxTriangles: 100000,
    textureMaxSize: 2048,
    envMapResolution: 1024,
    enableAutoRotate: true,
    toneMapping: 'ACESFilmic',
  },
  medium: {
    pixelRatio: 1.5,
    shadowMapSize: 1024,
    enableShadows: true,
    enableSSAO: false,
    enableBloom: true,
    enableFXAA: true,
    enableVignette: true,
    maxTriangles: 50000,
    textureMaxSize: 1024,
    envMapResolution: 512,
    enableAutoRotate: true,
    toneMapping: 'ACESFilmic',
  },
  low: {
    pixelRatio: 1,
    shadowMapSize: 512,
    enableShadows: false,
    enableSSAO: false,
    enableBloom: false,
    enableFXAA: true,
    enableVignette: false,
    maxTriangles: 25000,
    textureMaxSize: 512,
    envMapResolution: 256,
    enableAutoRotate: true,
    toneMapping: 'ACESFilmic',
  },
};

// ─── FPS Monitor ─────────────────────────────────────────────────────────────

/**
 * Monitors real-time FPS and triggers quality downgrade when performance drops.
 */
export class FPSMonitor {
  /**
   * @param {object} options
   * @param {number} options.targetFPS       — Target FPS (default 55, slightly below 60 for tolerance)
   * @param {number} options.sampleWindow    — Number of frames to average (default 60)
   * @param {number} options.downgradeThreshold — FPS below which to downgrade quality
   * @param {Function} options.onDowngrade   — Callback when quality should decrease
   * @param {Function} options.onUpgrade     — Callback when quality can increase
   */
  constructor(options = {}) {
    this.targetFPS = options.targetFPS || 55;
    this.sampleWindow = options.sampleWindow || 60;
    this.downgradeThreshold = options.downgradeThreshold || 35;
    this.upgradeThreshold = options.upgradeThreshold || 58;
    this.onDowngrade = options.onDowngrade || (() => {});
    this.onUpgrade = options.onUpgrade || (() => {});

    this._frameTimes = [];
    this._lastTime = performance.now();
    this._currentFPS = 60;
    this._downgradeCount = 0;
    this._upgradeCount = 0;
    this._cooldown = 0;
  }

  /** Call once per frame in the render loop */
  tick() {
    const now = performance.now();
    const delta = now - this._lastTime;
    this._lastTime = now;

    this._frameTimes.push(delta);
    if (this._frameTimes.length > this.sampleWindow) {
      this._frameTimes.shift();
    }

    // Calculate rolling average FPS
    if (this._frameTimes.length >= 10) {
      const avgDelta = this._frameTimes.reduce((a, b) => a + b, 0) / this._frameTimes.length;
      this._currentFPS = Math.round(1000 / avgDelta);
    }

    // Cooldown prevents rapid tier switching
    if (this._cooldown > 0) {
      this._cooldown--;
      return;
    }

    // Check for persistent low FPS → downgrade
    if (this._currentFPS < this.downgradeThreshold) {
      this._downgradeCount++;
      this._upgradeCount = 0;
      if (this._downgradeCount >= 30) { // 30 consecutive bad frames
        this.onDowngrade(this._currentFPS);
        this._downgradeCount = 0;
        this._cooldown = 120; // 2 seconds cooldown
      }
    }
    // Check for persistent high FPS → upgrade
    else if (this._currentFPS >= this.upgradeThreshold) {
      this._upgradeCount++;
      this._downgradeCount = 0;
      if (this._upgradeCount >= 180) { // 3 seconds of good performance
        this.onUpgrade(this._currentFPS);
        this._upgradeCount = 0;
        this._cooldown = 120;
      }
    } else {
      this._downgradeCount = Math.max(0, this._downgradeCount - 1);
      this._upgradeCount = Math.max(0, this._upgradeCount - 1);
    }
  }

  /** @returns {number} Current FPS reading */
  get fps() {
    return this._currentFPS;
  }
}

// ─── Performance Manager (orchestrator) ──────────────────────────────────────

/**
 * Orchestrates quality settings, applies them to the renderer,
 * monitors FPS, and auto-adjusts quality tier.
 */
export class PerformanceManager {
  /**
   * @param {THREE.WebGLRenderer} renderer
   * @param {object} options
   * @param {boolean} options.autoAdjust — Enable auto quality adjustment (default true)
   */
  constructor(renderer, options = {}) {
    this.renderer = renderer;
    this.autoAdjust = options.autoAdjust !== false;

    /** @type {GPUInfo} */
    this.gpuInfo = detectGPU(renderer);

    /** @type {QualityTier} */
    this.currentTier = this.gpuInfo.tier;

    /** @type {QualitySettings} */
    this.settings = { ...QUALITY_PRESETS[this.currentTier] };

    /** @type {FPSMonitor} */
    this.fpsMonitor = new FPSMonitor({
      onDowngrade: (fps) => {
        if (this.autoAdjust) {
          this._stepDown();
          console.info(`[PerfMgr] FPS=${fps} → Downgrade to "${this.currentTier}"`);
        }
      },
      onUpgrade: (fps) => {
        if (this.autoAdjust) {
          this._stepUp();
          console.info(`[PerfMgr] FPS=${fps} → Upgrade to "${this.currentTier}"`);
        }
      },
    });

    // Apply initial settings to the renderer
    this.applyToRenderer();

    this._onChangeCallbacks = [];
  }

  /** Register a callback for quality tier changes */
  onChange(callback) {
    this._onChangeCallbacks.push(callback);
  }

  /** Set quality tier manually */
  setTier(tier) {
    if (!QUALITY_PRESETS[tier]) return;
    this.currentTier = tier;
    this.settings = { ...QUALITY_PRESETS[tier] };
    this.applyToRenderer();
    this._notifyChange();
  }

  /** Apply current quality settings to the renderer */
  applyToRenderer() {
    const r = this.renderer;
    r.setPixelRatio(Math.min(window.devicePixelRatio, this.settings.pixelRatio));
    r.shadowMap.enabled = this.settings.enableShadows;
    if (r.shadowMap.enabled) {
      r.shadowMap.type = this.currentTier === 'high'
        ? THREE.PCFSoftShadowMap
        : THREE.PCFShadowMap;
    }

    // Tone mapping
    r.toneMapping = THREE.ACESFilmicToneMapping;
    r.toneMappingExposure = 1.0;
    r.outputColorSpace = THREE.SRGBColorSpace;
  }

  /** Call once per frame */
  tick() {
    this.fpsMonitor.tick();
  }

  /** @returns {number} Current FPS */
  get fps() {
    return this.fpsMonitor.fps;
  }

  /** Step down one quality tier */
  _stepDown() {
    const order = ['high', 'medium', 'low'];
    const idx = order.indexOf(this.currentTier);
    if (idx < order.length - 1) {
      this.setTier(order[idx + 1]);
    }
  }

  /** Step up one quality tier */
  _stepUp() {
    const order = ['high', 'medium', 'low'];
    const idx = order.indexOf(this.currentTier);
    const maxTier = this.gpuInfo.tier; // Never exceed detected max
    const maxIdx = order.indexOf(maxTier);
    if (idx > 0 && idx - 1 >= maxIdx) {
      this.setTier(order[idx - 1]);
    }
  }

  _notifyChange() {
    for (const cb of this._onChangeCallbacks) {
      try { cb(this.currentTier, this.settings); } catch (e) { console.error(e); }
    }
  }

  /** Returns a diagnostic summary object */
  getDiagnostics() {
    return {
      gpu: this.gpuInfo.renderer,
      vendor: this.gpuInfo.vendor,
      isMobile: this.gpuInfo.isMobile,
      memory: `${this.gpuInfo.memoryGB} GB`,
      maxTexture: this.gpuInfo.maxTexSize,
      detectedTier: this.gpuInfo.tier,
      currentTier: this.currentTier,
      fps: this.fps,
      pixelRatio: this.settings.pixelRatio,
      shadows: this.settings.enableShadows,
      ssao: this.settings.enableSSAO,
      bloom: this.settings.enableBloom,
    };
  }
}

// ─── Render-on-Demand Controller ─────────────────────────────────────────────

/**
 * Only triggers rendering when the scene has changed (user interaction,
 * animation, etc.), saving battery and GPU cycles on mobile.
 */
export class RenderOnDemand {
  constructor() {
    this._needsRender = true;
    this._animating = false;
    this._renderCount = 0;
  }

  /** Mark the scene as needing a render */
  invalidate() {
    this._needsRender = true;
  }

  /** Enable continuous rendering (during animations) */
  startAnimation() {
    this._animating = true;
  }

  /** Disable continuous rendering */
  stopAnimation() {
    this._animating = false;
  }

  /**
   * Check if a render is needed this frame.
   * Call this before rendering.
   * @returns {boolean}
   */
  shouldRender() {
    if (this._animating || this._needsRender) {
      this._needsRender = false;
      this._renderCount++;
      return true;
    }
    return false;
  }

  /** @returns {number} Total renders performed */
  get renderCount() {
    return this._renderCount;
  }
}
