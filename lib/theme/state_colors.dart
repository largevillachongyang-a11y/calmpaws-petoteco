// =============================================================================
// state_colors.dart — dominant_state 行为染色（铁律 4，P0-4）
// =============================================================================

import 'package:flutter/material.dart';
import '../models/models.dart';

class StateColors {
  StateColors._();

  static const Map<String, Color> stateColorMap = {
    'calm': Color(0xFF4CAF50),
    'sleep_normal': Color(0xFF66BB6A),
    'playing': Color(0xFF42A5F5),
    'pacing': Color(0xFFFFC107),
    'stressed': Color(0xFFFF9800),
    'shivering': Color(0xFFF44336),
    'sleep_abnormal': Color(0xFFFF5722),
    'suspected_not_worn': Color(0xFF90A4AE),
    'not_worn': Color(0xFF78909C),
    'notWorn': Color(0xFF78909C),
  };

  static const Map<String, String> stateLabelCN = {
    'calm': '平静',
    'sleep_normal': '睡眠',
    'playing': '玩耍',
    'pacing': '踱步',
    'stressed': '应激',
    'shivering': '颤抖',
    'sleep_abnormal': '睡眠异常',
    'suspected_not_worn': '疑似未佩戴',
    'not_worn': '未佩戴',
    'notWorn': '未佩戴',
  };

  /// 图例用短标签（避免英文一行挤不下 7 项）
  static const Map<String, String> stateLabelEN = {
    'calm': 'Calm',
    'sleep_normal': 'Sleep',
    'playing': 'Play',
    'pacing': 'Pace',
    'stressed': 'Stress',
    'shivering': 'Shiver',
    'sleep_abnormal': 'Lethargy',
    'suspected_not_worn': 'Possibly not worn',
    'not_worn': 'Not worn',
    'notWorn': 'Not worn',
  };

  static const List<String> legendOrder = [
    'calm',
    'sleep_normal',
    'playing',
    'pacing',
    'stressed',
    'shivering',
    'sleep_abnormal',
    'suspected_not_worn',
    'not_worn',
  ];

  static Color colorFor(String state) =>
      stateColorMap[state] ?? const Color(0xFFBDBDBD);

  static String labelFor(String state, bool isZh) =>
      isZh ? (stateLabelCN[state] ?? state) : (stateLabelEN[state] ?? state);

  /// /api/status 的 label 字段 → UI 行为枚举（snake_case）
  static PetBehaviorState? behaviorFromLabel(String? label) {
    switch (label) {
      case 'calm':
        return PetBehaviorState.calm;
      case 'pacing':
        return PetBehaviorState.pacing;
      case 'stressed':
        return PetBehaviorState.stressed;
      case 'playing':
        return PetBehaviorState.playing;
      case 'shivering':
        return PetBehaviorState.shivering;
      case 'sleep_normal':
        return PetBehaviorState.sleepNormal;
      case 'sleep_abnormal':
        return PetBehaviorState.sleepAbnormal;
      case 'suspected_not_worn':
      case 'suspectedNotWorn':
        return PetBehaviorState.suspectedNotWorn;
      case 'not_worn':
      case 'notWorn':
        return PetBehaviorState.notWorn;
      default:
        return null;
    }
  }
}
