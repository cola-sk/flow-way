/**
 * 初始化 event_logs 表
 * 运行: pnpm tsx scripts/init-db.ts
 */
import { neon } from '@neondatabase/serverless';
import { config } from 'dotenv';
config({ path: '.env.local' });

const sql = neon(process.env.DATABASE_URL!);

await sql`
  CREATE TABLE IF NOT EXISTS event_logs (
    id          BIGSERIAL PRIMARY KEY,
    event       TEXT        NOT NULL,
    user_token  TEXT,
    ip          TEXT,
    user_agent  TEXT,
    data        JSONB,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
  )
`;

await sql`CREATE INDEX IF NOT EXISTS idx_event_logs_event      ON event_logs (event)`;
await sql`CREATE INDEX IF NOT EXISTS idx_event_logs_user_token ON event_logs (user_token)`;
await sql`CREATE INDEX IF NOT EXISTS idx_event_logs_created_at ON event_logs (created_at DESC)`;

console.log('✅ event_logs table ready');
