import { requireRedis } from './redis';

export type RiskPointType = 'risk' | 'low_risk' | 'low_risk_access_road';

export interface RiskPoint {
  id: string;
  name: string;
  lat: number;
  lng: number;
  type: RiskPointType;
  note: string;
  createdAt: string;
}

const HASH_KEY_PREFIX = 'risk-points:user:';

function userRiskPointsKey(userToken: string): string {
  return `${HASH_KEY_PREFIX}${userToken}`;
}

export function normalizeRiskPointType(value: unknown): RiskPointType {
  if (value === 'low_risk' || value === 'low_risk_access_road') {
    return value;
  }
  return 'risk';
}

export async function listRiskPoints(userToken: string): Promise<RiskPoint[]> {
  const redisClient = requireRedis('risk points storage is unavailable: Redis env is not configured');
  const all = await redisClient.hgetall<Record<string, RiskPoint>>(userRiskPointsKey(userToken));
  if (!all) return [];
  return Object.values(all).sort(
    (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
  );
}

export async function saveRiskPoint(userToken: string, riskPoint: RiskPoint): Promise<void> {
  const redisClient = requireRedis('risk points storage is unavailable: Redis env is not configured');
  await redisClient.hset(userRiskPointsKey(userToken), { [riskPoint.id]: riskPoint });
}

export async function getRiskPoint(userToken: string, id: string): Promise<RiskPoint | null> {
  const redisClient = requireRedis('risk points storage is unavailable: Redis env is not configured');
  return (await redisClient.hget<RiskPoint>(userRiskPointsKey(userToken), id)) ?? null;
}

export async function deleteRiskPoint(userToken: string, id: string): Promise<boolean> {
  const redisClient = requireRedis('risk points storage is unavailable: Redis env is not configured');
  return (await redisClient.hdel(userRiskPointsKey(userToken), id)) > 0;
}
