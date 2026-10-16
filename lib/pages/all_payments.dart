import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:flutter/material.dart';
import 'package:hub/config/config.dart';
import 'package:hub/models/models.dart';
import 'package:hub/pages/chat.dart';
import 'package:hub/widgets/widgets.dart';
import 'package:hub/services/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';


class AllPaymentsPage extends StatefulWidget {
  final List<RecentPayment> payments;

  const AllPaymentsPage({
    super.key,
    required this.payments,
  });

  @override
  State<AllPaymentsPage> createState() => _AllPaymentsPageState();
}

class _AllPaymentsPageState extends State<AllPaymentsPage> {
  late List<RecentPayment> _payments;

  String _searchQuery = '';
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();

    _payments = [...widget.payments];

    _sortPayments();
  }

  void _sortPayments() {
    _payments.sort((a, b) {
      final aDate = _parseDate(a.paymentDate);
      final bDate = _parseDate(b.paymentDate);

      return bDate.compareTo(aDate);
    });
  }

  DateTime _parseDate(String value) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;

    return value[0].toUpperCase() +
        value.substring(1).toLowerCase();
  }

  String _formatKes(double amount) {
    return 'KES ${NumberFormat('#,##0.00').format(amount)}';
  }

  List<RecentPayment> get _filteredPayments {
    List<RecentPayment> result = [..._payments];

    // ------------------------------------------------
    // SEARCH
    // ------------------------------------------------

    if (_searchQuery
        .trim()
        .isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();

      result = result.where((payment) {
        return payment.tenantName
            .toLowerCase()
            .contains(query) ||
            payment.unitNumber
                .toLowerCase()
                .contains(query) ||
            payment.status
                .toLowerCase()
                .contains(query);
      }).toList();
    }

    // ------------------------------------------------
    // DATE FILTER
    // ------------------------------------------------

    final now = DateTime.now();

    if (_selectedFilter == 'This Month') {
      result = result.where((payment) {
        final date = _parseDate(payment.paymentDate);

        return date.year == now.year &&
            date.month == now.month;
      }).toList();
    }

    if (_selectedFilter == 'Last Month') {
      final lastMonth = DateTime(
        now.year,
        now.month - 1,
      );

      result = result.where((payment) {
        final date = _parseDate(payment.paymentDate);

        return date.year == lastMonth.year &&
            date.month == lastMonth.month;
      }).toList();
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final payments = _filteredPayments;

    final totalAmount = payments.fold<double>(
      0,
          (sum, payment) {
        return sum + (double.tryParse(
          payment.amount.toString(),
        ) ?? 0);
      },
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,

        title: const Text(
          'All Payments',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _payments = [...widget.payments];
            _sortPayments();
          });
        },

        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),

          slivers: [
            SliverToBoxAdapter(
              child: _buildSummary(
                totalAmount,
                payments.length,
              ),
            ),

            SliverToBoxAdapter(
              child: _buildSearch(),
            ),

            SliverToBoxAdapter(
              child: _buildFilters(),
            ),

            if (payments.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(),
              )
            else
              _buildGroupedPayments(payments),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(double totalAmount,
      int count,) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        8,
      ),
      child: Container(
        padding: const EdgeInsets.all(18),

        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.green.shade700,
              Colors.teal.shade600,
            ],
          ),

          borderRadius: BorderRadius.circular(18),

          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(.15),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),

        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Received',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'KES ${NumberFormat('#,##0.00').format(totalAmount)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),

            Container(
              height: 42,
              width: 1,
              color: Colors.white24,
            ),

            const SizedBox(width: 20),

            Column(
              crossAxisAlignment:
              CrossAxisAlignment.end,
              children: [
                const Text(
                  'Payments',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        12,
        16,
        8,
      ),
      child: TextField(
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },

        decoration: InputDecoration(
          hintText:
          'Search tenant or unit...',

          hintStyle: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
          ),

          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
          ),

          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: const Icon(
              Icons.clear,
              size: 18,
            ),
            onPressed: () {
              setState(() {
                _searchQuery = '';
              });
            },
          )
              : null,

          filled: true,
          fillColor: Colors.white,

          contentPadding:
          const EdgeInsets.symmetric(
            vertical: 12,
          ),

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        4,
        16,
        10,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip('All'),
            _filterChip('This Month'),
            _filterChip('Last Month'),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label) {
    final selected = _selectedFilter == label;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight:
            selected
                ? FontWeight.w600
                : FontWeight.w400,
            color: selected
                ? Colors.white
                : Colors.grey.shade700,
          ),
        ),

        selected: selected,

        selectedColor: Colors.green.shade600,

        backgroundColor: Colors.white,

        side: BorderSide(
          color: selected
              ? Colors.green.shade600
              : Colors.grey.shade200,
        ),

        onSelected: (_) {
          setState(() {
            _selectedFilter = label;
          });
        },
      ),
    );
  }

  Widget _buildGroupedPayments(List<RecentPayment> payments,) {
    final Map<String, List<RecentPayment>> grouped = {};

    for (final payment in payments) {
      final date = _parseDate(payment.paymentDate);

      final key = DateFormat(
        'yyyy-MM',
      ).format(date);

      grouped.putIfAbsent(
        key,
            () => [],
      );

      grouped[key]!.add(payment);
    }

    final months = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          final key = months[index];

          final monthPayments = grouped[key]!;

          final monthDate = DateTime.parse(
            '$key-01',
          );

          final total = monthPayments.fold<double>(
            0,
                (sum, payment) =>
            sum +
                (double.tryParse(
                  payment.amount.toString(),
                ) ??
                    0),
          );

          return _buildMonthSection(
            monthDate,
            monthPayments,
            total,
          );
        },
        childCount: months.length,
      ),
    );
  }

  Widget _buildMonthSection(DateTime month,
      List<RecentPayment> payments,
      double total,) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        4,
        16,
        12,
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 8,
            ),
            child: Row(
              children: [
                Text(
                  DateFormat(
                    'MMMM yyyy',
                  ).format(month),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(width: 8),

                Container(
                  padding:
                  const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius:
                    BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${payments.length}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),

                const Spacer(),

                Text(
                  'KES ${NumberFormat('#,##0').format(total)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),

          ...payments.map(
                (payment) =>
                Padding(
                  padding:
                  const EdgeInsets.only(bottom: 8),
                  child: _buildAllPaymentCard(
                    payment,
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllPaymentCard(RecentPayment payment,) {
    final isPaid =
        payment.status.toLowerCase() == 'paid';

    final date =
    _parseDate(payment.paymentDate);

    final amount =
        double.tryParse(
          payment.amount.toString(),
        ) ??
            0;

    return Container(
      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade100,
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.025),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),

      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,

            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),

            child: Icon(
              BootstrapIcons
                  .check_circle_fill,
              color: Colors.green.shade600,
              size: 19,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  payment.tenantName,
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,

                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(width: 8),

                    Icon(
                      BootstrapIcons.calendar3,
                      size: 10,
                      color: Colors.grey.shade500,
                    ),

                    const SizedBox(width: 4),

                    Text(
                      DateFormat(
                        'dd MMM yyyy',
                      ).format(date),
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

          const SizedBox(width: 10),

          Column(
            crossAxisAlignment:
            CrossAxisAlignment.end,
            children: [
              Text(
              _formatKes(amount),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.green.shade700,
                ),
              ),

              const SizedBox(height: 5),

              Container(
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 3,
                ),

                decoration: BoxDecoration(
                  color: isPaid
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius:
                  BorderRadius.circular(5),
                ),

                child: Text(
                  _capitalize(
                    payment.status,
                  ),
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: isPaid
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                BootstrapIcons.cash_stack,
                size: 38,
                color: Colors.green.shade500,
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              'No payments found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 7),

            Text(
              _searchQuery.isNotEmpty
                  ? 'Try searching for another tenant or unit.'
                  : 'Confirmed payments will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}