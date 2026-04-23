// =============================================================================
// stress_chart_card.dart — 14天压力趋势折线图
// =============================================================================
// 展示过去14天的每日压力分 + 喂食日标注，直观呈现 ZenBelly 的长期效果。
//
// 数据来源：PetHealthProvider.stressChartData（List<DailyStressDataPoint>）
//   当前为 generateDailyStressChart() 生成的模拟数据。
//
// [TODO: API 需求] 真实后端接入时替换为：
//   GET /api/health-stats/{petId}?days=14
//   返回: [{ date, stressScore, hasFeeding, timeToCalmSecs }]
// =============================================================================
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../providers/pet_health_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/mock_ble_service.dart';
import '../../theme/app_theme.dart';

class StressChartCard extends StatelessWidget {
  final PetHealthProvider provider;
  const StressChartCard({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LocaleProvider>().strings;
    final data = provider.stressChartData;
    final beforeAvg = data
        .where((d) => !d.isAfterTreatment)
        .map((d) => d.stressScore)
        .fold(0.0, (a, b) => a + b) /
        7;
    final afterAvg = data
        .where((d) => d.isAfterTreatment)
        .map((d) => d.stressScore)
        .fold(0.0, (a, b) => a + b) /
        7;
    final reduction =
        ((beforeAvg - afterAvg) / beforeAvg * 100).clamp(0.0, 100.0);

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
          // Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warmOrangeMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.show_chart_rounded,
                    color: AppColors.warmOrange, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                s.chartTitle,
                style: AppTextStyles.headlineSmall,
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.sageMuted,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  s.chartReduction(reduction.toStringAsFixed(0)),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.sageGreen,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            s.chartSubtitle,
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 20),

          // Chart
          SizedBox(
            height: 180,
            child: LineChart(
              _buildChartData(data),
            ),
          ),

          const SizedBox(height: 16),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: AppColors.chartBefore, label: s.chartLegendBefore),
              const SizedBox(width: 20),
              _LegendDot(color: AppColors.chartAfter, label: s.chartLegendAfter),
              const SizedBox(width: 20),
              // 上周均值参考线图例
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 2,
                    color: AppColors.warningAmber.withValues(alpha: 0.8),
                    margin: const EdgeInsets.only(right: 4),
                  ),
                  Text(
                    '上周均值',
                    style: AppTextStyles.labelSmall.copyWith(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  LineChartData _buildChartData(List<DailyStressDataPoint> data) {
    final beforeSpots = data
        .where((d) => !d.isAfterTreatment)
        .map((d) => FlSpot(d.dayIndex.toDouble(), d.stressScore))
        .toList();
    final afterSpots = data
        .where((d) => d.isAfterTreatment)
        .map((d) => FlSpot(d.dayIndex.toDouble(), d.stressScore))
        .toList();

    // 计算上周（D1-D7）平均分，作为参考线
    final beforeData = data.where((d) => !d.isAfterTreatment).toList();
    final lastWeekAvg = beforeData.isNotEmpty
        ? beforeData.map((d) => d.stressScore).fold(0.0, (a, b) => a + b) /
            beforeData.length
        : 0.0;

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 25,
        getDrawingHorizontalLine: (v) => FlLine(
          color: AppColors.chartGrid,
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
            interval: 1,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i == 0) return _axisLabel('D1');
              if (i == 6) return _axisLabel('D7');
              if (i == 7) return _axisLabel('Day 8', isMarker: true);
              if (i == 13) return _axisLabel('D14');
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: 13,
      minY: 0,
      maxY: 100,
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (spots) => spots
              .map((s) => LineTooltipItem(
                    '${s.y.toStringAsFixed(0)}',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ))
              .toList(),
        ),
      ),
      lineBarsData: [
        // 上周均值参考线（虚线）
        LineChartBarData(
          spots: [FlSpot(0, lastWeekAvg), FlSpot(13, lastWeekAvg)],
          isCurved: false,
          color: AppColors.warningAmber.withValues(alpha: 0.7),
          barWidth: 1.5,
          dashArray: [6, 4],
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
        // Before baseline
        LineChartBarData(
          spots: beforeSpots,
          isCurved: true,
          color: AppColors.chartBefore,
          barWidth: 2.5,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: AppColors.chartBefore.withValues(alpha: 0.08),
          ),
        ),
        // After treatment
        LineChartBarData(
          spots: afterSpots,
          isCurved: true,
          color: AppColors.chartAfter,
          barWidth: 2.5,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: AppColors.chartAfter.withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }

  Widget _axisLabel(String text, {bool isMarker = false}) => Text(
        text,
        style: AppTextStyles.labelSmall.copyWith(
          fontSize: 10,
          color: isMarker ? AppColors.sageGreen : AppColors.textMuted,
          fontWeight: isMarker ? FontWeight.w700 : FontWeight.w400,
        ),
      );
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.bodySmall),
      ],
    );
  }
}
