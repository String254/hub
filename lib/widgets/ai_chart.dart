import 'package:flutter/material.dart';
import 'package:hub/widgets/widgets.dart';

class AiChart extends StatelessWidget {
  final String? chartType;
  final List<Map<String, dynamic>> records;
  final Map<String, dynamic>? chartData;
  final Map<String, dynamic>? chartPeriod;

  const AiChart({
    super.key,
    required this.chartType,
    required this.records,
    this.chartData,
    this.chartPeriod,
  });

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const _EmptyChartState();
    }

    switch (chartType) {
      case 'monthly_collections':
        return MonthlyCollectionsChart(
          records: records,
          period: chartPeriod,
        );

      case 'property_revenue':
        return PropertyRevenueChart(
          records: records,
          period: chartPeriod,
        );

      case 'occupancy':
        return OccupancyChart(
          records: records,
          period: chartPeriod,
        );

      case 'overdue_by_tenant':
        return OverdueByTenantChart(
          records: records,
          period: chartPeriod,
        );

      default:
        return const _UnsupportedChartState();
    }
  }
}

class _EmptyChartState extends StatelessWidget {
  const _EmptyChartState();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xffE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.bar_chart_rounded,
            color: Colors.grey.shade400,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No chart records were returned for this request.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnsupportedChartState extends StatelessWidget {
  const _UnsupportedChartState();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        'This chart type is not yet supported.',
        style: TextStyle(
          fontSize: 12,
        ),
      ),
    );
  }
}