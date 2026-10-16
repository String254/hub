import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:hub/models/models.dart';

class ResponsiveRevenueChart extends StatelessWidget {
  final List<RevenueMonth> data;

  const ResponsiveRevenueChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

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
          legend: Legend(isVisible: true),
          primaryXAxis: CategoryAxis(
            labelRotation: isMobile ? -45 : 0,
          ),
          primaryYAxis: NumericAxis(
            numberFormat: NumberFormat.compactCurrency(symbol: 'Ksh '),
          ),
          tooltipBehavior: TooltipBehavior(enable: true),

          series: <CartesianSeries<RevenueMonth, String>>[
            // ACTUAL REVENUE - BAR CHART
            ColumnSeries<RevenueMonth, String>(
              name: 'Actual',
              dataSource: data,
              xValueMapper: (m, _) => m.month,
              yValueMapper: (m, _) => m.actual,
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

            // PROJECTED REVENUE - LINE GRAPH
            LineSeries<RevenueMonth, String>(
              name: 'Projected',
              dataSource: data,
              xValueMapper: (m, _) => m.month,
              yValueMapper: (m, _) => m.projected,
              color: Colors.orange.shade700,
              width: 3,
              markerSettings: const MarkerSettings(isVisible: true),
            ),
          ],
        ),
      ),
    );
  }
}
