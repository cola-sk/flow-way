# lib/pages/save_route_dialog.dart

- NavigationRoute · class · L6-L20 — class SaveRouteDialog extends StatefulWidget
- SaveRouteDialog · class · L6-L20 — class SaveRouteDialog extends StatefulWidget
- _SaveRouteDialogState · class · L22-L130 — class _SaveRouteDialogState extends State<SaveRouteDialog>
- TextEditingController · class · L22-L130 — class _SaveRouteDialogState extends State<SaveRouteDialog>
- startName · variable · L29-L29 — final startName = widget.stops.isNotEmpty ? widget.stops.first.name : '起点';
- endName · variable · L30-L30 — final endName = widget.stops.length >= 2 ? widget.stops.last.name : '终点';
- name · variable · L41-L41 — final name = _nameController.text.trim();
- success · variable · L59-L63 — final success = await widget.apiService.saveNavigationRoute(
