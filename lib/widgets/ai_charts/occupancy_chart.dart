import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hub/widgets/widgets.dart';

class OccupancyChart extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  final Map<String, dynamic>? period;

  const OccupancyChart({
    super.key,
    required this.records,
    this.period,
  });

  @override
  Widget build(BuildContext context) {
    final List<double> values = records
        .map(
          (record) => ChartHelpers.number(
        record['occupancy_rate'] ??
            record['occupancy'] ??
            record['rate'] ??
            0,
      ),
    )
        .toList();

    final double average = values.isEmpty
        ? 0.0
        : values.reduce((a, b) => a + b) / values.length;

    final double occupiedValue =
    average.clamp(0.0, 100.0).toDouble();

    final double vacantValue =
    (100.0 - average).clamp(0.0, 100.0).toDouble();

    return ChartCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChartHeader(
            icon: Icons.apartment_outlined,
            title: 'Occupancy Performance',
            subtitle: ChartHelpers.periodText(period),
          ),

          const SizedBox(height: 16),

          // ---------------------------------------------------------
          // OCCUPANCY SUMMARY
          // ---------------------------------------------------------

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  ChartHelpers.primary.withValues(alpha: 0.08),
                  ChartHelpers.secondary.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 65,
                  height: 65,
                  child: PieChart(
                    PieChartData(
                      centerSpaceRadius: 22,
                      sectionsSpace: 0,
                      sections: [
                        PieChartSectionData(
                          value: occupiedValue,
                          color: ChartHelpers.primary,
                          radius: 9,
                          showTitle: false,
                        ),
                        PieChartSectionData(
                          value: vacantValue,
                          color: const Color(0xffE5E7EB),
                          radius: 9,
                          showTitle: false,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 15),

                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Average occupancy',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      ChartHelpers.percentage(average),
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ---------------------------------------------------------
          // OCCUPANCY TREND
          // ---------------------------------------------------------

          SizedBox(
            height: 225,
            child: LineChart(
              LineChartData(
                minY: 0.0,
                maxY: 100.0,

                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25.0,
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
                      reservedSize: 38,
                      interval: 25.0,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}%',
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
                            top: 7,
                          ),
                          child: Text(
                            ChartHelpers.recordLabel(
                              records[index],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.grey.shade600,
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
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) {
                      return spots.map((spot) {
                        final int index = spot.x.toInt();

                        if (index < 0 ||
                            index >= records.length) {
                          return null;
                        }

                        return LineTooltipItem(
                          '${ChartHelpers.recordLabel(records[index])}\n'
                              '${ChartHelpers.percentage(spot.y)}',
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
                        final double occupancy =
                        ChartHelpers.number(
                          records[index]['occupancy_rate'] ??
                              records[index]['occupancy'] ??
                              records[index]['rate'] ??
                              0,
                        );

                        return FlSpot(
                          index.toDouble(),
                          occupancy,
                        );
                      },
                    ),

                    isCurved: true,
                    barWidth: 3,
                    color: ChartHelpers.success,

                    dotData: const FlDotData(
                      show: true,
                    ),

                    belowBarData: BarAreaData(
                      show: true,
                      color: ChartHelpers.success.withValues(alpha: 0.07),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}