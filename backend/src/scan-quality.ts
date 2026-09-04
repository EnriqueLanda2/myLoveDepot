import sharp from 'sharp';

const MIN_SIDE = 640;
const ANALYSIS_SIZE = 160;
const BORDER_SIZE = 8;
const MIN_SHARPNESS = 0.8;
const MIN_FOREGROUND = 0.08;
const MAX_FOREGROUND = 0.82;

export type ScanMetrics = {
  width: number;
  height: number;
  brightness: number;
  sharpness: number;
  coverage: number;
};

export class ScanQualityError extends Error {}

/**
 * Verifica que la foto permita recortar una silueta útil antes de almacenarla.
 * No intenta reconocer el producto: exige condiciones fotográficas medibles.
 */
export async function validateProductScan(input: Buffer) {
  const source = sharp(input, { failOn: 'error', limitInputPixels: 25_000_000 });
  const metadata = await source.metadata();
  if (!metadata.width || !metadata.height ||
      !['jpeg', 'png', 'webp'].includes(metadata.format ?? '')) {
    throw new ScanQualityError('Usa una foto JPEG, PNG o WebP válida.');
  }
  if (metadata.width < 64 || metadata.height < 64) {
    throw new ScanQualityError('La imagen es demasiado pequeña para procesarla.');
  }

  const oriented = sharp(input, { failOn: 'error', limitInputPixels: 25_000_000 })
    .rotate()
    .removeAlpha()
    .toColourspace('srgb');
  const stats = await oriented.clone().greyscale().stats();
  const brightness = stats.channels[0]?.mean ?? 128;

  const sample = await oriented.clone()
    .resize({ width: ANALYSIS_SIZE, height: ANALYSIS_SIZE, fit: 'inside' })
    .raw()
    .toBuffer({ resolveWithObject: true });
  const shape = foregroundShape(sample.data, sample.info.width, sample.info.height);

  const safeImage = await oriented
    .resize({ width: 1600, height: 1600, fit: 'inside', withoutEnlargement: true })
    .webp({ quality: 86 })
    .toBuffer();
  const metrics: ScanMetrics = {
    width: metadata.width,
    height: metadata.height,
    brightness: round(brightness),
    sharpness: round(stats.sharpness),
    coverage: round(shape.coverage),
  };
  return { safeImage, metrics };
}

function foregroundShape(data: Buffer, width: number, height: number) {
  const border: number[][] = [];
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      if (x < BORDER_SIZE || y < BORDER_SIZE ||
          x >= width - BORDER_SIZE || y >= height - BORDER_SIZE) {
        const offset = (y * width + x) * 3;
        border.push([data[offset], data[offset + 1], data[offset + 2]]);
      }
    }
  }
  const background = [0, 1, 2].map((channel) =>
    border.reduce((sum, pixel) => sum + pixel[channel], 0) / border.length,
  );
  const borderSpread = Math.sqrt(border.reduce((sum, pixel) =>
    sum + colourDistance(pixel, background) ** 2, 0) / border.length);
  const threshold = Math.max(28, borderSpread * 2.2);

  let count = 0;
  let sumDistance = 0;
  let minX = width;
  let minY = height;
  let maxX = -1;
  let maxY = -1;
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const offset = (y * width + x) * 3;
      const distance = colourDistance(
        [data[offset], data[offset + 1], data[offset + 2]], background,
      );
      if (distance < threshold) continue;
      count++;
      sumDistance += distance;
      minX = Math.min(minX, x);
      minY = Math.min(minY, y);
      maxX = Math.max(maxX, x);
      maxY = Math.max(maxY, y);
    }
  }
  const coverage = count / (width * height);
  return {
    coverage,
    contrast: count === 0 ? 0 : sumDistance / count,
    centerX: count === 0 ? 0.5 : (minX + maxX + 1) / (2 * width),
    centerY: count === 0 ? 0.5 : (minY + maxY + 1) / (2 * height),
    touchesEdge: minX < BORDER_SIZE / 2 || minY < BORDER_SIZE / 2 ||
      maxX >= width - BORDER_SIZE / 2 || maxY >= height - BORDER_SIZE / 2,
  };
}

function colourDistance(pixel: number[], other: number[]) {
  return Math.sqrt(pixel.reduce((sum, value, index) =>
    sum + (value - other[index]) ** 2, 0));
}

function round(value: number) {
  return Math.round(value * 1000) / 1000;
}
