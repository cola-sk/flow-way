import { Camera } from '@/types/camera';
import { scrapeCameras } from './scraper';

interface CacheData {
  cameras: Camera[];
  updatedAt: string;
  fetchedAt: number;
}

let cache: CacheData | null = null;

// 缓存有效期: 1 小时
const CACHE_TTL = 60 * 60 * 1000;

/**
 * 获取摄像头数据（带内存级缓存）
 */
export async function getCameras(): Promise<CacheData> {
  const now = Date.now();

  if (cache && now - cache.fetchedAt < CACHE_TTL) {
    return cache;
  }

  const { cameras, updatedAt } = await scrapeCameras();
  cache = { cameras, updatedAt, fetchedAt: now };
  return cache;
}

/**
 * 强制刷新缓存
 */
export async function refreshCameras(): Promise<CacheData> {
  const { cameras, updatedAt } = await scrapeCameras();
  cache = { cameras, updatedAt, fetchedAt: Date.now() };
  return cache;
}
