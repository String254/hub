import 'package:flutter/material.dart';
import 'package:hub/config/config.dart';
import 'package:hub/models/models.dart';
import 'package:hub/services/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with TickerProviderStateMixin {
  // ============================================================
  // API
  // ============================================================

  late ApiService apiService;

  late Future<List<MpesaTransaction>> mpesaFuture;
  late Future<List<MaintenanceNotification>> maintenanceFuture;
  late Future<List<OverdueNotification>> overdueFuture;

  // ============================================================
  // USER
  // ============================================================

  String? userFirstName;
  bool isLoadingUser = true;

  // ============================================================
  // READ / UNREAD
  // ============================================================

  final Set<String> readNotifications = {};

  static const String _readNotificationsKey = 'kejahub_read_notifications';

  // ============================================================
  // OVERDUE REMINDERS
  // ============================================================

  final Set<String> sentReminderNotifications = {};

  final Set<String> sendingReminderNotifications = {};

  static const String _sentReminderKey = 'kejahub_sent_overdue_reminders';

  // ============================================================
  // FILTERS
  // ============================================================

  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';

  int? _selectedMonth;
  int? _selectedYear;

  String _selectedType = 'All';

  // ============================================================
  // LOADING ANIMATIONS
  // ============================================================

  late AnimationController _loaderSpinController;
  late AnimationController _loaderPulseController;
  late AnimationController _loaderDotsController;

  // ============================================================
  // FILTER OPTIONS
  // ============================================================

  final List<String> _notificationTypes = [
    'All',
    'Payments',
    'Maintenance',
    'Overdue',
  ];

  // ============================================================
  // PROPERTY DATA
  // ============================================================

  Future<PropertyResponse> _maintenanceFuture = Future.value(
    PropertyResponse(
      properties: [],
      totalUnits: 0,
      occupiedUnits: 0,
      vacantUnits: 0,
      units: [],
    ),
  );

  Future<List<Nest>> _propertyFuture = Future.value(<Nest>[]);

  List<Nest> _propertyCache = [];

  List<PropertyDialog> _maintenanceProperties = [];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loaderSpinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _loaderPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _loaderDotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    apiService = ApiService(baseUrl: baseUrl);

    mpesaFuture = apiService.fetchMpesaNotifications('600000');

    maintenanceFuture = apiService.fetchMaintenanceNotifications();

    overdueFuture = apiService.fetchOverdueNotifications();

    _loadUserData();
    _loadReadNotifications();
    _loadSentReminders();
    _loadAllData();
  }

  // ============================================================
  // USER ID
  // ============================================================

  Future<String?> getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      return prefs.getString('user_id') ??
          prefs.getString('userId') ??
          prefs.getString('id');
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // USER DATA
  // ============================================================

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final fullName = prefs.getString('name');

      if (fullName != null && fullName.isNotEmpty) {
        userFirstName = fullName.split(' ')[0];
      } else {
        userFirstName =
            prefs.getString('first_name') ??
                prefs.getString('firstName') ??
                'User';
      }
    } catch (_) {
      userFirstName = 'User';
    }

    if (mounted) {
      setState(() {
        isLoadingUser = false;
      });
    }
  }

  // ============================================================
  // LOAD READ NOTIFICATIONS
  // ============================================================

  Future<void> _loadReadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final stored = prefs.getStringList(_readNotificationsKey) ?? [];

      if (!mounted) return;

      setState(() {
        readNotifications
          ..clear()
          ..addAll(stored);
      });
    } catch (e) {
      debugPrint('Read notification loading error: $e');
    }
  }

  // ============================================================
  // SAVE READ NOTIFICATIONS
  // ============================================================

  Future<void> _saveReadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setStringList(
        _readNotificationsKey,
        readNotifications.toList(),
      );
    } catch (e) {
      debugPrint('Read notification saving error: $e');
    }
  }

  // ============================================================
  // LOAD SENT REMINDERS
  // ============================================================

  Future<void> _loadSentReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final stored = prefs.getStringList(_sentReminderKey) ?? [];

      if (!mounted) return;

      setState(() {
        sentReminderNotifications
          ..clear()
          ..addAll(stored);
      });
    } catch (e) {
      debugPrint('Sent reminder loading error: $e');
    }
  }

  // ============================================================
  // SAVE SENT REMINDERS
  // ============================================================

  Future<void> _saveSentReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setStringList(
        _sentReminderKey,
        sentReminderNotifications.toList(),
      );
    } catch (e) {
      debugPrint('Sent reminder saving error: $e');
    }
  }

  // ============================================================
  // LOAD PROPERTY DATA
  // ============================================================

  Future<void> _loadAllData() async {
    final userIdStr = await getUserId();

    final int? userId = int.tryParse(userIdStr ?? '');

    _propertyFuture = apiService.fetchPropertiesData();

    if (userId != null) {
      _maintenanceFuture = apiService.fetchPropertyResponse(userId);
    } else {
      _maintenanceFuture = Future.value(
        PropertyResponse(
          properties: [],
          totalUnits: 0,
          occupiedUnits: 0,
          vacantUnits: 0,
          units: [],
        ),
      );
    }

    try {
      final props = await _propertyFuture;

      final maintResp = await _maintenanceFuture;

      if (!mounted) return;

      setState(() {
        _propertyCache = props;
        _maintenanceProperties = maintResp.properties;
      });
    } catch (e) {
      debugPrint('Property data loading error: $e');
    }
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> refreshNotifications() async {
    setState(() {
      mpesaFuture = apiService.fetchMpesaNotifications('600000');

      maintenanceFuture = apiService.fetchMaintenanceNotifications();

      overdueFuture = apiService.fetchOverdueNotifications();
    });

    await Future.wait([
      mpesaFuture,
      maintenanceFuture,
      overdueFuture,
    ]);
  }

  // ============================================================
  // READ STATE
  // ============================================================

  bool isRead(String key) {
    return readNotifications.contains(key);
  }

  Future<void> markAsRead(String key) async {
    if (readNotifications.contains(key)) {
      return;
    }

    setState(() {
      readNotifications.add(key);
    });

    await _saveReadNotifications();
  }

  Future<void> markAllAsRead(List<_InboxNotification> notifications) async {
    setState(() {
      for (final notification in notifications) {
        readNotifications.add(notification.key);
      }
    });

    await _saveReadNotifications();
  }

  // ============================================================
  // CURRENCY
  // ============================================================

  String formatKES(num amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_KE',
      symbol: 'Ksh ',
      decimalDigits: 0,
    );

    return formatter.format(amount);
  }

  // ============================================================
  // SEARCH
  // ============================================================

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value.trim().toLowerCase();
    });
  }

  // ============================================================
  // FILTER STATE
  // ============================================================

  bool get _hasActiveFilters {
    return _searchQuery.isNotEmpty ||
        _selectedMonth != null ||
        _selectedYear != null ||
        _selectedType != 'All';
  }


  List<int> get _availableYears {
    final current = DateTime.now().year;

    return List.generate(6, (index) => current - index);
  }

  // ============================================================
  // CLEAR FILTERS
  // ============================================================

  void _clearFilters() {
    setState(() {
      _searchQuery = '';

      _selectedMonth = null;

      _selectedYear = null;

      _selectedType = 'All';

      _searchController.clear();
    });
  }

  // ============================================================
  // DATE PARSER
  // ============================================================

  DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }

    try {
      if (value is DateTime) {
        return value;
      }

      final text = value.toString().trim();

      if (text.isEmpty) {
        return null;
      }

      if (RegExp(r'^\d{14}$').hasMatch(text)) {
        return DateTime(
          int.parse(text.substring(0, 4)),
          int.parse(text.substring(4, 6)),
          int.parse(text.substring(6, 8)),
          int.parse(text.substring(8, 10)),
          int.parse(text.substring(10, 12)),
          int.parse(text.substring(12, 14)),
        );
      }

      return DateTime.tryParse(text);
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // GET DATE
  // ============================================================

  DateTime? _notificationDate(dynamic notification) {
    try {
      if (notification is MpesaTransaction) {
        return _parseDate(notification.transactionTime);
      }

      if (notification is MaintenanceNotification) {
        return _parseDate(notification.createdAt);
      }

      if (notification is OverdueNotification) {
        return _parseDate(notification.invoiceDate);
      }
    } catch (_) {}

    return null;
  }

  // ============================================================
  // GET TENANT NAME
  // ============================================================

  String _notificationTenantName(dynamic notification) {
    try {
      if (notification is MpesaTransaction) {
        return notification.tenant?.name ??
            '${notification.firstName} '
                '${notification.lastName}'
                .trim();
      }

      if (notification is MaintenanceNotification) {
        return notification.tenant?.name ?? '';
      }

      if (notification is OverdueNotification) {
        return notification.tenant?.name ?? 'Unknown tenant';
      }
    } catch (_) {}

    return '';
  }

  // ============================================================
  // FILTER NOTIFICATION
  // ============================================================

  bool _matchesFilters(dynamic notification) {
    if (_selectedType != 'All') {
      if (_selectedType == 'Payments' && notification is! MpesaTransaction) {
        return false;
      }

      if (_selectedType == 'Maintenance' &&
          notification is! MaintenanceNotification) {
        return false;
      }

      if (_selectedType == 'Overdue' && notification is! OverdueNotification) {
        return false;
      }
    }

    if (_searchQuery.isNotEmpty) {
      final tenantName =
      _notificationTenantName(notification).toLowerCase();

      if (!tenantName.contains(_searchQuery)) {
        return false;
      }
    }

    final date = _notificationDate(notification);

    if (_selectedYear != null) {
      if (date == null || date.year != _selectedYear) {
        return false;
      }
    }

    if (_selectedMonth != null) {
      if (date == null || date.month != _selectedMonth) {
        return false;
      }
    }

    return true;
  }

  // ============================================================
  // FILTER LIST
  // ============================================================

  List<T> _filterNotifications<T>(List<T> notifications) {
    return notifications.where((item) => _matchesFilters(item)).toList();
  }

  // ============================================================
  // MONTH NAME
  // ============================================================

  String _monthName(int month) {
    return DateFormat('MMMM').format(DateTime(2024, month));
  }

  // ============================================================
  // CREATE INBOX NOTIFICATIONS
  // ============================================================

  List<_InboxNotification> _buildInboxNotifications(
      List<MpesaTransaction> mpesa,
      List<MaintenanceNotification> maintenance,
      List<OverdueNotification> overdue,
      ) {
    final notifications = <_InboxNotification>[];

    // ----------------------------------------------------------
    // M-PESA
    // ----------------------------------------------------------

    for (int i = 0; i < mpesa.length; i++) {
      final payment = mpesa[i];

      final tenantName = payment.tenant?.name ??
          '${payment.firstName} '
              '${payment.lastName}'
              .trim();

      final date = _notificationDate(payment);

      final key = _mpesaNotificationKey(payment, i);

      notifications.add(
        _InboxNotification(
          key: key,
          type: 'Payments',
          subject: tenantName.isEmpty
              ? 'Tenant payment received'
              : 'Payment received from $tenantName',
          description: 'M-Pesa payment of '
              '${formatKES(payment.amount)} '
              'received for Unit '
              '${payment.unitNumber}'
              ' • '
              '${payment.property?.name ?? 'Property'}',
          date: date,
          color: Colors.green,
          icon: Icons.payments_outlined,
          trailing: formatKES(payment.amount),
        ),
      );
    }

    // ----------------------------------------------------------
    // MAINTENANCE
    // ----------------------------------------------------------

    for (int i = 0; i < maintenance.length; i++) {
      final issue = maintenance[i];

      final date = _notificationDate(issue);

      final key = _maintenanceNotificationKey(issue, i);

      notifications.add(
        _InboxNotification(
          key: key,
          type: 'Maintenance',
          subject: issue.subject.isEmpty
              ? 'Maintenance request'
              : issue.subject,
          description:
          '${issue.tenant?.name ?? 'Unknown tenant'}'
              ' • Unit '
              '${issue.unit?.unitNumber ?? '-'}'
              ' • '
              '${issue.description}',
          date: date,
          color: Colors.orange,
          icon: Icons.build_outlined,
          trailing: _formatMaintenanceStatus(issue.status),
        ),
      );
    }

    // ----------------------------------------------------------
    // OVERDUE
    // ----------------------------------------------------------

    for (int i = 0; i < overdue.length; i++) {
      final payment = overdue[i];

      final date = _notificationDate(payment);

      final key = _overdueNotificationKey(payment, i);

      notifications.add(
        _InboxNotification(
          key: key,
          type: 'Overdue',
          subject: 'Overdue rent — '
              '${payment.tenant?.name ?? 'Unknown tenant'}',
          description: 'Unit '
              '${payment.unit?.unitNumber ?? '-'}'
              ' • '
              '${payment.property?.name ?? 'Property'}'
              ' • Outstanding balance',
          date: date,
          color: Colors.red,
          icon: Icons.warning_amber_rounded,
          trailing: formatKES(payment.balance),
          overdueNotification: payment,
        ),
      );
    }

    // ----------------------------------------------------------
    // SORT NEWEST FIRST
    // ----------------------------------------------------------

    notifications.sort((a, b) {
      final aDate =
          a.date ?? DateTime.fromMillisecondsSinceEpoch(0);

      final bDate =
          b.date ?? DateTime.fromMillisecondsSinceEpoch(0);

      return bDate.compareTo(aDate);
    });

    return notifications;
  }

  // ============================================================
  // STABLE NOTIFICATION KEYS
  // ============================================================

  String _mpesaNotificationKey(MpesaTransaction item, int index) {
    final tenant = item.tenant?.name ??
        '${item.firstName}'
            '${item.lastName}';

    final date = item.transactionTime.toString();

    return 'payment|'
        '${tenant.trim()}|'
        '$date|'
        '${item.amount}|'
        '${item.unitNumber}';
  }

  String _maintenanceNotificationKey(
      MaintenanceNotification item, int index) {
    final tenant = item.tenant?.name ?? '';

    final date = item.createdAt.toString();

    return 'maintenance|'
        '${item.subject}|'
        '${tenant.trim()}|'
        '$date|'
        '${item.unit?.unitNumber ?? ''}';
  }

  String _overdueNotificationKey(OverdueNotification item, int index) {
    final tenant = item.tenant?.name ?? '';

    final date = item.invoiceDate.toString();

    /*
     * Include the overdue notification ID
     * where available so the reminder state
     * belongs to the actual overdue record.
     */

    return 'overdue|'
        '${item.id}|'
        '${tenant.trim()}|'
        '$date|'
        '${item.balance}|'
        '${item.unit?.unitNumber ?? ''}';
  }

  // ============================================================
  // REMINDER KEY
  // ============================================================

  String _reminderKey(OverdueNotification notification) {
    return _overdueNotificationKey(notification, 0);
  }

  // ============================================================
  // SEND OVERDUE REMINDER
  // ============================================================

  Future<void> _sendOverdueReminder(OverdueNotification notification) async {
    final key = _reminderKey(notification);

    if (sentReminderNotifications.contains(key)) {
      return;
    }

    if (sendingReminderNotifications.contains(key)) {
      return;
    }

    final confirmed = await _showReminderConfirmation(
      notification,
    );

    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      sendingReminderNotifications.add(key);
    });

    try {
      /*
    |--------------------------------------------------------------------------
    | Flutter → authenticated Laravel → n8n
    |--------------------------------------------------------------------------
    */

      final invoiceId = notification.id;

      debugPrint('');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📨 OVERDUE REMINDER REQUEST');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('➡️ Invoice ID: $invoiceId');
      debugPrint(
        '➡️ Tenant: ${notification.tenant?.name}',
      );
      debugPrint(
        '➡️ Unit: ${notification.unit?.unitNumber}',
      );
      debugPrint(
        '➡️ Balance: ${notification.balance}',
      );

      final response = await apiService.sendOverdueReminder(
        invoiceId,
      );

      debugPrint('⬅️ Laravel response: $response');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      if (response['success'] == true) {
        if (!mounted) return;

        setState(() {
          sendingReminderNotifications.remove(key);
          sentReminderNotifications.add(key);
        });

        await _saveSentReminders();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green.shade700,
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Reminder sent to '
                        '${notification.tenant?.name ?? 'tenant'}',
                  ),
                ),
              ],
            ),
          ),
        );

        return;
      }

      throw Exception(
        response['message'] ??
            'Unable to send reminder.',
      );
    } catch (e) {
      debugPrint(
        '❌ OVERDUE REMINDER ERROR: $e',
      );

      if (!mounted) return;

      setState(() {
        sendingReminderNotifications.remove(key);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
          content: Row(
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  e.toString().replaceFirst(
                    'Exception: ',
                    '',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  // ============================================================
  // REMINDER CONFIRMATION
  // ============================================================

  Future<bool> _showReminderConfirmation(
      OverdueNotification notification) async {
    final tenantName = notification.tenant?.name ?? 'Unknown tenant';

    final unitNumber = notification.unit?.unitNumber ?? '-';

    final balance = formatKES(notification.balance);

    final propertyName = notification.property?.name ?? 'Property';

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_active_outlined,
                  color: Colors.orange.shade700,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Text(
                  'Send rent reminder?',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A rent reminder will be sent to:',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 14),

              _reminderInfoRow(
                Icons.person_outline,
                'Tenant',
                tenantName,
              ),

              const SizedBox(height: 8),

              _reminderInfoRow(
                Icons.home_outlined,
                'Property',
                propertyName,
              ),

              const SizedBox(height: 8),

              _reminderInfoRow(
                Icons.door_front_door_outlined,
                'Unit',
                unitNumber,
              ),

              const SizedBox(height: 8),

              _reminderInfoRow(
                Icons.payments_outlined,
                'Outstanding',
                balance,
              ),

              const SizedBox(height: 15),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 17,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'A daily reminder will be sent to the tenant '
                            'until the balance is paid.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(
                Icons.send_outlined,
                size: 17,
              ),
              label: const Text('Send reminder'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  // ============================================================
  // REMINDER INFO ROW
  // ============================================================

  Widget _reminderInfoRow(
      IconData icon,
      String label,
      String value,
      ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 17,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 9),
        SizedBox(
          width: 82,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.grey.shade500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // MAINTENANCE STATUS
  // ============================================================

  String _formatMaintenanceStatus(String status) {
    switch (status.toLowerCase()) {
      case 'in_progress':
        return 'In Progress';

      case 'resolved':
        return 'Resolved';

      case 'open':
        return 'Open';

      default:
        return status;
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF7F9FC),
      body: RefreshIndicator(
        onRefresh: refreshNotifications,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildNotificationsHeader(),

              const SizedBox(height: 16),

              _buildInboxToolbar(),

              const SizedBox(height: 12),

              _buildNotificationInbox(),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildNotificationsHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xff1E3A8A),
            Color(0xff2563EB),
            Color(0xff3B82F6),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff2563EB).withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -50,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isLoadingUser
                              ? 'Hello'
                              : 'Hello, ${userFirstName ?? 'User'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'SF-Pro-Text-Bold',
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Here is what is happening across your properties',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INBOX TOOLBAR
  // ============================================================

  Widget _buildInboxToolbar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 750;

          final search = TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search notifications...',
              hintStyle: TextStyle(
                fontSize: 13.5,
                color: Colors.grey.shade500,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 20,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                onPressed: () {
                  _searchController.clear();

                  _onSearchChanged('');
                },
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                ),
              )
                  : null,
              filled: true,
              fillColor: const Color(0xffF7F9FC),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          );

          if (compact) {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: search,
                    ),
                    const SizedBox(width: 8),
                    _filterButton(),
                  ],
                ),
                if (_hasActiveFilters) ...[
                  const SizedBox(height: 8),
                  _activeFilterSummary(),
                ],
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: search,
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 125,
                child: _buildFilterDropdown(
                  value: _selectedYear?.toString(),
                  items: [
                    'All years',
                    ..._availableYears.map(
                          (e) => e.toString(),
                    ),
                  ],
                  label: 'Year',
                  onChanged: (value) {
                    setState(() {
                      if (value == null || value == 'All years') {
                        _selectedYear = null;
                      } else {
                        _selectedYear = int.tryParse(value);
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 140,
                child: _buildFilterDropdown(
                  value: _selectedMonth == null
                      ? null
                      : _monthName(_selectedMonth!),
                  items: [
                    'All months',
                    ...List.generate(
                      12,
                          (index) => _monthName(index + 1),
                    ),
                  ],
                  label: 'Month',
                  onChanged: (value) {
                    setState(() {
                      if (value == null || value == 'All months') {
                        _selectedMonth = null;
                      } else {
                        _selectedMonth = List.generate(
                          12,
                              (index) => _monthName(index + 1),
                        ).indexOf(value) +
                            1;
                      }
                    });
                  },
                ),
              ),
              if (_hasActiveFilters) ...[
                const SizedBox(width: 6),
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text(
                    'Clear',
                    style: TextStyle(
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // INBOX
  // ============================================================

  Widget _buildNotificationInbox() {
    return FutureBuilder(
      future: Future.wait([
        mpesaFuture,
        maintenanceFuture,
        overdueFuture,
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildInboxLoading();
        }

        if (snapshot.hasError) {
          return _buildInboxError();
        }

        final mpesa = _filterNotifications<MpesaTransaction>(
          snapshot.data![0] as List<MpesaTransaction>,
        );

        final maintenance = _filterNotifications<MaintenanceNotification>(
          snapshot.data![1] as List<MaintenanceNotification>,
        );

        final overdue = _filterNotifications<OverdueNotification>(
          snapshot.data![2] as List<OverdueNotification>,
        );

        final notifications = _buildInboxNotifications(
          mpesa,
          maintenance,
          overdue,
        );

        if (notifications.isEmpty) {
          return _buildInboxEmpty();
        }

        final unreadCount = notifications
            .where(
              (notification) => !isRead(notification.key),
        )
            .length;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.shade200,
            ),
          ),
          child: Column(
            children: [
              _buildInboxHeader(
                notifications.length,
                unreadCount,
                notifications,
              ),
              Divider(
                height: 1,
                color: Colors.grey.shade200,
              ),
              ...notifications.map(
                    (notification) => _buildInboxRow(notification),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // INBOX HEADER
  // ============================================================

  Widget _buildInboxHeader(
      int total,
      int unread,
      List<_InboxNotification> notifications,
      ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 10, 13),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_none_rounded,
            size: 20,
          ),
          const SizedBox(width: 9),
          const Text(
            'Notifications',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.bold,
              fontFamily: 'SF-Pro-Text-Bold',
            ),
          ),
          const SizedBox(width: 7),
          if (unread > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$unread unread',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
          const Spacer(),
          Text(
            '$total total',
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.grey.shade500,
            ),
          ),
          if (unread > 0) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => markAllAsRead(notifications),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 4,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Mark all read',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // INBOX ROW
  // ============================================================

  Widget _buildInboxRow(_InboxNotification notification) {
    final read = isRead(notification.key);

    final isOverdue = notification.type == 'Overdue';

    final overdue = notification.overdueNotification;

    final reminderSent = overdue != null &&
        sentReminderNotifications.contains(_reminderKey(overdue));

    final reminderSending = overdue != null &&
        sendingReminderNotifications.contains(_reminderKey(overdue));

    return InkWell(
      onTap: () async {
        await markAsRead(notification.key);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: read ? Colors.white : const Color(0xffF4F8FF),
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.shade100,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --------------------------------------------------
            // UNREAD INDICATOR
            // --------------------------------------------------

            SizedBox(
              width: 12,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: read ? 0 : 7,
                  height: read ? 0 : 7,
                  decoration: BoxDecoration(
                    color: read
                        ? Colors.transparent
                        : notification.color.shade600,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 5),

            // --------------------------------------------------
            // ICON
            // --------------------------------------------------

            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: notification.color.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                notification.icon,
                size: 18,
                color: notification.color.shade700,
              ),
            ),

            const SizedBox(width: 11),

            // --------------------------------------------------
            // CONTENT
            // --------------------------------------------------

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          notification.subject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight:
                            read ? FontWeight.w500 : FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _buildDate(notification.date, read),
                    ],
                  ),

                  const SizedBox(height: 3),

                  Text(
                    notification.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: read ? FontWeight.w400 : FontWeight.w600,
                      color: read
                          ? Colors.grey.shade600
                          : Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            ),

            // --------------------------------------------------
            // OVERDUE REMINDER ACTION
            // --------------------------------------------------

            if (isOverdue && overdue != null) ...[
              const SizedBox(width: 10),

              _buildReminderButton(
                overdue,
                reminderSent,
                reminderSending,
              ),
            ] else if (notification.trailing != null) ...[
              const SizedBox(width: 10),
              _buildTrailing(notification),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // REMINDER BUTTON
  // ============================================================

  Widget _buildReminderButton(
      OverdueNotification notification,
      bool sent,
      bool sending,
      ) {
    if (sending) {
      return Container(
        height: 31,
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
        ),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Sending',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade700,
              ),
            ),
          ],
        ),
      );
    }

    if (sent) {
      return Container(
        height: 31,
        padding: const EdgeInsets.symmetric(
          horizontal: 9,
        ),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 14,
              color: Colors.green.shade700,
            ),
            const SizedBox(width: 5),
            Text(
              'Sent',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
          ],
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _sendOverdueReminder(notification),
        child: Container(
          height: 31,
          padding: const EdgeInsets.symmetric(
            horizontal: 9,
          ),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.red.shade100,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.send_outlined,
                size: 14,
                color: Colors.red.shade700,
              ),
              const SizedBox(width: 5),
              Text(
                'Remind',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DATE
  // ============================================================

  Widget _buildDate(DateTime? date, bool read) {
    if (date == null) {
      return const SizedBox();
    }

    final now = DateTime.now();

    final sameDay = now.year == date.year &&
        now.month == date.month &&
        now.day == date.day;

    final yesterday = now
        .difference(
      DateTime(
        date.year,
        date.month,
        date.day,
      ),
    )
        .inDays ==
        1;

    String text;

    if (sameDay) {
      text = DateFormat('HH:mm').format(date);
    } else if (yesterday) {
      text = 'Yesterday';
    } else if (now.year == date.year) {
      text = DateFormat('dd MMM').format(date);
    } else {
      text = DateFormat('dd MMM yyyy').format(date);
    }

    return Text(
      text,
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: read ? FontWeight.w400 : FontWeight.w700,
        color: read ? Colors.grey.shade500 : Colors.grey.shade700,
      ),
    );
  }

  // ============================================================
  // TRAILING
  // ============================================================

  Widget _buildTrailing(_InboxNotification notification) {
    final value = notification.trailing!;

    final isStatus = notification.type == 'Maintenance';

    return Container(
      constraints: const BoxConstraints(
        maxWidth: 100,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: notification.color.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: isStatus ? 9.5 : 10.5,
          fontWeight: FontWeight.bold,
          color: notification.color.shade700,
        ),
      ),
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _buildInboxLoading() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 46,
      ),
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
          SizedBox(
            width: 130,
            height: 130,
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _loaderSpinController,
                _loaderPulseController,
              ]),
              builder: (context, _) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.scale(
                      scale: 0.9 + (_loaderPulseController.value * 0.15),
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xff2563EB)
                                  .withValues(alpha: 0.18),
                              const Color(0xff2563EB)
                                  .withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    RotationTransition(
                      turns: _loaderSpinController,
                      child: CustomPaint(
                        size: const Size(120, 120),
                        painter: _CircularArcPainter(
                          sweep: 1.5,
                          strokeWidth: 4.5,
                          gradientColors: const [
                            Color(0xff1E3A8A),
                            Color(0xff2563EB),
                            Color(0xff60A5FA),
                            Color(0xff93C5FD),
                          ],
                        ),
                      ),
                    ),
                    RotationTransition(
                      turns: Tween<double>(
                        begin: 1.0,
                        end: 0.0,
                      ).animate(_loaderSpinController),
                      child: CustomPaint(
                        size: const Size(88, 88),
                        painter: _CircularArcPainter(
                          sweep: 0.85,
                          strokeWidth: 3,
                          gradientColors: [
                            const Color(0xff3B82F6)
                                .withValues(alpha: 0.0),
                            const Color(0xff3B82F6)
                                .withValues(alpha: 0.9),
                            const Color(0xffBFDBFE)
                                .withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xffEFF6FF),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xff2563EB)
                                .withValues(alpha: 0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.notifications_active_rounded,
                        size: 26,
                        color: Color(0xff2563EB),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          AnimatedBuilder(
            animation: _loaderSpinController,
            builder: (context, _) {
              final captions = [
                'Syncing notifications…',
                'Fetching updates…',
                'Almost there…',
              ];

              final index = (_loaderSpinController.value * captions.length)
                  .floor() %
                  captions.length;

              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                child: Text(
                  captions[index],
                  key: ValueKey<int>(index),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xff1E3A8A),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Text(
            'Please wait while we load your latest updates.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _loaderDotsController,
            builder: (context, _) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final phase = (_loaderDotsController.value * 5) - i;

                  final opacity = (0.35 +
                      (0.65 * (1 - (phase.abs() % 5) / 5)))
                      .clamp(0.25, 1.0);

                  final scale = (0.8 + (0.4 * (1 - (phase.abs() % 5) / 5)))
                      .clamp(0.7, 1.2);

                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xff2563EB)
                            .withValues(alpha: opacity),
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildInboxError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 34,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 10),
          const Text(
            'Unable to load notifications',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pull down to refresh.',
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildInboxEmpty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 55,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _hasActiveFilters
                  ? Icons.filter_alt_off_outlined
                  : Icons.notifications_none_outlined,
              size: 30,
              color: Colors.blue.shade600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _hasActiveFilters
                ? 'No matching notifications'
                : 'You are all caught up',
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _hasActiveFilters
                ? 'Try adjusting your filters.'
                : 'There are no notifications to display.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.grey.shade500,
            ),
          ),
          if (_hasActiveFilters) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: _clearFilters,
              child: const Text(
                'Clear filters',
                style: TextStyle(
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // FILTER DROPDOWN
  // ============================================================

  Widget _buildFilterDropdown({
    required String? value,
    required List<String> items,
    required String label,
    required ValueChanged<String?> onChanged,
  }) {
    final currentValue = value == null ? items.first : value;

    return DropdownButtonFormField<String>(
      initialValue: items.contains(currentValue) ? currentValue : items.first,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontSize: 11.5,
        ),
        filled: true,
        fillColor: const Color(0xffF7F9FC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 4,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
      style: const TextStyle(
        fontSize: 12.5,
        color: Colors.black87,
      ),
      items: items
          .map(
            (item) => DropdownMenuItem(
          value: item,
          child: Text(
            item,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      )
          .toList(),
      onChanged: onChanged,
    );
  }

  // ============================================================
  // MOBILE FILTER BUTTON
  // ============================================================

  Widget _filterButton() {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: _showMobileFilters,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.blue.shade100,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              Icons.tune_rounded,
              color: Colors.blue.shade700,
              size: 20,
            ),
            if (_hasActiveFilters)
              Positioned(
                right: -4,
                top: -5,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 1.5,
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
  // ACTIVE FILTER SUMMARY
  // ============================================================

  Widget _activeFilterSummary() {
    final filters = <String>[];

    if (_selectedType != 'All') {
      filters.add(_selectedType);
    }

    if (_selectedYear != null) {
      filters.add(_selectedYear.toString());
    }

    if (_selectedMonth != null) {
      filters.add(_monthName(_selectedMonth!));
    }

    if (_searchQuery.isNotEmpty) {
      filters.add('"$_searchQuery"');
    }

    return Row(
      children: [
        Icon(
          Icons.filter_alt_rounded,
          size: 15,
          color: Colors.blue.shade700,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            'Active: ${filters.join(' • ')}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.blue.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(
          onPressed: _clearFilters,
          child: const Text(
            'Clear',
            style: TextStyle(
              fontSize: 11.5,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // MOBILE FILTERS
  // ============================================================

  void _showMobileFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 25),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Filter notifications',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          _clearFilters();

                          setSheetState(() {});
                        },
                        child: const Text(
                          'Reset',
                          style: TextStyle(
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Notification type',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _notificationTypes
                        .map(
                          (type) {
                        final selected = _selectedType == type;

                        return ChoiceChip(
                          label: Text(type),
                          selected: selected,
                          onSelected: (_) {
                            setSheetState(() {
                              _selectedType = type;
                            });

                            setState(() {});
                          },
                          selectedColor: Colors.blue.shade700,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            color: selected
                                ? Colors.white
                                : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    )
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildFilterDropdown(
                          value: _selectedYear?.toString(),
                          items: [
                            'All years',
                            ..._availableYears.map(
                                  (e) => e.toString(),
                            ),
                          ],
                          label: 'Year',
                          onChanged: (value) {
                            setSheetState(() {
                              if (value == 'All years') {
                                _selectedYear = null;
                              } else {
                                _selectedYear =
                                    int.tryParse(value ?? '');
                              }
                            });

                            setState(() {});
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildFilterDropdown(
                          value: _selectedMonth == null
                              ? null
                              : _monthName(_selectedMonth!),
                          items: [
                            'All months',
                            ...List.generate(
                              12,
                                  (index) => _monthName(index + 1),
                            ),
                          ],
                          label: 'Month',
                          onChanged: (value) {
                            setSheetState(() {
                              if (value == 'All months') {
                                _selectedMonth = null;
                              } else {
                                _selectedMonth = List.generate(
                                  12,
                                      (index) => _monthName(index + 1),
                                ).indexOf(value ?? '') +
                                    1;
                              }
                            });

                            setState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Apply filters',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _loaderSpinController.dispose();
    _loaderPulseController.dispose();
    _loaderDotsController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}

// ================================================================
// CIRCULAR ARC PAINTER
// ================================================================

class _CircularArcPainter extends CustomPainter {
  final double sweep;
  final double strokeWidth;
  final List<Color> gradientColors;

  const _CircularArcPainter({
    required this.sweep,
    required this.strokeWidth,
    required this.gradientColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: gradientColors,
        startAngle: 0.0,
        endAngle: 3.1415926535 * 2,
      ).createShader(rect);

    canvas.drawArc(
      rect.deflate(strokeWidth / 2),
      -1.5707963268,
      sweep * 3.1415926535,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularArcPainter oldDelegate) {
    return oldDelegate.sweep != sweep ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.gradientColors != gradientColors;
  }
}

// ================================================================
// INBOX NOTIFICATION MODEL
// ================================================================

class _InboxNotification {
  final String key;

  final String type;

  final String subject;

  final String description;

  final DateTime? date;

  final MaterialColor color;

  final IconData icon;

  final String? trailing;

  final OverdueNotification? overdueNotification;

  const _InboxNotification({
    required this.key,
    required this.type,
    required this.subject,
    required this.description,
    required this.date,
    required this.color,
    required this.icon,
    this.trailing,
    this.overdueNotification,
  });
}