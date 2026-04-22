/**
 * 废弃摄像头持久化存储（Upstash Redis）
 *
 * Redis Hash key: "dismissed-cameras:user:{token}"
 * Hash field: coordKey(lat, lng) = "lat.toFixed(6),lng.toFixed(6)"
 * Hash value: JSON.stringify(DismissedCamera)
 *
 * scraper 刷新不会影响此数据，重启/切换 Lambda 实例后数据依然存在。
 */

import { requireRedis } from './redis';
import {
  getOrCreateDefaultUserToken,
  USER_META_HASH_KEY,
} from './user-token';

export type CameraMarkType = 6 | 12;
const DEFAULT_MARK_TYPE: CameraMarkType = 6;

export interface DismissedCamera {
  lat: number;
  lng: number;
  name: string;
  markedAt: string;
  type: CameraMarkType;
  note?: string;
}

const LEGACY_HASH_KEY = 'dismissed-cameras';
const HASH_KEY_PREFIX = 'dismissed-cameras:user:';
const MIGRATION_FIELD = 'migrated-dismissed-cameras-default';

function userHashKey(userToken: string): string {
  return `${HASH_KEY_PREFIX}${userToken}`;
}

async function ensureLegacyMigrated(userToken: string): Promise<void> {
  const redisClient = requireRedis('dismissed cameras storage is unavailable: Redis env is not configured');
  const defaultUserToken = await getOrCreateDefaultUserToken(redisClient);
  if (userToken !== defaultUserToken) {
    return;
  }

  const migrated = await redisClient.hget<string>(USER_META_HASH_KEY, MIGRATION_FIELD);
  if (migrated === defaultUserToken) {
    return;
  }

  const legacy = await redisClient.hgetall<Record<string, unknown>>(LEGACY_HASH_KEY);
  if (legacy && Object.keys(legacy).length > 0) {
    const targetKey = userHashKey(defaultUserToken);
    const existing = await redisClient.hgetall<Record<string, unknown>>(targetKey);
    const merged: Record<string, DismissedCamera> = {};
    for (const [key, value] of Object.entries(legacy)) {
      if (!existing || !(key in existing)) {
        const normalized = normalizeDismissedCamera(value, key);
        if (normalized) {
          merged[key] = normalized;
        }
      }
    }
    if (Object.keys(merged).length > 0) {
      await redisClient.hset(targetKey, merged);
    }
  }

  await redisClient.hset(USER_META_HASH_KEY, { [MIGRATION_FIELD]: defaultUserToken });
}

/** 生成坐标 key，精度 1e-6 度 ≈ 0.1m，足以唯一定位 */
export function coordKey(lat: number, lng: number): string {
  return `${lat.toFixed(6)},${lng.toFixed(6)}`;
}

function normalizeMarkType(value: unknown): CameraMarkType {
  if (value === 12 || value === '12') {
    return 12;
  }
  return DEFAULT_MARK_TYPE;
}

function parseLatLngFromKey(key: string): { lat: number; lng: number } | null {
  const [latText, lngText] = key.split(',');
  const lat = Number(latText);
  const lng = Number(lngText);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    return null;
  }
  return { lat, lng };
}

function normalizeDismissedCamera(raw: unknown, key?: string): DismissedCamera | null {
  if (typeof raw === 'string') {
    try {
      const parsed = JSON.parse(raw) as unknown;
      return normalizeDismissedCamera(parsed, key);
    } catch {
      // Fall through to key-based fallback.
    }
  }

  if (!raw || typeof raw !== 'object') {
    if (!key) return null;
    const parsed = parseLatLngFromKey(key);
    if (!parsed) return null;
    return {
      lat: parsed.lat,
      lng: parsed.lng,
      name: '未命名摄像头',
      markedAt: new Date(0).toISOString(),
      type: DEFAULT_MARK_TYPE,
      note: '',
    };
  }

  const value = raw as Partial<DismissedCamera>;
  const parsedFromKey = key ? parseLatLngFromKey(key) : null;

  const lat = Number(value.lat ?? parsedFromKey?.lat);
  const lng = Number(value.lng ?? parsedFromKey?.lng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    return null;
  }

  const name = typeof value.name === 'string' && value.name.trim().length > 0
    ? value.name
    : '未命名摄像头';
  const markedAt =
    typeof value.markedAt === 'string' && value.markedAt.length > 0
      ? value.markedAt
      : new Date(0).toISOString();
  const note = typeof value.note === 'string' ? value.note : '';

  return {
    lat,
    lng,
    name,
    markedAt,
    type: normalizeMarkType(value.type),
    note,
  };
}

