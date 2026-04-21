import { config } from 'dotenv';
import { Redis } from '@upstash/redis';

config({ path: '.env.local' });
config();

const TARGET_TOKEN = process.argv[2] ?? 'liuzhex20190618';
const TOKEN_REGEX = /^[A-Za-z0-9]{16}$/;

const USER_META_HASH_KEY = 'user-config-meta';
const USER_TOKEN_POLICY_HASH_KEY = 'user-token-policies';

const DEFAULT_USER_TOKEN_FIELD = 'default-user-token';
const MIGRATION_FIELDS = [
  'migrated-waypoints-default',
  'migrated-dismissed-cameras-default',
  'migrated-saved-routes-default',
  'migrated-saved-route-plans-default',
  'migrated-recent-navigations-default',
] as const;

type BucketConfig = {
  name: string;
  legacyKey: string;
  userPrefix: string;
};

const BUCKETS: BucketConfig[] = [
  {
    name: 'waypoints',
    legacyKey: 'waypoints',
    userPrefix: 'waypoints:user:',
  },
  {
    name: 'dismissed-cameras',
    legacyKey: 'dismissed-cameras',
    userPrefix: 'dismissed-cameras:user:',
  },
  {
    name: 'saved-routes',
    legacyKey: 'saved-routes',
    userPrefix: 'saved-routes:user:',
  },
  {
    name: 'saved-route-plans',
    legacyKey: 'saved-route-plans',
    userPrefix: 'saved-route-plans:user:',
  },
  {
    name: 'recent-navigations',
    legacyKey: 'recent-navigations',
    userPrefix: 'recent-navigations:user:',
  },
];

function ensureRedis(): Redis {
  const url = process.env.KV_REST_API_URL ?? process.env.UPSTASH_REDIS_REST_URL;
  const token = process.env.KV_REST_API_TOKEN ?? process.env.UPSTASH_REDIS_REST_TOKEN;

  if (!url || !token) {
    throw new Error('Redis env missing: KV_REST_API_URL/KV_REST_API_TOKEN');
  }

  return new Redis({ url, token });
}

async function readHash(redis: Redis, key: string): Promise<Record<string, unknown>> {
  const data = await redis.hgetall<Record<string, unknown>>(key);
  return data ?? {};
}

async function mergeBucket(
  redis: Redis,
  bucket: BucketConfig,
  defaultToken: string | null,
  targetToken: string
): Promise<void> {
  const targetKey = `${bucket.userPrefix}${targetToken}`;
  const targetData = await readHash(redis, targetKey);

  const legacyData = await readHash(redis, bucket.legacyKey);
  const fromDefaultData =
    defaultToken && defaultToken !== targetToken
      ? await readHash(redis, `${bucket.userPrefix}${defaultToken}`)
      : {};

  const merged: Record<string, unknown> = {
    ...legacyData,
    ...fromDefaultData,
    ...targetData,
  };

  const mergedEntries = Object.entries(merged);
  if (mergedEntries.length > 0) {
    await redis.hset(targetKey, merged);
  }

  console.log(
    `[migrate] ${bucket.name}: legacy=${Object.keys(legacyData).length}, ` +
      `default=${Object.keys(fromDefaultData).length}, target(before)=${Object.keys(targetData).length}, ` +
      `target(after)=${mergedEntries.length}`
  );
}

async function upsertPermanentPolicy(redis: Redis, token: string): Promise<void> {
  const existing = await redis.hget(USER_TOKEN_POLICY_HASH_KEY, token);
  const nowIso = new Date().toISOString();

  let createdAt = nowIso;
  if (existing && typeof existing === 'object' && existing !== null) {
    const raw = (existing as Record<string, unknown>).createdAt;
    if (typeof raw === 'string' && raw.trim().length > 0) {
      createdAt = raw;
    }
  }

  await redis.hset(USER_TOKEN_POLICY_HASH_KEY, {
    [token]: {
      token,
      validity: 'permanent',
      createdAt,
      updatedAt: nowIso,
    },
  });
}

async function main(): Promise<void> {
  if (!TOKEN_REGEX.test(TARGET_TOKEN)) {
    throw new Error(`Invalid token: ${TARGET_TOKEN}. Must be 16 letters/digits.`);
  }

  const redis = ensureRedis();

  const defaultTokenRaw = await redis.hget<string>(USER_META_HASH_KEY, DEFAULT_USER_TOKEN_FIELD);
  const defaultToken = typeof defaultTokenRaw === 'string' && TOKEN_REGEX.test(defaultTokenRaw)
    ? defaultTokenRaw
    : null;

  console.log(`[migrate] current default token: ${defaultToken ?? '(none)'}`);
  console.log(`[migrate] target token: ${TARGET_TOKEN}`);

  for (const bucket of BUCKETS) {
    await mergeBucket(redis, bucket, defaultToken, TARGET_TOKEN);
  }

  await upsertPermanentPolicy(redis, TARGET_TOKEN);

  const metaUpdates: Record<string, string> = {
    [DEFAULT_USER_TOKEN_FIELD]: TARGET_TOKEN,
  };
  for (const field of MIGRATION_FIELDS) {
    metaUpdates[field] = TARGET_TOKEN;
  }
  await redis.hset(USER_META_HASH_KEY, metaUpdates);

  console.log('[migrate] set target token policy = permanent');
  console.log('[migrate] set default-user-token and migration flags to target token');
  console.log('[migrate] done');
}

main().catch((error) => {
  console.error('[migrate] failed:', error);
  process.exit(1);
});
