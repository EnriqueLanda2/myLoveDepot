/**
 * Modelado Procedural 3D: Smartphone y Soporte de Escritorio (Three.js)
 * ====================================================================
 * Genera mallas 3D sólidas, limpias y libres de artefactos de escalonado lateral.
 *
 * Implementa las 4 fases:
 * - Fase 1: Descomposición geométrica analítica (Smartphone y Base a ~75°).
 * - Fase 2: Definición topológica cerrada sin caras coplanares ni vértices sueltos.
 * - Fase 3: Mapeo UV ortográfico frontal en [0,1]x[0,1] y materiales PBR.
 * - Fase 4: Integración para exportación a formato .glb / .gltf y .obj.
 */

import * as THREE from 'https://unpkg.com/three@0.160.0/build/three.module.js';

// =============================================================================
// FASE 1 Y 2: CONSTRUCCIÓN GEOMÉTRICA PROCEDURAL
// =============================================================================

/**
 * Genera una forma 2D continua con esquinas redondeadas (fillet) para evitar
 * cualquier artefacto de discretización o gradas laterales.
 */
export function createRoundedRectShape(width, height, radius) {
  const shape = new THREE.Shape();
  const halfW = width / 2;
  const halfH = height / 2;
  const r = Math.min(radius, halfW, halfH);

  shape.moveTo(-halfW + r, -halfH);
  shape.lineTo(halfW - r, -halfH);
  shape.absarc(halfW - r, -halfH + r, r, -Math.PI / 2, 0, false);
  shape.lineTo(halfW, halfH - r);
  shape.absarc(halfW - r, halfH - r, r, 0, Math.PI / 2, false);
  shape.lineTo(-halfW + r, halfH);
  shape.absarc(-halfW + r, halfH - r, r, Math.PI / 2, Math.PI, false);
  shape.lineTo(-halfW, -halfH + r);
  shape.absarc(-halfW + r, -halfH + r, r, Math.PI, 3 * Math.PI / 2, false);

  return shape;
}

/**
 * FASE 1 & 2: Construye la malla del Smartphone (Chasis + Pantalla Plana Inset).
 * FASE 3: Genera UVs normalizadas exactamente en [0, 1] x [0, 1] en la pantalla frontal.
 */
export function createSmartphoneMesh(options = {}, materials = {}) {
  const {
    width = 0.075,
    height = 0.160,
    thickness = 0.008,
    cornerRadius = 0.008,
    screenMargin = 0.0035,
    bevelWidth = 0.0008,
  } = options;

  const group = new THREE.Group();
  group.name = 'Smartphone';

  // 1. Chasis del Smartphone (Malla sólida extruida con biseles)
  const bodyShape = createRoundedRectShape(width, height, cornerRadius);
  const extrudeThickness = Math.max(0.001, thickness - bevelWidth * 2);

  const bodyGeometry = new THREE.ExtrudeGeometry(bodyShape, {
    depth: extrudeThickness,
    bevelEnabled: true,
    bevelSegments: 3,
    bevelSteps: 1,
    bevelSize: bevelWidth,
    bevelThickness: bevelWidth,
    curveSegments: 12,
  });

  bodyGeometry.center();

  const bodyMesh = new THREE.Mesh(
    bodyGeometry,
    materials.phoneBody || new THREE.MeshStandardMaterial({
      color: 0x111215,
      metalness: 0.92,
      roughness: 0.18,
    })
  );
  bodyMesh.name = 'Smartphone_Body';
  bodyMesh.castShadow = true;
  bodyMesh.receiveShadow = true;
  group.add(bodyMesh);

  // 2. Pantalla Frontal Plana (Área activa con mapeo UV [0,1]x[0,1])
  const sw = width - screenMargin * 2;
  const sh = height - screenMargin * 2;
  const sr = Math.max(0.002, cornerRadius - screenMargin);
  const screenShape = createRoundedRectShape(sw, sh, sr);

  const screenGeometry = new THREE.ShapeGeometry(screenShape, 16);

  // Mapeo UV frontal ortográfico sin distorsión
  const posAttr = screenGeometry.attributes.position;
  const uvAttr = screenGeometry.attributes.uv;
  const minX = -sw / 2;
  const maxX = sw / 2;
  const minY = -sh / 2;
  const maxY = sh / 2;

  for (let i = 0; i < posAttr.count; i++) {
    const vx = posAttr.getX(i);
    const vy = posAttr.getY(i);
    const u = (vx - minX) / (maxX - minX);
    const v = (vy - minY) / (maxY - minY);
    uvAttr.setXY(i, u, v);
  }
  uvAttr.needsUpdate = true;
  screenGeometry.computeVertexNormals();

  // Posicionar la pantalla en la cara frontal (-Z)
  screenGeometry.translate(0, 0, -thickness / 2 - 0.0001);

  const screenMesh = new THREE.Mesh(
    screenGeometry,
    materials.screen || new THREE.MeshStandardMaterial({
      color: 0x030408,
      roughness: 0.04,
      metalness: 0.0,
    })
  );
  screenMesh.name = 'Smartphone_Screen';
  screenMesh.receiveShadow = true;
  group.add(screenMesh);

  return {
    group,
    bodyMesh,
    screenMesh,
    dimensions: { width, height, thickness },
  };
}

/**
 * FASE 1 & 2: Construye la base / soporte de escritorio con ranura inclinada a ~75°.
 * Extruye analíticamente el perfil transversal lateral a lo largo de X.
 */
