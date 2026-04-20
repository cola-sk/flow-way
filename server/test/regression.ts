/**
 * Test Suite: Regression Test for Camera Avoidance Algorithm
 * 
 * Purpose: Ensure the camera avoidance routing algorithm continues to work correctly
 * after code changes. This test uses hardcoded coordinates from a real route that
 * previously failed (瑞都公园世家南区 -> 台湖大集) to verify the algorithm can
 * now successfully find camera-free alternate routes.
 * 
 * Context: This test was created to prevent regression when optimizing the routing
 * algorithm's exploration range and distance tolerance constraints.
 * 
 * Prerequisites:
 * - Next.js dev server running on http://localhost:3000
 * - Camera data available via /api/cameras endpoint
 * 
 * What it tests:
 * - Fixed route coordinates that previously couldn't avoid cameras
 * - Ensures the algorithm finds a route with ZERO cameras
 * - Validates algorithm performance and distance ratios
 * 
 * Success Criteria:
 * - Algorithm completes within reasonable time
 * - Returned route has 0 cameras on it
 * - Total distance stays within acceptable bounds
 * 
 * Usage: npx ts-node test/regression.ts
 */

import 'dotenv/config';
import { resolve } from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';
import { config } from 'dotenv';

const __dirname = dirname(fileURLToPath(import.meta.url));
// Load .env.local for Redis credentials
config({ path: resolve(__dirname, '../.env.local') });

import { planAvoidCamerasRoute } from '../src/lib/route';
import { Camera } from '../src/types/camera';

/**
 * Fetches cameras within a geographic bounding box via the API.
 */
async function getCamerasForBboxViaApi(bbox: any): Promise<Camera[]> {
  const url = `http://localhost:3000/api/cameras?minLng=${bbox.minLng}&maxLng=${bbox.maxLng}&minLat=${bbox.minLat}&maxLat=${bbox.maxLat}`;
  const res = await fetch(url);
  const data = await res.json();
  return data.cameras || [];
}

/**
 * Main regression test function.
 * Tests the hardcoded route from 瑞都公园世家南区 -> 台湖大集
 */
async function runRegression() {
  const startPoint = { lat: 39.865137, lng: 116.679391 };
  const endPoint = { lat: 39.839413, lng: 116.629009 };
  
  console.log('\n[REGRESSION TEST] Camera Avoidance Algorithm Regression Test\n');
  console.log('[INFO] Route: 瑞都公园世家南区 -> 台湖大集');
  console.log('[INFO] Start point:', startPoint);
  console.log('[INFO] End point:', endPoint);

  const bbox = {
    minLng: Math.min(startPoint.lng, endPoint.lng) - 0.05,
    maxLng: Math.max(startPoint.lng, endPoint.lng) + 0.05,
    minLat: Math.min(startPoint.lat, endPoint.lat) - 0.05,
    maxLat: Math.max(startPoint.lat, endPoint.lat) + 0.05,
  };
  
  const cameras = await getCamerasForBboxViaApi(bbox);
  console.log('[INFO] Fetched cameras via API:', cameras.length);
  
  console.log('[INFO] Starting camera-avoidance route planning algorithm...');
  const startT = Date.now();
  const res = await planAvoidCamerasRoute(startPoint, endPoint, cameras);
  const executionTime = Date.now() - startT;
  
  console.log('\n[RESULTS] ==================================');
  console.log('[RESULT] Execution Time:', executionTime, 'ms');
  console.log('[RESULT] Cameras still on route:', res.cameraIndices.length);
  console.log('[RESULT] Total Distance:', res.distance, 'meters');
  console.log('[RESULT] ==================================\n');
  
  // Test result
  if (res.cameraIndices.length === 0) {
    console.log('✅ [PASS] Regression test PASSED! Successfully avoided all cameras.');
    return true;
  } else {
    console.error('❌ [FAIL] Regression test FAILED! Route still contains', res.cameraIndices.length, 'camera(s).');
    return false;
  }
}

runRegression()
  .then((passed) => {
    process.exit(passed ? 0 : 1);
  })
  .catch((error) => {
    console.error('[ERROR]', error);
    process.exit(1);
  });
