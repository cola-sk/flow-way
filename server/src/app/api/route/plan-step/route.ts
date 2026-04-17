import { NextResponse, NextRequest } from 'next/server';
import { RoutePlanStepRequest, RoutePlanStepResponse } from '@/types/route';
import { getCameras } from '@/lib/cache';
import { createRoute, planAvoidCamerasRouteStep, AvoidRouteStepState } from '@/lib/route';
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

    let { cameras } = await getCameras();
    const dismissedSet = await getDismissedSet();
    if (dismissedSet.size > 0) {
      cameras = cameras.filter((cam) => !dismissedSet.has(coordKey(cam.lat, cam.lng)));
    }

    let bestState: AvoidRouteStepState | undefined;
    if (reqBody.bestRoute) {
      bestState = {
        points: reqBody.bestRoute.polylinePoints,
        cameraIndices: reqBody.bestRoute.cameraIndicesOnRoute,
        distance: reqBody.bestRoute.distance,
        duration: reqBody.bestRoute.duration,
      };
    }

    const step = await planAvoidCamerasRouteStep(
      start,
      end,
      cameras,
      iteration,
      bestState,
      reqBody.anchorDistance
    );

    const currentRoute = createRoute(
      start,
      end,
      step.current.points,
      step.current.cameraIndices,
      true,
      step.current.distance,
      step.current.duration
    );

    const bestRoute = createRoute(
      start,
      end,
      step.best.points,
      step.best.cameraIndices,
      true,
      step.best.distance,
      step.best.duration
    );

    const response: RoutePlanStepResponse = {
      currentRoute,
      bestRoute,
      iteration,
      maxIterations,
      done: step.done,
      anchorDistance: step.anchorDistance,
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
