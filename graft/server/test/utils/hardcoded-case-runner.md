# server/test/utils/hardcoded-case-runner.ts

- Coordinate · type · L5-L9 — type Coordinate = { name: string; lat: number; lng: number; };
- HardcodedAvoidCase · type · L11-L18 — type HardcodedAvoidCase = { caseName: string; start: Coordinate; end: Coordinate; waypoints?: Coordinate[]; retriesPerLeg?: number; maxTotalHits: number; };
- buildBbox · function · L20-L27 — function buildBbox(a: Coordinate, b: Coordinate, padding = 0.06)
- filterCamerasByBbox · function · L29-L40 — function filterCamerasByBbox( cameras: Camera[], bbox: { minLng: number; maxLng: number; minLat: number; maxLat: number } )
- evaluateLegWithRetries · function · L42-L81 — async function evaluateLegWithRetries( from: Coordinate, to: Coordinate, cameras: Camera[], retries: number )
- runHardcodedAvoidCase · function · L83-L127 — async function runHardcodedAvoidCase(caseDef: HardcodedAvoidCase): Promise<void>
