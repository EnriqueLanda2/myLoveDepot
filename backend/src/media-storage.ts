import { v2 as cloudinary } from 'cloudinary';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';

/**
 * Dónde se guardan las fotos de los productos.
 *
 * - `cloudinary` (por omisión): producción. Requiere las tres credenciales.
 * - `local`: desarrollo sin cuenta de Cloudinary. Los archivos quedan en
 *   `backend/uploads` y la propia API los sirve en `/uploads`. No sirve en
 *   Render, cuyo disco se borra en cada despliegue.
 */
export const mediaStorage = process.env.MEDIA_STORAGE === 'local' ? 'local' : 'cloudinary';

export const uploadsDir = path.resolve(process.cwd(), 'uploads');

const publicBaseUrl = () =>
  (process.env.PUBLIC_API_URL ?? `http://localhost:${process.env.PORT ?? 3000}`).replace(/\/$/, '');

export interface StoredMedia {
  url: string;
  publicId: string;
}

export async function storeProductMedia(
  buffer: Buffer,
  { productId, publicId, isVideo, format }: {
    productId: string;
    publicId: string;
    isVideo: boolean;
    format: string;
  },
): Promise<StoredMedia> {
  if (mediaStorage === 'local') {
    // El id llega validado, pero se limpia igual para que nunca salga de la carpeta.
    const safeProduct = productId.replace(/[^A-Za-z0-9_-]/g, '_');
    const fileName = `${path.basename(publicId).replace(/[^A-Za-z0-9_-]/g, '_')}.${format}`;
    const dir = path.join(uploadsDir, 'products', safeProduct);
    await mkdir(dir, { recursive: true });
    await writeFile(path.join(dir, fileName), buffer);
    const relative = `products/${safeProduct}/${fileName}`;
    return { url: `${publicBaseUrl()}/uploads/${relative}`, publicId: `local:${relative}` };
  }

  const result = await new Promise<{ secure_url: string; public_id: string }>((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(
      {
        folder: 'my-love-depot/products',
        public_id: publicId,
        overwrite: true,
        resource_type: isVideo ? 'video' : 'image',
        ...(isVideo ? {} : { format: 'webp' }),
      },
      (error, uploaded) => {
        if (error || !uploaded) reject(error ?? new Error('Cloudinary no respondió'));
        else resolve(uploaded);
      },
    );
    stream.end(buffer);
  });
  return { url: result.secure_url, publicId: result.public_id };
}
