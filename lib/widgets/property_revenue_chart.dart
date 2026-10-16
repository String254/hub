import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:hub/models/models.dart';

class ResponsivePropertyRevenueChart extends StatelessWidget {
  final List<MonthlyRevenue> data;

  const ResponsivePropertyRevenueChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final labelRotation = isMobile ? -45 : 0;
    final numberFormat = NumberFormat.compactCurrency(symbol: 'Ksh ');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SfCartesianChart(
          title: ChartTitle(
            alignment: ChartAlignment.center,
            text: 'Revenue Analytics',
            textStyle: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              fontFamily: "SF-Pro-Text-Bold",
            ),
          ),
          legend: Legend(
            isVisible: true,
            position: LegendPosition.bottom,
          ),
          primaryXAxis: CategoryAxis(
            labelRotation: labelRotation,
          ),
          primaryYAxis: NumericAxis(
            numberFormat: numberFormat,
            title: AxisTitle(text: 'Revenue (Ksh)'),
          ),
          tooltipBehavior: TooltipBehavior(
            enable: true,
            format: 'point.x : point.y',
            builder: (dynamic data, dynamic point, dynamic series,
                int pointIndex, int seriesIndex) {
              final monthData = data as MonthlyRevenue;
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      monthData.month,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Actual: ${numberFormat.format(monthData.actualRevenue)}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    Text(
                      'Projected: ${numberFormat.format(monthData.projectedRevenue)}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              );
            },
          ),
          series: <CartesianSeries<MonthlyRevenue, String>>[
            // Actual Revenue
            ColumnSeries<MonthlyRevenue, String>(
              name: 'Actual',
              dataSource: data,
              xValueMapper: (m, _) => m.month,
              yValueMapper: (m, _) => m.actualRevenue,
              borderRadius: BorderRadius.circular(6),
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade800,
                  Colors.lightBlueAccent,
                ],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
              dataLabelSettings: const DataLabelSettings(isVisible: false),
            ),

            // Projected Revenue
            ColumnSeries<MonthlyRevenue, String>(
              name: 'Projected',
              dataSource: data,
              xValueMapper: (m, _) => m.month,
              yValueMapper: (m, _) => m.projectedRevenue,
              borderRadius: BorderRadius.circular(6),
              color: Colors.blueGrey.shade300,
              opacity: 0.6,
              dataLabelSettings: const DataLabelSettings(isVisible: false),
            ),
          ],
        ),
      ),
    );
  }
}
