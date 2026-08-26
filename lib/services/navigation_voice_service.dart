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

  bool isActionableStep(RouteStep step) {
    final action = _normalized(step.action);
    final accessorialAction = _normalized(step.accessorialAction);

    if (action.isNotEmpty || accessorialAction.isNotEmpty) {
      return accessorialAction.isNotEmpty || action != '直行';
    }

    // 兼容修正字段映射前保存的路线：直接使用腾讯 instruction，
    // 不再通过关键词猜测动作。
    return step.instruction.trim().isNotEmpty;
  }

  String getDirectionLabel(RouteStep step) {
    final action = _normalized(step.action);
    final accessorialAction = _normalized(step.accessorialAction);
    final structured = '$action$accessorialAction';

    if (structured.isNotEmpty) return structured;

    final instruction = step.instruction.trim();
    return instruction.isNotEmpty ? instruction : '继续行驶';
  }

  IconData getTurnIcon(RouteStep step) {
    final action = _normalized(step.action);
    final accessorialAction = _normalized(step.accessorialAction);

    // 辅助动作只做精确匹配，避免把“不要下桥”误画成“下桥”。
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

  bool needsLongRangeWarning(RouteStep step) {
    return _longRangeActions.contains(_normalized(step.accessorialAction));
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
