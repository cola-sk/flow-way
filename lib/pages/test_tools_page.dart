import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TestToolsPage extends StatelessWidget {
  const TestToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('测试工具')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            '用于定位设备兼容性问题。测试结果不会自动上传，可由你确认后复制并反馈。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  Icons.record_voice_over_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              title: const Text(
                '音频播放测试',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('逐步测试系统 TTS、导航音频通道和音频焦点。'),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AudioTestToolPage(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              '更多测试工具将在这里陆续加入',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _AudioVerdict { untested, heard, notHeard }

class _AudioTestCase {
  final String id;
  final String title;
  final String description;
  final String text;
  final bool navigationAttributes;
  final bool requestAudioFocus;

  const _AudioTestCase({
    required this.id,
    required this.title,
    required this.description,
    required this.text,
    required this.navigationAttributes,
    required this.requestAudioFocus,
  });
}

class AudioTestToolPage extends StatefulWidget {
  const AudioTestToolPage({super.key});

  @override
  State<AudioTestToolPage> createState() => _AudioTestToolPageState();
}

class _AudioTestToolPageState extends State<AudioTestToolPage> {
  static const _tests = <_AudioTestCase>[
    _AudioTestCase(
      id: 'basic_tts',
      title: '基础文字转语音',
      description: '仅设置中文、语速和音量，不启用导航音频通道。',
      text: '基础语音测试。如果你听到这句话，请选择听到了。',
      navigationAttributes: false,
      requestAudioFocus: false,
    ),
    _AudioTestCase(
      id: 'navigation_channel',
      title: '导航音频通道',
      description: '启用导航语音通道，但暂不主动申请音频焦点。',
      text: '导航音频通道测试。前方三百米有摄像头。',
      navigationAttributes: true,
      requestAudioFocus: false,
    ),
    _AudioTestCase(
      id: 'navigation_full',
      title: '完整导航播报链路',
      description: '使用与导航页相同的音频通道，并申请短暂音频焦点。',
      text: '完整导航语音测试。前方一百米右转。',
      navigationAttributes: true,
      requestAudioFocus: true,
    ),
  ];

  final FlutterTts _flutterTts = FlutterTts();
  final Map<String, _AudioVerdict> _verdicts = {
    for (final test in _tests) test.id: _AudioVerdict.untested,
  };
  final Map<String, String> _statuses = {};
  final Map<String, String> _environment = {};
  final List<String> _logs = [];

  String? _activeTestId;
  bool _loadingEnvironment = true;
  bool _environmentExpanded = false;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _flutterTts.setStartHandler(() {
      _recordCallback('系统回调：开始播放');
    });
    _flutterTts.setCompletionHandler(() {
      _recordCallback('系统回调：播放完成');
    });
    _flutterTts.setCancelHandler(() {
      _recordCallback('系统回调：播放取消');
    });
    _flutterTts.setErrorHandler((message) {
      _recordCallback('系统回调：错误 $message');
    });
    unawaited(_loadEnvironment());
  }

  @override
  void dispose() {
    unawaited(_flutterTts.stop());
    super.dispose();
  }

  Future<String> _readValue(Future<dynamic> Function() read) async {
    try {
      final value = await read();
      return _formatValue(value);
    } catch (error) {
      return '读取失败：$error';
    }
  }

  String _formatValue(dynamic value) {
    if (value == null) return '无';
    if (value is Iterable) return value.join(', ');
    if (value is Map) {
      return value.entries.map((e) => '${e.key}=${e.value}').join(', ');
    }
    return value.toString();
  }

  String _platformLabel() {
    if (kIsWeb) return '网页端';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Android',
      TargetPlatform.iOS => 'iOS',
      TargetPlatform.macOS => 'macOS',
      TargetPlatform.windows => 'Windows',
      TargetPlatform.linux => 'Linux',
      TargetPlatform.fuchsia => 'Fuchsia',
    };
  }

  String _testLabel(String testId) {
    for (final test in _tests) {
      if (test.id == testId) return test.title;
    }
    return testId;
  }

  Future<void> _loadEnvironment() async {
    final values = <String, String>{'平台': _platformLabel()};
    if (_isAndroid) {
      values['默认 TTS 引擎'] = await _readValue(
        () => _flutterTts.getDefaultEngine,
      );
      values['已安装 TTS 引擎'] = await _readValue(() => _flutterTts.getEngines);
      values['默认音色'] = await _readValue(() => _flutterTts.getDefaultVoice);
      values['中文语言可用'] = await _readValue(
        () => _flutterTts.isLanguageAvailable('zh-CN'),
      );
      values['中文语音已安装'] = await _readValue(
        () => _flutterTts.isLanguageInstalled('zh-CN'),
      );
    } else {
      values['中文语言可用'] = await _readValue(
        () => _flutterTts.isLanguageAvailable('zh-CN'),
      );
    }
    if (!mounted) return;
    setState(() {
      _environment
        ..clear()
        ..addAll(values);
      _loadingEnvironment = false;
    });
  }

  void _recordCallback(String message) {
    if (!mounted || _activeTestId == null) return;
    final testId = _activeTestId!;
    setState(() {
      _statuses[testId] = message;
      _logs.add(
        '${DateTime.now().toIso8601String()} [${_testLabel(testId)}] $message',
      );
    });
  }

  Future<void> _runTest(_AudioTestCase test) async {
    await _flutterTts.stop();
    if (!mounted) return;
    setState(() {
      _activeTestId = test.id;
      _statuses[test.id] = '正在准备播放…';
      _logs.add('${DateTime.now().toIso8601String()} [${test.title}] 开始测试');
    });

    try {
      final languageResult = await _flutterTts.setLanguage('zh-CN');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      if (_isAndroid && test.navigationAttributes) {
        await _flutterTts.setAudioAttributesForNavigation();
      }
      final speakResult = await _flutterTts.speak(
        test.text,
        focus: test.requestAudioFocus,
      );
      if (!mounted) return;
      setState(() {
        _statuses[test.id] = '播放请求已发送，请根据实际听感选择结果';
        _logs.add(
          '${DateTime.now().toIso8601String()} [${test.title}] '
          '设置语言=$languageResult，播放=$speakResult，'
          '导航通道=${test.navigationAttributes ? '是' : '否'}，'
          '申请音频焦点=${test.requestAudioFocus ? '是' : '否'}',
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statuses[test.id] = '调用异常：$error';
        _logs.add(
          '${DateTime.now().toIso8601String()} [${test.title}] 调用异常：$error',
        );
      });
    }
  }

  void _setVerdict(String testId, _AudioVerdict verdict) {
    setState(() => _verdicts[testId] = verdict);
  }

  String _verdictLabel(_AudioVerdict verdict) => switch (verdict) {
    _AudioVerdict.untested => '未确认',
    _AudioVerdict.heard => '听到了',
    _AudioVerdict.notHeard => '没听到',
  };

  String _buildFeedback() {
    final buffer = StringBuffer()
      ..writeln('绕川音频测试反馈')
      ..writeln('测试时间：${DateTime.now().toIso8601String()}')
      ..writeln()
      ..writeln('设备语音环境：');
    for (final entry in _environment.entries) {
      buffer.writeln('- ${entry.key}：${entry.value}');
    }
    buffer
      ..writeln()
      ..writeln('测试结果：');
    for (final test in _tests) {
      buffer.writeln(
        '- ${test.title}：${_verdictLabel(_verdicts[test.id]!)}；'
        '${_statuses[test.id] ?? '未运行'}',
      );
    }
    buffer
      ..writeln()
      ..writeln('系统回调记录：');
    if (_logs.isEmpty) {
      buffer.writeln('- 无');
    } else {
      for (final log in _logs) {
        buffer.writeln('- $log');
      }
    }
    return buffer.toString();
  }

  Future<void> _copyFeedback() async {
    await Clipboard.setData(ClipboardData(text: _buildFeedback()));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('测试结果已复制，可以直接发送反馈')));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('音频播放测试')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text('请先调高媒体音量，并按顺序播放三个测试。每次播放后选择“听到了”或“没听到”。'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildEnvironmentCard(context),
          const SizedBox(height: 16),
          for (var i = 0; i < _tests.length; i++) ...[
            _buildTestCard(context, i + 1, _tests[i]),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 4),
          FilledButton.icon(
            onPressed: _copyFeedback,
            icon: const Icon(Icons.copy_all_rounded),
            label: const Text('复制测试结果'),
          ),
          const SizedBox(height: 8),
          Text(
            '结果仅保存在当前页面，离开后会清空，不会自动上传。',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildEnvironmentCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(
                        () => _environmentExpanded = !_environmentExpanded,
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          const Text(
                            '设备语音环境',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _environmentExpanded
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '重新读取',
                  onPressed: _loadingEnvironment
                      ? null
                      : () {
                          setState(() => _loadingEnvironment = true);
                          unawaited(_loadEnvironment());
                        },
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            if (_environmentExpanded) ...[
              if (_loadingEnvironment)
                const LinearProgressIndicator()
              else
                for (final entry in _environment.entries)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${entry.key}：',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(text: entry.value),
                        ],
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTestCard(BuildContext context, int index, _AudioTestCase test) {
    final scheme = Theme.of(context).colorScheme;
    final verdict = _verdicts[test.id]!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    '$index',
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        test.title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        test.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _runTest(test),
                icon: const Icon(Icons.volume_up_rounded),
                label: Text(_statuses.containsKey(test.id) ? '重新播放' : '播放测试语音'),
              ),
            ),
            if (_statuses[test.id] case final status?) ...[
              const SizedBox(height: 8),
              Text(
                status,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                const Text(
                  '实际听感：',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('听到了'),
                  selected: verdict == _AudioVerdict.heard,
                  onSelected: (_) => _setVerdict(test.id, _AudioVerdict.heard),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('没听到'),
                  selected: verdict == _AudioVerdict.notHeard,
                  onSelected: (_) =>
                      _setVerdict(test.id, _AudioVerdict.notHeard),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
