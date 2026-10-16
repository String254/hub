import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get_utils/src/extensions/string_extensions.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hub/config/config.dart';
import 'package:hub/models/models.dart';
import 'package:hub/pages/pages.dart';
import 'package:hub/services/services.dart';

@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  final Color success, warning, danger, info;
  final Color successBg, warningBg, dangerBg, infoBg;

  const StatusColors({
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.successBg,
    required this.warningBg,
    required this.dangerBg,
    required this.infoBg,
  });

  static const light = StatusColors(
    success: Color(0xFF15803D),
    warning: Color(0xFFB45309),
    danger: Color(0xFFB91C1C),
    info: Color(0xFF1D4ED8),
    successBg: Color(0xFFDCFCE7),
    warningBg: Color(0xFFFEF3C7),
    dangerBg: Color(0xFFFEE2E2),
    infoBg: Color(0xFFDBEAFE),
  );

  static const dark = StatusColors(
    success: Color(0xFF4ADE80),
    warning: Color(0xFFFBBF24),
    danger: Color(0xFFF87171),
    info: Color(0xFF60A5FA),
    successBg: Color(0xFF052E16),
    warningBg: Color(0xFF3B1D05),
    dangerBg: Color(0xFF450A0A),
    infoBg: Color(0xFF0A1E45),
  );

  @override
  StatusColors copyWith({
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? successBg,
    Color? warningBg,
    Color? dangerBg,
    Color? infoBg,
  }) =>
      StatusColors(
        success: success ?? this.success,
        warning: warning ?? this.warning,
        danger: danger ?? this.danger,
        info: info ?? this.info,
        successBg: successBg ?? this.successBg,
        warningBg: warningBg ?? this.warningBg,
        dangerBg: dangerBg ?? this.dangerBg,
        infoBg: infoBg ?? this.infoBg,
      );

  @override
  StatusColors lerp(ThemeExtension<StatusColors>? other, double t) {
    if (other is! StatusColors) return this;
    return StatusColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
      successBg: Color.lerp(successBg, other.successBg, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
      dangerBg: Color.lerp(dangerBg, other.dangerBg, t)!,
      infoBg: Color.lerp(infoBg, other.infoBg, t)!,
    );
  }
}

extension StatusColorsX on BuildContext {
  StatusColors get status {
    final ext = Theme.of(this).extension<StatusColors>();
    if (ext != null) return ext;
    return Theme.of(this).brightness == Brightness.dark
        ? StatusColors.dark
        : StatusColors.light;
  }
}

class Accent {
  static const purple = Color(0xFF7C3AED);
  static const teal = Color(0xFF0D9488);
  static const indigo = Color(0xFF4F46E5);
  static const orange = Color(0xFFEA580C);
  static const pink = Color(0xFFDB2777);
}

class TenantPortalPage extends StatefulWidget {
  final TenantPortalService service;

  const TenantPortalPage({
    super.key,
    required this.service,
  });

  @override
  State<TenantPortalPage> createState() => _TenantPortalPageState();
}

class _TenantPortalPageState extends State<TenantPortalPage> {
  int _selectedIndex = 0;

  TenantPortalUser? _tenant;
  TenantDashboard? _dashboard;

  List<TenantInvoice> _invoices = [];
  List<TenantDocument> _documents = [];

  bool _isInitialLoading = true;
  bool _isLoadingDashboard = false;
  bool _isLoadingInvoices = false;
  bool _isLoadingDocuments = false;
  bool _isPaymentInProgress = false;

  String? _initialError;
  String? _dashboardError;
  String? _invoicesError;
  String? _documentsError;

  String _invoiceFilter = 'all';
  String _invoiceSearch = '';
  String _paymentSearch = '';
  String _documentFilter = 'all';

