import 'dotenv/config';

import { v2 as cloudinary } from 'cloudinary';
import cors from 'cors';
import express, { type NextFunction, type Request, type Response } from 'express';
import multer from 'multer';
import mysql from 'mysql2/promise';
import { z } from 'zod';

const required = ['DATABASE_URL', 'CLOUDINARY_CLOUD_NAME', 'CLOUDINARY_API_KEY', 'CLOUDINARY_API_SECRET', 'INVENTORY_API_KEY'] as const;
for (const key of required) {
  if (!process.env[key]) throw new Error(`Falta la variable ${key}`);
}

const pool = mysql.createPool({
  uri: process.env.DATABASE_URL,
  connectionLimit: 8,
  enableKeepAlive: true,
  ssl: process.env.DATABASE_URL?.includes('localhost') ? undefined : {},
});

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
  secure: true,
});

const app = express();
const allowedOrigins = (process.env.ALLOWED_ORIGINS ?? '').split(',').map((item) => item.trim()).filter(Boolean);
app.use(cors({ origin: allowedOrigins.length === 0 ? false : allowedOrigins }));
app.use(express.json({ limit: '1mb' }));

app.get('/health', async (_request, response) => {
  await pool.query('SELECT 1');
  response.json({ status: 'ok' });
});

app.use('/api', (request, response, next) => {
  if (request.header('x-api-key') !== process.env.INVENTORY_API_KEY) {
    response.status(401).json({ error: 'No autorizado' });
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
  modelUrl: z.string().url().or(z.literal('')).optional().default(''),
});

app.get('/api/products', async (_request, response) => {
  const [rows] = await pool.query(`
    SELECT id, name, sku, COALESCE(barcode, '') barcode, category,
      CAST(price AS DOUBLE) price, stock, minimum_stock minimumStock,
      COALESCE(image_url, '') imageUrl, COALESCE(model_url, '') modelUrl
    FROM products ORDER BY name
  `);
  response.json(rows);
});

app.post('/api/products', async (request, response) => {
  const parsed = productSchema.parse(request.body);
  await pool.execute(
    `INSERT INTO products
      (id, name, sku, barcode, category, price, stock, minimum_stock, image_url, model_url)
     VALUES (?, ?, ?, NULLIF(?, ''), ?, ?, ?, ?, NULLIF(?, ''), NULLIF(?, ''))
     ON DUPLICATE KEY UPDATE name=VALUES(name), sku=VALUES(sku),
       barcode=VALUES(barcode), category=VALUES(category), price=VALUES(price),
       stock=VALUES(stock), minimum_stock=VALUES(minimum_stock),
       image_url=VALUES(image_url), model_url=VALUES(model_url)`,
    [parsed.id, parsed.name, parsed.sku, parsed.barcode, parsed.category, parsed.price,
      parsed.stock, parsed.minimumStock, parsed.imageUrl, parsed.modelUrl],
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
  limits: { fileSize: 8 * 1024 * 1024 },
  fileFilter: (_request, file, callback) => {
    callback(null, ['image/jpeg', 'image/png', 'image/webp', 'image/heic'].includes(file.mimetype));
  },
});

app.post('/api/uploads/product-image', upload.single('image'), async (request, response) => {
  if (!request.file) {
    response.status(400).json({ error: 'Falta una imagen válida' });
    return;
  }
  const productId = z.string().min(1).max(64).parse(request.body.productId);
  const result = await new Promise<{ secure_url: string; public_id: string }>((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(
      { folder: 'my-love-depot/products', public_id: productId, overwrite: true, resource_type: 'image' },
      (error, uploaded) => {
        if (error || !uploaded) reject(error ?? new Error('Cloudinary no respondió'));
        else resolve(uploaded);
      },
    );
    stream.end(request.file!.buffer);
  });
  await pool.execute(
    'UPDATE products SET image_url = ?, image_public_id = ? WHERE id = ?',
    [result.secure_url, result.public_id, productId],
  );
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
