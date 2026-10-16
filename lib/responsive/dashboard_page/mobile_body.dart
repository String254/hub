import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:flutter/material.dart';
import 'package:hub/config/config.dart';
import 'package:hub/models/models.dart';
import 'package:hub/widgets/widgets.dart';
import 'package:hub/services/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hub/pages/pages.dart';
import 'package:url_launcher/url_launcher.dart';

class DashboardMobilePage extends StatefulWidget {
  const DashboardMobilePage({super.key});

  @override
  State<DashboardMobilePage> createState() => _DashboardMobilePageState();
}

class _DashboardMobilePageState extends State<DashboardMobilePage> {
  late final ApiService apiService;
  late Future<DashboardMetrics?> metricsFuture;
  late Future<List<RecentPayment>> recentPaymentsFuture;
  late Future<List<PropertyOccupancyResponse>> occupancyRateFuture;
  late Future<List<RevenueMonth>> totalRevenueFuture;
  late Future<PropertyResponse> dialogFuture;
  String? userFirstName;
  bool isLoadingUser = true;
  List<MpesaTransaction> transactions = [];
  bool isLoadingTransactions = false;
  late ApiPropertyService _apiService;
  Future<PropertyResponse> _maintenanceFuture = Future.value(PropertyResponse(
    properties: [],
    totalUnits: 0,
    occupiedUnits: 0,
    vacantUnits: 0,
    units: [],
  ));
  List<Nest> _propertyCache = [];
  List<PropertyDialog> _maintenanceProperties = [];
  List<Document> _dashboardDocuments = [];
  bool _documentsLoading = true;
  late DocumentService documentService;

  // Full-page loading gate
  bool _isInitialLoading = true;

  // PERFORMANCE: cache maintenance future
  late Future<List<MaintenanceIssue>> _maintenanceIssuesFuture;

  // ─────────────────────────────────────────────────────────────
  // RESPONSIVE HELPERS
  // ─────────────────────────────────────────────────────────────
  bool get _isMobile => MediaQuery.of(context).size.width < 600;
  bool get _isTablet {
    final w = MediaQuery.of(context).size.width;
    return w >= 600 && w < 850;
  }

  double get _cardPadding => _isMobile ? 12 : 16;
  double get _cardMargin => _isMobile ? 8 : 20;
  double get _sectionSpacing => _isMobile ? 8 : 10;

