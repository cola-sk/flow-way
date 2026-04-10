import { NextResponse } from 'next/server';
import { getCameras } from '@/lib/cache';
import { CamerasResponse } from '@/types/camera';

export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    const { cameras, updatedAt } = await getCameras();

    const response: CamerasResponse = {
      cameras,
      updatedAt,
      total: cameras.length,
    };

    return NextResponse.json(response);
  } catch (error) {
    console.error('Failed to fetch cameras:', error);
    return NextResponse.json(
      { error: 'Failed to fetch camera data' },
      { status: 500 }
    );
  }
}
