import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:hub/models/tenant_maintenance.dart';
import 'package:hub/services/tenant_portal_service.dart';

class TenantMaintenancePage extends StatefulWidget {
  final TenantPortalService service;

  const TenantMaintenancePage({
    super.key,
    required this.service,
  });

  @override
  State<TenantMaintenancePage> createState() =>
      _TenantMaintenancePageState();
}

class _TenantMaintenancePageState extends State<TenantMaintenancePage> {
  final TextEditingController _searchController = TextEditingController();

  List<TenantMaintenance> _maintenance = [];

  TenantMaintenanceSummary _summary =
  const TenantMaintenanceSummary(
    total: 0,
    open: 0,
    inProgress: 0,
    resolved: 0,
  );

  bool _loading = true;

  String? _error;

  String _statusFilter = 'All';

  @override
  void initState() {
    super.initState();

    _loadMaintenance();

    _searchController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ===============================================================
  // DATA
  // ===============================================================

  Future<void> _loadMaintenance({
    bool showLoader = true,
  }) async {
    if (showLoader) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final result = await widget.service.fetchMaintenance();

      if (!mounted) return;

      setState(() {
        _maintenance = result.maintenance;
        _summary = result.summary;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = _friendlyErrorMessage(e);
      });
    }
  }

  String _friendlyErrorMessage(Object error) {
    final message = error.toString();

    if (message.toLowerCase().contains('socket')) {
      return 'Unable to connect to the server. Please check your connection.';
    }

    if (message.toLowerCase().contains('timeout')) {
      return 'The request timed out. Please try again.';
    }

    if (message.contains('401')) {
      return 'Your session has expired. Please sign in again.';
    }

    if (message.contains('403')) {
      return 'You are not authorised to access these requests.';
    }

    return 'Something went wrong while loading your maintenance requests.';
  }

  List<TenantMaintenance> get _filteredMaintenance {
    final search = _searchController.text.trim().toLowerCase();

    return _maintenance.where((item) {
      final matchesStatus =
          _statusFilter == 'All' ||
              item.statusKey == _statusFilter;

      if (!matchesStatus) return false;

      if (search.isEmpty) return true;

      return item.subject.toLowerCase().contains(search) ||
          item.description.toLowerCase().contains(search) ||
          item.statusLabel.toLowerCase().contains(search);
    }).toList();
  }

  // ===============================================================
  // CREATE MAINTENANCE
  // ===============================================================

