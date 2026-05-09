import { neon } from '@neondatabase/serverless';

if (!process.env.DATABASE_URL) {
  throw new Error('Missing environment variable: DATABASE_URL');
}

export const sql = neon(process.env.DATABASE_URL);
