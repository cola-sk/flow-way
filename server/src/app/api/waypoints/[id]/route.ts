import { NextResponse, NextRequest } from 'next/server';
import { deleteWayPointById } from '@/lib/waypoints-storage';
import { requireActiveUserTokenFromRequest } from '@/lib/user-context';

export const dynamic = 'force-dynamic';

export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const tokenGuard = await requireActiveUserTokenFromRequest(request);
    if (!tokenGuard.ok) {
      return tokenGuard.response!;
    }

    const { id } = await params;

    const deleted = await deleteWayPointById(tokenGuard.userToken!, id);
    if (!deleted) {
      return NextResponse.json(
        { error: '标记点不存在' },
        { status: 404 }
      );
    }

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Failed to delete waypoint:', error);
    return NextResponse.json(
      { error: 'Failed to delete waypoint' },
      { status: 500 }
    );
  }
}
