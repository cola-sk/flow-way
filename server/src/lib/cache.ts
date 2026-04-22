import { Camera } from '@/types/camera';
import { EnhancedCamera } from '@/types/camera-enhanced';
import { scrapeCameras, scrapeCamerasEnhanced } from './scraper';

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

/**
 * 获取摄像头数据（带内存级缓存）
 */
export async function getCameras(): Promise<CacheData> {
  if (cache) {
    return cache;
  }

  try {
    const { cameras, updatedAt } = await scrapeCameras();
    cache = { cameras, updatedAt, fetchedAt: Date.now() };
    return cache;
  } catch (err) {
    if (cache) {
      console.warn('[cache] scrapeCameras failed, using stale cache', err);
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
    const { cameras, updatedAt } = await scrapeCamerasEnhanced();
    enhancedCache = { cameras, updatedAt, fetchedAt: Date.now() };
    return enhancedCache;
  } catch (err) {
    if (enhancedCache) {
      console.warn('[cache] scrapeCamerasEnhanced failed, using stale enhanced cache', err);
      return enhancedCache;
    }
    throw err;
  }
}

/**
 * 强制刷新缓存
 */
export async function refreshCameras(): Promise<CacheData> {
  const { cameras, updatedAt } = await scrapeCameras();
  cache = { cameras, updatedAt, fetchedAt: Date.now() };
  return cache;
}

/**
 * 强制刷新增强的摄像头缓存
 */
export async function refreshCamerasEnhanced(): Promise<EnhancedCacheData> {
  const { cameras, updatedAt } = await scrapeCamerasEnhanced();
  enhancedCache = { cameras, updatedAt, fetchedAt: Date.now() };
  return enhancedCache;
}
