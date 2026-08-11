import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flow_way/pages/test_tools_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_tts'),
          (call) async => switch (call.method) {
            'getDefaultEngine' => 'com.samsung.SMT',
            'getEngines' => ['com.samsung.SMT'],
            'getDefaultVoice' => {'name': 'zh-CN', 'locale': 'zh-CN'},
            'isLanguageAvailable' => true,
            'isLanguageInstalled' => true,
            'speak' => 1,
            _ => 1,
          },
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null);
  });

  testWidgets('opens audio diagnostics and records a hearing result', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: TestToolsPage()));

    expect(find.text('测试工具'), findsOneWidget);
    expect(find.text('音频播放测试'), findsOneWidget);

    await tester.tap(find.text('音频播放测试'));
    await tester.pumpAndSettle();

    expect(find.text('基础文字转语音'), findsOneWidget);
    expect(find.text('导航音频通道'), findsOneWidget);

    await tester.tap(find.text('播放测试语音').first);
    await tester.pump();
    await tester.tap(find.text('听到了').first);
    await tester.pump();

    final selectedChip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, '听到了').first,
    );
    expect(selectedChip.selected, isTrue);

    await tester.scrollUntilVisible(
      find.text('完整导航播报链路'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('完整导航播报链路'), findsOneWidget);
  });
}
