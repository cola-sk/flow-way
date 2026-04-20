/**
 * Test Suite: Dynamic Route Planning with Saved Routes
 * 
 * Purpose: Test the camera avoidance routing algorithm against previously saved routes.
 * This test dynamically loads the latest saved route from the database and attempts to
 * plan an alternate route that avoids cameras along the original path.
 * 
 * Prerequisites:
 * - Next.js dev server running on http://localhost:3000
 * - Redis database with saved routes
 * - Camera data available via /api/cameras endpoint
 * 
 * What it tests:
 * - Loading saved routes from persistence layer
 * - Fetching camera data for a geographic bounding box
 * - Running the camera avoidance routing algorithm
 * - Measuring algorithm performance (execution time)
 * - Verifying the algorithm finds alternative routes
 * 
 * Usage: npx ts-node test/test-route.ts
 */

import 'dotenv/config';
import { resolve } from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';
import { config } from 'dotenv';

const __dirname = dirname(fileURLToPath(import.meta.url));
// Load .env.local for Redis credentials
config({ path: resolve(__dirname, '../.env.local') });

import { listRouteRecords } from '../src/lib/saved-navigation';
import { planAvoidCamerasRoute } from '../src/lib/route';
import { Camera } from '../src/types/camera';

/**
 * Fetches cameras within a geographic bounding box via the API.
 * Used since we don't have direct access to the camera DB hook in test context.
 */
async function getCamerasForBboxViaApi(bbox: any): Promise<Camera[]> {
  const url = `http://localhost:3000/api/cameras?minLng=${bbox.minLng}&maxLng=${bbox.maxLng}&minLat=${bbox.minLat}&maxLat=${bbox.maxLat}`;
  const res = await fetch(url);
  const data = await res.json();
  return data.cameras || [];
}

/**
 * Main test execution function.
 * Loads the first saved route from database and runs avoidance routing algorithm on it.
 */
async function test() {
  console.log('\n[TEST] Starting Dynamic Route Planning Test...\n');
  const routes = await listRouteRecords();
  console.log("[INFO] Found", routes.length, "saved routes");
  if(routes.length > 0) {
    const r = routes[0];
    console.log("[INFO] Testing route:", r.name);
    if (r.route?.startPoint && r.route?.endPoint) {
      console.log("[INFO] Start point:", r.route.startPoint);
      console.log("[INFO] End point:", r.route.endPoint);

      const bbox = {
        minLng: Math.min(r.route.startPoint.lng, r.route.endPoint.lng) - 0.05,
        maxLng: Math.max(r.route.startPoint.lng, r.route.endPoint.lng) + 0.05,
        minLat: Math.min(r.route.startPoint.lat, r.route.endPoint.lat) - 0.05,
        maxLat: Math.max(r.route.startPoint.lat, r.route.endPoint.lat) + 0.05,
      };
      
      const cameras = await getCamerasForBboxViaApi(bbox);
      console.log("[INFO] Fetched cameras via API:", cameras.length);
      
      console.log("[INFO] Starting camera-avoidance route planning algorithm...");
      const startT = Date.now();
      const res = await planAvoidCamerasRoute(r.route.startPoint, r.route.endPoint, cameras);
      const executionTime = Date.now() - startT;
      
      console.log("\n[RESULTS] =================================");
      console.log("[RESULT] Execution Time:", executionTime, "ms");
      console.log("[RESULT] Cameras still on route:", res.cameraIndices.length);
      console.log("[RESULT] Total Distance:", res.distance, "meters");
      console.log("[RESULT] ==================================\n");
      
      // Simple pass/fail criteria
      if (res.cameraIndices.length === 0) {
        console.log("✅ [PASS] Route successfully avoids all cameras!");
      } else {
        console.log("⚠️  [WARNING] Route still contains", res.cameraIndices.length, "camera(s). Algorithm may need tuning.");
      }
    }
  } else {
    console.log('[WARNING] No saved routes found. Please save a route first.');
  }
}

test()
  .then(() => {
    console.log('[TEST] Dynamic Route Planning Test completed.\n');
    process.exit(0);
  })
  .catch((error) => {
    console.error('[ERROR]', error);
    process.exit(1);
  });
