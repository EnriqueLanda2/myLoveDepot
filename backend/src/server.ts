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
import { FileValidationError, validateAndSanitizeMedia } from './security-validator.js';
import { AiError, analyzeProductImage } from './ai.js';
import { mediaStorage, storeProductMedia, uploadsDir } from './media-storage.js';
import { generateProductPhotos } from './product-photos.js';

const required = [
  'DATABASE_URL', 'JWT_SECRET', 'WIFEY_PASSWORD', 'HUSBAND_PASSWORD',
  // Con MEDIA_STORAGE=local las fotos se guardan en disco y Cloudinary sobra.
  ...(mediaStorage === 'cloudinary'
    ? ['CLOUDINARY_CLOUD_NAME', 'CLOUDINARY_API_KEY', 'CLOUDINARY_API_SECRET']
    : []),
];
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
if (mediaStorage === 'local') {
  app.use('/uploads', express.static(uploadsDir, { maxAge: '7d', fallthrough: false }));
}

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
  category: z.string().trim().min(1).max(100),
  price: z.number().nonnegative(),
  stock: z.number().int().nonnegative(),
  minimumStock: z.number().int().nonnegative(),
  imageUrl: z.string().url().or(z.literal('')).optional().default(''),
  imageUrls: z.array(z.string().url()).max(5).optional().default([]),
  shade: z.string().trim().max(120).optional().default(''),
  cost: z.number().nonnegative().optional().default(0),
  description: z.string().max(2000).optional().default(''),
  tags: z.array(z.string().trim().min(1).max(40)).max(12).optional().default([]),
});

app.get('/api/products', async (request, response) => {
  const page = Math.max(1, Number(request.query.page ?? 1));
  const limit = Math.max(1, Math.min(100, Number(request.query.limit ?? 30)));
  const offset = (page - 1) * limit;

  const category = (request.query.category as string | undefined)?.trim();
  const search = (request.query.search as string | undefined)?.trim();
  const lowStock = request.query.lowStock === 'true' || request.query.lowStock === '1';

  const whereConditions: string[] = [];
  const params: unknown[] = [];

  if (category && category.toLowerCase() !== 'todas' && category.toLowerCase() !== 'todas las categorías') {
    whereConditions.push('category = ?');
    params.push(category);
  }

  if (search) {
    whereConditions.push('(name LIKE ? OR sku LIKE ? OR shade LIKE ?)');
    const q = `%${search}%`;
    params.push(q, q, q);
  }

  if (lowStock) {
    whereConditions.push('stock <= minimum_stock');
  }

  const whereClause = whereConditions.length > 0 ? `WHERE ${whereConditions.join(' AND ')}` : '';

  const [countRows] = await pool.query<mysql.RowDataPacket[]>(
    `SELECT COUNT(*) total FROM products ${whereClause}`,
    params,
  );
  const total = Number(countRows[0]?.total ?? 0);

  const isPaginatedRequest = request.query.page !== undefined || request.query.paginated === 'true';
  const queryLimit = request.query.limit === undefined && !isPaginatedRequest ? 5000 : limit;
  const queryOffset = !isPaginatedRequest && request.query.page === undefined ? 0 : offset;

  const [rows] = await pool.query<mysql.RowDataPacket[]>(`
    SELECT id, name, sku, category, shade,
      CAST(price AS DOUBLE) price, CAST(cost AS DOUBLE) cost,
      stock, minimum_stock minimumStock,
      COALESCE(description, '') description, COALESCE(tags, '[]') tags,
      COALESCE(image_url, '') imageUrl, COALESCE(model_url, '') modelUrl
    FROM products ${whereClause} ORDER BY name LIMIT ? OFFSET ?
  `, [...params, queryLimit, queryOffset]);

  const productIds = rows.map((r) => r.id);
  const byProduct = new Map<string, string[]>();
  if (productIds.length > 0) {
    const [images] = await pool.query<mysql.RowDataPacket[]>(
      `SELECT product_id productId, image_url imageUrl FROM product_images
       WHERE product_id IN (?) ORDER BY product_id, view_index`,
      [productIds],
    );
    for (const image of images) {
      const list = byProduct.get(String(image.productId)) ?? [];
      list.push(String(image.imageUrl));
      byProduct.set(String(image.productId), list);
    }
  }

  const products = rows.map((row) => ({
    ...row,
    tags: parseTags(row.tags),
    imageUrls: byProduct.get(String(row.id)) ?? [],
  }));

  if (isPaginatedRequest) {
    response.json({
      products,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    });
  } else {
    response.json(products);
  }
});