  Future<void> _openCreateDialog() async {
    final isMobile =
        MediaQuery.of(context).size.width < 600;

    final submitted = isMobile
        ? await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context)
                .viewInsets
                .bottom,
          ),
          child: _CreateMaintenanceDialog(
            service: widget.service,
          ),
        );
      },
    )
        : await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return _CreateMaintenanceDialog(
          service: widget.service,
        );
      },
    );

    if (!mounted || submitted != true) return;

    // Refresh the list so the newly created request
    // appears immediately.
    await _loadMaintenance(
      showLoader: false,
    );

    if (!mounted) return;

    _showSuccessNotification(
      'Maintenance request submitted successfully.',
    );
  }

  // ===============================================================
  // SUCCESS NOTIFICATION
  // ===============================================================

  void _showSuccessNotification(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            24,
          ),
          duration: const Duration(seconds: 4),
          backgroundColor: const Color(0xff12B76A),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  // ===============================================================
  // DETAILS
  // ===============================================================

  Future<void> _openDetails(
      TenantMaintenance maintenance,
      ) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        return _MaintenanceDetailsDialog(
          maintenance: maintenance,
        );
      },
    );
  }

  // ===============================================================
  // BUILD
  // ===============================================================

  @override
  Widget build(BuildContext context) {
    final isMobile =
        MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: const Color(0xffF6F8FB),
      floatingActionButton: isMobile
          ? FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        backgroundColor: const Color(0xff1264E8),
        foregroundColor: Colors.white,
        icon: const Icon(
          Icons.add_rounded,
        ),
        label: const Text(
          'New Request',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      )
          : null,
      body: RefreshIndicator(
        onRefresh: () => _loadMaintenance(
          showLoader: false,
        ),
        child: _loading
            ? _buildLoading()
            : _error != null
            ? _buildError()
            : _buildContent(),
      ),
    );
  }

  // ===============================================================
  // CONTENT
  // ===============================================================

  Widget _buildContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop =
            constraints.maxWidth >= 900;

        return SingleChildScrollView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            desktop ? 32 : 16,
            24,
            desktop ? 32 : 16,
            110,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints:
              const BoxConstraints(
                maxWidth: 1250,
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  _buildHeader(desktop),
                  const SizedBox(height: 22),
                  _buildSummaryCards(desktop),
                  const SizedBox(height: 20),
                  _buildToolbar(desktop),
                  const SizedBox(height: 18),
                  _filteredMaintenance.isEmpty
                      ? _buildEmptyState()
                      : _buildMaintenanceList(
                    desktop,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ===============================================================
  // HEADER
  // ===============================================================

  Widget _buildHeader(bool desktop) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              const Text(
                'Maintenance requests',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xff172033),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Report and track issues in your unit.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        if (desktop)
          FilledButton.icon(
            onPressed: _openCreateDialog,
            style: FilledButton.styleFrom(
              backgroundColor:
              const Color(0xff1264E8),
              padding:
              const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 14,
              ),
              shape:
              RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(11),
              ),
            ),
            icon: const Icon(
              Icons.add_rounded,
              size: 19,
            ),
            label: const Text(
              'New Request',
              style: TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  // ===============================================================
  // SUMMARY
  // ===============================================================

  Widget _buildSummaryCards(bool desktop) {
    final cards = [
      _SummaryCardData(
        label: 'Total Requests',
        value: _summary.total,
        icon: Icons.build_outlined,
        iconColor: const Color(0xff1264E8),
      ),
      _SummaryCardData(
        label: 'Open',
        value: _summary.open,
        icon: Icons.pending_actions_rounded,
        iconColor: const Color(0xffF79009),
      ),
      _SummaryCardData(
        label: 'In Progress',
        value: _summary.inProgress,
        icon: Icons.engineering_outlined,
        iconColor: const Color(0xff7F56D9),
      ),
      _SummaryCardData(
        label: 'Resolved',
        value: _summary.resolved,
        icon: Icons.check_circle_outline_rounded,
        iconColor: const Color(0xff12B76A),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics:
      const NeverScrollableScrollPhysics(),
      gridDelegate:
      SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: desktop ? 4 : 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent:
        desktop ? 94 : 88,
      ),
      itemCount: cards.length,
      itemBuilder: (_, index) {
        final card = cards[index];

        return Container(
          padding: EdgeInsets.all(
            desktop ? 15 : 12,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
            BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xffE8ECF2),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: desktop ? 40 : 36,
                height: desktop ? 40 : 36,
                decoration: BoxDecoration(
                  color: card.iconColor
                      .withOpacity(.09),
                  borderRadius:
                  BorderRadius.circular(11),
                ),
                child: Icon(
                  card.icon,
                  color: card.iconColor,
                  size: desktop ? 20 : 18,
                ),
              ),
              SizedBox(
                width: desktop ? 12 : 10,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children: [
                    Text(
                      card.value.toString(),
                      style: TextStyle(
                        fontSize:
                        desktop ? 20 : 18,
                        fontWeight:
                        FontWeight.w800,
                        color:
                        const Color(0xff172033),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      card.label,
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize:
                        desktop ? 11 : 10,
                        color:
                        Colors.grey.shade600,
                        fontWeight:
                        FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ===============================================================
  // TOOLBAR
  // ===============================================================

  Widget _buildToolbar(bool desktop) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xffE8ECF2),
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            textInputAction:
            TextInputAction.search,
            decoration: InputDecoration(
              hintText:
              'Search by subject, description, or status…',
              hintStyle: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 19,
              ),
              suffixIcon:
              _searchController.text.isEmpty
                  ? null
                  : IconButton(
                onPressed:
                    () =>
                    _searchController
                        .clear(),
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                ),
                tooltip: 'Clear search',
              ),
              filled: true,
              fillColor:
              const Color(0xffF7F8FA),
              border: OutlineInputBorder(
                borderRadius:
                BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding:
              const EdgeInsets.symmetric(
                horizontal: 12,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection:
              Axis.horizontal,
              children: [
                _filterChip('All', 'All'),
                const SizedBox(width: 6),
                _filterChip('Open', 'open'),
                const SizedBox(width: 6),
                _filterChip(
                  'In Progress',
                  'in_progress',
                ),
                const SizedBox(width: 6),
                _filterChip(
                  'Resolved',
                  'resolved',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(
      String label,
      String value,
      ) {
    final selected =
        _statusFilter == value;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _statusFilter = value;
        });
      },
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected
            ? FontWeight.w700
            : FontWeight.w500,
        color: selected
            ? const Color(0xff1264E8)
            : const Color(0xff475467),
      ),
      selectedColor:
      const Color(0xff1264E8)
          .withOpacity(.09),
      backgroundColor:
      const Color(0xffF7F8FA),
      side: BorderSide(
        color: selected
            ? const Color(0xff1264E8)
            .withOpacity(.25)
            : const Color(0xffE4E7EC),
      ),
      showCheckmark: false,
    );
  }

  // ===============================================================
  // LIST
  // ===============================================================

  Widget _buildMaintenanceList(
      bool desktop,
      ) {
    return Column(
      children: _filteredMaintenance
          .map(
            (maintenance) => Padding(
          padding:
          const EdgeInsets.only(
            bottom: 10,
          ),
          child:
          _buildMaintenanceCard(
            maintenance,
            desktop,
          ),
        ),
      )
          .toList(),
    );
  }

  Widget _buildMaintenanceCard(
      TenantMaintenance maintenance,
      bool desktop,
      ) {
    final statusColor =
    _statusColor(maintenance.status);

    return InkWell(
      borderRadius:
      BorderRadius.circular(15),
      onTap: () =>
          _openDetails(maintenance),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.circular(15),
          border: Border.all(
            color: const Color(0xffE8ECF2),
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment:
            CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius:
                  const BorderRadius.horizontal(
                    left:
                    Radius.circular(15),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding:
                  const EdgeInsets.all(15),
                  child: Row(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration:
                        BoxDecoration(
                          color: statusColor
                              .withOpacity(.09),
                          borderRadius:
                          BorderRadius
                              .circular(12),
                        ),
                        child: Icon(
                          _statusIcon(
                            maintenance.status,
                          ),
                          color: statusColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    maintenance
                                        .subject,
                                    maxLines: 1,
                                    overflow:
                                    TextOverflow
                                        .ellipsis,
                                    style:
                                    const TextStyle(
                                      fontSize: 14,
                                      fontWeight:
                                      FontWeight
                                          .w700,
                                      color: Color(
                                        0xff172033,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(
                                  width: 8,
                                ),
                                _statusBadge(
                                  maintenance
                                      .status,
                                ),
                              ],
                            ),
                            const SizedBox(
                              height: 6,
                            ),
                            Text(
                              maintenance
                                  .description,
                              maxLines: 2,
                              overflow:
                              TextOverflow
                                  .ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.45,
                                color: Colors
                                    .grey
                                    .shade600,
                              ),
                            ),
                            const SizedBox(
                              height: 10,
                            ),
                            _buildCardMeta(
                              maintenance,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardMeta(
      TenantMaintenance maintenance,
      ) {
    return Row(
      children: [
        Icon(
          Icons.calendar_today_outlined,
          size: 13,
          color: Colors.grey.shade500,
        ),
        const SizedBox(width: 5),
        Text(
          maintenance.formattedDate,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
        if (maintenance.photos.isNotEmpty) ...[
          const SizedBox(width: 14),
          Icon(
            Icons.photo_library_outlined,
            size: 14,
            color: Colors.grey.shade500,
          ),
          const SizedBox(width: 4),
          Text(
            '${maintenance.photos.length}',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
        const Spacer(),
        Icon(
          Icons.arrow_forward_ios_rounded,
          size: 12,
          color: Colors.grey.shade400,
        ),
      ],
    );
  }

  Widget _statusBadge(String status) {
    final color =
    _statusColor(status);

    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.09),
        borderRadius:
        BorderRadius.circular(20),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          fontSize: 10,
          fontWeight:
          FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  // ===============================================================
  // EMPTY STATE
  // ===============================================================

  Widget _buildEmptyState() {
    final hasSearch =
        _searchController.text
            .trim()
            .isNotEmpty;

    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.symmetric(
        vertical: 60,
        horizontal: 24,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xffE8ECF2),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xff1264E8)
                  .withOpacity(.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.build_outlined,
              color: Color(0xff1264E8),
              size: 27,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            hasSearch
                ? 'No matching requests'
                : 'No maintenance requests',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xff172033),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasSearch
                ? 'Try a different search term or clear your search.'
                : _statusFilter == 'All'
                ? 'You currently have no maintenance requests.'
                : 'No ${_statusLabel(_statusFilter)} requests found.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 18),
          if (!hasSearch)
            FilledButton.icon(
              onPressed: _openCreateDialog,
              style: FilledButton.styleFrom(
                backgroundColor:
                const Color(0xff1264E8),
              ),
              icon: const Icon(
                Icons.add_rounded,
              ),
              label: const Text(
                'Report an Issue',
              ),
            ),
        ],
      ),
    );
  }

  // ===============================================================
  // LOADING
  // ===============================================================

  Widget _buildLoading() {
    return ListView(
      physics:
      const AlwaysScrollableScrollPhysics(),
      padding:
      const EdgeInsets.all(16),
      children: [
        Row(
          children: List.generate(
            2,
                (index) => Expanded(
              child: Container(
                height: 88,
                margin: EdgeInsets.only(
                  right:
                  index == 0 ? 12 : 0,
                ),
                decoration:
                BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                  BorderRadius.circular(
                    14,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        ...List.generate(
          5,
              (_) => Container(
            height: 118,
            margin:
            const EdgeInsets.only(
              bottom: 12,
            ),
            decoration:
            BoxDecoration(
              color: Colors.white,
              borderRadius:
              BorderRadius.circular(15),
            ),
            child: const _Skeleton(),
          ),
        ),
      ],
    );
  }

  // ===============================================================
  // ERROR
  // ===============================================================

  Widget _buildError() {
    return ListView(
      physics:
      const AlwaysScrollableScrollPhysics(),
      padding:
      const EdgeInsets.all(30),
      children: [
        const SizedBox(height: 100),
        Icon(
          Icons.error_outline_rounded,
          size: 48,
          color: Colors.red.shade300,
        ),
        const SizedBox(height: 15),
        const Text(
          'Unable to load maintenance requests',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          _error ??
              'Something went wrong.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: FilledButton(
            onPressed: _loadMaintenance,
            style:
            FilledButton.styleFrom(
              backgroundColor:
              const Color(0xff1264E8),
            ),
            child:
            const Text('Try Again'),
          ),
        ),
      ],
    );
  }

  // ===============================================================
  // STATUS HELPERS
  // ===============================================================

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'in_progress':
      case 'in progress':
        return const Color(0xff7F56D9);

      case 'resolved':
      case 'closed':
        return const Color(0xff12B76A);

      case 'open':
      default:
        return const Color(0xffF79009);
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'in_progress':
      case 'in progress':
        return Icons.engineering_outlined;

      case 'resolved':
      case 'closed':
        return Icons.check_circle_outline_rounded;

      case 'open':
      default:
        return Icons.pending_actions_rounded;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'in_progress':
      case 'in progress':
        return 'In Progress';

      case 'resolved':
      case 'closed':
        return 'Resolved';

      case 'open':
      default:
        return 'Open';
    }
  }
}

// ===================================================================
// SUMMARY CARD DATA
// ===================================================================

class _SummaryCardData {
  final String label;
  final int value;
  final IconData icon;
  final Color iconColor;

  const _SummaryCardData({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });
}

// ===================================================================
// SKELETON
// ===================================================================

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
      const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        mainAxisAlignment:
        MainAxisAlignment.center,
        children: [
          Container(
            width: 180,
            height: 12,
            decoration: BoxDecoration(
              color:
              const Color(0xffEEF1F5),
              borderRadius:
              BorderRadius.circular(5),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            height: 9,
            decoration: BoxDecoration(
              color:
              const Color(0xffF2F4F7),
              borderRadius:
              BorderRadius.circular(5),
            ),
          ),
          const SizedBox(height: 7),
          Container(
            width: 220,
            height: 9,
            decoration: BoxDecoration(
              color:
              const Color(0xffF2F4F7),
              borderRadius:
              BorderRadius.circular(5),
            ),
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// FIELD LABEL
// ===================================================================

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool required;

  const _FieldLabel(
      this.text, {
        this.required = false,
      });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (required)
          const Text(
            ' *',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xffD92D20),
            ),
          ),
      ],
    );
  }
}

// ===================================================================
// CREATE MAINTENANCE DIALOG
// ===================================================================

class _CreateMaintenanceDialog
    extends StatefulWidget {
  final TenantPortalService service;

  const _CreateMaintenanceDialog({
    required this.service,
  });

  @override
  State<_CreateMaintenanceDialog>
  createState() =>
      _CreateMaintenanceDialogState();
}

class _CreateMaintenanceDialogState
    extends State<_CreateMaintenanceDialog> {
  static const int
  _descriptionMaxLength = 50;

  static const List<String>
  _subjectOptions = [
    'Water Leakage',
    'Electrical Issue',
    'Plumbing',
    'Air Conditioning',
    'Heating',
    'Appliance Malfunction',
    'Pest Control',
    'Door / Lock Issue',
    'Window / Glass',
    'Other',
  ];

  final _formKey =
  GlobalKey<FormState>();

  final _descriptionController =
  TextEditingController();

  final ImagePicker _picker =
  ImagePicker();

  final List<_SelectedPhoto> _photos =
  [];

  String? _selectedSubject;

  bool _submitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  // ===============================================================
  // PHOTO PICKING
  // ===============================================================

  Future<void> _pickImages() async {
    if (_photos.length >= 5) {
      _showMessage(
        'You can attach up to 5 photos.',
      );
      return;
    }

    try {
      final images =
      await _picker.pickMultiImage(
        imageQuality: 80,
      );

      if (images.isEmpty) return;

      for (final image in images) {
        if (_photos.length >= 5) {
          break;
        }

        final bytes =
        await image.readAsBytes();

        if (!mounted) return;

        setState(() {
          _photos.add(
            _SelectedPhoto(
              name: image.name,
              bytes: bytes,
              mimeType:
              _detectMimeType(
                image.name,
              ),
            ),
          );
        });
      }
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'Unable to select the photos. Please try again.',
      );
    }
  }

  Future<void> _takePhoto() async {
    if (_photos.length >= 5) {
      _showMessage(
        'You can attach up to 5 photos.',
      );
      return;
    }

    try {
      final image =
      await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (image == null) return;

      final bytes =
      await image.readAsBytes();

      if (!mounted) return;

      setState(() {
        _photos.add(
          _SelectedPhoto(
            name: image.name,
            bytes: bytes,
            mimeType:
            _detectMimeType(
              image.name,
            ),
          ),
        );
      });
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'Unable to access the camera. Please try again.',
      );
    }
  }

  String _detectMimeType(
      String name,
      ) {
    final extension = name
        .split('.')
        .last
        .toLowerCase();

    switch (extension) {
      case 'png':
        return 'image/png';

      case 'webp':
        return 'image/webp';

      case 'heic':
        return 'image/heic';

      case 'heif':
        return 'image/heif';

      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  // ===============================================================
  // SUBMIT
  // ===============================================================

  Future<void> _submit() async {
    if (_submitting) return;

    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _submitting = true;
    });

    try {
      final payloads =
      <MaintenancePhotoPayload>[];

      for (final photo in _photos) {
        payloads.add(
          MaintenancePhotoPayload(
            filename: photo.name,
            mimeType: photo.mimeType,
            data: base64Encode(
              photo.bytes,
            ),
          ),
        );
      }

      await widget.service
          .submitMaintenance(
        subject: _selectedSubject!,
        description:
        _descriptionController
            .text
            .trim(),
        photos: payloads,
      );

      if (!mounted) return;

      // Return true to the parent page.
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _submitting = false;
      });

      _showMessage(
        _friendlySubmitError(e),
      );
    }
  }

  String _friendlySubmitError(
      Object error,
      ) {
    final message =
    error.toString().toLowerCase();

    if (message.contains('timeout')) {
      return 'The request timed out. Please try again.';
    }

    if (message.contains('socket')) {
      return 'Unable to connect to the server. Please check your connection.';
    }

    if (message.contains('401')) {
      return 'Your session has expired. Please sign in again.';
    }

    if (message.contains('413')) {
      return 'The selected photos are too large. Please choose smaller images.';
    }

    if (message.contains('422')) {
      return 'Please check the information entered and try again.';
    }

    return 'We could not submit your request. Please try again.';
  }

  void _showMessage(
      String message,
      ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior:
          SnackBarBehavior.floating,
          duration:
          const Duration(seconds: 4),
          backgroundColor:
          const Color(0xffD92D20),
          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(12),
          ),
          content: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style:
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  // ===============================================================
  // BUILD
  // ===============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final isBottomSheet =
        MediaQuery.of(context)
            .size
            .width <
            600;

    final content =
    _buildFormContent();

    if (isBottomSheet) {
      return Container(
        decoration:
        const BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.vertical(
            top: Radius.circular(22),
          ),
        ),
        padding:
        const EdgeInsets.fromLTRB(
          20,
          12,
          20,
          12,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize:
            MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                margin:
                const EdgeInsets.only(
                  bottom: 14,
                ),
                decoration:
                BoxDecoration(
                  color:
                  const Color(
                    0xffE4E7EC,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    2,
                  ),
                ),
              ),
              Flexible(
                child: content,
              ),
            ],
          ),
        ),
      );
    }

    return Dialog(
      insetPadding:
      const EdgeInsets.all(18),
      shape:
      RoundedRectangleBorder(
        borderRadius:
        BorderRadius.circular(18),
      ),
      child: ConstrainedBox(
        constraints:
        const BoxConstraints(
          maxWidth: 580,
          maxHeight: 720,
        ),
        child: Padding(
          padding:
          const EdgeInsets.all(22),
          child: content,
        ),
      ),
    );
  }

  Widget _buildFormContent() {
    return Column(
      mainAxisSize:
      MainAxisSize.min,
      children: [
        // =========================================================
        // HEADER
        // =========================================================

        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration:
              BoxDecoration(
                color:
                const Color(
                  0xff1264E8,
                ).withOpacity(.09),
                borderRadius:
                BorderRadius.circular(
                  11,
                ),
              ),
              child: const Icon(
                Icons.build_outlined,
                color:
                Color(0xff1264E8),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,
                children: [
                  Text(
                    'Report an Issue',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                      FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Tell your property manager what needs attention.',
                    style: TextStyle(
                      fontSize: 11,
                      color:
                      Color(0xff667085),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _submitting
                  ? null
                  : () =>
                  Navigator.pop(
                    context,
                  ),
              icon: const Icon(
                Icons.close_rounded,
              ),
              tooltip: 'Close',
            ),
          ],
        ),

        const SizedBox(height: 16),

        // =========================================================
        // FORM
        // =========================================================

        Flexible(
          child: Form(
            key: _formKey,
            child: ListView(
              shrinkWrap: true,
              children: [
                // =================================================
                // SUBJECT
                // =================================================

                const _FieldLabel(
                  'Subject',
                  required: true,
                ),

                const SizedBox(height: 7),

                DropdownButtonFormField<
                    String>(
                  value: _selectedSubject,
                  isExpanded: true,
                  decoration:
                  _inputDecoration(
                    'Select a subject',
                    Icons.subject_rounded,
                  ),
                  hint: const Text(
                    'Select a subject',
                    style: TextStyle(
                      fontSize: 14,
                      color:
                      Color(0xff98A2B3),
                    ),
                  ),
                  items:
                  _subjectOptions
                      .map(
                        (s) =>
                        DropdownMenuItem<
                            String>(
                          value: s,
                          child: Text(
                            s,
                            overflow:
                            TextOverflow
                                .ellipsis,
                            style:
                            const TextStyle(
                              fontSize: 14,
                            ),
                          ),
                        ),
                  ).toList(),
                  onChanged:
                  _submitting
                      ? null
                      : (value) {
                    setState(() {
                      _selectedSubject =
                          value;
                    });
                  },
                  validator: (value) {
                    if (value == null ||
                        value.isEmpty) {
                      return 'Please select a subject.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // =================================================
                // DESCRIPTION
                // =================================================

                Row(
                  children: [
                    const Expanded(
                      child: _FieldLabel(
                        'Description',
                        required: true,
                      ),
                    ),
                    ValueListenableBuilder<
                        TextEditingValue>(
                      valueListenable:
                      _descriptionController,
                      builder:
                          (
                          context,
                          value,
                          _,
                          ) {
                        final length =
                            value.text.length;

                        final isNearLimit =
                            length >=
                                _descriptionMaxLength -
                                    10;

                        return Text(
                          '$length/$_descriptionMaxLength',
                          style:
                          TextStyle(
                            fontSize: 11,
                            fontWeight:
                            isNearLimit
                                ? FontWeight
                                .w700
                                : FontWeight
                                .w500,
                            color: isNearLimit
                                ? const Color(
                              0xffD92D20,
                            )
                                : Colors
                                .grey
                                .shade600,
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 7),

                TextFormField(
                  controller:
                  _descriptionController,
                  minLines: 3,
                  maxLines: 4,
                  maxLength:
                  _descriptionMaxLength,
                  enabled:
                  !_submitting,
                  textInputAction:
                  TextInputAction.done,
                  textCapitalization:
                  TextCapitalization
                      .sentences,
                  decoration:
                  _inputDecoration(
                    'e.g. Kitchen sink is leaking under the cabinet',
                    Icons.description_outlined,
                  ).copyWith(
                    counterText: '',
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Please describe the issue.';
                    }

                    if (value.length >
                        _descriptionMaxLength) {
                      return 'Max $_descriptionMaxLength characters.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 10),

                // =================================================
                // PHOTOS
                // =================================================

                Row(
                  children: [
                    const Expanded(
                      child: _FieldLabel(
                        'Photos',
                      ),
                    ),
                    Text(
                      '${_photos.length}/5',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors
                            .grey
                            .shade600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    _photoAction(
                      icon: Icons
                          .photo_library_outlined,
                      label: 'Gallery',
                      onTap:
                      _pickImages,
                    ),
                    const SizedBox(width: 8),
                    _photoAction(
                      icon: Icons
                          .camera_alt_outlined,
                      label: 'Camera',
                      onTap:
                      _takePhoto,
                    ),
                  ],
                ),

                if (_photos.isNotEmpty) ...[
                  const SizedBox(height: 13),
                  SizedBox(
                    height: 82,
                    child:
                    ListView.separated(
                      scrollDirection:
                      Axis.horizontal,
                      itemCount:
                      _photos.length,
                      separatorBuilder:
                          (_, __) =>
                      const SizedBox(
                        width: 8,
                      ),
                      itemBuilder:
                          (_, index) =>
                          _photoPreview(
                            _photos[index],
                            index,
                          ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 15),

        // =========================================================
        // SUBMIT
        // =========================================================

        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton.icon(
            onPressed:
            _submitting
                ? null
                : _submit,
            style:
            FilledButton.styleFrom(
              backgroundColor:
              const Color(
                0xff1264E8,
              ),
              disabledBackgroundColor:
              const Color(
                0xff98A2B3,
              ),
              shape:
              RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(
                  12,
                ),
              ),
            ),
            icon: _submitting
                ? const SizedBox(
              width: 18,
              height: 18,
              child:
              CircularProgressIndicator(
                strokeWidth: 2.3,
                color: Colors.white,
              ),
            )
                : const Icon(
              Icons.send_rounded,
              size: 18,
            ),
            label: Text(
              _submitting
                  ? 'Submitting…'
                  : 'Submit Request',
              style:
              const TextStyle(
                fontWeight:
                FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===============================================================
  // INPUT DECORATION
  // ===============================================================

  InputDecoration _inputDecoration(
      String hint,
      IconData icon,
      ) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
      const TextStyle(
        fontSize: 14,
        color: Color(0xff98A2B3),
      ),
      prefixIcon: Icon(
        icon,
        size: 19,
      ),
      filled: true,
      fillColor:
      const Color(0xffF7F8FA),
      contentPadding:
      const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 14,
      ),
      border:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(11),
        borderSide:
        BorderSide.none,
      ),
      focusedBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(11),
        borderSide:
        const BorderSide(
          color:
          Color(0xff1264E8),
        ),
      ),
      errorBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(11),
        borderSide:
        const BorderSide(
          color:
          Color(0xffD92D20),
        ),
      ),
      focusedErrorBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(11),
        borderSide:
        const BorderSide(
          color:
          Color(0xffD92D20),
        ),
      ),
    );
  }

  // ===============================================================
  // PHOTO ACTION
  // ===============================================================

  Widget _photoAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed:
        _photos.length >= 5
            ? null
            : onTap,
        icon: Icon(
          icon,
          size: 17,
        ),
        label: Text(
          label,
          style:
          const TextStyle(
            fontSize: 12,
          ),
        ),
        style:
        OutlinedButton.styleFrom(
          padding:
          const EdgeInsets.symmetric(
            vertical: 12,
          ),
          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(
              10,
            ),
          ),
        ),
      ),
    );
  }

  // ===============================================================
  // PHOTO PREVIEW
  // ===============================================================

  Widget _photoPreview(
      _SelectedPhoto photo,
      int index,
      ) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius:
          BorderRadius.circular(10),
          child: Image.memory(
            photo.bytes,
            width: 82,
            height: 82,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          right: 3,
          top: 3,
          child: GestureDetector(
            onTap: _submitting
                ? null
                : () {
              setState(() {
                _photos.removeAt(
                  index,
                );
              });
            },
            child: Container(
              width: 23,
              height: 23,
              decoration:
              const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 15,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ===================================================================
// SELECTED PHOTO
// ===================================================================

class _SelectedPhoto {
  final String name;
  final Uint8List bytes;
  final String mimeType;

  const _SelectedPhoto({
    required this.name,
    required this.bytes,
    required this.mimeType,
  });
}

// ===================================================================
// MAINTENANCE DETAILS DIALOG
// ===================================================================

class _MaintenanceDetailsDialog
    extends StatelessWidget {
  final TenantMaintenance maintenance;

  const _MaintenanceDetailsDialog({
    required this.maintenance,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor =
    _statusColor(
      maintenance.status,
    );

    return Dialog(
      insetPadding:
      const EdgeInsets.all(18),
      backgroundColor: Colors.white,
      shape:
      RoundedRectangleBorder(
        borderRadius:
        BorderRadius.circular(20),
      ),
      child: ConstrainedBox(
        constraints:
        const BoxConstraints(
          maxWidth: 620,
          maxHeight: 720,
        ),
        child: Padding(
          padding:
          const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              // ===================================================
              // HEADER
              // ===================================================

              Row(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration:
                    BoxDecoration(
                      color:
                      const Color(
                        0xff1264E8,
                      ).withOpacity(.08),
                      borderRadius:
                      BorderRadius
                          .circular(
                        13,
                      ),
                    ),
                    child: const Icon(
                      Icons
                          .build_circle_outlined,
                      color:
                      Color(0xff1264E8),
                      size: 23,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [
                        const Text(
                          'Maintenance Request',
                          style:
                          TextStyle(
                            fontSize: 18,
                            fontWeight:
                            FontWeight
                                .w800,
                            color: Color(
                              0xff172033,
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 4,
                        ),
                        Text(
                          '#${maintenance.id}',
                          style:
                          TextStyle(
                            fontSize: 11.5,
                            color: Colors
                                .grey
                                .shade600,
                            fontWeight:
                            FontWeight
                                .w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    padding:
                    const EdgeInsets
                        .symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration:
                    BoxDecoration(
                      color:
                      statusColor
                          .withOpacity(
                        .09,
                      ),
                      borderRadius:
                      BorderRadius
                          .circular(
                        20,
                      ),
                    ),
                    child: Row(
                      mainAxisSize:
                      MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration:
                          BoxDecoration(
                            color:
                            statusColor,
                            shape:
                            BoxShape
                                .circle,
                          ),
                        ),
                        const SizedBox(
                          width: 6,
                        ),
                        Text(
                          maintenance
                              .statusLabel,
                          style:
                          TextStyle(
                            color:
                            statusColor,
                            fontSize: 11,
                            fontWeight:
                            FontWeight
                                .w700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 4),

                  IconButton(
                    onPressed: () =>
                        Navigator.pop(
                          context,
                        ),
                    icon: const Icon(
                      Icons.close_rounded,
                      color:
                      Color(0xff667085),
                    ),
                    tooltip: 'Close',
                  ),
                ],
              ),

              const SizedBox(height: 6),

              const Divider(height: 24),

              // ===================================================
              // BODY
              // ===================================================

              Expanded(
                child: ListView(
                  physics:
                  const BouncingScrollPhysics(),
                  children: [
                    _detailLabel(
                      'Subject',
                    ),

                    const SizedBox(
                      height: 6,
                    ),

                    Text(
                      maintenance.subject,
                      style:
                      const TextStyle(
                        fontSize: 16,
                        fontWeight:
                        FontWeight.w800,
                        color: Color(
                          0xff172033,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    _detailLabel(
                      'Description',
                    ),

                    const SizedBox(
                      height: 7,
                    ),

                    Container(
                      width:
                      double.infinity,
                      padding:
                      const EdgeInsets
                          .all(14),
                      decoration:
                      BoxDecoration(
                        color: const Color(
                          0xffF8FAFC,
                        ),
                        borderRadius:
                        BorderRadius
                            .circular(
                          13,
                        ),
                        border: Border.all(
                          color:
                          const Color(
                            0xffEAECF0,
                          ),
                        ),
                      ),
                      child: Text(
                        maintenance
                            .description,
                        style:
                        const TextStyle(
                          fontSize: 13,
                          height: 1.55,
                          color: Color(
                            0xff475467,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: _infoTile(
                            icon: Icons
                                .calendar_today_outlined,
                            title:
                            'Submitted',
                            value: maintenance
                                .formattedDateTime,
                          ),
                        ),
                        const SizedBox(
                          width: 10,
                        ),
                        Expanded(
                          child: _infoTile(
                            icon: Icons
                                .home_outlined,
                            title: 'Unit',
                            value: maintenance
                                .unit
                                .unitNumber,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 22,
                    ),

                    if (maintenance
                        .photos
                        .isNotEmpty) ...[
                      Row(
                        children: [
                          Expanded(
                            child:
                            _detailLabel(
                              'Attached Photos',
                            ),
                          ),
                          Text(
                            '${maintenance.photos.length} '
                                '${maintenance.photos.length == 1 ? 'photo' : 'photos'}',
                            style:
                            const TextStyle(
                              fontSize: 11,
                              color: Color(
                                0xff667085,
                              ),
                              fontWeight:
                              FontWeight
                                  .w500,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 10,
                      ),

                      _buildPhotoGallery(
                        context,
                      ),
                    ],

                    const SizedBox(
                      height: 12,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ===================================================
              // CLOSE
              // ===================================================

              SizedBox(
                width:
                double.infinity,
                height: 46,
                child:
                OutlinedButton(
                  onPressed: () =>
                      Navigator.pop(
                        context,
                      ),
                  style:
                  OutlinedButton.styleFrom(
                    foregroundColor:
                    const Color(
                      0xff344054,
                    ),
                    side:
                    const BorderSide(
                      color:
                      Color(0xffD0D5DD),
                    ),
                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius
                          .circular(
                        12,
                      ),
                    ),
                  ),
                  child:
                  const Text(
                    'Close',
                    style:
                    TextStyle(
                      fontSize: 13,
                      fontWeight:
                      FontWeight
                          .w700,
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

  // ===============================================================
  // PHOTO GALLERY
  // ===============================================================

  Widget _buildPhotoGallery(
      BuildContext context,
      ) {
    return GridView.builder(
      shrinkWrap: true,
      physics:
      const NeverScrollableScrollPhysics(),
      gridDelegate:
      const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.15,
      ),
      itemCount:
      maintenance.photos.length,
      itemBuilder:
          (context, index) {
        final photo =
        maintenance.photos[index];

        return GestureDetector(
          onTap: () {
            _openPhotoViewer(
              context,
              maintenance.photos,
              index,
              tagPrefix:
              'maintenance_photo_${maintenance.id}_',
            );
          },
          child: ClipRRect(
            borderRadius:
            BorderRadius.circular(13),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  photo,
                  fit: BoxFit.cover,
                  width:
                  double.infinity,
                  height:
                  double.infinity,

                  // Required for your
                  // Flutter Web setup.
                  webHtmlElementStrategy:
                  WebHtmlElementStrategy
                      .prefer,

                  loadingBuilder:
                      (
                      context,
                      child,
                      loadingProgress,
                      ) {
                    if (loadingProgress ==
                        null) {
                      return child;
                    }

                    return Container(
                      color: const Color(
                        0xffF2F4F7,
                      ),
                      child: Center(
                        child:
                        SizedBox(
                          width: 22,
                          height: 22,
                          child:
                          CircularProgressIndicator(
                            strokeWidth:
                            2,
                            value: loadingProgress
                                .expectedTotalBytes !=
                                null
                                ? loadingProgress
                                .cumulativeBytesLoaded /
                                loadingProgress
                                    .expectedTotalBytes!
                                : null,
                          ),
                        ),
                      ),
                    );
                  },

                  errorBuilder:
                      (
                      context,
                      error,
                      stackTrace,
                      ) {
                    return Container(
                      color: const Color(
                        0xffF2F4F7,
                      ),
                      child: Column(
                        mainAxisAlignment:
                        MainAxisAlignment
                            .center,
                        children: [
                          Icon(
                            Icons
                                .image_not_supported_outlined,
                            size: 28,
                            color: Colors
                                .grey
                                .shade400,
                          ),
                          const SizedBox(
                            height: 6,
                          ),
                          Text(
                            'Unable to load',
                            textAlign:
                            TextAlign
                                .center,
                            style:
                            TextStyle(
                              fontSize: 10,
                              color: Colors
                                  .grey
                                  .shade500,
                              fontWeight:
                              FontWeight
                                  .w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Photo counter
                Positioned(
                  right: 7,
                  bottom: 7,
                  child: Container(
                    padding:
                    const EdgeInsets
                        .symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration:
                    BoxDecoration(
                      color: Colors.black
                          .withOpacity(.58),
                      borderRadius:
                      BorderRadius
                          .circular(
                        8,
                      ),
                    ),
                    child: Text(
                      '${index + 1}/${maintenance.photos.length}',
                      style:
                      const TextStyle(
                        color:
                        Colors.white,
                        fontSize: 9.5,
                        fontWeight:
                        FontWeight
                            .w700,
                      ),
                    ),
                  ),
                ),

                // View icon
                Positioned(
                  top: 7,
                  right: 7,
                  child: Container(
                    width: 27,
                    height: 27,
                    decoration:
                    BoxDecoration(
                      color: Colors.black
                          .withOpacity(.48),
                      shape:
                      BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons
                          .open_in_full_rounded,
                      size: 14,
                      color:
                      Colors.white,
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

  Widget _detailLabel(
      String text,
      ) {
    return Text(
      text,
      style:
      const TextStyle(
        fontSize: 11,
        fontWeight:
        FontWeight.w700,
        color:
        Color(0xff667085),
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding:
      const EdgeInsets.all(12),
      decoration:
      BoxDecoration(
        color:
        const Color(0xffF8FAFC),
        borderRadius:
        BorderRadius.circular(
          12,
        ),
        border: Border.all(
          color:
          const Color(0xffEAECF0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration:
            BoxDecoration(
              color:
              const Color(
                0xff1264E8,
              ).withOpacity(.08),
              borderRadius:
              BorderRadius.circular(
                9,
              ),
            ),
            child: Icon(
              icon,
              size: 16,
              color:
              const Color(
                0xff1264E8,
              ),
            ),
          ),
          const SizedBox(
            width: 9,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style:
                  const TextStyle(
                    fontSize: 10,
                    color:
                    Color(0xff667085),
                    fontWeight:
                    FontWeight.w500,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style:
                  const TextStyle(
                    fontSize: 12,
                    fontWeight:
                    FontWeight.w700,
                    color:
                    Color(0xff172033),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// PHOTO VIEWER
// ===================================================================

void _openPhotoViewer(
    BuildContext context,
    List<String> photos,
    int initialIndex, {
      required String tagPrefix,
    }) {
  showDialog(
    context: context,
    barrierColor:
    Colors.black.withOpacity(.92),
    builder: (dialogContext) {
      final controller =
      PageController(
        initialPage: initialIndex,
      );

      return Dialog(
        backgroundColor:
        Colors.transparent,
        insetPadding:
        const EdgeInsets.all(12),
        child: StatefulBuilder(
          builder: (
              context,
              setState,
              ) {
            var currentIndex =
                initialIndex;

            return Stack(
              children: [
                // =================================================
                // IMAGE
                // =================================================

                Positioned.fill(
                  child:
                  PageView.builder(
                    controller:
                    controller,
                    itemCount:
                    photos.length,
                    onPageChanged:
                        (index) {
                      setState(() {
                        currentIndex =
                            index;
                      });
                    },
                    itemBuilder:
                        (context, index) {
                      final photo =
                      photos[index];

                      return Center(
                        child:
                        Image.network(
                          photo,
                          fit: BoxFit.contain,
                          width:
                          double.infinity,
                          height:
                          double.infinity,

                          // Keep the same strategy
                          // that fixed image loading
                          // on Flutter Web.
                          webHtmlElementStrategy:
                          WebHtmlElementStrategy
                              .prefer,

                          loadingBuilder:
                              (
                              context,
                              child,
                              loadingProgress,
                              ) {
                            if (loadingProgress ==
                                null) {
                              return child;
                            }

                            return const Center(
                              child:
                              SizedBox(
                                width: 32,
                                height: 32,
                                child:
                                CircularProgressIndicator(
                                  strokeWidth:
                                  2,
                                  color:
                                  Colors.white,
                                ),
                              ),
                            );
                          },

                          errorBuilder:
                              (
                              context,
                              error,
                              stackTrace,
                              ) {
                            return const Center(
                              child:
                              Column(
                                mainAxisSize:
                                MainAxisSize
                                    .min,
                                children: [
                                  Icon(
                                    Icons
                                        .broken_image_outlined,
                                    color: Colors
                                        .white70,
                                    size: 48,
                                  ),
                                  SizedBox(
                                    height: 12,
                                  ),
                                  Text(
                                    'Unable to load image',
                                    style:
                                    TextStyle(
                                      color: Colors
                                          .white70,
                                      fontSize:
                                      13,
                                    ),
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

                // =================================================
                // CLOSE
                // =================================================

                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.black
                        .withOpacity(.55),
                    shape:
                    const CircleBorder(),
                    child:
                    IconButton(
                      onPressed: () {
                        Navigator.of(
                          dialogContext,
                        ).pop();
                      },
                      icon:
                      const Icon(
                        Icons
                            .close_rounded,
                        color:
                        Colors.white,
                      ),
                      tooltip:
                      'Close',
                    ),
                  ),
                ),

                // =================================================
                // COUNTER
                // =================================================

                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding:
                    const EdgeInsets
                        .symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration:
                    BoxDecoration(
                      color: Colors.black
                          .withOpacity(.55),
                      borderRadius:
                      BorderRadius
                          .circular(
                        20,
                      ),
                    ),
                    child: Text(
                      '${currentIndex + 1} / ${photos.length}',
                      style:
                      const TextStyle(
                        color:
                        Colors.white,
                        fontSize: 12,
                        fontWeight:
                        FontWeight
                            .w700,
                      ),
                    ),
                  ),
                ),

                // =================================================
                // PREVIOUS
                // =================================================

                if (photos.length > 1)
                  Positioned(
                    left: 12,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Material(
                        color: Colors.black
                            .withOpacity(
                          .45,
                        ),
                        shape:
                        const CircleBorder(),
                        child:
                        IconButton(
                          onPressed:
                          currentIndex >
                              0
                              ? () {
                            controller
                                .previousPage(
                              duration:
                              const Duration(
                                milliseconds:
                                250,
                              ),
                              curve:
                              Curves
                                  .easeOut,
                            );
                          }
                              : null,
                          icon:
                          const Icon(
                            Icons
                                .chevron_left_rounded,
                            color: Colors
                                .white,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                  ),

                // =================================================
                // NEXT
                // =================================================

                if (photos.length > 1)
                  Positioned(
                    right: 12,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Material(
                        color: Colors.black
                            .withOpacity(
                          .45,
                        ),
                        shape:
                        const CircleBorder(),
                        child:
                        IconButton(
                          onPressed:
                          currentIndex <
                              photos.length -
                                  1
                              ? () {
                            controller
                                .nextPage(
                              duration:
                              const Duration(
                                milliseconds:
                                250,
                              ),
                              curve:
                              Curves
                                  .easeOut,
                            );
                          }
                              : null,
                          icon:
                          const Icon(
                            Icons
                                .chevron_right_rounded,
                            color: Colors
                                .white,
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

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'in_progress':
    case 'in progress':
      return const Color(0xff7F56D9);

    case 'resolved':
    case 'closed':
      return const Color(0xff12B76A);

    case 'open':
    default:
      return const Color(0xffF79009);
  }
}

IconData _statusIcon(String status) {
  switch (status.toLowerCase()) {
    case 'in_progress':
    case 'in progress':
      return Icons.engineering_outlined;

    case 'resolved':
    case 'closed':
      return Icons.check_circle_outline_rounded;

    case 'open':
    default:
      return Icons.pending_actions_rounded;
  }
}

String _statusLabel(String status) {
  switch (status.toLowerCase()) {
    case 'in_progress':
    case 'in progress':
      return 'In Progress';

    case 'resolved':
    case 'closed':
      return 'Resolved';

    case 'open':
    default:
      return 'Open';
  }
}