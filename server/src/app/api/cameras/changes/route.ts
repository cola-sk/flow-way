import { NextRequest, NextResponse } from 'next/server';
import {
  calculateDistanceMeters,
  getLatestCameraDiffReport,
  CameraDiffReport,
  CameraChangeRecord,
} from '@/lib/camera-changes';

export const dynamic = 'force-dynamic';

export async function GET(request: NextRequest) {
  try {
    const report = await getLatestCameraDiffReport();
    if (!report) {
      return NextResponse.json({
        report: null,
        message: 'No diff report available yet.',
      });
    }

    const searchParams = request.nextUrl.searchParams;
    const centerLat = searchParams.get('lat')
      ? parseFloat(searchParams.get('lat')!)
      : null;
    const centerLng = searchParams.get('lng')
      ? parseFloat(searchParams.get('lng')!)
      : null;
    const radius = searchParams.get('radius')
      ? parseFloat(searchParams.get('radius')!)
      : null;

    const swLat = searchParams.get('swLat')
      ? parseFloat(searchParams.get('swLat')!)
      : null;
    const swLng = searchParams.get('swLng')
      ? parseFloat(searchParams.get('swLng')!)
      : null;
    const neLat = searchParams.get('neLat')
      ? parseFloat(searchParams.get('neLat')!)
      : null;
    const neLng = searchParams.get('neLng')
      ? parseFloat(searchParams.get('neLng')!)
      : null;

    // 如果未指定范围参数，直接返回全量报告
    const isCircleFilter =
      centerLat !== null && centerLng !== null && radius !== null;
    const isRectFilter =
      swLat !== null && swLng !== null && neLat !== null && neLng !== null;

    if (!isCircleFilter && !isRectFilter) {
      return NextResponse.json({
        report,
      });
    }

    // 根据指定范围过滤变动记录
    let filteredRecords: CameraChangeRecord[] = [];

    if (isCircleFilter) {
      filteredRecords = report.records.filter((r) => {
        const d = calculateDistanceMeters(centerLat!, centerLng!, r.lat, r.lng);
        return d <= radius!;
      });
    } else if (isRectFilter) {
      const minLat = Math.min(swLat!, neLat!);
      const maxLat = Math.max(swLat!, neLat!);
      const minLng = Math.min(swLng!, neLng!);
      const maxLng = Math.max(swLng!, neLng!);

      filteredRecords = report.records.filter(
        (r) =>
          r.lat >= minLat &&
          r.lat <= maxLat &&
          r.lng >= minLng &&
          r.lng <= maxLng
      );
    }

    const filteredReport: CameraDiffReport = {
      ...report,
      totalChanges: filteredRecords.length,
      addedCount: filteredRecords.filter((r) => r.changeType === 'added').length,
      removedCount: filteredRecords.filter((r) => r.changeType === 'removed')
        .length,
      typeChangedCount: filteredRecords.filter(
        (r) => r.changeType === 'typeChanged'
      ).length,
      infoChangedCount: filteredRecords.filter(
        (r) => r.changeType === 'infoChanged'
      ).length,
      records: filteredRecords,
    };

    return NextResponse.json({
      report: filteredReport,
      isFiltered: true,
    });
  } catch (error) {
    console.error('Failed to query camera changes:', error);
    return NextResponse.json(
      { error: 'Failed to query camera changes' },
      { status: 500 }
    );
  }
}
