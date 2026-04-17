import { Redis } from '@upstash/redis';
import { v4 as uuidv4 } from 'uuid';
import { Coordinate, Route } from '@/types/route';

export interface NamedCoordinate extends Coordinate {
  name: string;
  address?: string;
}

export interface SavedRouteRecord {
  id: string;
  name: string;
  route: Route;
  stops: NamedCoordinate[];
  createdAt: string;
}

export interface SavedRoutePlanRecord {
  id: string;
  name: string;
  start: NamedCoordinate;
  end: NamedCoordinate;
  waypoints: NamedCoordinate[];
  avoidCameras: boolean;
  createdAt: string;
}

export interface RecentNavigationRecord {
  id: string;
  name: string;
  start: NamedCoordinate;
  end: NamedCoordinate;
  waypoints: NamedCoordinate[];
  avoidCameras: boolean;
  source?: string;
  createdAt: string;
}

const ROUTES_HASH_KEY = 'saved-routes';
const PLANS_HASH_KEY = 'saved-route-plans';
const RECENT_HASH_KEY = 'recent-navigations';

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

function sortedByTimeDesc<T extends { createdAt: string }>(items: T[]): T[] {
  return items.sort(
    (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
  );
}

export async function saveRouteRecord(input: {
  name?: string;
  route: Route;
  stops?: NamedCoordinate[];
}): Promise<SavedRouteRecord> {
  const createdAt = new Date().toISOString();
  const record: SavedRouteRecord = {
    id: uuidv4(),
    name: input.name?.trim() || '未命名线路',
    route: input.route,
    stops: input.stops ?? [],
    createdAt,
  };

  await getRedis().hset(ROUTES_HASH_KEY, { [record.id]: record });
  return record;
}

export async function listRouteRecords(): Promise<SavedRouteRecord[]> {
  const all = await getRedis().hgetall<Record<string, SavedRouteRecord>>(ROUTES_HASH_KEY);
  if (!all) return [];
  return sortedByTimeDesc(Object.values(all));
}

export async function deleteRouteRecord(id: string): Promise<boolean> {
  const deleted = await getRedis().hdel(ROUTES_HASH_KEY, id);
  return deleted > 0;
}

export async function saveRoutePlanRecord(input: {
  name?: string;
  start: NamedCoordinate;
  end: NamedCoordinate;
  waypoints?: NamedCoordinate[];
  avoidCameras?: boolean;
}): Promise<SavedRoutePlanRecord> {
  const createdAt = new Date().toISOString();
  const record: SavedRoutePlanRecord = {
    id: uuidv4(),
    name: input.name?.trim() || '未命名点位方案',
    start: input.start,
    end: input.end,
    waypoints: input.waypoints ?? [],
    avoidCameras: Boolean(input.avoidCameras),
    createdAt,
  };

  await getRedis().hset(PLANS_HASH_KEY, { [record.id]: record });
  return record;
}

export async function listRoutePlanRecords(): Promise<SavedRoutePlanRecord[]> {
  const all = await getRedis().hgetall<Record<string, SavedRoutePlanRecord>>(PLANS_HASH_KEY);
  if (!all) return [];
  return sortedByTimeDesc(Object.values(all));
}

export async function deleteRoutePlanRecord(id: string): Promise<boolean> {
  const deleted = await getRedis().hdel(PLANS_HASH_KEY, id);
  return deleted > 0;
}

export async function saveRecentNavigationRecord(input: {
  name?: string;
  start: NamedCoordinate;
  end: NamedCoordinate;
  waypoints?: NamedCoordinate[];
  avoidCameras?: boolean;
  source?: string;
}): Promise<RecentNavigationRecord> {
  const createdAt = new Date().toISOString();
  const record: RecentNavigationRecord = {
    id: uuidv4(),
    name: input.name?.trim() || `${input.start.name} -> ${input.end.name}`,
    start: input.start,
    end: input.end,
    waypoints: input.waypoints ?? [],
    avoidCameras: Boolean(input.avoidCameras),
    source: input.source,
    createdAt,
  };

  await getRedis().hset(RECENT_HASH_KEY, { [record.id]: record });
  return record;
}

export async function listRecentNavigationRecords(): Promise<RecentNavigationRecord[]> {
  const all = await getRedis().hgetall<Record<string, RecentNavigationRecord>>(RECENT_HASH_KEY);
  if (!all) return [];
  return sortedByTimeDesc(Object.values(all));
}

export async function deleteRecentNavigationRecord(id: string): Promise<boolean> {
  const deleted = await getRedis().hdel(RECENT_HASH_KEY, id);
  return deleted > 0;
}
