import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ChartHelpers {
  static const Color primary = Color(0xff2563EB);
  static const Color secondary = Color(0xff4F46E5);
  static const Color success = Color(0xff16A34A);
  static const Color warning = Color(0xffF59E0B);
  static const Color danger = Color(0xffDC2626);

  static double number(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value) ?? 0;
    }

    return 0;
  }

  static int integer(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value) ?? 0;
    }

    return 0;
  }

  static String money(
      dynamic value, {
        bool compact = false,
      }) {
    final amount = number(value);

    if (compact) {
      if (amount >= 1000000) {
        return 'Ksh ${(amount / 1000000).toStringAsFixed(1)}M';
      }

      if (amount >= 1000) {
        return 'Ksh ${(amount / 1000).toStringAsFixed(1)}K';
      }
    }

    return 'Ksh ${NumberFormat('#,##0').format(amount)}';
  }

  static String percentage(dynamic value) {
    final amount = number(value);

    return '${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 1)}%';
  }

  static String periodText(
      Map<String, dynamic>? period,
      ) {
    if (period == null) {
      return '';
    }

    final start = period['start']?.toString();
    final end = period['end']?.toString();

    if (start == null || end == null) {
      return '';
    }

    try {
      final startDate = DateTime.parse(start);
      final endDate = DateTime.parse(end);

      final startText =
      DateFormat('MMM yyyy').format(startDate);

      final endText =
      DateFormat('MMM yyyy').format(endDate);

      if (startText == endText) {
        return startText;
      }

      return '$startText – $endText';
    } catch (_) {
      return '$start – $end';
    }
  }

  static String recordLabel(
      Map<String, dynamic> record,
      ) {
    return (record['label'] ??
        record['month'] ??
        record['name'] ??
        record['tenant_name'] ??
        record['property_name'] ??
        '')
        .toString();
  }
}

/// ============================================================
/// CHART HEADER
/// ============================================================

class ChartHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const ChartHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: ChartHelpers.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.bar_chart_rounded,
            color: ChartHelpers.primary,
            size: 19,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null &&
                  subtitle!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// ============================================================
/// CHART CARD
/// ============================================================

class ChartCard extends StatelessWidget {
  final Widget child;

  const ChartCard({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(
        15,
        15,
        15,
        12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xffE8ECF2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}