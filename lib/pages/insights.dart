import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:hub/models/models.dart';
import 'package:hub/services/services.dart';
import 'package:hub/config/config.dart';
import 'package:hub/widgets/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key});

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  late final ApiService apiService;

  Future<PropertyResponse>? propertyResponseFuture;
  late Future<List<ApiInvoiceResponse>> _invoicesFuture;
  String? userId;

  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _invoicesFuture = _loadInvoices();
    apiService = ApiService(baseUrl: baseUrl);

    _loadData();
  }

  // ============================================================
  // DATA
  // ============================================================

  Future<List<ApiInvoiceResponse>> _loadInvoices() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Change 'token' if your app stores the authentication token
      // under a different SharedPreferences key.
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception(
          'Authentication token not found. Please log in again.',
        );
      }

      final url = Uri.parse(allInvoices);

      debugPrint('Loading invoices from: $url');

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('Invoice API status: ${response.statusCode}');
      debugPrint('Invoice API response: ${response.body}');

      if (response.statusCode == 401) {
        throw Exception(
          'Authentication failed (401). Please log in again.',
        );
      }

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to load invoices: '
              '${response.statusCode} ${response.reasonPhrase}',
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw Exception(
          'Invalid invoice API response.',
        );
      }

      final data = decoded['data'];

      if (data == null) {
        return [];
      }

      if (data is! List) {
        throw Exception(
          'Invalid invoice data format.',
        );
      }

      return data.map<ApiInvoiceResponse>((item) {
        return ApiInvoiceResponse.fromJson(
          Map<String, dynamic>.from(item),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error loading invoices: $e');
      rethrow;
    }
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      userId = prefs.getString('user_id') ??
          prefs.getString('userId') ??
          prefs.getString('id');

      final userIdInt = int.tryParse(userId ?? '');

      if (userIdInt == null) {
        _setEmptyResponse();
        return;
      }

      if (mounted) {
        setState(() {

          propertyResponseFuture =
              apiService.fetchPropertyResponse(userIdInt);
        });
      }
    } catch (e) {
      debugPrint('Error loading analytics data: $e');

      _setEmptyResponse();
    }
  }

  void _setEmptyResponse() {
    if (!mounted) return;

    setState(() {
      propertyResponseFuture = Future.value(
        PropertyResponse(
          properties: [],
          totalUnits: 0,
          occupiedUnits: 0,
          vacantUnits: 0,
          units: [],
        ),
      );
    });
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;

    final id = int.tryParse(userId ?? '');

    if (id == null) {
      await _loadData();
      return;
    }

    setState(() {
      _isRefreshing = true;
      propertyResponseFuture =
          apiService.fetchPropertyResponse(id);
    });

    try {
      await propertyResponseFuture;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                  size: 18,
                ),
                SizedBox(width: 8),
                Text('Analytics refreshed successfully'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to refresh analytics: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),

              const SizedBox(height: 20),

              Expanded(
                child: propertyResponseFuture == null
                    ? _buildInitialLoading()
                    : FutureBuilder<PropertyResponse>(
                  future: propertyResponseFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return _buildLoadingState();
                    }

                    if (snapshot.hasError) {
                      return _buildErrorState(
                        snapshot.error.toString(),
                      );
                    }

                    if (!snapshot.hasData) {
                      return _buildEmptyState();
                    }

                    final response = snapshot.data!;

                    if (response.properties.isEmpty) {
                      return _buildEmptyState();
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth >= 1050) {
                          return _buildDesktopLayout(response);
                        }

                        return _buildMobileLayout(response);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Palette.nestBlue,
                Palette.nestBlue.withValues(alpha: 0.75),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.insights_rounded,
            color: Colors.white,
            size: 21,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Analytics',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'SF-Pro-Text-Bold',
                  color: Color(0xFF202938),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Monitor your property performance and occupancy',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        _buildRefreshButton(),
      ],
    );
  }

  Widget _buildRefreshButton() {
    return ElevatedButton.icon(
      onPressed: _isRefreshing ? null : _refreshData,
      icon: _isRefreshing
          ? const SizedBox(
        width: 15,
        height: 15,
        child: CircularProgressIndicator(
          strokeWidth: 1.8,
          color: Colors.white,
        ),
      )
          : const Icon(
        Icons.refresh_rounded,
        size: 18,
        color: Colors.white,
      ),
      label: Text(
        _isRefreshing ? 'Refreshing...' : 'Refresh',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Palette.nestBlue,
        disabledBackgroundColor:
        Palette.nestBlue.withValues(alpha: 0.65),
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
        ),
      ),
    );
  }

  // ============================================================
  // DESKTOP
  // ============================================================

  Widget _buildDesktopLayout(PropertyResponse response) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildKpiSection(response),

          const SizedBox(height: 20),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 7,
                child: _buildMainAnalyticsCard(response),
              ),

              const SizedBox(width: 20),

              Expanded(
                flex: 4,
                child: _buildUtilizationCard(response),
              ),
            ],
          ),

          const SizedBox(height: 20),

          _buildPropertyPerformanceCard(response),
        ],
      ),
    );
  }

  // ============================================================
  // MOBILE / TABLET
  // ============================================================

  Widget _buildMobileLayout(PropertyResponse response) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildKpiSection(response),

          const SizedBox(height: 16),

          _buildUtilizationCard(response),

          const SizedBox(height: 16),

          _buildMainAnalyticsCard(response),

          const SizedBox(height: 16),

          _buildPropertyPerformanceCard(response),
        ],
      ),
    );
  }

  // ============================================================
  // KPI SECTION
  // ============================================================

  Widget _buildKpiSection(PropertyResponse response) {
    final totalProperties = response.properties.length;

    final totalUnits = response.totalUnits;

    final occupiedUnits = response.occupiedUnits;

    final vacantUnits = totalUnits - occupiedUnits;

    final occupancyRate = totalUnits > 0
        ? ((occupiedUnits / totalUnits) * 100).round()
        : 0;

    final paidTenants = response.units
        .where((unit) => unit.latestInvoice?.isPaid ?? false)
        .length;

    final cards = [
      _KpiData(
        title: 'Properties',
        value: totalProperties.toString(),
        subtitle: 'Managed properties',
        icon: Icons.business_rounded,
        color: Colors.blue,
      ),
      _KpiData(
        title: 'Total Units',
        value: totalUnits.toString(),
        subtitle: 'Available units',
        icon: Icons.apartment_rounded,
        color: Colors.indigo,
      ),
      _KpiData(
        title: 'Occupied',
        value: occupiedUnits.toString(),
        subtitle: '$occupancyRate% occupancy',
        icon: Icons.people_alt_rounded,
        color: Colors.green,
      ),
      _KpiData(
        title: 'Vacant',
        value: vacantUnits.toString(),
        subtitle: 'Units available',
        icon: Icons.meeting_room_outlined,
        color: Colors.orange,
      ),
      _KpiData(
        title: 'Paid',
        value: paidTenants.toString(),
        subtitle: 'Paid this month',
        icon: Icons.payments_rounded,
        color: Colors.teal,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 650;

        if (isSmall) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cards.length,
            gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.8,
            ),
            itemBuilder: (context, index) {
              return _buildKpiCard(cards[index]);
            },
          );
        }

        return Row(
          children: cards.map((card) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: card == cards.last ? 0 : 12,
                ),
                child: _buildKpiCard(card),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildKpiCard(_KpiData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              data.icon,
              color: data.color,
              size: 20,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  data.value,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF202938),
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  data.subtitle,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey.shade500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MAIN ANALYTICS
  // ============================================================

  Widget _buildMainAnalyticsCard(PropertyResponse response) {
    return _buildSectionCard(
      title: 'Property Insights',
      subtitle: 'Key tenant and revenue analytics',
      icon: Icons.analytics_outlined,
      child: Column(
        children: [
          if (propertyResponseFuture != null)
            TenantInsights(
              dialogFuture: propertyResponseFuture!,
            ),

          const SizedBox(height: 12),

          RevenueAnalyticsWidget(
            invoicesFuture: _invoicesFuture,
          )
        ],
      ),
    );
  }

  // ============================================================
  // UTILIZATION CARD
  // ============================================================

  Widget _buildUtilizationCard(PropertyResponse response) {
    return _buildSectionCard(
      title: 'Asset Utilization',
      subtitle: 'Occupancy across your portfolio',
      icon: Icons.pie_chart_outline_rounded,
      child: Column(
        children: [
          _buildOverallUtilization(response),

          const SizedBox(height: 22),

          Divider(
            height: 1,
            color: Colors.grey.shade200,
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              const Text(
                'Property Performance',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF202938),
                ),
              ),
              const Spacer(),
              Text(
                '${response.properties.length} properties',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          ...response.properties.map((property) {
            final totalUnits = property.units.length;

            if (totalUnits == 0) {
              return const SizedBox.shrink();
            }

            final occupiedUnits = property.units
                .where((u) => u.isOccupied)
                .length;

            final vacantUnits = totalUnits - occupiedUnits;

            final occupancyRate =
            ((occupiedUnits / totalUnits) * 100).round();

            return _buildPropertyUtilizationItem(
              property.name,
              occupancyRate,
              occupiedUnits,
              vacantUnits,
              totalUnits,
            );
          }),
        ],
      ),
    );
  }

  // ============================================================
  // OVERALL UTILIZATION
  // ============================================================

  Widget _buildOverallUtilization(
      PropertyResponse propertyResponse,
      ) {
    final totalUnits = propertyResponse.totalUnits;

    final occupiedUnits = propertyResponse.occupiedUnits;

    final vacantUnits = totalUnits - occupiedUnits;

    if (totalUnits == 0) {
      return _buildNoDataMessage(
        icon: Icons.apartment_outlined,
        title: 'No units available',
        message: 'Add properties and units to see utilization.',
      );
    }

    final occupancyRate =
    ((occupiedUnits / totalUnits) * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overall Occupancy',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  '$occupancyRate%',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF202938),
                  ),
                ),
              ],
            ),

            const Spacer(),

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.trending_up_rounded,
                    size: 13,
                    color: Colors.green.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Portfolio',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                Expanded(
                  flex: occupiedUnits,
                  child: Container(
                    color: Colors.green.shade500,
                  ),
                ),

                if (vacantUnits > 0)
                  Expanded(
                    flex: vacantUnits,
                    child: Container(
                      color: Colors.orange.shade300,
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        Row(
          children: [
            _buildLegendItem(
              'Occupied',
              occupiedUnits,
              Colors.green.shade500,
            ),

            const Spacer(),

            _buildLegendItem(
              'Vacant',
              vacantUnits,
              Colors.orange.shade300,
            ),

            const Spacer(),

            _buildLegendItem(
              'Total',
              totalUnits,
              Palette.nestBlue,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(
      String title,
      int value,
      Color color,
      ) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),

        const SizedBox(width: 5),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value.toString(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // PROPERTY PERFORMANCE
  // ============================================================

  Widget _buildPropertyPerformanceCard(
      PropertyResponse response,
      ) {
    return _buildSectionCard(
      title: 'Property Occupancy',
      subtitle: 'Detailed utilization by property',
      icon: Icons.domain_rounded,
      child: Column(
        children: [
          _buildPropertyTableHeader(),

          const SizedBox(height: 4),

          ...response.properties.map((property) {
            final totalUnits = property.units.length;

            if (totalUnits == 0) {
              return _buildEmptyPropertyRow(property.name);
            }

            final occupiedUnits =
                property.units.where((u) => u.isOccupied).length;

            final vacantUnits =
                totalUnits - occupiedUnits;

            final occupancyRate =
            ((occupiedUnits / totalUnits) * 100).round();

            return _buildPropertyRow(
              property.name,
              occupiedUnits,
              vacantUnits,
              totalUnits,
              occupancyRate,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPropertyTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Expanded(
            flex: 3,
            child: Text(
              'Property',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),

          const Expanded(
            child: Text(
              'Occupied',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),

          const Expanded(
            child: Text(
              'Vacant',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),

          const Expanded(
            child: Text(
              'Total',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),

          const Expanded(
            flex: 2,
            child: Text(
              'Occupancy',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyRow(
      String propertyName,
      int occupiedUnits,
      int vacantUnits,
      int totalUnits,
      int occupancyRate,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade100,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Palette.nestBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.apartment_rounded,
                    size: 16,
                    color: Palette.nestBlue,
                  ),
                ),

                const SizedBox(width: 9),

                Expanded(
                  child: Text(
                    propertyName,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF202938),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Text(
              occupiedUnits.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade700,
              ),
            ),
          ),

          Expanded(
            child: Text(
              vacantUnits.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade700,
              ),
            ),
          ),

          Expanded(
            child: Text(
              totalUnits.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          Expanded(
            flex: 2,
            child: SizedBox(
              width: 32,
              child: Text(
                '$occupancyRate%',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _getOccupancyColor(
                    occupancyRate,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPropertyRow(String propertyName) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 14,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              propertyName,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const Expanded(
            flex: 5,
            child: Text(
              'No units configured',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PROPERTY UTILIZATION ITEM
  // ============================================================

  Widget _buildPropertyUtilizationItem(
      String propertyName,
      int occupancyRate,
      int occupiedUnits,
      int vacantUnits,
      int totalUnits,
      ) {
    final occupancyColor =
    _getOccupancyColor(occupancyRate);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.grey.shade100,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  propertyName,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF202938),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: occupancyColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$occupancyRate%',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: occupancyColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 9),

          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: occupancyRate / 100,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                occupancyColor,
              ),
            ),
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              _buildSmallMetric(
                'Occupied',
                occupiedUnits.toString(),
                Colors.green.shade600,
              ),

              const SizedBox(width: 12),

              _buildSmallMetric(
                'Vacant',
                vacantUnits.toString(),
                Colors.orange.shade600,
              ),

              const Spacer(),

              Text(
                '$totalUnits units',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallMetric(
      String title,
      String value,
      Color color,
      ) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),

        const SizedBox(width: 4),

        Text(
          '$value $title',
          style: TextStyle(
            fontSize: 9,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SECTION CARD
  // ============================================================

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Palette.nestBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    icon,
                    size: 17,
                    color: Palette.nestBlue,
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF202938),
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            child,
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _buildInitialLoading() {
    return _buildLoadingState();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 28,
          vertical: 24,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.grey.shade200,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
              ),
            ),

            const SizedBox(height: 14),

            const Text(
              'Loading analytics',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              'Preparing your property insights...',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildErrorState(String error) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 420,
        ),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.shade200,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                color: Colors.red.shade500,
                size: 28,
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'Unable to load analytics',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Something went wrong while retrieving your property data.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 18),

            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(
                Icons.refresh_rounded,
                size: 16,
              ),
              label: const Text(
                'Try Again',
                style: TextStyle(fontSize: 11),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Palette.nestBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 420,
        ),
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.shade200,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Palette.nestBlue.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.analytics_outlined,
                size: 30,
                color: Palette.nestBlue,
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'No analytics available',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF202938),
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Add properties and units to start seeing occupancy and performance insights.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 18),

            OutlinedButton.icon(
              onPressed: _refreshData,
              icon: const Icon(
                Icons.refresh_rounded,
                size: 16,
              ),
              label: const Text(
                'Refresh Data',
                style: TextStyle(fontSize: 11),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Palette.nestBlue,
                side: BorderSide(
                  color: Palette.nestBlue,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataMessage({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(
            icon,
            size: 34,
            color: Colors.grey.shade400,
          ),

          const SizedBox(height: 8),

          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Color _getOccupancyColor(int percentage) {
    if (percentage >= 80) {
      return Colors.green.shade600;
    }

    if (percentage >= 50) {
      return Colors.orange.shade600;
    }

    return Colors.red.shade500;
  }
}

// ============================================================
// KPI MODEL
// ============================================================

class _KpiData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _KpiData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}