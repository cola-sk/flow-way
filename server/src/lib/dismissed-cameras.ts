/**
 * 废弃摄像头持久化存储（Upstash Redis）
 *
 * Redis Hash key: "dismissed-cameras"
 * Hash field: coordKey(lat, lng) = "lat.toFixed(6),lng.toFixed(6)"
 * Hash value: JSON.stringify(DismissedCamera)
 *
 * scraper 刷新不会影响此数据，重启/切换 Lambda 实例后数据依然存在。
 */

import { Redis } from '@upstash/redis';

export interface DismissedCamera {
  lat: number;
  lng: number;
  name: string;
  markedAt: string;
}

const HASH_KEY = 'dismissed-cameras';

let redis: Redis;
function getRedis(): Redis {
  if (!redis) {
    redis = new Redis({
      url: process.env.KV_REST_API_URL!,
      token: process.env.KV_REST_API_TOKEN!,
    });
  }
  return redis;
}

/** 生成坐标 key，精度 1e-6 度 ≈ 0.1m，足以唯一定位 */
export function coordKey(lat: number, lng: number): string {
  return `${lat.toFixed(6)},${lng.toFixed(6)}`;
}

export async function isDismissed(lat: number, lng: number): Promise<boolean> {
  const val = await getRedis().hget(HASH_KEY, coordKey(lat, lng));
  return val !== null;
}

export async function markDismissed(
  lat: number,
  lng: number,
  name: string
): Promise<DismissedCamera> {
  const entry: DismissedCamera = {
    lat,
    lng,
    name,
    markedAt: new Date().toISOString(),
  };
  await getRedis().hset(HASH_KEY, { [coordKey(lat, lng)]: entry });
  return entry;
}

/** 返回 true 表示成功删除，false 表示原本不存在 */
export async function unmarkDismissed(lat: number, lng: number): Promise<boolean> {
  const deleted = await getRedis().hdel(HASH_KEY, coordKey(lat, lng));
  return deleted > 0;
}

export async function getDismissedList(): Promise<DismissedCamera[]> {
  const all = await getRedis().hgetall<Record<string, DismissedCamera>>(HASH_KEY);
  if (!all) return [];
  return Object.values(all)
    .sort((a, b) => new Date(b.markedAt).getTime() - new Date(a.markedAt).getTime());
}

/**
 * 获取所有废弃摄像头坐标集合（用于路线规划过滤，内存缓存 60s 减少 Redis 读次数）
 */
let dismissedSetCache: Set<string> | null = null;
let dismissedSetCachedAt = 0;
const DISMISSED_CACHE_TTL = 60_000;

export async function getDismissedSet(): Promise<Set<string>> {
  const now = Date.now();
  if (dismissedSetCache && now - dismissedSetCachedAt < DISMISSED_CACHE_TTL) {
    return dismissedSetCache;
  }
  const list = await getDismissedList();
  dismissedSetCache = new Set(list.map((c) => coordKey(c.lat, c.lng)));
  dismissedSetCachedAt = now;
  return dismissedSetCache;
}

/** 标记/取消标记后立即失效缓存 */
export function invalidateDismissedCache(): void {
  dismissedSetCache = null;
}
