import 'dotenv/config';

import { v2 as cloudinary } from 'cloudinary';
import cors from 'cors';
import { randomUUID, timingSafeEqual } from 'node:crypto';
import express, { type NextFunction, type Request, type Response } from 'express';
import jwt from 'jsonwebtoken';
import multer from 'multer';
import mysql from 'mysql2/promise';
import { z } from 'zod';

import { databaseSsl } from './database-config.js';
import { ModelBuildError, buildModel } from './model-generator.js';
import { ScanQualityError, validateProductScan } from './scan-quality.js';

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
const allowedOrigins = (process.env.ALLOWED_ORIGINS ?? '').split(',').map((item) => item.trim().replace(/\/$/, '')).filter(Boolean);
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

const categorySchema = z.object({
  id: z.string().min(1).max(64).optional(),
  name: z.string().trim().min(1).max(100),
});

app.get('/api/categories', async (_request, response) => {
  const [rows] = await pool.query<mysql.RowDataPacket[]>(`
    SELECT c.id, c.name, COUNT(p.id) productCount
    FROM categories c LEFT JOIN products p ON p.category = c.name
    GROUP BY c.id, c.name ORDER BY c.name
  `);
  response.json(rows.map((row) => ({ ...row, productCount: Number(row.productCount) })));
});

app.post('/api/categories', async (request, response) => {
  const parsed = categorySchema.parse(request.body);
  const [existing] = await pool.query<mysql.RowDataPacket[]>(
    'SELECT id, name FROM categories WHERE name = ?',
    [parsed.name],
  );
  if (existing.length > 0) {
    response.status(200).json({ id: existing[0].id, name: existing[0].name });
    return;
  }
  const id = parsed.id ?? randomUUID();
  await pool.execute('INSERT INTO categories (id, name) VALUES (?, ?)', [id, parsed.name]);
  response.status(201).json({ id, name: parsed.name });
});

app.patch('/api/categories/:id', async (request, response) => {
  const parsed = categorySchema.parse(request.body);
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const [rows] = await connection.execute<mysql.RowDataPacket[]>(
      'SELECT name FROM categories WHERE id = ? FOR UPDATE',
      [request.params.id],
    );
    if (rows.length === 0) {
      await connection.rollback();
      response.status(404).json({ error: 'La categoría no existe' });
      return;
    }
    // Los productos guardan el nombre, así que el cambio se propaga a mano.
    await connection.execute('UPDATE categories SET name = ? WHERE id = ?',
      [parsed.name, request.params.id]);
    await connection.execute('UPDATE products SET category = ? WHERE category = ?',
      [parsed.name, rows[0].name]);
    await connection.commit();
    response.json({ id: request.params.id, name: parsed.name });
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
});

app.delete('/api/categories/:id', async (request, response) => {
  const [rows] = await pool.query<mysql.RowDataPacket[]>(
    `SELECT c.name, COUNT(p.id) total FROM categories c
     LEFT JOIN products p ON p.category = c.name
     WHERE c.id = ? GROUP BY c.name`,
    [request.params.id],
  );
  if (rows.length > 0 && Number(rows[0].total) > 0) {
    response.status(409).json({
      error: `“${rows[0].name}” tiene ${rows[0].total} producto(s). Muévelos antes de eliminarla.`,
    });
    return;
  }
  await pool.execute('DELETE FROM categories WHERE id = ?', [request.params.id]);
  response.status(204).send();
});

