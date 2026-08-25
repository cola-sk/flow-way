# server/src/lib/waypoints-storage.ts

- userWaypointsKey · function · L12-L14 — function userWaypointsKey(userToken: string): string
- sortByCreatedAtDesc · function · L16-L18 — function sortByCreatedAtDesc(items: WayPoint[]): WayPoint[]
- ensureLegacyMigrated · function · L20-L48 — async function ensureLegacyMigrated(userToken: string): Promise<void>
- listWayPoints · function · L50-L56 — async function listWayPoints(userToken: string): Promise<WayPoint[]>
- saveWayPoint · function · L58-L62 — async function saveWayPoint(userToken: string, wayPoint: WayPoint): Promise<void>
- deleteWayPointById · function · L64-L69 — async function deleteWayPointById(userToken: string, id: string): Promise<boolean>
