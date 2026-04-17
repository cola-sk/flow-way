import { NextRequest, NextResponse } from 'next/server';
import { deleteRecentNavigationRecord } from '@/lib/saved-navigation';

export const dynamic = 'force-dynamic';

export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    const ok = await deleteRecentNavigationRecord(id);
    if (!ok) {
      return NextResponse.json({ error: '记录不存在' }, { status: 404 });
    }
    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Failed to delete recent navigation:', error);
    return NextResponse.json({ error: 'Failed to delete recent navigation' }, { status: 500 });
  }
}
