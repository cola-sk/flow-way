import 'package:flutter/material.dart';

import '../models/route.dart';

/// 导航语音播报模式。
enum VoiceGuidanceMode {
  /// 特殊道路动作最远 1 公里预告，普通动作 300 米预告。
  detailed,

  /// 150 米预告，30 米执行提示。
  concise,
}

class VoicePromptEvaluation {
  final String text;
  final String alertKey;

  const VoicePromptEvaluation({required this.text, required this.alertKey});
}

/// 基于腾讯 Direction API 结构化字段生成导航提示。
///
/// 不从自然语言中推断左右方向。新路线使用 act_desc/accessorial_desc；
/// 旧路线没有结构化字段时，原样回退到 instruction。
class NavigationVoiceService {
  const NavigationVoiceService();

  static const Set<String> _longRangeActions = {
    '进入辅路',
    '进入主路',
    '出主路',
    '进高速',
    '进入匝道',
    '驶出高速',
    '驶出当前高速',
    '到达出口',
    '上桥',
    '下桥',
    '上高架',
    '下高架',
  };

  String _normalized(String? value) {
    final text = value?.trim() ?? '';
    return text == '空' ? '' : text;
  }

  bool hasStructuredGuidance(RouteStep step) {
    return _normalized(step.action).isNotEmpty ||
        _normalized(step.accessorialAction).isNotEmpty;
  }

  /// 从自然语言 instruction 中提取简短动作描述（用于兼容旧路线或无结构化动作时的兜底）
  String _extractActionFromInstruction(String instruction) {
    final trimmed = instruction.trim();
    if (trimmed.isEmpty) return '继续行驶';

    // 优先截取最后一个逗号后的动作说明（腾讯常用格式："沿xxx行驶xx米,动作"）
    final commaIndex = trimmed.lastIndexOf(',');
    final chineseCommaIndex = trimmed.lastIndexOf('，');
    final splitIndex = commaIndex > chineseCommaIndex ? commaIndex : chineseCommaIndex;
    if (splitIndex >= 0 && splitIndex + 1 < trimmed.length) {
      final tail = trimmed.substring(splitIndex + 1).trim();
      if (tail.isNotEmpty && tail.length <= 25) {
        return tail;
      }
    }

    // 若无逗号或尾部异常，尝试关键词匹配
    if (trimmed.contains('左转掉头') || trimmed.contains('掉头') || trimmed.contains('调头')) {
      return '掉头';
    }
    if (trimmed.contains('左后转')) return '左后转';
    if (trimmed.contains('右后转')) return '右后转';
    if (trimmed.contains('偏左转') || trimmed.contains('左前方') || trimmed.contains('靠左')) {
      return '偏左转';
    }
    if (trimmed.contains('偏右转') || trimmed.contains('右前方') || trimmed.contains('靠右')) {
      return '偏右转';
    }
    if (trimmed.contains('左转')) return '左转';
    if (trimmed.contains('右转')) return '右转';
    if (trimmed.contains('进入辅路')) return '进入辅路';
    if (trimmed.contains('进入主路') || trimmed.contains('出主路')) return '进入主路';
    if (trimmed.contains('进入匝道')) return '进入匝道';
    if (trimmed.contains('到达目的地') || trimmed.contains('到达终点')) return '到达目的地';
    if (trimmed.contains('直行') || trimmed.contains('直走')) return '直行';

    return trimmed;
  }

  bool isActionableStep(RouteStep step) {
    final action = _normalized(step.action);
    final accessorialAction = _normalized(step.accessorialAction);

    if (action.isNotEmpty || accessorialAction.isNotEmpty) {
      return accessorialAction.isNotEmpty || action != '直行';
    }

    // 兼容旧路线或无结构化字段：从 instruction 提取简短动作，纯直行不予播报
    final extracted = _extractActionFromInstruction(step.instruction);
    if (extracted == '直行' ||
        extracted == '继续直行' ||
        extracted == '请直行' ||
        extracted == '注意直行' ||
        extracted == '继续行驶' ||
        extracted.isEmpty) {
      return false;
    }
    return true;
  }

  String getDirectionLabel(RouteStep step) {
    final action = _normalized(step.action);
    final accessorialAction = _normalized(step.accessorialAction);
    final structured = '$action$accessorialAction';

    if (structured.isNotEmpty) return structured;

    return _extractActionFromInstruction(step.instruction);
  }

