import 'dotenv/config';
import mysql from 'mysql2/promise';
import { databaseSsl } from './database-config.js';

async function main() {
  if (!process.env.DATABASE_URL) {
    console.error('Falta la variable DATABASE_URL');
    process.exit(1);
  }

  const pool = mysql.createPool({
    uri: process.env.DATABASE_URL,
    waitForConnections: true,
    connectionLimit: 5,
    ssl: databaseSsl(process.env.DATABASE_URL!),
  });

  try {
    await pool.query('SET FOREIGN_KEY_CHECKS = 0;');
    console.log('Clearing stock_movements...');
    await pool.query('TRUNCATE TABLE stock_movements;');
    console.log('Clearing products...');
    await pool.query('TRUNCATE TABLE products;');
    console.log('Clearing categories...');
    await pool.query('TRUNCATE TABLE categories;');
    await pool.query('SET FOREIGN_KEY_CHECKS = 1;');
    console.log('Database cleared successfully!');
  } catch (e) {
    console.error('Error clearing database:', e);
  } finally {
    await pool.end();
  }
}

main();
