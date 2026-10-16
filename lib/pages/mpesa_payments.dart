import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:hub/models/models.dart';


class AllMpesaPaymentsPage extends StatefulWidget {
  final List<MpesaTransaction> transactions;

  const AllMpesaPaymentsPage({
    super.key,
    required this.transactions,
  });

  @override
  State<AllMpesaPaymentsPage> createState() =>
      _AllMpesaPaymentsPageState();
}

class _AllMpesaPaymentsPageState
    extends State<AllMpesaPaymentsPage> {

  late List<MpesaTransaction> _transactions;

  String _searchQuery = '';
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();

    _transactions = [...widget.transactions];

    _transactions.sort(
          (a, b) => _parseDate(
        b.transactionTime,
      ).compareTo(
        _parseDate(a.transactionTime),
      ),
    );
  }

  // ============================================================
  // DATE
  // ============================================================

  DateTime _parseDate(String value) {
    // M-Pesa format:
    // 20260817150000

    if (value.length >= 14 &&
        RegExp(r'^\d{14}$').hasMatch(value)) {
      try {
        return DateTime(
          int.parse(value.substring(0, 4)),
          int.parse(value.substring(4, 6)),
          int.parse(value.substring(6, 8)),
          int.parse(value.substring(8, 10)),
          int.parse(value.substring(10, 12)),
          int.parse(value.substring(12, 14)),
        );
      } catch (_) {}
    }

    return DateTime.tryParse(value) ??
        DateTime.now();
  }

  // ============================================================
  // CURRENCY
  // ============================================================

  String _formatKes(double amount) {
    return 'KES ${NumberFormat('#,##0.00').format(amount)}';
  }

  // ============================================================
  // FILTERED TRANSACTIONS
  // ============================================================

  List<MpesaTransaction> get _filteredTransactions {
    List<MpesaTransaction> result =
    [..._transactions];

    // ----------------------------------------------------------
    // SEARCH
    // ----------------------------------------------------------

    if (_searchQuery.trim().isNotEmpty) {
      final query =
      _searchQuery.trim().toLowerCase();

      result = result.where((transaction) {
        return transaction.firstName
            .toLowerCase()
            .contains(query) ||
            transaction.lastName
                .toLowerCase()
                .contains(query) ||
            transaction.unitNumber
                .toLowerCase()
                .contains(query) ||
            transaction.transactionId
                .toLowerCase()
                .contains(query) ||
            transaction.billRefNumber
                .toLowerCase()
                .contains(query);
      }).toList();
    }

    // ----------------------------------------------------------
    // DATE FILTER
    // ----------------------------------------------------------

    final now = DateTime.now();

    if (_selectedFilter == 'This Month') {
      result = result.where((transaction) {
        final date =
        _parseDate(transaction.transactionTime);

        return date.year == now.year &&
            date.month == now.month;
      }).toList();
    }

    if (_selectedFilter == 'Last Month') {
      final lastMonth = DateTime(
        now.year,
        now.month - 1,
      );

      result = result.where((transaction) {
        final date =
        _parseDate(transaction.transactionTime);

        return date.year == lastMonth.year &&
            date.month == lastMonth.month;
      }).toList();
    }

    return result;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final filtered =
        _filteredTransactions;

    final total = filtered.fold<double>(
      0,
          (sum, transaction) {
        return sum +
            (double.tryParse(
              transaction.amount.toString(),
            ) ??
                0);
      },
    );

    return Scaffold(
      backgroundColor:
      const Color(0xFFF7F9FC),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,

        title: const Text(
          'Mpesa Payments',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      body: CustomScrollView(
        slivers: [

          // ========================================================
          // SUMMARY
          // ========================================================

          SliverToBoxAdapter(
            child: _buildMpesaSummary(
              total,
              filtered.length,
            ),
          ),

          // ========================================================
          // SEARCH
          // ========================================================

          SliverToBoxAdapter(
            child: _buildMpesaSearch(),
          ),

          // ========================================================
          // FILTERS
          // ========================================================

          SliverToBoxAdapter(
            child: _buildMpesaFilters(),
          ),

          // ========================================================
          // CONTENT
          // ========================================================

          if (filtered.isEmpty)

            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildMpesaFullEmptyState(),
            )

          else

            _buildGroupedMpesaPayments(
              filtered,
            ),
        ],
      ),
    );
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  Widget _buildMpesaSummary(
      double total,
      int count,
      ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        8,
      ),
      child: Container(
        padding:
        const EdgeInsets.all(18),

        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade700,
              Colors.indigo.shade600,
            ],
          ),

          borderRadius:
          BorderRadius.circular(18),

          boxShadow: [
            BoxShadow(
              color:
              Colors.blue.withOpacity(.15),
              blurRadius: 18,
              offset:
              const Offset(0, 8),
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
                    _formatKes(total),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight:
                      FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),

            Container(
              width: 1,
              height: 42,
              color: Colors.white24,
            ),

            const SizedBox(width: 20),

            Column(
              crossAxisAlignment:
              CrossAxisAlignment.end,
              children: [

                const Text(
                  'Transactions',
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
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Widget _buildMpesaSearch() {
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
          'Search tenant, unit or transaction ID...',

          hintStyle: TextStyle(
            fontSize: 12,
            color:
            Colors.grey.shade500,
          ),

          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
          ),

          suffixIcon:
          _searchQuery.isNotEmpty
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

          border:
          OutlineInputBorder(
            borderRadius:
            BorderRadius.circular(12),
            borderSide:
            BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FILTERS
  // ============================================================

  Widget _buildMpesaFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        4,
        16,
        10,
      ),
      child: SingleChildScrollView(
        scrollDirection:
        Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('All'),
            _buildFilterChip('This Month'),
            _buildFilterChip('Last Month'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
      String label,
      ) {
    final selected =
        _selectedFilter == label;

    return Padding(
      padding:
      const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected
                ? FontWeight.w600
                : FontWeight.w400,
            color: selected
                ? Colors.white
                : Colors.grey.shade700,
          ),
        ),

        selected: selected,

        selectedColor:
        Colors.blue.shade600,

        backgroundColor:
        Colors.white,

        side: BorderSide(
          color: selected
              ? Colors.blue.shade600
              : Colors.grey.shade200,
        ),

        onSelected: (_) {
          setState(() {
            _selectedFilter =
                label;
          });
        },
      ),
    );
  }

  // ============================================================
  // GROUP BY MONTH
  // ============================================================

  Widget _buildGroupedMpesaPayments(
      List<MpesaTransaction> transactions,
      ) {
    final Map<
        String,
        List<MpesaTransaction>>
    grouped = {};

    for (final transaction
    in transactions) {
      final date =
      _parseDate(
        transaction.transactionTime,
      );

      final key =
      DateFormat('yyyy-MM')
          .format(date);

      grouped.putIfAbsent(
        key,
            () => [],
      );

      grouped[key]!
          .add(transaction);
    }

    final months =
    grouped.keys.toList()
      ..sort(
            (a, b) =>
            b.compareTo(a),
      );

    return SliverList(
      delegate:
      SliverChildBuilderDelegate(
            (context, index) {
          final key =
          months[index];

          final monthTransactions =
          grouped[key]!;

          final monthDate =
          DateTime.parse(
            '$key-01',
          );

          final total =
          monthTransactions
              .fold<double>(
            0,
                (sum, transaction) {
              return sum +
                  (double.tryParse(
                    transaction
                        .amount
                        .toString(),
                  ) ??
                      0);
            },
          );

          return _buildMpesaMonthSection(
            monthDate,
            monthTransactions,
            total,
          );
        },

        childCount:
        months.length,
      ),
    );
  }

  // ============================================================
  // MONTH SECTION
  // ============================================================

  Widget _buildMpesaMonthSection(
      DateTime month,
      List<MpesaTransaction> transactions,
      double total,
      ) {
    return Padding(
      padding:
      const EdgeInsets.fromLTRB(
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
            padding:
            const EdgeInsets.symmetric(
              vertical: 8,
            ),

            child: Row(
              children: [

                Text(
                  DateFormat(
                    'MMMM yyyy',
                  ).format(month),

                  style:
                  const TextStyle(
                    fontSize: 13,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),

                const SizedBox(width: 8),

                Container(
                  padding:
                  const EdgeInsets
                      .symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),

                  decoration:
                  BoxDecoration(
                    color:
                    Colors.blue.shade50,
                    borderRadius:
                    BorderRadius
                        .circular(
                      20,
                    ),
                  ),

                  child: Text(
                    '${transactions.length}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                      FontWeight.w700,
                      color:
                      Colors.blue.shade700,
                    ),
                  ),
                ),

                const Spacer(),

                Text(
                  _formatKes(total),

                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                    FontWeight.w700,
                    color:
                    Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),

          ...transactions.map(
                (transaction) {
              return Padding(
                padding:
                const EdgeInsets.only(
                  bottom: 8,
                ),

                child:
                _buildFullMpesaCard(
                  transaction,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FULL PAYMENT CARD
  // ============================================================

  Widget _buildFullMpesaCard(
      MpesaTransaction transaction,
      ) {
    final date =
    _parseDate(
      transaction.transactionTime,
    );

    final amount =
        double.tryParse(
          transaction.amount
              .toString(),
        ) ??
            0;

    final tenantName =
    '${transaction.firstName} '
        '${transaction.lastName}'
        .trim();

    return Container(
      padding:
      const EdgeInsets.all(14),

      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(14),

        border: Border.all(
          color:
          Colors.grey.shade100,
        ),

        boxShadow: [
          BoxShadow(
            color:
            Colors.black.withOpacity(.025),
            blurRadius: 8,
            offset:
            const Offset(0, 3),
          ),
        ],
      ),

      child: Row(
        children: [

          Container(
            width: 42,
            height: 42,

            decoration:
            BoxDecoration(
              color:
              Colors.blue.shade50,
              shape:
              BoxShape.circle,
            ),

            child: Icon(
              BootstrapIcons
                  .check_circle_fill,
              color:
              Colors.blue.shade600,
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
                  tenantName.isEmpty
                      ? 'Unknown Tenant'
                      : tenantName,

                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,

                  style:
                  const TextStyle(
                    fontSize: 12,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 5),

                Wrap(
                  spacing: 8,
                  runSpacing: 4,

                  children: [

                    _infoItem(
                      Icons.home_work_outlined,
                      'Unit ${transaction.unitNumber}',
                    ),

                    _infoItem(
                      Icons.calendar_today_outlined,
                      DateFormat(
                        'dd MMM yyyy',
                      ).format(date),
                    ),

                    _infoItem(
                      Icons.tag_outlined,
                      transaction.transactionId,
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
                  fontWeight:
                  FontWeight.w800,
                  color:
                  Colors.blue.shade700,
                ),
              ),

              const SizedBox(height: 5),

              Container(
                padding:
                const EdgeInsets
                    .symmetric(
                  horizontal: 7,
                  vertical: 3,
                ),

                decoration:
                BoxDecoration(
                  color:
                  Colors.green.shade50,
                  borderRadius:
                  BorderRadius
                      .circular(5),
                ),

                child: Text(
                  'Received',

                  style: TextStyle(
                    fontSize: 8,
                    fontWeight:
                    FontWeight.w700,
                    color:
                    Colors.green.shade700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INFO ITEM
  // ============================================================

  Widget _infoItem(
      IconData icon,
      String text,
      ) {
    return Row(
      mainAxisSize:
      MainAxisSize.min,

      children: [

        Icon(
          icon,
          size: 10,
          color:
          Colors.grey.shade500,
        ),

        const SizedBox(width: 3),

        Text(
          text,
          style: TextStyle(
            fontSize: 9,
            color:
            Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildMpesaFullEmptyState() {
    final isSearching =
        _searchQuery.trim().isNotEmpty;

    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(32),

        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,

          children: [

            Container(
              width: 64,
              height: 64,

              decoration:
              BoxDecoration(
                color:
                Colors.blue.shade50,
                shape:
                BoxShape.circle,
              ),

              child: Icon(
                BootstrapIcons.receipt,
                size: 28,
                color:
                Colors.blue.shade400,
              ),
            ),

            const SizedBox(height: 18),

            Text(
              isSearching
                  ? 'No matching payments'
                  : 'No Mpesa payments yet',

              style:
              const TextStyle(
                fontSize: 16,
                fontWeight:
                FontWeight.w700,
              ),
            ),

            const SizedBox(height: 7),

            Text(
              isSearching
                  ? 'Try a different tenant, unit or transaction ID.'
                  : 'Confirmed Mpesa payments will appear here.',

              textAlign:
              TextAlign.center,

              style: TextStyle(
                fontSize: 12,
                color:
                Colors.grey.shade500,
                height: 1.5,
              ),
            ),

            if (isSearching) ...[
              const SizedBox(height: 14),

              TextButton(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                  });
                },
                child: const Text(
                  'Clear search',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}