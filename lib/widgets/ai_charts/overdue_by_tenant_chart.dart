import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hub/widgets/widgets.dart';

class OverdueByTenantChart extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  final Map<String, dynamic>? period;

  const OverdueByTenantChart({
    super.key,
    required this.records,
    this.period,
  });

  @override
  Widget build(BuildContext context) {
    final double total = records.fold<double>(
      0.0,
          (sum, record) {
        return sum +
            ChartHelpers.number(
              record['overdue'] ??
                  record['outstanding'] ??
                  record['amount'],
            );
      },
    );

    final double maxValue = records.fold<double>(
      0.0,
          (max, record) {
        final double value = ChartHelpers.number(
          record['overdue'] ??
              record['outstanding'] ??
              record['amount'],
        );

        return value > max ? value : max;
      },
    );

    final double chartMax = maxValue <= 0.0
        ? 1000.0
        : maxValue * 1.25;

    return ChartCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChartHeader(
            icon: Icons.warning_amber_rounded,
            title: 'Overdue Rent by Tenant',
            subtitle: ChartHelpers.periodText(period),
          ),

          const SizedBox(height: 14),

          // Total overdue summary
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: ChartHelpers.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.error_outline,
                  size: 18,
                  color: ChartHelpers.danger,
                ),
              ),

              const SizedBox(width: 10),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total overdue',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ChartHelpers.money(total),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          SizedBox(
            height: _chartHeight(),
            child: BarChart(
              BarChartData(
                minY: 0.0,
                maxY: chartMax,

                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _interval(chartMax),
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: const Color(0xffE9EDF3),
                    strokeWidth: 1,
                  ),
                ),

                borderData: FlBorderData(
                  show: false,
                ),

                titlesData: FlTitlesData(
                  // Top
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: false,
                    ),
                  ),

                  // Right
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: false,
                    ),
                  ),

                  // Left - money values
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 58,
                      interval: _interval(chartMax),
                      getTitlesWidget: (value, meta) {
                        return Text(
                          ChartHelpers.money(
                            value,
                            compact: true,
                          ),
                          style: TextStyle(
                            fontSize: 8,
                            color: Colors.grey.shade500,
                          ),
                        );
                      },
                    ),
                  ),

                  // Bottom - tenant names
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 48,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final int index = value.toInt();

                        if (index < 0 ||
                            index >= records.length) {
                          return const SizedBox.shrink();
                        }

                        final String label =
                        ChartHelpers.recordLabel(
                          records[index],
                        );

                        return Padding(
                          padding: const EdgeInsets.only(
                            top: 8,
                          ),
                          child: SizedBox(
                            width: 65,
                            child: Text(
                              label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 8,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Tooltip
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem:
                        (group, groupIndex, rod, rodIndex) {
                      if (groupIndex < 0 ||
                          groupIndex >= records.length) {
                        return null;
                      }

                      final record = records[groupIndex];

                      return BarTooltipItem(
                        '${ChartHelpers.recordLabel(record)}\n'
                            '${ChartHelpers.money(rod.toY)}',
                        const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),

                // Bars
                barGroups: List.generate(
                  records.length,
                      (index) {
                    final double value =
                    ChartHelpers.number(
                      records[index]['overdue'] ??
                          records[index]['outstanding'] ??
                          records[index]['amount'],
                    );

                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: value,
                          width: 18,
                          borderRadius: BorderRadius.circular(5),
                          color: ChartHelpers.danger,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _chartHeight() {
    final double base = records.length * 34.0;

    return base.clamp(180.0, 420.0).toDouble();
  }

  double _interval(double max) {
    if (max <= 1000.0) {
      return 200.0;
    }

    if (max <= 10000.0) {
      return 2000.0;
    }

    if (max <= 50000.0) {
      return 10000.0;
    }

    return max / 5.0;
  }
}