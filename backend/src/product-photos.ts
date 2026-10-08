import sharp, { type OverlayOptions } from 'sharp';

/**
 * Genera fotografías de catálogo a partir de una sola foto del producto.
 *
 * 1. Quita el fondo: estima el color del fondo en los bordes de la foto y lo
 *    "inunda" desde ahí (flood fill). Lo que no se alcanza es el producto.
 * 2. Recorta el producto y lo coloca, con sombra, sobre fondos de estudio.
 *
 * Funciona bien con fondos lisos o con poco detalle, que es lo que piden las
 * guías de la app. Si el recorte no es confiable (el "producto" ocupa casi toda
 * la foto o casi nada), se usa la foto completa con esquinas redondeadas para
 * no entregar un recorte roto.
 */

const CANVAS = 1024;
const WORK_MAX = 1200;

type Rgb = [number, number, number];

interface Shadow {
  color: Rgb;
  opacity: number;
  blur: number;
  dy: number;
}

interface Variant {
  key: string;
  label: string;
  background: { solid: string } | { from: string; to: string };
  shadow?: Shadow;
  contactShadow?: number;
}

// Cada "juego" son cuatro opciones; "Generar otras" pide el siguiente.
const VARIANT_SETS: Variant[][] = [
  [
    { key: 'estudio', label: 'Estudio blanco', background: { solid: '#FFFFFF' }, contactShadow: 0.22 },
    {
      key: 'rosa', label: 'Rosa pastel', background: { solid: '#F9E3EB' },
      shadow: { color: [168, 51, 95], opacity: 0.22, blur: 14, dy: 14 },
    },
    {
      key: 'sombra', label: 'Sombra suave', background: { solid: '#F3EEE9' },
      shadow: { color: [42, 31, 36], opacity: 0.3, blur: 22, dy: 26 },
    },
    {
      key: 'contraste', label: 'Contraste', background: { solid: '#2A1F24' },
      shadow: { color: [255, 255, 255], opacity: 0.2, blur: 26, dy: 0 },
    },
  ],
  [
    { key: 'degradado', label: 'Degradado rosa', background: { from: '#FBE8EF', to: '#FFFFFF' }, contactShadow: 0.18 },
    {
      key: 'menta', label: 'Menta', background: { solid: '#E6F4EC' },
      shadow: { color: [33, 112, 75], opacity: 0.18, blur: 16, dy: 16 },
    },
    {
      key: 'arena', label: 'Arena cálida', background: { solid: '#F4E7D7' },
      shadow: { color: [110, 66, 10], opacity: 0.24, blur: 22, dy: 24 },
    },
    { key: 'lavanda', label: 'Lavanda', background: { from: '#EFE7F8', to: '#FBF7F8' }, contactShadow: 0.2 },
  ],
];

export const PHOTO_SET_COUNT = VARIANT_SETS.length;

export interface ProductPhoto {
  key: string;
  label: string;
  /** JPEG listo para usarse como `src` o para guardarse como foto del producto. */
  image: string;
}

export interface ProductPhotosResult {
  /** `false` cuando no se pudo separar el producto del fondo. */
  cutout: boolean;
  photos: ProductPhoto[];
}

export async function generateProductPhotos(input: Buffer, set = 0): Promise<ProductPhotosResult> {
  const { data, info } = await sharp(input, { failOn: 'error', limitInputPixels: 30_000_000 })
    .rotate()
    .resize({ width: WORK_MAX, height: WORK_MAX, fit: 'inside', withoutEnlargement: true })
    .ensureAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true });
  const { width, height } = info;

  const cut = cutOut(data, width, height);
  const product = await cropProduct(data, width, height, cut);

  const variants = VARIANT_SETS[((set % PHOTO_SET_COUNT) + PHOTO_SET_COUNT) % PHOTO_SET_COUNT];
  const photos = await Promise.all(variants.map(async (variant) => ({
    key: variant.key,
    label: variant.label,
    image: `data:image/jpeg;base64,${(await compose(product, variant)).toString('base64')}`,
  })));
  return { cutout: cut.reliable, photos };
}

// ── Recorte ──────────────────────────────────────────────────────────────────

interface CutOut {
  /** Alfa por píxel (0-255) del tamaño de trabajo. */
  alpha: Uint8Array;
  reliable: boolean;
}

function colorDistance(r1: number, g1: number, b1: number, r2: number, g2: number, b2: number) {
  // Distancia RGB ponderada: el ojo es más sensible al verde.
  const dr = r1 - r2;
  const dg = g1 - g2;
  const db = b1 - b2;
  return Math.sqrt((2 * dr * dr + 4 * dg * dg + 3 * db * db) / 9);
}

