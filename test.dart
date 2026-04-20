import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() {
  final _hitNotifier = LayerHitNotifier<String>();
  _hitNotifier.addListener(() {
    print(_hitNotifier.value?.hitValues);
  });
  final p = Polyline<String>(points: [LatLng(0,0)], hitValue: "hi");
  final pl = PolylineLayer<String>(
    hitNotifier: _hitNotifier,
    polylines: [p],
  );
}
