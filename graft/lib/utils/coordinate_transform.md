# lib/utils/coordinate_transform.dart

- CoordinateTransform · class · L6-L58 — class CoordinateTransform
- double · class · L6-L58 — class CoordinateTransform
- ret · variable · L16-L17 — var ret =
- ret · variable · L28-L29 — var ret =
- dLat · variable · L44-L44 — var dLat = _transformLat(lng - 105.0, lat - 35.0);
- dLng · variable · L45-L45 — var dLng = _transformLng(lng - 105.0, lat - 35.0);
- radLat · variable · L46-L46 — final radLat = lat / 180.0 * _pi;
- magic · variable · L47-L47 — var magic = math.sin(radLat);
- sqrtMagic · variable · L49-L49 — final sqrtMagic = math.sqrt(magic);
- mgLat · variable · L54-L54 — final mgLat = lat + dLat;
- mgLng · variable · L55-L55 — final mgLng = lng + dLng;
