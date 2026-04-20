import { getCameras } from '../../src/lib/cache';
import { planAvoidCamerasRoute } from '../../src/lib/route';
import { Camera } from '../../src/types/camera';

type Coordinate = {
  name: string;
  lat: number;
  lng: number;
};

type HardcodedAvoidCase = {
  caseName: string;
  start: Coordinate;
  end: Coordinate;
  waypoints?: Coordinate[];
  retriesPerLeg?: number;
  maxTotalHits: number;
};

function buildBbox(a: Coordinate, b: Coordinate, padding = 0.06) {
  return {
    minLng: Math.min(a.lng, b.lng) - padding,
    maxLng: Math.max(a.lng, b.lng) + padding,
    minLat: Math.min(a.lat, b.lat) - padding,
    maxLat: Math.max(a.lat, b.lat) + padding,
  };
}

function filterCamerasByBbox(
  cameras: Camera[],
  bbox: { minLng: number; maxLng: number; minLat: number; maxLat: number }
) {
  return cameras.filter(
    (c) =>
      c.lng >= bbox.minLng &&
      c.lng <= bbox.maxLng &&
      c.lat >= bbox.minLat &&
      c.lat <= bbox.maxLat
  );
}

async function evaluateLegWithRetries(
  from: Coordinate,
  to: Coordinate,
  cameras: Camera[],
  retries: number
) {
  let best: Awaited<ReturnType<typeof planAvoidCamerasRoute>> | null = null;
  let lastError: unknown;

  for (let i = 0; i < retries; i++) {
    try {
      const result = await planAvoidCamerasRoute(
        { lat: from.lat, lng: from.lng },
        { lat: to.lat, lng: to.lng },
        cameras
      );

      if (
        !best ||
        result.cameraIndices.length < best.cameraIndices.length ||
        (result.cameraIndices.length === best.cameraIndices.length && result.distance < best.distance)
      ) {
        best = result;
      }

      if (best.cameraIndices.length === 0) {
        break;
      }
    } catch (error) {
      lastError = error;
      console.warn(`[WARN] Leg retry ${i + 1} failed:`, error);
    }
  }

  if (!best) {
    throw lastError ?? new Error('Leg planning failed without detailed error.');
  }

  return best;
}

export async function runHardcodedAvoidCase(caseDef: HardcodedAvoidCase): Promise<void> {
  const retriesPerLeg = caseDef.retriesPerLeg ?? 3;
  const { cameras: allCameras } = await getCameras();
  const stops: Coordinate[] = [caseDef.start, ...(caseDef.waypoints ?? []), caseDef.end];

  let totalHits = 0;
  let totalDistance = 0;
  let totalDuration = 0;

  console.log(`\n[CASE] ${caseDef.caseName}`);
  console.log(`[CASE] legs=${stops.length - 1}, retriesPerLeg=${retriesPerLeg}, cameras=${allCameras.length}`);

  for (let i = 0; i < stops.length - 1; i++) {
    const from = stops[i];
    const to = stops[i + 1];
    const bbox = buildBbox(from, to);
    const legCameras = filterCamerasByBbox(allCameras, bbox);
    const result = await evaluateLegWithRetries(from, to, legCameras, retriesPerLeg);

    const legHits = result.cameraIndices.length;
    totalHits += legHits;
    totalDistance += result.distance;
    totalDuration += result.duration;

    console.log(
      `[LEG ${i + 1}] ${from.name} -> ${to.name} | hits=${legHits} distance=${Math.round(result.distance)} duration=${Math.round(result.duration)}`
    );
  }

  console.log(
    `[RESULT] hits=${totalHits}, maxAllowed=${caseDef.maxTotalHits}, distance=${Math.round(totalDistance)}, duration=${Math.round(totalDuration)}`
  );

  if (totalHits > caseDef.maxTotalHits) {
    throw new Error(
      `Case failed: hits=${totalHits} exceeds maxAllowed=${caseDef.maxTotalHits}`
    );
  }

  if (totalDistance <= 0 || totalDuration <= 0) {
    throw new Error('Case failed: invalid total distance or duration.');
  }

  console.log('[PASS] Case passed.');
}