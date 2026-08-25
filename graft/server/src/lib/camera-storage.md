# server/src/lib/camera-storage.ts

- CameraSnapshot · interface · L4-L8 — interface CameraSnapshot
- normalizeSnapshot · function · L14-L40 — function normalizeSnapshot(raw: unknown): CameraSnapshot | null
- findHistoricalKeys · function · L42-L63 — async function findHistoricalKeys(): Promise<string[]>
- loadCameraSnapshotFromKv · function · L65-L69 — async function loadCameraSnapshotFromKv(): Promise<CameraSnapshot | null>
- saveCameraSnapshotToKv · function · L71-L109 — async function saveCameraSnapshotToKv(input: { cameras: Camera[]; updatedAt: string; }): Promise<CameraSnapshot>
