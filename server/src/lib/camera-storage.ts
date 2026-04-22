import { Camera } from '@/types/camera';
import { requireRedis } from './redis';

export interface CameraSnapshot {
  cameras: Camera[];
  updatedAt: string;
  fetchedAt: number;
}

const CAMERA_SNAPSHOT_LATEST_KEY = 'cameras:snapshot:latest';
const CAMERA_SNAPSHOT_PREFIX = 'cameras:snapshot:';
const LEGACY_HISTORY_PATTERNS = ['cameras:history:*', 'cameras:snapshot:history:*'];

function normalizeSnapshot(raw: unknown): CameraSnapshot | null {
  if (!raw || typeof raw !== 'object') {
    return null;
  }

  const value = raw as {
    cameras?: unknown;
    updatedAt?: unknown;
    fetchedAt?: unknown;
  };

  if (!Array.isArray(value.cameras)) {
    return null;
  }
  if (typeof value.updatedAt !== 'string' || value.updatedAt.trim().length === 0) {
    return null;
  }
  if (typeof value.fetchedAt !== 'number' || !Number.isFinite(value.fetchedAt)) {
    return null;
  }

  return {
    cameras: value.cameras as Camera[],
    updatedAt: value.updatedAt,
    fetchedAt: value.fetchedAt,
  };
}

async function findHistoricalKeys(): Promise<string[]> {
  const redis = requireRedis('camera storage is unavailable: Redis env is not configured');
  const keySet = new Set<string>();

  const snapshotKeys = await redis.keys(`${CAMERA_SNAPSHOT_PREFIX}*`);
  for (const key of snapshotKeys) {
    if (key !== CAMERA_SNAPSHOT_LATEST_KEY) {
      keySet.add(key);
    }
  }

  for (const pattern of LEGACY_HISTORY_PATTERNS) {
    const keys = await redis.keys(pattern);
    for (const key of keys) {
      if (key !== CAMERA_SNAPSHOT_LATEST_KEY) {
        keySet.add(key);
      }
    }
  }

  return Array.from(keySet);
}

export async function loadCameraSnapshotFromKv(): Promise<CameraSnapshot | null> {
  const redis = requireRedis('camera storage is unavailable: Redis env is not configured');
  const raw = await redis.get<unknown>(CAMERA_SNAPSHOT_LATEST_KEY);
  return normalizeSnapshot(raw);
}

export async function saveCameraSnapshotToKv(input: {
  cameras: Camera[];
  updatedAt: string;
}): Promise<CameraSnapshot> {
  const redis = requireRedis('camera storage is unavailable: Redis env is not configured');

  const snapshot: CameraSnapshot = {
    cameras: input.cameras,
    updatedAt: input.updatedAt,
    fetchedAt: Date.now(),
  };

  try {
    await redis.set(CAMERA_SNAPSHOT_LATEST_KEY, snapshot);
    console.info(
      `[camera-kv] write success: key=${CAMERA_SNAPSHOT_LATEST_KEY}, total=${snapshot.cameras.length}, sourceUpdatedAt=${snapshot.updatedAt}`
    );
  } catch (error) {
    console.error('[camera-kv] write failed', error);
    throw error;
  }

  try {
    const historicalKeys = await findHistoricalKeys();
    if (historicalKeys.length > 0) {
      const deleted = await redis.del(...historicalKeys);
      console.info(
        `[camera-kv] history cleanup success: deleted=${deleted}, keys=${historicalKeys.length}`
      );
    } else {
      console.info('[camera-kv] history cleanup success: deleted=0');
    }
  } catch (error) {
    console.error('[camera-kv] history cleanup failed', error);
    throw error;
  }

  return snapshot;
}

