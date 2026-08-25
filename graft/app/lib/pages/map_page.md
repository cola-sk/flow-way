# app/lib/pages/map_page.dart

- MapPage · class · L11-L16 — class MapPage extends StatefulWidget
- override · class · L11-L16 — class MapPage extends StatefulWidget
- _MapPageState · class · L18-L568 — class _MapPageState extends State<MapPage>
- MapController · class · L18-L568 — class _MapPageState extends State<MapPage>
- response · variable · L49-L49 — final response = await _apiService.getCameras();
- waypoints · variable · L65-L65 — final waypoints = await _apiService.getWayPoints();
- response · variable · L90-L94 — final response = await _apiService.planRoute(
- nameController · variable · L134-L134 — final nameController = TextEditingController();
- name · variable · L150-L150 — final name = nameController.text.trim();
- success · variable · L158-L161 — final success = await _apiService.saveWayPoint(
- confirmed · variable · L188-L204 — final confirmed = await showDialog<bool>(
- success · variable · L207-L207 — final success = await _apiService.deleteWayPoint(wayPoint.id);
