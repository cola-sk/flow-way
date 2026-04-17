import { NextRequest, NextResponse } from 'next/server';
import { deleteRouteRecord } from '@/lib/saved-navigation';

export const dynamic = 'force-dynamic';

export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    const ok = await deleteRouteRecord(id);
    if (!ok) {
      return NextResponse.json({ error: '线路不存在' }, { status: 404 });
    }
    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Failed to delete saved route:', error);
    return NextResponse.json({ error: 'Failed to delete saved route' }, { status: 500 });
  }
}
