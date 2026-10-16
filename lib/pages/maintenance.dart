import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hub/models/models.dart';
import 'package:hub/services/services.dart';
import 'package:hub/config/config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MaintenancePage extends StatefulWidget {
  const MaintenancePage({super.key});

  @override
  State<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends State<MaintenancePage>
    with TickerProviderStateMixin {
  late final ApiService apiService;
  late Future<List<MaintenanceIssue>> maintenanceIssuesFuture;

  String? userId;
  bool _isMounted = true;

  // ============================================================
  // FILTER STATE
  // ============================================================

  String _selectedType = 'All Types';
  String _selectedProperty = 'All Properties';
  String _selectedPeriod = 'All Time';
  String _selectedStatus = 'All Statuses';

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  // ✅ Filter panel visibility (hidden by default)
  bool _showFilters = false;

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

  /// Canonical status keys used by the API, paired with a friendly label.
  static const List<Map<String, String>> _statusOptions = [
    {'key': 'All Statuses', 'label': 'All Statuses'},
    {'key': 'open', 'label': 'Open'},
    {'key': 'in_progress', 'label': 'In Progress'},
    {'key': 'resolved', 'label': 'Resolved'},
  ];

  // ============================================================
  // INIT / DISPOSE
  // ============================================================

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    apiService = ApiService(baseUrl: baseUrl);
    maintenanceIssuesFuture = _fetchIssues();
  }

  @override
  void dispose() {
    _isMounted = false;
    super.dispose();
  }

  // ============================================================
  // DATA
  // ============================================================

  Future<List<MaintenanceIssue>> _fetchIssues() async {
    final results = await Future.wait([
      _actuallyFetchIssues(),
      Future<void>.delayed(const Duration(milliseconds: 850)),
    ]);
    return results.first as List<MaintenanceIssue>;
  }

  Future<List<MaintenanceIssue>> _actuallyFetchIssues() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getString('user_id');
      if (userId == null) return const [];
      final userIdInt = int.tryParse(userId!);
      if (userIdInt == null) return const [];
      return await apiService.fetchMaintenanceIssues();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _loadData() async {
    if (!_isMounted || !mounted) return;
    setState(() {
      maintenanceIssuesFuture = _fetchIssues();
    });
  }

  Future<void> _refreshData() async {
    if (!_isMounted || !mounted) return;
    try {
      setState(() {
        maintenanceIssuesFuture = _fetchIssues();
      });
      await maintenanceIssuesFuture;
    } catch (_) {}
  }

  // ============================================================
  // RESPONSIVE TEXT SCALING
  // ============================================================

  double _computeTextScale(double width) {
    if (width >= 1500) return 1.40;
    if (width >= 1200) return 1.28;
    if (width >= 1000) return 1.18;
    if (width >= 800) return 1.10;
    if (width >= 600) return 1.05;
    return 1.0;
  }

  Widget _withScaledText(BuildContext context, Widget child) {
    final mq = MediaQuery.of(context);
    final scale = _computeTextScale(mq.size.width);
    return MediaQuery(
      data: mq.copyWith(textScaler: TextScaler.linear(scale)),
      child: child,
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _getHouseNumber(MaintenanceIssue issue) => issue.houseNo.trim();

  String _propertyLabel(MaintenanceIssue issue) =>
      issue.propertyName.trim().isEmpty
          ? 'Unknown Property'
          : issue.propertyName.trim();

  // ============================================================
  // FILTERING
  // ============================================================

  List<MaintenanceIssue> _filterIssues(List<MaintenanceIssue> issues) {
    return issues.where((issue) {
      bool matchesType = true;
      if (_selectedType != 'All Types') {
        matchesType = _getIssueType(issue) == _selectedType;
      }

      bool matchesProperty = true;
      if (_selectedProperty != 'All Properties') {
        matchesProperty = issue.propertyName.trim() == _selectedProperty;
      }

      bool matchesStatus = true;
      if (_selectedStatus != 'All Statuses') {
        matchesStatus =
            (issue.status).toLowerCase() == _selectedStatus.toLowerCase();
      }

      bool matchesPeriod = true;
      if (_selectedPeriod != 'All Time') {
        final issueDate = _getIssueDate(issue);
        if (issueDate == null) {
          matchesPeriod = false;
        } else if (_selectedPeriod == 'Monthly') {
          matchesPeriod = issueDate.month == _selectedMonth &&
              issueDate.year == _selectedYear;
        } else if (_selectedPeriod == 'Yearly') {
          matchesPeriod = issueDate.year == _selectedYear;
        }
      }

      return matchesType && matchesProperty && matchesStatus && matchesPeriod;
    }).toList();
  }

  String _getIssueType(MaintenanceIssue issue) {
    final value = issue.subject.trim();
    return value.isEmpty ? 'Other' : value;
  }

  DateTime? _getIssueDate(MaintenanceIssue issue) {
    final value = issue.createdAt;
    return value;
  }

  List<String> _getAvailableTypes(List<MaintenanceIssue> issues) {
    final types = <String>{'All Types'};
    for (final issue in issues) {
      final type = _getIssueType(issue);
      if (type.isNotEmpty) types.add(type);
    }
    final result = types.toList()..remove('All Types');
    result.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['All Types', ...result];
  }

  List<String> _getAvailableProperties(List<MaintenanceIssue> issues) {
    final properties = <String>{'All Properties'};
    for (final issue in issues) {
      final name = issue.propertyName.trim();
      if (name.isNotEmpty) properties.add(name);
    }
    final result = properties.toList()..remove('All Properties');
    result.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['All Properties', ...result];
  }

  List<Map<String, String>> _getAvailableStatuses(
      List<MaintenanceIssue> issues) {
    final present = <String>{};
    for (final issue in issues) {
      final s = (issue.status).trim().toLowerCase();
      if (s.isNotEmpty) present.add(s);
    }

    return _statusOptions.where((opt) {
      if (opt['key'] == 'All Statuses') return true;
      return present.contains(opt['key']);
    }).toList();
  }

  bool get _hasActiveFilters =>
      _selectedType != 'All Types' ||
          _selectedProperty != 'All Properties' ||
          _selectedPeriod != 'All Time' ||
          _selectedStatus != 'All Statuses';

  int get _activeFilterCount {
    int count = 0;
    if (_selectedType != 'All Types') count++;
    if (_selectedProperty != 'All Properties') count++;
    if (_selectedPeriod != 'All Time') count++;
    if (_selectedStatus != 'All Statuses') count++;
    return count;
  }

  void _clearFilters() {
    if (!_isMounted || !mounted) return;
    setState(() {
      _selectedType = 'All Types';
      _selectedProperty = 'All Properties';
      _selectedPeriod = 'All Time';
      _selectedStatus = 'All Statuses';
      _selectedMonth = DateTime.now().month;
      _selectedYear = DateTime.now().year;
    });
  }

  void _clearSingleFilter(String key) {
    if (!_isMounted || !mounted) return;
    setState(() {
      switch (key) {
        case 'type':
          _selectedType = 'All Types';
          break;
        case 'property':
          _selectedProperty = 'All Properties';
          break;
        case 'period':
          _selectedPeriod = 'All Time';
          break;
        case 'status':
          _selectedStatus = 'All Statuses';
          break;
      }
    });
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _showSafeSnackBar(
      String message, {
        Color backgroundColor = Colors.blue,
      }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isMounted && mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: backgroundColor,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
      }
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final scale = _computeTextScale(mq.size.width);

    return MediaQuery(
      data: mq.copyWith(textScaler: TextScaler.linear(scale)),
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7FB),
        body: SafeArea(
          child: Column(
            children: [
              _buildPageHeader(),
              Expanded(
                child: FutureBuilder<List<MaintenanceIssue>>(
                  future: maintenanceIssuesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      // ✅ Themed loader
                      return const _MaintenanceLoader();
                    }
                    if (snapshot.hasError) {
                      return _buildMaintenanceError(snapshot.error);
                    }
                    final issues = snapshot.data ?? [];
                    return RefreshIndicator(
                      onRefresh: _refreshData,
                      color: Palette.nestBlue,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ✅ Compact toggle bar + collapsible panel
                                _buildFilterToggleBar(issues),
                                if (_showFilters) ...[
                                  const SizedBox(height: 12),
                                  _buildMaintenanceFilters(issues),
                                ],
                                const SizedBox(height: 20),
                                _buildIssuesSection(issues),
                                const SizedBox(height: 20),
                                _buildAnalyticsSection(
                                  issues,
                                  constraints.maxWidth,
                                ),
                              ],
                            ),
                          );
                        },
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

  // ============================================================
  // PAGE HEADER
  // ============================================================

  Widget _buildPageHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Palette.nestBlue,
              Palette.nestBlue.withValues(alpha: 0.82),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Palette.nestBlue.withValues(alpha: 0.28),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.28),
                ),
              ),
              child: const Icon(
                Icons.build_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Maintenance',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Monitor and manage property maintenance',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            FutureBuilder<List<MaintenanceIssue>>(
              future: maintenanceIssuesFuture,
              builder: (context, snapshot) {
                int openCount = 0;
                if (snapshot.hasData) {
                  openCount =
                      snapshot.data!.where((i) => i.status == 'open').length;
                }
                return _buildNotificationButton(openCount);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationButton(int count) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: _refreshData,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(
                Icons.notifications_none_rounded,
                color: Colors.white,
                size: 24,
              ),
              if (count > 0)
                Positioned(
                  right: 5,
                  top: 5,
                  child: Container(
                    constraints:
                    const BoxConstraints(minWidth: 18, minHeight: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF4D4F),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        count > 99 ? '99+' : count.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
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

  // ============================================================
  // FILTER TOGGLE BAR (compact summary + toggle button)
  // ============================================================

  Widget _buildFilterToggleBar(List<MaintenanceIssue> issues) {
    final hasActive = _hasActiveFilters;
    final filteredIssues = _filterIssues(issues);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECF2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Toggle button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() => _showFilters = !_showFilters);
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _showFilters
                      ? Palette.nestBlue.withValues(alpha: 0.10)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 17,
                      color: _showFilters
                          ? Palette.nestBlue
                          : const Color(0xFF475569),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _showFilters
                            ? Palette.nestBlue
                            : const Color(0xFF334155),
                      ),
                    ),
                    if (hasActive) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Palette.nestBlue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$_activeFilterCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 5),
                    Icon(
                      _showFilters
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: _showFilters
                          ? Palette.nestBlue
                          : const Color(0xFF64748B),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Active chips / result count
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  if (_selectedType != 'All Types')
                    _buildActiveChip(
                      icon: Icons.category_outlined,
                      label: _selectedType,
                      onClear: () => _clearSingleFilter('type'),
                    ),
                  if (_selectedProperty != 'All Properties')
                    _buildActiveChip(
                      icon: Icons.home_outlined,
                      label: _selectedProperty,
                      onClear: () => _clearSingleFilter('property'),
                    ),
                  if (_selectedStatus != 'All Statuses')
                    _buildActiveChip(
                      icon: Icons.flag_outlined,
                      label: _selectedStatus == 'in_progress'
                          ? 'In Progress'
                          : _selectedStatus[0].toUpperCase() +
                          _selectedStatus.substring(1),
                      onClear: () => _clearSingleFilter('status'),
                    ),
                  if (_selectedPeriod != 'All Time')
                    _buildActiveChip(
                      icon: Icons.date_range_outlined,
                      label: _selectedPeriod == 'Monthly'
                          ? _months[_selectedMonth - 1]
                          : _selectedPeriod == 'Yearly'
                          ? _selectedYear.toString()
                          : _selectedPeriod,
                      onClear: () => _clearSingleFilter('period'),
                    ),
                  if (!hasActive)
                    Text(
                      '${filteredIssues.length} of ${issues.length} shown',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ),

          if (hasActive)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _clearFilters,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.clear_all_rounded,
                      size: 17,
                      color: Colors.red,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveChip({
    required IconData icon,
    required String label,
    required VoidCallback onClear,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Container(
        padding: const EdgeInsets.only(left: 8, right: 4, top: 5, bottom: 5),
        decoration: BoxDecoration(
          color: Palette.nestBlue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Palette.nestBlue.withValues(alpha: 0.20),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: Palette.nestBlue),
            const SizedBox(width: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Palette.nestBlue,
                ),
              ),
            ),
            const SizedBox(width: 2),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onClear,
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(
                    Icons.close_rounded,
                    size: 13,
                    color: Palette.nestBlue,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FILTER SECTION (expanded panel)
  // ============================================================

  Widget _buildMaintenanceFilters(List<MaintenanceIssue> issues) {
    final availableTypes = _getAvailableTypes(issues);
    final availableProperties = _getAvailableProperties(issues);
    final availableStatuses = _getAvailableStatuses(issues);
    final filteredIssues = _filterIssues(issues);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Palette.nestBlue.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: Palette.nestBlue,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Refine Results',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Filter maintenance by type, property, status and period',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF8A94A3),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() => _showFilters = false);
                },
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;

              // ---- Wide desktop: 4 filters in one row -------------
              if (w >= 950) {
                return Row(
                  children: [
                    Expanded(child: _buildTypeFilter(availableTypes)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildPropertyFilter(availableProperties)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatusFilter(availableStatuses)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildPeriodFilter()),
                  ],
                );
              }

              // ---- Narrow desktop / large tablet: 2 + 2 -----------
              if (w >= 720) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildTypeFilter(availableTypes)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildPropertyFilter(availableProperties),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatusFilter(availableStatuses),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: _buildPeriodFilter()),
                      ],
                    ),
                  ],
                );
              }

              // ---- Small tablet / mobile: stack -------------------
              return Column(
                children: [
                  _buildTypeFilter(availableTypes),
                  const SizedBox(height: 12),
                  _buildPropertyFilter(availableProperties),
                  const SizedBox(height: 12),
                  _buildStatusFilter(availableStatuses),
                  const SizedBox(height: 12),
                  _buildPeriodFilter(),
                ],
              );
            },
          ),

          if (_selectedPeriod == 'Monthly') ...[
            const SizedBox(height: 12),
            _buildMonthSelector(),
          ],

          if (_selectedPeriod == 'Monthly' ||
              _selectedPeriod == 'Yearly') ...[
            const SizedBox(height: 12),
            _buildYearSelector(),
          ],

          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FC),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.analytics_outlined,
                  size: 18,
                  color: Color(0xFF7A8493),
                ),
                const SizedBox(width: 8),
                Text(
                  '${filteredIssues.length} '
                      '${filteredIssues.length == 1 ? 'issue' : 'issues'} found',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF374151),
                  ),
                ),
                const Spacer(),
                if (_hasActiveFilters)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Palette.nestBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Filtered',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Palette.nestBlue,
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

  Widget _buildTypeFilter(List<String> types) {
    return DropdownButtonFormField<String>(
      initialValue: types.contains(_selectedType) ? _selectedType : 'All Types',
      isExpanded: true,
      decoration: _filterDecoration(
        label: 'Issue Type',
        icon: Icons.category_outlined,
      ),
      items: types.map((type) {
        return DropdownMenuItem<String>(
          value: type,
          child: Text(
            type,
            style: const TextStyle(fontSize: 10),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value == null) return;
        setState(() => _selectedType = value);
      },
    );
  }

  Widget _buildPropertyFilter(List<String> properties) {
    return DropdownButtonFormField<String>(
      initialValue: properties.contains(_selectedProperty)
          ? _selectedProperty
          : 'All Properties',
      isExpanded: true,
      decoration: _filterDecoration(
        label: 'Property',
        icon: Icons.home_outlined,
      ),
      items: properties.map((property) {
        return DropdownMenuItem<String>(
          value: property,
          child: Text(
            property,
            style: const TextStyle(fontSize: 10),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value == null) return;
        setState(() => _selectedProperty = value);
      },
    );
  }

  Widget _buildStatusFilter(List<Map<String, String>> statuses) {
    final keys = statuses.map((s) => s['key']!).toList();
    final safeValue =
    keys.contains(_selectedStatus) ? _selectedStatus : 'All Statuses';

    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      isExpanded: true,
      decoration: _filterDecoration(
        label: 'Status',
        icon: Icons.flag_outlined,
      ),
      items: statuses.map((status) {
        final key = status['key']!;
        final label = status['label']!;
        final color = _getStatusColor(key);

        return DropdownMenuItem<String>(
          value: key,
          child: Row(
            children: [
              if (key != 'All Statuses') ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value == null) return;
        setState(() => _selectedStatus = value);
      },
    );
  }

  Widget _buildPeriodFilter() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedPeriod,
      isExpanded: true,
      decoration: _filterDecoration(
        label: 'Period',
        icon: Icons.date_range_outlined,
      ),
      items: const [
        DropdownMenuItem(
          value: 'All Time',
          child: Text('All Time', style: TextStyle(fontSize: 10)),
        ),
        DropdownMenuItem(
          value: 'Monthly',
          child: Text('Monthly', style: TextStyle(fontSize: 10)),
        ),
        DropdownMenuItem(
          value: 'Yearly',
          child: Text('Yearly', style: TextStyle(fontSize: 10)),
        ),
      ],
      onChanged: (value) {
        if (value == null) return;
        setState(() => _selectedPeriod = value);
      },
    );
  }

  Widget _buildMonthSelector() {
    return DropdownButtonFormField<int>(
      initialValue: _selectedMonth,
      isExpanded: true,
      decoration: _filterDecoration(
        label: 'Month',
        icon: Icons.calendar_month_outlined,
      ),
      items: List.generate(
        12,
            (index) => DropdownMenuItem<int>(
          value: index + 1,
          child: Text(_months[index], style: const TextStyle(fontSize: 12)),
        ),
      ),
      onChanged: (value) {
        if (value == null) return;
        setState(() => _selectedMonth = value);
      },
    );
  }

  Widget _buildYearSelector() {
    final currentYear = DateTime.now().year;
    final years = List.generate(6, (index) => currentYear - index);
    if (!years.contains(_selectedYear)) {
      _selectedYear = currentYear;
    }

    return DropdownButtonFormField<int>(
      initialValue: _selectedYear,
      isExpanded: true,
      decoration: _filterDecoration(
        label: 'Year',
        icon: Icons.calendar_today_outlined,
      ),
      items: years.map((year) {
        return DropdownMenuItem<int>(
          value: year,
          child: Text(year.toString(), style: const TextStyle(fontSize: 12)),
        );
      }).toList(),
      onChanged: (value) {
        if (value == null) return;
        setState(() => _selectedYear = value);
      },
    );
  }

  InputDecoration _filterDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 11, color: Color(0xFF7A8493)),
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFF697586)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: Palette.nestBlue, width: 1.2),
      ),
    );
  }

  // ============================================================
  // ISSUES SECTION (GRID)
  // ============================================================

  Widget _buildIssuesSection(List<MaintenanceIssue> allIssues) {
    final issues = _filterIssues(allIssues);
    final truncated = issues.length > 12;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Maintenance Issues',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Review and manage reported issues',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF8A94A3),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: Palette.nestBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  issues.length.toString(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Palette.nestBlue,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          if (issues.isEmpty)
            _buildEmptyMaintenanceState()
          else
            _buildIssuesGrid(issues),

          if (truncated) ...[
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Showing 12 of ${issues.length} issues',
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF8A94A3),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIssuesGrid(List<MaintenanceIssue> issues) {
    final displayIssues =
    issues.length > 12 ? issues.take(12).toList() : issues;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;

        int crossAxisCount;
        double cardHeight;

        if (w >= 1100) {
          crossAxisCount = 3;
          cardHeight = 310;
        } else if (w >= 700) {
          crossAxisCount = 2;
          cardHeight = 310;
        } else {
          crossAxisCount = 1;
          cardHeight = 310;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: cardHeight,
          ),
          itemCount: displayIssues.length,
          itemBuilder: (context, index) {
            return _buildIssueCard(displayIssues[index]);
          },
        );
      },
    );
  }

  // ============================================================
  // ISSUE CARD
  // ============================================================

  Widget _buildIssueCard(MaintenanceIssue issue) {
    final issueType = _getIssueType(issue);
    final issueDate = _getIssueDate(issue);
    final houseNumber = _getHouseNumber(issue);
    final propertyLabel = _propertyLabel(issue);
    final hasPhotos = issue.photos.isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _showMaintenanceDetails(issue),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------- HEADER ----------
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Palette.nestBlue.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.build_outlined,
                    color: Palette.nestBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        issue.subject,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(
                            Icons.home_outlined,
                            size: 12,
                            color: Color(0xFF8A94A3),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              propertyLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF8A94A3),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                _buildStatusBadge(issue.status),
              ],
            ),

            const SizedBox(height: 10),

            // ---------- CHIPS ----------
            if (houseNumber.isNotEmpty || issue.name.trim().isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (houseNumber.isNotEmpty)
                    _buildChip(
                      icon: Icons.meeting_room_outlined,
                      label: 'House $houseNumber',
                    ),
                  if (issue.name.trim().isNotEmpty)
                    _buildChip(
                      icon: Icons.person_outline_rounded,
                      label: issue.name.trim(),
                    ),
                ],
              ),
              const SizedBox(height: 10),
            ],

            // ---------- DESCRIPTION ----------
            Text(
              issue.description.isEmpty
                  ? 'No description provided.'
                  : issue.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                height: 1.45,
                color: Color(0xFF667085),
              ),
            ),

            // ---------- PHOTOS ----------
            if (hasPhotos) ...[
              const SizedBox(height: 10),
              _buildCompactPhotos(issue),
            ],

            // ---------- FOOTER ----------
            const SizedBox(height: 12),
            Container(height: 1, color: Colors.grey.shade100),
            const SizedBox(height: 10),

            Row(
              children: [
                _buildIssueMeta(Icons.tag_outlined, '#${issue.id}'),
                const SizedBox(width: 10),
                Flexible(
                  child: _buildIssueMeta(
                    Icons.category_outlined,
                    issueType,
                  ),
                ),
                if (issueDate != null) ...[
                  const SizedBox(width: 10),
                  _buildIssueMeta(
                    Icons.calendar_today_outlined,
                    _formatDate(issueDate),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showUpdateStatusDialog(issue),
                icon: const Icon(Icons.edit_outlined, size: 15),
                label: const Text(
                  'Update Status',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Palette.nestBlue,
                  side: BorderSide(
                    color: Palette.nestBlue.withValues(alpha: 0.28),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // COMPACT PHOTOS (for grid cards)
  // ============================================================

  Widget _buildCompactPhotos(MaintenanceIssue issue) {
    final photos = issue.photos;
    final visibleCount = photos.length > 4 ? 4 : photos.length;

    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: visibleCount,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final photo = photos[index];

          return GestureDetector(
            onTap: () => _openMaintenancePhotoViewer(context, photos, index),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    photo,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F4F7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.broken_image_outlined,
                          color: Color(0xFF98A2B3),
                          size: 20,
                        ),
                      );
                    },
                  ),
                ),
                if (index == 3 && photos.length > 4)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '+${photos.length - 4}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Palette.nestBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Palette.nestBlue),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Palette.nestBlue,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATUS BADGE
  // ============================================================

  Widget _buildStatusBadge(String? status) {
    final color = _getStatusColor(status);
    final label = (status ?? 'unknown').replaceAll('_', ' ').toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIssueMeta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: const Color(0xFF98A2B3)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9,
              color: Color(0xFF7A8493),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  // ============================================================
  // MAINTENANCE DETAILS
  // ============================================================

  Future<void> _showMaintenanceDetails(MaintenanceIssue issue) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final issueDate = _getIssueDate(issue);
        final statusColor = _getStatusColor(issue.status);
        final houseNumber = _getHouseNumber(issue);
        final propertyLabel = _propertyLabel(issue);

        return _withScaledText(
          dialogContext,
          Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680, maxHeight: 780),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Palette.nestBlue.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(
                            Icons.build_outlined,
                            color: Palette.nestBlue,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                issue.subject,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Maintenance Issue #${issue.id}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF8A94A3),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildStatusBadge(issue.status),
                        const SizedBox(width: 5),
                        IconButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: Colors.grey.shade200),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.home_outlined,
                                  size: 18,
                                  color: Color(0xFF667085),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'PROPERTY',
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF98A2B3),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        propertyLabel,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF374151),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (houseNumber.isNotEmpty) ...[
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Palette.nestBlue
                                          .withValues(alpha: 0.09),
                                      borderRadius:
                                      BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.meeting_room_outlined,
                                          size: 12,
                                          color: Palette.nestBlue,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'House $houseNumber',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: Palette.nestBlue,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 15),

                          const Text(
                            'Description',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF374151),
                            ),
                          ),

                          const SizedBox(height: 7),

                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Text(
                              issue.description.isEmpty
                                  ? 'No description provided.'
                                  : issue.description,
                              style: const TextStyle(
                                fontSize: 11,
                                height: 1.5,
                                color: Color(0xFF667085),
                              ),
                            ),
                          ),

                          if (issue.photos.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                const Text(
                                  'Photos',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Palette.nestBlue
                                        .withValues(alpha: .08),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    issue.photos.length.toString(),
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Palette.nestBlue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 9),
                            _buildDetailsPhotoGrid(issue),
                          ],

                          const SizedBox(height: 18),

                          Row(
                            children: [
                              Expanded(
                                child: _buildDetailsMeta(
                                  icon: Icons.category_outlined,
                                  label: 'Type',
                                  value: _getIssueType(issue),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildDetailsMeta(
                                  icon: Icons.calendar_today_outlined,
                                  label: 'Reported',
                                  value: issueDate == null
                                      ? 'Unknown'
                                      : _formatDate(issueDate),
                                ),
                              ),
                            ],
                          ),

                          if (issue.name.trim().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _buildDetailsMeta(
                              icon: Icons.person_outline_rounded,
                              label: 'Reported By',
                              value: issue.name.trim(),
                            ),
                          ],

                          const SizedBox(height: 10),

                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: .06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: statusColor.withValues(alpha: .12),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 17,
                                  color: statusColor,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Current status: '
                                        '${(issue.status).replaceAll('_', ' ')}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
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
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            _showUpdateStatusDialog(issue);
                          },
                          icon: const Icon(Icons.edit_outlined, size: 15),
                          label: const Text(
                            'Update Status',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Palette.nestBlue,
                            side: BorderSide(
                              color: Palette.nestBlue.withValues(alpha: .25),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        ElevatedButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Palette.nestBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                          child: const Text(
                            'Done',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
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
        );
      },
    );
  }

  Widget _buildDetailsPhotoGrid(MaintenanceIssue issue) {
    final photos = issue.photos;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.15,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];

        return GestureDetector(
          onTap: () => _openMaintenancePhotoViewer(context, photos, index),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  photo,
                  fit: BoxFit.cover,
                  webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFFF2F4F7),
                      child: const Icon(
                        Icons.broken_image_outlined,
                        color: Color(0xFF98A2B3),
                      ),
                    );
                  },
                ),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.zoom_in_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailsMeta({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF7A8493)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 7,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF98A2B3),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FULL SCREEN PHOTO VIEWER
  // ============================================================

  void _openMaintenancePhotoViewer(
      BuildContext context,
      List<String> photos,
      int initialIndex,
      ) {
    if (photos.isEmpty) return;

    final controller = PageController(initialPage: initialIndex);

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .92),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: StatefulBuilder(
            builder: (context, setState) {
              var currentIndex = initialIndex;

              return Stack(
                children: [
                  Positioned.fill(
                    child: PageView.builder(
                      controller: controller,
                      itemCount: photos.length,
                      onPageChanged: (index) {
                        setState(() => currentIndex = index);
                      },
                      itemBuilder: (context, index) {
                        final photo = photos[index];

                        return Center(
                          child: InteractiveViewer(
                            minScale: 0.8,
                            maxScale: 4.0,
                            child: Image.network(
                              photo,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: double.infinity,
                              webHtmlElementStrategy:
                              WebHtmlElementStrategy.prefer,
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.broken_image_outlined,
                                        color: Colors.white70,
                                        size: 52,
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        'Unable to load image',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.black.withValues(alpha: .55),
                      shape: const CircleBorder(),
                      child: IconButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                        tooltip: 'Close',
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .55),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${currentIndex + 1} / ${photos.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (photos.length > 1)
                    Positioned(
                      left: 12,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Material(
                          color: Colors.black.withValues(alpha: .45),
                          shape: const CircleBorder(),
                          child: IconButton(
                            onPressed: currentIndex > 0
                                ? () {
                              controller.previousPage(
                                duration:
                                const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                              );
                            }
                                : null,
                            icon: const Icon(
                              Icons.chevron_left_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (photos.length > 1)
                    Positioned(
                      right: 12,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Material(
                          color: Colors.black.withValues(alpha: .45),
                          shape: const CircleBorder(),
                          child: IconButton(
                            onPressed: currentIndex < photos.length - 1
                                ? () {
                              controller.nextPage(
                                duration:
                                const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                              );
                            }
                                : null,
                            icon: const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // ============================================================
  // ANALYTICS SECTION
  // ============================================================

  Widget _buildAnalyticsSection(
      List<MaintenanceIssue> allIssues,
      double width,
      ) {
    final issues = _filterIssues(allIssues);
    final isCompact = width < 950;

    if (isCompact) {
      return Column(
        children: [
          _buildAnalyticsCard(child: _buildMaintenanceStats(issues)),
          const SizedBox(height: 20),
          _buildAnalyticsCard(child: _buildSubjectsRanking(issues)),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildAnalyticsCard(child: _buildMaintenanceStats(issues)),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _buildAnalyticsCard(child: _buildSubjectsRanking(issues)),
        ),
      ],
    );
  }

  Widget _buildAnalyticsCard({required Widget child}) {
    return Container(decoration: _cardDecoration(), child: child);
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.grey.shade200),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.025),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  // ============================================================
  // MAINTENANCE STATS
  // ============================================================

  Widget _buildMaintenanceStats(List<MaintenanceIssue> issues) {
    final openCount = issues.where((i) => i.status == 'open').length;
    final inProgressCount =
        issues.where((i) => i.status == 'in_progress').length;
    final resolvedCount =
        issues.where((i) => i.status == 'resolved').length;

    final totalCount = issues.length;
    final resolutionRate = totalCount == 0
        ? 0
        : ((resolvedCount / totalCount) * 100).round();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnalyticsHeader(
            icon: Icons.analytics_outlined,
            title: 'Overview',
            subtitle: 'Current maintenance performance',
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildOverviewHighlight(
                  title: 'Total Issues',
                  value: totalCount.toString(),
                  icon: Icons.build_outlined,
                  color: Palette.nestBlue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildOverviewHighlight(
                  title: 'Resolution',
                  value: '$resolutionRate%',
                  icon: Icons.check_circle_outline,
                  color: Colors.green.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          _buildStatItem(
            'Open',
            openCount.toString(),
            Icons.error_outline,
            Colors.red.shade600,
          ),
          const SizedBox(height: 10),
          _buildStatItem(
            'In Progress',
            inProgressCount.toString(),
            Icons.pending_actions_outlined,
            Colors.orange.shade600,
          ),
          const SizedBox(height: 10),
          _buildStatItem(
            'Resolved',
            resolvedCount.toString(),
            Icons.check_circle_outline,
            Colors.green.shade600,
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Palette.nestBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: Palette.nestBlue),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 9,
                  color: Color(0xFF8A94A3),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewHighlight({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFF7A8493),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      String title,
      String value,
      IconData icon,
      Color color,
      ) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF7A8493),
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // TOP ISSUE / SUBJECT RANKING
  // ============================================================

  Widget _buildSubjectsRanking(List<MaintenanceIssue> issues) {
    if (issues.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAnalyticsHeader(
              icon: Icons.leaderboard_outlined,
              title: 'Top Issues',
              subtitle: 'Most frequently reported issues',
            ),
            const SizedBox(height: 25),
            const Center(
              child: Text(
                'No issues to rank',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 15),
          ],
        ),
      );
    }

    final Map<String, int> subjectCount = {};

    for (final issue in issues) {
      final subject = issue.subject.trim();
      if (subject.isNotEmpty) {
        subjectCount[subject] = (subjectCount[subject] ?? 0) + 1;
      }
    }

    final sortedSubjects = subjectCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topSubjects = sortedSubjects.length > 5
        ? sortedSubjects.take(5).toList()
        : sortedSubjects;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnalyticsHeader(
            icon: Icons.leaderboard_outlined,
            title: 'Top Issues',
            subtitle: 'Most frequently reported issues',
          ),
          const SizedBox(height: 18),
          ...topSubjects.asMap().entries.map((entry) {
            final index = entry.key;
            final subjectEntry = entry.value;
            final percentage =
            ((subjectEntry.value / issues.length) * 100).round();

            return _buildRankingItem(
              index: index,
              subject: subjectEntry.key,
              count: subjectEntry.value,
              percentage: percentage,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRankingItem({
    required int index,
    required String subject,
    required int count,
    required int percentage,
  }) {
    Color rankColor;
    if (index == 0) {
      rankColor = Colors.amber.shade600;
    } else if (index == 1) {
      rankColor = Colors.grey.shade500;
    } else if (index == 2) {
      rankColor = Colors.brown.shade400;
    } else {
      rankColor = Colors.grey.shade300;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: rankColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: index >= 3 ? Colors.black54 : Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    minHeight: 4,
                    backgroundColor: Colors.grey.shade100,
                    color: Palette.nestBlue,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                count.toString(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F2937),
                ),
              ),
              Text(
                '$percentage%',
                style: const TextStyle(
                  fontSize: 9,
                  color: Color(0xFF8A94A3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyMaintenanceState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 45, horizontal: 20),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Palette.nestBlue.withValues(alpha: 0.10),
                    Palette.nestBlue.withValues(alpha: 0.02),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _hasActiveFilters
                    ? Icons.filter_alt_off_outlined
                    : Icons.build_outlined,
                size: 34,
                color: Palette.nestBlue,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _hasActiveFilters
                  ? 'No matching issues'
                  : 'No maintenance issues',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _hasActiveFilters
                  ? 'Try changing your filters to see more results.'
                  : 'Maintenance issues will appear here when reported.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                height: 1.4,
                color: Color(0xFF8A94A3),
              ),
            ),
            if (_hasActiveFilters) ...[
              const SizedBox(height: 14),
              TextButton(
                onPressed: _clearFilters,
                child: const Text(
                  'Clear Filters',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Palette.nestBlue,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildMaintenanceError(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_outlined,
                color: Colors.red,
                size: 35,
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              'Unable to load maintenance issues',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Something went wrong while loading your maintenance data.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Color(0xFF8A94A3)),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Palette.nestBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
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
  // STATUS DIALOG
  // ============================================================

  Future<void> _showUpdateStatusDialog(MaintenanceIssue issue) async {
    if (!_isMounted || !mounted) return;

    String? selectedStatus = issue.status;

    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return _withScaledText(
          dialogContext,
          StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                titlePadding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
                contentPadding: const EdgeInsets.fromLTRB(22, 8, 22, 10),
                actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 15),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Palette.nestBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(
                        Icons.edit_outlined,
                        color: Palette.nestBlue,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Update Status',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ISSUE',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF98A2B3),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            issue.subject,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Select new status',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475467),
                      ),
                    ),
                    const SizedBox(height: 8),

                    RadioGroup<String>(
                      groupValue: selectedStatus,
                      onChanged: (value) {
                        setDialogState(() => selectedStatus = value);
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildStatusRadioOption('open', 'Open'),
                          _buildStatusRadioOption('in_progress', 'In Progress'),
                          _buildStatusRadioOption('resolved', 'Resolved'),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                  ElevatedButton(
                    onPressed:
                    selectedStatus != null && selectedStatus != issue.status
                        ? () {
                      Navigator.of(dialogContext).pop();
                      _updateIssueStatus(
                        issue.id,
                        selectedStatus!,
                      );
                    }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Palette.nestBlue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade200,
                      disabledForegroundColor: Colors.grey,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Update',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildStatusRadioOption(String value, String label) {
    final color = _getStatusColor(value);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: RadioListTile<String>(
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: 7),
        title: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        value: value,
        activeColor: color,
      ),
    );
  }

  // ============================================================
  // STATUS COLOR
  // ============================================================

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'open':
        return Colors.red.shade600;
      case 'in_progress':
        return Colors.orange.shade600;
      case 'resolved':
        return Colors.green.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  // ============================================================
  // UPDATE MAINTENANCE ISSUE STATUS
  // ============================================================

  Future<void> _updateIssueStatus(int issueId, String newStatus) async {
    if (!_isMounted || !mounted) return;

    final readableStatus = newStatus.replaceAll('_', ' ');

    try {
      _showSafeSnackBar(
        'Updating status to $readableStatus...',
        backgroundColor: Palette.nestBlue,
      );

      await apiService.updateMaintenanceIssueStatus(issueId, newStatus);

      if (!_isMounted || !mounted) return;

      await _loadData();

      if (!_isMounted || !mounted) return;

      _showSafeSnackBar(
        'Issue status updated to "$readableStatus" successfully!',
        backgroundColor: Colors.green,
      );

      if (newStatus == 'resolved') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_isMounted && mounted) {
            _showSuccessDialog(
              'Issue Resolved',
              'Maintenance issue #$issueId has been marked as resolved.',
            );
          }
        });
      }
    } catch (e) {
      if (!_isMounted || !mounted) return;
      _showSafeSnackBar(
        'Failed to update status: ${e.toString()}',
        backgroundColor: Colors.red,
      );
    }
  }

  // ============================================================
  // SUCCESS DIALOG
  // ============================================================

  Future<void> _showSuccessDialog(String title, String message) async {
    if (!_isMounted || !mounted) return;

    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return _withScaledText(
          dialogContext,
          AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
            contentPadding: const EdgeInsets.fromLTRB(22, 8, 22, 10),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 15),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                height: 1.5,
                color: Color(0xFF667085),
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Themed full-page loading screen for MaintenancePage.
// Matches the Documents page loader: orbiting rings, breathing
// core, cycling messages, and a progress bar.
// ═══════════════════════════════════════════════════════════════
class _MaintenanceLoader extends StatefulWidget {
  const _MaintenanceLoader({
    this.messages = const [
      'Loading maintenance data...',
      'Fetching your reports...',
      'Checking status updates...',
      'Almost ready...',
    ],
  });

  final List<String> messages;

  @override
  State<_MaintenanceLoader> createState() => _MaintenanceLoaderState();
}

class _MaintenanceLoaderState extends State<_MaintenanceLoader>
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
      color: const Color(0xFFF4F7FB),
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
              const SizedBox(height: 36),
              _buildWordmark(blue),
              const SizedBox(height: 14),
              _buildMessage(),
              const SizedBox(height: 24),
              _buildProgressBar(blue),
              const SizedBox(height: 18),
              _buildDots(blue),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrbit(Color blue) {
    return SizedBox(
      width: 170,
      height: 170,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Expanding halo rings
          ...List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                final t = (_pulse.value + index / 3) % 1.0;
                final size = 84 + (t * 84);

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

          // Counter-rotating dotted ring
          RotationTransition(
            turns: ReverseAnimation(_spin),
            child: CustomPaint(
              size: const Size(152, 152),
              painter: _MaintenanceLoaderDotsPainter(color: blue),
            ),
          ),

          // Spinning gradient arc
          RotationTransition(
            turns: _spin,
            child: CustomPaint(
              size: const Size(128, 128),
              painter: _MaintenanceLoaderArcPainter(color: blue),
            ),
          ),

          // Breathing core
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
              width: 74,
              height: 74,
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
                    blurRadius: 26,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.build_rounded,
                color: Colors.white,
                size: 30,
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
          'MAINTENANCE',
          style: TextStyle(
            fontSize: 15,
            letterSpacing: 6,
            fontWeight: FontWeight.w700,
            fontFamily: 'SF-Pro-Text-Bold',
            color: blue,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'PROPERTY SERVICE REQUESTS',
          style: TextStyle(
            fontSize: 8,
            letterSpacing: 2.5,
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
      width: 210,
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
            final intensity =
            (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);
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
class _MaintenanceLoaderArcPainter extends CustomPainter {
  const _MaintenanceLoaderArcPainter({required this.color});

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
  bool shouldRepaint(covariant _MaintenanceLoaderArcPainter oldDelegate) =>
      oldDelegate.color != color;
}

// ── Fading dotted ring ─────────────────────────────────────────
class _MaintenanceLoaderDotsPainter extends CustomPainter {
  const _MaintenanceLoaderDotsPainter({
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

      canvas.drawCircle(Offset(0, -radius), 1.6, paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MaintenanceLoaderDotsPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.dotCount != dotCount;
}