import { NextResponse } from 'next/server';
import { getCameras, refreshCameras } from '@/lib/cache';
import { CamerasResponse } from '@/types/camera';

export const dynamic = 'force-dynamic';

function formatCrawledAt(fetchedAt: number): string {
  const dt = new Date(fetchedAt);
  const two = (n: number) => n.toString().padStart(2, '0');
  return `${dt.getFullYear()}-${two(dt.getMonth() + 1)}-${two(dt.getDate())} ${two(dt.getHours())}:${two(dt.getMinutes())}:${two(dt.getSeconds())}`;
}

export async function GET() {
  try {
    const { cameras, updatedAt, fetchedAt } = await getCameras();

    const response: CamerasResponse = {
      cameras,
      updatedAt: formatCrawledAt(fetchedAt),
      total: cameras.length,
    };

    return NextResponse.json({
      ...response,
      sourceUpdatedAt: updatedAt,
    });
  } catch (error) {
    console.error('Failed to fetch cameras:', error);
    return NextResponse.json(
      { error: 'Failed to fetch camera data' },
      { status: 500 }
    );
  }
}

export async function POST() {
  try {
    const { cameras, updatedAt, fetchedAt } = await refreshCameras();
    const response: CamerasResponse = {
      cameras,
      updatedAt: formatCrawledAt(fetchedAt),
      total: cameras.length,
    };

    return NextResponse.json({
      ...response,
      sourceUpdatedAt: updatedAt,
    });
  } catch (error) {
    console.error('Failed to refresh cameras:', error);
    return NextResponse.json(
      { error: 'Failed to refresh camera data' },
      { status: 500 }
    );
  }
}
