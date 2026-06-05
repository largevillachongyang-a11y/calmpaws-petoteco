// =============================================================================
// stress_chart_card.dart — 焦虑历史图表（P0-4）
// =============================================================================
// 数据来源：PetHealthProvider.history24h / history7d / history30d（/api/history）
// 24h：折线图（按 dominant_state 分段染色，无数据时段断开）
// 7d/30d：柱状图（按 dominant_state 染色，无数据天灰色空柱）
// =============================================================================

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../models/history_models.dart';
import '../../providers/pet_health_provider.dart';
import '../../providers/locale_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/state_colors.dart';
import '../../utils/app_strings.dart';

class StressChartCard extends StatefulWidget {
  final PetHealthProvider provider;
  const StressChartCard({super.key, required this.provider});

  @override
  State<StressChartCard> createState() => _StressChartCardState();
}

class _StressChartCardState extends State<StressChartCard> {
  int _tabIndex = 0;

  static const _ranges = [HistoryRange.h24, HistoryRange.d7, HistoryRange.d30];

  HistoryResponse? get _currentResponse {
    switch (_tabIndex) {
      case 0:
        return widget.provider.history24h;
      case 1:
        return widget.provider.history7d;
      case 2:
        return widget.provider.history30d;
      default:
        return widget.provider.history24h;
    }
  }

