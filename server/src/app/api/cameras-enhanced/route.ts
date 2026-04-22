import { NextResponse } from 'next/server';
import { getCamerasEnhanced } from '@/lib/cache';

export const dynamic = 'force-dynamic';

function formatCrawledAt(fetchedAt: number): string {
  const dt = new Date(fetchedAt);
  const two = (n: number) => n.toString().padStart(2, '0');
  return `${dt.getFullYear()}-${two(dt.getMonth() + 1)}-${two(dt.getDate())} ${two(dt.getHours())}:${two(dt.getMinutes())}:${two(dt.getSeconds())}`;
}

export async function GET() {
  try {
    const { cameras, updatedAt, fetchedAt } = await getCamerasEnhanced();

    const response = {
      cameras,
      updatedAt: formatCrawledAt(fetchedAt),
      sourceUpdatedAt: updatedAt,
      total: cameras.length,
    };

    return NextResponse.json(response);
  } catch (error) {
    console.error('Failed to fetch enhanced cameras:', error);
    return NextResponse.json(
      { error: 'Failed to fetch camera data' },
      { status: 500 }
    );
  }
}