  Future<void> _fetchDashboardDocuments() async {
    try {
      setState(() {
        _documentsLoading = true;
      });

      final documents = await documentService.fetchMyDocs();

      documents.sort((a, b) {
        final aDate = a.createdAt;
        final bDate = b.createdAt;

        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;

        return bDate.compareTo(aDate);
      });

      if (!mounted) return;

      setState(() {
        _dashboardDocuments = documents.take(5).toList();
        _documentsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _dashboardDocuments = [];
        _documentsLoading = false;
      });
    }
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fullName = prefs.getString('name');
      if (fullName != null && fullName.isNotEmpty) {
        userFirstName = fullName.split(' ')[0];
      } else {
        userFirstName = prefs.getString('first_name') ??
            prefs.getString('firstName') ??
            'User';
      }
    } catch (_) {
      userFirstName = 'User';
    }
    if (!mounted) return;
    setState(() => isLoadingUser = false);
  }

  Future<void> _loadAllData() async {
    final userIdStr = await getUserId();
    final int? userId = int.tryParse(userIdStr ?? '');
    _propertyFuture = apiService.fetchPropertiesData();
    if (userId != null) {
      _maintenanceFuture = apiService.fetchPropertyResponse(userId);
    } else {
      _maintenanceFuture = Future.value(PropertyResponse(
        properties: [],
        totalUnits: 0,
        occupiedUnits: 0,
        vacantUnits: 0,
        units: [],
      ));
    }

    final props = await _propertyFuture;
    final maintResp = await _maintenanceFuture;

    if (!mounted) return;

    setState(() {
      _propertyCache = props;
      _maintenanceProperties = maintResp.properties;
    });
  }

  String toTitleCase(String input) {
    if (input.trim().isEmpty) return input;

    final buffer = StringBuffer();
    bool capitalizeNext = true;

    for (int i = 0; i < input.length; i++) {
      final char = input[i];
      if (char == ' ' || char == '-' || char == '\'' || char == '_') {
        buffer.write(' ');
        capitalizeNext = true;
      } else if (capitalizeNext) {
        buffer.write(char.toUpperCase());
        capitalizeNext = false;
      } else {
        buffer.write(char.toLowerCase());
      }
    }
    return buffer.toString().trim();
  }

  String formatDocumentName(String name) {
    final parts = name.split('_');
    final trimmed = parts.take(2).join(' ');
    return toTitleCase(trimmed);
  }

  Future<List<Nest>> _propertyFuture = Future.value(<Nest>[]);

  String formatKES(num amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_KE',
      symbol: 'Ksh ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  final NumberFormat _kesFormatter = NumberFormat.currency(
    locale: 'en_KE',
    symbol: 'Ksh ',
    decimalDigits: 0,
  );

  String kes(num amount) => _kesFormatter.format(amount);

  String formatDate(String dateTimeStr) {
    try {
      String year = dateTimeStr.substring(0, 4);
      String month = dateTimeStr.substring(4, 6);
      String day = dateTimeStr.substring(6, 8);
      String hour = dateTimeStr.substring(8, 10);
      String minute = dateTimeStr.substring(10, 12);
      String second = dateTimeStr.substring(12, 14);

      DateTime dateTime = DateTime(
        int.parse(year),
        int.parse(month),
        int.parse(day),
        int.parse(hour),
        int.parse(minute),
        int.parse(second),
      );

      return DateFormat("dd-MMM-yy").format(dateTime);
    } catch (e) {
      return "Invalid date";
    }
  }

  void _showAddPropertyDialog() {
    final nameCtrl = TextEditingController();
    final typeCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final unitsCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Property'),
        titleTextStyle:
        const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Property Name'),
              ),
              TextField(
                controller: typeCtrl,
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              TextField(
                controller: locationCtrl,
                decoration: const InputDecoration(labelText: 'Location'),
              ),
              TextField(
                controller: unitsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Total Units'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Palette.nestBlue),
            onPressed: () async {
              await apiService.createProperty(
                name: nameCtrl.text,
                type: typeCtrl.text,
                location: locationCtrl.text,
                totalUnits: int.tryParse(unitsCtrl.text) ?? 0,
              );
              if (!mounted) return;
              Navigator.pop(context);
              await _loadAllData();
            },
            child: const Text('Save', style: TextStyle(color: Colors.white),),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    apiService = ApiService(baseUrl: baseUrl);
    _apiService = ApiPropertyService(baseUrl: baseUrl);
    metricsFuture = apiService.fetchDashboardMetricsData();
    recentPaymentsFuture = apiService.fetchRecentPaymentsData();
    occupancyRateFuture = apiService.fetchOccupancyData();
    totalRevenueFuture = apiService.fetchRevenueData();
    _propertyFuture = apiService.fetchPropertiesData();

    // Cache maintenance future — only fetch once
    _maintenanceIssuesFuture = apiService.fetchMaintenanceIssues();

    _loadDashboardData();
    _loadUserData();
    _loadAllData();
    documentService = DocumentService(baseUrl: baseUrl);
    _fetchDashboardDocuments();

    _bootstrapDashboard();
  }

  Future<void> _bootstrapDashboard() async {
    final started = DateTime.now();

    await Future<void>.delayed(const Duration(milliseconds: 350));

    final pending = <Future<Object?>>[
      metricsFuture,
      recentPaymentsFuture,
      occupancyRateFuture,
      totalRevenueFuture,
      _propertyFuture,
      _maintenanceFuture,
    ];

    for (final future in pending) {
      try {
        await future;
      } catch (_) {}
    }

    // Reduced minimum to 1200ms for snappier mobile feel
    const minimum = Duration(milliseconds: 1200);
    final elapsed = DateTime.now().difference(started);
    if (elapsed < minimum) {
      await Future<void>.delayed(minimum - elapsed);
    }

    if (!mounted) return;
    setState(() => _isInitialLoading = false);
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_KE',
      symbol: 'KES ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  void _showInvoiceDetailsDialog(BuildContext context, Invoice invoice) {
    final isPaid = invoice.status.toLowerCase() == 'paid';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 500, maxWidth: 500),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isPaid ? Colors.green.shade50 : Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPaid ? Icons.check_circle : Icons.pending,
                  size: 30,
                  color: isPaid ? Colors.green.shade700 : Colors.orange.shade700,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Invoice Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Unit Number', invoice.unitNumber),
              _buildDetailRow('Due Date', _formatDate(invoice.invoiceDate)),
              _buildDetailRow('Amount', _formatCurrency(invoice.amount)),
              _buildDetailRow(
                'Status',
                isPaid ? 'Paid' : 'Unpaid',
                valueColor: isPaid ? Colors.green : Colors.orange,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CreateReceiptScreen(
                                invoiceId: invoice.id, invoiceRef: invoice.ref),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Receipt'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: valueColor ?? Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('user_id') ??
          prefs.getString('userId') ??
          prefs.getString('id');
      return userId;
    } catch (e) {
      return null;
    }
  }

  String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  String _formatDate(String dateStr) {
    try {
      final DateTime date = DateTime.parse(dateStr);
      final DateFormat formatter = DateFormat('dd/MMM');
      return formatter.format(date);
    } catch (e) {
      return dateStr;
    }
  }

  // Skeleton loading widgets (mobile-optimized)
  Widget _buildSkeletonStatsGrid() {
    final columns = _isMobile ? 2 : 3;
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.7,
      ),
      itemCount: 6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        return Card(
          elevation: 2,
          shadowColor: Colors.black12,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 70,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 55,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeletonRecentPayments() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 120,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              separatorBuilder: (_, __) => const Divider(height: 20),
              itemBuilder: (context, index) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey.shade300,
                    child: Container(),
                  ),
                  title: Container(
                    width: 100,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  subtitle: Container(
                    width: 80,
                    height: 12,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  trailing: Container(
                    width: 60,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonChart() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 150,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 600) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSkeletonStatsGrid(),
                    const SizedBox(height: 12),
                    _buildSkeletonChart(),
                    const SizedBox(height: 12),
                    _buildSkeletonChart(),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _buildSkeletonRecentPayments(),
              ),
            ],
          );
        }
        return Column(
          children: [
            _buildSkeletonStatsGrid(),
            const SizedBox(height: 12),
            _buildSkeletonRecentPayments(),
            const SizedBox(height: 12),
            _buildSkeletonChart(),
            const SizedBox(height: 12),
            _buildSkeletonChart(),
          ],
        );
      },
    );
  }

  Future<void> _loadDashboardData() async {
    try {
      final userId = await getUserId();

      if (userId != null && userId.isNotEmpty) {
        final userIdInt = int.tryParse(userId);
        if (userIdInt != null) {
          if (!mounted) return;
          setState(() {
            dialogFuture = apiService.fetchPropertyResponse(userIdInt);
          });
        } else {
          if (mounted) {
            setState(() {
              dialogFuture = Future.value(PropertyResponse(
                properties: [],
                totalUnits: 0,
                occupiedUnits: 0,
                vacantUnits: 0,
                units: [],
              ));
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            dialogFuture = Future.value(PropertyResponse(
              properties: [],
              totalUnits: 0,
              occupiedUnits: 0,
              vacantUnits: 0,
              units: [],
            ));
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          dialogFuture = Future.value(PropertyResponse(
            properties: [],
            totalUnits: 0,
            occupiedUnits: 0,
            vacantUnits: 0,
            units: [],
          ));
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading) {
      return const _MobileDashboardLoader(
        messages: [
          'Loading your properties...',
          'Fetching recent payments...',
          'Crunching revenue numbers...',
          'Preparing your dashboard...',
        ],
      );
    }

    return Container(
      color: const Color(0xFFF4F7FC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─────────────────────────────────────────────────────
          // HEADER
          // ─────────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
              _isMobile ? 16 : 20,
              _isMobile ? 8 : 10,
              _isMobile ? 8 : 12,
              0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isLoadingUser
                            ? 'Welcome 👋'
                            : 'Welcome ${userFirstName ?? 'User'} 👋',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: _isMobile ? 14 : 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: "SF-Pro-Text-Bold",
                          color: const Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Here\'s what\'s happening today',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: _isMobile ? 11 : 12,
                          fontFamily: "SF-Pro-Text-Regular",
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    // Notifications (only on tablet)
                    if (_isTablet)
                      Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => NotificationsPage(),
                              ),
                            );
                          },
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor:
                            Palette.nestBlue.withValues(alpha: 0.1),
                            child: Icon(Icons.notifications_none,
                                color: Palette.nestBlue, size: 18),
                          ),
                        ),
                      ),
                    // Help (only on tablet)
                    if (_isTablet)
                      Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatPage(),
                              ),
                            );
                          },
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor:
                            Palette.nestBlue.withValues(alpha: 0.1),
                            child: Icon(Icons.help,
                                color: Palette.nestBlue, size: 18),
                          ),
                        ),
                      ),
                    // Avatar menu
                    Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: PopupMenuButton<String>(
                        offset: const Offset(0, 50),
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: _isMobile ? 18 : 20,
                          backgroundColor:
                          Palette.nestBlue.withValues(alpha: 0.1),
                          child: Text(
                            isLoadingUser
                                ? '...'
                                : (userFirstName?[0] ?? 'U').toUpperCase(),
                            style: TextStyle(
                              fontSize: _isMobile ? 15 : 17,
                              fontWeight: FontWeight.bold,
                              color: Palette.nestBlue,
                            ),
                          ),
                        ),
                        onSelected: (value) {
                          if (value == 'profile') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const ChatPage()),
                            );
                          } else if (value == 'signout') {
                            _showSignOutDialog(context);
                          }
                        },
                        itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(
                            value: 'profile',
                            child: Row(
                              children: [
                                Icon(Icons.person_outline,
                                    color: Colors.black87, size: 20),
                                SizedBox(width: 12),
                                Text(
                                  'Account Profile',
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'signout',
                            child: Row(
                              children: [
                                Icon(Icons.logout,
                                    color: Colors.red, size: 20),
                                SizedBox(width: 12),
                                Text(
                                  'Sign Out',
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: _isMobile ? 8 : 10),
          Padding(
            padding: EdgeInsets.fromLTRB(
              _isMobile ? 16 : 20,
              0,
              _isMobile ? 16 : 20,
              0,
            ),
            child: Text(
              'Overview',
              style: TextStyle(
                fontSize: _isMobile ? 14 : 16,
                fontWeight: FontWeight.bold,
                fontFamily: "SF-Pro-Text-Bold",
                color: const Color(0xFF333333),
              ),
            ),
          ),
          SizedBox(height: _isMobile ? 12 : 16),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: _isMobile ? 12 : 16),
              child: FutureBuilder<DashboardMetrics?>(
                future: metricsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildSkeletonLayout();
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 80),
                        child: Column(
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.red.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Something went wrong',
                              style: TextStyle(color: Colors.red.shade600),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final metrics = snapshot.data;
                  if (metrics == null) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 80),
                        child: Text('No dashboard data available'),
                      ),
                    );
                  }

                  return FutureBuilder<List<PropertyOccupancyResponse>>(
                    future: occupancyRateFuture,
                    builder: (context, occupancySnapshot) {
                      final chartData = occupancySnapshot.data ?? [];

                      return FutureBuilder<List<RevenueMonth>>(
                        future: totalRevenueFuture,
                        builder: (context, revenueSnapshot) {
                          final revenueData = revenueSnapshot.data ?? [];

                          return LayoutBuilder(
                            builder: (context, constraints) {
                              // ─────────────────────────────────
                              // TABLET LAYOUT (600-850px) — two column
                              // ─────────────────────────────────
                              if (constraints.maxWidth > 600) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          _buildStatsGrid(context, metrics),
                                          const SizedBox(height: 8),
                                          _buildManageProperties(context),
                                          const SizedBox(height: 8),
                                          _buildMaintenanceSection(context),
                                          const SizedBox(height: 8),
                                          _buildDocumentsSection(),
                                          const SizedBox(height: 8),
                                          RepaintBoundary(
                                            child: ResponsiveOccupancyChart(
                                                data: chartData),
                                          ),
                                          const SizedBox(height: 8),
                                          RepaintBoundary(
                                            child: ResponsiveRevenueChart(
                                                data: revenueData),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: _buildRecentPayments(context),
                                    ),
                                  ],
                                );
                              }

                              // ─────────────────────────────────
                              // MOBILE LAYOUT (< 600px) — single column
                              // ─────────────────────────────────
                              return Column(
                                children: [
                                  _buildStatsGrid(context, metrics),

                                  SizedBox(height: _sectionSpacing),

                                  _buildRecentPayments(context),

                                  SizedBox(height: _sectionSpacing),

                                  _buildManageProperties(context),

                                  SizedBox(height: _sectionSpacing),

                                  _buildMaintenanceSection(context),

                                  SizedBox(height: _sectionSpacing),

                                  _buildDocumentsSection(),

                                  SizedBox(height: _sectionSpacing),

                                  RepaintBoundary(
                                    child: ResponsiveOccupancyChart(
                                        data: chartData),
                                  ),

                                  SizedBox(height: _sectionSpacing),

                                  RepaintBoundary(
                                    child: ResponsiveRevenueChart(
                                        data: revenueData),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              _isMobile ? 16 : 20,
              _isMobile ? 16 : 20,
              _isMobile ? 16 : 20,
              _isMobile ? 16 : 20,
            ),
            child: const BottomBar(),
          ),
        ],
      ),
    );
  }

  // ---------------- STAT CARD ----------------

  Widget _buildStatCard(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String value,
        required Color color,
        required VoidCallback? onTap,
      }) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 4),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: _isMobile ? 10 : 11,
                  fontFamily: "SF-Pro-Text-Regular",
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: _isMobile ? 12 : 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: "SF-Pro-Text-Bold",
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- STATS GRID ----------------

  Widget _buildStatsGrid(BuildContext context, DashboardMetrics metrics) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount;
        double aspectRatio;

        if (constraints.maxWidth < 400) {
          crossAxisCount = 2;
          aspectRatio = 1.55;
        } else if (constraints.maxWidth < 600) {
          crossAxisCount = 2;
          aspectRatio = 1.75;
        } else {
          crossAxisCount = 3;
          aspectRatio = 1.65;
        }

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: aspectRatio,
          ),
          itemCount: 6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            switch (index) {
              case 0:
                return _buildStatCard(
                  context,
                  icon: BootstrapIcons.houses_fill,
                  title: 'Total Units',
                  value: metrics.totalUnits.toString(),
                  color: Palette.nestBlue,
                  onTap: () => _showUnitsDialog(),
                );
              case 1:
                return _buildStatCard(
                  context,
                  icon: BootstrapIcons.house_check_fill,
                  title: 'Paid Units',
                  value: metrics.paidUnits.toString(),
                  color: Colors.green.shade600,
                  onTap: () => _showPaidUnitsDialog(),
                );
              case 2:
                return _buildStatCard(
                  context,
                  icon: BootstrapIcons.house_dash_fill,
                  title: 'Unpaid Units',
                  value: metrics.unpaidUnits.toString(),
                  color: Colors.orange.shade700,
                  onTap: () => _showUnpaidUnitsDialog(),
                );
              case 3:
                return _buildStatCard(
                  context,
                  icon: BootstrapIcons.building_fill_check,
                  title: 'Rent Paid',
                  value: formatKES(metrics.rentPaidThisMonth),
                  color: Palette.nestBlue,
                  onTap: () => _showRentPaidDialog(),
                );
              case 4:
                return _buildStatCard(
                  context,
                  icon: BootstrapIcons.building_fill_exclamation,
                  title: 'Due This Month',
                  value: formatKES(metrics.rentDueThisMonth),
                  color: Colors.blueAccent.shade700,
                  onTap: () => _showDueThisMonthDialog(),
                );
              default:
                return _buildStatCard(
                  context,
                  icon: BootstrapIcons.building_fill_lock,
                  title: 'Overdue',
                  value: formatKES(metrics.overdueRent),
                  color: Colors.redAccent.shade700,
                  onTap: () => _showOverdueThisMonthDialog(),
                );
            }
          },
        );
      },
    );
  }

  // ---------------- PAYMENTS ----------------

  Widget _buildRecentPayments(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: Colors.green.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.green.shade100,
                        Colors.green.shade50,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    BootstrapIcons.cash_stack,
                    color: Colors.green.shade700,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'All Payments',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          fontFamily: "SF-Pro-Text-Bold",
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Confirmed payments',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final payments = await recentPaymentsFuture;

                    if (!context.mounted) return;

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AllPaymentsPage(
                          payments: payments,
                        ),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.green.shade700,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 6,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'View all',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 10,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FutureBuilder<List<RecentPayment>>(
              future: recentPaymentsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: CircularProgressIndicator(
                        strokeWidth: 1,
                        color: Colors.green.shade600,
                      ),
                    ),
                  );
                }

                if (snapshot.hasError ||
                    !snapshot.hasData ||
                    snapshot.data!.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.green.shade100,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            BootstrapIcons.cash_stack,
                            size: 30,
                            color: Colors.green.shade300,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No recent payments',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Payments will appear here once received.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final payments = snapshot.data!;

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: payments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final payment = payments[index];

                    final bool isPaid =
                        payment.status.toLowerCase() == 'paid';

                    return _buildRecentPaymentCard(
                      context,
                      payment,
                      isPaid,
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentPaymentCard(
      BuildContext context,
      RecentPayment payment,
      bool isPaid,
      ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.green.shade50.withValues(alpha: 0.75),
            Colors.green.shade50.withValues(alpha: 0.25),
            Colors.white,
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.green.shade100,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.green.shade100,
                  Colors.green.shade50,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              BootstrapIcons.check_circle_fill,
              color: Colors.green.shade600,
              size: 15,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.tenantName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: "SF-Pro-Text-Bold",
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(
                      BootstrapIcons.building,
                      size: 11,
                      color: Colors.green.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Unit ${payment.unitNumber}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      BootstrapIcons.calendar3,
                      size: 10,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(payment.paymentDate),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  kes(payment.amount),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isPaid
                        ? Colors.green.shade100
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPaid
                            ? BootstrapIcons.check_circle
                            : BootstrapIcons.clock,
                        size: 9,
                        color: isPaid
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        capitalize(payment.status),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isPaid
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                        ),
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

  void showTenantInvoicesPopup(
      BuildContext context, int tenantId, String name) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 550, maxWidth: 700),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.blue.shade700, Colors.blue.shade900],
                  ),
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.all(18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '$name Invoices',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                        iconSize: 14,
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Invoice>>(
                  future: _apiService.fetchTenantInvoices(tenantId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(strokeWidth: 2),
                            SizedBox(height: 16),
                            Text(
                              'Loading invoices...',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.error_outline,
                                  color: Colors.red.shade700,
                                  size: 48,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "Failed to load invoices",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  showTenantInvoicesPopup(
                                      context, tenantId, name);
                                },
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final invoices = snapshot.data ?? [];

                    if (invoices.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.receipt_outlined,
                                  size: 48,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No Invoices Found',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'This tenant has no invoices yet',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final totalAmount = invoices.fold<double>(
                      0,
                          (sum, invoice) => sum + invoice.amount,
                    );
                    final paidCount =
                        invoices.where((i) => i.status == 'paid').length;

                    return Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildSummaryCard(
                                  icon: Icons.receipt_long,
                                  label: 'Total',
                                  value: invoices.length.toString(),
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildSummaryCard(
                                  icon: Icons.check_circle,
                                  label: 'Paid',
                                  value: paidCount.toString(),
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildSummaryCard(
                                  icon: Icons.money,
                                  label: 'Amount',
                                  value: _formatCurrency(totalAmount),
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(14),
                            itemCount: invoices.length,
                            itemBuilder: (context, index) {
                              final invoice = invoices[index];
                              final isPaid =
                                  invoice.status.toLowerCase() == 'paid';

                              return GestureDetector(
                                onTap: () {
                                  _showInvoiceDetailsDialog(context, invoice);
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white,
                                        isPaid
                                            ? Colors.green.shade50
                                            : Colors.orange.shade50,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isPaid
                                          ? Colors.green.shade200
                                          : Colors.orange.shade200,
                                      width: 1,
                                    ),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        _showInvoiceDetailsDialog(
                                            context, invoice);
                                      },
                                      borderRadius: BorderRadius.circular(16),
                                      child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding:
                                              const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: isPaid
                                                    ? Colors.green.shade100
                                                    : Colors.orange.shade100,
                                                borderRadius:
                                                BorderRadius.circular(12),
                                              ),
                                              child: Icon(
                                                Icons.apartment,
                                                color: isPaid
                                                    ? Colors.green.shade700
                                                    : Colors.orange.shade700,
                                                size: 18,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Unit ${invoice.unitNumber}',
                                                    style: TextStyle(
                                                      fontWeight:
                                                      FontWeight.w600,
                                                      fontSize: 13,
                                                      color: Colors
                                                          .grey.shade800,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.calendar_today,
                                                        size: 12,
                                                        color: Colors
                                                            .grey.shade500,
                                                      ),
                                                      const SizedBox(
                                                          width: 4),
                                                      Text(
                                                        _formatDate(invoice
                                                            .invoiceDate),
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.grey
                                                              .shade600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  _formatCurrency(
                                                      invoice.amount),
                                                  style: TextStyle(
                                                    fontWeight:
                                                    FontWeight.bold,
                                                    fontSize: 13,
                                                    color: isPaid
                                                        ? Colors
                                                        .green.shade700
                                                        : Colors
                                                        .orange.shade700,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: isPaid
                                                        ? Colors.green.shade50
                                                        : Colors
                                                        .orange.shade50,
                                                    borderRadius:
                                                    BorderRadius.circular(
                                                        20),
                                                    border: Border.all(
                                                      color: isPaid
                                                          ? Colors
                                                          .green.shade200
                                                          : Colors
                                                          .orange.shade200,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                    MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        isPaid
                                                            ? Icons
                                                            .check_circle
                                                            : Icons.pending,
                                                        size: 11,
                                                        color: isPaid
                                                            ? Colors.green
                                                            .shade700
                                                            : Colors.orange
                                                            .shade700,
                                                      ),
                                                      const SizedBox(
                                                          width: 4),
                                                      Text(
                                                        isPaid
                                                            ? 'Paid'
                                                            : 'Unpaid',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight:
                                                          FontWeight.w600,
                                                          color: isPaid
                                                              ? Colors.green
                                                              .shade700
                                                              : Colors.orange
                                                              .shade700,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
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

  Widget _buildSummaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- DIALOGS ----------------

  Future<void> _showUnitsDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: SizedBox(
          width: 300,
          height: 200,
          child: Dialog(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 4,
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.grey.shade300,
                      valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Loading properties...',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      final userId = await getUserId();

      if (userId == null) {
        _closeLoadingDialogAndShowError('Please login to view properties');
        return;
      }

      final userIdInt = int.tryParse(userId);
      if (userIdInt == null) {
        _closeLoadingDialogAndShowError('Invalid user ID format');
        return;
      }

      final propertyResponse =
      await apiService.fetchPropertyResponse(userIdInt);

      if (!mounted) return;
      _closeLoadingDialog();

      if (!mounted) return;
      _showPropertiesDialog(propertyResponse);
    } catch (e) {
      _closeLoadingDialogAndShowError(
          'Error loading properties: ${e.toString()}');
    }
  }

  Future<void> _showPaidUnitsDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: SizedBox(
          width: 300,
          height: 200,
          child: Dialog(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 4,
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.green.shade600),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Loading paid units...',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      final userId = await getUserId();

      if (userId == null) {
        _closeLoadingDialogAndShowError('Please login to view paid units');
        return;
      }

      final userIdInt = int.tryParse(userId);
      if (userIdInt == null) {
        _closeLoadingDialogAndShowError('Invalid user ID format');
        return;
      }

      final propertyResponse =
      await apiService.fetchPropertyResponse(userIdInt);

      final paidPropertyResponse = _filterPaidUnits(propertyResponse);

      if (!mounted) return;
      _closeLoadingDialog();

      if (!mounted) return;
      _showPaidUnitsDialogContent(paidPropertyResponse);
    } catch (e) {
      _closeLoadingDialogAndShowError(
          'Error loading paid units: ${e.toString()}');
    }
  }

  Future<void> _showUnpaidUnitsDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: SizedBox(
          width: 300,
          height: 200,
          child: Dialog(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 4,
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.grey.shade300,
                      valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.red.shade600),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Loading unpaid units...',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      final userId = await getUserId();

      if (userId == null) {
        _closeLoadingDialogAndShowError('Please login to view unpaid units');
        return;
      }

      final userIdInt = int.tryParse(userId);
      if (userIdInt == null) {
        _closeLoadingDialogAndShowError('Invalid user ID format');
        return;
      }

      final propertyResponse =
      await apiService.fetchPropertyResponse(userIdInt);

      final unpaidPropertyResponse = _filterUnpaidUnits(propertyResponse);

      if (!mounted) return;
      _closeLoadingDialog();

      if (!mounted) return;
      _showUnpaidUnitsDialogContent(unpaidPropertyResponse);
    } catch (e) {
      _closeLoadingDialogAndShowError(
          'Error loading unpaid units: ${e.toString()}');
    }
  }

  Future<void> _showRentPaidDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: SizedBox(
          width: 300,
          height: 200,
          child: Dialog(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 4,
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.grey.shade300,
                      valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Loading rent paid data...',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      final userId = await getUserId();

      if (userId == null) {
        _closeLoadingDialogAndShowError(
            'Please login to view rent paid data');
        return;
      }

      final userIdInt = int.tryParse(userId);
      if (userIdInt == null) {
        _closeLoadingDialogAndShowError('Invalid user ID format');
        return;
      }

      final propertyResponse =
      await apiService.fetchPropertyResponse(userIdInt);

      final rentPaidPropertyResponse =
      _filterRentPaidUnits(propertyResponse);

      if (!mounted) return;
      _closeLoadingDialog();

      if (!mounted) return;
      _showRentPaidDialogContent(rentPaidPropertyResponse);
    } catch (e) {
      _closeLoadingDialogAndShowError(
          'Error loading rent paid data: ${e.toString()}');
    }
  }

  Future<void> _showDueThisMonthDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: SizedBox(
          width: 300,
          height: 200,
          child: Dialog(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 4,
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.blueAccent.shade700),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Loading due this month...',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      final userId = await getUserId();

      if (userId == null) {
        _closeLoadingDialogAndShowError(
            'Please login to view due amounts');
        return;
      }

      final userIdInt = int.tryParse(userId);
      if (userIdInt == null) {
        _closeLoadingDialogAndShowError('Invalid user ID format');
        return;
      }

      final propertyResponse =
      await apiService.fetchPropertyResponse(userIdInt);

      final dueThisMonthPropertyResponse =
      _filterDueThisMonthUnits(propertyResponse);

      if (!mounted) return;
      _closeLoadingDialog();

      if (!mounted) return;
      _showDueThisMonthDialogContent(dueThisMonthPropertyResponse);
    } catch (e) {
      _closeLoadingDialogAndShowError(
          'Error loading due amounts: ${e.toString()}');
    }
  }

  Future<void> _showOverdueThisMonthDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: SizedBox(
          width: 300,
          height: 200,
          child: Dialog(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 4,
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.redAccent.shade700),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Loading overdue units...',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      final userId = await getUserId();

      if (userId == null) {
        _closeLoadingDialogAndShowError(
            'Please login to view overdue units');
        return;
      }

      final userIdInt = int.tryParse(userId);
      if (userIdInt == null) {
        _closeLoadingDialogAndShowError('Invalid user ID format');
        return;
      }

      final propertyResponse =
      await apiService.fetchPropertyResponse(userIdInt);

      final overduePropertyResponse = _filterOverdueUnits(propertyResponse);

      if (!mounted) return;
      _closeLoadingDialog();

      if (!mounted) return;
      _showOverdueDialogContent(overduePropertyResponse);
    } catch (e) {
      _closeLoadingDialogAndShowError(
          'Error loading overdue units: ${e.toString()}');
    }
  }

  PropertyResponse _filterOverdueUnits(PropertyResponse original) {
    final today = DateTime.now();

    final filteredProperties = original.properties.map((property) {
      final overdueUnits = property.units.where((unit) {
        if (unit.latestInvoice == null) {
          return unit.isOccupied;
        }

        final invoice = unit.latestInvoice!;
        if (invoice.isPaid) return false;

        try {
          final dueDate = DateTime.parse(invoice.invoiceDate);
          return dueDate.isBefore(DateTime(today.year, today.month, today.day));
        } catch (e) {
          return false;
        }
      }).toList();

      return PropertyDialog(
        id: property.id,
        name: property.name,
        type: property.type,
        location: property.location,
        totalUnits: property.totalUnits,
        userId: property.userId,
        createdAt: property.createdAt,
        updatedAt: property.updatedAt,
        units: overdueUnits,
      );
    }).where((property) => property.units.isNotEmpty).toList();

    final overdueUnits = original.units.where((unit) {
      if (unit.latestInvoice == null) {
        return unit.isOccupied;
      }

      final invoice = unit.latestInvoice!;
      if (invoice.isPaid) return false;

      try {
        final dueDate = DateTime.parse(invoice.invoiceDate);
        return dueDate.isBefore(DateTime.now());
      } catch (e) {
        return false;
      }
    }).toList();

    return PropertyResponse(
      properties: filteredProperties,
      totalUnits: overdueUnits.length,
      occupiedUnits: overdueUnits.where((u) => u.isOccupied).length,
      vacantUnits: overdueUnits.where((u) => u.isVacant).length,
      units: overdueUnits,
    );
  }

  void _showOverdueDialogContent(PropertyResponse propertyResponse) {
    final totalOverdue = propertyResponse.units.fold(
        0.0, (sum, unit) => sum + _getOverdueAmount(unit));
    final daysOverdueList =
    propertyResponse.units.map((unit) => _getDaysOverdue(unit)).toList();
    final avgDaysOverdue = daysOverdueList.isEmpty
        ? 0
        : daysOverdueList.reduce((a, b) => a + b) / daysOverdueList.length;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.redAccent.shade700, Colors.red.shade900],
                  ),
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.warning,
                              color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Overdue This Month',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${propertyResponse.properties.length} properties • ${propertyResponse.totalUnits} units',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                        iconSize: 16,
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildDialogStatCard(
                        'Overdue Units',
                        propertyResponse.totalUnits.toString(),
                        Icons.warning,
                        Colors.redAccent,
                      ),
                      const SizedBox(width: 10),
                      _buildDialogStatCard(
                        'Total Overdue',
                        kes(totalOverdue),
                        Icons.account_balance,
                        Colors.red,
                      ),
                      const SizedBox(width: 10),
                      _buildDialogStatCard(
                        'Avg Days',
                        avgDaysOverdue.toStringAsFixed(1),
                        Icons.schedule,
                        Colors.orange,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: propertyResponse.properties.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle,
                          size: 48, color: Colors.green.shade400),
                      const SizedBox(height: 16),
                      Text('No overdue units this month!',
                          style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                )
                    : ListView.builder(
                  itemCount: propertyResponse.properties.length,
                  itemBuilder: (context, index) {
                    final property =
                    propertyResponse.properties[index];
                    final propertyOverdue = property.units.fold(0.0,
                            (sum, unit) => sum + _getOverdueAmount(unit));
                    final propertyDaysOverdueList = property.units
                        .map((unit) => _getDaysOverdue(unit))
                        .toList();
                    final avgPropertyDaysOverdue =
                    propertyDaysOverdueList.isEmpty
                        ? 0
                        : propertyDaysOverdueList.reduce(
                            (a, b) => a + b) /
                        propertyDaysOverdueList.length;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ExpansionTile(
                        title: Text(
                          property.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        subtitle: Text(
                          '${property.location} • ${property.units.length} units',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w300),
                        ),
                        children: [
                          Padding(
                            padding:
                            const EdgeInsets.fromLTRB(14, 0, 14, 14),
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius:
                                    BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildPropertyStat(
                                        'Units',
                                        property.units.length.toString(),
                                        Icons.warning,
                                        Colors.redAccent,
                                      ),
                                      _buildPropertyStat(
                                        'Amount',
                                        kes(propertyOverdue),
                                        Icons.account_balance,
                                        Colors.red,
                                      ),
                                      _buildPropertyStat(
                                        'Avg Days',
                                        avgPropertyDaysOverdue
                                            .toStringAsFixed(1),
                                        Icons.schedule,
                                        Colors.orange,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                if (property.units.isNotEmpty) ...[
                                  const Text(
                                    'Overdue Units:',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildOverdueUnitsTable(
                                      property.units),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
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

  double _getOverdueAmount(UnitDialog unit) {
    if (unit.latestInvoice == null) return unit.rentAmount;

    final invoice = unit.latestInvoice!;
    if (invoice.isPaid) return 0.0;

    return double.parse(invoice.amount);
  }

  int _getDaysOverdue(UnitDialog unit) {
    if (unit.latestInvoice == null) return 0;

    final invoice = unit.latestInvoice!;
    if (invoice.isPaid) return 0;

    try {
      final dueDate = DateTime.parse(invoice.invoiceDate);
      final today = DateTime.now();
      if (dueDate.isBefore(today)) {
        return today.difference(dueDate).inDays;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  Widget _buildOverdueUnitsTable(List<UnitDialog> units) {
    final totalOverdue =
    units.fold(0.0, (sum, unit) => sum + _getOverdueAmount(unit));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 700),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                        width: 80,
                        child: Text('Unit #',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 11))),
                    SizedBox(
                        width: 100,
                        child: Text('Tenant',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 11))),
                    SizedBox(
                        width: 80,
                        child: Text('Rent',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 11))),
                    SizedBox(
                        width: 100,
                        child: Text('Overdue',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 11))),
                    SizedBox(
                        width: 80,
                        child: Text('Due Date',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 11))),
                    SizedBox(
                        width: 80,
                        child: Text('Days',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 11))),
                  ],
                ),
              ),
              ...units.map((unit) {
                final invoice = unit.latestInvoice;
                final overdueAmount = _getOverdueAmount(unit);
                final daysOverdue = _getDaysOverdue(unit);
                final dueDate = invoice?.invoiceDate ?? 'Not invoiced';

                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border:
                    Border(bottom: BorderSide(color: Colors.grey.shade100)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                          width: 80,
                          child: Text(unit.unitNumber,
                              style: const TextStyle(fontSize: 11))),
                      SizedBox(
                          width: 100,
                          child: Text(unit.tenant?.name ?? '-',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11))),
                      SizedBox(
                          width: 80,
                          child: Text(kes(unit.rentAmount),
                              style: const TextStyle(fontSize: 11))),
                      SizedBox(
                          width: 100,
                          child: Text(kes(overdueAmount),
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.red))),
                      SizedBox(
                          width: 80,
                          child: Text(dueDate,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11))),
                      SizedBox(
                        width: 80,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$daysOverdue d',
                            style: const TextStyle(
                                fontSize: 10,
                                color: Colors.red,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(8)),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                        width: 280,
                        child: Text('TOTAL OVERDUE',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 11))),
                    SizedBox(
                      width: 100,
                      child: Text(
                        kes(totalOverdue),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                            fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PropertyResponse _filterDueThisMonthUnits(PropertyResponse original) {
    final currentMonth = DateTime.now().month;
    final currentYear = DateTime.now().year;

    final filteredProperties = original.properties.map((property) {
      final dueUnits = property.units.where((unit) {
        if (unit.latestInvoice == null) return true;

        final invoiceDate = DateTime.tryParse(unit.latestInvoice!.invoiceDate);
        if (invoiceDate == null) return false;

        return invoiceDate.month == currentMonth &&
            invoiceDate.year == currentYear;
      }).toList();

      return PropertyDialog(
        id: property.id,
        name: property.name,
        type: property.type,
        location: property.location,
        totalUnits: property.totalUnits,
        userId: property.userId,
        createdAt: property.createdAt,
        updatedAt: property.updatedAt,
        units: dueUnits,
      );
    }).where((property) => property.units.isNotEmpty).toList();

    final dueUnits = original.units.where((unit) {
      if (unit.latestInvoice == null) return true;

      final invoiceDate = DateTime.tryParse(unit.latestInvoice!.invoiceDate);
      if (invoiceDate == null) return false;

      return invoiceDate.month == currentMonth &&
          invoiceDate.year == currentYear;
    }).toList();

    return PropertyResponse(
      properties: filteredProperties,
      totalUnits: dueUnits.length,
      occupiedUnits: dueUnits.where((u) => u.isOccupied).length,
      vacantUnits: dueUnits.where((u) => u.isVacant).length,
      units: dueUnits,
    );
  }

  void _showDueThisMonthDialogContent(PropertyResponse propertyResponse) {
    final totalDue =
    propertyResponse.units.fold(0.0, (sum, unit) => sum + _getDueAmount(unit));

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.blueAccent.shade700,
                      Colors.blue.shade900
                    ],
                  ),
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.calendar_today,
                              color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Due This Month',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${propertyResponse.properties.length} properties • ${propertyResponse.totalUnits} units',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                        iconSize: 16,
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildDialogStatCard(
                        'Units Due',
                        propertyResponse.totalUnits.toString(),
                        Icons.calendar_today,
                        Colors.blueAccent,
                      ),
                      const SizedBox(width: 10),
                      _buildDialogStatCard(
                        'Total Due',
                        kes(totalDue),
                        Icons.account_balance,
                        Colors.orange,
                      ),
                      const SizedBox(width: 10),
                      _buildDialogStatCard(
                        'Properties',
                        propertyResponse.properties.length.toString(),
                        Icons.business,
                        Colors.purple,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: propertyResponse.properties.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('No units due this month',
                          style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                )
                    : ListView.builder(
                  itemCount: propertyResponse.properties.length,
                  itemBuilder: (context, index) {
                    final property =
                    propertyResponse.properties[index];
                    final propertyDue = property.units.fold(0.0,
                            (sum, unit) => sum + _getDueAmount(unit));

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ExpansionTile(
                        title: Text(
                          property.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        subtitle: Text(
                          '${property.location} • ${property.units.length} units',
                          style: const TextStyle(
                              fontWeight: FontWeight.w300, fontSize: 11),
                        ),
                        children: [
                          Padding(
                            padding:
                            const EdgeInsets.fromLTRB(14, 0, 14, 14),
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius:
                                    BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildPropertyStat(
                                        'Due Units',
                                        property.units.length.toString(),
                                        Icons.calendar_today,
                                        Colors.blueAccent,
                                      ),
                                      _buildPropertyStat(
                                        'Amount Due',
                                        kes(propertyDue),
                                        Icons.account_balance,
                                        Colors.orange,
                                      ),
                                      _buildPropertyStat(
                                        'Avg',
                                        property.units.isEmpty
                                            ? '0'
                                            : kes(propertyDue /
                                            property.units.length),
                                        Icons.calculate,
                                        Colors.purple,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                if (property.units.isNotEmpty) ...[
                                  const Text(
                                    'Due This Month:',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDueThisMonthTable(
                                      property.units),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
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

  double _getDueAmount(UnitDialog unit) {
    if (unit.latestInvoice == null) return unit.rentAmount;

    final invoice = unit.latestInvoice!;
    if (invoice.isPaid) return 0.0;

    return double.parse(invoice.amount);
  }

  Widget _buildDueThisMonthTable(List<UnitDialog> units) {
    final totalDue =
    units.fold(0.0, (sum, unit) => sum + _getDueAmount(unit));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 700),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                        width: 80,
                        child: Text('Unit #',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 11))),
                    SizedBox(
                        width: 100,
                        child: Text('Tenant',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 11))),
                    SizedBox(
                        width: 80,
                        child: Text('Rent',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 11))),
                    SizedBox(
                        width: 100,
                        child: Text('Total Due',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 11))),
                    SizedBox(
                        width: 80,
                        child: Text('Due Date',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 11))),
                    SizedBox(
                        width: 80,
                        child: Text('Status',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 11))),
                  ],
                ),
              ),
              ...units.map((unit) {
                final invoice = unit.latestInvoice;
                final dueAmount = _getDueAmount(unit);
                final dueDate = invoice?.invoiceDate ?? 'Not invoiced';
                final isOverdue = _isDueDateOverdue(dueDate);

                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border:
                    Border(bottom: BorderSide(color: Colors.grey.shade100)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                          width: 80,
                          child: Text(unit.unitNumber,
                              style: const TextStyle(fontSize: 11))),
                      SizedBox(
                          width: 100,
                          child: Text(unit.tenant?.name ?? '-',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11))),
                      SizedBox(
                          width: 80,
                          child: Text(kes(unit.rentAmount),
                              style: const TextStyle(fontSize: 11))),
                      SizedBox(
                          width: 100,
                          child: Text(kes(dueAmount),
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color:
                                  isOverdue ? Colors.red : Colors.orange))),
                      SizedBox(
                          width: 80,
                          child: Text(dueDate,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11,
                                  color:
                                  isOverdue ? Colors.red : Colors.black))),
                      SizedBox(
                        width: 80,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: isOverdue
                                ? Colors.red.withValues(alpha: 0.1)
                                : Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isOverdue ? 'Overdue' : 'Due',
                            style: TextStyle(
                                fontSize: 10,
                                color:
                                isOverdue ? Colors.red : Colors.orange,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(8)),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                        width: 280,
                        child: Text('TOTAL DUE THIS MONTH',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 11))),
                    SizedBox(
                      width: 100,
                      child: Text(
                        kes(totalDue),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                            fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isDueDateOverdue(String dueDateString) {
    try {
      final dueDate = DateTime.parse(dueDateString);
      final today = DateTime.now();
      return dueDate.isBefore(DateTime(today.year, today.month, today.day));
    } catch (e) {
      return false;
    }
  }

  PropertyResponse _filterRentPaidUnits(PropertyResponse original) {
    final filteredProperties = original.properties.map((property) {
      final paidUnits =
      property.units.where((unit) => unit.isInvoicePaid).toList();
      return PropertyDialog(
        id: property.id,
        name: property.name,
        type: property.type,
        location: property.location,
        totalUnits: property.totalUnits,
        userId: property.userId,
        createdAt: property.createdAt,
        updatedAt: property.updatedAt,
        units: paidUnits,
      );
    }).where((property) => property.units.isNotEmpty).toList();

    final paidUnits =
    original.units.where((unit) => unit.isInvoicePaid).toList();

    return PropertyResponse(
      properties: filteredProperties,
      totalUnits: paidUnits.length,
      occupiedUnits: paidUnits.where((u) => u.isOccupied).length,
      vacantUnits: paidUnits.where((u) => u.isVacant).length,
      units: paidUnits,
    );
  }

  void _showRentPaidDialogContent(PropertyResponse propertyResponse) {
    final totalRentCollected = propertyResponse.units.fold(
        0.0,
            (sum, unit) =>
        sum + (unit.latestInvoice?.rentAmount ?? unit.rentAmount));

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.blue.shade700, Colors.blue.shade900],
                  ),
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.account_balance,
                              color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Rent Paid',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${propertyResponse.properties.length} properties • ${propertyResponse.totalUnits} payments',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                        iconSize: 16,
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildDialogStatCard(
                        'Payments',
                        propertyResponse.totalUnits.toString(),
                        Icons.account_balance,
                        Colors.blue,
                      ),
                      const SizedBox(width: 10),
                      _buildDialogStatCard(
                        'Collected',
                        kes(totalRentCollected),
                        Icons.attach_money,
                        Colors.green,
                      ),
                      const SizedBox(width: 10),
                      _buildDialogStatCard(
                        'Properties',
                        propertyResponse.properties.length.toString(),
                        Icons.business,
                        Colors.purple,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: propertyResponse.properties.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.account_balance_outlined,
                          size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('No rent payments found',
                          style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                )
                    : ListView.builder(
                  itemCount: propertyResponse.properties.length,
                  itemBuilder: (context, index) {
                    final property =
                    propertyResponse.properties[index];
                    final propertyRentCollected =
                    property.units.fold(0.0,
                            (sum, unit) => sum + (unit.latestInvoice?.rentAmount ?? unit.rentAmount));

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ExpansionTile(
                        title: Text(
                          property.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        subtitle: Text(
                          '${property.location} • ${property.units.length} payments',
                          style: const TextStyle(
                              fontWeight: FontWeight.w300, fontSize: 11),
                        ),
                        children: [
                          Padding(
                            padding:
                            const EdgeInsets.fromLTRB(14, 0, 14, 14),
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius:
                                    BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildPropertyStat(
                                        'Paid Units',
                                        property.units.length.toString(),
                                        Icons.account_balance,
                                        Colors.blue,
                                      ),
                                      _buildPropertyStat(
                                        'Collected',
                                        kes(propertyRentCollected),
                                        Icons.attach_money,
                                        Colors.green,
                                      ),
                                      _buildPropertyStat(
                                        'Avg',
                                        property.units.isEmpty
                                            ? '0'
                                            : kes(propertyRentCollected /
                                            property.units.length),
                                        Icons.calculate,
                                        Colors.purple,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                if (property.units.isNotEmpty) ...[
                                  const Text(
                                    'Rent Payments:',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildRentPaidTable(property.units),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildRentPaidTable(List<UnitDialog> units) {
    final totalRentCollected = units.fold(
        0.0,
            (sum, unit) =>
        sum + (unit.latestInvoice?.rentAmount ?? unit.rentAmount));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 650),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                        width: 80,
                        child: Text('Unit #',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 11))),
                    SizedBox(
                        width: 100,
                        child: Text('Tenant',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 11))),
                    SizedBox(
                        width: 100,
                        child: Text('Rent',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 11))),
                    SizedBox(
                        width: 100,
                        child: Text('Payment Date',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 11))),
                    SizedBox(
                        width: 100,
                        child: Text('Invoice #',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 11))),
                  ],
                ),
              ),
              ...units.map((unit) {
                final invoice = unit.latestInvoice;
                final rentAmount =
                    invoice?.rentAmount ?? unit.rentAmount;

                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border:
                    Border(bottom: BorderSide(color: Colors.grey.shade100)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                          width: 80,
                          child: Text(unit.unitNumber,
                              style: const TextStyle(fontSize: 11))),
                      SizedBox(
                          width: 100,
                          child: Text(unit.tenant?.name ?? '-',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11))),
                      SizedBox(
                          width: 100,
                          child: Text(kes(rentAmount),
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.green))),
                      SizedBox(
                          width: 100,
                          child: Text(invoice?.invoiceDate ?? '-',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11))),
                      SizedBox(
                          width: 100,
                          child: Text(invoice!.ref.split('.')[0],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11))),
                    ],
                  ),
                );
              }).toList(),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(8)),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                        width: 280,
                        child: Text('TOTAL RENT COLLECTED',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 11))),
                    SizedBox(
                      width: 100,
                      child: Text(
                        kes(totalRentCollected),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                            fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PropertyResponse _filterPaidUnits(PropertyResponse original) {
    final filteredProperties = original.properties.map((property) {
      final paidUnits =
      property.units.where((unit) => unit.isInvoicePaid).toList();
      return PropertyDialog(
        id: property.id,
        name: property.name,
        type: property.type,
        location: property.location,
        totalUnits: property.totalUnits,
        userId: property.userId,
        createdAt: property.createdAt,
        updatedAt: property.updatedAt,
        units: paidUnits,
      );
    }).where((property) => property.units.isNotEmpty).toList();

    final paidUnits =
    original.units.where((unit) => unit.isInvoicePaid).toList();

    return PropertyResponse(
      properties: filteredProperties,
      totalUnits: paidUnits.length,
      occupiedUnits: paidUnits.where((u) => u.isOccupied).length,
      vacantUnits: paidUnits.where((u) => u.isVacant).length,
      units: paidUnits,
    );
  }

  void _showPaidUnitsDialogContent(PropertyResponse propertyResponse) {
    final totalCollected = propertyResponse.units.fold(
        0.0, (sum, unit) => sum + (unit.latestInvoice?.totalAmount ?? 0.0));

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.green.shade700, Colors.green.shade900],
                  ),
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.check_circle,
                              color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Paid Units',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${propertyResponse.properties.length} properties • ${propertyResponse.totalUnits} paid units',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                        iconSize: 16,
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildDialogStatCard(
                        'Paid Units',
                        propertyResponse.totalUnits.toString(),
                        Icons.check_circle,
                        Colors.green,
                      ),
                      const SizedBox(width: 10),
                      _buildDialogStatCard(
                        'Total Collected',
                        kes(totalCollected),
                        Icons.account_balance,
                        Colors.blue,
                      ),
                      const SizedBox(width: 10),
                      _buildDialogStatCard(
                        'Properties',
                        propertyResponse.properties.length.toString(),
                        Icons.business,
                        Colors.purple,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: propertyResponse.properties.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('No paid units found',
                          style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                )
                    : ListView.builder(
                  itemCount: propertyResponse.properties.length,
                  itemBuilder: (context, index) {
                    final property =
                    propertyResponse.properties[index];
                    final propertyTotalCollected = property.units.fold(
                        0.0,
                            (sum, unit) =>
                        sum +
                            (unit.latestInvoice?.totalAmount ?? 0.0));

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ExpansionTile(
                        title: Text(
                          property.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        subtitle: Text(
                          '${property.location} • ${property.units.length} paid units',
                          style: const TextStyle(
                              fontWeight: FontWeight.w300, fontSize: 11),
                        ),
                        children: [
                          Padding(
                            padding:
                            const EdgeInsets.fromLTRB(14, 0, 14, 14),
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius:
                                    BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildPropertyStat(
                                        'Paid Units',
                                        property.units.length.toString(),
                                        Icons.check_circle,
                                        Colors.green,
                                      ),
                                      _buildPropertyStat(
                                        'Collected',
                                        kes(propertyTotalCollected),
                                        Icons.account_balance,
                                        Colors.blue,
                                      ),
                                      _buildPropertyStat(
                                        'Avg',
                                        property.units.isEmpty
                                            ? '0'
                                            : kes(propertyTotalCollected /
                                            property.units.length),
                                        Icons.calculate,
                                        Colors.purple,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                if (property.units.isNotEmpty) ...[
                                  const Text(
                                    'Paid Units:',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildPaidUnitsTable(property.units),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildPaidUnitsTable(List<UnitDialog> units) {
    final totalAmount = units.fold(
        0.0, (sum, unit) => sum + (unit.latestInvoice?.totalAmount ?? 0.0));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 700),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                        width: 70,
                        child: Text('Unit #',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 11))),
                    SizedBox(
                        width: 100,
                        child: Text('Tenant',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 11))),
                    SizedBox(
                        width: 80,
                        child: Text('Rent',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 11))),
                    SizedBox(
                        width: 80,
                        child: Text('Service',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 11))),
                    SizedBox(
                        width: 80,
                        child: Text('Total',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 11))),
                    SizedBox(
                        width: 80,
                        child: Text('Date',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 11))),
                  ],
                ),
              ),
              ...units.map((unit) {
                final invoice = unit.latestInvoice;
                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border:
                    Border(bottom: BorderSide(color: Colors.grey.shade100)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                          width: 70,
                          child: Text(unit.unitNumber,
                              style: const TextStyle(fontSize: 11))),
                      SizedBox(
                          width: 100,
                          child: Text(unit.tenant?.name ?? '-',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11))),
                      SizedBox(
                          width: 80,
                          child: Text(
                              invoice != null
                                  ? kes(double.parse(invoice.rent))
                                  : '-',
                              style: const TextStyle(fontSize: 11))),
                      SizedBox(
                          width: 80,
                          child: Text(
                              invoice != null
                                  ? kes(double.parse(invoice.service))
                                  : '-',
                              style: const TextStyle(fontSize: 11))),
                      SizedBox(
                          width: 80,
                          child: Text(
                              invoice != null
                                  ? kes(double.parse(invoice.amount))
                                  : '-',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.green))),
                      SizedBox(
                          width: 80,
                          child: Text(invoice?.invoiceDate ?? '-',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11))),
                    ],
                  ),
                );
              }).toList(),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(8)),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                        width: 330,
                        child: Text('TOTAL',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 11))),
                    SizedBox(
                      width: 80,
                      child: Text(
                        kes(totalAmount),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                            fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _closeLoadingDialog() {
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

  void _closeLoadingDialogAndShowError(String message) {
    _closeLoadingDialog();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  void _showPropertiesDialog(PropertyResponse propertyResponse) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.blue.shade700, Colors.blue.shade900],
                  ),
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.business,
                              color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'All Properties',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${propertyResponse.properties.length} properties • ${propertyResponse.totalUnits} units',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                        iconSize: 16,
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildDialogStatCard(
                        'Properties',
                        propertyResponse.properties.length.toString(),
                        Icons.business,
                        Colors.blue,
                      ),
                      const SizedBox(width: 10),
                      _buildDialogStatCard(
                        'Total Units',
                        propertyResponse.totalUnits.toString(),
                        Icons.apartment,
                        Colors.green,
                      ),
                      const SizedBox(width: 10),
                      _buildDialogStatCard(
                        'Occupied',
                        propertyResponse.occupiedUnits.toString(),
                        Icons.check_circle,
                        Colors.orange,
                      ),
                      const SizedBox(width: 10),
                      _buildDialogStatCard(
                        'Vacant',
                        (propertyResponse.totalUnits -
                            propertyResponse.occupiedUnits)
                            .toString(),
                        Icons.door_front_door,
                        Colors.red,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: propertyResponse.properties.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.business_outlined,
                          size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('No properties found',
                          style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                )
                    : ListView.builder(
                  itemCount: propertyResponse.properties.length,
                  itemBuilder: (context, index) {
                    final property =
                    propertyResponse.properties[index];
                    final occupiedUnits =
                        property.units.where((u) => u.isOccupied).length;
                    final vacantUnits =
                        property.units.length - occupiedUnits;
                    final occupancyRate = property.units.isEmpty
                        ? 0
                        : (occupiedUnits /
                        property.units.length *
                        100)
                        .round();

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ExpansionTile(
                        title: Text(
                          property.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        subtitle: Text(
                          '${property.location} • ${property.units.length} units',
                          style: const TextStyle(
                              fontWeight: FontWeight.w300, fontSize: 11),
                        ),
                        children: [
                          Padding(
                            padding:
                            const EdgeInsets.fromLTRB(14, 0, 14, 14),
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius:
                                    BorderRadius.circular(8),
                                  ),
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                      children: [
                                        _buildPropertyStat(
                                          'Total',
                                          property.units.length
                                              .toString(),
                                          Icons.apartment,
                                          Colors.blue,
                                        ),
                                        const SizedBox(width: 16),
                                        _buildPropertyStat(
                                          'Occupied',
                                          occupiedUnits.toString(),
                                          Icons.check_circle,
                                          Colors.green,
                                        ),
                                        const SizedBox(width: 16),
                                        _buildPropertyStat(
                                          'Vacant',
                                          vacantUnits.toString(),
                                          Icons.cancel,
                                          Colors.orange,
                                        ),
                                        const SizedBox(width: 16),
                                        _buildPropertyStat(
                                          'Occupancy',
                                          '$occupancyRate%',
                                          Icons.percent,
                                          Colors.purple,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                if (property.units.isNotEmpty) ...[
                                  const Text(
                                    'Units:',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildUnitsTable(property.units),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildPropertyStat(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildUnitsTable(List<UnitDialog> units) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 500),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                        width: 80,
                        child: Text('Unit #',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 11))),
                    SizedBox(
                        width: 120,
                        child: Text('Tenant',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 11))),
                    SizedBox(
                        width: 90,
                        child: Text('Rent',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 11))),
                    SizedBox(
                        width: 90,
                        child: Text('Status',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 11))),
                  ],
                ),
              ),
              ...units.map((unit) => Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: Colors.grey.shade100)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                        width: 80,
                        child: Text(unit.unitNumber,
                            style: const TextStyle(fontSize: 11))),
                    SizedBox(
                        width: 120,
                        child: Text(unit.tenant?.name ?? '-',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11))),
                    SizedBox(
                        width: 90,
                        child: Text(kes(unit.rentAmount),
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500))),
                    SizedBox(
                      width: 90,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: unit.isOccupied
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              unit.isOccupied
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              size: 11,
                              color: unit.isOccupied
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              unit.isOccupied ? 'Occupied' : 'Vacant',
                              style: TextStyle(
                                fontSize: 9,
                                color: unit.isOccupied
                                    ? Colors.green
                                    : Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  PropertyResponse _filterUnpaidUnits(PropertyResponse original) {
    final filteredProperties = original.properties.map((property) {
      final unpaidUnits = property.units
          .where((unit) =>
      unit.latestInvoice != null &&
          (unit.latestInvoice!.isUnpaid ||
              unit.latestInvoice!.isPartial))
          .toList();
      return PropertyDialog(
        id: property.id,
        name: property.name,
        type: property.type,
        location: property.location,
        totalUnits: property.totalUnits,
        userId: property.userId,
        createdAt: property.createdAt,
        updatedAt: property.updatedAt,
        units: unpaidUnits,
      );
    }).where((property) => property.units.isNotEmpty).toList();

    final unpaidUnits = original.units
        .where((unit) =>
    unit.latestInvoice != null &&
        (unit.latestInvoice!.isUnpaid ||
            unit.latestInvoice!.isPartial))
        .toList();

    return PropertyResponse(
      properties: filteredProperties,
      totalUnits: unpaidUnits.length,
      occupiedUnits: unpaidUnits.where((u) => u.isOccupied).length,
      vacantUnits: unpaidUnits.where((u) => u.isVacant).length,
      units: unpaidUnits,
    );
  }

  void _showUnpaidUnitsDialogContent(PropertyResponse propertyResponse) {
    final totalOutstanding = propertyResponse.units
        .fold(0.0, (sum, unit) => sum + _getOutstandingAmount(unit));

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.red.shade700, Colors.red.shade900],
                  ),
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.pending_actions,
                              color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Unpaid Units',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${propertyResponse.properties.length} properties • ${propertyResponse.totalUnits} unpaid units',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                        iconSize: 16,
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildDialogStatCard(
                        'Unpaid Units',
                        propertyResponse.totalUnits.toString(),
                        Icons.pending_actions,
                        Colors.red,
                      ),
                      const SizedBox(width: 10),
                      _buildDialogStatCard(
                        'Outstanding',
                        kes(totalOutstanding),
                        Icons.warning,
                        Colors.orange,
                      ),
                      const SizedBox(width: 10),
                      _buildDialogStatCard(
                        'Properties',
                        propertyResponse.properties.length.toString(),
                        Icons.business,
                        Colors.purple,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: propertyResponse.properties.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle,
                          size: 48, color: Colors.green.shade400),
                      const SizedBox(height: 16),
                      Text('No unpaid units found!',
                          style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                )
                    : ListView.builder(
                  itemCount: propertyResponse.properties.length,
                  itemBuilder: (context, index) {
                    final property =
                    propertyResponse.properties[index];
                    final propertyOutstanding = property.units.fold(0.0,
                            (sum, unit) => sum + _getOutstandingAmount(unit));

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ExpansionTile(
                        title: Text(
                          property.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        subtitle: Text(
                          '${property.location} • ${property.units.length} unpaid units',
                          style: const TextStyle(
                              fontWeight: FontWeight.w300, fontSize: 11),
                        ),
                        children: [
                          Padding(
                            padding:
                            const EdgeInsets.fromLTRB(14, 0, 14, 14),
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius:
                                    BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildPropertyStat(
                                        'Unpaid',
                                        property.units.length.toString(),
                                        Icons.pending_actions,
                                        Colors.red,
                                      ),
                                      _buildPropertyStat(
                                        'Outstanding',
                                        kes(propertyOutstanding),
                                        Icons.warning,
                                        Colors.orange,
                                      ),
                                      _buildPropertyStat(
                                        'Avg',
                                        property.units.isEmpty
                                            ? '0'
                                            : kes(propertyOutstanding /
                                            property.units.length),
                                        Icons.calculate,
                                        Colors.purple,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                if (property.units.isNotEmpty) ...[
                                  const Text(
                                    'Unpaid Units:',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildUnpaidUnitsTable(
                                      property.units),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
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

  double _getOutstandingAmount(UnitDialog unit) {
    if (unit.latestInvoice == null) return unit.rentAmount;

    final invoice = unit.latestInvoice!;
    if (invoice.isPaid) return 0.0;

    return double.parse(invoice.amount);
  }

  Widget _buildUnpaidUnitsTable(List<UnitDialog> units) {
    final totalOutstanding = units
        .fold(0.0, (sum, unit) => sum + _getOutstandingAmount(unit));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 750),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                        width: 70,
                        child: Text('Unit #',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 11))),
                    SizedBox(
                        width: 100,
                        child: Text('Tenant',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 11))),
                    SizedBox(
                        width: 70,
                        child: Text('Rent',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 11))),
                    SizedBox(
                        width: 70,
                        child: Text('Service',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 11))),
                    SizedBox(
                        width: 90,
                        child: Text('Outstanding',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 11))),
                    SizedBox(
                        width: 80,
                        child: Text('Due Date',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 11))),
                    SizedBox(
                        width: 70,
                        child: Text('Action',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 11))),
                  ],
                ),
              ),
              ...units.map((unit) {
                final invoice = unit.latestInvoice;
                final outstandingAmount = _getOutstandingAmount(unit);
                final isPartial = invoice?.isPartial ?? false;

                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border:
                    Border(bottom: BorderSide(color: Colors.grey.shade100)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                          width: 70,
                          child: Text(unit.unitNumber,
                              style: const TextStyle(fontSize: 11))),
                      SizedBox(
                          width: 100,
                          child: Text(unit.tenant?.name ?? '-',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11))),
                      SizedBox(
                          width: 70,
                          child: Text(
                              invoice != null
                                  ? kes(double.parse(invoice.rent))
                                  : kes(unit.rentAmount),
                              style: const TextStyle(fontSize: 11))),
                      SizedBox(
                          width: 70,
                          child: Text(
                              invoice != null
                                  ? kes(double.parse(invoice.service))
                                  : '0.00',
                              style: const TextStyle(fontSize: 11))),
                      SizedBox(
                          width: 90,
                          child: Text(kes(outstandingAmount),
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: isPartial
                                      ? Colors.orange
                                      : Colors.red))),
                      SizedBox(
                          width: 80,
                          child: Text(invoice?.invoiceDate ?? 'No invoice',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11))),
                      SizedBox(
                        width: 70,
                        child: InkWell(
                          onTap: invoice == null
                              ? () => _showCreateInvoiceDialog(unit)
                              : null,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: invoice == null
                                  ? Colors.red.withValues(alpha: 0.1)
                                  : Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: invoice == null
                                    ? Colors.red.withValues(alpha: 0.3)
                                    : Colors.grey.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              invoice == null ? 'Create' : 'Created',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                color:
                                invoice == null ? Colors.red : Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(8)),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                        width: 310,
                        child: Text('TOTAL OUTSTANDING',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 11))),
                    SizedBox(
                      width: 90,
                      child: Text(
                        kes(totalOutstanding),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                            fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateInvoiceDialog(UnitDialog unit) {
    // Implement your create invoice logic here
  }

  void _showSignOutDialog(BuildContext context) {
    var screenSize = MediaQuery.of(context).size.width;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Sign out',
            style: TextStyle(
              fontSize: screenSize <= 1000 ? 12 : 14,
              fontFamily: "SF-Pro-Text-Bold",
            ),
          ),
          content: Text(
            'Are you sure?',
            style: TextStyle(
              fontSize: screenSize <= 1000 ? 11 : 13,
              fontFamily: "SF-Pro-Text-Regular",
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'No',
                style: TextStyle(
                  fontSize: screenSize <= 1000 ? 12 : 14,
                  color: Colors.black,
                  fontFamily: "SF-Pro-Text-Bold",
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(
                'Yes',
                style: TextStyle(
                  fontSize: screenSize <= 1000 ? 12 : 14,
                  color: Colors.red,
                  fontFamily: "SF-Pro-Text-Bold",
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildManageProperties(BuildContext context) {
    return FutureBuilder<List<Nest>>(
      future: _propertyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildManagePropertiesSkeleton();
        }

        if (snapshot.hasError) {
          return Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red.shade400,
                      size: 32,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Unable to load properties',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Please try again later',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildManagePropertiesEmptyState();
        }

        final List<Nest> properties = snapshot.data!;

        _propertyCache = properties;

        return Card(
          elevation: 1,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.blue.shade600,
                            Colors.indigo.shade600,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.dashboard_customize_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Manage Properties',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              fontFamily: "SF-Pro-Text-Bold",
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${properties.length} properties',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _showAddPropertyDialog,
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text(
                        'Add',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue.shade700,
                        side: BorderSide(color: Colors.blue.shade200),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade200),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(14),
                itemCount: properties.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final property = properties[index];
                  return _buildManagePropertyCard(context, property);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildManagePropertyCard(
      BuildContext context,
      Nest property,
      ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PropertyResponsivePage(
                property: property,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.blue.shade50.withValues(alpha: 0.45),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.shade100,
                      Colors.indigo.shade100,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.apartment_rounded,
                  color: Colors.blue.shade700,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFamily: "SF-Pro-Text-Bold",
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            property.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            property.type,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.home_work_outlined,
                                size: 10,
                                color: Colors.green.shade700,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${property.totalUnits} Units',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: IconButton(
                  tooltip: 'Manage property',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PropertyResponsivePage(
                          property: property,
                        ),
                      ),
                    );
                  },
                  icon: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: Colors.blue.shade700,
                  ),
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMaintenanceSection(BuildContext context) {
    return FutureBuilder<List<MaintenanceIssue>>(
      future: _maintenanceIssuesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildMaintenanceLoading();
        }

        if (snapshot.hasError) {
          return _buildMaintenanceError(context);
        }

        final issues = snapshot.data ?? [];

        if (issues.isEmpty) {
          return _buildEmptyMaintenanceSection(context);
        }

        final openIssues =
            issues.where((issue) => issue.status == 'open').length;

        final inProgressIssues =
            issues.where((issue) => issue.status == 'in_progress').length;

        final resolvedIssues =
            issues.where((issue) => issue.status == 'resolved').length;

        final recentIssues = [...issues];
        recentIssues.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        final displayIssues = recentIssues.take(5).toList();

        return Card(
          elevation: 1,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.build_rounded,
                        color: Colors.orange.shade700,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Maintenance',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'SF-Pro-Text-Bold',
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${issues.length} ${issues.length == 1 ? 'issue' : 'issues'}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => MaintenancePage()),
                        );
                      },
                      icon: const Icon(Icons.arrow_forward, size: 14),
                      label: const Text(
                        'View all',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Column(
                  children: [
                    _buildMaintenanceSummary(
                      'Open',
                      openIssues,
                      Colors.red,
                      Icons.error_outline,
                    ),
                    const SizedBox(height: 8),
                    _buildMaintenanceSummary(
                      'In Progress',
                      inProgressIssues,
                      Colors.orange,
                      Icons.build_outlined,
                    ),
                    const SizedBox(height: 8),
                    _buildMaintenanceSummary(
                      'Resolved',
                      resolvedIssues,
                      Colors.green,
                      Icons.check_circle_outline,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Recent Issues',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${displayIssues.length} shown',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayIssues.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return _buildMaintenanceItem(
                      context,
                      displayIssues[index],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMaintenanceSummary(
      String title,
      int count,
      Color color,
      IconData icon,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              icon,
              size: 14,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 14,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceLoading() {
    return Card(
      elevation: 1,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildSkeletonBox(width: 36, height: 36, radius: 11),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSkeletonBox(width: 100, height: 12),
                      const SizedBox(height: 7),
                      _buildSkeletonBox(width: 170, height: 9),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildSkeletonBox(
              width: double.infinity,
              height: 60,
              radius: 11,
            ),
            const SizedBox(height: 8),
            _buildSkeletonBox(
              width: double.infinity,
              height: 60,
              radius: 11,
            ),
            const SizedBox(height: 8),
            _buildSkeletonBox(
              width: double.infinity,
              height: 60,
              radius: 11,
            ),
            const SizedBox(height: 16),
            _buildSkeletonBox(width: 100, height: 11),
            const SizedBox(height: 10),
            _buildMaintenanceSkeletonItem(),
            const SizedBox(height: 8),
            _buildMaintenanceSkeletonItem(),
          ],
        ),
      ),
    );
  }

  Widget _buildMaintenanceSkeletonItem() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildSkeletonBox(width: 34, height: 34, radius: 9),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSkeletonBox(width: 150, height: 10),
                const SizedBox(height: 7),
                _buildSkeletonBox(width: 90, height: 8),
              ],
            ),
          ),
          _buildSkeletonBox(width: 55, height: 22, radius: 6),
        ],
      ),
    );
  }

  Widget _buildSkeletonBox({
    required double width,
    required double height,
    double radius = 6,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _buildMaintenanceItem(
      BuildContext context,
      MaintenanceIssue issue,
      ) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (issue.status.toLowerCase()) {
      case 'open':
        statusColor = Colors.red.shade600;
        statusIcon = Icons.error_outline;
        statusText = 'Open';
        break;
      case 'in_progress':
        statusColor = Colors.orange.shade700;
        statusIcon = Icons.build_outlined;
        statusText = 'In Progress';
        break;
      case 'resolved':
        statusColor = Colors.green.shade600;
        statusIcon = Icons.check_circle_outline;
        statusText = 'Resolved';
        break;
      default:
        statusColor = Colors.grey.shade600;
        statusIcon = Icons.help_outline;
        statusText = issue.status;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _showMaintenanceDetails(context, issue);
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  statusIcon,
                  color: statusColor,
                  size: 12,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            issue.subject,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'SF-Pro-Text-Bold',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildMaintenanceStatus(
                          statusText,
                          statusColor,
                          statusIcon,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${issue.propertyName} • Unit ${issue.houseNo}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMaintenanceStatus(
      String status,
      Color color,
      IconData icon,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showMaintenanceDetails(
      BuildContext context,
      MaintenanceIssue issue,
      ) {
    Color statusColor;

    switch (issue.status.toLowerCase()) {
      case 'open':
        statusColor = Colors.red.shade600;
        break;
      case 'in_progress':
        statusColor = Colors.orange.shade700;
        break;
      case 'resolved':
        statusColor = Colors.green.shade600;
        break;
      default:
        statusColor = Colors.grey.shade600;
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 600,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.orange.shade600,
                        Colors.deepOrange.shade700,
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.build_rounded,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Maintenance Details',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        issue.subject,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildMaintenanceDetailRow(
                        Icons.apartment,
                        'Property',
                        issue.propertyName,
                      ),
                      _buildMaintenanceDetailRow(
                        Icons.home_outlined,
                        'Unit',
                        issue.houseNo,
                      ),
                      _buildMaintenanceDetailRow(
                        Icons.calendar_today_outlined,
                        'Reported',
                        _formatMaintenanceDate(
                          issue.createdAt.toString(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Description',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              issue.description,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _maintenanceStatusText(issue.status),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMaintenanceDetailRow(
      IconData icon,
      String label,
      String value,
      ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 17,
            color: Colors.grey.shade500,
          ),
          const SizedBox(width: 10),
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _maintenanceStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return 'Open';
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      default:
        return status;
    }
  }

  String _formatMaintenanceDate(String date) {
    try {
      final parsed = DateTime.parse(date);
      return DateFormat('dd MMM yyyy').format(parsed);
    } catch (_) {
      return date;
    }
  }

  Widget _buildMaintenanceError(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.build_circle_outlined,
                size: 42,
                color: Colors.red.shade300,
              ),
              const SizedBox(height: 12),
              const Text(
                'Unable to load maintenance issues',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _maintenanceIssuesFuture =
                        apiService.fetchMaintenanceIssues();
                  });
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyMaintenanceSection(BuildContext context) {
    return Card(
      elevation: 1,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 24,
        ),
        child: Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.build_circle_outlined,
                  color: Colors.green.shade600,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'All clear!',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'There are no maintenance issues requiring attention.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MaintenancePage(),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.build_outlined,
                  size: 16,
                ),
                label: const Text(
                  'View Maintenance',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange.shade700,
                  side: BorderSide(
                    color: Colors.orange.shade200,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentsSection() {
    final primaryColor = Theme.of(context).primaryColor;

    final Map<String, List<Document>> groupedDocuments = {};

    for (final document in _dashboardDocuments) {
      final propertyName = document.propertyName.trim().isNotEmpty
          ? document.propertyName.trim()
          : 'Other Documents';

      groupedDocuments.putIfAbsent(propertyName, () => []);
      groupedDocuments[propertyName]!.add(document);
    }

    return Container(
      margin: EdgeInsets.fromLTRB(
        _isMobile ? 0 : 8,
        4,
        _isMobile ? 0 : 8,
        _isMobile ? 4 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primaryColor,
                        primaryColor.withValues(alpha: 0.75),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.folder_copy_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Documents',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _documentsLoading
                            ? 'Loading documents...'
                            : '${_dashboardDocuments.length} recent documents',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DocumentsPage(),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View all',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 3),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 11,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!_documentsLoading && _dashboardDocuments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildDocumentSummary(),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: _documentsLoading
                ? _buildDocumentsSkeleton()
                : _dashboardDocuments.isEmpty
                ? _buildDocumentsEmptyState()
                : Column(
              children:
              groupedDocuments.entries.map((entry) {
                return _buildPropertyDocumentGroup(
                  propertyName: entry.key,
                  documents: entry.value,
                  primaryColor: primaryColor,
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DocumentsPage(),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.folder_open_rounded,
                      size: 16,
                    ),
                    label: const Text('Manage Documents',
                        style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyDocumentGroup({
    required String propertyName,
    required List<Document> documents,
    required Color primaryColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.apartment_rounded,
                    color: primaryColor,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        propertyName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${documents.length} ${documents.length == 1 ? 'document' : 'documents'}',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey.shade200,
                    ),
                  ),
                  child: Text(
                    '${documents.length}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Column(
              children: documents.map((document) {
                return _buildDashboardDocumentItem(document);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentSummary() {
    final total = _dashboardDocuments.length;

    final pdfCount = _dashboardDocuments
        .where((doc) => doc.url.toLowerCase().contains('.pdf'))
        .length;

    final categories = _dashboardDocuments
        .map((doc) => doc.category)
        .where((category) => category.isNotEmpty)
        .toSet()
        .length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildDocumentMetric(
              icon: Icons.description_outlined,
              value: '$total',
              label: 'Recent',
            ),
          ),
          Container(
            height: 30,
            width: 1,
            color: Colors.grey.shade300,
          ),
          Expanded(
            child: _buildDocumentMetric(
              icon: Icons.picture_as_pdf_outlined,
              value: '$pdfCount',
              label: 'PDF files',
            ),
          ),
          Container(
            height: 30,
            width: 1,
            color: Colors.grey.shade300,
          ),
          Expanded(
            child: _buildDocumentMetric(
              icon: Icons.category_outlined,
              value: '$categories',
              label: 'Categories',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentMetric({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          size: 18,
          color: Theme.of(context).primaryColor,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentsSkeleton() {
    return Column(
      children: List.generate(
        3,
            (index) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 12,
                      width: 150,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 9,
                      width: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentsEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 20,
        horizontal: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.folder_open_rounded,
              size: 25,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'No documents yet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Upload tenant documents to keep everything organized.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardDocumentItem(Document document) {
    final primaryColor = Theme.of(context).primaryColor;

    final isPdf = document.url.toLowerCase().contains('.pdf');

    final date = document.createdAt;

    final formattedDate = date != null
        ? DateFormat('dd MMM yyyy').format(date)
        : 'Unknown date';

    return InkWell(
      onTap: () async {
        try {
          await launchUrl(
            Uri.parse(document.url),
            mode: LaunchMode.externalApplication,
          );
        } catch (e) {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unable to open document: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isPdf
                    ? Colors.red.withValues(alpha: 0.1)
                    : primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isPdf
                    ? Icons.picture_as_pdf_rounded
                    : Icons.description_rounded,
                color: isPdf ? Colors.red : primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatDocumentName(document.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          document.category.toUpperCase(),
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 10,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          formattedDate,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: Colors.grey.shade200,
                ),
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagePropertiesSkeleton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _skeletonBox(width: 42, height: 42, radius: 14),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _skeletonBox(width: 150, height: 15),
                    const SizedBox(height: 7),
                    _skeletonBox(width: 210, height: 10),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _skeletonBox(height: 70, width: 70, radius: 12),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _skeletonBox(height: 70, width: 70, radius: 12),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _skeletonBox(
            width: double.infinity,
            height: 42,
            radius: 12,
          ),
        ],
      ),
    );
  }

  Widget _skeletonBox({
    required double width,
    required double height,
    double radius = 6,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _buildManagePropertiesEmptyState() {
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      padding: const EdgeInsets.all(24),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.apartment_rounded,
              size: 30,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No properties yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add your first property to start managing tenants, units and payments.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              _showAddPropertyDialog();
            },
            icon: const Icon(
              Icons.add_rounded,
              size: 17,
            ),
            label: const Text('Add Property',
                style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Animated full-page loading screen for the mobile dashboard.
// ═══════════════════════════════════════════════════════════════
class _MobileDashboardLoader extends StatefulWidget {
  const _MobileDashboardLoader({
    this.messages = const ['Loading your dashboard...'],
  });

  final List<String> messages;

  @override
  State<_MobileDashboardLoader> createState() => _MobileDashboardLoaderState();
}

class _MobileDashboardLoaderState extends State<_MobileDashboardLoader>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _spin;
  late final AnimationController _breathe;
  late final AnimationController _progress;
  late final AnimationController _entrance;

  int _messageIndex = 0;

  @override
  void initState() {
    super.initState();

    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _progress = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..forward();

    _cycleMessages();
  }

  Future<void> _cycleMessages() async {
    if (widget.messages.length < 2) return;

    while (mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;
      setState(() {
        _messageIndex = (_messageIndex + 1) % widget.messages.length;
      });
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _spin.dispose();
    _breathe.dispose();
    _progress.dispose();
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final blue = Palette.nestBlue;

    return Container(
      color: const Color(0xFFF4F7FC),
      child: Center(
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: _entrance,
            curve: Curves.easeOut,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildOrbit(blue),
              const SizedBox(height: 32),
              _buildWordmark(blue),
              const SizedBox(height: 12),
              _buildMessage(),
              const SizedBox(height: 22),
              _buildProgressBar(blue),
              const SizedBox(height: 16),
              _buildDots(blue),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrbit(Color blue) {
    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ...List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                final t = (_pulse.value + index / 3) % 1.0;
                final size = 74 + (t * 74);

                return Opacity(
                  opacity: (1 - t) * 0.35,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: blue, width: 1.6),
                    ),
                  ),
                );
              },
            );
          }),
          RotationTransition(
            turns: ReverseAnimation(_spin),
            child: CustomPaint(
              size: const Size(135, 135),
              painter: _MobileLoaderDotsPainter(color: blue),
            ),
          ),
          RotationTransition(
            turns: _spin,
            child: CustomPaint(
              size: const Size(115, 115),
              painter: _MobileLoaderArcPainter(color: blue),
            ),
          ),
          AnimatedBuilder(
            animation: _breathe,
            builder: (context, child) {
              final t = Curves.easeInOut.transform(_breathe.value);
              return Transform.scale(
                scale: 0.96 + (t * 0.08),
                child: child,
              );
            },
            child: Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    blue,
                    Color.lerp(blue, Colors.black, 0.25)!,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: blue.withValues(alpha: 0.35),
                    blurRadius: 22,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                BootstrapIcons.houses_fill,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordmark(Color blue) {
    return Column(
      children: [
        Text(
          'KejaHub',
          style: TextStyle(
            fontSize: 20,
            letterSpacing: 7,
            fontWeight: FontWeight.w700,
            fontFamily: 'SF-Pro-Text-Bold',
            color: blue,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'PROPERTY MANAGEMENT',
          style: TextStyle(
            fontSize: 8,
            letterSpacing: 3,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildMessage() {
    return SizedBox(
      height: 20,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: Text(
          widget.messages[_messageIndex],
          key: ValueKey<int>(_messageIndex),
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'SF-Pro-Text-Regular',
            color: Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(Color blue) {
    return SizedBox(
      width: 190,
      height: 4,
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          final value =
          (0.08 + Curves.easeOutCubic.transform(_progress.value) * 0.82)
              .clamp(0.0, 1.0);

          return ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 4,
              backgroundColor: blue.withValues(alpha: 0.10),
              valueColor: AlwaysStoppedAnimation<Color>(blue),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDots(Color blue) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final t = (_pulse.value + index * 0.18) % 1.0;
            final intensity = (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);
            final opacity = 0.20 + (intensity * 0.80);

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: blue.withValues(alpha: opacity),
              ),
            );
          }),
        );
      },
    );
  }
}

// ── Sweeping gradient arc ──────────────────────────────────────
class _MobileLoaderArcPainter extends CustomPainter {
  const _MobileLoaderArcPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.shortestSide * 0.032;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.05),
          color.withValues(alpha: 0.85),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect);

    canvas.drawArc(
      rect.deflate(stroke / 2),
      0,
      4.4,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _MobileLoaderArcPainter oldDelegate) =>
      oldDelegate.color != color;
}

// ── Fading dotted ring ─────────────────────────────────────────
class _MobileLoaderDotsPainter extends CustomPainter {
  const _MobileLoaderDotsPainter({
    required this.color,
    this.dotCount = 20,
  });

  final Color color;
  final int dotCount;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 3;
    final paint = Paint()..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(center.dx, center.dy);

    for (int i = 0; i < dotCount; i++) {
      canvas.rotate(6.28318 / dotCount);

      final fade = i / dotCount;
      paint.color = color.withValues(alpha: 0.04 + fade * 0.26);

      canvas.drawCircle(Offset(0, -radius), 1.5, paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MobileLoaderDotsPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.dotCount != dotCount;
}