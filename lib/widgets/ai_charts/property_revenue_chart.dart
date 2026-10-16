import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hub/widgets/widgets.dart';

class PropertyRevenueChart extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  final Map<String, dynamic>? period;

  const PropertyRevenueChart({
    super.key,
    required this.records,
    this.period,
  });

  @override
  Widget build(BuildContext context) {
    final List<double> values = records
        .map(
          (record) => ChartHelpers.number(
        record['revenue'] ??
            record['actual_revenue'] ??
            record['amount'] ??
            record['total'] ??
            0,
      ),
    )
        .toList();

    final double total = values.fold<double>(
      0.0,
          (sum, value) => sum + value,
    );

    final double maxValue = values.fold<double>(
      0.0,
          (max, value) {
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
            icon: Icons.account_balance_wallet_outlined,
            title: 'Property Revenue',
            subtitle: ChartHelpers.periodText(period),
          ),

          const SizedBox(height: 14),

          // ---------------------------------------------------------
          // TOTAL REVENUE
          // ---------------------------------------------------------

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xffF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.payments_outlined,
                  size: 17,
                  color: ChartHelpers.success,
                ),

                const SizedBox(width: 8),

                Text(
                  'Total revenue',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),

                const Spacer(),

                Text(
                  ChartHelpers.money(total),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ---------------------------------------------------------
          // REVENUE BAR CHART
          // ---------------------------------------------------------

          SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                minY: 0.0,
                maxY: chartMax,

                alignment: BarChartAlignment.spaceAround,

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
                  // -------------------------------------------------
                  // TOP
                  // -------------------------------------------------

                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: false,
                    ),
                  ),

                  // -------------------------------------------------
                  // RIGHT
                  // -------------------------------------------------

                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: false,
                    ),
                  ),

                  // -------------------------------------------------
                  // LEFT
                  // -------------------------------------------------

                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 48,
                      interval: _interval(chartMax),
                      getTitlesWidget: (value, meta) {
                        return Text(
                          ChartHelpers.money(
                            value,
                            compact: true,
                          ).replaceFirst('Ksh ', ''),
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey.shade500,
                          ),
                        );
                      },
                    ),
                  ),

                  // -------------------------------------------------
                  // BOTTOM
                  // -------------------------------------------------

                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      interval: 1.0,
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
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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

                // ---------------------------------------------------
                // TOOLTIP
                // ---------------------------------------------------

                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem:
                        (group, groupIndex, rod, rodIndex) {
                      if (groupIndex < 0 ||
                          groupIndex >= records.length) {
                        return null;
                      }

                      final record =
                      records[groupIndex];

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

                // ---------------------------------------------------
                // BARS
                // ---------------------------------------------------

                barGroups: List.generate(
                  records.length,
                      (index) {
                    final double value =
                    ChartHelpers.number(
                      records[index]['revenue'] ??
                          records[index]['actual_revenue'] ??
                          records[index]['amount'] ??
                          records[index]['total'] ??
                          0,
                    );

                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: value,
                          width: records.length > 8
                              ? 12.0
                              : 22.0,
                          borderRadius:
                          const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                          color: ChartHelpers.primary,
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