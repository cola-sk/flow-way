import { NextResponse, NextRequest } from 'next/server';
import { wayPointsStorage } from '@/lib/waypoints-storage';

export const dynamic = 'force-dynamic';

export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;

    if (!wayPointsStorage.has(id)) {
      return NextResponse.json(
        { error: '标记点不存在' },
        { status: 404 }
      );
    }

    wayPointsStorage.delete(id);

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Failed to delete waypoint:', error);
    return NextResponse.json(
      { error: 'Failed to delete waypoint' },
      { status: 500 }
    );
  }
}
