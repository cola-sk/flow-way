import { WayPoint } from '@/types/route';
import { Redis } from '@upstash/redis';

const WAYPOINTS_HASH_KEY = 'waypoints';

let redis: Redis | null = null;
const memoryFallback = new Map<string, WayPoint>();

function getRedis(): Redis | null {
	if (redis) return redis;

	const url = process.env.KV_REST_API_URL;
	const token = process.env.KV_REST_API_TOKEN;
	if (!url || !token) {
		return null;
	}

	redis = new Redis({ url, token });
	return redis;
}

function sortByCreatedAtDesc(items: WayPoint[]): WayPoint[] {
	return items.sort(
		(a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
	);
}

export async function listWayPoints(): Promise<WayPoint[]> {
	const redisClient = getRedis();
	if (!redisClient) {
		return sortByCreatedAtDesc(Array.from(memoryFallback.values()));
	}

	const all = await redisClient.hgetall<Record<string, WayPoint>>(WAYPOINTS_HASH_KEY);
	if (!all) return [];
	return sortByCreatedAtDesc(Object.values(all));
}

export async function saveWayPoint(wayPoint: WayPoint): Promise<void> {
	const redisClient = getRedis();
	if (!redisClient) {
		memoryFallback.set(wayPoint.id, wayPoint);
		return;
	}

	await redisClient.hset(WAYPOINTS_HASH_KEY, { [wayPoint.id]: wayPoint });
}

export async function deleteWayPointById(id: string): Promise<boolean> {
	const redisClient = getRedis();
	if (!redisClient) {
		return memoryFallback.delete(id);
	}

	const deleted = await redisClient.hdel(WAYPOINTS_HASH_KEY, id);
	return deleted > 0;
}
