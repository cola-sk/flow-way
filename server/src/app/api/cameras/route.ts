import { NextResponse } from 'next/server';
import { NextRequest } from 'next/server';
import { getCameras } from '@/lib/cache';
import { refreshCameras } from '@/lib/cache';
import { CamerasResponse } from '@/types/camera';
import { requireActiveUserTokenFromRequest } from '@/lib/user-context';

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

export async function POST(request: NextRequest) {
  try {
    const tokenGuard = await requireActiveUserTokenFromRequest(request);
    if (!tokenGuard.ok) {
      return tokenGuard.response!;
    }

    console.info('[camera-api] manual refresh requested');
    const { cameras, updatedAt, fetchedAt } = await refreshCameras();
    const response: CamerasResponse = {
      cameras,
      updatedAt: formatCrawledAt(fetchedAt),
      total: cameras.length,
    };
    console.info(
      `[camera-api] manual refresh succeeded: total=${cameras.length}, sourceUpdatedAt=${updatedAt}`
    );
    return NextResponse.json({
      ...response,
      sourceUpdatedAt: updatedAt,
    });
  } catch (error) {
    console.error('[camera-api] manual refresh failed', error);
    return NextResponse.json(
      { error: 'Failed to refresh camera data' },
      { status: 500 }
    );
  }
}
