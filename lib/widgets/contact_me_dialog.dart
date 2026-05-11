import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

const String kWechatId = 'kero_wi';
const String kXianyuUrl = 'https://m.tb.cn/h.RZUBs4W?tk=VoEy5pFEchA';

Future<void> showContactMeDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('联系我'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('微信号: $kWechatId', style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('复制微信号'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: kWechatId));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('微信号已复制'),
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                  Navigator.of(ctx).pop();
                },
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('打开闲鱼咨询'),
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  final uri = Uri.parse(kXianyuUrl);
                  final ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
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
            ],
          ),
        ],
      ),
    ),
  );
}