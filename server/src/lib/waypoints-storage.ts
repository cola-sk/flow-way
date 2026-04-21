import { WayPoint } from '@/types/route';
import { requireRedis } from './redis';
import {
  getOrCreateDefaultUserToken,
  USER_META_HASH_KEY,
} from './user-token';

const LEGACY_WAYPOINTS_HASH_KEY = 'waypoints';
const WAYPOINTS_HASH_PREFIX = 'waypoints:user:';
const MIGRATION_FIELD = 'migrated-waypoints-default';

function userWaypointsKey(userToken: string): string {
  return `${WAYPOINTS_HASH_PREFIX}${userToken}`;
}

function sortByCreatedAtDesc(items: WayPoint[]): WayPoint[] {
	return items.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
}

async function ensureLegacyMigrated(userToken: string): Promise<void> {
  const redisClient = requireRedis('waypoints storage is unavailable: Redis env is not configured');
  const defaultUserToken = await getOrCreateDefaultUserToken(redisClient);
  if (userToken !== defaultUserToken) {
    return;
  }

  const migrated = await redisClient.hget<string>(USER_META_HASH_KEY, MIGRATION_FIELD);
  if (migrated === defaultUserToken) {
    return;
  }

  const legacy = await redisClient.hgetall<Record<string, WayPoint>>(LEGACY_WAYPOINTS_HASH_KEY);
  if (legacy && Object.keys(legacy).length > 0) {
    const targetKey = userWaypointsKey(defaultUserToken);
    const existing = await redisClient.hgetall<Record<string, WayPoint>>(targetKey);
    const merged: Record<string, WayPoint> = {};
    for (const [id, point] of Object.entries(legacy)) {
      if (!existing || !(id in existing)) {
        merged[id] = point;
      }
    }
    if (Object.keys(merged).length > 0) {
      await redisClient.hset(targetKey, merged);
    }
  }

  await redisClient.hset(USER_META_HASH_KEY, { [MIGRATION_FIELD]: defaultUserToken });
}

export async function listWayPoints(userToken: string): Promise<WayPoint[]> {
	await ensureLegacyMigrated(userToken);
	const redisClient = requireRedis('waypoints storage is unavailable: Redis env is not configured');
	const all = await redisClient.hgetall<Record<string, WayPoint>>(userWaypointsKey(userToken));
	if (!all) return [];
	return sortByCreatedAtDesc(Object.values(all));
}

export async function saveWayPoint(userToken: string, wayPoint: WayPoint): Promise<void> {
	await ensureLegacyMigrated(userToken);
	const redisClient = requireRedis('waypoints storage is unavailable: Redis env is not configured');
	await redisClient.hset(userWaypointsKey(userToken), { [wayPoint.id]: wayPoint });
}

export async function deleteWayPointById(userToken: string, id: string): Promise<boolean> {
	await ensureLegacyMigrated(userToken);
	const redisClient = requireRedis('waypoints storage is unavailable: Redis env is not configured');
	const deleted = await redisClient.hdel(userWaypointsKey(userToken), id);
	return deleted > 0;
}
