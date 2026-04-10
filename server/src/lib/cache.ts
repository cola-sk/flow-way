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
 * 获取增强的摄像头数据（包含方向、状态等信息）
 */
export async function getCamerasEnhanced(): Promise<EnhancedCacheData> {
  const now = Date.now();

  if (enhancedCache && now - enhancedCache.fetchedAt < CACHE_TTL) {
    return enhancedCache;
  }

  const { cameras, updatedAt } = await scrapeCamerasEnhanced();
  enhancedCache = { cameras, updatedAt, fetchedAt: now };
  return enhancedCache;
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
