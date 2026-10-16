import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:hub/models/models.dart'; // Adjust import as needed

class ResponsiveOccupancyChart extends StatelessWidget {
  final List<PropertyOccupancyResponse> data;

  const ResponsiveOccupancyChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final labelSize = isMobile ? 10.0 : 12.0;

    List<CartesianSeries<ChartOccupancyCollectionData, String>> buildSeries(
        List<PropertyOccupancyResponse> rawData) {
      final List<ChartOccupancyCollectionData> chartData =
      rawData.map((item) {
        return ChartOccupancyCollectionData(
          propertyName: item.propertyName,
          occupancyRate: item.occupancyPercent,
          collectionRate: item.collectionPercent,
        );
      }).toList();

      return <CartesianSeries<ChartOccupancyCollectionData, String>>[
        ColumnSeries<ChartOccupancyCollectionData, String>(
          name: 'Occupancy Rate',
          dataSource: chartData,
          xValueMapper: (datum, index) => datum.propertyName,
          yValueMapper: (datum, index) => datum.occupancyRate,
          color: Colors.blue,
          borderRadius: BorderRadius.circular(8),
          dataLabelSettings: DataLabelSettings(
            isVisible: true,
            labelAlignment: ChartDataLabelAlignment.auto,
            textStyle: TextStyle(
              fontSize: labelSize - 2,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            builder: (dynamic data, dynamic point, dynamic series,
                int pointIndex, int seriesIndex) {
              final datum = data as ChartOccupancyCollectionData;
              return Text('${datum.occupancyRate.toStringAsFixed(0)}%');
            },
          ),
        ),
        ColumnSeries<ChartOccupancyCollectionData, String>(
          name: 'Collection Rate',
          dataSource: chartData,
          xValueMapper: (datum, index) => datum.propertyName,
          yValueMapper: (datum, index) => datum.collectionRate,
          color: Colors.orange,
          borderRadius: BorderRadius.circular(8),
          dataLabelSettings: DataLabelSettings(
            isVisible: true,
            labelAlignment: ChartDataLabelAlignment.auto,
            textStyle: TextStyle(
              fontSize: labelSize - 2,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            builder: (dynamic data, dynamic point, dynamic series,
                int pointIndex, int seriesIndex) {
              final datum = data as ChartOccupancyCollectionData;
              return Text('${datum.collectionRate.toStringAsFixed(0)}%');
            },
          ),
        ),
      ];
    }

    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SfCartesianChart(
          title: ChartTitle(
            alignment: ChartAlignment.center,
            text: 'Occupancy Rate Analytics',
            textStyle: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              fontFamily: "SF-Pro-Text-Bold",
            ),
          ),
          legend: Legend(isVisible: true, position: LegendPosition.bottom),
          primaryXAxis: CategoryAxis(
            labelRotation: isMobile ? -45 : 0,
            labelStyle: TextStyle(fontSize: labelSize),
          ),
          primaryYAxis: NumericAxis(
            minimum: 0,
            maximum: 100,
            interval: 20,
            labelFormat: '{value}%',
            title: AxisTitle(
              text: 'Percentage (%)',
              textStyle: TextStyle(fontSize: labelSize),
            ),
          ),
          tooltipBehavior: TooltipBehavior(enable: true),
          series: buildSeries(data),
        ),
      ),
    );
  }
}

// Helper class for chart data mapping
class ChartOccupancyCollectionData {
  final String propertyName;
  final int occupancyRate;
  final int collectionRate;

  ChartOccupancyCollectionData({
    required this.propertyName,
    required this.occupancyRate,
    required this.collectionRate,
  });
}
