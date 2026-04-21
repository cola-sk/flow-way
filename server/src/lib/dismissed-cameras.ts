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

export interface DismissedCamera {
  lat: number;
  lng: number;
  name: string;
  markedAt: string;
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

  const legacy = await redisClient.hgetall<Record<string, DismissedCamera>>(LEGACY_HASH_KEY);
  if (legacy && Object.keys(legacy).length > 0) {
    const targetKey = userHashKey(defaultUserToken);
    const existing = await redisClient.hgetall<Record<string, DismissedCamera>>(targetKey);
    const merged: Record<string, DismissedCamera> = {};
    for (const [key, value] of Object.entries(legacy)) {
      if (!existing || !(key in existing)) {
        merged[key] = value;
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
  name: string
): Promise<DismissedCamera> {
  await ensureLegacyMigrated(userToken);
  const entry: DismissedCamera = {
    lat,
    lng,
    name,
    markedAt: new Date().toISOString(),
  };
  const redisClient = requireRedis('dismissed cameras storage is unavailable: Redis env is not configured');
  await redisClient.hset(userHashKey(userToken), { [coordKey(lat, lng)]: entry });
  return entry;
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
  const all = await redisClient.hgetall<Record<string, DismissedCamera>>(userHashKey(userToken));
  if (!all) return [];
  return Object.values(all)
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

/** 标记/取消标记后立即失效缓存 */
export function invalidateDismissedCache(userToken?: string): void {
  if (userToken) {
    dismissedSetCacheByUser.delete(userToken);
    return;
  }
  dismissedSetCacheByUser.clear();
}