  IconData getTurnIcon(RouteStep step) {
    final action = _normalized(step.action);
    final accessorialAction = _normalized(step.accessorialAction);

    // 1. 优先使用结构化动作匹配
    if (action.isNotEmpty || accessorialAction.isNotEmpty) {
      switch (accessorialAction) {
        case '进入辅路':
          return Icons.alt_route_rounded;
        case '进入主路':
        case '出主路':
          return Icons.merge_type_rounded;
        case '进入匝道':
        case '进高速':
        case '驶出高速':
        case '驶出当前高速':
        case '到达出口':
          return Icons.alt_route_rounded;
        case '上桥':
        case '上高架':
        case '上坡':
          return Icons.trending_up_rounded;
        case '下桥':
        case '下高架':
        case '下坡':
          return Icons.trending_down_rounded;
      }

      switch (action) {
        case '左转':
          return Icons.turn_left;
        case '右转':
          return Icons.turn_right;
        case '偏左转':
        case '靠左':
          return Icons.turn_slight_left;
        case '偏右转':
        case '靠右':
          return Icons.turn_slight_right;
        case '左后转':
        case '左转掉头':
          return Icons.u_turn_left;
        case '右后转':
          return Icons.u_turn_right;
        case '进入环岛':
          return Icons.change_circle_outlined;
        case '直行':
          return Icons.straight;
        default:
          return Icons.navigation;
      }
    }

    // 2. 兜底逻辑：无结构化字段时根据提取动作匹配图标
    final label = _extractActionFromInstruction(step.instruction);
    if (label.contains('辅路') || label.contains('匝道') || label.contains('出口')) {
      return Icons.alt_route_rounded;
    }
    if (label.contains('主路')) {
      return Icons.merge_type_rounded;
    }
    if (label.contains('上桥') || label.contains('上高架') || label.contains('上坡')) {
      return Icons.trending_up_rounded;
    }
    if (label.contains('下桥') || label.contains('下高架') || label.contains('下坡')) {
      return Icons.trending_down_rounded;
    }
    if (label.contains('掉头') || label.contains('调头')) {
      return Icons.u_turn_left;
    }
    if (label.contains('偏左') || label.contains('靠左') || label.contains('左前')) {
      return Icons.turn_slight_left;
    }
    if (label.contains('偏右') || label.contains('靠右') || label.contains('右前')) {
      return Icons.turn_slight_right;
    }
    if (label.contains('左转')) {
      return Icons.turn_left;
    }
    if (label.contains('右转')) {
      return Icons.turn_right;
    }
    if (label.contains('直行') || label.contains('直走')) {
      return Icons.straight;
    }
    return Icons.navigation;
  }

  bool needsLongRangeWarning(RouteStep step) {
    final accessorialAction = _normalized(step.accessorialAction);
    if (accessorialAction.isNotEmpty) {
      return _longRangeActions.contains(accessorialAction);
    }
    final label = _extractActionFromInstruction(step.instruction);
    return _longRangeActions.any((action) => label.contains(action));
  }

  String formatDistanceForVoice(double distanceMeters) {
    if (distanceMeters >= 1000) {
      final km = distanceMeters / 1000;
      if ((km - km.round()).abs() < 0.05) {
        return '${km.round()}公里';
      }
      return '${km.toStringAsFixed(1)}公里';
    }
    return '${distanceMeters.round()}米';
  }

  VoicePromptEvaluation? evaluateVoicePrompt({
    required RouteStep step,
    required double remainingDistance,
    required VoiceGuidanceMode mode,
    required Set<String> alertedKeys,
  }) {
    if (!isActionableStep(step) || remainingDistance <= 0) return null;

    final stepId = '${step.polylineIdxStart}-${step.polylineIdxEnd}';
    final label = getDirectionLabel(step);

    if (mode == VoiceGuidanceMode.concise) {
      if (remainingDistance <= 30) {
        return _promptIfNeeded(
          key: '${stepId}_concise_now',
          text: label,
          alertedKeys: alertedKeys,
        );
      }
      if (remainingDistance <= 150) {
        return _promptIfNeeded(
          key: '${stepId}_concise_near',
          text: '前方${formatDistanceForVoice(remainingDistance)}，$label',
          alertedKeys: alertedKeys,
        );
      }
      return null;
    }

    if (remainingDistance <= 50) {
      return _promptIfNeeded(
        key: '${stepId}_detailed_now',
        text: label,
        alertedKeys: alertedKeys,
      );
    }
    if (remainingDistance <= 300) {
      return _promptIfNeeded(
        key: '${stepId}_detailed_near',
        text: '前方${formatDistanceForVoice(remainingDistance)}，$label',
        alertedKeys: alertedKeys,
      );
    }
    if (needsLongRangeWarning(step) && remainingDistance <= 1000) {
      return _promptIfNeeded(
        key: '${stepId}_detailed_far',
        text: '前方${formatDistanceForVoice(remainingDistance)}，$label',
        alertedKeys: alertedKeys,
      );
    }

    return null;
  }

  VoicePromptEvaluation? _promptIfNeeded({
    required String key,
    required String text,
    required Set<String> alertedKeys,
  }) {
    if (alertedKeys.contains(key)) return null;
    return VoicePromptEvaluation(text: text, alertKey: key);
  }
}
