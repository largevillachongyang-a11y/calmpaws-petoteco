// =============================================================================
// state_colors.dart — dominant_state 行为染色（铁律 4，P0-4）
// =============================================================================

import 'package:flutter/material.dart';

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
  };

  static const Map<String, String> stateLabelCN = {
    'calm': '平静',
    'sleep_normal': '睡眠',
    'playing': '玩耍',
    'pacing': '踱步',
    'stressed': '应激',
    'shivering': '颤抖',
    'sleep_abnormal': '睡眠异常',
  };

  static const Map<String, String> stateLabelEN = {
    'calm': 'Calm',
    'sleep_normal': 'Sleep',
    'playing': 'Play',
    'pacing': 'Pacing',
    'stressed': 'Stress',
    'shivering': 'Shiver',
    'sleep_abnormal': 'Lethargy',
  };

  static const List<String> legendOrder = [
    'calm',
    'sleep_normal',
    'playing',
    'pacing',
    'stressed',
    'shivering',
    'sleep_abnormal',
  ];

  static Color colorFor(String state) =>
      stateColorMap[state] ?? const Color(0xFFBDBDBD);

  static String labelFor(String state, bool isZh) =>
      isZh
          ? (stateLabelCN[state] ?? state)
          : (stateLabelEN[state] ?? state);
}
