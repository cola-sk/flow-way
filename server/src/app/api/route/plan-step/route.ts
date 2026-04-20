import { NextResponse, NextRequest } from 'next/server';
import { RoutePlanStepRequest, RoutePlanStepResponse } from '@/types/route';
import { getCameras } from '@/lib/cache';
import { createRoute, planAvoidCamerasRoute } from '@/lib/route';
import { getDismissedSet, coordKey } from '@/lib/dismissed-cameras';

export const dynamic = 'force-dynamic';

const DEFAULT_MAX_ITERATIONS = 15;

export async function POST(request: NextRequest) {
  let body: RoutePlanStepRequest | undefined;
  try {
    body = await request.json();
    const reqBody = body;
    if (!reqBody) {
      return NextResponse.json({ errorMessage: '请求体无效' }, { status: 400 });
    }

    const { start, end, iteration } = reqBody;
    const requestedMaxIterations =
      typeof reqBody.maxIterations === 'number' && Number.isFinite(reqBody.maxIterations)
        ? Math.floor(reqBody.maxIterations)
        : DEFAULT_MAX_ITERATIONS;
    const maxIterations = Math.max(requestedMaxIterations, 1);

    if (!start || !end || typeof start.lat !== 'number' || typeof start.lng !== 'number') {
      return NextResponse.json({ errorMessage: '起点坐标无效' }, { status: 400 });
    }
    if (typeof end.lat !== 'number' || typeof end.lng !== 'number') {
      return NextResponse.json({ errorMessage: '终点坐标无效' }, { status: 400 });
    }
    if (typeof iteration !== 'number' || !Number.isFinite(iteration) || iteration < 0) {
      return NextResponse.json({ errorMessage: '迭代次数无效' }, { status: 400 });
    }

    const { cameras: originalCameras } = await getCameras();
    const dismissedSet = await getDismissedSet();
    const ignoreOutsideSixthRing = reqBody.ignoreOutsideSixthRing === true;

    const cameras: typeof originalCameras = [];
    const indexMapping: Record<number, number> = {};

    let filteredIdx = 0;
    for (let i = 0; i < originalCameras.length; i++) {
      const cam = originalCameras[i];
      if (dismissedSet.has(coordKey(cam.lat, cam.lng))) {
        continue;
      }
      if (ignoreOutsideSixthRing && cam.type === 6) {
        continue;
      }
      cameras.push(cam);
      indexMapping[filteredIdx++] = i;
    }

    // 沿用 4/17 高效策略：单次请求内完成完整避让搜索，避免前后端反复往返导致收敛变慢
    const finalState = await planAvoidCamerasRoute(
      start,
      end,
      cameras
    );

    const globalCameraIndices = finalState.cameraIndices.map((i) => indexMapping[i]);

    const currentRoute = createRoute(
      start,
      end,
      finalState.points,
      globalCameraIndices,
      true,
      finalState.distance,
      finalState.duration
    );

    const bestRoute = createRoute(
      start,
      end,
      finalState.points,
      globalCameraIndices,
      true,
      finalState.distance,
      finalState.duration
    );

    const response: RoutePlanStepResponse = {
      currentRoute,
      bestRoute,
      iteration: maxIterations,
      maxIterations,
      done: true,
      anchorDistance: 0,
    };

    return NextResponse.json(response);
  } catch (error) {
    console.error('Failed to plan route step:', error);
    const response: RoutePlanStepResponse = {
      iteration: 0,
      maxIterations: DEFAULT_MAX_ITERATIONS,
      done: true,
      anchorDistance: body?.anchorDistance,
      errorMessage: '路线单步规划失败: ' + String(error),
    };
    return NextResponse.json(response, { status: 500 });
  }
}
