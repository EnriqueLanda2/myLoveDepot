import 'dotenv/config';

import { v2 as cloudinary } from 'cloudinary';
import cors from 'cors';
import { timingSafeEqual } from 'node:crypto';
import express, { type NextFunction, type Request, type Response } from 'express';
import jwt from 'jsonwebtoken';
import multer from 'multer';
import mysql from 'mysql2/promise';
import sharp from 'sharp';
import { z } from 'zod';

import { databaseSsl } from './database-config.js';

const required = [
  'DATABASE_URL', 'CLOUDINARY_CLOUD_NAME', 'CLOUDINARY_API_KEY',
  'CLOUDINARY_API_SECRET', 'JWT_SECRET', 'WIFEY_PASSWORD', 'HUSBAND_PASSWORD',
] as const;
for (const key of required) {
  if (!process.env[key]) throw new Error(`Falta la variable ${key}`);
}

const pool = mysql.createPool({
  uri: process.env.DATABASE_URL,
  connectionLimit: 8,
  enableKeepAlive: true,
  ssl: databaseSsl(process.env.DATABASE_URL!),
});

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
  secure: true,
});

const app = express();
app.set('trust proxy', 1);
const allowedOrigins = (process.env.ALLOWED_ORIGINS ?? '').split(',').map((item) => item.trim()).filter(Boolean);
app.use(cors({ origin: allowedOrigins.length === 0 ? false : allowedOrigins }));
app.use(express.json({ limit: '1mb' }));

app.get('/health', async (_request, response) => {
  await pool.query('SELECT 1');
  response.json({ status: 'ok' });
});

type Role = 'wifey' | 'husband';
type AuthRequest = Request & { user?: { role: Role; username: string } };

const loginSchema = z.object({
  username: z.string().trim().min(1).max(80),
  password: z.string().min(8).max(200),
});
const loginAttempts = new Map<string, { count: number; resetAt: number }>();

function safeEqual(left: string, right: string) {
  const leftBuffer = Buffer.from(left);
  const rightBuffer = Buffer.from(right);
  return leftBuffer.length === rightBuffer.length && timingSafeEqual(leftBuffer, rightBuffer);
}

app.post('/auth/login', (request, response) => {
  const client = request.ip ?? 'unknown';
  const now = Date.now();
  const attempt = loginAttempts.get(client);
  if (attempt && attempt.resetAt > now && attempt.count >= 8) {
    response.status(429).json({ error: 'Demasiados intentos. Espera 15 minutos.' });
    return;
  }
  const credentials = loginSchema.parse(request.body);
  const users = [
    { role: 'wifey' as const, username: process.env.WIFEY_USERNAME ?? 'wifey', password: process.env.WIFEY_PASSWORD! },
    { role: 'husband' as const, username: process.env.HUSBAND_USERNAME ?? 'husband', password: process.env.HUSBAND_PASSWORD! },
  ];
  const user = users.find((candidate) => candidate.username === credentials.username &&
    safeEqual(candidate.password, credentials.password));
  if (!user) {
    loginAttempts.set(client, {
      count: attempt && attempt.resetAt > now ? attempt.count + 1 : 1,
      resetAt: attempt && attempt.resetAt > now ? attempt.resetAt : now + 15 * 60 * 1000,
    });
    response.status(401).json({ error: 'Usuario o contraseña incorrectos' });
    return;
  }
  loginAttempts.delete(client);
  const token = jwt.sign(
    { role: user.role, username: user.username },
    process.env.JWT_SECRET!,
    { algorithm: 'HS256', expiresIn: '12h', subject: user.username },
  );
  response.json({ token, role: user.role, username: user.username, expiresIn: 43200 });
});

app.use('/api', (request: AuthRequest, response, next) => {
  const authorization = request.header('authorization');
  if (!authorization?.startsWith('Bearer ')) {
    response.status(401).json({ error: 'Inicia sesión para continuar' });
    return;
  }
  try {
    const payload = jwt.verify(authorization.slice(7), process.env.JWT_SECRET!, {
      algorithms: ['HS256'],
    }) as { role?: Role; username?: string };
    if (!payload.role || !payload.username || !['wifey', 'husband'].includes(payload.role)) {
      throw new Error('Token sin rol válido');
    }
    request.user = { role: payload.role, username: payload.username };
  } catch {
    response.status(401).json({ error: 'La sesión venció o no es válida' });
    return;
  }
  next();
});

const productSchema = z.object({
  id: z.string().min(1).max(64),
  name: z.string().min(1).max(160),
  sku: z.string().min(1).max(80),
  barcode: z.string().max(120).optional().default(''),
  category: z.string().min(1).max(100),
  price: z.number().nonnegative(),
  stock: z.number().int().nonnegative(),
  minimumStock: z.number().int().nonnegative(),
  imageUrl: z.string().url().or(z.literal('')).optional().default(''),
  imageUrls: z.array(z.string().url()).max(5).optional().default([]),
});

app.get('/api/products', async (_request, response) => {
  const [rows] = await pool.query<mysql.RowDataPacket[]>(`
    SELECT id, name, sku, COALESCE(barcode, '') barcode, category,
      CAST(price AS DOUBLE) price, stock, minimum_stock minimumStock,
      COALESCE(image_url, '') imageUrl
    FROM products ORDER BY name
  `);
  const [images] = await pool.query<mysql.RowDataPacket[]>(
    'SELECT product_id productId, image_url imageUrl FROM product_images ORDER BY product_id, view_index',
  );
  const byProduct = new Map<string, string[]>();
  for (const image of images) {
    const list = byProduct.get(String(image.productId)) ?? [];
    list.push(String(image.imageUrl));
    byProduct.set(String(image.productId), list);
  }
  response.json(rows.map((row) => ({ ...row, imageUrls: byProduct.get(String(row.id)) ?? [] })));
});

