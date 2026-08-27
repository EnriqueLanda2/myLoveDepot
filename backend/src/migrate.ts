import 'dotenv/config';

import { readFile } from 'node:fs/promises';
import mysql from 'mysql2/promise';

if (!process.env.DATABASE_URL) throw new Error('Falta la variable DATABASE_URL');

const connection = await mysql.createConnection({
  uri: process.env.DATABASE_URL,
  multipleStatements: true,
  ssl: process.env.DATABASE_URL.includes('localhost') ? undefined : {},
});

try {
  const schemaUrl = new URL('../schema.sql', import.meta.url);
  const schema = await readFile(schemaUrl, 'utf8');
  await connection.query(schema);
  console.log('Esquema MySQL actualizado.');
} finally {
  await connection.end();
}
