import { NextRequest, NextResponse } from 'next/server';
import { getCameras } from '@/lib/cache';
import { getDismissedMap, coordKey } from '@/lib/dismissed-cameras';
import { listRiskPointAvoidanceTargets } from '@/lib/risk-points-storage';
import { findCamerasNearRoute } from '@/lib/route';
import { requireActiveUserTokenFromRequest } from '@/lib/user-context';
import type { RoutePoint } from '@/types/route';

export const dynamic = 'force-dynamic';

type DetectCamerasRequest = {
  polylinePoints?: RoutePoint[];
  avoidCameras?: boolean;
  ignoreOutsideSixthRing?: boolean;
  ignoreLowRiskCameras?: boolean;
  userToken?: string;
};

export async function POST(request: NextRequest) {
  try {
    const body: DetectCamerasRequest = await request.json();

    const tokenGuard = await requireActiveUserTokenFromRequest(
      request,
      body as unknown as Record<string, unknown>
    );
    if (!tokenGuard.ok) {
      return tokenGuard.response!;
    }

    const points = body.polylinePoints;
    if (
      !Array.isArray(points) ||
      points.length < 2 ||
      points.some(
        (p) =>
          typeof p?.lat !== 'number' ||
          typeof p?.lng !== 'number' ||
          !Number.isFinite(p.lat) ||
          !Number.isFinite(p.lng)
      )
    ) {
      return NextResponse.json(
        { errorMessage: '路线坐标无效，无法检测摄像头' },
        { status: 400 }
      );
    }

    const { cameras: originalCameras } = await getCameras();
    const dismissedMap = await getDismissedMap(tokenGuard.userToken!);
    const shouldIgnoreOutsideSixth =
      body.avoidCameras === true && body.ignoreOutsideSixthRing === true;
    const shouldIgnoreLowRisk =
      body.avoidCameras === true && body.ignoreLowRiskCameras === true;

    const cameras: typeof originalCameras = [];
    const indexMapping: Record<number, number> = {};
    const riskPointIdByPlanningIndex = new Map<number, string>();
    let filteredIdx = 0;

    for (let i = 0; i < originalCameras.length; i++) {
      const cam = originalCameras[i];
      const markType = dismissedMap.get(coordKey(cam.lat, cam.lng));

      if (markType !== undefined) {
        if (markType === 12 && !shouldIgnoreLowRisk) {
          // 低风险摄像头在用户未选择忽略时仍参与检测。
        } else {
          continue;
        }
      }

      if (shouldIgnoreOutsideSixth && cam.type === 6) {
        continue;
      }

      cameras.push(cam);
      indexMapping[filteredIdx++] = i;
    }

    if (body.avoidCameras === true) {
      const riskPointTargets = await listRiskPointAvoidanceTargets(
        tokenGuard.userToken!,
        shouldIgnoreLowRisk
      );
      for (const target of riskPointTargets) {
        riskPointIdByPlanningIndex.set(cameras.length, target.riskPointId);
        cameras.push(target.camera);
      }
    }

    const matchedIndices = findCamerasNearRoute(points, cameras);
    const cameraIndicesOnRoute = matchedIndices.flatMap((idx) => {
      const cameraIndex = indexMapping[idx];
      return cameraIndex === undefined ? [] : [cameraIndex];
    });
    const riskPointIdsOnRoute = matchedIndices.flatMap((idx) => {
      const riskPointId = riskPointIdByPlanningIndex.get(idx);
      return riskPointId === undefined ? [] : [riskPointId];
    });

    return NextResponse.json({ cameraIndicesOnRoute, riskPointIdsOnRoute });
  } catch (error) {
    console.error('Failed to detect cameras on route:', error);
    return NextResponse.json(
      { errorMessage: '摄像头重新检测失败: ' + String(error) },
      { status: 500 }
    );
  }
}
