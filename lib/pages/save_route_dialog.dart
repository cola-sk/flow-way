import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/route.dart';
import '../services/api_service.dart';

class SaveRouteDialog extends StatefulWidget {
  final NavigationRoute route;
  final ApiService apiService;
  final List<PlaceResult> stops;
  
  const SaveRouteDialog({
    Key? key,
    required this.route,
    required this.apiService,
    required this.stops,
  }) : super(key: key);

  @override
  State<SaveRouteDialog> createState() => _SaveRouteDialogState();
}

class _SaveRouteDialogState extends State<SaveRouteDialog> {
  final TextEditingController _nameController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final startName = widget.stops.isNotEmpty ? widget.stops.first.name : '起点';
    final endName = widget.stops.length >= 2 ? widget.stops.last.name : '终点';
    _nameController.text = '$startName -> $endName路线';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入路线名称')),
      );
      return;
    }

    setState(() => _saving = true);

    final success = await widget.apiService.saveNavigationRoute(
      route: widget.route,
      name: name,
      stops: widget.stops,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存成功')),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存失败，请重试')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('保存此导航路线'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('保存后可在"已保存路线"中快速发起，无需再次计算避让路径。', style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '路线名称',
              hintText: '例如：避开某某路常走路段',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('保存'),
        ),
      ],
    );
  }
}
