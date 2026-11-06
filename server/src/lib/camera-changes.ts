import { Camera } from '@/types/camera';
import { CameraSnapshot } from './camera-storage';
import { getRedis } from './redis';
import { v4 as uuidv4 } from 'uuid';

export type CameraChangeType = 'added' | 'removed' | 'typeChanged' | 'infoChanged';

export interface CameraChangeRecord {
  id: string;
  changeType: CameraChangeType;
  cameraName: string;
  lat: number;
  lng: number;
  oldType?: number;
  newType?: number;
  oldDate?: string;
  newDate?: string;
  oldEdittime?: string;
  newEdittime?: string;
  detectedAt: string;
  description: string;
}

export interface CameraDiffReport {
  id: string;
  detectedAt: string;
  previousUpdatedAt: string | null;
  currentUpdatedAt: string;
  totalPrevious: number;
  totalCurrent: number;
  addedCount: number;
  removedCount: number;
  typeChangedCount: number;
  infoChangedCount: number;
  totalChanges: number;
  records: CameraChangeRecord[];
}

const LATEST_DIFF_KEY = 'cameras:diff:latest';
const HISTORY_DIFF_KEY = 'cameras:diff:history';
const MAX_HISTORY_ITEMS = 20;

function formatType(type?: number): string {
  switch (type) {
    case 1:
      return '只拍晚高峰';
    case 2:
      return '六环内';
    case 4:
      return '待核实';
    case 5:
      return '晚高峰+六环内';
    case 6:
      return '六环外';
    default:
      return '未知';
  }
}

/**
 * 地球大圆距离（米），GCJ-02 近似测距
 */
