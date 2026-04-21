import { NextRequest, NextResponse } from 'next/server';
import { deleteRoutePlanRecord } from '@/lib/saved-navigation';
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
    const ok = await deleteRoutePlanRecord(tokenGuard.userToken!, id);
    if (!ok) {
      return NextResponse.json({ error: '点位方案不存在' }, { status: 404 });
    }
    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Failed to delete saved route plan:', error);
    return NextResponse.json({ error: 'Failed to delete saved route plan' }, { status: 500 });
  }
}