app.post('/api/products', async (request, response) => {
  const parsed = productSchema.parse(request.body);
  // Una categoría escrita desde el formulario queda registrada al vuelo, para que
  // el desplegable la ofrezca la próxima vez.
  await pool.execute('INSERT IGNORE INTO categories (id, name) VALUES (?, ?)',
    [randomUUID(), parsed.category]);
  await pool.execute(
    `INSERT INTO products
      (id, name, sku, category, shade, price, cost, stock, minimum_stock,
       description, tags, image_url)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULLIF(?, ''))
     ON DUPLICATE KEY UPDATE name=VALUES(name), sku=VALUES(sku),
       category=VALUES(category), shade=VALUES(shade), price=VALUES(price),
       cost=VALUES(cost), stock=VALUES(stock), minimum_stock=VALUES(minimum_stock),
       description=VALUES(description), tags=VALUES(tags),
       image_url=COALESCE(VALUES(image_url), image_url)`,
    [parsed.id, parsed.name, parsed.sku, parsed.category, parsed.shade, parsed.price,
      parsed.cost, parsed.stock, parsed.minimumStock, parsed.description,
      JSON.stringify(parsed.tags), parsed.imageUrl],
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

app.get('/api/movements', async (request, response) => {
  const limit = Math.max(1, Math.min(500, Number(request.query.limit ?? 200)));
  const offset = Math.max(0, Number(request.query.offset ?? 0));

  // Los movimientos antiguos no guardaban precio ni costo; para ellos se usa
  // el valor actual del producto.
  const [rows] = await pool.query<mysql.RowDataPacket[]>(`
    SELECT CAST(m.id AS CHAR) id, m.product_id productId, p.name productName,
      COALESCE(p.shade, '') productShade, m.type, m.quantity,
      CAST(COALESCE(m.unit_price, p.price, 0) AS DOUBLE) unitPrice,
      CAST(COALESCE(m.unit_cost, p.cost, 0) AS DOUBLE) unitCost,
      m.note, m.created_at createdAt
    FROM stock_movements m
    LEFT JOIN products p ON p.id = m.product_id
    ORDER BY m.created_at DESC, m.id DESC
    LIMIT ? OFFSET ?
  `, [limit, offset]);

  const [countRows] = await pool.query<mysql.RowDataPacket[]>(
    'SELECT COUNT(*) total FROM stock_movements',
  );
  const total = Number(countRows[0]?.total ?? 0);

  response.json({
    movements: rows.map((row) => ({
      id: String(row.id),
      productId: row.productId,
      productName: row.productName ?? 'Producto eliminado',
      productShade: row.productShade ?? '',
      type: row.type,
      quantity: Number(row.quantity),
      unitPrice: Number(row.unitPrice ?? 0),
      unitCost: Number(row.unitCost ?? 0),
      note: row.note ?? '',
      createdAt: row.createdAt,
    })),
    total,
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
      'SELECT stock, price, cost FROM products WHERE id = ? FOR UPDATE',
      [request.params.id],
    );
    if (rows.length === 0) {
      await connection.rollback();
      response.status(404).json({ error: 'Producto no encontrado' });
      return;
    }
    const delta = movement.type === 'incoming' ? movement.quantity : -movement.quantity;
    // Regla de negocio: una salida nunca puede dejar el stock en negativo.
    if (Number(rows[0].stock) + delta < 0) {
      await connection.rollback();
      response.status(409).json({
        error: `Existencias insuficientes: solo hay ${rows[0].stock} disponible(s).`,
      });
      return;
    }
    await connection.execute('UPDATE products SET stock = stock + ? WHERE id = ?', [delta, request.params.id]);
    // El precio y el costo se congelan en el movimiento: la ganancia de una venta
    // no cambia si después se edita el producto.
    const [inserted] = await connection.execute<mysql.ResultSetHeader>(
      `INSERT INTO stock_movements (product_id, type, quantity, note, unit_price, unit_cost)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [request.params.id, movement.type, movement.quantity, movement.note,
        rows[0].price, rows[0].cost],
    );
    await connection.commit();
    response.json({
      id: String(inserted.insertId),
      stock: Number(rows[0].stock) + delta,
      unitPrice: Number(rows[0].price),
      unitCost: Number(rows[0].cost),
    });
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
});

const expenseSchema = z.object({
  amount: z.number().positive(),
  category: z.string().trim().min(1).max(100),
  note: z.string().trim().max(255).optional().default(''),
});

app.get('/api/expenses', async (_request, response) => {
  const [rows] = await pool.query<mysql.RowDataPacket[]>(`
    SELECT CAST(id AS CHAR) id, CAST(amount AS DOUBLE) amount, category, note,
      created_at createdAt
    FROM personal_expenses ORDER BY created_at DESC, id DESC LIMIT 2000
  `);
  response.json(rows.map((row) => ({ ...row, amount: Number(row.amount) })));
});

app.post('/api/expenses', async (request, response) => {
  const expense = expenseSchema.parse(request.body);
  const [result] = await pool.execute<mysql.ResultSetHeader>(
    'INSERT INTO personal_expenses (amount, category, note) VALUES (?, ?, ?)',
    [expense.amount, expense.category, expense.note],
  );
  response.status(201).json({ id: String(result.insertId) });
});

app.delete('/api/expenses/:id', async (request, response) => {
  const id = z.coerce.number().int().positive().parse(request.params.id);
  await pool.execute('DELETE FROM personal_expenses WHERE id = ?', [id]);
  response.status(204).send();
});

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 25 * 1024 * 1024, files: 1, fields: 4 },
});

async function handleMediaUpload(request: Request, response: Response) {
  const file = request.file;
  if (!file) {
    response.status(400).json({ error: 'Falta un archivo multimedia válido (imagen o video)' });
    return;
  }
  const productId = z.string().min(1).max(64).parse(request.body.productId);
  const viewIndex = z.coerce.number().int().min(0).max(10).parse(request.body.viewIndex ?? 0);

  // Validación estricta: Magic Bytes, corrupción, escaneo de código malicioso y re-codificación limpia
  const validated = await validateAndSanitizeMedia(file.buffer, file.originalname);

  const isVideo = validated.mediaType === 'video';
  const stored = await storeProductMedia(validated.safeBuffer, {
    productId,
    publicId: `${productId}/media-${viewIndex}-${Date.now()}`,
    isVideo,
    format: validated.format,
  });
  const result = { secure_url: stored.url, public_id: stored.publicId };

  await pool.execute(
    `INSERT INTO product_images (product_id, view_index, image_url, image_public_id)
     VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE image_url=VALUES(image_url), image_public_id=VALUES(image_public_id)`,
    [productId, viewIndex, result.secure_url, result.public_id],
  );

  if (viewIndex === 0) {
    await pool.execute('UPDATE products SET image_url = ?, image_public_id = ? WHERE id = ?',
      [result.secure_url, result.public_id, productId]);
  }

  response.status(201).json({
    url: result.secure_url,
    publicId: result.public_id,
    mediaType: validated.mediaType,
    format: validated.format,
  });
}

app.post('/api/uploads/product-image', upload.single('image'), handleMediaUpload);
app.post('/api/uploads/product-media', upload.single('media'), handleMediaUpload);

// ── IA ────────────────────────────────────────────────────────────────────────

async function readAiImage(request: Request) {
  if (!request.file) throw new FileValidationError('Falta la foto del producto.');
  const validated = await validateAndSanitizeMedia(request.file.buffer, request.file.originalname);
  if (validated.mediaType !== 'image') throw new FileValidationError('La IA solo analiza fotos.');
  return validated.safeBuffer;
}

app.post('/api/ai/analyze-product', upload.single('image'), async (request, response) => {
  const image = await readAiImage(request);
  // La lista de categorías sale de la base de datos, no del cliente.
  const [rows] = await pool.query<mysql.RowDataPacket[]>('SELECT name FROM categories ORDER BY name');
  const analysis = await analyzeProductImage(image, rows.map((row) => String(row.name)));
  response.json(analysis);
});

app.post('/api/ai/product-photos', upload.single('image'), async (request, response) => {
  const image = await readAiImage(request);
  const set = z.coerce.number().int().min(0).max(100).catch(0).parse(request.body?.set);
  response.json(await generateProductPhotos(image, set));
});

app.use((error: unknown, _request: Request, response: Response, _next: NextFunction) => {
  console.error(error);
  if (error instanceof z.ZodError) {
    response.status(400).json({ error: 'Datos inválidos', details: error.issues });
    return;
  }
  if (error instanceof FileValidationError) {
    response.status(400).json({ error: error.message });
    return;
  }
  if (error instanceof multer.MulterError) {
    response.status(400).json({ error: error.message });
    return;
  }
  if (error instanceof AiError) {
    response.status(error.status).json({ error: error.message });
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

function parseTags(value: unknown): string[] {
  if (Array.isArray(value)) return value.map(String);
  try {
    const parsed = JSON.parse(String(value ?? '[]'));
    return Array.isArray(parsed) ? parsed.map(String) : [];
  } catch {
    return [];
  }
}

const port = Number(process.env.PORT ?? 3000);
app.listen(port, '0.0.0.0', () => console.log(`API escuchando en el puerto ${port}`));