const productSchema = z.object({
  id: z.string().min(1).max(64),
  name: z.string().min(1).max(160),
  sku: z.string().min(1).max(80),
  barcode: z.string().max(120).optional().default(''),
  category: z.string().trim().min(1).max(100),
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
      COALESCE(image_url, '') imageUrl, COALESCE(model_url, '') modelUrl
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
  // Una categoría escrita desde el formulario queda registrada al vuelo, para que
  // el desplegable la ofrezca la próxima vez.
  await pool.execute('INSERT IGNORE INTO categories (id, name) VALUES (?, ?)',
    [randomUUID(), parsed.category]);
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

app.post('/api/products/:id/model', async (request, response) => {
  const productId = request.params.id;
  const [products] = await pool.query<mysql.RowDataPacket[]>(
    'SELECT id FROM products WHERE id = ?', [productId],
  );
  if (products.length === 0) {
    response.status(404).json({ error: 'Producto no encontrado' });
    return;
  }
  const [images] = await pool.query<mysql.RowDataPacket[]>(
    `SELECT view_index viewIndex, image_url imageUrl FROM product_images
     WHERE product_id = ? ORDER BY view_index`,
    [productId],
  );
  if (images.length === 0) {
    response.status(400).json({
      error: 'Sube al menos una fotografía antes de generar el modelo.',
    });
    return;
  }

  const { glb, report, render } = await buildModel(images.map((row) => ({
    viewIndex: Number(row.viewIndex),
    imageUrl: String(row.imageUrl),
  })));

  const uploadPromises: Promise<{ secure_url: string; public_id: string }>[] = [];
  
  // Upload GLB
  uploadPromises.push(new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(
      {
        folder: 'my-love-depot/models',
        public_id: `${productId}/model.glb`,
        resource_type: 'raw',
        overwrite: true,
      },
      (error, result) => {
        if (error || !result) reject(error ?? new Error('Cloudinary no respondió al subir GLB'));
        else resolve(result);
      },
    );
    stream.end(glb);
  }));

  // Upload Render if it exists
  if (render) {
    uploadPromises.push(new Promise((resolve, reject) => {
      const stream = cloudinary.uploader.upload_stream(
        {
          folder: 'my-love-depot/renders',
          public_id: `${productId}/render`,
          resource_type: 'image',
          format: 'png',
          overwrite: true,
        },
        (error, result) => {
          if (error || !result) reject(error ?? new Error('Cloudinary no respondió al subir el render'));
          else resolve(result);
        },
      );
      stream.end(render);
    }));
  }

  const results = await Promise.all(uploadPromises);
  const uploadedGlb = results[0];
  const uploadedRender = render && results.length > 1 ? results[1] : null;

  if (uploadedRender) {
    await pool.execute(
      `UPDATE products SET model_url = ?, model_public_id = ?, render_url = ?, render_public_id = ?, model_built_at = NOW()
       WHERE id = ?`,
      [uploadedGlb.secure_url, uploadedGlb.public_id, uploadedRender.secure_url, uploadedRender.public_id, productId],
    );
  } else {
    await pool.execute(
      `UPDATE products SET model_url = ?, model_public_id = ?, model_built_at = NOW()
       WHERE id = ?`,
      [uploadedGlb.secure_url, uploadedGlb.public_id, productId],
    );
  }

  response.status(201).json({ 
    modelUrl: uploadedGlb.secure_url, 
    renderUrl: uploadedRender?.secure_url ?? null,
    ...report 
  });
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
  let scanMetrics;
  try {
    const validated = await validateProductScan(request.file.buffer);
    safeImage = validated.safeImage;
    scanMetrics = validated.metrics;
  } catch (error) {
    response.status(400).json({
      error: error instanceof ScanQualityError
        ? error.message
        : 'El archivo no es una imagen JPEG, PNG o WebP real y válida',
    });
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
  response.status(201).json({
    url: result.secure_url,
    publicId: result.public_id,
    scanQuality: scanMetrics,
  });
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
  if (error instanceof ModelBuildError) {
    response.status(422).json({ error: error.message });
    return;
  }
  if ((error as { code?: string }).code === 'ER_DUP_ENTRY') {
    response.status(409).json({ error: 'Ese nombre ya está registrado' });
    return;
  }
  response.status(500).json({ error: 'Error interno' });
});

const port = Number(process.env.PORT ?? 3000);
app.listen(port, '0.0.0.0', () => console.log(`API escuchando en el puerto ${port}`));