  String get _currentRange => _ranges[_tabIndex];

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LocaleProvider>().strings;
    final isZh = context.watch<LocaleProvider>().isZh;
    final provider = widget.provider;
    final response = _currentResponse;
    final loading = provider.isLoadingHistory &&
        (response == null || !_hasChartData(response));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warmOrangeMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.show_chart_rounded,
                  color: AppColors.warmOrange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.chartTitle, style: AppTextStyles.headlineSmall),
                    Text(s.chartSubtitle, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              if (provider.useRealServer)
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  color: AppColors.textMuted,
                  tooltip: isZh ? '从服务器重新加载' : 'Reload from server',
                  onPressed: provider.isLoadingHistory
                      ? null
                      : () => provider.loadServerHistory(clearBeforeLoad: true),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _RangeTabs(
            index: _tabIndex,
            labels: [s.chartTab24h, s.chartTab7d, s.chartTab30d],
            onChanged: (i) => setState(() => _tabIndex = i),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: _buildChartBody(s, isZh, loading, response),
          ),
          const SizedBox(height: 12),
          if (response != null && _hasChartData(response)) ...[
            _SummaryRow(response: response, s: s),
            const SizedBox(height: 10),
          ],
          _StateLegend(isZh: isZh),
          const SizedBox(height: 8),
          ..._footerLines(s, response),
        ],
      ),
    );
  }

  Widget _buildChartBody(
    AppStrings s,
    bool isZh,
    bool loading,
    HistoryResponse? response,
  ) {
    if (!widget.provider.useRealServer) {
      return _CenterMessage(s.chartMockHint);
    }
    if (loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: 10),
            Text(s.chartLoading, style: AppTextStyles.bodySmall),
          ],
        ),
      );
    }
    if (response?.error != null) {
      return _CenterMessage(response!.error!);
    }
    if (response == null || !_hasChartData(response)) {
      if (_tabIndex == 0) {
        final weekDays = widget.provider.history7d?.summary.daysWithData ?? 0;
        return _CenterMessage(
          s.chartNoData24h,
          subtext: weekDays > 0 ? s.chartNoData24hHint : null,
        );
      }
      return _CenterMessage(s.chartNoData);
    }

    if (_tabIndex == 0) {
      return LineChart(_build24hChart(response));
    }
    return BarChart(_buildDailyChart(response, _tabIndex == 1 ? 7 : 30));
  }

  /// 24h：需有带 time 的数据点；7d/30d：需有 record_count>0 的天
  bool _hasChartData(HistoryResponse response) {
    if (_tabIndex == 0) {
      return response.points.any((p) => p.time != null && p.recordCount > 0);
    }
    return response.points.any((p) => p.date != null && p.recordCount > 0);
  }

  int _daysWithRecords(HistoryResponse? response) {
    if (response == null) return 0;
    return response.points.where((p) => p.recordCount > 0).length;
  }

  List<Widget> _footerLines(AppStrings s, HistoryResponse? response) {
    final style = AppTextStyles.bodySmall.copyWith(fontSize: 12);
    if (!widget.provider.useRealServer) {
      return [Text(s.chartMockHint, style: style)];
    }
    if (response == null) {
      return [Text(s.chartNoData, style: style)];
    }

    final lines = <Widget>[];

    if (_tabIndex == 0) {
      if (!_hasChartData(response)) {
        lines.add(Text(s.chartNoData24hFooter, style: style));
        final week = widget.provider.history7d;
        final withData = week?.summary.daysWithData ?? 0;
        if (withData > 0) {
          final hours = (week!.summary.onlineHoursTotal ??
                  (week.summary.onlineMinutesTotal ?? 0) / 60.0)
              .toStringAsFixed(1);
          lines.add(const SizedBox(height: 4));
          lines.add(
            Text(
              s.chartMonitoredPeriod(withData, 7, hours),
              style: style.copyWith(color: AppColors.textMuted),
            ),
          );
        }
        return lines;
      }
      final mins = response.summary.onlineMinutes ?? 0;
      lines.add(Text(s.chartMonitoredToday(mins ~/ 60, mins % 60), style: style));
      return lines;
    }

    if (!_hasChartData(response)) {
      lines.add(Text(s.chartNoData, style: style));
      return lines;
    }

    final withData =
        response.summary.daysWithData ?? _daysWithRecords(response);
    final total = response.summary.daysTotal ?? (_tabIndex == 1 ? 7 : 30);
    final hours = (response.summary.onlineHoursTotal ??
            (response.summary.onlineMinutesTotal ?? 0) / 60.0)
        .toStringAsFixed(1);
    lines.add(Text(s.chartMonitoredPeriod(withData, total, hours), style: style));
    return lines;
  }

  LineChartData _build24hChart(HistoryResponse response) {
    final sorted = response.points
        .where((p) => p.localDateTime != null)
        .toList()
      ..sort((a, b) => a.time!.compareTo(b.time!));

    final intervalSec = response.intervalSeconds ?? 300;
    final gapThreshold = intervalSec * 2.5;

    double xOf(HistoryPoint p) {
      final dt = p.localDateTime!;
      return dt.hour + dt.minute / 60.0 + dt.second / 3600.0;
    }

    final segments = <LineChartBarData>[];
    for (var i = 0; i < sorted.length - 1; i++) {
      final a = sorted[i];
      final b = sorted[i + 1];
      final gap = (b.time! - a.time!).abs();
      if (gap > gapThreshold) continue;

      segments.add(
        LineChartBarData(
          spots: [FlSpot(xOf(a), a.anxietyScore), FlSpot(xOf(b), b.anxietyScore)],
          isCurved: false,
          color: StateColors.colorFor(b.dominantState),
          barWidth: 2.5,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      );
    }

    final dotBars = sorted.map((p) {
      final x = xOf(p);
      return LineChartBarData(
        spots: [FlSpot(x, p.anxietyScore)],
        color: StateColors.colorFor(p.dominantState),
        barWidth: 0,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
            radius: 3,
            color: StateColors.colorFor(p.dominantState),
            strokeWidth: 0,
          ),
        ),
        belowBarData: BarAreaData(show: false),
      );
    }).toList();

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 25,
        getDrawingHorizontalLine: (_) => FlLine(
          color: AppColors.chartGrid,
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 32,
            interval: 25,
            getTitlesWidget: (v, _) => Text(
              v.toInt().toString(),
              style: AppTextStyles.labelSmall.copyWith(fontSize: 11),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 22,
            interval: 6,
            getTitlesWidget: (v, _) {
              final h = v.toInt();
              if (h == 0 || h == 6 || h == 12 || h == 18 || h == 24) {
                return Text(
                  '${h.toString().padLeft(2, '0')}:00',
                  style: AppTextStyles.labelSmall.copyWith(fontSize: 10),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: 24,
      minY: 0,
      maxY: 100,
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (spots) => spots
              .map(
                (spot) => LineTooltipItem(
                  spot.y.toStringAsFixed(0),
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              )
              .toList(),
        ),
      ),
      lineBarsData: [...segments, ...dotBars],
    );
  }

  BarChartData _buildDailyChart(HistoryResponse response, int dayCount) {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: dayCount - 1));

    final byDate = <String, HistoryPoint>{};
    for (final p in response.points) {
      if (p.date != null) byDate[p.date!] = p;
    }

    final groups = <BarChartGroupData>[];
    for (var i = 0; i < dayCount; i++) {
      final d = start.add(Duration(days: i));
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final point = byDate[key];
      final hasData = point != null && point.recordCount > 0;

      if (hasData) {
        // 焦虑分为 0 时仍显示细柱，表示「有监测、状态平静」
        final barH = point.anxietyScore > 0 ? point.anxietyScore : 5.0;
        groups.add(
          BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: barH,
                color: StateColors.colorFor(point.dominantState),
                width: dayCount <= 7 ? 18 : 8,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(3)),
              ),
            ],
          ),
        );
      } else {
        // 无数据天：不画柱，避免底部灰色半圆伪影
        groups.add(
          BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: 0,
                color: Colors.transparent,
                width: dayCount <= 7 ? 18 : 8,
                borderRadius: BorderRadius.zero,
              ),
            ],
          ),
        );
      }
    }

    return BarChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 25,
        getDrawingHorizontalLine: (_) => FlLine(
          color: AppColors.chartGrid,
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 32,
            interval: 25,
            getTitlesWidget: (v, _) => Text(
              v.toInt().toString(),
              style: AppTextStyles.labelSmall.copyWith(fontSize: 11),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 22,
            interval: dayCount <= 7 ? 1 : 5,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= dayCount) return const SizedBox.shrink();
              if (dayCount > 7 && i % 5 != 0 && i != dayCount - 1) {
                return const SizedBox.shrink();
              }
              final d = start.add(Duration(days: i));
              final label = dayCount <= 7
                  ? '${d.month}/${d.day}'
                  : '${d.month}/${d.day}';
              return Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(fontSize: 9),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      minY: 0,
      maxY: 100,
      barGroups: groups,
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final d = start.add(Duration(days: group.x));
            final key =
                '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
            final point = byDate[key];
            if (point == null || point.recordCount == 0) {
              return BarTooltipItem(
                '—',
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            }
            final score = point.anxietyScore;
            return BarTooltipItem(
              score.toStringAsFixed(0),
              const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RangeTabs extends StatelessWidget {
  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  const _RangeTabs({
    required this.index,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = i == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? AppColors.cardBackground : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: AppColors.shadowColor,
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? AppColors.sageGreen
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final HistoryResponse response;
  final AppStrings s;

  const _SummaryRow({required this.response, required this.s});

  @override
  Widget build(BuildContext context) {
    final summary = response.summary;
    return Row(
      children: [
        _Chip(
          label: '${s.chartAvgAnxiety} ${summary.avgAnxiety.toStringAsFixed(0)}',
          color: StateColors.colorFor(summary.dominantState),
        ),
        const SizedBox(width: 8),
        _Chip(
          label: '${s.chartPeakAnxiety} ${summary.peakAnxiety}',
          color: AppColors.warmOrange,
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _StateLegend extends StatelessWidget {
  final bool isZh;
  const _StateLegend({required this.isZh});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      children: StateColors.legendOrder.map((state) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: StateColors.colorFor(state),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              StateColors.labelFor(state, isZh),
              style: AppTextStyles.labelSmall.copyWith(fontSize: 10),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _CenterMessage extends StatelessWidget {
  final String text;
  final String? subtext;
  const _CenterMessage(this.text, {this.subtext});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtext != null) ...[
              const SizedBox(height: 6),
              Text(
                subtext!,
                style: AppTextStyles.bodySmall.copyWith(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
