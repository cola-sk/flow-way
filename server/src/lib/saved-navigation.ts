import { v4 as uuidv4 } from 'uuid';
import { Coordinate, Route } from '@/types/route';
import { requireRedis } from './redis';
import {
  getOrCreateDefaultUserToken,
  USER_META_HASH_KEY,
} from './user-token';

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

const LEGACY_ROUTES_HASH_KEY = 'saved-routes';
const LEGACY_PLANS_HASH_KEY = 'saved-route-plans';
const LEGACY_RECENT_HASH_KEY = 'recent-navigations';
const ROUTES_HASH_PREFIX = 'saved-routes:user:';
const PLANS_HASH_PREFIX = 'saved-route-plans:user:';
const RECENT_HASH_PREFIX = 'recent-navigations:user:';

const MIGRATION_ROUTES_FIELD = 'migrated-saved-routes-default';
const MIGRATION_PLANS_FIELD = 'migrated-saved-route-plans-default';
const MIGRATION_RECENT_FIELD = 'migrated-recent-navigations-default';

const RECENT_KEEP_LIMIT = 10;

function routesHashKey(userToken: string): string {
  return `${ROUTES_HASH_PREFIX}${userToken}`;
}

function plansHashKey(userToken: string): string {
  return `${PLANS_HASH_PREFIX}${userToken}`;
}

function recentHashKey(userToken: string): string {
  return `${RECENT_HASH_PREFIX}${userToken}`;
}

