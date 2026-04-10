import { NextResponse } from 'next/server';
import { scrapeCamerasEnhanced } from '@/lib/scraper';

export const dynamic = 'force-dynamic';

// 缓存增强的摄像头数据
let cachedEnhancedCameras: any = null;
let cacheTime = 0;
const CACHE_DURATION = 6 * 60 * 60 * 1000; // 6小时缓存

export async function GET() {
  try {
    const now = Date.now();

    // 检查缓存是否有效
    if (cachedEnhancedCameras && now - cacheTime < CACHE_DURATION) {
      return NextResponse.json(cachedEnhancedCameras);
    }

    // 获取增强的摄像头数据
    const { cameras, updatedAt } = await scrapeCamerasEnhanced();

    const response = {
      cameras,
      updatedAt,
      total: cameras.length,
    };

    // 更新缓存
    cachedEnhancedCameras = response;
    cacheTime = now;

    return NextResponse.json(response);
  } catch (error) {
    console.error('Failed to fetch enhanced cameras:', error);
    return NextResponse.json(
      { error: 'Failed to fetch camera data' },
      { status: 500 }
    );
  }
}
