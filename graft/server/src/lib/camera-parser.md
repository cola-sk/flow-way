# server/src/lib/camera-parser.ts

- extractDirection · function · L13-L32 — function extractDirection(name: string): CameraDirection
- extractStatus · function · L38-L62 — function extractStatus(name: string, type: number, date: string): CameraStatus
- extractOtherFlags · function · L67-L90 — function extractOtherFlags(name: string): string[]
- extractLocationInfo · function · L95-L122 — function extractLocationInfo(name: string): { district?: string; location?: string; road?: string; }
- createEnhancedCamera · function · L127-L152 — function createEnhancedCamera( id: string, name: string, lng: number, lat: number, type: number, date: string, href: string, editTime?: string ): EnhancedCamera
- angleBetweenBearings · function · L159-L166 — function angleBetweenBearings(bearing1: number, bearing2: number): number
- calculateBearing · function · L172-L185 — function calculateBearing( fromLat: number, fromLng: number, toLat: number, toLng: number ): number
- willBeDetectedByCamera · function · L191-L226 — function willBeDetectedByCamera( cameraLat: number, cameraLng: number, cameraDirection: CameraDirection, routeStartLat: number, routeStartLng: number, routeEndLat: number, routeEndLng: number, detectionAngleTolerance: number = 90 // 默认±90度范围内可被拍到 ): boolean
- CameraRisk · interface · L231-L237 — interface CameraRisk
- assessCameraRisks · function · L239-L306 — function assessCameraRisks( route: Array<{ lat: number; lng: number }>, cameras: EnhancedCamera[], detectionThreshold: number = 100 // 100米范围内视为靠近 ): CameraRisk[]
- toRad · function · L309-L311 — function toRad(degree: number): number
- calculateDistance · function · L313-L325 — function calculateDistance(lat1: number, lng1: number, lat2: number, lng2: number): number
