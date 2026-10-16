import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hub/widgets/widgets.dart';

class MonthlyCollectionsChart extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  final Map<String, dynamic>? period;

  const MonthlyCollectionsChart({
    super.key,
    required this.records,
    this.period,
  });

  @override
  Widget build(BuildContext context) {
    final List<double> values = records
        .map(
          (record) => ChartHelpers.number(
        record['actual_collections'] ?? 0,
      ),
    )
        .toList();

    final double total = values.fold<double>(
      0.0,
          (sum, value) => sum + value,
    );

    final int payments = records.fold<int>(
      0,
          (sum, record) {
        return sum +
            ChartHelpers.integer(
              record['payment_count'] ?? 0,
            );
      },
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
            icon: Icons.trending_up_rounded,
            title: 'Monthly Collections',
            subtitle: ChartHelpers.periodText(period),
          ),

          const SizedBox(height: 15),

          // ---------------------------------------------------------
          // SUMMARY METRICS
          // ---------------------------------------------------------

          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Total collected',
                  value: ChartHelpers.money(total),
                  icon: Icons.payments_outlined,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _Metric(
                  label: 'Payments',
                  value: '$payments',
                  icon: Icons.receipt_long_outlined,
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // ---------------------------------------------------------
          // COLLECTIONS TREND
          // ---------------------------------------------------------

          SizedBox(
            height: 235,
            child: LineChart(
              LineChartData(
                minY: 0.0,
                maxY: chartMax,

                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval:
                  _horizontalInterval(chartMax),
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
                      interval:
                      _horizontalInterval(chartMax),
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
                      reservedSize: 30,
                      interval: 1.0,
                      getTitlesWidget: (value, meta) {
                        final int index = value.toInt();

                        if (index < 0 ||
                            index >= records.length) {
                          return const SizedBox.shrink();
                        }

                        return Padding(
                          padding: const EdgeInsets.only(
                            top: 8,
                          ),
                          child: Text(
                            _shortLabel(records[index]),
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
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

                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) {
                      return spots.map((spot) {
                        final int index = spot.x.toInt();

                        if (index < 0 ||
                            index >= records.length) {
                          return null;
                        }

                        final record = records[index];

                        final double collection =
                        ChartHelpers.number(
                          record['actual_collections'] ?? 0,
                        );

                        final int paymentCount =
                        ChartHelpers.integer(
                          record['payment_count'] ?? 0,
                        );

                        return LineTooltipItem(
                          '${ChartHelpers.recordLabel(record)}\n'
                              '${ChartHelpers.money(collection)}\n'
                              '$paymentCount payments',
                          const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),

                // ---------------------------------------------------
                // LINE
                // ---------------------------------------------------

                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      records.length,
                          (index) {
                        final double collection =
                        ChartHelpers.number(
                          records[index]
                          ['actual_collections'] ??
                              0,
                        );

                        return FlSpot(
                          index.toDouble(),
                          collection,
                        );
                      },
                    ),

                    isCurved: true,
                    barWidth: 3.0,
                    isStrokeCapRound: true,

                    dotData: const FlDotData(
                      show: true,
                    ),

                    belowBarData: BarAreaData(
                      show: true,
                      color: ChartHelpers.primary
                          .withValues(alpha: 0.08),
                    ),

                    color: ChartHelpers.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _horizontalInterval(double max) {
    if (max <= 1000.0) {
      return 200.0;
    }

    if (max <= 10000.0) {
      return 2000.0;
    }

    if (max <= 50000.0) {
      return 10000.0;
    }

    if (max <= 100000.0) {
      return 20000.0;
    }

    return max / 5.0;
  }

  String _shortLabel(Map<String, dynamic> record) {
    final String label =
    ChartHelpers.recordLabel(record);

    if (label.length > 8) {
      return label.substring(0, 7);
    }

    return label;
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: ChartHelpers.primary,
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey.shade500,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}