app.post('/api/products', async (request, response) => {
  const parsed = productSchema.parse(request.body);
  await pool.execute(
    `INSERT INTO products
      (id, name, sku, barcode, category, price, stock, minimum_stock, image_url)
     VALUES (?, ?, ?, NULLIF(?, ''), ?, ?, ?, ?, NULLIF(?, ''))
     ON DUPLICATE KEY UPDATE name=VALUES(name), sku=VALUES(sku),
       barcode=VALUES(barcode), category=VALUES(category), price=VALUES(price),
       stock=VALUES(stock), minimum_stock=VALUES(minimum_stock), image_url=VALUES(image_url)`,
    [parsed.id, parsed.name, parsed.sku, parsed.barcode, parsed.category, parsed.price,
      parsed.stock, parsed.minimumStock, parsed.imageUrl],
  );
  response.status(200).json({ ok: true });
});

app.delete('/api/products/:id', async (request, response) => {
  await pool.execute('DELETE FROM products WHERE id = ?', [request.params.id]);
  response.status(204).send();
});

const movementSchema = z.object({
  type: z.enum(['incoming', 'outgoing']),
  quantity: z.number().int().positive(),
  note: z.string().max(255).optional().default(''),
});

app.post('/api/products/:id/movements', async (request, response) => {
  const movement = movementSchema.parse(request.body);
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const [rows] = await connection.execute<mysql.RowDataPacket[]>(
      'SELECT stock FROM products WHERE id = ? FOR UPDATE',
      [request.params.id],
    );
    if (rows.length === 0) {
      await connection.rollback();
      response.status(404).json({ error: 'Producto no encontrado' });
      return;
    }
    const delta = movement.type === 'incoming' ? movement.quantity : -movement.quantity;
    if (Number(rows[0].stock) + delta < 0) {
      await connection.rollback();
      response.status(409).json({ error: 'Existencias insuficientes' });
      return;
    }
    await connection.execute('UPDATE products SET stock = stock + ? WHERE id = ?', [delta, request.params.id]);
    await connection.execute(
      'INSERT INTO stock_movements (product_id, type, quantity, note) VALUES (?, ?, ?, ?)',
      [request.params.id, movement.type, movement.quantity, movement.note],
    );
    await connection.commit();
    response.json({ stock: Number(rows[0].stock) + delta });
  } finally {
    connection.release();
  }
});

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 8 * 1024 * 1024, files: 1, fields: 3 },
});

app.post('/api/uploads/product-image', upload.single('image'), async (request, response) => {
  if (!request.file) {
    response.status(400).json({ error: 'Falta una imagen válida' });
    return;
  }
  const productId = z.string().min(1).max(64).parse(request.body.productId);
  const viewIndex = z.coerce.number().int().min(0).max(4).parse(request.body.viewIndex ?? 0);
  let safeImage: Buffer;
  try {
    const metadata = await sharp(request.file.buffer, { failOn: 'error', limitInputPixels: 25_000_000 }).metadata();
    if (!metadata.width || !metadata.height || !['jpeg', 'png', 'webp'].includes(metadata.format ?? '')) {
      throw new Error('Formato de imagen no permitido');
    }
    if (metadata.width < 200 || metadata.height < 200) {
      response.status(400).json({ error: 'La imagen debe medir al menos 200 x 200 píxeles' });
      return;
    }
    safeImage = await sharp(request.file.buffer, { failOn: 'error', limitInputPixels: 25_000_000 })
      .rotate().resize({ width: 1600, height: 1600, fit: 'inside', withoutEnlargement: true })
      .webp({ quality: 84 }).toBuffer();
  } catch {
    response.status(400).json({ error: 'El archivo no es una imagen JPEG, PNG o WebP real y válida' });
    return;
  }
  const result = await new Promise<{ secure_url: string; public_id: string }>((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(
      { folder: 'my-love-depot/products', public_id: `${productId}/view-${viewIndex}`, overwrite: true, resource_type: 'image', format: 'webp' },
      (error, uploaded) => {
        if (error || !uploaded) reject(error ?? new Error('Cloudinary no respondió'));
        else resolve(uploaded);
      },
    );
    stream.end(safeImage);
  });
  await pool.execute(`INSERT INTO product_images (product_id, view_index, image_url, image_public_id)
    VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE image_url=VALUES(image_url), image_public_id=VALUES(image_public_id)`,
  [productId, viewIndex, result.secure_url, result.public_id]);
  if (viewIndex === 0) {
    await pool.execute('UPDATE products SET image_url = ?, image_public_id = ? WHERE id = ?',
      [result.secure_url, result.public_id, productId]);
  }
  response.status(201).json({ url: result.secure_url, publicId: result.public_id });
});

app.use((error: unknown, _request: Request, response: Response, _next: NextFunction) => {
  console.error(error);
  if (error instanceof z.ZodError) {
    response.status(400).json({ error: 'Datos inválidos', details: error.issues });
    return;
  }
  if (error instanceof multer.MulterError) {
    response.status(400).json({ error: error.message });
    return;
  }
  response.status(500).json({ error: 'Error interno' });
});

const port = Number(process.env.PORT ?? 3000);
app.listen(port, '0.0.0.0', () => console.log(`API escuchando en el puerto ${port}`));
