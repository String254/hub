import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hub/config/config.dart';
import 'package:hub/models/models.dart';
import 'package:hub/services/services.dart';
import 'package:hub/pages/pages.dart';
import 'package:intl/intl.dart';

class GenerateMonthlyInvoicesPage extends StatefulWidget {
  final Nest property;

  const GenerateMonthlyInvoicesPage({
    super.key,
    required this.property,
  });

  @override
  State<GenerateMonthlyInvoicesPage> createState() =>
      _GenerateMonthlyInvoicesPageState();
}

class _GenerateMonthlyInvoicesPageState
    extends State<GenerateMonthlyInvoicesPage> {
  late ApiPropertyService apiService;

  Future<List<UnitsDetails>>? _unitsFuture;

  final TextEditingController _searchController = TextEditingController();

  final Map<int, TextEditingController> _waterControllers = {};
  final Map<int, TextEditingController> _serviceControllers = {};

  final Map<int, double> _waterValues = {};
  final Map<int, double> _serviceValues = {};

  /// Currently selected unit IDs (only these will be invoiced).
  final Set<int> _selectedUnitIds = {};
  bool _selectionInitialized = false;

  String _searchQuery = '';

  /// The date the invoice is issued. Used for the `invoice_date` field sent to
  /// Laravel and as the lower bound for the due-date picker.
  DateTime _invoiceDate = DateTime.now();

  /// The date payment is due. The invoice *period* is derived from this month.
  DateTime _dueDate = DateTime(
    DateTime.now().year,
    DateTime.now().month + 1,
    5,
  );

  bool _isGenerating = false;
  bool _isSavingDraft = false;

  String _generationStage = 'Preparing invoices...';
  int _generationStep = 0;

  StateSetter? _generationDialogSetState;

  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'en_KE',
    symbol: 'Ksh ',
    decimalDigits: 0,
  );

  static const List<String> _generationStages = [
    'Preparing invoices...',
    'Generating invoice PDFs...',
    'Sending invoices to tenants...',
    'Finalizing invoice run...',
  ];

  @override
  void initState() {
    super.initState();

    apiService = ApiPropertyService(
      baseUrl: baseUrl,
    );

    _loadUnits();

    _searchController.addListener(() {
      if (!mounted) return;

      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  // ---------------------------------------------------------------------------
  // Load units and auto-select all occupied ones on first load.
  // ---------------------------------------------------------------------------
  void _loadUnits() {
    _unitsFuture = apiService.fetchPropertyUnits(widget.property.id).then(
          (units) {
        if (!_selectionInitialized) {
          final occupied = units.where((u) {
            return u.status.toLowerCase() == 'occupied' && u.tenant != null;
          });
          _selectedUnitIds.addAll(occupied.map((u) => u.id));
          _selectionInitialized = true;
        }
        return units;
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();

    for (final controller in _waterControllers.values) {
      controller.dispose();
    }

    for (final controller in _serviceControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  // ===========================================================================
  // FORMATTING
  // ===========================================================================

  String _formatCurrency(num amount) {
    return _currencyFormatter.format(amount);
  }

  /// Invoice period label — derived from the due date's month.
  String _invoicePeriod() {
    return DateFormat('MMM yyyy').format(_dueDate);
  }

  /// Long-form invoice period — derived from the due date's month.
  String _invoicePeriodLong() {
    return DateFormat('MMMM yyyy').format(_dueDate);
  }

  // ===========================================================================
  // UNIT FILTERING / SELECTION
  // ===========================================================================

  List<UnitsDetails> _getOccupiedUnits(List<UnitsDetails> units) {
    return units.where((unit) {
      return unit.status.toLowerCase() == 'occupied' && unit.tenant != null;
    }).toList();
  }

  List<UnitsDetails> _getFilteredUnits(List<UnitsDetails> units) {
    final occupiedUnits = _getOccupiedUnits(units);

    if (_searchQuery.isEmpty) {
      return occupiedUnits;
    }

    return occupiedUnits.where((unit) {
      final unitNumber = unit.unitNumber.toLowerCase();
      final tenantName = unit.tenant?.name.toLowerCase() ?? '';
      final tenantEmail = unit.tenant?.email.toLowerCase() ?? '';

      return unitNumber.contains(_searchQuery) ||
          tenantName.contains(_searchQuery) ||
          tenantEmail.contains(_searchQuery);
    }).toList();
  }

  List<UnitsDetails> _getSelectedUnits(List<UnitsDetails> units) {
    return units.where((u) => _selectedUnitIds.contains(u.id)).toList();
  }

  bool _isUnitSelected(int unitId) => _selectedUnitIds.contains(unitId);

  void _toggleUnitSelection(int unitId) {
    if (_isGenerating) return;

    setState(() {
      if (_selectedUnitIds.contains(unitId)) {
        _selectedUnitIds.remove(unitId);
      } else {
        _selectedUnitIds.add(unitId);
      }
    });
  }

  bool _isAllSelected(List<UnitsDetails> units) {
    if (units.isEmpty) return false;
    return units.every((u) => _selectedUnitIds.contains(u.id));
  }

  bool _isAnySelected(List<UnitsDetails> units) {
    return units.any((u) => _selectedUnitIds.contains(u.id));
  }

  /// Toggle selection for the units currently shown (respects the search filter).
  void _toggleSelectAll(List<UnitsDetails> units) {
    if (_isGenerating) return;

    setState(() {
      final allSelected = _isAllSelected(units);
      if (allSelected) {
        _selectedUnitIds.removeAll(units.map((u) => u.id));
      } else {
        _selectedUnitIds.addAll(units.map((u) => u.id));
      }
    });
  }

  // ===========================================================================
  // CONTROLLERS
  // ===========================================================================

  TextEditingController _getWaterController(int unitId) {
    if (!_waterControllers.containsKey(unitId)) {
      _waterControllers[unitId] = TextEditingController(text: '0');
    }

    return _waterControllers[unitId]!;
  }

  double _getWater(int unitId) {
    final controller = _getWaterController(unitId);
    return double.tryParse(controller.text) ?? 0.0;
  }

  TextEditingController _getServiceController(int unitId) {
    if (!_serviceControllers.containsKey(unitId)) {
      _serviceControllers[unitId] = TextEditingController(text: '0');
    }

    return _serviceControllers[unitId]!;
  }

  double _getServiceCost(int unitId) {
    final controller = _getServiceController(unitId);
    return double.tryParse(controller.text) ?? 0.0;
  }

  /// Water Bill + Service Cost = ONE Service Charge.
  double _getServiceCharge(int unitId) {
    return _getWater(unitId) + _getServiceCost(unitId);
  }

  /// Final invoice amount: Rent + Service Charge.
  double _getTotal(UnitsDetails unit) {
    return unit.rentAmount.toDouble() + _getServiceCharge(unit.id);
  }

  double _getTotalRent(List<UnitsDetails> units) {
    return units.fold<double>(0, (sum, unit) => sum + unit.rentAmount.toDouble());
  }

  double _getTotalWater(List<UnitsDetails> units) {
    return units.fold<double>(0, (sum, unit) => sum + _getWater(unit.id));
  }

  double _getTotalServiceCost(List<UnitsDetails> units) {
    return units.fold<double>(0, (sum, unit) => sum + _getServiceCost(unit.id));
  }

  /// Total Service Charge = Water + Service Cost.
  double _getTotalServiceCharges(List<UnitsDetails> units) {
    return units.fold<double>(0, (sum, unit) => sum + _getServiceCharge(unit.id));
  }

  /// Total amount appearing on invoices.
  double _getGrandTotal(List<UnitsDetails> units) {
    return units.fold<double>(0, (sum, unit) => sum + _getTotal(unit));
  }

  int _getCompletedEntries(List<UnitsDetails> units) {
    return units.where((unit) {
      return _getWater(unit.id) > 0 || _getServiceCost(unit.id) > 0;
    }).length;
  }

  // ===========================================================================
  // INVOICE PAYLOAD
  // ===========================================================================

  List<Map<String, dynamic>> _buildInvoicePayload(List<UnitsDetails> units) {
    return units.map((unit) {
      final tenant = unit.tenant;

      final water = _getWater(unit.id);
      final serviceCost = _getServiceCost(unit.id);

      // Combined service charge.
      final serviceCharge = water + serviceCost;

      final rent = unit.rentAmount.toDouble();

      final total = rent + serviceCharge;

      return {
        'tenant_id': tenant?.id,
        'unit_id': unit.id,
        'unit_number': unit.unitNumber,
        'tenant_name': tenant?.name,
        'tenant_email': tenant?.email,

        'rent': rent,
        'service': serviceCharge,

        'water_bill': water,
        'service_cost': serviceCost,

        'amount': total,

        'invoice_date': DateFormat('yyyy-MM-dd').format(_invoiceDate),
        'due_date': DateFormat('yyyy-MM-dd').format(_invoiceDate),

        // Invoice period is the due date's month.
        'invoice_period': _invoicePeriod(),
      };
    }).toList();
  }

  // ===========================================================================
  // DATE SELECTION
  // ===========================================================================

  Future<void> _selectDueDate() async {
    if (_isGenerating) return;

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _dueDate.isBefore(_invoiceDate) ? _invoiceDate : _dueDate,
      firstDate: _invoiceDate,
      lastDate: DateTime(2100),
    );

    if (selectedDate != null && mounted) {
      setState(() {
        _dueDate = selectedDate;
      });
    }
  }

  // ===========================================================================
  // RESET
  // ===========================================================================

  void _clearAllCharges(List<UnitsDetails> units) {
    if (_isGenerating) return;

    for (final unit in units) {
      _waterControllers[unit.id]?.text = '0';
      _serviceControllers[unit.id]?.text = '0';
    }

    setState(() {
      _waterValues.clear();
      _serviceValues.clear();
    });
  }

  Future<void> _showClearConfirmation(List<UnitsDetails> units) async {
    if (_isGenerating) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.restart_alt_rounded, color: Colors.orange),
              SizedBox(width: 10),
              Text('Clear Charges'),
            ],
          ),
          content: const Text(
            'This will reset all water bills and service costs to zero.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Clear All'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      _clearAllCharges(units);
    }
  }

  // ===========================================================================
  // VALIDATION
  // ===========================================================================

  bool _validateInvoices(List<UnitsDetails> units) {
    if (units.isEmpty) {
      _showMessage(
        'Please select at least one tenant to invoice.',
        isError: true,
      );
      return false;
    }

    for (final unit in units) {
      if (unit.tenant == null) {
        _showMessage(
          'Unit ${unit.unitNumber} does not have a tenant assigned.',
          isError: true,
        );
        return false;
      }

      if (unit.tenant!.email.trim().isEmpty) {
        _showMessage(
          '${unit.tenant!.name} does not have an email address.',
          isError: true,
        );
        return false;
      }
    }

    return true;
  }

  // ===========================================================================
  // MESSAGES
  // ===========================================================================

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // GENERATE CONFIRMATION
  // ===========================================================================

  Future<void> _showGenerateConfirmation(List<UnitsDetails> selectedUnits) async {
    if (_isGenerating || _isSavingDraft) {
      return;
    }

    if (!_validateInvoices(selectedUnits)) {
      return;
    }

    final grandTotal = _getGrandTotal(selectedUnits);
    final serviceCharges = _getTotalServiceCharges(selectedUnits);

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          titlePadding: EdgeInsets.zero,
          contentPadding: EdgeInsets.zero,
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.shade700,
                        Colors.blue.shade900,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 25,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Generate & Send Invoices',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Invoices will be generated and emailed to the selected tenants.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildConfirmationRow(
                        icon: Icons.receipt_long_outlined,
                        label: 'Invoices',
                        value: '${selectedUnits.length}',
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 14),
                      _buildConfirmationRow(
                        icon: Icons.calendar_month_outlined,
                        label: 'Invoice Period',
                        // Period is now derived from the due date's month.
                        value: _invoicePeriodLong(),
                        color: Colors.purple,
                      ),
                      const SizedBox(height: 14),
                      _buildConfirmationRow(
                        icon: Icons.event_available_outlined,
                        label: 'Due Date',
                        value: DateFormat('dd MMM yyyy').format(_dueDate),
                        color: Colors.orange,
                      ),
                      const SizedBox(height: 14),
                      _buildConfirmationRow(
                        icon: Icons.water_drop_outlined,
                        label: 'Service Charges',
                        value: _formatCurrency(serviceCharges),
                        color: Colors.orange,
                      ),
                      const SizedBox(height: 14),
                      _buildConfirmationRow(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Total Invoiced',
                        value: _formatCurrency(grandTotal),
                        color: Colors.green,
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Water bills and service costs will be combined into one Service Charge on each invoice.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.email_outlined,
                              color: Colors.green.shade700,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Each generated invoice will be automatically emailed to the tenant.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context, false);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context, true);
                          },
                          icon: const Icon(Icons.send_rounded),
                          label: const Text('Generate'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
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
          ),
        );
      },
    );

    if (confirmed == true && mounted) {
      await _generateInvoices(selectedUnits);
    }
  }

  Widget _buildConfirmationRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }

  // ===========================================================================
  // GENERATION PROGRESS
  // ===========================================================================

  void _updateGenerationProgress({required int step, required String stage}) {
    if (!mounted) return;

    setState(() {
      _generationStep = step;
      _generationStage = stage;
    });

    _generationDialogSetState?.call(() {});
  }

  Future<void> _showInvoiceGenerationDialog() async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            _generationDialogSetState = setDialogState;
            return _buildGenerationDialog();
          },
        );
      },
    );

    _generationDialogSetState = null;
  }

  Widget _buildGenerationDialog() {
    return PopScope(
      canPop: false,
      child: Dialog(
        elevation: 0,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 46,
                      height: 46,
                      child: CircularProgressIndicator(
                        strokeWidth: 3.5,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Generating Invoices',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    _generationStage,
                    key: ValueKey(_generationStage),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 24),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    minHeight: 7,
                    value: (_generationStep + 1) / 4,
                    backgroundColor: Colors.grey.shade100,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Step ${_generationStep + 1} of 4',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                    Text(
                      '${(((_generationStep + 1) / 4) * 100).round()}%',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _buildGenerationStep(
                  index: 0,
                  icon: Icons.description_outlined,
                  title: 'Prepare invoices',
                ),
                _buildGenerationStep(
                  index: 1,
                  icon: Icons.picture_as_pdf_outlined,
                  title: 'Generate PDF documents',
                ),
                _buildGenerationStep(
                  index: 2,
                  icon: Icons.email_outlined,
                  title: 'Send to tenants',
                ),
                _buildGenerationStep(
                  index: 3,
                  icon: Icons.check_circle_outline_rounded,
                  title: 'Complete invoice run',
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 17,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Please keep this window open while invoices are being processed.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGenerationStep({
    required int index,
    required IconData icon,
    required String title,
  }) {
    final isCompleted = _generationStep > index;
    final isCurrent = _generationStep == index;

    final Color iconColor;
    if (isCompleted) {
      iconColor = Colors.green.shade600;
    } else if (isCurrent) {
      iconColor = Colors.blue.shade700;
    } else {
      iconColor = Colors.grey.shade400;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isCompleted
                  ? Colors.green.shade50
                  : isCurrent
                  ? Colors.blue.shade50
                  : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompleted ? Icons.check_rounded : icon,
              size: 17,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                color: isCurrent ? Colors.grey.shade900 : Colors.grey.shade600,
              ),
            ),
          ),
          if (isCurrent)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                color: Colors.blue.shade700,
              ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // GENERATE — processes only the selected units
  // ===========================================================================

  Future<void> _generateInvoices(List<UnitsDetails> units) async {
    if (units.isEmpty) {
      _showMessage(
        'Please select at least one tenant to invoice.',
        isError: true,
      );
      return;
    }

    if (!_validateInvoices(units)) {
      return;
    }

    bool progressDialogOpen = false;

    setState(() {
      _isGenerating = true;
      _generationStep = 0;
      _generationStage = _generationStages[0];
    });

    _showInvoiceGenerationDialog();
    progressDialogOpen = true;

    try {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      _updateGenerationProgress(
        step: 0,
        stage: 'Preparing invoices...',
      );

      // Period is derived from the due date's month.
      final invoicePeriod = _invoicePeriod();

      final invoicePayload = units.map((unit) {
        final tenant = unit.tenant!;
        final water = _getWater(unit.id);
        final serviceCost = _getServiceCost(unit.id);
        final serviceCharge = water + serviceCost;
        final rent = unit.rentAmount.toDouble();
        final total = rent + serviceCharge;

        return {
          'unit_id': unit.id,
          'unit_number': unit.unitNumber,
          'tenant_id': tenant.id,
          'tenant_name': tenant.name,
          'tenant_email': tenant.email,
          'rent': rent,
          'service': serviceCharge,
          'water': water,
          'service_cost': serviceCost,
          'amount': total,
          'invoice_period': invoicePeriod,
          'invoice_date': DateFormat('yyyy-MM-dd').format(_dueDate),
          'due_date': DateFormat('yyyy-MM-dd').format(_dueDate),
        };
      }).toList();

      if (!mounted) return;

      _updateGenerationProgress(
        step: 1,
        stage: 'Generating invoice PDFs...',
      );

      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      _updateGenerationProgress(
        step: 2,
        stage: 'Sending invoices to tenants...',
      );

      final response = await apiService.generateMonthlyInvoices(
        propertyId: widget.property.id,
        propertyName: widget.property.name,
        invoiceDate: _dueDate,
        dueDate: _dueDate,
        invoices: invoicePayload,
      );

      if (!mounted) return;

      _updateGenerationProgress(
        step: 3,
        stage: 'Finalizing invoice run...',
      );

      await Future.delayed(const Duration(milliseconds: 700));

      final success = response['success'] == true;

      if (!success) {
        throw Exception(
          response['error'] ??
              response['message'] ??
              'Unable to generate invoices.',
        );
      }

      final summary =
      Map<String, dynamic>.from(response['summary'] ?? {});

      final invoiceCount =
          summary['invoice_count'] ?? response['generated'] ?? units.length;

      final generatedCount = invoiceCount is int
          ? invoiceCount
          : int.tryParse(invoiceCount.toString()) ?? units.length;

      final failed = response['failed'] ?? 0;
      final failedCount =
      failed is int ? failed : int.tryParse(failed.toString()) ?? 0;

      if (mounted && progressDialogOpen) {
        _generationDialogSetState = null;
        Navigator.of(context, rootNavigator: true).pop();
        progressDialogOpen = false;
      }

      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;

      await _showSuccessDialog(
        units,
        generated: generatedCount,
        failed: failedCount,
        response: response,
      );

      if (mounted) {
        setState(() {
          _loadUnits();
        });
      }
    } catch (e) {
      if (mounted && progressDialogOpen) {
        _generationDialogSetState = null;
        Navigator.of(context, rootNavigator: true).pop();
        progressDialogOpen = false;
      }

      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;

      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _generationStep = 0;
          _generationStage = _generationStages[0];
        });
      }
    }
  }

  // ===========================================================================
  // SUCCESS DIALOG
  // ===========================================================================

  /// Tries several possible key names for an integer value and returns the
  /// first one found. Falls back to [fallback] when nothing matches.
  ///
  /// This exists because the backend may return the PDF / email counts under
  /// different key names than the ones we originally expected. Previously the
  /// dialog read `pdf_summary.successful_count` and
  /// `email_summary.sent_count`, and defaulted to 0 when those keys weren't
  /// present — which is why the counts displayed as zero even though the run
  /// succeeded.
  int _readInt(
      Map<String, dynamic> source,
      List<String> keys, {
        required int fallback,
      }) {
    for (final k in keys) {
      final v = source[k];
      if (v == null) continue;
      if (v is int) return v;
      final parsed = int.tryParse(v.toString());
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  Future<void> _showSuccessDialog(
      List<UnitsDetails> units, {
        required int generated,
        required int failed,
        required Map<String, dynamic> response,
      }) async {
    // Pull every likely sub-map from the response, safely.
    final summary = response['summary'] is Map
        ? Map<String, dynamic>.from(response['summary'])
        : <String, dynamic>{};

    final pdfSummary = response['pdf_summary'] is Map
        ? Map<String, dynamic>.from(response['pdf_summary'])
        : <String, dynamic>{};

    final emailSummary = response['email_summary'] is Map
        ? Map<String, dynamic>.from(response['email_summary'])
        : <String, dynamic>{};

    // -------- TOTAL AMOUNT --------
    final totalAmount = (() {
      final v = summary['total_amount'] ??
          response['total_amount'] ??
          response['amount'];
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ??
          _getGrandTotal(units);
    })();

    // -------- PDFS --------
    // Look inside pdf_summary and at the top level. Falls back to `generated`
    // because any invoice that was sent must have had a PDF produced.
    final pdfSuccessful = _readInt(
      {...response, ...pdfSummary},
      const [
        'successful_count',
        'success_count',
        'pdf_count',
        'pdfs_generated',
        'generated',
      ],
      fallback: generated,
    );

    // -------- EMAILS --------
    // Same pattern for emails, with the same sensible fallback.
    final emailSent = _readInt(
      {...response, ...emailSummary},
      const [
        'sent_count',
        'emails_sent',
        'sent',
        'delivered',
        'delivered_count',
      ],
      fallback: generated,
    );

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          contentPadding: EdgeInsets.zero,
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.green.shade600,
                        Colors.green.shade800,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Invoice Run Complete!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$generated invoices were successfully generated.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      _buildRunSummaryRow(
                        icon: Icons.receipt_long_outlined,
                        label: 'Invoices Generated',
                        value: '$generated',
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 14),
                      _buildRunSummaryRow(
                        icon: Icons.picture_as_pdf_outlined,
                        label: 'PDFs Generated',
                        value: '$pdfSuccessful',
                        color: Colors.red,
                      ),
                      const SizedBox(height: 14),
                      _buildRunSummaryRow(
                        icon: Icons.mark_email_read_outlined,
                        label: 'Emails Delivered',
                        value: '$emailSent',
                        color: Colors.green,
                      ),
                      if (failed > 0) ...[
                        const SizedBox(height: 14),
                        _buildRunSummaryRow(
                          icon: Icons.error_outline_rounded,
                          label: 'Failed',
                          value: '$failed',
                          color: Colors.orange,
                        ),
                      ],
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'TOTAL INVOICED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: Colors.green.shade700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _formatCurrency(totalAmount),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BulkInvoiceRunResultsPage(
                                  result: response,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.analytics_outlined),
                          label: const Text('View Invoice Run Results'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Done'),
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

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: _buildAppBar(),
      body: FutureBuilder<List<UnitsDetails>>(
        future: _unitsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }

          if (snapshot.hasError) {
            return _buildErrorState();
          }

          final units = snapshot.data ?? [];

          final occupiedUnits = _getOccupiedUnits(units);
          final filteredUnits = _getFilteredUnits(units);
          final selectedUnits = _getSelectedUnits(occupiedUnits);

          return _buildPage(
            occupiedUnits,
            filteredUnits,
            selectedUnits,
          );
        },
      ),
    );
  }

  // ===========================================================================
  // APP BAR
  // ===========================================================================

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 24,
      leading: IconButton(
        onPressed: _isGenerating
            ? null
            : () {
          Navigator.pop(context);
        },
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Generate Monthly Invoices',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            widget.property.name,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _isGenerating
              ? null
              : () {
            setState(() {
              _loadUnits();
            });
          },
          icon: const Icon(Icons.refresh_rounded),
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  // ===========================================================================
  // PAGE
  // ===========================================================================

  Widget _buildPage(
      List<UnitsDetails> occupiedUnits,
      List<UnitsDetails> filteredUnits,
      List<UnitsDetails> selectedUnits,
      ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isDesktop ? 28 : 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPageHeader(occupiedUnits),
                  const SizedBox(height: 20),
                  _buildConfigurationCard(),
                  const SizedBox(height: 18),
                  _buildSummaryCards(
                    occupiedUnits,
                    selectedUnits,
                    isDesktop,
                  ),
                  const SizedBox(height: 22),
                  _buildInvoiceTable(
                    occupiedUnits,
                    filteredUnits,
                    isDesktop,
                  ),
                  const SizedBox(height: 22),
                  _buildActionSection(
                    occupiedUnits,
                    selectedUnits,
                    isDesktop,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // HEADER
  // ===========================================================================

  Widget _buildPageHeader(List<UnitsDetails> units) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade700,
            Colors.blue.shade900,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Monthly Invoice Run',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Select tenants, enter water and service costs, then generate and email invoices.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (MediaQuery.of(context).size.width > 700)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 17,
                vertical: 11,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Column(
                children: [
                  Text(
                    '${units.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Occupied Units',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 10,
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
  // CONFIGURATION — period derives from the due date; only the due date is
  // user-selectable.
  // ===========================================================================

  Widget _buildConfigurationCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  color: Colors.blue.shade700,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Invoice Settings',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // The invoice period is derived from the due date's month.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 13,
                      color: Colors.purple.shade700,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _invoicePeriodLong(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.purple.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildDateSelector(
            label: 'Due Date',
            icon: Icons.event_available_outlined,
            value: DateFormat('dd MMM yyyy').format(_dueDate),
            onTap: _selectDueDate,
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector({
    required String label,
    required IconData icon,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _isGenerating ? null : onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: Colors.blue.shade700, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.grey.shade500,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SUMMARY CARDS — reflect the currently selected units
  // ===========================================================================

  Widget _buildSummaryCards(
      List<UnitsDetails> occupiedUnits,
      List<UnitsDetails> selectedUnits,
      bool isDesktop,
      ) {
    final cards = [
      _buildSummaryCard(
        title: 'Selected Tenants',
        value: '${selectedUnits.length} / ${occupiedUnits.length}',
        subtitle: selectedUnits.isEmpty
            ? 'No tenants selected'
            : 'Ready for invoicing',
        icon: Icons.apartment_rounded,
        color: Colors.blue,
      ),
      _buildSummaryCard(
        title: 'Monthly Rent',
        value: _formatCurrency(_getTotalRent(selectedUnits)),
        subtitle: 'Base rental income',
        icon: Icons.home_work_outlined,
        color: Colors.purple,
      ),
      _buildSummaryCard(
        title: 'Service Charges',
        value: _formatCurrency(_getTotalServiceCharges(selectedUnits)),
        subtitle: 'Water + service cost',
        icon: Icons.water_drop_outlined,
        color: Colors.orange,
      ),
      _buildSummaryCard(
        title: 'Total Invoiced',
        value: _formatCurrency(_getGrandTotal(selectedUnits)),
        subtitle: 'Current invoice run',
        icon: Icons.account_balance_wallet_outlined,
        color: Colors.green,
      ),
    ];

    if (isDesktop) {
      return Row(
        children: cards
            .map(
              (card) => Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: card,
            ),
          ),
        )
            .toList(),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: cards
          .map(
            (card) => SizedBox(
          width: (MediaQuery.of(context).size.width - 42) / 2,
          child: card,
        ),
      )
          .toList(),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // INVOICE TABLE (with selection)
  // ===========================================================================

  Widget _buildInvoiceTable(
      List<UnitsDetails> allUnits,
      List<UnitsDetails> filteredUnits,
      bool isDesktop,
      ) {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.receipt_long_outlined,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tenant Invoice Charges',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Select which tenants to invoice, then set water and service cost.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isDesktop)
                  TextButton.icon(
                    onPressed: _isGenerating
                        ? null
                        : () {
                      _showClearConfirmation(allUnits);
                    },
                    icon: const Icon(Icons.restart_alt_rounded, size: 17),
                    label: const Text('Reset'),
                  ),
              ],
            ),
          ),

          // ------------------------------------------------------------- SEARCH
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: TextField(
              controller: _searchController,
              enabled: !_isGenerating,
              decoration: InputDecoration(
                hintText: 'Search tenant, unit or email...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
              ),
            ),
          ),

          const SizedBox(height: 15),

          // --------------------------------------------------- SELECTION TOOLBAR
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: _buildSelectionToolbar(filteredUnits),
          ),

          const SizedBox(height: 15),

          if (!isDesktop)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _isGenerating
                      ? null
                      : () {
                    _showClearConfirmation(allUnits);
                  },
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Reset Charges'),
                ),
              ),
            ),

          isDesktop
              ? _buildDesktopTable(filteredUnits)
              : _buildMobileInvoiceList(filteredUnits),

          const SizedBox(height: 10),
        ],
      ),
    );
  }

  /// Toolbar above the tenant list showing "Select all" + count.
  Widget _buildSelectionToolbar(List<UnitsDetails> units) {
    if (units.isEmpty) {
      return const SizedBox.shrink();
    }

    final allSelected = _isAllSelected(units);
    final anySelected = _isAnySelected(units);
    final selectedCount =
        units.where((u) => _selectedUnitIds.contains(u.id)).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.shade100,
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: allSelected,
            tristate: false,
            activeColor: Colors.blue.shade700,
            onChanged: _isGenerating
                ? null
                : (_) => _toggleSelectAll(units),
          ),
          Expanded(
            child: GestureDetector(
              onTap:
              _isGenerating ? null : () => _toggleSelectAll(units),
              child: Text(
                allSelected
                    ? 'Deselect all'
                    : anySelected
                    ? 'Select all tenants'
                    : 'Select all tenants',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E40AF),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$selectedCount of ${units.length} selected',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.blue.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // DESKTOP TABLE
  // ===========================================================================

  Widget _buildDesktopTable(List<UnitsDetails> units) {
    if (units.isEmpty) {
      return _buildEmptyTableState();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 1240,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              color: Colors.grey.shade50,
              child: const Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text(
                      '',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(
                      'UNIT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: Text(
                      'TENANT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: Text(
                      'EMAIL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: Text(
                      'RENT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: Text(
                      'WATER BILL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: Text(
                      'SERVICE COST',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 160,
                    child: Text(
                      'TOTAL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...units.map((unit) => _buildDesktopInvoiceRow(unit)),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopInvoiceRow(UnitsDetails unit) {
    final tenant = unit.tenant;
    final isSelected = _isUnitSelected(unit.id);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.blue.shade50.withValues(alpha: 0.35)
            : Colors.transparent,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Checkbox(
              value: isSelected,
              activeColor: Colors.blue.shade700,
              onChanged: _isGenerating
                  ? null
                  : (_) => _toggleUnitSelection(unit.id),
            ),
          ),
          SizedBox(
            width: 80,
            child: _buildUnitBadge(unit.unitNumber),
          ),
          SizedBox(
            width: 200,
            child: Text(
              tenant?.name ?? '-',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 200,
            child: Text(
              tenant?.email ?? '-',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              _formatCurrency(unit.rentAmount),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          SizedBox(
            width: 140,
            child: _buildAmountField(
              controller: _getWaterController(unit.id),
              onChanged: (value) {
                setState(() {
                  _waterValues[unit.id] = double.tryParse(value) ?? 0;
                });
              },
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 140,
            child: _buildAmountField(
              controller: _getServiceController(unit.id),
              onChanged: (value) {
                setState(() {
                  _serviceValues[unit.id] = double.tryParse(value) ?? 0;
                });
              },
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 160,
            child: Text(
              _formatCurrency(_getTotal(unit)),
              style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // MOBILE
  // ===========================================================================

  Widget _buildMobileInvoiceList(List<UnitsDetails> units) {
    if (units.isEmpty) {
      return _buildEmptyTableState();
    }

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: units.map((unit) {
          final tenant = unit.tenant;
          final isSelected = _isUnitSelected(unit.id);

          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.blue.shade50.withValues(alpha: 0.35)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: isSelected
                    ? Colors.blue.shade200
                    : Colors.grey.shade200,
                width: isSelected ? 1.4 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: isSelected,
                      activeColor: Colors.blue.shade700,
                      onChanged: _isGenerating
                          ? null
                          : (_) => _toggleUnitSelection(unit.id),
                    ),
                    _buildUnitBadge(unit.unitNumber),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tenant?.name ?? '-',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            tenant?.email ?? '-',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: _buildMobileAmountInfo(
                        'Rent',
                        _formatCurrency(unit.rentAmount),
                        Colors.blue,
                      ),
                    ),
                    Expanded(
                      child: _buildMobileAmountInfo(
                        'Service Charge',
                        _formatCurrency(_getServiceCharge(unit.id)),
                        Colors.orange,
                      ),
                    ),
                    Expanded(
                      child: _buildMobileAmountInfo(
                        'Total',
                        _formatCurrency(_getTotal(unit)),
                        Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: _buildMobileInput(
                        label: 'Water Bill',
                        controller: _getWaterController(unit.id),
                        onChanged: (value) {
                          setState(() {
                            _waterValues[unit.id] =
                                double.tryParse(value) ?? 0;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMobileInput(
                        label: 'Service Cost',
                        controller: _getServiceController(unit.id),
                        onChanged: (value) {
                          setState(() {
                            _serviceValues[unit.id] =
                                double.tryParse(value) ?? 0;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 17,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 7),
                      const Expanded(
                        child: Text(
                          'Service Charge',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        _formatCurrency(_getServiceCharge(unit.id)),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMobileAmountInfo(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildMobileInput({
    required String label,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 5),
        _buildAmountField(
          controller: controller,
          onChanged: onChanged,
        ),
      ],
    );
  }

  // ===========================================================================
  // INPUT
  // ===========================================================================

  Widget _buildAmountField({
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
  }) {
    return SizedBox(
      height: 43,
      child: TextField(
        controller: controller,
        enabled: !_isGenerating,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
        ],
        onChanged: onChanged,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          prefixText: 'Ksh ',
          prefixStyle: TextStyle(color: Colors.grey.shade500, fontSize: 10),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(color: Colors.blue.shade600, width: 1.5),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // BADGE / EMPTY
  // ===========================================================================

  Widget _buildUnitBadge(String unitNumber) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        unitNumber,
        style: TextStyle(
          color: Colors.blue.shade700,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildEmptyTableState() {
    return Padding(
      padding: const EdgeInsets.all(45),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 13),
          const Text(
            'No tenants found',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          Text(
            'Try changing your search criteria.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // ACTION SECTION
  // ===========================================================================

  Widget _buildActionSection(
      List<UnitsDetails> allUnits,
      List<UnitsDetails> selectedUnits,
      bool isDesktop,
      ) {
    final completedEntries = _getCompletedEntries(selectedUnits);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: isDesktop
          ? Row(
        children: [
          Expanded(
            child: _buildActionSummary(
              allUnits,
              selectedUnits,
              completedEntries,
            ),
          ),
          const SizedBox(width: 30),
          _buildActionButtons(selectedUnits),
        ],
      )
          : Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildActionSummary(
            allUnits,
            selectedUnits,
            completedEntries,
          ),
          const SizedBox(height: 18),
          _buildActionButtons(selectedUnits),
        ],
      ),
    );
  }

  Widget _buildActionSummary(
      List<UnitsDetails> allUnits,
      List<UnitsDetails> selectedUnits,
      int completedEntries,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ready to Generate',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          selectedUnits.isEmpty
              ? 'Select at least one tenant to continue.'
              : '${selectedUnits.length} of ${allUnits.length} tenants will receive invoices.',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 7,
          children: [
            _buildMiniSummary(
              Icons.people_outline_rounded,
              '${selectedUnits.length} Selected',
              Colors.blue,
            ),
            _buildMiniSummary(
              Icons.edit_note_rounded,
              '$completedEntries Charges Updated',
              Colors.orange,
            ),
            _buildMiniSummary(
              Icons.account_balance_wallet_outlined,
              _formatCurrency(_getGrandTotal(selectedUnits)),
              Colors.green,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniSummary(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(List<UnitsDetails> selectedUnits) {
    final hasSelection = selectedUnits.isNotEmpty;
    final canGenerate =
        hasSelection && !_isGenerating && !_isSavingDraft;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.end,
      children: [
        ElevatedButton.icon(
          onPressed: canGenerate
              ? () {
            _showGenerateConfirmation(selectedUnits);
          }
              : null,
          icon: _isGenerating
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          )
              : const Icon(Icons.send_rounded, size: 18),
          label: Text(
            _isGenerating
                ? 'Generating...'
                : !hasSelection
                ? 'Select tenants to invoice'
                : 'Generate & Send (${selectedUnits.length})',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.blue.shade200,
            disabledForegroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 14,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(11),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // STATES
  // ===========================================================================

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 35,
            height: 35,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Loading units...',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(30),
        decoration: _cardDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 55,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to Load Units',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your connection and try again.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _loadUnits();
                });
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // CARD DECORATION
  // ===========================================================================

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: Colors.grey.shade200),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.025),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _buildRunSummaryRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}