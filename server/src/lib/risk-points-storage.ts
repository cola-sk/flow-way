import { requireRedis } from './redis';
import type { Camera } from '@/types/camera';

export type RiskPointType = 'risk' | 'low_risk' | 'low_risk_access_road';
export type RiskPointDirection =
  | 'both'
  | 'east_west'
  | 'west_east'
  | 'south_north'
  | 'north_south';

export interface RiskPoint {
  id: string;
  name: string;
  lat: number;
  lng: number;
  type: RiskPointType;
  direction: RiskPointDirection;
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

export function normalizeRiskPointDirection(value: unknown): RiskPointDirection {
  if (
    value === 'east_west' ||
    value === 'west_east' ||
    value === 'south_north' ||
    value === 'north_south'
  ) {
    return value;
  }
  return 'both';
}

export async function listRiskPoints(userToken: string): Promise<RiskPoint[]> {
  const redisClient = requireRedis('risk points storage is unavailable: Redis env is not configured');
  const all = await redisClient.hgetall<Record<string, RiskPoint>>(userRiskPointsKey(userToken));
  if (!all) return [];
  return Object.values(all).map((point) => ({
    ...point,
    // 兼容方向字段发布前创建的风险点：默认为双向避让。
    direction: normalizeRiskPointDirection(point.direction),
  })).sort(
    (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
  );
}

/**
 * 将用户标记的风险点转换为路线避让算法可识别的目标。
 * 这些目标只用于规划，不会作为摄像头返回给客户端。
 */
export async function listRiskPointAvoidanceTargets(
  userToken: string,
  ignoreLowRisk: boolean
): Promise<Camera[]> {
  const riskPoints = await listRiskPoints(userToken);
  return riskPoints
    .filter((point) => point.type === 'risk' || !ignoreLowRisk)
    .map((point) => ({
      // 使用固定名称编码方向，复用现有的行驶方向匹配逻辑。
      name: point.direction === 'both' ? '用户风险点' : `用户风险点（${riskPointDirectionLabel(point.direction)}）`,
      lat: point.lat,
      lng: point.lng,
      type: 2,
      date: '',
      href: '',
    }));
}

function riskPointDirectionLabel(direction: RiskPointDirection): string {
  switch (direction) {
    case 'east_west':
      return '东向西';
    case 'west_east':
      return '西向东';
    case 'south_north':
      return '南向北';
    case 'north_south':
      return '北向南';
    case 'both':
      return '双向';
  }
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
