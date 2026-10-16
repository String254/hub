import 'package:flutter/material.dart';
import 'package:hub/models/models.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class RevenueAnalyticsWidget extends StatefulWidget {
  /// IMPORTANT:
  /// This should contain ALL invoices required for analytics,
  /// including historical invoices and receipts.
  final Future<List<ApiInvoiceResponse>> invoicesFuture;

  const RevenueAnalyticsWidget({
    super.key,
    required this.invoicesFuture,
  });

  @override
  State<RevenueAnalyticsWidget> createState() =>
      _RevenueAnalyticsWidgetState();
}

class _RevenueAnalyticsWidgetState extends State<RevenueAnalyticsWidget> {
  late Future<List<ApiInvoiceResponse>> _invoicesFuture;

  int _selectedYear = DateTime.now().year;
  int? _selectedPropertyId;
  int? _selectedMonth;

  List<int> _availableYears = [];
  List<ApiInvoiceResponse> _allInvoices = [];

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

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_KE',
    symbol: 'KES ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _invoicesFuture = widget.invoicesFuture;
  }

  @override
  void didUpdateWidget(covariant RevenueAnalyticsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.invoicesFuture != widget.invoicesFuture) {
      _invoicesFuture = widget.invoicesFuture;
    }
  }

  // ===========================================================================
  // FORMATTERS
  // ===========================================================================

  String _formatCurrency(double value) {
    return _currencyFormat.format(value);
  }

  String _formatCompactCurrency(double value) {
    if (value >= 1000000000) {
      return 'KES ${(value / 1000000000).toStringAsFixed(1)}B';
    }

    if (value >= 1000000) {
      return 'KES ${(value / 1000000).toStringAsFixed(1)}M';
    }

    if (value >= 1000) {
      return 'KES ${(value / 1000).toStringAsFixed(1)}K';
    }

    return 'KES ${value.toStringAsFixed(0)}';
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

  void _prepareData(List<ApiInvoiceResponse> invoices) {
    _allInvoices = invoices;

    final years = <int>{};

    for (final invoice in invoices) {
      final invoiceDate = _parseDate(invoice.invoiceDate);

      if (invoiceDate != null) {
        years.add(invoiceDate.year);
      }

      for (final receipt in invoice.receipts) {
        final paymentDate = _parseDate(receipt.paymentDate);

        if (paymentDate != null) {
          years.add(paymentDate.year);
        }
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

  List<ApiInvoiceResponse> _getFilteredInvoices() {
    return _allInvoices.where((invoice) {
      if (_selectedPropertyId != null &&
          invoice.unit.property.id != _selectedPropertyId) {
        return false;
      }

      final invoiceDate = _parseDate(invoice.invoiceDate);

      final invoiceMatchesYear =
          invoiceDate != null && invoiceDate.year == _selectedYear;

      final receiptMatchesYear = invoice.receipts.any((receipt) {
        final date = _parseDate(receipt.paymentDate);

        return date != null && date.year == _selectedYear;
      });

      if (!invoiceMatchesYear && !receiptMatchesYear) {
        return false;
      }

      if (_selectedMonth != null) {
        final invoiceMatchesMonth =
            invoiceDate != null &&
                invoiceDate.year == _selectedYear &&
                invoiceDate.month == _selectedMonth;

        final receiptMatchesMonth = invoice.receipts.any((receipt) {
          final date = _parseDate(receipt.paymentDate);

          return date != null &&
              date.year == _selectedYear &&
              date.month == _selectedMonth;
        });

        if (!invoiceMatchesMonth && !receiptMatchesMonth) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  // ===========================================================================
  // PROPERTY FILTER DATA
  // ===========================================================================

  Map<int, String> _getProperties() {
    final properties = <int, String>{};

    for (final invoice in _allInvoices) {
      final property = invoice.unit.property;

      if (property.id > 0 && property.name.isNotEmpty) {
        properties[property.id] = property.name;
      }
    }

    return properties;
  }

  // ===========================================================================
  // REVENUE CALCULATIONS
  // ===========================================================================

  double _calculateTotalInvoiced(List<ApiInvoiceResponse> invoices) {
    double total = 0;

    for (final invoice in invoices) {
      final date = _parseDate(invoice.invoiceDate);

      if (date == null || date.year != _selectedYear) {
        continue;
      }

      if (_selectedMonth != null && date.month != _selectedMonth) {
        continue;
      }

      total += invoice.amount;
    }

    return total;
  }

  double _calculateTotalCollected(List<ApiInvoiceResponse> invoices) {
    double total = 0;

    for (final invoice in invoices) {
      for (final receipt in invoice.receipts) {
        final date = _parseDate(receipt.paymentDate);

        if (date == null || date.year != _selectedYear) {
          continue;
        }

        if (_selectedMonth != null && date.month != _selectedMonth) {
          continue;
        }

        total += receipt.amount;
      }
    }

    return total;
  }

  double _calculateOutstanding(List<ApiInvoiceResponse> invoices) {
    double total = 0;

    for (final invoice in invoices) {
      final date = _parseDate(invoice.invoiceDate);

      if (date == null || date.year != _selectedYear) {
        continue;
      }

      if (_selectedMonth != null && date.month != _selectedMonth) {
        continue;
      }

      if (invoice.balance > 0) {
        total += invoice.balance;
      }
    }

    return total;
  }

  double _calculateCollectionRate(
      double invoiced,
      double collected,
      ) {
    if (invoiced <= 0) {
      return 0;
    }

    return (collected / invoiced) * 100;
  }

  // ===========================================================================
  // YEAR OVER YEAR GROWTH
  // ===========================================================================

  double _calculateGrowth() {
    double currentYear = 0;
    double previousYear = 0;

    for (final invoice in _allInvoices) {
      if (_selectedPropertyId != null &&
          invoice.unit.property.id != _selectedPropertyId) {
        continue;
      }

      for (final receipt in invoice.receipts) {
        final date = _parseDate(receipt.paymentDate);

        if (date == null) continue;

        if (_selectedMonth != null &&
            date.month != _selectedMonth) {
          continue;
        }

        if (date.year == _selectedYear) {
          currentYear += receipt.amount;
        } else if (date.year == _selectedYear - 1) {
          previousYear += receipt.amount;
        }
      }
    }

    if (previousYear == 0) {
      return currentYear > 0 ? 100 : 0;
    }

    return ((currentYear - previousYear) / previousYear) * 100;
  }

  // ===========================================================================
  // MONTHLY DATA
  // ===========================================================================

  List<_MonthlyRevenueData> _calculateMonthlyRevenue(
      List<ApiInvoiceResponse> invoices,
      ) {
    final collected = List<double>.filled(12, 0);
    final invoiced = List<double>.filled(12, 0);

    for (final invoice in invoices) {
      final invoiceDate = _parseDate(invoice.invoiceDate);

      if (invoiceDate != null &&
          invoiceDate.year == _selectedYear) {
        invoiced[invoiceDate.month - 1] += invoice.amount;
      }

      for (final receipt in invoice.receipts) {
        final paymentDate = _parseDate(receipt.paymentDate);

        if (paymentDate != null &&
            paymentDate.year == _selectedYear) {
          collected[paymentDate.month - 1] += receipt.amount;
        }
      }
    }

    return List.generate(
      12,
          (index) {
        return _MonthlyRevenueData(
          month: _months[index].substring(0, 3),
          monthNumber: index + 1,
          collected: collected[index],
          invoiced: invoiced[index],
        );
      },
    );
  }

  // ===========================================================================
  // PROPERTY REVENUE
  // ===========================================================================

  List<_PropertyRevenue> _calculatePropertyRevenue(
      List<ApiInvoiceResponse> invoices,
      ) {
    final Map<int, _PropertyRevenue> data = {};

    for (final invoice in invoices) {
      final property = invoice.unit.property;

      if (property.id <= 0) continue;

      double collected = 0;

      for (final receipt in invoice.receipts) {
        final date = _parseDate(receipt.paymentDate);

        if (date == null ||
            date.year != _selectedYear) {
          continue;
        }

        if (_selectedMonth != null &&
            date.month != _selectedMonth) {
          continue;
        }

        collected += receipt.amount;
      }

      final existing = data[property.id];

      data[property.id] = _PropertyRevenue(
        propertyId: property.id,
        propertyName: property.name,
        amount: (existing?.amount ?? 0) + collected,
      );
    }

    final result = data.values.toList();

    result.sort((a, b) => b.amount.compareTo(a.amount));

    return result;
  }

  // ===========================================================================
  // OCCUPANCY
  // ===========================================================================

  int _totalUnits(List<ApiInvoiceResponse> invoices) {
    return invoices
        .map((invoice) => invoice.unit.id)
        .where((id) => id > 0)
        .toSet()
        .length;
  }

  bool _isOccupiedStatus(String status) {
    final value = status.trim().toLowerCase();

    return value == 'occupied' ||
        value == 'rented' ||
        value == 'active' ||
        value == 'leased';
  }

  bool _isVacantStatus(String status) {
    final value = status.trim().toLowerCase();

    return value == 'vacant' ||
        value == 'available' ||
        value == 'empty';
  }

  int _occupiedUnits(List<ApiInvoiceResponse> invoices) {
    final units = <int, String>{};

    for (final invoice in invoices) {
      units[invoice.unit.id] = invoice.unit.status;
    }

    return units.values.where(_isOccupiedStatus).length;
  }

  int _vacantUnits(List<ApiInvoiceResponse> invoices) {
    final units = <int, String>{};

    for (final invoice in invoices) {
      units[invoice.unit.id] = invoice.unit.status;
    }

    return units.values.where(_isVacantStatus).length;
  }

  double _occupancyRate(List<ApiInvoiceResponse> invoices) {
    final total = _totalUnits(invoices);

    if (total == 0) return 0;

    return (_occupiedUnits(invoices) / total) * 100;
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ApiInvoiceResponse>>(
      future: _invoicesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoading();
        }

        if (snapshot.hasError) {
          return _buildError(snapshot.error.toString());
        }

        final invoices = snapshot.data ?? [];

        if (invoices.isEmpty) {
          return _buildEmptyState();
        }

        _prepareData(invoices);

        final filteredInvoices = _getFilteredInvoices();

        return _buildAnalytics(filteredInvoices);
      },
    );
  }

  // ===========================================================================
  // MAIN ANALYTICS
  // ===========================================================================

  Widget _buildAnalytics(List<ApiInvoiceResponse> invoices) {
    final totalInvoiced = _calculateTotalInvoiced(invoices);
    final totalCollected = _calculateTotalCollected(invoices);
    final outstanding = _calculateOutstanding(invoices);

    final collectionRate =
    _calculateCollectionRate(totalInvoiced, totalCollected);

    final growth = _calculateGrowth();

    final totalUnits = _totalUnits(invoices);
    final occupiedUnits = _occupiedUnits(invoices);
    final vacantUnits = _vacantUnits(invoices);

    final occupancyRate = _occupancyRate(invoices);

    final monthlyRevenue =
    _calculateMonthlyRevenue(invoices);

    final propertyRevenue =
    _calculatePropertyRevenue(invoices);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),

        const SizedBox(height: 18),

        _buildFilters(context),

        const SizedBox(height: 18),

        _buildKpiSection(
          totalCollected: totalCollected,
          totalInvoiced: totalInvoiced,
          outstanding: outstanding,
          collectionRate: collectionRate,
          growth: growth,
        ),

        const SizedBox(height: 18),

        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 900) {
              return Column(
                children: [
                  _buildRevenueOverview(
                    collected: totalCollected,
                    invoiced: totalInvoiced,
                    outstanding: outstanding,
                    collectionRate: collectionRate,
                  ),
                  const SizedBox(height: 18),
                  _buildOccupancySummary(
                    totalUnits,
                    occupiedUnits,
                    vacantUnits,
                    occupancyRate,
                  ),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _buildRevenueOverview(
                    collected: totalCollected,
                    invoiced: totalInvoiced,
                    outstanding: outstanding,
                    collectionRate: collectionRate,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  flex: 2,
                  child: _buildOccupancySummary(
                    totalUnits,
                    occupiedUnits,
                    vacantUnits,
                    occupancyRate,
                  ),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 18),

        _buildMonthlyRevenueChart(monthlyRevenue),

        const SizedBox(height: 18),

        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 900) {
              return Column(
                children: [
                  _buildPropertyRevenueChart(propertyRevenue),
                  const SizedBox(height: 18),
                  _buildPropertyPerformance(propertyRevenue),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildPropertyRevenueChart(
                    propertyRevenue,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: _buildPropertyPerformance(
                    propertyRevenue,
                  ),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 18),

        _buildRevenueSummary(
          invoiced: totalInvoiced,
          collected: totalCollected,
          outstanding: outstanding,
          collectionRate: collectionRate,
        ),

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
              Icons.insights_outlined,
              color: Colors.white,
              size: 27,
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Revenue Analytics',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  'Financial performance and property revenue insights',
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
                prefixIcon: Icon(Icons.apartment_outlined),
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
                    ),),
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
                prefixIcon: Icon(Icons.calendar_today_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10))
                ),
              ),
              items: _availableYears
                  .map(
                    (year) => DropdownMenuItem(
                  value: year,
                  child: Text(year.toString()),
                ),
              )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;

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
                prefixIcon: Icon(Icons.date_range_outlined),
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
                    child: Text(_months[index]),
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
                _selectedYear = _availableYears.first;
              });
            },
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // KPI SECTION
  // ===========================================================================

  Widget _buildKpiSection({
    required double totalCollected,
    required double totalInvoiced,
    required double outstanding,
    required double collectionRate,
    required double growth,
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
            (width - ((columns - 1) * 12)) / columns;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth,
              child: _buildKpiCard(
                title: 'Collected Revenue',
                value: _formatCompactCurrency(totalCollected),
                subtitle: 'Actual payments received',
                icon: Icons.payments_outlined,
                trend: growth,
              ),
            ),

            SizedBox(
              width: cardWidth,
              child: _buildKpiCard(
                title: 'Total Invoiced',
                value: _formatCompactCurrency(totalInvoiced),
                subtitle: 'Revenue billed to tenants',
                icon: Icons.receipt_long_outlined,
              ),
            ),

            SizedBox(
              width: cardWidth,
              child: _buildKpiCard(
                title: 'Outstanding',
                value: _formatCompactCurrency(outstanding),
                subtitle: 'Pending tenant payments',
                icon: Icons.account_balance_wallet_outlined,
              ),
            ),

            SizedBox(
              width: cardWidth,
              child: _buildKpiCard(
                title: 'Collection Rate',
                value: _formatPercentage(collectionRate),
                subtitle: 'Payments vs invoiced',
                icon: Icons.percent_outlined,
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
    double? trend,
  }) {
    final isPositive = trend == null || trend >= 0;

    return Container(
      height: 135,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),

              const Spacer(),

              if (trend != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isPositive
                        ? Colors.green.withOpacity(.10)
                        : Colors.red.withOpacity(.10),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPositive
                            ? Icons.trending_up
                            : Icons.trending_down,
                        size: 14,
                        color: isPositive
                            ? Colors.green
                            : Colors.red,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${trend.abs().toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isPositive
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ],
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
  // REVENUE OVERVIEW
  // ===========================================================================

  Widget _buildRevenueOverview({
    required double collected,
    required double invoiced,
    required double outstanding,
    required double collectionRate,
  }) {
    final data = [
      _RevenueBreakdown('Collected', collected),
      _RevenueBreakdown('Outstanding', outstanding),
    ];

    return Container(
      height: 280,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Revenue Overview',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            'Financial performance for ${_selectedPeriodLabel()}',
            style: const TextStyle(
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
                      DoughnutSeries<_RevenueBreakdown, String>(
                        dataSource: data,
                        xValueMapper: (data, _) => data.label,
                        yValueMapper: (data, _) => data.amount,
                        innerRadius: '68%',
                        radius: '85%',
                      ),
                    ],
                  ),
                ),

                SizedBox(
                  width: 160,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildRevenueMetric(
                        'Invoiced',
                        _formatCompactCurrency(invoiced),
                      ),

                      const SizedBox(height: 14),

                      _buildRevenueMetric(
                        'Collected',
                        _formatCompactCurrency(collected),
                      ),

                      const SizedBox(height: 14),

                      _buildRevenueMetric(
                        'Collection Rate',
                        _formatPercentage(collectionRate),
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

  Widget _buildRevenueMetric(
      String label,
      String value,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
        ),

        const SizedBox(height: 3),

        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // OCCUPANCY
  // ===========================================================================

  Widget _buildOccupancySummary(
      int total,
      int occupied,
      int vacant,
      double occupancyRate,
      ) {
    return Container(
      height: 280,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Occupancy Performance',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 4),

          const Text(
            'Current property occupancy overview',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 20),

          Center(
            child: Text(
              _formatPercentage(occupancyRate),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          Center(
            child: Text(
              '$occupied of $total units occupied',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
          ),

          const SizedBox(height: 18),

          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: occupancyRate / 100,
              minHeight: 10,
              backgroundColor: Colors.grey.withOpacity(.12),
            ),
          ),

          const Spacer(),

          Row(
            children: [
              Expanded(
                child: _occupancyMetric(
                  'Total',
                  total.toString(),
                ),
              ),

              Expanded(
                child: _occupancyMetric(
                  'Occupied',
                  occupied.toString(),
                ),
              ),

              Expanded(
                child: _occupancyMetric(
                  'Vacant',
                  vacant.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _occupancyMetric(
      String label,
      String value,
      ) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
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
  // MONTHLY REVENUE CHART
  // ===========================================================================

  Widget _buildMonthlyRevenueChart(
      List<_MonthlyRevenueData> data,
      ) {
    return Container(
      height: 420,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monthly Revenue Performance',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 4),

          const Text(
            'Compare invoiced revenue against actual collections',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: SfCartesianChart(
              legend: const Legend(
                isVisible: true,
                position: LegendPosition.bottom,
              ),
              tooltipBehavior: TooltipBehavior(
                enable: true,
              ),
              primaryXAxis: const CategoryAxis(
                majorGridLines: MajorGridLines(width: 0),
              ),
              primaryYAxis: NumericAxis(
                numberFormat: NumberFormat.compactCurrency(
                  symbol: 'KES ',
                  decimalDigits: 0,
                ),
                majorGridLines: MajorGridLines(
                  width: .5,
                  color: Colors.grey,
                ),
              ),
              series: [
                ColumnSeries<_MonthlyRevenueData, String>(
                  name: 'Invoiced',
                  dataSource: data,
                  xValueMapper: (item, _) => item.month,
                  yValueMapper: (item, _) => item.invoiced,
                  width: .65,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(5),
                  ),
                ),

                LineSeries<_MonthlyRevenueData, String>(
                  name: 'Collected',
                  dataSource: data,
                  xValueMapper: (item, _) => item.month,
                  yValueMapper: (item, _) => item.collected,
                  markerSettings: const MarkerSettings(
                    isVisible: true,
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
  // PROPERTY REVENUE CHART
  // ===========================================================================

  Widget _buildPropertyRevenueChart(
      List<_PropertyRevenue> data,
      ) {
    if (data.isEmpty) {
      return _buildNoChartData(
        'No property revenue data available.',
      );
    }

    return Container(
      height: 390,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Revenue by Property',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 4),

          const Text(
            'Distribution of collected revenue',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),

          Expanded(
            child: SfCircularChart(
              legend: const Legend(
                isVisible: true,
                position: LegendPosition.bottom,
                overflowMode: LegendItemOverflowMode.wrap,
              ),
              tooltipBehavior: TooltipBehavior(
                enable: true,
              ),
              series: [
                DoughnutSeries<_PropertyRevenue, String>(
                  dataSource: data,
                  xValueMapper: (item, _) =>
                  item.propertyName,
                  yValueMapper: (item, _) =>
                  item.amount,
                  innerRadius: '60%',
                  radius: '85%',
                  dataLabelSettings:
                  const DataLabelSettings(
                    isVisible: false,
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
      List<_PropertyRevenue> properties,
      ) {
    return Container(
      height: 390,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Performing Properties',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 4),

          const Text(
            'Ranked by collected revenue',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: properties.isEmpty
                ? const Center(
              child: Text(
                'No revenue performance data',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            )
                : ListView.separated(
              itemCount:
              properties.length > 5 ? 5 : properties.length,
              separatorBuilder: (_, __) =>
              const Divider(height: 1),
              itemBuilder: (context, index) {
                final property = properties[index];

                return _buildPropertyRankItem(
                  rank: index + 1,
                  property: property,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyRankItem({
    required int rank,
    required _PropertyRevenue property,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withOpacity(.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '#$rank',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              property.propertyName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          Text(
            _formatCompactCurrency(property.amount),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // REVENUE SUMMARY
  // ===========================================================================

  Widget _buildRevenueSummary({
    required double invoiced,
    required double collected,
    required double outstanding,
    required double collectionRate,
  }) {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(
                  Icons.account_balance_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),

                const SizedBox(width: 10),

                const Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Revenue Summary',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Complete financial overview',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          _summaryRow(
            'Total Invoiced',
            _formatCurrency(invoiced),
            Icons.receipt_long_outlined,
          ),

          _summaryRow(
            'Total Collected',
            _formatCurrency(collected),
            Icons.payments_outlined,
          ),

          _summaryRow(
            'Outstanding Balance',
            _formatCurrency(outstanding),
            Icons.account_balance_wallet_outlined,
          ),

          _summaryRow(
            'Collection Efficiency',
            _formatPercentage(collectionRate),
            Icons.analytics_outlined,
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _summaryRow(
      String title,
      String value,
      IconData icon,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 12,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 19,
            color: Theme.of(context).colorScheme.primary,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),

          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
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
              borderRadius: BorderRadius.circular(18),
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
                    color: Colors.grey.withOpacity(.10),
                    borderRadius: BorderRadius.circular(16),
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
              borderRadius: BorderRadius.circular(16),
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
              'Unable to load revenue analytics',
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
              Icons.analytics_outlined,
              size: 56,
              color: Colors.grey.withOpacity(.45),
            ),

            const SizedBox(height: 14),

            const Text(
              'No revenue data available',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Invoices and payment receipts will appear here.',
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

  Widget _buildNoChartData(String message) {
    return Container(
      height: 300,
      alignment: Alignment.center,
      decoration: _cardDecoration(),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.grey,
        ),
      ),
    );
  }
}

// =============================================================================
// DATA MODELS
// =============================================================================

class _MonthlyRevenueData {
  final String month;
  final int monthNumber;
  final double collected;
  final double invoiced;

  _MonthlyRevenueData({
    required this.month,
    required this.monthNumber,
    required this.collected,
    required this.invoiced,
  });
}

class _PropertyRevenue {
  final int propertyId;
  final String propertyName;
  final double amount;

  _PropertyRevenue({
    required this.propertyId,
    required this.propertyName,
    required this.amount,
  });
}

class _RevenueBreakdown {
  final String label;
  final double amount;

  _RevenueBreakdown(
      this.label,
      this.amount,
      );
}