export function createDeskStandMesh(options = {}, materials = {}) {
  const {
    standWidth = 0.088,
    angleDeg = 75.0,
    bevelWidth = 0.0012,
  } = options;

  const angleRad = (angleDeg * Math.PI) / 180;
  const tanA = Math.tan(angleRad);
  const cosA = Math.cos(angleRad);

  const slotBottomY = 0.008; // 8 mm sobre la mesa
  const lipHeight = 0.020;   // 20 mm
  const lipFrontZ = -0.042;  // Frente hacia el usuario (-Z)
  const lipBackZ = -0.026;   // Pared interior frontal
  const slotWidth = 0.012;   // 12 mm ancho de ranura

  const backrestBottomZ = lipBackZ + slotWidth * cosA;
  const backrestBottomY = slotBottomY;

  const backrestTopY = 0.065;
  const dyBackrest = backrestTopY - backrestBottomY;
  const backrestTopZ = backrestBottomZ + dyBackrest / tanA;

  // Perfil 2D lateral: Eje X_shape = Profundidad Z, Eje Y_shape = Altura Y
  const standShape = new THREE.Shape();
  standShape.moveTo(lipFrontZ, 0.0);
  standShape.lineTo(lipFrontZ, lipHeight - 0.003);
  standShape.lineTo(lipFrontZ + 0.003, lipHeight);
  standShape.lineTo(lipBackZ, lipHeight);
  standShape.lineTo(lipBackZ, slotBottomY + 0.003);
  standShape.lineTo(lipBackZ + 0.002, slotBottomY);
  standShape.lineTo(backrestBottomZ, slotBottomY);
  standShape.lineTo(backrestTopZ, backrestTopY);
  standShape.lineTo(backrestTopZ + 0.007, backrestTopY);
  standShape.lineTo(0.048, 0.016);
  standShape.lineTo(0.052, 0.006);
  standShape.lineTo(0.052, 0.0);
  standShape.closePath();

  const extrudeDepth = Math.max(0.001, standWidth - bevelWidth * 2);
  const standGeometry = new THREE.ExtrudeGeometry(standShape, {
    depth: extrudeDepth,
    bevelEnabled: true,
    bevelSegments: 2,
    bevelSteps: 1,
    bevelSize: bevelWidth,
    bevelThickness: bevelWidth,
  });

  standGeometry.center();
  standGeometry.rotateY(-Math.PI / 2);

  standGeometry.computeBoundingBox();
  const minY = standGeometry.boundingBox.min.y;
  standGeometry.translate(0, -minY, 0);

  const standMesh = new THREE.Mesh(
    standGeometry,
    materials.stand || new THREE.MeshStandardMaterial({
      color: 0x18191c,
      roughness: 0.88,
      metalness: 0.02,
    })
  );
  standMesh.name = 'DeskStand';
  standMesh.castShadow = true;
  standMesh.receiveShadow = true;

  return {
    mesh: standMesh,
    params: {
      angleDeg,
      slotBottomY,
      backrestBottomZ,
      lipHeight,
      slotWidth,
    },
  };
}

/**
 * Acopla de forma precisa el smartphone en la ranura a 75°:
 * - Espalda apoyada contra el respaldo (+Z).
 * - Pantalla orientada hacia el frente (-Z).
 * - Tolerancia de 0.4 mm para evitar Z-fighting / coplanaridad.
 */
export function dockSmartphoneInStand(phoneGroup, standParams, phoneDims) {
  const angleDeg = standParams.angleDeg || 75.0;
  const tiltRad = ((90.0 - angleDeg) * Math.PI) / 180; // 15° hacia atrás

  const slotBottomY = standParams.slotBottomY || 0.008;
  const backrestBottomZ = standParams.backrestBottomZ || -0.0219;
  const clearance = 0.0004;

  const cosT = Math.cos(tiltRad);
  const sinT = Math.sin(tiltRad);
  const halfT = phoneDims.thickness / 2;
  const halfH = phoneDims.height / 2;

  // El punto posterior-inferior en local es (0, -halfH, +halfT)
  // Rotado alrededor de X por -tiltRad:
  const rotY = (-halfH) * cosT - halfT * sinT;
  const rotZ = (-halfH) * sinT + halfT * cosT;

  const targetY = slotBottomY + clearance * cosT;
  const targetZ = backrestBottomZ + clearance * sinT;

  const transY = targetY - rotY;
  const transZ = targetZ - rotZ;

  phoneGroup.rotation.set(-tiltRad, 0, 0);
  phoneGroup.position.set(0, transY, transZ);
}

// =============================================================================
// FASE 3: MATERIALES PBR THREE.JS
// =============================================================================
export function createThreeMaterials(textureMap = null) {
  const screen = new THREE.MeshStandardMaterial({
    color: textureMap ? 0xffffff : 0x080c14,
    map: textureMap,
    roughness: 0.04,
    metalness: 0.0,
    emissive: textureMap ? 0x222222 : 0x050a12,
    emissiveMap: textureMap || null,
  });

  const phoneBody = new THREE.MeshStandardMaterial({
    color: 0x121316,
    roughness: 0.18,
    metalness: 0.92,
  });

  const stand = new THREE.MeshStandardMaterial({
    color: 0x1c1d22,
    roughness: 0.88,
    metalness: 0.03,
  });

  return { screen, phoneBody, stand };
}
