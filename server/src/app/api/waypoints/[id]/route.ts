import { NextResponse, NextRequest } from 'next/server';

export const dynamic = 'force-dynamic';

// 引用存储（简化实现）
const wayPointsStorage = new Map<string, any>();

export async function DELETE(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const { id } = params;

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
