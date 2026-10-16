import 'package:flutter/material.dart';
import 'package:hub/models/models.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class TenantInsights extends StatefulWidget {
  final Future<PropertyResponse> dialogFuture;

  const TenantInsights({
    super.key,
    required this.dialogFuture,
  });

  @override
  State<TenantInsights> createState() => _TenantInsightsState();
}

class _TenantInsightsState extends State<TenantInsights> {
  late Future<PropertyResponse> _dialogFuture;

  int _selectedYear = DateTime.now().year;
  int? _selectedMonth;
  int? _selectedPropertyId;

  List<int> _availableYears = [];
  List<PropertyDialog> _allProperties = [];
  List<UnitDialog> _allUnits = [];

  final List<String> _months = const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  final NumberFormat _numberFormat = NumberFormat('#,##0');

  @override
  void initState() {
    super.initState();
    _dialogFuture = widget.dialogFuture;
  }

  @override
  void didUpdateWidget(covariant TenantInsights oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.dialogFuture != widget.dialogFuture) {
      _dialogFuture = widget.dialogFuture;
    }
  }

  // ===========================================================================
  // FORMATTERS
  // ===========================================================================

  String _formatNumber(int value) {
    return _numberFormat.format(value);
  }

  String _formatPercentage(double value) {
    return '${value.toStringAsFixed(1)}%';
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    return DateTime.tryParse(value);
  }

  String _selectedPeriodLabel() {
    final month = _selectedMonth == null
        ? 'All Months'
        : _months[_selectedMonth! - 1];

    return '$month $_selectedYear';
  }

  // ===========================================================================
  // DATA PREPARATION
  // ===========================================================================

  void _prepareData(PropertyResponse response) {
    _allProperties = response.properties;
    _allUnits = response.units;

    final years = <int>{};

    for (final property in response.properties) {
      for (final unit in property.units) {
        final invoice = unit.latestInvoice;

        if (invoice == null) {
          continue;
        }

        final invoiceDate = _parseDate(invoice.invoiceDate);

        if (invoiceDate != null) {
          years.add(invoiceDate.year);
        }

        final paymentDate = invoice.updatedAt;

        years.add(paymentDate.year);
      }
    }

    years.add(DateTime.now().year);

    _availableYears = years.toList()
      ..sort((a, b) => b.compareTo(a));

    if (!_availableYears.contains(_selectedYear)) {
      _selectedYear = _availableYears.isNotEmpty
          ? _availableYears.first
          : DateTime.now().year;
    }
  }

  // ===========================================================================
  // PROPERTY FILTER
  // ===========================================================================

  Map<int, String> _getProperties() {
    final properties = <int, String>{};

    for (final property in _allProperties) {
      if (property.id > 0 && property.name.isNotEmpty) {
        properties[property.id] = property.name;
      }
    }

    return properties;
  }

  // ===========================================================================
  // FILTERED UNITS
  // ===========================================================================

  List<UnitDialog> _getFilteredUnits() {
    return _allUnits.where((unit) {
      if (_selectedPropertyId != null &&
          unit.propertyId != _selectedPropertyId) {
        return false;
      }

      final invoice = unit.latestInvoice;

      if (invoice == null) {
        return false;
      }

      if (unit.tenant == null) {
        return false;
      }

      if (!invoice.isPaid) {
        return false;
      }

      final invoiceDate = _parseDate(invoice.invoiceDate);

      if (invoiceDate == null) {
        return false;
      }

      if (invoiceDate.year != _selectedYear) {
        return false;
      }

      if (_selectedMonth != null &&
          invoiceDate.month != _selectedMonth) {
        return false;
      }

      return true;
    }).toList();
  }

  // ===========================================================================
  // PAYMENT METRICS
  // ===========================================================================

  List<TenantRanking> _getAllRankings(
      List<UnitDialog> units,
      ) {
    final rankings = <TenantRanking>[];

    for (final unit in units) {
      if (unit.tenant == null ||
          unit.latestInvoice == null ||
          !unit.latestInvoice!.isPaid) {
        continue;
      }

      rankings.add(
        _calculateTenantRanking(unit),
      );
    }

    rankings.sort(
          (a, b) => b.rankScore.compareTo(a.rankScore),
    );

    return rankings;
  }

  int _countByRank(
      List<TenantRanking> rankings,
      String rank,
      ) {
    return rankings.where((item) => item.rank == rank).length;
  }

  int _earlyPayments(List<TenantRanking> rankings) {
    return rankings.where((item) {
      return item.daysDifference < 0;
    }).length;
  }

  int _onTimePayments(List<TenantRanking> rankings) {
    return rankings.where((item) {
      return item.daysDifference == 0;
    }).length;
  }

  int _latePayments(List<TenantRanking> rankings) {
    return rankings.where((item) {
      return item.daysDifference > 0;
    }).length;
  }

  double _reliabilityRate(
      List<TenantRanking> rankings,
      ) {
    if (rankings.isEmpty) {
      return 0;
    }

    final reliable = rankings.where((item) {
      return item.daysDifference <= 0;
    }).length;

    return (reliable / rankings.length) * 100;
  }

  double _averagePaymentTiming(
      List<TenantRanking> rankings,
      ) {
    if (rankings.isEmpty) {
      return 0;
    }

    final total = rankings.fold<int>(
      0,
          (sum, item) => sum + item.daysDifference,
    );

    return total / rankings.length;
  }

  // ===========================================================================
  // RANKING
  // ===========================================================================

  TenantRanking _calculateTenantRanking(
      UnitDialog unit,
      ) {
    final invoice = unit.latestInvoice!;
    final tenant = unit.tenant!;

    try {
      final dueDate = DateTime.parse(
        invoice.invoiceDate,
      );

      // Existing implementation uses updatedAt
      // as the payment date approximation.
      final paymentDate = invoice.updatedAt;

      final difference =
          paymentDate.difference(dueDate).inDays;

      final rankData = _getRankData(
        difference,
      );

      return TenantRanking(
        tenant: tenant,
        unit: unit,
        daysDifference: difference,
        rank: rankData.rank,
        rankDescription: rankData.description,
        rankColor: rankData.color,
        rankIcon: rankData.icon,
        rankScore: rankData.score,
      );
    } catch (_) {
      return TenantRanking(
        tenant: tenant,
        unit: unit,
        daysDifference: 0,
        rank: 'Normal',
        rankDescription: 'Paid on due date',
        rankColor: Colors.orange,
        rankIcon: Icons.schedule_rounded,
        rankScore: 3,
      );
    }
  }

  RankData _getRankData(
      int daysDifference,
      ) {
    if (daysDifference < -3) {
      return RankData(
        'Excellent',
        'Paid more than 3 days early',
        Colors.green,
        Icons.emoji_events_rounded,
        6,
      );
    }

    if (daysDifference < -1) {
      return RankData(
        'Very Good',
        'Paid 2–3 days early',
        Colors.lightGreen,
        Icons.thumb_up_alt_rounded,
        5,
      );
    }

    if (daysDifference < 0) {
      return RankData(
        'Good',
        'Paid 1 day early',
        Colors.lightGreen,
        Icons.check_circle_rounded,
        4,
      );
    }

    if (daysDifference == 0) {
      return RankData(
        'Normal',
        'Paid on due date',
        Colors.orange,
        Icons.schedule_rounded,
        3,
      );
    }

    if (daysDifference <= 1) {
      return RankData(
        'Okay',
        'Paid 1 day late',
        Colors.amber,
        Icons.watch_later_rounded,
        2,
      );
    }

    if (daysDifference <= 3) {
      return RankData(
        'Late',
        'Paid 2–3 days late',
        Colors.deepOrange,
        Icons.warning_amber_rounded,
        1,
      );
    }

    return RankData(
      'Bad',
      'Paid more than 3 days late',
      Colors.red,
      Icons.thumb_down_alt_rounded,
      0,
    );
  }

  // ===========================================================================
  // MAIN BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PropertyResponse>(
      future: _dialogFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return _buildLoading();
        }

        if (snapshot.hasError) {
          return _buildError(
            snapshot.error.toString(),
          );
        }

        final response = snapshot.data;

        if (response == null ||
            response.units.isEmpty) {
          return _buildEmptyState();
        }

        _prepareData(response);

        final filteredUnits =
        _getFilteredUnits();

        final rankings =
        _getAllRankings(filteredUnits);

        if (rankings.isEmpty) {
          return _buildNoDataState();
        }

        return _buildAnalytics(
          rankings,
          filteredUnits,
        );
      },
    );
  }

  // ===========================================================================
  // ANALYTICS
  // ===========================================================================

  Widget _buildAnalytics(
      List<TenantRanking> rankings,
      List<UnitDialog> units,
      ) {
    final totalTenants = rankings.length;

    final early = _earlyPayments(rankings);
    final onTime = _onTimePayments(rankings);
    final late = _latePayments(rankings);

    final reliability =
    _reliabilityRate(rankings);

    final averageTiming =
    _averagePaymentTiming(rankings);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),

        const SizedBox(height: 18),

        _buildFilters(context),

        const SizedBox(height: 18),

        _buildKpiSection(
          totalTenants: totalTenants,
          early: early,
          onTime: onTime,
          late: late,
          reliability: reliability,
        ),

        const SizedBox(height: 18),

        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 900) {
              return Column(
                children: [
                  _buildPaymentReliability(
                    rankings,
                    reliability,
                  ),
                  const SizedBox(height: 18),
                  _buildPaymentTiming(
                    rankings,
                    averageTiming,
                  ),
                ],
              );
            }

            return Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _buildPaymentReliability(
                    rankings,
                    reliability,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  flex: 2,
                  child: _buildPaymentTiming(
                    rankings,
                    averageTiming,
                  ),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 18),

        _buildPerformanceChart(rankings),

        const SizedBox(height: 18),

        _buildPropertyPerformance(units),

        const SizedBox(height: 18),

        _buildTenantRankingSection(rankings),

        const SizedBox(height: 20),
      ],
    );
  }

  // ===========================================================================
  // HEADER
  // ===========================================================================

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context)
                .colorScheme
                .primary
                .withOpacity(.72),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.people_alt_outlined,
              color: Colors.white,
              size: 27,
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tenant Payment Insights',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  'Payment behaviour, reliability and tenant performance',
                  style: TextStyle(
                    color: Colors.white.withOpacity(.82),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _selectedPeriodLabel(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // FILTERS
  // ===========================================================================

  Widget _buildFilters(BuildContext context) {
    final properties = _getProperties();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: 230,
            child: DropdownButtonFormField<int?>(
              value: _selectedPropertyId,
              decoration: const InputDecoration(
                labelText: 'Property',
                prefixIcon:
                Icon(Icons.apartment_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10))
                ),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('All Properties',
                    style: TextStyle(
                      fontSize: 13
                    ),
                  ),
                ),
                ...properties.entries.map(
                      (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedPropertyId = value;
                });
              },
            ),
          ),

          SizedBox(
            width: 150,
            child: DropdownButtonFormField<int>(
              value: _selectedYear,
              decoration: const InputDecoration(
                labelText: 'Year',
                labelStyle: TextStyle(
                  fontSize: 12
                ),
                prefixIcon:
                Icon(Icons.calendar_today_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10))
                ),
              ),
              items: _availableYears
                  .map(
                    (year) => DropdownMenuItem(
                  value: year,
                  child: Text(
                    year.toString(),
                  ),
                ),
              )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _selectedYear = value;
                });
              },
            ),
          ),

          SizedBox(
            width: 180,
            child: DropdownButtonFormField<int?>(
              value: _selectedMonth,
              decoration: const InputDecoration(
                labelText: 'Month',
                labelStyle: TextStyle(
                    fontSize: 13
                ),
                prefixIcon:
                Icon(Icons.date_range_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10))
                ),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('All Months',
                    style: TextStyle(
                      fontSize: 13
                  ),),
                ),
                ...List.generate(
                  12,
                      (index) => DropdownMenuItem(
                    value: index + 1,
                    child: Text(
                      _months[index],
                    ),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedMonth = value;
                });
              },
            ),
          ),

          OutlinedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Reset'),
            onPressed: () {
              setState(() {
                _selectedPropertyId = null;
                _selectedMonth = null;
                _selectedYear =
                _availableYears.isNotEmpty
                    ? _availableYears.first
                    : DateTime.now().year;
              });
            },
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // KPI CARDS
  // ===========================================================================

  Widget _buildKpiSection({
    required int totalTenants,
    required int early,
    required int onTime,
    required int late,
    required double reliability,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        int columns;

        if (width < 600) {
          columns = 1;
        } else if (width < 1000) {
          columns = 2;
        } else {
          columns = 4;
        }

        final cardWidth =
            (width - ((columns - 1) * 12)) /
                columns;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth,
              child: _buildKpiCard(
                title: 'Paid Tenants',
                value:
                _formatNumber(totalTenants),
                subtitle:
                'Tenants with paid invoices',
                icon: Icons.people_alt_outlined,
              ),
            ),

            SizedBox(
              width: cardWidth,
              child: _buildKpiCard(
                title: 'Paid Early',
                value: _formatNumber(early),
                subtitle:
                'Payments before due date',
                icon:
                Icons.trending_up_rounded,
              ),
            ),

            SizedBox(
              width: cardWidth,
              child: _buildKpiCard(
                title: 'On Time',
                value:
                _formatNumber(onTime),
                subtitle:
                'Payments on due date',
                icon:
                Icons.schedule_rounded,
              ),
            ),

            SizedBox(
              width: cardWidth,
              child: _buildKpiCard(
                title: 'Reliability',
                value:
                _formatPercentage(reliability),
                subtitle:
                '$late tenants paid late',
                icon:
                Icons.verified_outlined,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      height: 135,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withOpacity(.10),
                  borderRadius:
                  BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: Theme.of(context)
                      .colorScheme
                      .primary,
                ),
              ),
            ],
          ),

          const Spacer(),

          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PAYMENT RELIABILITY
  // ===========================================================================

  Widget _buildPaymentReliability(
      List<TenantRanking> rankings,
      double reliability,
      ) {
    final excellent =
    _countByRank(rankings, 'Excellent');

    final veryGood =
    _countByRank(rankings, 'Very Good');

    final good =
    _countByRank(rankings, 'Good');

    final normal =
    _countByRank(rankings, 'Normal');

    final okay =
    _countByRank(rankings, 'Okay');

    final late =
    _countByRank(rankings, 'Late');

    final bad =
    _countByRank(rankings, 'Bad');

    final chartData = [
      _PaymentCategory(
        'Excellent',
        excellent,
        Colors.green,
      ),
      _PaymentCategory(
        'Very Good',
        veryGood,
        Colors.lightGreen,
      ),
      _PaymentCategory(
        'Good',
        good,
        Colors.lightGreen.shade400,
      ),
      _PaymentCategory(
        'On Time',
        normal,
        Colors.orange,
      ),
      _PaymentCategory(
        'Okay',
        okay,
        Colors.amber,
      ),
      _PaymentCategory(
        'Late',
        late,
        Colors.deepOrange,
      ),
      _PaymentCategory(
        'Bad',
        bad,
        Colors.red,
      ),
    ].where((item) => item.count > 0).toList();

    return Container(
      height: 300,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Reliability',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 4),

          const Text(
            'Distribution of tenant payment behaviour',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),

          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: SfCircularChart(
                    series: [
                      DoughnutSeries<
                          _PaymentCategory,
                          String>(
                        dataSource: chartData,
                        xValueMapper:
                            (item, _) =>
                        item.label,
                        yValueMapper:
                            (item, _) =>
                        item.count,
                        pointColorMapper:
                            (item, _) =>
                        item.color,
                        innerRadius: '65%',
                        radius: '85%',
                      ),
                    ],
                    annotations: [
                      CircularChartAnnotation(
                        widget: Column(
                          mainAxisSize:
                          MainAxisSize.min,
                          children: [
                            Text(
                              _formatPercentage(
                                reliability,
                              ),
                              style:
                              const TextStyle(
                                fontSize: 18,
                                fontWeight:
                                FontWeight.w700,
                              ),
                            ),
                            const Text(
                              'Reliable',
                              style:
                              TextStyle(
                                fontSize: 9,
                                color:
                                Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(
                  width: 160,
                  child: Column(
                    mainAxisAlignment:
                    MainAxisAlignment.center,
                    children: [
                      _buildReliabilityMetric(
                        'Early',
                        '${excellent + veryGood + good}',
                        Colors.green,
                      ),

                      const SizedBox(height: 12),

                      _buildReliabilityMetric(
                        'On Time',
                        normal.toString(),
                        Colors.orange,
                      ),

                      const SizedBox(height: 12),

                      _buildReliabilityMetric(
                        'Late',
                        '${okay + late + bad}',
                        Colors.red,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReliabilityMetric(
      String label,
      String value,
      Color color,
      ) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),

        const SizedBox(width: 8),

        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
          ),
        ),

        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // PAYMENT TIMING
  // ===========================================================================

  Widget _buildPaymentTiming(
      List<TenantRanking> rankings,
      double averageTiming,
      ) {
    final early = _earlyPayments(rankings);
    final onTime = _onTimePayments(rankings);
    final late = _latePayments(rankings);

    String timingLabel;

    if (averageTiming < 0) {
      timingLabel =
      '${averageTiming.abs().toStringAsFixed(1)} days early';
    } else if (averageTiming > 0) {
      timingLabel =
      '${averageTiming.toStringAsFixed(1)} days late';
    } else {
      timingLabel = 'On due date';
    }

    return Container(
      height: 300,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Timing',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 4),

          const Text(
            'Average tenant payment behaviour',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 25),

          Center(
            child: Text(
              timingLabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: averageTiming <= 0
                    ? Colors.green
                    : Colors.deepOrange,
              ),
            ),
          ),

          const SizedBox(height: 4),

          const Center(
            child: Text(
              'Average payment timing',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
          ),

          const Spacer(),

          Row(
            children: [
              Expanded(
                child: _buildTimingMetric(
                  'Early',
                  early,
                  Colors.green,
                ),
              ),
              Expanded(
                child: _buildTimingMetric(
                  'On Time',
                  onTime,
                  Colors.orange,
                ),
              ),
              Expanded(
                child: _buildTimingMetric(
                  'Late',
                  late,
                  Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimingMetric(
      String label,
      int value,
      Color color,
      ) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),

        const SizedBox(height: 3),

        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // PERFORMANCE CHART
  // ===========================================================================

  Widget _buildPerformanceChart(
      List<TenantRanking> rankings,
      ) {
    final data = [
      _PerformanceData(
        'Excellent',
        _countByRank(
          rankings,
          'Excellent',
        ),
      ),
      _PerformanceData(
        'Very Good',
        _countByRank(
          rankings,
          'Very Good',
        ),
      ),
      _PerformanceData(
        'Good',
        _countByRank(
          rankings,
          'Good',
        ),
      ),
      _PerformanceData(
        'On Time',
        _countByRank(
          rankings,
          'Normal',
        ),
      ),
      _PerformanceData(
        'Okay',
        _countByRank(
          rankings,
          'Okay',
        ),
      ),
      _PerformanceData(
        'Late',
        _countByRank(
          rankings,
          'Late',
        ),
      ),
      _PerformanceData(
        'Bad',
        _countByRank(
          rankings,
          'Bad',
        ),
      ),
    ];

    return Container(
      height: 390,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            'Tenant Performance Distribution',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 4),

          const Text(
            'Number of tenants by payment performance category',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: SfCartesianChart(
              tooltipBehavior:
              TooltipBehavior(
                enable: true,
              ),
              primaryXAxis:
              const CategoryAxis(
                majorGridLines:
                MajorGridLines(
                  width: 0,
                ),
              ),
              primaryYAxis:
              const NumericAxis(
                minimum: 0,
                interval: 1,
                majorGridLines:
                MajorGridLines(
                  width: .5,
                ),
              ),
              series: [
                ColumnSeries<
                    _PerformanceData,
                    String>(
                  dataSource: data,
                  xValueMapper:
                      (item, _) =>
                  item.category,
                  yValueMapper:
                      (item, _) =>
                  item.count,
                  borderRadius:
                  const BorderRadius.vertical(
                    top: Radius.circular(5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PROPERTY PERFORMANCE
  // ===========================================================================

  Widget _buildPropertyPerformance(
      List<UnitDialog> units,
      ) {
    final Map<int, _PropertyTenantPerformance>
    propertyData = {};

    for (final unit in units) {
      if (unit.tenant == null) {
        continue;
      }

      final property = _allProperties.firstWhere(
            (property) =>
        property.id == unit.propertyId,
        orElse: () => _allProperties.first,
      );

      final ranking =
      _calculateTenantRanking(unit);

      final existing =
      propertyData[property.id];

      propertyData[property.id] =
          _PropertyTenantPerformance(
            propertyId: property.id,
            propertyName: property.name,
            tenantCount:
            (existing?.tenantCount ?? 0) + 1,
            reliableCount:
            (existing?.reliableCount ?? 0) +
                (ranking.daysDifference <= 0
                    ? 1
                    : 0),
            averageTiming:
            (existing?.averageTiming ?? 0) +
                ranking.daysDifference,
          );
    }

    final properties =
    propertyData.values.toList();

    for (final property in properties) {
      if (property.tenantCount > 0) {
        property.averageTiming =
            property.averageTiming /
                property.tenantCount;
      }
    }

    properties.sort(
          (a, b) => b.reliableRate.compareTo(
        a.reliableRate,
      ),
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            'Property Tenant Performance',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 4),

          const Text(
            'Compare tenant payment reliability across properties',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 14),

          ...properties.take(5).map(
                (property) {
              return _buildPropertyPerformanceRow(
                property,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyPerformanceRow(
      _PropertyTenantPerformance property,
      ) {
    final rate =
        property.reliableRate;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 9,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withOpacity(.08),
              borderRadius:
              BorderRadius.circular(9),
            ),
            child: Icon(
              Icons.apartment_outlined,
              size: 17,
              color: Theme.of(context)
                  .colorScheme
                  .primary,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  property.propertyName,
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  '${property.tenantCount} tenants',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius:
              BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: rate / 100,
                minHeight: 7,
                backgroundColor:
                Colors.grey.withOpacity(.10),
              ),
            ),
          ),

          const SizedBox(width: 12),

          SizedBox(
            width: 50,
            child: Text(
              _formatPercentage(rate),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: rate >= 80
                    ? Colors.green
                    : rate >= 60
                    ? Colors.orange
                    : Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TENANT RANKING
  // ===========================================================================

  Widget _buildTenantRankingSection(
      List<TenantRanking> rankings,
      ) {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(
                  Icons.leaderboard_outlined,
                  color: Theme.of(context)
                      .colorScheme
                      .primary,
                ),

                const SizedBox(width: 10),

                const Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tenant Payment Ranking',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                          FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Tenants ranked by payment reliability',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

                Text(
                  '${rankings.length} tenants',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          _buildTableHeader(),

          ...rankings.asMap().entries.map(
                (entry) {
              return _buildTenantRow(
                entry.key,
                entry.value,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 10,
        ),
        color: Colors.grey.shade50,
        child: const Row(
          children: [
          SizedBox(
          width: 40,
          child: Text(
            '#',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        Expanded(
          flex: 4,
          child: Text(
            'TENANT',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        Expanded(
            flex: 2,
            child: Text('UNIT',
              style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ),

          Expanded(
            flex: 3,
            child: Text(
              'TIMING',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          SizedBox(
            width: 90,
            child: Text(
              'STATUS',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ],
        ),
    );
  }

  Widget _buildTenantRow(
      int index,
      TenantRanking ranking,
      ) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 54,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: index.isEven
            ? Colors.white
            : Colors.grey.shade50,
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade100,
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade500,
              ),
            ),
          ),

          Expanded(
            flex: 4,
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: ranking.rankColor
                        .withOpacity(.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_outline,
                    size: 16,
                    color: ranking.rankColor,
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: Text(
                    ranking.tenant.name,
                    maxLines: 1,
                    overflow:
                    TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            flex: 2,
            child: Text(
              ranking.unit.unitNumber,
              style: const TextStyle(
                fontSize: 10,
              ),
            ),
          ),

          Expanded(
            flex: 3,
            child: Text(
              _getTimingText(
                ranking.daysDifference,
              ),
              style: TextStyle(
                fontSize: 10,
                color: ranking.rankColor,
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),

          SizedBox(
            width: 90,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildStatusBadge(
                ranking,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTimingText(
      int daysDifference,
      ) {
    if (daysDifference < 0) {
      return '${daysDifference.abs()}d early';
    }

    if (daysDifference > 0) {
      return '${daysDifference}d late';
    }

    return 'On due date';
  }

  Widget _buildStatusBadge(
      TenantRanking ranking,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: ranking.rankColor
            .withOpacity(.08),
        borderRadius:
        BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ranking.rankIcon,
            size: 11,
            color: ranking.rankColor,
          ),

          const SizedBox(width: 4),

          Flexible(
            child: Text(
              ranking.rank,
              maxLines: 1,
              overflow:
              TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                color: ranking.rankColor,
                fontWeight:
                FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // CARD DECORATION
  // ===========================================================================

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: Colors.grey.withOpacity(.12),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.025),
          blurRadius: 14,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  // ===========================================================================
  // STATES
  // ===========================================================================

  Widget _buildLoading() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(.10),
              borderRadius:
              BorderRadius.circular(18),
            ),
          ),

          const SizedBox(height: 18),

          Row(
            children: List.generate(
              4,
                  (index) => Expanded(
                child: Container(
                  height: 135,
                  margin: EdgeInsets.only(
                    right: index == 3 ? 0 : 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey
                        .withOpacity(.10),
                    borderRadius:
                    BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 18),

          Container(
            height: 350,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(.08),
              borderRadius:
              BorderRadius.circular(16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: _cardDecoration(),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.redAccent,
            ),

            const SizedBox(height: 12),

            const Text(
              'Unable to load tenant insights',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 350,
      decoration: _cardDecoration(),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline,
              size: 56,
              color: Colors.grey.withOpacity(.45),
            ),

            const SizedBox(height: 14),

            const Text(
              'No tenant data available',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Tenant payment information will appear here.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataState() {
    return Container(
      height: 350,
      decoration: _cardDecoration(),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_busy_outlined,
              size: 50,
              color: Colors.grey.withOpacity(.45),
            ),

            const SizedBox(height: 12),
            const Center(
              child: Text(
                'No paid tenant data available',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Try selecting another property, month or year.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// DATA MODELS
// =============================================================================

class TenantRanking {
  final TenantDialog tenant;
  final UnitDialog unit;
  final int daysDifference;
  final String rank;
  final String rankDescription;
  final Color rankColor;
  final IconData rankIcon;
  final int rankScore;

  TenantRanking({
    required this.tenant,
    required this.unit,
    required this.daysDifference,
    required this.rank,
    required this.rankDescription,
    required this.rankColor,
    required this.rankIcon,
    required this.rankScore,
  });
}

class RankData {
  final String rank;
  final String description;
  final Color color;
  final IconData icon;
  final int score;

  RankData(
      this.rank,
      this.description,
      this.color,
      this.icon,
      this.score,
      );
}

class _PaymentCategory {
  final String label;
  final int count;
  final Color color;

  _PaymentCategory(
      this.label,
      this.count,
      this.color,
      );
}

class _PerformanceData {
  final String category;
  final int count;

  _PerformanceData(
      this.category,
      this.count,
      );
}

class _PropertyTenantPerformance {
  final int propertyId;
  final String propertyName;
  final int tenantCount;
  final int reliableCount;
  double averageTiming;

  _PropertyTenantPerformance({
    required this.propertyId,
    required this.propertyName,
    required this.tenantCount,
    required this.reliableCount,
    required this.averageTiming,
  });

  double get reliableRate {
    if (tenantCount == 0) {
      return 0;
    }

    return (reliableCount / tenantCount) * 100;
  }
}