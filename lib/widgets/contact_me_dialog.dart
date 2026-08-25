import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

const String kDefaultWechatId = '';
const String kDefaultXianyuUrl = '';

String _cachedWechatId = kDefaultWechatId;
String _cachedXianyuUrl = kDefaultXianyuUrl;

Future<void> showContactMeDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => const _ContactMeDialog(),
  );
}

class _ContactMeDialog extends StatefulWidget {
  const _ContactMeDialog();

  @override
  State<_ContactMeDialog> createState() => _ContactMeDialogState();
}

class _ContactMeDialogState extends State<_ContactMeDialog> {
  late String _wechatId;
  late String _xianyuUrl;
  bool _fetching = false;

  @override
  void initState() {
    super.initState();
    _wechatId = _cachedWechatId;
    _xianyuUrl = _cachedXianyuUrl;
    _fetchLatestContact();
  }

  Future<void> _fetchLatestContact() async {
    setState(() => _fetching = true);
    try {
      final info = await ApiService().getContactInfo();
      if (info != null && mounted) {
        setState(() {
          if (info.wechatId.isNotEmpty) {
            _wechatId = info.wechatId;
            _cachedWechatId = info.wechatId;
          }
          if (info.xianyuUrl.isNotEmpty) {
            _xianyuUrl = info.xianyuUrl;
            _cachedXianyuUrl = info.xianyuUrl;
          }
        });
      }
    } catch (_) {
      // 忽略异常，使用默认/缓存值
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('联系我'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('微信号: ', style: TextStyle(fontSize: 14)),
              SelectableText(
                _wechatId.isEmpty ? '加载中...' : _wechatId,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('复制微信号'),
              onPressed: _wechatId.isEmpty
                  ? null
                  : () async {
                      await Clipboard.setData(ClipboardData(text: _wechatId));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('微信号已复制到剪贴板'),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                      if (mounted) Navigator.of(context).pop();
                    },
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(_fetching ? '获取链接中...' : '打开闲鱼咨询'),
              onPressed: _xianyuUrl.isEmpty
                  ? null
                  : () async {
                      Navigator.of(context).pop();
                      final uri = Uri.parse(_xianyuUrl);
                      final ok = await launchUrl(uri,
                          mode: LaunchMode.platformDefault);
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('打开闲鱼链接失败'),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6E5E0D),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}