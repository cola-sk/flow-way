import { Camera } from '@/types/camera';
import { EnhancedCamera } from '@/types/camera-enhanced';
import { createEnhancedCamera } from '@/lib/camera-parser';
import { scrapeCameras } from './scraper';
import {
  loadCameraSnapshotFromKv,
  saveCameraSnapshotToKv,
} from './camera-storage';

interface CacheData {
  cameras: Camera[];
  updatedAt: string;
  fetchedAt: number;
}

interface EnhancedCacheData {
  cameras: EnhancedCamera[];
  updatedAt: string;
  fetchedAt: number;
}

let cache: CacheData | null = null;
let enhancedCache: EnhancedCacheData | null = null;

function buildEnhancedCameras(cameras: Camera[]): EnhancedCamera[] {
  return cameras.map((cam, index) => {
    const id = `camera_${index}_${cam.lat.toFixed(6)}_${cam.lng.toFixed(6)}`;
    return createEnhancedCamera(
      id,
      cam.name,
      cam.lng,
      cam.lat,
      cam.type,
      cam.date,
      cam.href,
      cam.edittime
    );
  });
}

/**
 * 获取摄像头数据（带内存级缓存）
 */
export async function getCameras(): Promise<CacheData> {
  if (cache) {
    return cache;
  }

  try {
    const snapshot = await loadCameraSnapshotFromKv();
    if (!snapshot) {
      throw new Error(
        'camera snapshot is empty in KV; wait for cron refresh to populate data'
      );
    }
    cache = {
      cameras: snapshot.cameras,
      updatedAt: snapshot.updatedAt,
      fetchedAt: snapshot.fetchedAt,
    };
    return cache;
  } catch (err) {
    if (cache) {
      console.warn('[cache] getCameras failed, using stale cache', err);
      return cache;
    }
    throw err;
  }
}

/**
 * 获取增强的摄像头数据（包含方向、状态等信息）
 */
export async function getCamerasEnhanced(): Promise<EnhancedCacheData> {
  if (enhancedCache) {
    return enhancedCache;
  }

  try {
    const base = await getCameras();
    enhancedCache = {
      cameras: buildEnhancedCameras(base.cameras),
      updatedAt: base.updatedAt,
      fetchedAt: base.fetchedAt,
    };
    return enhancedCache;
  } catch (err) {
    if (enhancedCache) {
      console.warn(
        '[cache] getCamerasEnhanced failed, using stale enhanced cache',
        err
      );
      return enhancedCache;
    }
    throw err;
  }
}

/**
 * 强制刷新缓存
 */
export async function refreshCameras(): Promise<CacheData> {
  console.info('[camera-refresh] crawl start: source=https://www.jinjing365.com/index.asp');

  let crawled: { cameras: Camera[]; updatedAt: string };
  try {
    crawled = await scrapeCameras();
    console.info(
      `[camera-refresh] crawl success: total=${crawled.cameras.length}, sourceUpdatedAt=${crawled.updatedAt}`
    );
  } catch (error) {
    console.error('[camera-refresh] crawl failed', error);
    throw error;
  }

  const snapshot = await saveCameraSnapshotToKv({
    cameras: crawled.cameras,
    updatedAt: crawled.updatedAt,
  });

  cache = {
    cameras: snapshot.cameras,
    updatedAt: snapshot.updatedAt,
    fetchedAt: snapshot.fetchedAt,
  };
  enhancedCache = {
    cameras: buildEnhancedCameras(snapshot.cameras),
    updatedAt: snapshot.updatedAt,
    fetchedAt: snapshot.fetchedAt,
  };
  console.info(
    `[camera-refresh] memory cache updated: total=${cache.cameras.length}, fetchedAt=${cache.fetchedAt}`
  );

  return cache;
}

/**
 * 强制刷新增强的摄像头缓存
 */
export async function refreshCamerasEnhanced(): Promise<EnhancedCacheData> {
  const base = await refreshCameras();
  enhancedCache = {
    cameras: buildEnhancedCameras(base.cameras),
    updatedAt: base.updatedAt,
    fetchedAt: base.fetchedAt,
  };
  return enhancedCache;
}