function sortedByTimeDesc<T extends { createdAt: string }>(items: T[]): T[] {
  return items.sort(
    (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
  );
}

async function migrateLegacyHashIfNeeded<T extends { id: string }>(
  userToken: string,
  legacyHashKey: string,
  targetHashKey: string,
  migrationField: string
): Promise<void> {
  const redisClient = requireRedis('saved navigation storage is unavailable: Redis env is not configured');
  const defaultUserToken = await getOrCreateDefaultUserToken(redisClient);
  if (userToken !== defaultUserToken) {
    return;
  }

  const migrated = await redisClient.hget<string>(USER_META_HASH_KEY, migrationField);
  if (migrated === defaultUserToken) {
    return;
  }

  const legacy = await redisClient.hgetall<Record<string, T>>(legacyHashKey);
  if (legacy && Object.keys(legacy).length > 0) {
    const existing = await redisClient.hgetall<Record<string, T>>(targetHashKey);
    const merged: Record<string, T> = {};
    for (const [id, record] of Object.entries(legacy)) {
      if (!existing || !(id in existing)) {
        merged[id] = record;
      }
    }
    if (Object.keys(merged).length > 0) {
      await redisClient.hset(targetHashKey, merged);
    }
  }

  await redisClient.hset(USER_META_HASH_KEY, { [migrationField]: defaultUserToken });
}

async function ensureLegacyMigrated(userToken: string): Promise<void> {
  await migrateLegacyHashIfNeeded<SavedRouteRecord>(
    userToken,
    LEGACY_ROUTES_HASH_KEY,
    routesHashKey(userToken),
    MIGRATION_ROUTES_FIELD
  );
  await migrateLegacyHashIfNeeded<SavedRoutePlanRecord>(
    userToken,
    LEGACY_PLANS_HASH_KEY,
    plansHashKey(userToken),
    MIGRATION_PLANS_FIELD
  );
  await migrateLegacyHashIfNeeded<RecentNavigationRecord>(
    userToken,
    LEGACY_RECENT_HASH_KEY,
    recentHashKey(userToken),
    MIGRATION_RECENT_FIELD
  );
}

export async function saveRouteRecord(input: {
  userToken: string;
  name?: string;
  route: Route;
  stops?: NamedCoordinate[];
}): Promise<SavedRouteRecord> {
  await ensureLegacyMigrated(input.userToken);

  const createdAt = new Date().toISOString();
  const record: SavedRouteRecord = {
    id: uuidv4(),
    name: input.name?.trim() || '未命名线路',
    route: input.route,
    stops: input.stops ?? [],
    createdAt,
  };

  const redisClient = requireRedis('saved navigation storage is unavailable: Redis env is not configured');
  await redisClient.hset(routesHashKey(input.userToken), { [record.id]: record });
  return record;
}

export async function listRouteRecords(userToken: string): Promise<SavedRouteRecord[]> {
  await ensureLegacyMigrated(userToken);

  const redisClient = requireRedis('saved navigation storage is unavailable: Redis env is not configured');
  const all = await redisClient.hgetall<Record<string, SavedRouteRecord>>(routesHashKey(userToken));
  if (!all) return [];
  return sortedByTimeDesc(Object.values(all));
}

export async function deleteRouteRecord(userToken: string, id: string): Promise<boolean> {
  await ensureLegacyMigrated(userToken);

  const redisClient = requireRedis('saved navigation storage is unavailable: Redis env is not configured');
  const deleted = await redisClient.hdel(routesHashKey(userToken), id);
  return deleted > 0;
}

export async function saveRoutePlanRecord(input: {
  userToken: string;
  name?: string;
  start: NamedCoordinate;
  end: NamedCoordinate;
  waypoints?: NamedCoordinate[];
  avoidCameras?: boolean;
}): Promise<SavedRoutePlanRecord> {
  await ensureLegacyMigrated(input.userToken);

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

  const redisClient = requireRedis('saved navigation storage is unavailable: Redis env is not configured');
  await redisClient.hset(plansHashKey(input.userToken), { [record.id]: record });
  return record;
}

export async function listRoutePlanRecords(userToken: string): Promise<SavedRoutePlanRecord[]> {
  await ensureLegacyMigrated(userToken);

  const redisClient = requireRedis('saved navigation storage is unavailable: Redis env is not configured');
  const all = await redisClient.hgetall<Record<string, SavedRoutePlanRecord>>(plansHashKey(userToken));
  if (!all) return [];
  return sortedByTimeDesc(Object.values(all));
}

export async function deleteRoutePlanRecord(userToken: string, id: string): Promise<boolean> {
  await ensureLegacyMigrated(userToken);

  const redisClient = requireRedis('saved navigation storage is unavailable: Redis env is not configured');
  const deleted = await redisClient.hdel(plansHashKey(userToken), id);
  return deleted > 0;
}

export async function saveRecentNavigationRecord(input: {
  userToken: string;
  name?: string;
  start: NamedCoordinate;
  end: NamedCoordinate;
  waypoints?: NamedCoordinate[];
  avoidCameras?: boolean;
  source?: string;
}): Promise<RecentNavigationRecord> {
  await ensureLegacyMigrated(input.userToken);

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

  const redisClient = requireRedis('saved navigation storage is unavailable: Redis env is not configured');
  const targetRecentHashKey = recentHashKey(input.userToken);
  await redisClient.hset(targetRecentHashKey, { [record.id]: record });

  // 仅保留最近 10 条，超出部分直接物理删除，降低存储占用。
  const all = await redisClient.hgetall<Record<string, RecentNavigationRecord>>(targetRecentHashKey);
  if (all) {
    const sorted = sortedByTimeDesc(Object.values(all));
    const staleIds = sorted.slice(RECENT_KEEP_LIMIT).map((item) => item.id);
    if (staleIds.length > 0) {
      await redisClient.hdel(targetRecentHashKey, ...staleIds);
    }
  }

  return record;
}

export async function listRecentNavigationRecords(userToken: string): Promise<RecentNavigationRecord[]> {
  await ensureLegacyMigrated(userToken);

  const redisClient = requireRedis('saved navigation storage is unavailable: Redis env is not configured');
  const targetRecentHashKey = recentHashKey(userToken);
  const all = await redisClient.hgetall<Record<string, RecentNavigationRecord>>(targetRecentHashKey);
  if (!all) return [];
  const sorted = sortedByTimeDesc(Object.values(all));

  // 兜底清理历史脏数据：超过限制的记录一并删除。
  const staleIds = sorted.slice(RECENT_KEEP_LIMIT).map((item) => item.id);
  if (staleIds.length > 0) {
    await redisClient.hdel(targetRecentHashKey, ...staleIds);
  }

  return sorted.slice(0, RECENT_KEEP_LIMIT);
}

export async function deleteRecentNavigationRecord(userToken: string, id: string): Promise<boolean> {
  await ensureLegacyMigrated(userToken);

  const redisClient = requireRedis('saved navigation storage is unavailable: Redis env is not configured');
  const deleted = await redisClient.hdel(recentHashKey(userToken), id);
  return deleted > 0;
}