export function calculateDistanceMeters(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number
): number {
  const R = 6371000; // 地球半径（米）
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

/**
 * 纯函数：比对两批摄像头数据，生成变动差异报告
 */
export function computeCameraDiff(
  previousCameras: Camera[],
  currentCameras: Camera[],
  previousUpdatedAt: string | null,
  currentUpdatedAt: string,
  detectedAt: string = new Date().toISOString()
): CameraDiffReport {
  const prevMap = new Map<string, Camera>();
  for (const c of previousCameras) {
    const key = `${c.lat.toFixed(6)},${c.lng.toFixed(6)}_${c.name}`;
    prevMap.set(key, c);
  }

  const currMap = new Map<string, Camera>();
  for (const c of currentCameras) {
    const key = `${c.lat.toFixed(6)},${c.lng.toFixed(6)}_${c.name}`;
    currMap.set(key, c);
  }

  const records: CameraChangeRecord[] = [];

  // 1. 查找新增
  for (const [key, curr] of currMap.entries()) {
    if (!prevMap.has(key)) {
      records.push({
        id: uuidv4(),
        changeType: 'added',
        cameraName: curr.name,
        lat: curr.lat,
        lng: curr.lng,
        newType: curr.type,
        newDate: curr.date,
        newEdittime: curr.edittime,
        detectedAt,
        description: `新增摄像头，抓拍类型: ${formatType(curr.type)}`,
      });
    }
  }

  // 2. 查找下线移除
  for (const [key, prev] of prevMap.entries()) {
    if (!currMap.has(key)) {
      records.push({
        id: uuidv4(),
        changeType: 'removed',
        cameraName: prev.name,
        lat: prev.lat,
        lng: prev.lng,
        oldType: prev.type,
        oldDate: prev.date,
        oldEdittime: prev.edittime,
        detectedAt,
        description: '摄像头已从最新数据源中下线或移除',
      });
    }
  }

  // 3. 查找规则类型变动与时间更新
  for (const [key, curr] of currMap.entries()) {
    const prev = prevMap.get(key);
    if (!prev) continue;

    if (curr.type !== prev.type) {
      records.push({
        id: uuidv4(),
        changeType: 'typeChanged',
        cameraName: curr.name,
        lat: curr.lat,
        lng: curr.lng,
        oldType: prev.type,
        newType: curr.type,
        oldDate: prev.date,
        newDate: curr.date,
        oldEdittime: prev.edittime,
        newEdittime: curr.edittime,
        detectedAt,
        description: `抓拍规则变更：由 [${formatType(prev.type)}] 变更为 [${formatType(curr.type)}]`,
      });
    } else if (
      curr.edittime !== prev.edittime ||
      curr.date !== prev.date ||
      curr.name !== prev.name
    ) {
      const parts: string[] = [];
      if (curr.name !== prev.name) parts.push(`名称由 "${prev.name}" 更新为 "${curr.name}"`);
      if (curr.edittime !== prev.edittime) {
        parts.push(`编辑时间更新为 ${curr.edittime ?? '无'}`);
      }
      if (curr.date !== prev.date) parts.push(`抓取时间更新为 ${curr.date}`);

      records.push({
        id: uuidv4(),
        changeType: 'infoChanged',
        cameraName: curr.name,
        lat: curr.lat,
        lng: curr.lng,
        oldType: prev.type,
        newType: curr.type,
        oldDate: prev.date,
        newDate: curr.date,
        oldEdittime: prev.edittime,
        newEdittime: curr.edittime,
        detectedAt,
        description: parts.join('；'),
      });
    }
  }

  const addedCount = records.filter((r) => r.changeType === 'added').length;
  const removedCount = records.filter((r) => r.changeType === 'removed').length;
  const typeChangedCount = records.filter((r) => r.changeType === 'typeChanged').length;
  const infoChangedCount = records.filter((r) => r.changeType === 'infoChanged').length;

  return {
    id: uuidv4(),
    detectedAt,
    previousUpdatedAt,
    currentUpdatedAt,
    totalPrevious: previousCameras.length,
    totalCurrent: currentCameras.length,
    addedCount,
    removedCount,
    typeChangedCount,
    infoChangedCount,
    totalChanges: records.length,
    records,
  };
}

/**
 * 定时任务后置变动计算：在入库成功之后执行
 * 【极其重要】该函数内部包含完备的异常捕获，即使失败也绝不向外抛错，
 * 绝不会影响定时任务已完成的入库流程。
 */
export async function recordCameraDiffSafe(
  previousSnapshot: CameraSnapshot | null,
  currentSnapshot: CameraSnapshot
): Promise<CameraDiffReport | null> {
  const redis = getRedis();
  if (!redis) {
    console.warn('[camera-diff] Redis not available, skipping server-side diff storage');
    return null;
  }

  try {
    const prevCameras = previousSnapshot?.cameras ?? [];
    const prevUpdatedAt = previousSnapshot?.updatedAt ?? null;
    const now = new Date().toISOString();

    // 首次抓取，无前置历史快照
    if (!previousSnapshot || prevCameras.length === 0) {
      console.info(
        `[camera-diff] initial baseline established, total=${currentSnapshot.cameras.length}`
      );
      const baselineReport: CameraDiffReport = {
        id: uuidv4(),
        detectedAt: now,
        previousUpdatedAt: null,
        currentUpdatedAt: currentSnapshot.updatedAt,
        totalPrevious: 0,
        totalCurrent: currentSnapshot.cameras.length,
        addedCount: 0,
        removedCount: 0,
        typeChangedCount: 0,
        infoChangedCount: 0,
        totalChanges: 0,
        records: [],
      };
      await redis.set(LATEST_DIFF_KEY, baselineReport);
      return baselineReport;
    }

    const report = computeCameraDiff(
      prevCameras,
      currentSnapshot.cameras,
      prevUpdatedAt,
      currentSnapshot.updatedAt,
      now
    );

    console.info(
      `[camera-diff] computed diff: changes=${report.totalChanges} (added=${report.addedCount}, removed=${report.removedCount}, typeChanged=${report.typeChangedCount}, infoChanged=${report.infoChangedCount})`
    );

    // 仅在有变动或常规刷新时更新最新变动记录
    await redis.set(LATEST_DIFF_KEY, report);

    if (report.totalChanges > 0) {
      // 变动记录追加到历史队列（最多保留 20 条）
      try {
        await redis.lpush(HISTORY_DIFF_KEY, JSON.stringify(report));
        await redis.ltrim(HISTORY_DIFF_KEY, 0, MAX_HISTORY_ITEMS - 1);
      } catch (histErr) {
        console.warn('[camera-diff] failed to append history list:', histErr);
      }
    }

    return report;
  } catch (error) {
    // 捕获并记录错误，确保隔离，绝不影响外层爬取入库结果
    console.error('[camera-diff] post-processing diff failed (crawl unaffected):', error);
    return null;
  }
}

/**
 * 获取服务端记录的最新摄像头变动报告
 */
export async function getLatestCameraDiffReport(): Promise<CameraDiffReport | null> {
  const redis = getRedis();
  if (!redis) return null;
  try {
    const data = await redis.get<CameraDiffReport>(LATEST_DIFF_KEY);
    return data ?? null;
  } catch (err) {
    console.error('[camera-diff] failed to fetch latest diff from Redis:', err);
    return null;
  }
}