  final TextEditingController _invoiceSearchController =
  TextEditingController();
  final TextEditingController _paymentSearchController = TextEditingController();

  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'en_KE',
    symbol: 'Ksh ',
    decimalDigits: 0,
  );

  final DateFormat _dateFormatter = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _initializePortal();
  }

  @override
  void dispose() {
    _invoiceSearchController.dispose();
    _paymentSearchController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // RESPONSIVE TYPE HELPER
  // -------------------------------------------------------------------------

  double _fs(double base) {
    final w = MediaQuery.of(context).size.width;
    if (w < 340) return base * 0.88;
    if (w < 360) return base * 0.94;
    if (w >= 900) return base * 1.06;
    if (w >= 600) return base * 1.02;
    return base;
  }

  // -------------------------------------------------------------------------
  // INITIALIZATION
  // -------------------------------------------------------------------------

  Future<void> _initializePortal() async {
    try {
      final hasSession = await TenantPortalStorage.hasValidSession();

      if (!hasSession) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SignInScreen()),
              (route) => false,
        );
        return;
      }

      final tenant = await widget.service.fetchMe();

      if (!mounted) return;

      setState(() {
        _tenant = tenant;
        _isInitialLoading = false;
        _initialError = null;
      });

      await Future.wait([
        _loadDashboard(),
        _loadInvoices(),
        _loadDocuments(),
      ]);
    } on TenantPortalAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _isInitialLoading = false;
        _initialError = e.message;
      });

      await TenantPortalStorage.clearSession();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SignInScreen()),
            (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isInitialLoading = false;
        _initialError = _cleanError(e);
      });
    }
  }

  Future<void> _loadDashboard() async {
    if (mounted) {
      setState(() {
        _isLoadingDashboard = true;
        _dashboardError = null;
      });
    }

    try {
      final dashboard = await widget.service.fetchDashboard();
      if (!mounted) return;
      setState(() {
        _dashboard = dashboard;
        _isLoadingDashboard = false;
      });
    } on TenantPortalAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingDashboard = false;
        _dashboardError = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingDashboard = false;
        _dashboardError = _cleanError(e);
      });
    }
  }

  Future<void> _loadInvoices() async {
    if (mounted) {
      setState(() {
        _isLoadingInvoices = true;
        _invoicesError = null;
      });
    }

    try {
      final invoices = await widget.service.fetchInvoices();
      if (!mounted) return;
      setState(() {
        _invoices = invoices;
        _isLoadingInvoices = false;
      });
    } on TenantPortalAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingInvoices = false;
        _invoicesError = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingInvoices = false;
        _invoicesError = _cleanError(e);
      });
    }
  }

  Future<void> _loadDocuments() async {
    if (mounted) {
      setState(() {
        _isLoadingDocuments = true;
        _documentsError = null;
      });
    }

    try {
      final documents = await widget.service.fetchDocuments();
      if (!mounted) return;
      setState(() {
        _documents = documents;
        _isLoadingDocuments = false;
      });
    } on TenantPortalAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingDocuments = false;
        _documentsError = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingDocuments = false;
        _documentsError = _cleanError(e);
      });
    }
  }

  Future<void> _refreshPortal() async {
    HapticFeedback.selectionClick();
    await Future.wait([
      _loadDashboard(),
      _loadInvoices(),
      _loadDocuments(),
    ]);
    if (!mounted) return;
    _showSnackBar('Up to date');
  }

  // -------------------------------------------------------------------------
  // LOGOUT
  // -------------------------------------------------------------------------

  Future<void> _logout() async {
    HapticFeedback.mediumImpact();

    final isDesktop = MediaQuery.of(context).size.width >= 1000;
    final shouldLogout = isDesktop
        ? await _confirmLogoutDialog()
        : await _confirmLogoutSheet();

    if (shouldLogout != true) return;

    await widget.service.logout();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SignInScreen()),
          (route) => false,
    );
  }

  Future<bool?> _confirmLogoutDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to access your tenant portal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmLogoutSheet() {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            28 + MediaQuery.of(context).padding.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 22),
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: .08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout_rounded, color: Colors.red),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sign out?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'You will need to sign in again to access your tenant portal.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Sign Out'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // NAVIGATION
  // -------------------------------------------------------------------------

  void _selectPage(int index) {
    final safeIndex = index.clamp(0, 4);
    if (safeIndex == _selectedIndex) return;

    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = safeIndex);

    if (safeIndex == 1 && _invoices.isEmpty && !_isLoadingInvoices) {
      _loadInvoices();
    }
    if (safeIndex == 3 && _documents.isEmpty && !_isLoadingDocuments) {
      _loadDocuments();
    }
  }

  void _openProfile() {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: const Color(0xFFF7F9FC),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            title: Text(
              'Profile',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: _fs(19),
              ),
            ),
          ),
          body: _buildProfile(),
        ),
      ),
    );
  }

  String get _pageTitle {
    switch (_selectedIndex) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Invoices';
      case 2:
        return 'Payments';
      case 3:
        return 'Documents';
      case 4:
        return 'Maintenance';
      default:
        return 'Dashboard';
    }
  }

  // -------------------------------------------------------------------------
  // BUILD
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        body: _buildInitialLoading(),
      );
    }

    if (_initialError != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        body: _buildInitialError(),
      );
    }

    final isDesktop = MediaQuery.of(context).size.width >= 1000;
    return isDesktop ? _buildDesktopLayout() : _buildMobileLayout();
  }

  // -------------------------------------------------------------------------
  // DESKTOP
  // -------------------------------------------------------------------------

  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: Row(
        children: [
          _buildDesktopSidebar(),
          Expanded(
            child: Column(
              children: [
                _buildDesktopTopBar(),
                Expanded(child: _buildCurrentPage()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopSidebar() {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE8ECF2))),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Palette.nestBlue, Color(0xFF4F7BE5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.home_work_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 11),
                  const Text(
                    'Kejahub',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
            _buildDesktopTenantHeader(),
            const SizedBox(height: 18),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    _desktopNavItem(
                      index: 0,
                      icon: Icons.dashboard_rounded,
                      label: 'Dashboard',
                    ),
                    _desktopNavItem(
                      index: 1,
                      icon: Icons.receipt_long_rounded,
                      label: 'Invoices',
                    ),
                    _desktopNavItem(
                      index: 2,
                      icon: Icons.payments_rounded,
                      label: 'Payments',
                    ),
                    _desktopNavItem(
                      index: 3,
                      icon: Icons.folder_rounded,
                      label: 'Documents',
                    ),
                    _desktopNavItem(
                      index: 4,
                      icon: Icons.build_circle_rounded,
                      label: 'Maintenance',
                    ),
                    _desktopNavItem(
                      index: 5,
                      icon: Icons.person_rounded,
                      label: 'Profile',
                      onTapOverride: _openProfile,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: _desktopLogoutButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopTenantHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Palette.nestBlue.withValues(alpha: .06),
              Palette.nestBlue.withValues(alpha: .02),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Palette.nestBlue.withValues(alpha: .10)),
        ),
        child: Row(
          children: [
            _buildAvatar(name: _tenant?.name ?? 'Tenant', radius: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _firstName(_tenant?.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _tenant?.email ?? 'Tenant account',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _desktopNavItem({
    required int index,
    required IconData icon,
    required String label,
    VoidCallback? onTapOverride,
  }) {
    final selected = onTapOverride == null && _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTapOverride ?? () => _selectPage(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? Palette.nestBlue.withValues(alpha: .10)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? Palette.nestBlue : Colors.grey.shade600,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Palette.nestBlue : Colors.grey.shade700,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                if (selected) ...[
                  const Spacer(),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: Palette.nestBlue,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _desktopLogoutButton() {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _logout,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: .05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.logout_rounded, size: 20, color: Colors.red.shade600),
            const SizedBox(width: 12),
            Text(
              'Sign Out',
              style: TextStyle(
                color: Colors.red.shade600,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopTopBar() {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE8ECF2))),
      ),
      child: Row(
        children: [
          Text(
            _pageTitle,
            style: TextStyle(
              fontSize: _fs(21),
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refreshPortal,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _openProfile,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: _buildAvatar(name: _tenant?.name ?? 'Tenant', radius: 20),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _firstName(_tenant?.name),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // MOBILE — tuned for thumbs
  // -------------------------------------------------------------------------

  Widget _buildMobileLayout() {
    final isDashboard = _selectedIndex == 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        titleSpacing: 16,
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, .1),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: isDashboard
              ? Column(
            key: const ValueKey('greeting'),
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    _greeting(),
                    style: TextStyle(
                      fontSize: _fs(16),
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    _firstName(_tenant?.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: _fs(16),
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ],
          )
              : Text(
            key: ValueKey('title-$_selectedIndex'),
            _pageTitle,
            style: TextStyle(
              fontSize: _fs(20),
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refreshPortal,
            icon: const Icon(Icons.refresh_rounded),
          ),
          if (!isDashboard)
            Padding(
              padding: const EdgeInsets.only(right: 4, left: 2),
              child: InkWell(
                onTap: _openProfile,
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: _buildAvatar(
                    name: _tenant?.name ?? 'Tenant',
                    radius: 16,
                  ),
                ),
              ),
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'profile') {
                _openProfile();
              } else if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline_rounded),
                    SizedBox(width: 10),
                    Text('Profile'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded),
                    SizedBox(width: 10),
                    Text('Sign Out'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 2),
        ],
      ),
      body: _buildCurrentPage(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectPage,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        height: 68,
        indicatorColor: Palette.nestBlue.withValues(alpha: .14),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Invoices',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments_rounded),
            label: 'Payments',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder_rounded),
            label: 'Documents',
          ),
          NavigationDestination(
            icon: Icon(Icons.build_outlined),
            selectedIcon: Icon(Icons.build_rounded),
            label: 'Repairs',
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  // -------------------------------------------------------------------------
  // CURRENT PAGE
  // -------------------------------------------------------------------------

  Widget _buildCurrentPage() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboard();
      case 1:
        return _buildInvoices();
      case 2:
        return _buildPayments();
      case 3:
        return _buildDocuments();
      case 4:
        return _buildMaintenancePlaceholder();
      default:
        return _buildDashboard();
    }
  }

  // -------------------------------------------------------------------------
  // CAPTION
  // -------------------------------------------------------------------------

  Widget _buildCaption(String text, {VoidCallback? onRefresh}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: _fs(12.5),
              height: 1.35,
            ),
          ),
        ),
        if (onRefresh != null)
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Refresh',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 20),
          ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // DASHBOARD
  // -------------------------------------------------------------------------

  Widget _buildDashboard() {
    if (_isLoadingDashboard && _dashboard == null) {
      return _buildDashboardLoading();
    }

    if (_dashboardError != null && _dashboard == null) {
      return _buildErrorState(
        title: 'Unable to load dashboard',
        message: _dashboardError!,
        onRetry: _loadDashboard,
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshPortal,
      edgeOffset: 8,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 1000;

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 28 : 16,
              isDesktop ? 28 : 16,
              isDesktop ? 28 : 16,
              isDesktop ? 28 : 24,
            ),
            children: [
              _FadeIn(
                child: _buildQuickActions(),
              ),
              const SizedBox(height: 20),
              _FadeIn(
                delay: const Duration(milliseconds: 80),
                child: _buildDashboardBalanceCard(),
              ),
              const SizedBox(height: 20),
              _FadeIn(
                delay: const Duration(milliseconds: 160),
                child: _buildFinancialOverview(),
              ),
              const SizedBox(height: 20),
              if (isDesktop)
                _FadeIn(
                  delay: const Duration(milliseconds: 240),
                  child: _buildDesktopDashboardBottom(),
                )
              else ...[
                _FadeIn(
                  delay: const Duration(milliseconds: 240),
                  child: _buildCurrentInvoiceSection(),
                ),
                const SizedBox(height: 16),
                _FadeIn(
                  delay: const Duration(milliseconds: 320),
                  child: _buildRecentPaymentsCard(),
                ),
                const SizedBox(height: 16),
                _FadeIn(
                  delay: const Duration(milliseconds: 400),
                  child: _buildMaintenanceSummary(),
                ),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
  }

  // -------- Balance hero --------------------------------------------------

  Widget _buildDashboardBalanceCard() {
    final outstanding = _totalOutstanding;
    final next = _nextDueInvoice;

    final daysLeft = next?.dueDate?.difference(DateTime.now()).inDays;
    final isOverdue = daysLeft != null && daysLeft < 0;
    final isUrgent = daysLeft != null && daysLeft >= 0 && daysLeft <= 3;

    final s = context.status;
    final List<Color> gradient;

    if (outstanding <= 0) {
      gradient = [const Color(0xFF0F766E), const Color(0xFF115E59)];
    } else if (isOverdue) {
      gradient = [s.danger, Color.lerp(s.danger, Colors.black, .22)!];
    } else if (isUrgent) {
      gradient = [s.warning, Color.lerp(s.warning, Colors.black, .18)!];
    } else {
      gradient = [Palette.nestBlue, const Color(0xFF2A4F9E)];
    }

    final String subtitle;
    final IconData? subtitleIcon;

    if (outstanding <= 0) {
      subtitle = 'Your account is up to date.';
      subtitleIcon = Icons.verified_rounded;
    } else if (daysLeft == null) {
      subtitle = 'Please clear your outstanding balance.';
      subtitleIcon = null;
    } else if (daysLeft < 0) {
      subtitle =
      '${-daysLeft} day${-daysLeft == 1 ? '' : 's'} overdue — please pay now.';
      subtitleIcon = Icons.error_rounded;
    } else if (daysLeft == 0) {
      subtitle = 'Payment is due today.';
      subtitleIcon = Icons.schedule_rounded;
    } else if (daysLeft <= 3) {
      subtitle = 'Due in $daysLeft day${daysLeft == 1 ? '' : 's'}.';
      subtitleIcon = Icons.schedule_rounded;
    } else {
      subtitle = 'Next payment due in $daysLeft days.';
      subtitleIcon = null;
    }

    final showPay = outstanding > 0 && next != null;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: .28),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Outstanding balance',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _currency(outstanding),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: _fs(20),
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (subtitleIcon != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 1, right: 6),
                            child: Icon(
                              subtitleIcon,
                              size: 15,
                              color: Colors.white,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            subtitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .16),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  outstanding > 0
                      ? Icons.account_balance_wallet_rounded
                      : Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
          if (showPay) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: FilledButton.icon(
                    onPressed: () => _payInvoice(next),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: gradient.first,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.lock_outline_rounded, size: 18),
                    label: const Text(
                      'Pay Now',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    onPressed: () => _selectPage(1),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white60),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Details',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // -------- Financial overview --------------------------------------------

  Widget _buildFinancialOverview() {
    final totalInvoices = _invoices.length;
    final paidInvoices = _invoices.where((i) => i.isPaid).length;
    final totalPaid = _invoices.fold<double>(0, (sum, i) => sum + i.paid);
    final outstanding = _totalOutstanding;

    final s = context.status;

    final cards = [
      _dashboardMetric(
        title: 'Invoices',
        value: totalInvoices.toString(),
        icon: Icons.receipt_long_rounded,
        color: Palette.nestBlue,
      ),
      _dashboardMetric(
        title: 'Total paid',
        value: _currency(totalPaid),
        icon: Icons.check_circle_rounded,
        color: s.success,
      ),
      _dashboardMetric(
        title: 'Outstanding',
        value: _currency(outstanding),
        icon: Icons.pending_actions_rounded,
        color: outstanding > 0 ? s.danger : s.success,
      ),
      _dashboardMetric(
        title: 'Paid invoices',
        value: paidInvoices.toString(),
        icon: Icons.verified_rounded,
        color: Accent.teal,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _accentBar(Accent.purple),
            const SizedBox(width: 8),
            Text(
              'Financial overview',
              style: TextStyle(
                fontSize: _fs(15.5),
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 650;

            if (!isWide) {
              final itemWidth = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: cards
                    .map((c) => SizedBox(width: itemWidth, child: c))
                    .toList(),
              );
            }

            return Row(
              children: cards.map((card) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: card,
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _dashboardMetric({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: _fs(15),
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: _fs(11.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopDashboardBottom() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              _buildCurrentInvoiceSection(),
            ],
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            children: [
              _buildRecentPaymentsCard(),
              const SizedBox(height: 18),
              _buildMaintenanceSummary(),
            ],
          ),
        ),
      ],
    );
  }

  // -------- Current invoice -----------------------------------------------

  Widget _buildCurrentInvoiceSection() {
    if (_invoices.isEmpty) {
      return _dashboardSectionCard(
        title: 'Current invoice',
        icon: Icons.receipt_long_rounded,
        accent: Palette.nestBlue,
        child: _emptyInline('No invoices available yet.'),
      );
    }

    final sorted = [..._invoices]..sort((a, b) {
      final ad = a.invoiceDate;
      final bd = b.invoiceDate;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    });

    final invoice = sorted.first;
    final st = _invoiceStatus(invoice);
    final canPay = !invoice.isPaid;

    return _dashboardSectionCard(
      title: 'Current invoice',
      icon: Icons.receipt_long_rounded,
      accent: Palette.nestBlue,
      trailing: TextButton(
        onPressed: () => _selectPage(1),
        child: const Text('View all'),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showInvoiceDetails(invoice),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: st.bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: st.fg.withValues(alpha: .18)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(st.icon, color: st.fg),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'INV-${invoice.reference.toString().split('.').first}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          invoice.formattedDueDate,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        invoice.formattedAmount,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: _fs(14),
                        ),
                      ),
                      const SizedBox(height: 5),
                      _statusBadgeRich(st),
                    ],
                  ),
                ],
              ),
              if (canPay) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _payInvoice(invoice),
                    style: FilledButton.styleFrom(
                      backgroundColor: Palette.nestBlue,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.lock_outline_rounded, size: 17),
                    label: Text(
                      'Pay ${invoice.formattedOutstanding}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // -------- Quick actions -------------------------------------------------

  Widget _buildQuickActions() {
    return _dashboardSectionCard(
      title: 'Quick actions',
      icon: Icons.flash_on_rounded,
      accent: Accent.purple,
      child: Row(
        children: [
          Expanded(
            child: _quickAction(
              icon: Icons.receipt_long_rounded,
              title: 'Invoices',
              color: Palette.nestBlue,
              onTap: () => _selectPage(1),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _quickAction(
              icon: Icons.folder_rounded,
              title: 'Documents',
              color: Accent.purple,
              onTap: () => _selectPage(3),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _quickAction(
              icon: Icons.build_rounded,
              title: 'Repairs',
              color: Accent.orange,
              onTap: () => _selectPage(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: .18)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: _fs(11.5),
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------- Recent payments -----------------------------------------------

  Widget _buildRecentPaymentsCard() {
    final payments = _allPayments.take(5).toList();

    return _dashboardSectionCard(
      title: 'Recent payments',
      icon: Icons.payments_rounded,
      accent: context.status.success,
      trailing: TextButton(
        onPressed: () => _selectPage(2),
        child: const Text('View all'),
      ),
      child: payments.isEmpty
          ? _emptyInline('No payments recorded yet.')
          : Column(
        children: payments
            .map(
              (payment) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _paymentListTile(payment),
          ),
        )
            .toList(),
      ),
    );
  }

  Widget _paymentListTile(_TenantPaymentRecord payment) {
    final s = context.status;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: s.successBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: s.success.withValues(alpha: .15)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.receipt_long_rounded, color: s.success, size: 20),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INV-${payment.invoiceReference.toString().split('.').first}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  payment.paymentDate != null
                      ? _formatDate(payment.paymentDate)
                      : 'Date unavailable',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _currency(payment.amount),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // -------- Maintenance summary -------------------------------------------

  Widget _buildMaintenanceSummary() {
    return _dashboardSectionCard(
      title: 'Maintenance',
      icon: Icons.build_circle_rounded,
      accent: Accent.orange,
      trailing: TextButton(
        onPressed: () => _selectPage(4),
        child: const Text('Open'),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Accent.orange.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Accent.orange.withValues(alpha: .18)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.build_rounded, color: Accent.orange),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Report an issue or check the status of your maintenance requests.',
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------- Small helpers -------------------------------------------------

  Widget _accentBar(Color color) {
    return Container(
      width: 4,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _dashboardSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    required Color accent,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 15, color: accent),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: _fs(14),
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // INVOICES
  // -------------------------------------------------------------------------

  List<TenantInvoice> get _filteredInvoices {
    final query = _invoiceSearch.trim().toLowerCase();

    return _invoices.where((invoice) {
      final matchesFilter = switch (_invoiceFilter) {
        'paid' => invoice.isPaid,
        'partial' => invoice.isPartial,
        'unpaid' => invoice.isUnpaid,
        'overdue' => invoice.dueDate != null &&
            invoice.dueDate!.isBefore(DateTime.now()) &&
            !invoice.isPaid,
        _ => true,
      };

      if (!matchesFilter) return false;
      if (query.isEmpty) return true;

      return invoice.reference.toLowerCase().contains(query) ||
          invoice.statusLabel.toLowerCase().contains(query);
    }).toList();
  }

  Widget _buildInvoices() {
    if (_isLoadingInvoices && _invoices.isEmpty) {
      return _buildInvoicesLoading();
    }

    if (_invoicesError != null && _invoices.isEmpty) {
      return _buildErrorState(
        title: 'Unable to load invoices',
        message: _invoicesError!,
        onRetry: _loadInvoices,
      );
    }

    final invoices = _filteredInvoices;

    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.selectionClick();
        await _loadInvoices();
      },
      edgeOffset: 8,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          _FadeIn(child: _buildCaption(
            'Track your rental invoices and pay online.',
            onRefresh: _loadInvoices,
          )),
          const SizedBox(height: 14),
          _FadeIn(
            delay: const Duration(milliseconds: 60),
            child: _buildInvoiceSummary(),
          ),
          const SizedBox(height: 12),
          _FadeIn(
            delay: const Duration(milliseconds: 120),
            child: _buildInvoiceFilters(),
          ),
          const SizedBox(height: 18),
          if (_isLoadingInvoices && _invoices.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(minHeight: 3),
              ),
            ),
          if (invoices.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 40),
              child: _emptyState(
                icon: _invoiceSearch.trim().isNotEmpty
                    ? Icons.search_off_rounded
                    : Icons.receipt_long_rounded,
                title: _invoiceSearch.trim().isNotEmpty
                    ? 'No matching invoices'
                    : _invoiceFilter == 'all'
                    ? 'No invoices yet'
                    : 'No ${_invoiceFilter.capitalizeFirst} invoices',
                message: _invoiceSearch.trim().isNotEmpty
                    ? 'Try a different search term or clear your search.'
                    : _invoiceFilter == 'all'
                    ? 'Your monthly invoices will appear here once they are issued.'
                    : 'There are no invoices in this category.',
              ),
            )
          else
            ...invoices.asMap().entries.map(
                  (entry) => _FadeIn(
                delay: Duration(milliseconds: 80 * entry.key.clamp(0, 8)),
                child: _buildModernInvoiceCard(entry.value),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModernInvoiceCard(TenantInvoice invoice) {
    final status = invoice.status.toLowerCase();

    final bool isPaid = invoice.isPaid;
    final bool isPartial = invoice.isPartial;

    final Color statusColor;
    final Color statusBackground;
    final IconData statusIcon;
    final String statusText;

    if (isPaid) {
      statusColor = context.status.success;
      statusBackground = context.status.success.withValues(alpha: .10);
      statusIcon = Icons.check_circle_rounded;
      statusText = 'Paid';
    } else if (isPartial) {
      statusColor = context.status.warning;
      statusBackground = context.status.warning.withValues(alpha: .10);
      statusIcon = Icons.timelapse_rounded;
      statusText = 'Partially Paid';
    } else {
      statusColor = context.status.danger;
      statusBackground = context.status.danger.withValues(alpha: .10);
      statusIcon = Icons.pending_actions_rounded;
      statusText = status == 'overdue' ? 'Overdue' : 'Unpaid';
    }

    final bool isOverdue = !isPaid &&
        invoice.dueDate != null &&
        invoice.dueDate!.isBefore(DateTime.now());

    final Color accentColor =
    isOverdue ? context.status.danger : Palette.nestBlue;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOverdue
              ? context.status.danger.withValues(alpha: .30)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .035),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            HapticFeedback.selectionClick();
            _showInvoiceDetails(invoice);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: .09),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.receipt_long_rounded,
                        color: accentColor,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Invoice',
                            style: TextStyle(
                              fontSize: _fs(11.5),
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'INV-${invoice.reference.split('.').first}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: _fs(15),
                              fontWeight: FontWeight.w800,
                              color: Colors.grey.shade900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            invoice.formattedDueDate,
                            style: TextStyle(
                              fontSize: _fs(11.5),
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusBackground,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 14, color: statusColor),
                          const SizedBox(width: 5),
                          Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: _fs(11),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Invoice amount',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: _fs(11.5),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currency(invoice.amount),
                              style: TextStyle(
                                color: Colors.grey.shade900,
                                fontSize: _fs(20),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 38,
                        color: Colors.grey.shade200,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Outstanding',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: _fs(11.5),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currency(invoice.outstanding),
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: invoice.outstanding > 0
                                    ? context.status.danger
                                    : context.status.success,
                                fontSize: _fs(14),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _invoiceDetailItem(
                        icon: Icons.home_work_outlined,
                        label: 'Rent',
                        value: _currency(invoice.rent),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _invoiceDetailItem(
                        icon: Icons.miscellaneous_services_outlined,
                        label: 'Services',
                        value: _currency(invoice.service),
                      ),
                    ),
                  ],
                ),
                if (invoice.dueDate != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        isOverdue
                            ? Icons.warning_amber_rounded
                            : Icons.event_outlined,
                        size: 17,
                        color: isOverdue
                            ? context.status.danger
                            : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        isOverdue ? 'Overdue' : 'Due date',
                        style: TextStyle(
                          fontSize: _fs(11.5),
                          color: isOverdue
                              ? context.status.danger
                              : Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _formatInvoiceDate(invoice.dueDate!),
                        style: TextStyle(
                          fontSize: _fs(11.5),
                          color: isOverdue
                              ? context.status.danger
                              : Colors.grey.shade800,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _showInvoiceDetails(invoice);
                    },
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('View Invoice'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Palette.nestBlue,
                      side: BorderSide(
                        color: Palette.nestBlue.withValues(alpha: .25),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: TextStyle(
                        fontSize: _fs(13),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatInvoiceDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }

  Widget _invoiceDetailItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: Palette.nestBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: _fs(10.5),
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: _fs(11.5),
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceSummary() {
    final s = context.status;
    final total = _invoices.length;
    final paid = _invoices.where((i) => i.isPaid).length;
    final partial = _invoices.where((i) => i.isPartial).length;
    final unpaid = _invoices.where((i) => i.isUnpaid).length;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _smallStat('Total', total.toString(), Palette.nestBlue),
        _smallStat('Paid', paid.toString(), s.success),
        _smallStat('Partial', partial.toString(), s.warning),
        _smallStat('Unpaid', unpaid.toString(), s.danger),
      ],
    );
  }

  Widget _smallStat(String title, String value, Color color) {
    return Container(
      constraints: const BoxConstraints(minWidth: 108),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: _fs(17),
              height: 1.1,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: _fs(11.5),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceFilters() {
    final filters = [
      ('all', 'All'),
      ('unpaid', 'Unpaid'),
      ('partial', 'Partial'),
      ('paid', 'Paid'),
      ('overdue', 'Overdue'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: filters.map((filter) {
          final selected = _invoiceFilter == filter.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter.$2),
              selected: selected,
              onSelected: (_) {
                HapticFeedback.selectionClick();
                setState(() => _invoiceFilter = filter.$1);
              },
              labelStyle: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: _fs(12.5),
                color: selected ? Colors.white : Colors.grey.shade800,
              ),
              selectedColor: Palette.nestBlue,
              backgroundColor: Colors.white,
              side: BorderSide(
                color: selected ? Palette.nestBlue : Colors.grey.shade300,
              ),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // PAYMENTS
  // -------------------------------------------------------------------------

  List<_TenantPaymentRecord> get _allPayments {
    final payments = <_TenantPaymentRecord>[];
    for (final invoice in _invoices) {
      for (final receipt in invoice.receipts) {
        payments.add(
          _TenantPaymentRecord(
            id: receipt.id,
            amount: receipt.amount,
            paymentDate: receipt.paymentDate,
            reference: receipt.reference,
            invoiceReference: invoice.reference,
          ),
        );
      }
    }
    payments.sort((a, b) {
      final ad = a.paymentDate;
      final bd = b.paymentDate;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    });
    return payments;
  }

  List<_TenantPaymentRecord> get _filteredPayments {
    final query = _paymentSearch.trim().toLowerCase();
    if (query.isEmpty) return _allPayments;
    return _allPayments.where((payment) {
      return payment.invoiceReference.toLowerCase().contains(query) ||
          (payment.reference ?? '').toLowerCase().contains(query);
    }).toList();
  }

  Widget _buildPayments() {
    final s = context.status;
    final payments = _filteredPayments;
    final totalPaid = payments.fold<double>(0, (sum, p) => sum + p.amount);

    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.selectionClick();
        await _loadInvoices();
      },
      edgeOffset: 8,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          _FadeIn(child: _buildCaption(
            'Review your payment history.',
            onRefresh: _loadInvoices,
          )),
          const SizedBox(height: 12),
          _FadeIn(
            delay: const Duration(milliseconds: 60),
            child: Row(
              children: [
                Expanded(
                  child: _smallStat(
                    'Payments',
                    payments.length.toString(),
                    Accent.teal,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _smallStat(
                    'Total paid',
                    _currency(totalPaid),
                    s.success,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _FadeIn(
            delay: const Duration(milliseconds: 120),
            child: TextField(
              controller: _paymentSearchController,
              onChanged: (v) => setState(() => _paymentSearch = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search invoice no...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _paymentSearch.isNotEmpty
                    ? IconButton(
                  onPressed: () {
                    _paymentSearchController.clear();
                    setState(() => _paymentSearch = '');
                  },
                  icon: const Icon(Icons.clear_rounded),
                )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Palette.nestBlue, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (payments.isEmpty)
            _emptyState(
              icon: Icons.payments_rounded,
              title: 'No payments yet',
              message: 'Your payment history will appear here.',
            )
          else
            ...payments.asMap().entries.map(
                  (entry) => _FadeIn(
                delay: Duration(milliseconds: 60 * entry.key.clamp(0, 8)),
                child: _buildPaymentRow(entry.value),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(_TenantPaymentRecord payment) {
    final s = context.status;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: s.successBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.check_circle_rounded, color: s.success),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INV-${payment.invoiceReference.toString().split('.').first}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(payment.paymentDate),
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _currency(payment.amount),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: _fs(13.5),
              color: s.success,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // DOCUMENTS
  // -------------------------------------------------------------------------

  Widget _buildDocuments() {
    if (_isLoadingDocuments && _documents.isEmpty) {
      return _buildDocumentsLoading();
    }

    if (_documentsError != null && _documents.isEmpty) {
      return _buildErrorState(
        title: 'Unable to load documents',
        message: _documentsError!,
        onRetry: _loadDocuments,
      );
    }

    final filtered = _documents.where((d) {
      if (_documentFilter == 'all') return true;
      return d.category.toLowerCase() == _documentFilter;
    }).toList();

    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.selectionClick();
        await _loadDocuments();
      },
      edgeOffset: 8,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          _FadeIn(child: _buildCaption(
            'Access your tenancy and property documents.',
            onRefresh: _loadDocuments,
          )),
          const SizedBox(height: 12),
          _FadeIn(
            delay: const Duration(milliseconds: 60),
            child: _buildDocumentSummary(),
          ),
          const SizedBox(height: 16),
          _FadeIn(
            delay: const Duration(milliseconds: 120),
            child: _buildDocumentFilters(),
          ),
          const SizedBox(height: 14),
          if (filtered.isEmpty)
            _buildDocumentsEmpty()
          else
            ...filtered.asMap().entries.map(
                  (entry) => _FadeIn(
                delay: Duration(milliseconds: 60 * entry.key.clamp(0, 8)),
                child: _buildDocumentCard(entry.value),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDocumentSummary() {
    final invoices =
        _documents.where((d) => d.category.toLowerCase() == 'invoice').length;
    final receipts =
        _documents.where((d) => d.category.toLowerCase() == 'receipt').length;
    final leases =
        _documents.where((d) => d.category.toLowerCase() == 'lease').length;

    final cards = [
      _documentStat(
        'Total',
        _documents.length.toString(),
        Icons.folder_rounded,
        Palette.nestBlue,
      ),
      _documentStat(
        'Invoices',
        invoices.toString(),
        Icons.receipt_long_rounded,
        context.status.warning,
      ),
      _documentStat(
        'Receipts',
        receipts.toString(),
        Icons.payments_rounded,
        context.status.success,
      ),
      _documentStat(
        'Agreements',
        leases.toString(),
        Icons.description_rounded,
        Accent.purple,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        if (!isWide) {
          final itemWidth = (constraints.maxWidth - 10) / 2;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: cards
                .map((c) => SizedBox(width: itemWidth, child: c))
                .toList(),
          );
        }
        return Row(
          children: cards.map((card) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: card,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _documentStat(
      String label,
      String value,
      IconData icon,
      Color color,
      ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: _fs(17),
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: _fs(11),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentFilters() {
    final filters = [
      ('all', 'All'),
      ('lease', 'Leases'),
      ('invoice', 'Invoices'),
      ('receipt', 'Receipts'),
      ('document', 'Other'),
      ('photo', 'Photos'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: filters.map((filter) {
          final selected = _documentFilter == filter.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter.$2),
              selected: selected,
              onSelected: (_) {
                HapticFeedback.selectionClick();
                setState(() => _documentFilter = filter.$1);
              },
              labelStyle: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: _fs(12.5),
                color: selected ? Colors.white : Colors.grey.shade800,
              ),
              selectedColor: Accent.purple,
              backgroundColor: Colors.white,
              side: BorderSide(
                color: selected ? Accent.purple : Colors.grey.shade300,
              ),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDocumentCard(TenantDocument document) {
    final category = document.category.toLowerCase();
    IconData icon;
    Color color;

    switch (category) {
      case 'lease':
        icon = Icons.description_rounded;
        color = Accent.purple;
        break;
      case 'invoice':
        icon = Icons.receipt_long_rounded;
        color = context.status.warning;
        break;
      case 'receipt':
        icon = Icons.payments_rounded;
        color = context.status.success;
        break;
      case 'photo':
        icon = Icons.image_rounded;
        color = Accent.pink;
        break;
      default:
        icon = Icons.insert_drive_file_rounded;
        color = Palette.nestBlue;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap:
        document.fileUrl == null ? null : () => _openDocument(document),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _documentCategoryLabel(document.category),
                      style: TextStyle(
                        color: color,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    ...[
                      const SizedBox(height: 3),
                    ],
                    if (document.createdAt != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        _formatDocumentDate(document.createdAt.toString()),
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.open_in_new_rounded,
                  size: 18,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _documentCategoryLabel(String category) {
    switch (category.toLowerCase()) {
      case 'lease':
        return 'Lease Agreement';
      case 'invoice':
        return 'Invoice';
      case 'receipt':
        return 'Payment Receipt';
      case 'photo':
        return 'Property Photo';
      case 'document':
        return 'Document';
      default:
        if (category.isEmpty) return 'Document';
        return category[0].toUpperCase() + category.substring(1);
    }
  }

  String _formatDocumentDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return _dateFormatter.format(parsed.toLocal());
  }

  Future<void> _openDocument(TenantDocument document) async {
    final fileUrl = document.fileUrl;

    if (fileUrl == null || fileUrl.trim().isEmpty) {
      _showSnackBar('This document has no link.');
      return;
    }

    final uri = Uri.tryParse(fileUrl.trim());

    if (uri == null) {
      _showSnackBar('Invalid document URL.');
      return;
    }

    HapticFeedback.selectionClick();

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        _showSnackBar('Unable to open this document.');
      }
    } catch (e) {
      if (!mounted) return;

      _showSnackBar('Unable to open this document.');
    }
  }

  Widget _buildDocumentsEmpty() {
    return _emptyState(
      icon: Icons.folder_open_rounded,
      title: 'No documents found',
      message: _documentFilter == 'all'
          ? 'Your tenancy documents will appear here once uploaded.'
          : 'There are no documents in this category.',
    );
  }

  // -------------------------------------------------------------------------
  // MAINTENANCE / PROFILE
  // -------------------------------------------------------------------------

  Widget _buildMaintenancePlaceholder() {
    return TenantMaintenancePage(service: widget.service);
  }

  Widget _buildProfile() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        _FadeIn(child: _buildProfileHeader()),
        const SizedBox(height: 14),
        _FadeIn(
          delay: const Duration(milliseconds: 60),
          child: _profileCard(
            title: 'Contact information',
            icon: Icons.contact_page_rounded,
            accent: Palette.nestBlue,
            children: [
              _infoRow(
                Icons.person_outline_rounded,
                'Name',
                _tenant?.name ?? '—',
              ),
              _infoRow(Icons.email_outlined, 'Email', _tenant?.email ?? '—'),
              _infoRow(Icons.phone_outlined, 'Phone', _tenant?.phone ?? '—'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _FadeIn(
          delay: const Duration(milliseconds: 120),
          child: _profileCard(
            title: 'Property information',
            icon: Icons.home_work_rounded,
            accent: Accent.teal,
            children: [
              _infoRow(
                Icons.home_rounded,
                'Property',
                _tenant?.property.name ?? '—',
              ),
              _infoRow(
                Icons.location_on_outlined,
                'Location',
                _tenant?.property.location ?? '—',
              ),
              _infoRow(
                Icons.meeting_room_outlined,
                'Unit',
                _tenant?.unit.unitNumber ?? '—',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _FadeIn(
          delay: const Duration(milliseconds: 180),
          child: _profileCard(
            title: 'Account',
            icon: Icons.manage_accounts_rounded,
            accent: Accent.purple,
            children: [
              _infoRow(
                Icons.verified_user_outlined,
                'Portal status',
                'Active',
              ),
              _infoRow(
                Icons.folder_outlined,
                'Documents',
                '${_documents.length} available',
              ),
              _infoRow(
                Icons.receipt_long_outlined,
                'Invoices',
                '${_invoices.length} available',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: _logout,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            foregroundColor: Colors.red.shade600,
            side: BorderSide(color: Colors.red.shade200),
          ),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sign Out'),
        ),
      ],
    );
  }

  Widget _buildProfileHeader() {
    final s = context.status;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Palette.nestBlue.withValues(alpha: .10),
            Accent.purple.withValues(alpha: .06),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Palette.nestBlue.withValues(alpha: .15)),
      ),
      child: Row(
        children: [
          _buildAvatar(name: _tenant?.name ?? 'Tenant', radius: 32),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tenant?.name ?? 'Tenant',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: _fs(18),
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _tenant?.email ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: _fs(12),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: s.successBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: s.success.withValues(alpha: .20)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_rounded, size: 12, color: s.success),
                const SizedBox(width: 4),
                Text(
                  'Active',
                  style: TextStyle(
                    color: s.success,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: accent, size: 15),
              ),
              const SizedBox(width: 9),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: _fs(14),
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade500),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: _fs(12.5),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: _fs(12.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // INVOICE DETAILS
  // -------------------------------------------------------------------------

  Future<void> _showInvoiceDetails(TenantInvoice invoice) async {
    HapticFeedback.selectionClick();
    final isDesktop = MediaQuery.of(context).size.width >= 700;

    if (isDesktop) {
      await showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620, maxHeight: 780),
            child: _invoiceDetailContent(invoice),
          ),
        ),
      );
    } else {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * .92,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 4),
              Flexible(child: _invoiceDetailContent(invoice)),
            ],
          ),
        ),
      );
    }
  }

  Widget _invoiceDetailContent(TenantInvoice invoice) {
    final st = _invoiceStatus(invoice);
    final canPay = !invoice.isPaid;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Invoice details',
                  style: TextStyle(
                    fontSize: _fs(19),
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              _statusBadgeRich(st),
            ],
          ),
          const SizedBox(height: 20),
          _invoiceDetailHeader(invoice),
          const SizedBox(height: 16),
          _invoicePropertySection(invoice),
          const SizedBox(height: 16),
          _invoiceAmountSection(invoice),
          const SizedBox(height: 16),
          _invoiceReceiptsSection(invoice),
          if (canPay) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isPaymentInProgress
                    ? null
                    : () {
                  // Close the invoice-details dialog/bottom sheet first.
                  // This prevents it from appearing to reopen behind the
                  // payment confirmation dialog.
                  Navigator.of(context).pop();

                  // Start the payment flow after the details route closes.
                  Future<void>.delayed(Duration.zero, () {
                    if (mounted && !_isPaymentInProgress) {
                      _payInvoice(invoice);
                    }
                  });
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Palette.nestBlue,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.lock_outline_rounded, size: 18),
                label: Text(
                  'Pay ${invoice.formattedOutstanding}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: _fs(15),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _invoiceDetailHeader(TenantInvoice invoice) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.nestBlue.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Palette.nestBlue.withValues(alpha: .15)),
      ),
      child: Column(
        children: [
          _infoRow(
            Icons.tag_rounded,
            'Reference',
            'INV-${invoice.reference.toString().split('.').first}',
          ),
          _infoRow(
            Icons.calendar_today_rounded,
            'Invoice date',
            invoice.formattedDueDate,
          ),
          _infoRow(
            Icons.event_rounded,
            'Due date',
            _formatDate(invoice.dueDate),
          ),
        ],
      ),
    );
  }

  Widget _invoicePropertySection(TenantInvoice invoice) {
    return _profileCard(
      title: 'Property',
      icon: Icons.home_work_rounded,
      accent: Accent.teal,
      children: [
        _infoRow(Icons.home_rounded, 'Property', invoice.property.name),
        _infoRow(
          Icons.location_on_outlined,
          'Location',
          invoice.property.location,
        ),
        _infoRow(
          Icons.meeting_room_outlined,
          'Unit',
          invoice.unit.unitNumber,
        ),
      ],
    );
  }

  Widget _invoiceAmountSection(TenantInvoice invoice) {
    return _profileCard(
      title: 'Amount',
      icon: Icons.payments_rounded,
      accent: Accent.purple,
      children: [
        _infoRow(Icons.home_rounded, 'Rent', _currency(invoice.rent)),
        _infoRow(
          Icons.miscellaneous_services_rounded,
          'Service',
          _currency(invoice.service),
        ),
        _infoRow(
          Icons.receipt_long_rounded,
          'Total',
          invoice.formattedAmount,
        ),
        _infoRow(
          Icons.check_circle_outline_rounded,
          'Paid',
          invoice.formattedPaid,
        ),
        _infoRow(
          Icons.pending_actions_rounded,
          'Outstanding',
          invoice.formattedOutstanding,
        ),
      ],
    );
  }

  Widget _invoiceReceiptsSection(TenantInvoice invoice) {
    final s = context.status;
    return _profileCard(
      title: 'Payments',
      icon: Icons.payments_rounded,
      accent: s.success,
      children: invoice.receipts.isEmpty
          ? [_emptyInline('No payments recorded for this invoice.')]
          : invoice.receipts.map((receipt) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: s.successBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: s.success,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      receipt.reference ?? 'Payment',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(receipt.paymentDate),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _currency(receipt.amount),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: _fs(12.5),
                  color: s.success,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // -------------------------------------------------------------------------
  // SHARED UI
  // -------------------------------------------------------------------------

  Widget _buildAvatar({required String name, required double radius}) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            Palette.nestBlue.withValues(alpha: .18),
            Accent.purple.withValues(alpha: .14),
          ],
        ),
        border: Border.all(
          color: Palette.nestBlue.withValues(alpha: .20),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(1.5),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: Colors.transparent,
        child: Text(
          _initials(name),
          style: TextStyle(
            color: Palette.nestBlue,
            fontWeight: FontWeight.w800,
            fontSize: radius * .58,
          ),
        ),
      ),
    );
  }

  Widget _statusBadgeRich(
      ({String label, Color fg, Color bg, IconData icon}) st,
      ) {
    return Semantics(
      label: 'Status: ${st.label}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: st.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: st.fg.withValues(alpha: .20)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(st.icon, size: 11, color: st.fg),
            const SizedBox(width: 4),
            Text(
              st.label,
              style: TextStyle(
                color: st.fg,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  ({String label, Color fg, Color bg, IconData icon}) _invoiceStatus(
      TenantInvoice invoice,
      ) {
    final s = context.status;

    if (invoice.isPaid) {
      return (
      label: 'Paid',
      fg: s.success,
      bg: s.successBg,
      icon: Icons.check_circle_rounded,
      );
    }

    final due = invoice.dueDate;
    if (due != null) {
      final days = due.difference(DateTime.now()).inDays;
      if (days < 0) {
        return (
        label: '${-days}d overdue',
        fg: s.danger,
        bg: s.dangerBg,
        icon: Icons.error_rounded,
        );
      }
      if (days == 0) {
        return (
        label: 'Due today',
        fg: s.danger,
        bg: s.dangerBg,
        icon: Icons.schedule_rounded,
        );
      }
      if (days <= 7) {
        return (
        label: 'Due in ${days}d',
        fg: s.warning,
        bg: s.warningBg,
        icon: Icons.schedule_rounded,
        );
      }
    }

    return (
    label: invoice.statusLabel,
    fg: s.warning,
    bg: s.warningBg,
    icon: Icons.pending_actions_rounded,
    );
  }

  Widget _emptyInline(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        message,
        style: TextStyle(color: Colors.grey.shade600, fontSize: _fs(12.5)),
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Palette.nestBlue.withValues(alpha: .10),
                  Accent.purple.withValues(alpha: .08),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: Palette.nestBlue),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: _fs(16),
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: _fs(12.5),
              height: 1.5,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState({
    required String title,
    required String message,
    required VoidCallback onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 52,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: _fs(17),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: _fs(12.5),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // LOADING STATES
  // -------------------------------------------------------------------------

  Widget _buildInitialLoading() {
    return const _BrandLoader(
      label: 'Loading tenant portal...',
    );
  }

  Widget _buildInitialError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 52,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 15),
            Text(
              'Unable to load tenant portal',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: _fs(18),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              _initialError ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: _fs(12.5),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _initializePortal,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardLoading() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: const [
        _SkeletonBox(width: double.infinity, height: 180, borderRadius: 22),
        SizedBox(height: 18),
        _SkeletonBox(width: double.infinity, height: 90, borderRadius: 17),
        SizedBox(height: 14),
        _SkeletonBox(width: double.infinity, height: 90, borderRadius: 17),
        SizedBox(height: 14),
        _SkeletonBox(width: double.infinity, height: 160, borderRadius: 17),
        SizedBox(height: 14),
        _SkeletonBox(width: double.infinity, height: 200, borderRadius: 17),
      ],
    );
  }

  Widget _buildInvoicesLoading() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const _SkeletonBox(width: 220, height: 20, borderRadius: 6),
        const SizedBox(height: 18),
        const _SkeletonBox(
          width: double.infinity,
          height: 48,
          borderRadius: 13,
        ),
        const SizedBox(height: 18),
        ...List.generate(
          5,
              (index) => const Padding(
            padding: EdgeInsets.only(bottom: 11),
            child: _SkeletonBox(
              width: double.infinity,
              height: 82,
              borderRadius: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentsLoading() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const _SkeletonBox(width: 220, height: 20, borderRadius: 6),
        const SizedBox(height: 20),
        Row(
          children: List.generate(
            3,
                (index) => Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _SkeletonBox(
                  width: double.infinity,
                  height: 68,
                  borderRadius: 15,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        ...List.generate(
          5,
              (index) => const Padding(
            padding: EdgeInsets.only(bottom: 11),
            child: _SkeletonBox(
              width: double.infinity,
              height: 82,
              borderRadius: 16,
            ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // HELPERS
  // -------------------------------------------------------------------------

  double get _totalOutstanding {
    return _invoices.fold<double>(0, (sum, i) => sum + i.outstanding);
  }

  TenantInvoice? get _nextDueInvoice {
    final unpaid = _invoices
        .where((i) => !i.isPaid && i.dueDate != null)
        .toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    return unpaid.isEmpty ? null : unpaid.first;
  }

  String _currency(double value) => _currencyFormatter.format(value);

  String _formatDate(DateTime? value) {
    if (value == null) return '—';
    return _dateFormatter.format(value.toLocal());
  }

  String _firstName(String? name) {
    if (name == null || name.trim().isEmpty) return 'Tenant';
    return name.trim().split(RegExp(r'\s+')).first;
  }

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return 'T';
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  String _cleanError(Object error) {
    if (error is TenantPortalAuthException) return error.message;
    if (error is SocketException || error is TimeoutException) {
      return 'Check your internet connection and try again.';
    }
    if (error is FormatException) {
      return 'We received an unexpected response. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  // -------------------------------------------------------------------------
  // ACTIONS
  // -------------------------------------------------------------------------

  Future<void> _payInvoice(TenantInvoice invoice) async {
    if (_isPaymentInProgress) return;

    HapticFeedback.selectionClick();

    if (invoice.isPaid) {
      _showSnackBar(
        'This invoice has already been paid.',
      );
      return;
    }

    /*
  |--------------------------------------------------------------------------
  | Show confirmation
  |--------------------------------------------------------------------------
  */

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Confirm Payment',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'You are about to pay ${invoice.formattedOutstanding} '
                'for invoice ${invoice.reference.toString().split('.').first}.',
            style: TextStyle(
              fontSize: _fs(12),
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: Palette.nestBlue,
              ),
              child: const Text('Pay Now'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isPaymentInProgress = true);

    /*
  |--------------------------------------------------------------------------
  | Show STK waiting dialog
  |--------------------------------------------------------------------------
  */

    bool dialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),

                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Palette.nestBlue.withOpacity(.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.phone_android_rounded,
                    color: Palette.nestBlue,
                    size: 30,
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  'Check your phone',
                  style: TextStyle(
                    fontSize: _fs(14),
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 10),

                Text(
                  'An M-PESA payment request has been sent to your phone.',
                  style: TextStyle(
                    fontSize: _fs(12),
                    height: 1.5,
                    color: Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 18),

                Text(
                  invoice.formattedOutstanding,
                  style: TextStyle(
                    fontSize: _fs(22),
                    fontWeight: FontWeight.w900,
                    color: Palette.nestBlue,
                  ),
                ),

                const SizedBox(height: 18),

                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                  ),
                ),

                const SizedBox(height: 14),

                Text(
                  'Waiting for payment confirmation...',
                  style: TextStyle(
                    fontSize: _fs(12),
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      dialogOpen = false;
    });

    try {
      /*
    |--------------------------------------------------------------------------
    | 1. Initiate STK Push
    |--------------------------------------------------------------------------
    */

      final response =
      await widget.service.initiateInvoicePayment(
        invoice.id,
      );

      if (!mounted) {
        return;
      }

      if (response['success'] != true) {

        if (dialogOpen && mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }

        _showSnackBar(
          response['message'] ??
              'Unable to initiate M-PESA payment.',
        );

        return;
      }

      /*
    |--------------------------------------------------------------------------
    | 2. Get transaction ID
    |--------------------------------------------------------------------------
    */

      final transaction =
      response['transaction'];

      if (transaction is! Map) {

        if (dialogOpen && mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }

        _showSnackBar(
          'Invalid payment response from server.',
        );

        return;
      }

      final transactionId =
      int.tryParse(
        transaction['id'].toString(),
      );

      if (transactionId == null) {

        if (dialogOpen && mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }

        _showSnackBar(
          'Payment transaction could not be identified.',
        );

        return;
      }

      /*
    |--------------------------------------------------------------------------
    | 3. Poll payment status
    |--------------------------------------------------------------------------
    */

      const maxAttempts = 30;

      var paymentCompleted = false;
      var paymentFailed = false;

      String? failureMessage;

      for (
      int attempt = 0;
      attempt < maxAttempts;
      attempt++
      ) {

        await Future.delayed(
          const Duration(seconds: 2),
        );

        if (!mounted) {
          return;
        }

        Map<String, dynamic> statusResponse;

        try {
          statusResponse = await widget.service
              .getPaymentStatus(transactionId)
              .timeout(const Duration(seconds: 10));
        } catch (_) {
          // A temporary network/status-check failure should not end the payment wait.
          continue;
        }

        if (statusResponse['success'] != true) {
          continue;
        }

        final statusTransaction =
        statusResponse['transaction'];

        if (statusTransaction is! Map) {
          continue;
        }

        final status =
        statusTransaction['status']
            ?.toString()
            .toLowerCase();

        if (status == 'completed') {
          paymentCompleted = true;
          break;
        }

        if (
        status == 'failed' ||
            status == 'cancelled'
        ) {
          paymentFailed = true;

          failureMessage =
              statusTransaction[
              'result_description']
                  ?.toString();

          break;
        }
      }

      /*
    |--------------------------------------------------------------------------
    | 4. Close waiting dialog
    |--------------------------------------------------------------------------
    */

      if (dialogOpen && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogOpen = false;
      }

      if (!mounted) {
        return;
      }

      /*
    |--------------------------------------------------------------------------
    | 5. Payment successful
    |--------------------------------------------------------------------------
    */

      if (paymentCompleted) {

        _showSnackBar(
          'Payment successful. Your invoice has been updated.',
        );

        /*
      |--------------------------------------------------------------------------
      | Refresh invoices from Laravel
      |--------------------------------------------------------------------------
      */

        await Future.wait([
          _loadInvoices(),
          _loadDashboard(),
        ]);

        if (!mounted) {
          return;
        }

        return;
      }

      /*
    |--------------------------------------------------------------------------
    | 6. Payment failed
    |--------------------------------------------------------------------------
    */

      if (paymentFailed) {

        _showSnackBar(
          failureMessage?.isNotEmpty == true
              ? failureMessage!
              : 'M-PESA payment was not completed.',
        );

        return;
      }

      /*
    |--------------------------------------------------------------------------
    | 7. Timeout
    |--------------------------------------------------------------------------
    */

      _showSnackBar(
        'Payment confirmation is taking longer than expected. '
            'Please check your M-PESA messages and refresh your invoices.',
      );

    } catch (e) {

      /*
    |--------------------------------------------------------------------------
    | Error handling
    |--------------------------------------------------------------------------
    */

      if (dialogOpen && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogOpen = false;
      }

      if (!mounted) {
        return;
      }

      _showSnackBar(
        _cleanError(e),
      );
    } finally {
      if (mounted) {
        setState(() => _isPaymentInProgress = false);
      }
    }
  }
}

// ============================================================================
// PAYMENT MODEL
// ============================================================================

class _TenantPaymentRecord {
  final int id;
  final double amount;
  final DateTime? paymentDate;
  final String? reference;
  final String invoiceReference;

  const _TenantPaymentRecord({
    required this.id,
    required this.amount,
    required this.paymentDate,
    required this.reference,
    required this.invoiceReference,
  });
}

// ============================================================================
// FADE-IN WRAPPER — animates children in with a smooth slide-up + fade.
// ============================================================================

class _FadeIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;

  const _FadeIn({
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 420),
    this.offset = const Offset(0, 0.06),
  });

  @override
  State<_FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<_FadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeOutCubic,
  );

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: widget.offset,
    end: Offset.zero,
  ).animate(
    CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
  );

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ============================================================================
// BRAND LOADER — animated pulsing/rotating brand mark for full-screen loads.
// ============================================================================

class _BrandLoader extends StatefulWidget {
  final String label;

  const _BrandLoader({required this.label});

  @override
  State<_BrandLoader> createState() => _BrandLoaderState();
}

class _BrandLoaderState extends State<_BrandLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              final t = _ctrl.value;
              final pulse = 1.0 + (0.08 * (1 - (t * 2 - 1).abs()));
              final glow = 0.15 + (0.20 * (1 - (t * 2 - 1).abs()));

              return Transform.rotate(
                angle: t * 6.28318, // full rotation
                child: Transform.scale(
                  scale: pulse,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Palette.nestBlue, Color(0xFF4F7BE5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Palette.nestBlue.withValues(alpha: glow),
                          blurRadius: 28,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.home_work_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 26),
          Text(
            widget.label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 14),
          _DotsLoader(),
        ],
      ),
    );
  }
}

class _DotsLoader extends StatefulWidget {
  @override
  State<_DotsLoader> createState() => _DotsLoaderState();
}

class _DotsLoaderState extends State<_DotsLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final offset = (i * 0.2);
            final t = (_ctrl.value + offset) % 1.0;
            final scale = 0.6 + 0.5 * (1 - (t * 2 - 1).abs());
            final opacity = 0.35 + 0.65 * (1 - (t * 2 - 1).abs());

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Palette.nestBlue.withValues(alpha: opacity),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ============================================================================
// SKELETON (shimmer + pulse)
// ============================================================================

class _SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const _SkeletonBox({
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF1F2937) : Colors.grey.shade200;
    final highlight = isDark ? const Color(0xFF374151) : Colors.grey.shade100;

    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final t = _ctrl.value;

          // Sweep position
          final begin = -2.0 + 3.0 * t;
          final end = begin + 1.5;

          // Subtle pulse
          final pulse = 1.0 - 0.02 * (1 - (t * 2 - 1).abs());

          return Transform.scale(
            scale: pulse,
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                gradient: LinearGradient(
                  begin: Alignment(begin, 0),
                  end: Alignment(end, 0),
                  colors: [base, highlight, base],
                  stops: const [0.35, 0.5, 0.65],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