function cutOut(rgba: Buffer, width: number, height: number): CutOut {
  const total = width * height;

  // Una foto que ya trae transparencia (PNG recortado) no necesita nada más.
  let transparent = 0;
  for (let i = 0; i < total; i++) if (rgba[i * 4 + 3] < 250) transparent++;
  if (transparent > total * 0.05) {
    const alpha = new Uint8Array(total);
    for (let i = 0; i < total; i++) alpha[i] = rgba[i * 4 + 3];
    return { alpha, reliable: true };
  }

  // Color del fondo: mediana de una franja en los cuatro bordes.
  const band = Math.max(2, Math.round(Math.min(width, height) * 0.02));
  const border: number[] = [];
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      if (x < band || y < band || x >= width - band || y >= height - band) border.push(y * width + x);
    }
  }
  const channel = (c: number) => {
    const values = border.map((p) => rgba[p * 4 + c]).sort((a, b) => a - b);
    return values[Math.floor(values.length / 2)];
  };
  const bg: Rgb = [channel(0), channel(1), channel(2)];
  const borderDistances = border
    .map((p) => colorDistance(rgba[p * 4], rgba[p * 4 + 1], rgba[p * 4 + 2], ...bg))
    .sort((a, b) => a - b);
  const p90 = borderDistances[Math.floor(borderDistances.length * 0.9)];
  const threshold = Math.min(70, Math.max(18, p90 * 1.6 + 12));

  // Inundación desde los bordes. Acepta píxeles parecidos al fondo, o que
  // cambian muy poco respecto al vecino (degradados y viñeteado del fondo).
  const isBackground = new Uint8Array(total);
  const queue = new Int32Array(total);
  let head = 0;
  let tail = 0;
  const distanceToBg = (p: number) =>
    colorDistance(rgba[p * 4], rgba[p * 4 + 1], rgba[p * 4 + 2], ...bg);
  for (const p of border) {
    if (!isBackground[p] && distanceToBg(p) < threshold) {
      isBackground[p] = 1;
      queue[tail++] = p;
    }
  }
  while (head < tail) {
    const p = queue[head++];
    const x = p % width;
    const y = (p - x) / width;
    const neighbours = [
      x > 0 ? p - 1 : -1,
      x < width - 1 ? p + 1 : -1,
      y > 0 ? p - width : -1,
      y < height - 1 ? p + width : -1,
    ];
    for (const n of neighbours) {
      if (n < 0 || isBackground[n]) continue;
      const d = distanceToBg(n);
      const step = colorDistance(
        rgba[n * 4], rgba[n * 4 + 1], rgba[n * 4 + 2],
        rgba[p * 4], rgba[p * 4 + 1], rgba[p * 4 + 2],
      );
      if (d < threshold || (step < 5 && d < threshold * 2.2)) {
        isBackground[n] = 1;
        queue[tail++] = n;
      }
    }
  }

  // Se conservan solo las piezas grandes: elimina motas sueltas del fondo.
  const label = new Int32Array(total).fill(-1);
  const sizes: number[] = [];
  for (let start = 0; start < total; start++) {
    if (isBackground[start] || label[start] !== -1) continue;
    const id = sizes.length;
    let size = 0;
    head = 0;
    tail = 0;
    queue[tail++] = start;
    label[start] = id;
    while (head < tail) {
      const p = queue[head++];
      size++;
      const x = p % width;
      const y = (p - x) / width;
      const neighbours = [
        x > 0 ? p - 1 : -1,
        x < width - 1 ? p + 1 : -1,
        y > 0 ? p - width : -1,
        y < height - 1 ? p + width : -1,
      ];
      for (const n of neighbours) {
        if (n >= 0 && !isBackground[n] && label[n] === -1) {
          label[n] = id;
          queue[tail++] = n;
        }
      }
    }
    sizes.push(size);
  }
  const largest = sizes.length ? Math.max(...sizes) : 0;
  // Asas, tapas y piezas delgadas pueden quedar separadas del cuerpo; se
  // conservan mientras no sean motas diminutas.
  const minPiece = Math.max(largest * 0.01, total * 0.0004);
  const alpha = new Uint8Array(total);
  let foreground = 0;
  for (let p = 0; p < total; p++) {
    if (label[p] >= 0 && sizes[label[p]] >= minPiece) {
      alpha[p] = 255;
      foreground++;
    }
  }

  const ratio = foreground / total;
  if (ratio < 0.015 || ratio > 0.92) {
    return { alpha: roundedRectAlpha(width, height), reliable: false };
  }
  return { alpha, reliable: true };
}

function roundedRectAlpha(width: number, height: number) {
  const alpha = new Uint8Array(width * height);
  const r = Math.round(Math.min(width, height) * 0.06);
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const cx = x < r ? r : x >= width - r ? width - r - 1 : x;
      const cy = y < r ? r : y >= height - r ? height - r - 1 : y;
      const inside = (x - cx) ** 2 + (y - cy) ** 2 <= r * r;
      alpha[y * width + x] = inside ? 255 : 0;
    }
  }
  return alpha;
}

interface CroppedProduct {
  png: Buffer;
  width: number;
  height: number;
}

