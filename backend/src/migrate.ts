import 'dotenv/config';

import { readFile } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import mysql from 'mysql2/promise';

import { databaseSsl } from './database-config.js';

if (!process.env.DATABASE_URL) throw new Error('Falta la variable DATABASE_URL');

const connection = await mysql.createConnection({
  uri: process.env.DATABASE_URL,
  multipleStatements: true,
  ssl: databaseSsl(process.env.DATABASE_URL),
});

// MySQL no acepta ADD COLUMN IF NOT EXISTS, así que las columnas que llegaron
// después del esquema original se comprueban antes de añadirlas.
const addedColumns: Array<[string, string, string]> = [
  ['products', 'model_public_id', 'VARCHAR(255) NULL'],
  ['products', 'model_built_at', 'TIMESTAMP NULL'],
];

async function ensureColumn(table: string, column: string, definition: string) {
  const [rows] = await connection.query<mysql.RowDataPacket[]>(
    `SELECT 1 FROM information_schema.columns
     WHERE table_schema = DATABASE() AND table_name = ? AND column_name = ?`,
    [table, column],
  );
  if (rows.length === 0) {
    await connection.query(`ALTER TABLE \`${table}\` ADD COLUMN \`${column}\` ${definition}`);
    console.log(`Columna ${table}.${column} agregada.`);
  }
}

try {
  const schema = await readFile(new URL('../schema.sql', import.meta.url), 'utf8');
  await connection.query(schema);
  for (const [table, column, definition] of addedColumns) {
    await ensureColumn(table, column, definition);
  }

  // Las categorías existían solo como texto dentro de cada producto; se registran
  // para que el catálogo quede completo desde la primera ejecución.
  const [pending] = await connection.query<mysql.RowDataPacket[]>(
    `SELECT DISTINCT p.category FROM products p
     LEFT JOIN categories c ON c.name = p.category
     WHERE c.id IS NULL AND p.category <> ''`,
  );
  for (const row of pending) {
    await connection.execute(
      'INSERT IGNORE INTO categories (id, name) VALUES (?, ?)',
      [randomUUID(), row.category],
    );
  }
  if (pending.length > 0) {
    console.log(`${pending.length} categoría(s) registradas a partir de los productos.`);
  }

  console.log('Esquema MySQL actualizado.');
} finally {
  await connection.end();
}
