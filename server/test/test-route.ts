import { loadEnvConfig } from '@next/env';
import { resolve } from 'path';

loadEnvConfig(resolve(__dirname, '../'));

import { listRouteRecords } from '../src/lib/saved-navigation';
import { planAvoidCamerasRoute } from '../src/lib/route';
import { Camera } from '../src/types/camera';

// simple fetch wrapper because we don't have camera DB hook directly here
async function getCamerasForBboxViaApi(bbox: any): Promise<Camera[]> {
  const url = `http://localhost:3000/api/cameras?minLng=${bbox.minLng}&maxLng=${bbox.maxLng}&minLat=${bbox.minLat}&maxLat=${bbox.maxLat}`;
  const res = await fetch(url);
  const data = await res.json();
  return data.cameras || [];
}

async function test() {
  const routes = await listRouteRecords();
  console.log("Found", routes.length, "routes");
  if(routes.length > 0) {
    const r = routes[0];
    console.log("Name:", r.name);
    if (r.route?.startPoint && r.route?.endPoint) {
      console.log("Start:", r.route.startPoint);
      console.log("End:", r.route.endPoint);

      const bbox = {
        minLng: Math.min(r.route.startPoint.lng, r.route.endPoint.lng) - 0.05,
        maxLng: Math.max(r.route.startPoint.lng, r.route.endPoint.lng) + 0.05,
        minLat: Math.min(r.route.startPoint.lat, r.route.endPoint.lat) - 0.05,
        maxLat: Math.max(r.route.startPoint.lat, r.route.endPoint.lat) + 0.05,
      };
      
      const cameras = await getCamerasForBboxViaApi(bbox);
      console.log("Fetched cameras via API:", cameras.length);
      
      console.log("Starting route plan...");
      const startT = Date.now();
      const res = await planAvoidCamerasRoute(r.route.startPoint, r.route.endPoint, cameras);
      console.log("===================================");
      console.log("Plan time:", Date.now() - startT, "ms");
      console.log("Camera count under risk:", res.cameraIndices.length);
      console.log("Total Distance:", res.distance, "meters");
    }
  }
}
test().catch(console.error);
