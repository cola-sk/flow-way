# server/src/lib/dismissed-cameras.ts

- CameraMarkType · type · L17-L17 — type CameraMarkType = 6 | 12;
- DismissedCamera · interface · L20-L27 — interface DismissedCamera
- userHashKey · function · L33-L35 — function userHashKey(userToken: string): string
- ensureLegacyMigrated · function · L37-L68 — async function ensureLegacyMigrated(userToken: string): Promise<void>
- coordKey · function · L71-L73 — function coordKey(lat: number, lng: number): string
- normalizeMarkType · function · L75-L80 — function normalizeMarkType(value: unknown): CameraMarkType
- parseLatLngFromKey · function · L82-L90 — function parseLatLngFromKey(key: string): { lat: number; lng: number } | null
- normalizeDismissedCamera · function · L92-L142 — function normalizeDismissedCamera(raw: unknown, key?: string): DismissedCamera | null
- isDismissed · function · L144-L149 — async function isDismissed(userToken: string, lat: number, lng: number): Promise<boolean>
- markDismissed · function · L151-L172 — async function markDismissed( userToken: string, lat: number, lng: number, name: string, type: CameraMarkType = DEFAULT_MARK_TYPE, note?: string ): Promise<DismissedCamera>
- updateDismissedNote · function · L174-L196 — async function updateDismissedNote( userToken: string, lat: number, lng: number, note?: string ): Promise<DismissedCamera | null>
- unmarkDismissed · function · L199-L204 — async function unmarkDismissed(userToken: string, lat: number, lng: number): Promise<boolean>
- getDismissedList · function · L206-L216 — async function getDismissedList(userToken: string): Promise<DismissedCamera[]>
- getDismissedSet · function · L224-L235 — async function getDismissedSet(userToken: string): Promise<Set<string>>
- getDismissedMap · function · L239-L250 — async function getDismissedMap(userToken: string): Promise<Map<string, CameraMarkType>>
- invalidateDismissedCache · function · L253-L261 — function invalidateDismissedCache(userToken?: string): void