async function cropProduct(rgba: Buffer, width: number, height: number, cut: CutOut): Promise<CroppedProduct> {
  // Bordes suaves: el alfa se difumina un poco para que no se vea serruchado.
  const softAlpha = await sharp(Buffer.from(cut.alpha), { raw: { width, height, channels: 1 } })
    .blur(cut.reliable ? 1.2 : 0.6)
    // Sin esto sharp devuelve la máscara en RGB (3 bytes por píxel).
    .toColourspace('b-w')
    .extractChannel(0)
    .raw()
    .toBuffer();

  let minX = width;
  let minY = height;
  let maxX = -1;
  let maxY = -1;
  const withAlpha = Buffer.from(rgba);
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const p = y * width + x;
      const a = Math.min(rgba[p * 4 + 3], softAlpha[p]);
      withAlpha[p * 4 + 3] = a;
      if (a > 128) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  if (maxX < 0) {
    minX = 0;
    minY = 0;
    maxX = width - 1;
    maxY = height - 1;
  }
  const pad = Math.round(Math.max(maxX - minX, maxY - minY) * 0.02);
  const left = Math.max(0, minX - pad);
  const top = Math.max(0, minY - pad);
  const cropWidth = Math.min(width - left, maxX - minX + 1 + pad * 2);
  const cropHeight = Math.min(height - top, maxY - minY + 1 + pad * 2);

  const png = await sharp(withAlpha, { raw: { width, height, channels: 4 } })
    .extract({ left, top, width: cropWidth, height: cropHeight })
    .png()
    .toBuffer();
  return { png, width: cropWidth, height: cropHeight };
}

// ── Composición ──────────────────────────────────────────────────────────────

function backgroundSvg(variant: Variant) {
  const fill = 'solid' in variant.background
    ? variant.background.solid
    : 'url(#g)';
  const defs = 'solid' in variant.background
    ? ''
    : `<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stop-color="${variant.background.from}"/>
        <stop offset="1" stop-color="${variant.background.to}"/>
      </linearGradient></defs>`;
  return Buffer.from(
    `<svg xmlns="http://www.w3.org/2000/svg" width="${CANVAS}" height="${CANVAS}">${defs}
      <rect width="100%" height="100%" fill="${fill}"/></svg>`,
  );
}

function contactShadowSvg(cx: number, baseY: number, productWidth: number, opacity: number) {
  const rx = Math.round(productWidth * 0.42);
  const ry = Math.max(8, Math.round(CANVAS * 0.025));
  return Buffer.from(
    `<svg xmlns="http://www.w3.org/2000/svg" width="${CANVAS}" height="${CANVAS}">
      <defs><radialGradient id="s">
        <stop offset="0" stop-color="#2A1F24" stop-opacity="${opacity}"/>
        <stop offset="1" stop-color="#2A1F24" stop-opacity="0"/>
      </radialGradient></defs>
      <ellipse cx="${cx}" cy="${baseY}" rx="${rx}" ry="${ry}" fill="url(#s)"/></svg>`,
  );
}

async function compose(product: CroppedProduct, variant: Variant): Promise<Buffer> {
  const box = Math.round(CANVAS * 0.72);
  const scale = Math.min(box / product.width, box / product.height);
  const w = Math.max(1, Math.round(product.width * scale));
  const h = Math.max(1, Math.round(product.height * scale));
  const left = Math.round((CANVAS - w) / 2);
  // Un poco por encima del centro: deja aire para la sombra.
  const top = Math.round(CANVAS * 0.47 - h / 2);

  const resized = await sharp(product.png).resize(w, h).png().toBuffer();
  const layers: OverlayOptions[] = [];

  if (variant.contactShadow) {
    layers.push({ input: contactShadowSvg(CANVAS / 2, top + h, w, variant.contactShadow), left: 0, top: 0 });
  }

  if (variant.shadow) {
    const { color, opacity, blur, dy } = variant.shadow;
    const alpha = await sharp(resized).extractChannel(3).raw().toBuffer();
    const shape = Buffer.alloc(w * h * 4);
    for (let i = 0; i < w * h; i++) {
      shape[i * 4] = color[0];
      shape[i * 4 + 1] = color[1];
      shape[i * 4 + 2] = color[2];
      shape[i * 4 + 3] = Math.round(alpha[i] * opacity);
    }
    const shadowLayer = await sharp({
      create: { width: CANVAS, height: CANVAS, channels: 4, background: { r: 0, g: 0, b: 0, alpha: 0 } },
    })
      .composite([{
        input: shape,
        raw: { width: w, height: h, channels: 4 },
        left,
        top: Math.min(CANVAS - h, Math.max(0, top + dy)),
      }])
      .png()
      .toBuffer();
    layers.push({ input: await sharp(shadowLayer).blur(blur).png().toBuffer(), left: 0, top: 0 });
  }

  layers.push({ input: resized, left, top });

  return sharp(backgroundSvg(variant))
    .composite(layers)
    .flatten({ background: '#FFFFFF' })
    .jpeg({ quality: 86, mozjpeg: true })
    .toBuffer();
}
