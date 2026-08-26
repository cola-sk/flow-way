import 'package:flow_way/models/route.dart';
import 'package:flow_way/services/navigation_voice_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = NavigationVoiceService();

  RouteStep step({
    String instruction = '沿道路行驶500米,偏右转进入匝道',
    String? action = '偏右转',
    String? accessorialAction = '进入匝道',
    int start = 10,
    int end = 20,
  }) {
    return RouteStep(
      instruction: instruction,
      distance: 500,
      duration: 30,
      polylineIdxStart: start,
      polylineIdxEnd: end,
      action: action,
      accessorialAction: accessorialAction,
    );
  }

  group('腾讯结构化动作', () {
    test('直接组合 act_desc 和 accessorial_desc', () {
      final routeStep = step();

      expect(service.isActionableStep(routeStep), isTrue);
      expect(service.getDirectionLabel(routeStep), '偏右转进入匝道');
      expect(service.needsLongRangeWarning(routeStep), isTrue);
      expect(service.getTurnIcon(routeStep), Icons.alt_route_rounded);
    });

    test('识别上桥但不推断左右方向', () {
      final routeStep = step(
        instruction: '沿立交桥行驶300米,直行上桥',
        action: '直行',
        accessorialAction: '上桥',
      );

      expect(service.getDirectionLabel(routeStep), '直行上桥');
      expect(service.needsLongRangeWarning(routeStep), isTrue);
      expect(service.getTurnIcon(routeStep), Icons.trending_up_rounded);
    });

    test('否定动作不会映射成相反图标', () {
      final routeStep = step(
        instruction: '沿二环行驶1公里,右转不要下坡',
        action: '右转',
        accessorialAction: '不要下坡',
      );

      expect(service.getDirectionLabel(routeStep), '右转不要下坡');
      expect(service.getTurnIcon(routeStep), Icons.turn_right);
    });

    test('纯直行不播报，直行进入主路需要播报', () {
      final straight = step(
        instruction: '沿京密快速行驶3公里,直行',
        action: '直行',
        accessorialAction: null,
      );
      final enterMainRoad = step(
        instruction: '沿京密路行驶1公里,直行进入主路',
        action: '直行',
        accessorialAction: '进入主路',
      );

      expect(service.isActionableStep(straight), isFalse);
      expect(service.isActionableStep(enterMainRoad), isTrue);
      expect(service.getDirectionLabel(enterMainRoad), '直行进入主路');
    });

    test('旧路线只回退 instruction，不猜测动作或图标', () {
      final oldStep = step(
        instruction: '沿西直门外大街行驶446米,偏右转进入辅路',
        action: null,
        accessorialAction: null,
      );

      expect(service.hasStructuredGuidance(oldStep), isFalse);
      expect(service.isActionableStep(oldStep), isTrue);
      expect(service.getDirectionLabel(oldStep), '沿西直门外大街行驶446米,偏右转进入辅路');
      expect(service.getTurnIcon(oldStep), Icons.navigation);
    });

    test('RouteStep JSON 保留辅助动作字段', () {
      final original = step(accessorialAction: '进入辅路');
      final restored = RouteStep.fromJson(original.toJson());

      expect(restored.action, '偏右转');
      expect(restored.accessorialAction, '进入辅路');
    });
  });

  group('简化播报策略', () {
    final rampStep = step();

    test('简洁模式仅在 150 米和 30 米提示', () {
      final alerted = <String>{};

      expect(
        service.evaluateVoicePrompt(
          step: rampStep,
          remainingDistance: 800,
          mode: VoiceGuidanceMode.concise,
          alertedKeys: alerted,
        ),
        isNull,
      );

      var prompt = service.evaluateVoicePrompt(
        step: rampStep,
        remainingDistance: 140,
        mode: VoiceGuidanceMode.concise,
        alertedKeys: alerted,
      );
      expect(prompt?.text, '前方140米，偏右转进入匝道');
      alerted.add(prompt!.alertKey);

      expect(
        service.evaluateVoicePrompt(
          step: rampStep,
          remainingDistance: 120,
          mode: VoiceGuidanceMode.concise,
          alertedKeys: alerted,
        ),
        isNull,
      );

      prompt = service.evaluateVoicePrompt(
        step: rampStep,
        remainingDistance: 25,
        mode: VoiceGuidanceMode.concise,
        alertedKeys: alerted,
      );
      expect(prompt?.text, '偏右转进入匝道');
    });

    test('详细模式对特殊动作提供远、中、近三档提示', () {
      final alerted = <String>{};

      var prompt = service.evaluateVoicePrompt(
        step: rampStep,
        remainingDistance: 850,
        mode: VoiceGuidanceMode.detailed,
        alertedKeys: alerted,
      );
      expect(prompt?.text, '前方850米，偏右转进入匝道');
      expect(prompt?.text, isNot(contains('变道')));
      alerted.add(prompt!.alertKey);

      prompt = service.evaluateVoicePrompt(
        step: rampStep,
        remainingDistance: 250,
        mode: VoiceGuidanceMode.detailed,
        alertedKeys: alerted,
      );
      expect(prompt?.text, '前方250米，偏右转进入匝道');
      alerted.add(prompt!.alertKey);

      prompt = service.evaluateVoicePrompt(
        step: rampStep,
        remainingDistance: 40,
        mode: VoiceGuidanceMode.detailed,
        alertedKeys: alerted,
      );
      expect(prompt?.text, '偏右转进入匝道');
    });

    test('普通转向不触发远距离提示', () {
      final turn = step(
        instruction: '沿中关村南大街行驶500米,右转',
        action: '右转',
        accessorialAction: null,
      );

      expect(
        service.evaluateVoicePrompt(
          step: turn,
          remainingDistance: 800,
          mode: VoiceGuidanceMode.detailed,
          alertedKeys: <String>{},
        ),
        isNull,
      );
      expect(
        service
            .evaluateVoicePrompt(
              step: turn,
              remainingDistance: 300,
              mode: VoiceGuidanceMode.detailed,
              alertedKeys: <String>{},
            )
            ?.text,
        '前方300米，右转',
      );
    });

    test('左侧匝道保持腾讯返回方向，不生成向右变道', () {
      final leftRamp = step(instruction: '沿道路行驶1公里,偏左转进入匝道', action: '偏左转');

      final prompt = service.evaluateVoicePrompt(
        step: leftRamp,
        remainingDistance: 900,
        mode: VoiceGuidanceMode.detailed,
        alertedKeys: <String>{},
      );

      expect(prompt?.text, '前方900米，偏左转进入匝道');
      expect(prompt?.text, isNot(contains('向右')));
    });
  });
}