export async function isDismissed(userToken: string, lat: number, lng: number): Promise<boolean> {
  await ensureLegacyMigrated(userToken);
  const redisClient = requireRedis('dismissed cameras storage is unavailable: Redis env is not configured');
  const val = await redisClient.hget(userHashKey(userToken), coordKey(lat, lng));
  return val !== null;
}

export async function markDismissed(
  userToken: string,
  lat: number,
  lng: number,
  name: string,
  type: CameraMarkType = DEFAULT_MARK_TYPE,
  note?: string
): Promise<DismissedCamera> {
  await ensureLegacyMigrated(userToken);
  const normalizedNote = typeof note === 'string' ? note.trim() : '';
  const entry: DismissedCamera = {
    lat,
    lng,
    name,
    markedAt: new Date().toISOString(),
    type: normalizeMarkType(type),
    note: normalizedNote,
  };
  const redisClient = requireRedis('dismissed cameras storage is unavailable: Redis env is not configured');
  await redisClient.hset(userHashKey(userToken), { [coordKey(lat, lng)]: entry });
  return entry;
}

export async function updateDismissedNote(
  userToken: string,
  lat: number,
  lng: number,
  note?: string
): Promise<DismissedCamera | null> {
  await ensureLegacyMigrated(userToken);
  const redisClient = requireRedis('dismissed cameras storage is unavailable: Redis env is not configured');
  const key = coordKey(lat, lng);
  const current = await redisClient.hget<unknown>(userHashKey(userToken), key);
  if (!current) {
    return null;
  }

  const normalized = normalizeDismissedCamera(current, key);
  if (!normalized) {
    return null;
  }

  normalized.note = typeof note === 'string' ? note.trim() : '';
  await redisClient.hset(userHashKey(userToken), { [key]: normalized });
  return normalized;
}

/** 返回 true 表示成功删除，false 表示原本不存在 */
export async function unmarkDismissed(userToken: string, lat: number, lng: number): Promise<boolean> {
  await ensureLegacyMigrated(userToken);
  const redisClient = requireRedis('dismissed cameras storage is unavailable: Redis env is not configured');
  const deleted = await redisClient.hdel(userHashKey(userToken), coordKey(lat, lng));
  return deleted > 0;
}

export async function getDismissedList(userToken: string): Promise<DismissedCamera[]> {
  await ensureLegacyMigrated(userToken);
  const redisClient = requireRedis('dismissed cameras storage is unavailable: Redis env is not configured');
  const all = await redisClient.hgetall<Record<string, unknown>>(userHashKey(userToken));
  if (!all) return [];
  const list = Object.entries(all)
    .map(([key, value]) => normalizeDismissedCamera(value, key))
    .filter((item): item is DismissedCamera => Boolean(item));
  return list
    .sort((a, b) => new Date(b.markedAt).getTime() - new Date(a.markedAt).getTime());
}

/**
 * 获取所有废弃摄像头坐标集合（用于路线规划过滤，内存缓存 60s 减少 Redis 读次数）
 */
const dismissedSetCacheByUser = new Map<string, { set: Set<string>; cachedAt: number }>();
const DISMISSED_CACHE_TTL = 60_000;

export async function getDismissedSet(userToken: string): Promise<Set<string>> {
  await ensureLegacyMigrated(userToken);
  const now = Date.now();
  const cached = dismissedSetCacheByUser.get(userToken);
  if (cached && now - cached.cachedAt < DISMISSED_CACHE_TTL) {
    return cached.set;
  }
  const list = await getDismissedList(userToken);
  const nextSet = new Set(list.map((c) => coordKey(c.lat, c.lng)));
  dismissedSetCacheByUser.set(userToken, { set: nextSet, cachedAt: now });
  return nextSet;
}

const dismissedMapCacheByUser = new Map<string, { map: Map<string, CameraMarkType>; cachedAt: number }>();

export async function getDismissedMap(userToken: string): Promise<Map<string, CameraMarkType>> {
  await ensureLegacyMigrated(userToken);
  const now = Date.now();
  const cached = dismissedMapCacheByUser.get(userToken);
  if (cached && now - cached.cachedAt < DISMISSED_CACHE_TTL) {
    return cached.map;
  }
  const list = await getDismissedList(userToken);
  const nextMap = new Map<string, CameraMarkType>(list.map((c) => [coordKey(c.lat, c.lng), c.type]));
  dismissedMapCacheByUser.set(userToken, { map: nextMap, cachedAt: now });
  return nextMap;
}

/** 标记/取消标记后立即失效缓存 */
export function invalidateDismissedCache(userToken?: string): void {
  if (userToken) {
    dismissedSetCacheByUser.delete(userToken);
    dismissedMapCacheByUser.delete(userToken);
    return;
  }
  dismissedSetCacheByUser.clear();
  dismissedMapCacheByUser.clear();
}
