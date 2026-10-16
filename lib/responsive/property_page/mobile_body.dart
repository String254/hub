import 'package:flutter/material.dart';
import 'package:hub/models/models.dart';
import 'package:hub/config/config.dart';
import 'package:hub/services/services.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hub/widgets/widgets.dart';
import 'package:hub/pages/pages.dart';

class PropertyDetailsMobilePage extends StatefulWidget {
  final Nest property;

  const PropertyDetailsMobilePage({super.key, required this.property});

  @override
  State<PropertyDetailsMobilePage> createState() =>
      _PropertyDetailsMobilePageState();
}

class _PropertyDetailsMobilePageState extends State<PropertyDetailsMobilePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  DateTimeRange? _selectedDateRange;
  late ApiPropertyService apiService;
  late Future<PropertyDetails> propertiesFuture;
  late Future<List<Payment>> paymentsFuture;
  late Future<List<MonthlyRevenue>> propertyRevenueFuture;
  late Future<List<TenantInfo>> tenantsFuture;
  late Future<List<UnitsDetails>> unitsFuture;

  // Full page loading gate
  bool _isInitialLoading = true;

  // ─────────────────────────────────────────────────────────────
  // RESPONSIVE HELPERS
  // ─────────────────────────────────────────────────────────────

  bool get _isMobile => MediaQuery.of(context).size.width < 600;
  bool get _isTablet {
    final w = MediaQuery.of(context).size.width;
    return w >= 600 && w < 850;
  }

  double get _pagePadding => _isMobile ? 12 : 18;
  double get _sectionSpacing => _isMobile ? 14 : 20;

  String formatDateToDdMmm(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd-MMM').format(date);
    } catch (e) {
      return dateString;
    }
  }

  final NumberFormat _kesFormatter = NumberFormat.currency(
    locale: 'en_KE',
    symbol: 'Ksh ',
    decimalDigits: 0,
  );

  String _kes(num amount) => _kesFormatter.format(amount);

  void _reloadTenants() {
    setState(() {
      tenantsFuture = apiService.fetchPropertyTenants(widget.property.id);
    });
  }

  void _reloadUnits() {
    setState(() {
      unitsFuture = apiService.fetchPropertyUnits(widget.property.id);
      propertiesFuture = apiService.fetchPropertyDetails(widget.property.id);
    });
  }

  void _reloadAllData() {
    setState(() {
      propertiesFuture = apiService.fetchPropertyDetails(widget.property.id);
      paymentsFuture = apiService.fetchRecentPayments(widget.property.id);
      tenantsFuture = apiService.fetchPropertyTenants(widget.property.id);
      propertyRevenueFuture =
          apiService.fetchPropertyRevenue(widget.property.id);
      unitsFuture = apiService.fetchPropertyUnits(widget.property.id);
    });
  }

  // ═════════════════════════════════════════════════════════════
  // Animated toast notification engine
  // ═════════════════════════════════════════════════════════════
  void _showNotification({
    required String title,
    required String message,
    required Color color,
    bool isError = false,
  }) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    late OverlayEntry entry;
    var removed = false;

    entry = OverlayEntry(
      builder: (_) => _AnimatedNotificationOverlay(
        title: title,
        message: message,
        color: color,
        isError: isError,
        onDismiss: () {
          if (removed) return;
          removed = true;
          entry.remove();
        },
      ),
    );

    overlay.insert(entry);
  }

  void _showSuccessToast({
    required String title,
    required String message,
    Color color = const Color(0xFF059669),
  }) {
    _showNotification(
      title: title,
      message: message,
      color: color,
    );
  }

  void _showErrorToast({
    required String title,
    required String message,
  }) {
    _showNotification(
      title: title,
      message: message,
      color: const Color(0xFFDC2626),
      isError: true,
    );
  }

  void _showAdditionalCost(
      int id, int tenantId, String houseNo, String tenantEmail,
      String tenantName) {
    final waterController = TextEditingController();
    final serviceController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Additional Costs',
            style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              keyboardType: TextInputType.number,
              controller: waterController,
              decoration: const InputDecoration(labelText: 'Water Bill'),
            ),
            TextField(
              keyboardType: TextInputType.number,
              controller: serviceController,
              decoration: const InputDecoration(labelText: 'Service Bill'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            child: const Text('Save'),
            onPressed: () async {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => InvoicePage(
                      unitId: id,
                      propertyId: widget.property.id,
                      propertyName: widget.property.name,
                      tenantId: tenantId,
                      houseNo: houseNo,
                      tenantName: tenantName,
                      tenantEmail: tenantEmail,
                      paybillNumber: widget.property.paybillNumber ?? '',
                      accountNumber: widget.property.accountNumber ?? '',
                      waterBill: double.parse(waterController.text),
                      serviceCost: double.parse(serviceController.text)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_KE',
      symbol: 'KES ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  void _showInvoiceDetailsDialog(BuildContext context, Invoice invoice) {
    final isPaid = invoice.status.toLowerCase() == 'paid';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: _isMobile ? 16 : 24,
          vertical: 24,
        ),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 500, maxWidth: 500),
          padding: const EdgeInsets.all(20),
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
                  color:
                  isPaid ? Colors.green.shade50 : Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPaid ? Icons.check_circle : Icons.pending,
                  size: 30,
                  color:
                  isPaid ? Colors.green.shade700 : Colors.orange.shade700,
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
                                invoiceId: invoice.id,
                                invoiceRef: invoice.ref),
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
              fontSize: 13,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: valueColor ?? Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsDashboard() {
    return _buildSectionCard(
      title: 'Recent Payments',
      subtitle: 'Latest rent and property payment activity',
      icon: Icons.receipt_long_outlined,
      trailing: _compactActionButton(
        label: 'Refresh',
        icon: Icons.refresh_rounded,
        onTap: _reloadAllData,
      ),
      child: FutureBuilder<List<Payment>>(
        future: paymentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildListSkeleton();
          }

          if (snapshot.hasError) {
            return _buildErrorState(
              message: 'Unable to load recent payments',
              onRetry: _reloadAllData,
            );
          }

          final payments = snapshot.data ?? [];

          if (payments.isEmpty) {
            return _buildEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No payments yet',
              subtitle: 'Recent property payments will appear here.',
            );
          }

          return _recentPaymentsCard(payments);
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
    apiService = ApiPropertyService(baseUrl: baseUrl);
    _initializeFutures();
    _bootstrapPage();
  }

  void _initializeFutures() {
    propertyRevenueFuture =
        apiService.fetchPropertyRevenue(widget.property.id);
    paymentsFuture = apiService.fetchRecentPayments(widget.property.id);
    tenantsFuture = apiService.fetchPropertyTenants(widget.property.id);
    propertiesFuture = apiService.fetchPropertyDetails(widget.property.id);
    unitsFuture = apiService.fetchPropertyUnits(widget.property.id);
  }

  // ─────────────────────────────────────────────────────────────
  // Wait for initial data, keep loader visible for minimum time.
  // ─────────────────────────────────────────────────────────────
  Future<void> _bootstrapPage() async {
    final started = DateTime.now();

    final pending = <Future<Object?>>[
      propertiesFuture,
      paymentsFuture,
      tenantsFuture,
      propertyRevenueFuture,
      unitsFuture,
    ];

    for (final future in pending) {
      try {
        await future;
      } catch (_) {
        // Each section renders its own error state – ignore here.
      }
    }

    // Reduced minimum for snappier mobile feel
    const minimum = Duration(milliseconds: 1400);
    final elapsed = DateTime.now().difference(started);
    if (elapsed < minimum) {
      await Future<void>.delayed(minimum - elapsed);
    }

    if (!mounted) return;
    setState(() => _isInitialLoading = false);
  }

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
                    'Loading units...',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final units = await apiService.fetchPropertyUnits(widget.property.id);

    if (!mounted) return;
    Navigator.of(context).pop();

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => _buildUnitsListDialog(units),
    );
  }

  Widget _buildUnitsListDialog(List<UnitsDetails> units) {
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: _isMobile ? 12 : 24,
        vertical: 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
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
                        child: const Icon(Icons.apartment,
                            color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'All Units',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '${units.length} total units',
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
                      'Total Units',
                      units.length.toString(),
                      Icons.apartment,
                      Colors.blue,
                    ),
                    const SizedBox(width: 10),
                    _buildDialogStatCard(
                      'Occupied',
                      units
                          .where((u) => u.status == 'occupied')
                          .length
                          .toString(),
                      Icons.check_circle,
                      Colors.green,
                    ),
                    const SizedBox(width: 10),
                    _buildDialogStatCard(
                      'Vacant',
                      units.where((u) => u.status == 'vacant').length
                          .toString(),
                      Icons.door_front_door,
                      Colors.orange,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: units.isEmpty
                  ? _buildDialogEmptyState(
                icon: Icons.home_work_outlined,
                title: 'No units found',
              )
                  : ListView.builder(
                padding: EdgeInsets.all(_isMobile ? 12 : 16),
                itemCount: units.length,
                itemBuilder: (context, index) {
                  final unit = units[index];
                  return _buildUnitCard(unit);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitCard(UnitsDetails unit) {
    final isOccupied = unit.status == 'occupied';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (isOccupied ? Colors.green : Colors.orange)
                  .withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              isOccupied ? Icons.check_circle : Icons.cancel,
              color: isOccupied ? Colors.green : Colors.orange,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Unit ${unit.unitNumber}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isOccupied ? Colors.green : Colors.orange)
                            .withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isOccupied ? 'Occupied' : 'Vacant',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color:
                          isOccupied ? Colors.green : Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 12,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        unit.tenant?.name ?? 'No tenant',
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
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _kes(unit.rentAmount),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Palette.nestBlue,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'per month',
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

  Future<void> _showOccupiedUnitsDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildLoadingDialog(
        'Loading occupied units...',
        Colors.green.shade600,
      ),
    );

    final units = await apiService.fetchPropertyUnits(widget.property.id);
    final occupiedUnits =
    units.where((u) => u.status == 'occupied').toList();

    if (!mounted) return;
    Navigator.of(context).pop();

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => _buildFilteredUnitsDialog(
        title: 'Occupied Units',
        subtitle: '${occupiedUnits.length} units currently occupied',
        units: occupiedUnits,
        headerColor: Colors.green.shade700,
        headerColor2: Colors.green.shade900,
        headerIcon: Icons.check_circle,
        statLabel: 'Occupied Units',
        statIcon: Icons.check_circle,
        statColor: Colors.green,
        showPaidStatus: true,
      ),
    );
  }

  Future<void> _showVacantUnitsDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildLoadingDialog(
        'Loading vacant units...',
        Colors.orange.shade600,
      ),
    );

    final units = await apiService.fetchPropertyUnits(widget.property.id);
    final vacantUnits = units.where((u) => u.status == 'vacant').toList();

    if (!mounted) return;
    Navigator.of(context).pop();

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => _buildFilteredUnitsDialog(
        title: 'Vacant Units',
        subtitle: '${vacantUnits.length} units currently vacant',
        units: vacantUnits,
        headerColor: Colors.orangeAccent.shade400,
        headerColor2: Colors.orangeAccent.shade700,
        headerIcon: Icons.door_front_door,
        statLabel: 'Vacant Units',
        statIcon: Icons.door_front_door,
        statColor: Colors.orange,
        showPaidStatus: true,
      ),
    );
  }

  Future<void> _showPaidUnitsDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildLoadingDialog(
        'Loading paid units...',
        Colors.cyan.shade600,
      ),
    );

    final units = await apiService.fetchPropertyUnits(widget.property.id);
    final paidUnits =
    units.where((u) => u.latestInvoice?.status == 'paid').toList();

    if (!mounted) return;
    Navigator.of(context).pop();

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => _buildFilteredUnitsDialog(
        title: 'Paid Units',
        subtitle: '${paidUnits.length} units with paid rent',
        units: paidUnits,
        headerColor: Colors.cyan.shade700,
        headerColor2: Colors.cyan.shade900,
        headerIcon: Icons.payments,
        statLabel: 'Paid Units',
        statIcon: Icons.payments,
        statColor: Colors.cyan,
        showPaidStatus: false,
        showServiceAndPayment: true,
      ),
    );
  }

  Future<void> _showUnpaidUnitsDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildLoadingDialog(
        'Loading unpaid units...',
        Colors.red.shade600,
      ),
    );

    final units = await apiService.fetchPropertyUnits(widget.property.id);
    final unpaidUnits =
    units.where((u) => u.latestInvoice?.status != 'paid').toList();

    if (!mounted) return;
    Navigator.of(context).pop();

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => _buildUnpaidUnitsDialog(unpaidUnits),
    );
  }

  Widget _buildLoadingDialog(String message, Color color) {
    return Center(
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
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilteredUnitsDialog({
    required String title,
    required String subtitle,
    required List<UnitsDetails> units,
    required Color headerColor,
    required Color headerColor2,
    required IconData headerIcon,
    required String statLabel,
    required IconData statIcon,
    required Color statColor,
    required bool showPaidStatus,
    bool showServiceAndPayment = false,
  }) {
    final totalRent = units.fold<num>(0, (sum, u) => sum + u.rentAmount);
    final totalCollected = units.fold<num>(0, (sum, u) {
      if (u.latestInvoice != null) return sum + u.latestInvoice!.amount;
      return sum;
    });

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: _isMobile ? 12 : 24,
        vertical: 24,
      ),
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
                  colors: [headerColor, headerColor2],
                ),
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(headerIcon,
                              color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                      statLabel,
                      units.length.toString(),
                      statIcon,
                      statColor,
                    ),
                    const SizedBox(width: 10),
                    _buildDialogStatCard(
                      'Total Rent',
                      _kes(totalRent),
                      Icons.money,
                      Colors.blue,
                    ),
                    if (showServiceAndPayment) ...[
                      const SizedBox(width: 10),
                      _buildDialogStatCard(
                        'Total Collected',
                        _kes(totalCollected),
                        Icons.account_balance,
                        Colors.green,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Expanded(
              child: units.isEmpty
                  ? _buildDialogEmptyState(
                icon: Icons.check_circle_outline,
                title: 'No units found',
              )
                  : ListView.builder(
                padding: EdgeInsets.all(_isMobile ? 12 : 16),
                itemCount: units.length,
                itemBuilder: (context, index) {
                  return _buildFilteredUnitCard(
                    units[index],
                    showPaidStatus: showPaidStatus,
                    showServiceAndPayment: showServiceAndPayment,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilteredUnitCard(
      UnitsDetails unit, {
        required bool showPaidStatus,
        required bool showServiceAndPayment,
      }) {
    final isPaid = unit.latestInvoice?.status == 'paid';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row - unit number + status badge
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Palette.nestBlue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.apartment_rounded,
                  size: 18,
                  color: Palette.nestBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unit ${unit.unitNumber}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      unit.tenant?.name ?? 'No tenant',
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
              if (showPaidStatus)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: (isPaid ? Colors.green : Colors.orange)
                        .withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (isPaid ? Colors.green : Colors.orange)
                          .withValues(alpha: 0.30),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPaid ? Icons.check_circle : Icons.pending,
                        size: 11,
                        color: isPaid ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isPaid ? 'Paid' : 'Unpaid',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isPaid ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),
          // Bottom row - amounts
          Row(
            children: [
              Expanded(
                child: _buildSmallInfo(
                  'RENT',
                  _kes(unit.rentAmount),
                  Colors.black87,
                ),
              ),
              if (showServiceAndPayment && unit.latestInvoice != null) ...[
                Expanded(
                  child: _buildSmallInfo(
                    'SERVICE',
                    _kes(unit.latestInvoice!.service),
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildSmallInfo(
                    'PAID',
                    _kes(unit.latestInvoice!.amount),
                    Colors.green,
                  ),
                ),
              ] else if (unit.latestInvoice != null &&
                  !showServiceAndPayment) ...[
                Expanded(
                  child: _buildSmallInfo(
                    'INVOICE',
                    unit.latestInvoice!.status == 'paid'
                        ? 'Settled'
                        : 'Pending',
                    isPaid ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallInfo(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildUnpaidUnitsDialog(List<UnitsDetails> unpaidUnits) {
    final totalOutstanding = unpaidUnits.fold<num>(0, (sum, u) {
      if (u.latestInvoice != null) return sum + u.latestInvoice!.amount;
      return sum + u.rentAmount;
    });

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: _isMobile ? 12 : 24,
        vertical: 24,
      ),
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
                  Expanded(
                    child: Row(
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
                        Expanded(
                          child: Column(
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
                                '${unpaidUnits.length} units with unpaid rent',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                      unpaidUnits.length.toString(),
                      Icons.pending_actions,
                      Colors.red,
                    ),
                    const SizedBox(width: 10),
                    _buildDialogStatCard(
                      'Total Outstanding',
                      _kes(totalOutstanding),
                      Icons.warning,
                      Colors.orange,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: unpaidUnits.isEmpty
                  ? _buildDialogEmptyState(
                icon: Icons.check_circle,
                title: 'No unpaid units!',
              )
                  : ListView.builder(
                padding: EdgeInsets.all(_isMobile ? 12 : 16),
                itemCount: unpaidUnits.length,
                itemBuilder: (context, index) {
                  return _buildUnpaidUnitCard(unpaidUnits[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnpaidUnitCard(UnitsDetails unit) {
    final hasInvoice = unit.latestInvoice != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.pending_actions,
                  size: 18,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unit ${unit.unitNumber}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      unit.tenant?.name ?? 'No tenant',
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
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildSmallInfo(
                  'RENT',
                  hasInvoice
                      ? _kes(unit.latestInvoice!.rent)
                      : _kes(unit.rentAmount),
                  Colors.red,
                ),
              ),
              Expanded(
                child: _buildSmallInfo(
                  'SERVICE',
                  hasInvoice
                      ? _kes(unit.latestInvoice!.service)
                      : 'Ksh 0',
                  Colors.red,
                ),
              ),
            ],
          ),
          if (!hasInvoice && unit.tenant != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  _showAdditionalCost(
                    unit.id,
                    unit.tenant!.id,
                    unit.tenant!.unitId.toString(),
                    unit.tenant!.email,
                    unit.tenant!.name,
                  );
                },
                icon: const Icon(Icons.add_circle_outline, size: 16),
                label: const Text(
                  'Create Invoice',
                  style: TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: BorderSide(
                    color: Colors.red.withValues(alpha: 0.3),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDialogEmptyState({
    required IconData icon,
    required String title,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      width: 130,
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

  // ═════════════════════════════════════════════════════════════
  // Add Tenant with validation + animated success toast
  // ═════════════════════════════════════════════════════════════
  void _showAddTenantDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final unitController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('New Tenant', style: TextStyle(fontSize: 16)),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                      labelText: 'Full Name',
                      labelStyle: TextStyle(fontSize: 13)),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter the tenant name'
                      : null,
                ),
                TextFormField(
                  keyboardType: TextInputType.number,
                  controller: phoneController,
                  decoration: const InputDecoration(
                      labelText: 'Mobile Number',
                      labelStyle: TextStyle(fontSize: 13)),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter the mobile number'
                      : null,
                ),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                      labelText: 'Email',
                      labelStyle: TextStyle(fontSize: 13)),
                ),
                TextFormField(
                  controller: unitController,
                  decoration: const InputDecoration(
                      labelText: 'House Number',
                      labelStyle: TextStyle(fontSize: 13)),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter the house number'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            child: const Text('Save'),
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;

              final tenantName = nameController.text.trim();
              final houseNo = unitController.text.trim();

              Navigator.pop(context);

              try {
                await apiService.createTenant(
                  propertyId: widget.property.id,
                  name: tenantName,
                  phone: phoneController.text,
                  email: emailController.text,
                  unitNo: houseNo,
                );

                if (!mounted) return;

                _showSuccessToast(
                  title: 'Tenant Added',
                  message:
                  '$tenantName was successfully assigned to unit $houseNo.',
                  color: const Color(0xFF4F46E5),
                );

                _reloadTenants();
              } catch (e) {
                if (!mounted) return;
                _showErrorToast(
                  title: 'Could not add tenant',
                  message: 'Something went wrong. Please try again.',
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // Add Unit with validation + animated success toast
  // ═════════════════════════════════════════════════════════════
  void _showAddUnitDialog() {
    final rentController = TextEditingController();
    final unitController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('New Unit', style: TextStyle(fontSize: 16)),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: unitController,
                  decoration: const InputDecoration(
                      labelText: 'House Number',
                      labelStyle: TextStyle(fontSize: 13)),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter the house number'
                      : null,
                ),
                TextFormField(
                  controller: rentController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Rent Amount (Ksh)',
                      labelStyle: TextStyle(fontSize: 13)),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Enter the rent amount';
                    }
                    if (int.tryParse(v.trim()) == null) {
                      return 'Enter a valid number';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            child: const Text('Save'),
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;

              final unitNo = unitController.text.trim();
              final rent = int.parse(rentController.text.trim());

              Navigator.pop(context);

              try {
                await apiService.createUnit(
                  id: widget.property.id,
                  unitNo: unitNo,
                  rent: rent,
                );

                if (!mounted) return;

                _showSuccessToast(
                  title: 'Unit Added',
                  message:
                  'Unit $unitNo was created with a monthly rent of ${_kes(rent)}.',
                  color: const Color(0xFF2563EB),
                );

                _reloadUnits();
              } catch (e) {
                if (!mounted) return;
                _showErrorToast(
                  title: 'Could not add unit',
                  message: 'Something went wrong. Please try again.',
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Future<ApiResponse> removeTenant(int tenantId) async {
    ApiResponse apiResponse = ApiResponse();

    try {
      final token = await getToken();

      final response = await http.delete(
        Uri.parse('$deleteTenant/$tenantId'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        apiResponse.data =
            decoded['message']?.toString() ?? 'Tenant deleted successfully';
      } else {
        apiResponse.error =
        'Failed to delete tenant (${response.statusCode})';
      }
    } catch (e) {
      apiResponse.error = 'Server error: ${e.toString()}';
    }

    return apiResponse;
  }

  Future<void> _handleDeleteTenant(int tenantId, String tenantName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tenant'),
        content: Text('Are you sure you want to delete $tenantName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final response = await removeTenant(tenantId);

      if (mounted) Navigator.pop(context);

      if (response.error == null) {
        if (mounted) {
          _showSuccessToast(
            title: 'Tenant Deleted',
            message: '$tenantName was removed from this property.',
            color: const Color(0xFF059669),
          );
          _reloadTenants();
        }
      } else {
        if (mounted) {
          _showErrorToast(
            title: 'Delete failed',
            message: response.error ?? 'Unable to delete tenant.',
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        _showErrorToast(
          title: 'Server error',
          message: 'An unexpected error occurred. Please try again.',
        );
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<PropertyDetails> fetchPropertyMetrics() async {
    return apiService.fetchPropertyDetails(widget.property.id);
  }

  Future<List<Payment>> fetchPropertyPaymentMetrics() async {
    try {
      final List<Payment> payments =
      await apiService.fetchRecentPayments(widget.property.id);
      return payments;
    } catch (e, stack) {
      return [];
    }
  }

  Future<List<TenantInfo>> fetchPropertyTenants() async {
    try {
      final List<TenantInfo> tenants =
      await apiService.fetchPropertyTenants(widget.property.id);
      return tenants;
    } catch (e, stack) {
      return [];
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Palette.nestBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Full page animated loader until initial data ready.
    if (_isInitialLoading) {
      return _PropertyDashboardLoader(
        propertyName: widget.property.name,
        messages: const [
          'Loading property details...',
          'Fetching units and tenants...',
          'Crunching payment history...',
          'Preparing your dashboard...',
        ],
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8FAFC),
              Color(0xFFF1F5F9),
            ],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: () async {
            _reloadAllData();

            await Future.wait([
              propertiesFuture,
              paymentsFuture,
              tenantsFuture,
              propertyRevenueFuture,
              unitsFuture,
            ]);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              _buildModernAppBar(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    _pagePadding,
                    _isMobile ? 14 : 20,
                    _pagePadding,
                    _isMobile ? 24 : 40,
                  ),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPropertyHero(),
                        SizedBox(height: _sectionSpacing),
                        _buildQuickActions(),
                        SizedBox(height: _sectionSpacing),
                        _buildSectionCard(
                          title: 'Property Overview',
                          subtitle:
                          'Monitor occupancy, units and payment performance',
                          icon: Icons.dashboard_outlined,
                          child: _buildKpiDashboard(),
                        ),
                        SizedBox(height: _sectionSpacing),
                        _buildPaymentsDashboard(),
                        SizedBox(height: _sectionSpacing),
                        _buildTenantsDashboard(),
                        SizedBox(height: _sectionSpacing),
                        _buildRevenueDashboard(),
                        SizedBox(height: _sectionSpacing),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recentPaymentsCard(List<Payment> payments) {
    if (payments.isEmpty) {
      return _buildEmptyState(
        icon: Icons.payments_outlined,
        title: 'No recent payments',
        subtitle: 'New payment activity will appear here.',
      );
    }

    return Column(
      children: List.generate(payments.length, (index) {
        final payment = payments[index];

        final tenantName =
        payment.tenantName.isNotEmpty ? payment.tenantName : '-';
        final houseNo = payment.houseNo.isNotEmpty ? payment.houseNo : '-';
        final amountPaid = payment.amountPaid ?? 0;
        final balance = payment.balance ?? 0;
        final date = payment.date ?? '-';

        return _buildMobilePaymentCard(
          tenantName: tenantName,
          houseNo: houseNo,
          amountPaid: amountPaid,
          balance: balance,
          date: date,
          index: index,
        );
      }),
    );
  }

  Widget _modernTenantsCard(List<TenantInfo> tenants) {
    if (tenants.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outline_rounded,
        title: 'No tenants found',
        subtitle: 'Add your first tenant to start managing this property.',
      );
    }

    return Column(
      children: List.generate(tenants.length, (index) {
        return _buildMobileTenantCard(
          tenant: tenants[index],
          index: index,
        );
      }),
    );
  }

  void showTenantInvoicesPopup(
      BuildContext context, int tenantId, String name) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: _isMobile ? 12 : 20,
          vertical: 24,
        ),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 600, maxWidth: 700),
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
                  future: apiService.fetchTenantInvoices(tenantId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
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
                              const SizedBox(height: 8),
                              Text(
                                snapshot.error.toString(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.grey.shade600),
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
                                    borderRadius:
                                    BorderRadius.circular(12),
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
                                  _showInvoiceDetailsDialog(
                                      context, invoice);
                                },
                                child: Container(
                                  margin:
                                  const EdgeInsets.only(bottom: 12),
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
                                    borderRadius:
                                    BorderRadius.circular(16),
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
                                      borderRadius:
                                      BorderRadius.circular(16),
                                      child: Padding(
                                        padding:
                                        const EdgeInsets.all(14),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding:
                                              const EdgeInsets.all(
                                                  10),
                                              decoration: BoxDecoration(
                                                color: isPaid
                                                    ? Colors
                                                    .green.shade100
                                                    : Colors.orange
                                                    .shade100,
                                                borderRadius:
                                                BorderRadius
                                                    .circular(12),
                                              ),
                                              child: Icon(
                                                Icons.apartment,
                                                color: isPaid
                                                    ? Colors
                                                    .green.shade700
                                                    : Colors.orange
                                                    .shade700,
                                                size: 18,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                CrossAxisAlignment
                                                    .start,
                                                children: [
                                                  Text(
                                                    'Unit ${invoice.unitNumber}',
                                                    style: TextStyle(
                                                      fontWeight:
                                                      FontWeight
                                                          .w600,
                                                      fontSize: 13,
                                                      color: Colors
                                                          .grey.shade800,
                                                    ),
                                                  ),
                                                  const SizedBox(
                                                      height: 4),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .calendar_today,
                                                        size: 12,
                                                        color: Colors
                                                            .grey.shade500,
                                                      ),
                                                      const SizedBox(
                                                          width: 4),
                                                      Text(
                                                        _formatDate(
                                                            invoice
                                                                .invoiceDate),
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors
                                                              .grey.shade600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment:
                                              CrossAxisAlignment
                                                  .end,
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
                                                        : Colors.orange
                                                        .shade700,
                                                  ),
                                                ),
                                                const SizedBox(
                                                    height: 6),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                                  decoration:
                                                  BoxDecoration(
                                                    color: isPaid
                                                        ? Colors.green
                                                        .shade50
                                                        : Colors.orange
                                                        .shade50,
                                                    borderRadius:
                                                    BorderRadius
                                                        .circular(20),
                                                    border: Border.all(
                                                      color: isPaid
                                                          ? Colors.green
                                                          .shade200
                                                          : Colors.orange
                                                          .shade200,
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
                                                            : Icons
                                                            .pending,
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
                                                          FontWeight
                                                              .w600,
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

  Widget buildRevenueChart(List<MonthlyRevenue>? revenueData) {
    if (revenueData == null || revenueData.isEmpty) {
      return Card(
        elevation: 2,
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No revenue data available',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return ResponsivePropertyRevenueChart(
      data: revenueData,
    );
  }

  SliverAppBar _buildModernAppBar() {
    return SliverAppBar(
      pinned: true,
      floating: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      expandedHeight: _isMobile ? 0 : null,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: IconButton(
          tooltip: 'Back',
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              size: 19,
              color: Color(0xFF334155),
            ),
          ),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.property.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w700,
              fontSize: _isMobile ? 15 : 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Property Dashboard',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFF64748B),
              fontSize: _isMobile ? 10 : 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Select date range',
          onPressed: _selectDateRange,
          icon: const Icon(
            Icons.date_range_outlined,
            color: Color(0xFF475569),
            size: 21,
          ),
        ),
        IconButton(
          tooltip: 'Refresh dashboard',
          onPressed: _reloadAllData,
          icon: const Icon(
            Icons.refresh_rounded,
            color: Color(0xFF475569),
            size: 21,
          ),
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  Widget _buildPropertyHero() {
    return FutureBuilder<PropertyDetails>(
      future: propertiesFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(_isMobile ? 18 : 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF312E81),
                Color(0xFF4F46E5),
                Color(0xFF2563EB),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.20),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: _isMobile ? 46 : 52,
                    height: _isMobile ? 46 : 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.20),
                      ),
                    ),
                    child: Icon(
                      Icons.apartment_rounded,
                      color: Colors.white,
                      size: _isMobile ? 22 : 26,
                    ),
                  ),
                  SizedBox(width: _isMobile ? 12 : 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.property.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: _isMobile ? 17 : 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Everything you need to monitor and manage your property.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: _isMobile ? 12 : 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (data != null) ...[
                SizedBox(height: _isMobile ? 16 : 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildHeroStat(
                      value: data.totalUnits.toString(),
                      label: 'Total Units',
                      icon: Icons.apartment_outlined,
                    ),
                    _buildHeroStat(
                      value: data.occupiedUnits.toString(),
                      label: 'Occupied',
                      icon: Icons.check_circle_outline,
                    ),
                    _buildHeroStat(
                      value: '${data.occupancyRate.toInt()}%',
                      label: 'Occupancy',
                      icon: Icons.pie_chart_outline,
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeroStat({
    required String value,
    required String label,
    required IconData icon,
  }) {
    return Container(
      width: _isMobile ? 100 : 130,
      padding: EdgeInsets.all(_isMobile ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.80),
            size: _isMobile ? 18 : 20,
          ),
          SizedBox(height: _isMobile ? 12 : 16),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: _isMobile ? 20 : 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: _isMobile ? 10 : 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildQuickAction(
          label: 'Add Tenant',
          icon: Icons.person_add_alt_1_rounded,
          color: const Color(0xFF4F46E5),
          onTap: _showAddTenantDialog,
        ),
        _buildQuickAction(
          label: 'Add Unit',
          icon: Icons.add_home_work_outlined,
          color: const Color(0xFF2563EB),
          onTap: _showAddUnitDialog,
        ),
        _buildQuickAction(
          label: 'View Units',
          icon: Icons.apartment_outlined,
          color: const Color(0xFF0891B2),
          onTap: _showUnitsDialog,
        ),
        _buildQuickAction(
          label: 'Generate Invoices',
          icon: Icons.auto_awesome_rounded,
          color: const Color(0xFF059669),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GenerateMonthlyInvoicesPage(
                  property: widget.property,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickAction({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: _isMobile ? 12 : 16,
            vertical: _isMobile ? 10 : 12,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: _isMobile ? 32 : 36,
                height: _isMobile ? 32 : 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: _isMobile ? 17 : 19,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: _isMobile ? 12 : 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiDashboard() {
    return FutureBuilder<PropertyDetails>(
      future: propertiesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildKpiSkeleton();
        }

        if (snapshot.hasError) {
          return _buildErrorState(
            message: 'Unable to load property metrics',
            onRetry: _reloadAllData,
          );
        }

        final data = snapshot.data;

        if (data == null) {
          return _buildEmptyState(
            icon: Icons.analytics_outlined,
            title: 'No property data available',
            subtitle: 'Property metrics will appear here.',
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount;
            double childAspectRatio;

            if (constraints.maxWidth >= 900) {
              crossAxisCount = 6;
              childAspectRatio = 1.2;
            } else if (constraints.maxWidth >= 600) {
              crossAxisCount = 3;
              childAspectRatio = 1.45;
            } else if (constraints.maxWidth >= 400) {
              crossAxisCount = 2;
              childAspectRatio = 1.4;
            } else {
              crossAxisCount = 2;
              childAspectRatio = 1.25;
            }

            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: childAspectRatio,
              children: [
                _modernKpiCard(
                  title: 'Total Units',
                  value: data.totalUnits.toString(),
                  icon: Icons.apartment_outlined,
                  color: const Color(0xFF2563EB),
                  onTap: _showUnitsDialog,
                ),
                _modernKpiCard(
                  title: 'Occupied',
                  value: data.occupiedUnits.toString(),
                  icon: Icons.check_circle_outline,
                  color: const Color(0xFF10B981),
                  onTap: _showOccupiedUnitsDialog,
                ),
                _modernKpiCard(
                  title: 'Vacant',
                  value: data.vacantUnits.toString(),
                  icon: Icons.door_front_door_outlined,
                  color: const Color(0xFFF59E0B),
                  onTap: _showVacantUnitsDialog,
                ),
                _modernKpiCard(
                  title: 'Occupancy',
                  value: '${data.occupancyRate.toInt()}%',
                  icon: Icons.pie_chart_outline,
                  color: const Color(0xFF8B5CF6),
                  onTap: _showUnitsDialog,
                ),
                _modernKpiCard(
                  title: 'Paid',
                  value: data.paidUnits.toString(),
                  icon: Icons.payments_outlined,
                  color: const Color(0xFF06B6D4),
                  onTap: _showPaidUnitsDialog,
                ),
                _modernKpiCard(
                  title: 'Unpaid',
                  value: data.unpaidUnits.toString(),
                  icon: Icons.pending_actions_outlined,
                  color: const Color(0xFFEF4444),
                  onTap: _showUnpaidUnitsDialog,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _modernKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: EdgeInsets.all(_isMobile ? 12 : 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE8EDF3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.025),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: _isMobile ? 32 : 36,
                    height: _isMobile ? 32 : 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: _isMobile ? 16 : 18,
                    ),
                  ),
                  Icon(
                    Icons.arrow_outward_rounded,
                    size: 14,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: _isMobile ? 18 : 22,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: _isMobile ? 10 : 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
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

  Widget _buildRevenueDashboard() {
    return _buildSectionCard(
      title: 'Revenue Analytics',
      subtitle: 'Track your property revenue performance',
      icon: Icons.trending_up_rounded,
      child: FutureBuilder<List<MonthlyRevenue>>(
        future: propertyRevenueFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return SizedBox(
              height: 280,
              child: _buildChartSkeleton(),
            );
          }

          if (snapshot.hasError) {
            return SizedBox(
              height: 280,
              child: _buildErrorState(
                message: 'Unable to load revenue analytics',
                onRetry: _reloadAllData,
              ),
            );
          }

          final revenueData = snapshot.data ?? [];

          if (revenueData.isEmpty) {
            return SizedBox(
              height: 280,
              child: _buildEmptyState(
                icon: Icons.bar_chart_outlined,
                title: 'No revenue data',
                subtitle: 'Revenue analytics will appear here.',
              ),
            );
          }

          return buildRevenueChart(revenueData);
        },
      ),
    );
  }

  Widget _buildTenantsDashboard() {
    return _buildSectionCard(
      title: 'Tenants',
      subtitle: 'Manage tenants and property occupancy',
      icon: Icons.people_outline_rounded,
      trailing: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _compactActionButton(
            label: 'Add Unit',
            icon: Icons.add_home_work_outlined,
            onTap: _showAddUnitDialog,
          ),
          _compactActionButton(
            label: 'Add Tenant',
            icon: Icons.person_add_alt_1_rounded,
            isPrimary: true,
            onTap: _showAddTenantDialog,
          ),
        ],
      ),
      child: FutureBuilder<List<TenantInfo>>(
        future: tenantsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildListSkeleton();
          }

          if (snapshot.hasError) {
            return _buildErrorState(
              message: 'Unable to load tenant information',
              onRetry: _reloadTenants,
            );
          }

          final tenants = snapshot.data ?? [];

          if (tenants.isEmpty) {
            return _buildEmptyState(
              icon: Icons.people_outline,
              title: 'No tenants found',
              subtitle: 'Add your first tenant to get started.',
            );
          }

          return _modernTenantsCard(tenants);
        },
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(_isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE8EDF3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 500;

              if (isSmall) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSectionTitle(
                      title,
                      subtitle,
                      icon,
                    ),
                    if (trailing != null) ...[
                      const SizedBox(height: 14),
                      trailing,
                    ],
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: _buildSectionTitle(
                      title,
                      subtitle,
                      icon,
                    ),
                  ),
                  if (trailing != null) trailing,
                ],
              );
            },
          ),
          SizedBox(height: _isMobile ? 16 : 20),
          child,
        ],
      ),
    );
  }

  Widget _buildSectionTitle(
      String title,
      String subtitle,
      IconData icon,
      ) {
    return Row(
      children: [
        Container(
          width: _isMobile ? 40 : 46,
          height: _isMobile ? 40 : 46,
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF4F46E5),
            size: _isMobile ? 19 : 22,
          ),
        ),
        SizedBox(width: _isMobile ? 10 : 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: _isMobile ? 15 : 17,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: _isMobile ? 11 : 12,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _compactActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(
        icon,
        size: 16,
      ),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor:
        isPrimary ? const Color(0xFF4F46E5) : const Color(0xFFF1F5F9),
        foregroundColor:
        isPrimary ? Colors.white : const Color(0xFF334155),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Animated shimmer skeletons
  // ─────────────────────────────────────────────────────────────

  Widget _buildKpiSkeleton() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth > 600 ? 3 : 2;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: count,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: count == 3 ? 1.45 : 1.4,
          children: List.generate(
            6,
                (_) => const _ShimmerBox(height: null, radius: 18),
          ),
        );
      },
    );
  }

  Widget _buildListSkeleton() {
    return Column(
      children: List.generate(
        4,
            (index) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              const _ShimmerBox(height: 46, width: 46, radius: 13),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: const [
                    _ShimmerBox(height: 14, radius: 6),
                    SizedBox(height: 8),
                    _ShimmerBox(height: 10, radius: 6),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartSkeleton() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              7,
                  (index) {
                final heights = [
                  90.0,
                  140.0,
                  110.0,
                  180.0,
                  130.0,
                  200.0,
                  160.0,
                ];

                return _ShimmerBox(
                  width: 20,
                  height: heights[index],
                  radius: 8,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: _isMobile ? 30 : 40,
        horizontal: 20,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                icon,
                size: 30,
                color: const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState({
    required String message,
    required VoidCallback onRetry,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: _isMobile ? 28 : 35,
        horizontal: 20,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFEF4444),
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again',
                  style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4F46E5),
                side: const BorderSide(
                  color: Color(0xFFC7D2FE),
                ),
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
      ),
    );
  }

  Widget _buildMobilePaymentCard({
    required String tenantName,
    required String houseNo,
    required num amountPaid,
    required num balance,
    required String date,
    required int index,
  }) {
    final hasBalance = balance > 0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(
        milliseconds: 250 + (index * 60),
      ),
      curve: Curves.easeOutCubic,
      builder: (context, animation, child) {
        return Opacity(
          opacity: animation,
          child: Transform.translate(
            offset: Offset(0, 15 * (1 - animation)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFE8EDF3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                _buildAvatar(
                  name: tenantName,
                  color: const Color(0xFF10B981),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tenantName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.home_outlined,
                            size: 13,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Unit $houseNo',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildBalanceBadge(
                  balance,
                  hasBalance,
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildPaymentInfo(
                    label: 'AMOUNT PAID',
                    value: _kes(amountPaid),
                    valueColor: const Color(0xFF059669),
                  ),
                ),
                Expanded(
                  child: _buildPaymentInfo(
                    label: 'DATE',
                    value: date,
                    valueColor: const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileTenantCard({
    required TenantInfo tenant,
    required int index,
  }) {
    final tenantName = tenant.name.isNotEmpty ? tenant.name : '-';
    final houseNo = tenant.unitNumber.isNotEmpty ? tenant.unitNumber : '-';
    final status = tenant.status.toLowerCase();
    final isActive = status == 'occupied' || status == 'active';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(
        milliseconds: 250 + (index * 60),
      ),
      curve: Curves.easeOutCubic,
      builder: (context, animation, child) {
        return Opacity(
          opacity: animation,
          child: Transform.translate(
            offset: Offset(0, 15 * (1 - animation)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFE8EDF3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                _buildAvatar(
                  name: tenantName,
                  color: const Color(0xFF6366F1),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tenantName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(
                            Icons.home_outlined,
                            size: 13,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              'Unit $houseNo',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(
                  status,
                  isActive,
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: Color(0xFFF1F5F9)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildTenantActionButton(
                    label: 'Invoice',
                    icon: Icons.description_outlined,
                    color: const Color(0xFF2563EB),
                    onTap: () {
                      _showAdditionalCost(
                        tenant.unitId,
                        tenant.tenantId,
                        tenant.unitNumber,
                        tenant.email,
                        tenantName,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTenantActionButton(
                    label: 'Receipt',
                    icon: Icons.receipt_long_outlined,
                    color: const Color(0xFF059669),
                    onTap: () {
                      showTenantInvoicesPopup(
                        context,
                        tenant.tenantId,
                        tenant.name,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                _buildActionIcon(
                  tooltip: 'Delete tenant',
                  icon: Icons.delete_outline_rounded,
                  color: const Color(0xFFEF4444),
                  onTap: () {
                    _handleDeleteTenant(
                      tenant.tenantId,
                      tenantName,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentInfo({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
            color: Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

final NumberFormat _kesFormatter = NumberFormat.currency(
  locale: 'en_KE',
  symbol: 'Ksh ',
  decimalDigits: 0,
);

String _kes(num amount) => _kesFormatter.format(amount);

class _TableHeader extends StatelessWidget {
  final String text;

  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.7,
        color: Color(0xFF94A3B8),
      ),
    );
  }
}

Widget _buildAvatar({
  required String name,
  required Color color,
}) {
  final initial =
  name.isNotEmpty && name != '-' ? name[0].toUpperCase() : '?';

  return Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(
        color: color.withValues(alpha: 0.15),
      ),
    ),
    alignment: Alignment.center,
    child: Text(
      initial,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w800,
        fontSize: 16,
      ),
    ),
  );
}

Widget _buildBalanceBadge(
    num balance,
    bool hasBalance,
    ) {
  final color =
  hasBalance ? const Color(0xFFDC2626) : const Color(0xFF059669);
  final label = hasBalance ? _kes(balance) : 'Cleared';

  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 10,
      vertical: 6,
    ),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

Widget _buildStatusBadge(
    String status,
    bool isActive,
    ) {
  final color =
  isActive ? const Color(0xFF059669) : const Color(0xFFF59E0B);
  final icon =
  isActive ? Icons.check_circle_outline : Icons.pending_outlined;
  final label = status.isEmpty
      ? 'Unknown'
      : status[0].toUpperCase() + status.substring(1);

  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 9,
      vertical: 6,
    ),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 12,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

Widget _buildActionIcon({
  required String tooltip,
  required IconData icon,
  required Color color,
  required VoidCallback onTap,
}) {
  return Tooltip(
    message: tooltip,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: color,
            size: 18,
          ),
        ),
      ),
    ),
  );
}

Widget _buildTenantActionButton({
  required String label,
  required IconData icon,
  required Color color,
  required VoidCallback onTap,
}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: color,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════
// Animated shimmer skeleton box used by all loading placeholders.
// ═══════════════════════════════════════════════════════════════
class _ShimmerBox extends StatefulWidget {
  const _ShimmerBox({
    this.width,
    this.height,
    this.radius = 8,
  });

  final double? width;
  final double? height;
  final double radius;

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final t = _animation.value;
        final base = Color.lerp(
          const Color(0xFFE2E8F0),
          const Color(0xFFF1F5F9),
          t,
        )!;
        final highlight = Color.lerp(
          const Color(0xFFF1F5F9),
          const Color(0xFFE2E8F0),
          t,
        )!;

        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [base, highlight, base],
              stops: const [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Full page animated loading screen for the property page.
// ═══════════════════════════════════════════════════════════════
class _PropertyDashboardLoader extends StatefulWidget {
  const _PropertyDashboardLoader({
    required this.propertyName,
    this.messages = const ['Loading property...'],
  });

  final String propertyName;
  final List<String> messages;

  @override
  State<_PropertyDashboardLoader> createState() =>
      _PropertyDashboardLoaderState();
}

class _PropertyDashboardLoaderState extends State<_PropertyDashboardLoader>
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
      duration: const Duration(seconds: 12),
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
    const indigo = Color(0xFF4F46E5);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8FAFC),
              Color(0xFFF1F5F9),
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: _entrance,
              curve: Curves.easeOut,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildOrbit(indigo),
                const SizedBox(height: 32),
                _buildWordmark(indigo),
                const SizedBox(height: 12),
                _buildMessage(),
                const SizedBox(height: 22),
                _buildProgressBar(indigo),
                const SizedBox(height: 16),
                _buildDots(indigo),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrbit(Color accent) {
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
                      border: Border.all(color: accent, width: 1.6),
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
              painter: _PropertyLoaderDotsPainter(color: accent),
            ),
          ),
          RotationTransition(
            turns: _spin,
            child: CustomPaint(
              size: const Size(115, 115),
              painter: _PropertyLoaderArcPainter(color: accent),
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
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF4F46E5),
                    Color(0xFF312E81),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.35),
                    blurRadius: 22,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.apartment_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordmark(Color accent) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            widget.propertyName.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'PROPERTY DASHBOARD',
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
            color: Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(Color accent) {
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
              backgroundColor: accent.withValues(alpha: 0.10),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDots(Color accent) {
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
                color: accent.withValues(alpha: opacity),
              ),
            );
          }),
        );
      },
    );
  }
}

// ── Sweeping gradient arc ──────────────────────────────────────
class _PropertyLoaderArcPainter extends CustomPainter {
  const _PropertyLoaderArcPainter({required this.color});

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
  bool shouldRepaint(covariant _PropertyLoaderArcPainter oldDelegate) =>
      oldDelegate.color != color;
}

// ── Fading dotted ring ─────────────────────────────────────────
class _PropertyLoaderDotsPainter extends CustomPainter {
  const _PropertyLoaderDotsPainter({
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
  bool shouldRepaint(covariant _PropertyLoaderDotsPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.dotCount != dotCount;
}

// ═══════════════════════════════════════════════════════════════
// Animated top-of-screen notification with a drawn check / cross,
// elastic entrance, auto-dismiss life bar and tap-to-dismiss.
// ═══════════════════════════════════════════════════════════════
class _AnimatedNotificationOverlay extends StatefulWidget {
  const _AnimatedNotificationOverlay({
    required this.title,
    required this.message,
    required this.color,
    required this.onDismiss,
    this.isError = false,
  });

  final String title;
  final String message;
  final Color color;
  final VoidCallback onDismiss;
  final bool isError;

  @override
  State<_AnimatedNotificationOverlay> createState() =>
      _AnimatedNotificationOverlayState();
}

class _AnimatedNotificationOverlayState
    extends State<_AnimatedNotificationOverlay> with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _exit;
  late final AnimationController _glyph;
  late final AnimationController _life;

  bool _dismissing = false;

  @override
  void initState() {
    super.initState();

    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _exit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _glyph = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _life = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _enter.forward();
    _life.forward();

    Future<void>.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _glyph.forward();
    });

    _runAutoDismiss();
  }

  Future<void> _runAutoDismiss() async {
    await Future<void>.delayed(const Duration(milliseconds: 2800));
    if (!mounted) return;
    await _dismiss();
  }

  Future<void> _dismiss() async {
    if (_dismissing) return;
    _dismissing = true;

    if (!mounted) {
      widget.onDismiss();
      return;
    }

    await _exit.forward();
    if (!mounted) {
      widget.onDismiss();
      return;
    }
    widget.onDismiss();
  }

  @override
  void dispose() {
    _enter.dispose();
    _exit.dispose();
    _glyph.dispose();
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topInset + 12,
      left: 12,
      right: 12,
      child: Align(
        alignment: Alignment.topCenter,
        child: AnimatedBuilder(
          animation: Listenable.merge([_enter, _exit]),
          builder: (context, child) {
            final enterValue = _enter.value.clamp(0.0, 1.0);
            final exitValue = Curves.easeInCubic.transform(_exit.value);

            final enterScale = Curves.easeOutBack.transform(enterValue);
            final scale =
                (0.86 + 0.14 * enterScale) * (1 - 0.06 * exitValue);

            final opacity = (enterValue * (1 - exitValue)).clamp(0.0, 1.0);

            final slide =
                (1 - Curves.easeOutCubic.transform(enterValue)) * -34 +
                    exitValue * -26;

            return Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(0, slide),
                child: Transform.scale(
                  scale: scale,
                  child: child,
                ),
              ),
            );
          },
          child: _buildCard(),
        ),
      ),
    );
  }

  Widget _buildCard() {
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.color.withValues(alpha: 0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.20),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                  child: Row(
                    children: [
                      _buildBadge(),
                      const SizedBox(width: 12),
                      Expanded(child: _buildTexts()),
                      _buildCloseButton(),
                    ],
                  ),
                ),
                _buildLifeBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge() {
    return AnimatedBuilder(
      animation: _enter,
      builder: (context, child) {
        final t = Curves.easeOutBack.transform(
          _enter.value.clamp(0.0, 1.0),
        );
        return Transform.scale(
          scale: 0.7 + (0.3 * t),
          child: child,
        );
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              widget.color,
              Color.lerp(widget.color, Colors.black, 0.28)!,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _glyph,
            builder: (context, _) {
              return CustomPaint(
                size: const Size(24, 24),
                painter: _NotificationGlyphPainter(
                  progress: Curves.easeOutCubic
                      .transform(_glyph.value.clamp(0.0, 1.0)),
                  color: Colors.white,
                  isError: widget.isError,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTexts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          widget.message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11.5,
            height: 1.35,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildCloseButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _dismiss,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.close_rounded,
            size: 16,
            color: Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }

  Widget _buildLifeBar() {
    return AnimatedBuilder(
      animation: _life,
      builder: (context, _) {
        final value = (1 - _life.value).clamp(0.0, 1.0);

        return SizedBox(
          height: 3,
          child: LinearProgressIndicator(
            value: value,
            minHeight: 3,
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation<Color>(
              widget.color.withValues(alpha: 0.75),
            ),
          ),
        );
      },
    );
  }
}

// ── Drawn check / cross glyph ──────────────────────────────────
class _NotificationGlyphPainter extends CustomPainter {
  const _NotificationGlyphPainter({
    required this.progress,
    required this.color,
    required this.isError,
  });

  final double progress;
  final Color color;
  final bool isError;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (isError) {
      final first = Path()
        ..moveTo(size.width * 0.28, size.height * 0.28)
        ..lineTo(size.width * 0.72, size.height * 0.72);
      final second = Path()
        ..moveTo(size.width * 0.72, size.height * 0.28)
        ..lineTo(size.width * 0.28, size.height * 0.72);

      _drawPartial(
        canvas,
        first,
        (progress * 2).clamp(0.0, 1.0),
        paint,
      );
      _drawPartial(
        canvas,
        second,
        ((progress - 0.5) * 2).clamp(0.0, 1.0),
        paint,
      );
    } else {
      final path = Path()
        ..moveTo(size.width * 0.24, size.height * 0.52)
        ..lineTo(size.width * 0.43, size.height * 0.72)
        ..lineTo(size.width * 0.78, size.height * 0.30);

      _drawPartial(canvas, path, progress.clamp(0.0, 1.0), paint);
    }
  }

  void _drawPartial(
      Canvas canvas,
      Path path,
      double t,
      Paint paint,
      ) {
    if (t <= 0) return;
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(
        metric.extractPath(0, metric.length * t),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NotificationGlyphPainter old) =>
      old.progress != progress ||
          old.color != color ||
          old.isError != isError;
}