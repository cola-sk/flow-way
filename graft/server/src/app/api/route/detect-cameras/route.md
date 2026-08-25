# server/src/app/api/route/detect-cameras/route.ts

- DetectCamerasRequest · type · L10-L16 — type DetectCamerasRequest = { polylinePoints?: RoutePoint[]; avoidCameras?: boolean; ignoreOutsideSixthRing?: boolean; ignoreLowRiskCameras?: boolean; userToken?: string; };
- POST · function · L18-L91 — async function POST(request: NextRequest)
