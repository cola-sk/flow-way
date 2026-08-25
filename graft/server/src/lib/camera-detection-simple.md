# server/src/lib/camera-detection-simple.ts

- calculateBearing · function · L12-L25 — function calculateBearing( fromLat: number, fromLng: number, toLat: number, toLng: number ): number
- minAngleBetween · function · L30-L33 — function minAngleBetween(bearing1: number, bearing2: number): number
- isDetectedByCamera · function · L49-L64 — function isDetectedByCamera( routeBearing: number, cameraBearing: number, detectionAngle: number = 90 ): boolean
- willBeDetected · function · L77-L98 — function willBeDetected( routeStart: { lat: number; lng: number }, routeEnd: { lat: number; lng: number }, cameraLat: number, cameraLng: number, cameraDirection: CameraDirection, detectionAngle: number = 90 ): boolean
- isRouteDetected · function · L111-L172 — function isRouteDetected( routePolyline: Array<{ lat: number; lng: number }>, cameraLat: number, cameraLng: number, cameraDirection: CameraDirection, distanceThreshold: number = 100 ): boolean
- checkCameraOnSegment · function · L178-L227 — function checkCameraOnSegment( latA: number, lngA: number, latB: number, lngB: number, latC: number, lngC: number, maxCrossTrackDist: number = 40, maxLongitudinalDist: number = 5 ): boolean
- calculateDistance · function · L232-L245 — function calculateDistance(lat1: number, lng1: number, lat2: number, lng2: number): number
- demonstrateDetection · function · L250-L273 — function demonstrateDetection()
