import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class BulkInvoiceRunResultsPage extends StatefulWidget {
  final Map<String, dynamic> result;

  const BulkInvoiceRunResultsPage({
    super.key,
    required this.result,
  });

  @override
  State<BulkInvoiceRunResultsPage> createState() =>
      _BulkInvoiceRunResultsPageState();
}

class _BulkInvoiceRunResultsPageState extends State<BulkInvoiceRunResultsPage> {
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';

  String _selectedFilter = 'All';

  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'en_KE',
    symbol: 'Ksh ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      if (!mounted) return;

      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  String _formatCurrency(dynamic amount) {
    final value = amount is num
        ? amount.toDouble()
        : double.tryParse(amount?.toString() ?? '0') ?? 0;

    return _currencyFormatter.format(value);
  }

  int _getInt(dynamic value) {
    if (value is int) return value;

    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  double _getDouble(dynamic value) {
    if (value is num) return value.toDouble();

    return double.tryParse(value?.toString() ?? '0') ?? 0;
  }

  Map<String, dynamic> _getMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return {};
  }

  List<Map<String, dynamic>> _getInvoices() {
    final invoices = widget.result['invoices'];

    if (invoices is! List) {
      return [];
    }

    return invoices.map((invoice) {
      if (invoice is Map<String, dynamic>) {
        return invoice;
      }

      return Map<String, dynamic>.from(invoice);
    }).toList();
  }

  Map<String, dynamic> get _property => _getMap(widget.result['property']);

  Map<String, dynamic> get _summary => _getMap(widget.result['summary']);

  Map<String, dynamic> get _pdfSummary =>
      _getMap(widget.result['pdf_summary']);

  Map<String, dynamic> get _emailSummary =>
      _getMap(widget.result['email_summary']);

  // ---------------------------------------------------------------------------
  // RESILIENT INT READER
  //
  // Tries several possible key names for an integer value and returns the
  // first one found. Falls back to [fallback] when nothing matches.
  //
  // This exists because the backend may return the PDF / email counts under
  // different key names than the ones we originally expected. Previously the
  // summary cards read `pdf_summary.successful_count` and
  // `email_summary.sent_count`, and defaulted to 0 when those keys weren't
  // present — which is why the counts displayed as zero even though the run
  // succeeded.
  // ---------------------------------------------------------------------------
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

  /// Count invoices in the response where `pdf_generated == true`.
  int _countPdfGenerated(List<Map<String, dynamic>> invoices) {
    return invoices.where((i) => i['pdf_generated'] == true).length;
  }

  /// Count invoices in the response where `email_sent == true`.
  int _countEmailSent(List<Map<String, dynamic>> invoices) {
    return invoices.where((i) => i['email_sent'] == true).length;
  }

  // ---------------------------------------------------------------------------
  // FIELD EXTRACTION (supports flat and nested shapes)
  // ---------------------------------------------------------------------------

  String _getUnitNumber(Map<String, dynamic> invoice) {
    final unit = _getMap(invoice['unit']);

    final value = invoice['unit_number'] ??
        invoice['unit_no'] ??
        invoice['unitNumber'] ??
        invoice['unitNo'] ??
        unit['unit_number'] ??
        unit['unit_no'] ??
        unit['unitNumber'] ??
        unit['unitNo'] ??
        unit['number'] ??
        unit['name'];

    if (value == null) return '-';

    final text = value.toString().trim();

    return text.isEmpty ? '-' : text;
  }

  String _getTenantName(Map<String, dynamic> invoice) {
    final tenant = _getMap(invoice['tenant']);

    final value = invoice['tenant_name'] ??
        invoice['tenantName'] ??
        invoice['tenant_full_name'] ??
        invoice['tenant_fullname'] ??
        invoice['name'] ??
        tenant['name'] ??
        tenant['full_name'] ??
        tenant['fullName'];

    if (value == null) return '-';

    final text = value.toString().trim();

    return text.isEmpty ? '-' : text;
  }

  String _getTenantEmail(Map<String, dynamic> invoice) {
    final tenant = _getMap(invoice['tenant']);

    final value = invoice['tenant_email'] ??
        invoice['tenantEmail'] ??
        invoice['email'] ??
        tenant['email'] ??
        tenant['email_address'];

    if (value == null) return '-';

    final text = value.toString().trim();

    return text.isEmpty ? '-' : text;
  }

  String _getReference(Map<String, dynamic> invoice) {
    // Check nested objects that might hold the reference
    final nestedInvoice = _getMap(invoice['invoice']);
    final nestedDetails = _getMap(invoice['details']);
    final nestedMeta = _getMap(invoice['meta']);

    final value = invoice['reference'] ??
        invoice['ref'] ??
        invoice['reference_number'] ??
        invoice['reference_no'] ??
        invoice['referenceNumber'] ??
        invoice['referenceNo'] ??
        invoice['ref_no'] ??
        invoice['refNo'] ??
        invoice['invoice_reference'] ??
        invoice['invoice_ref'] ??
        invoice['invoice_number'] ??
        invoice['invoice_no'] ??
        invoice['invoiceNumber'] ??
        invoice['invoiceNo'] ??
        invoice['invoice_id'] ??
        invoice['number'] ??
        invoice['no'] ??
        invoice['code'] ??
        invoice['id'] ??
        nestedInvoice['reference'] ??
        nestedInvoice['ref'] ??
        nestedInvoice['reference_number'] ??
        nestedInvoice['invoice_number'] ??
        nestedDetails['reference'] ??
        nestedDetails['ref'] ??
        nestedMeta['reference'] ??
        nestedMeta['ref'];

    if (value == null) return '-';

    final text = value.toString().trim();

    return text.isEmpty ? '-' : text;
  }

  /// Returns the reference with a leading '#', unless it already has one
  /// or the value is empty.
  String _getDisplayReference(Map<String, dynamic> invoice) {
    final reference = _getReference(invoice);

    if (reference == '-' || reference.isEmpty) {
      return reference;
    }

    if (reference.startsWith('#')) {
      return reference;
    }

    return '#$reference';
  }

  // ---------------------------------------------------------------------------
  // FILTERING
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> _getFilteredInvoices() {
    var invoices = _getInvoices();

    invoices = invoices.where((invoice) {
      if (_searchQuery.isEmpty) {
        return true;
      }

      final unitNumber = _getUnitNumber(invoice).toLowerCase();
      final tenantName = _getTenantName(invoice).toLowerCase();
      final tenantEmail = _getTenantEmail(invoice).toLowerCase();
      final reference = _getReference(invoice).toLowerCase();

      return unitNumber.contains(_searchQuery) ||
          tenantName.contains(_searchQuery) ||
          tenantEmail.contains(_searchQuery) ||
          reference.contains(_searchQuery);
    }).toList();

    switch (_selectedFilter) {
      case 'Successful':
        invoices = invoices.where((invoice) {
          return invoice['pdf_generated'] == true &&
              invoice['email_sent'] == true;
        }).toList();

        break;

      case 'Email Failed':
        invoices = invoices.where((invoice) {
          return invoice['email_sent'] != true;
        }).toList();

        break;

      case 'PDF Failed':
        invoices = invoices.where((invoice) {
          return invoice['pdf_generated'] != true;
        }).toList();

        break;
    }

    return invoices;
  }

  // ---------------------------------------------------------------------------
  // PDF
  // ---------------------------------------------------------------------------

  Future<void> _openPdf(String? pdfUrl) async {
    if (pdfUrl == null || pdfUrl.trim().isEmpty) {
      _showMessage(
        'PDF is not available.',
        isError: true,
      );
      return;
    }

    try {
      String url = pdfUrl.trim();

      // Convert old Laravel storage paths to the new /media/ route.
      if (url.contains('/public/storage/')) {
        url = url.replaceFirst(
          '/public/storage/',
          '/media/',
        );
      } else if (url.contains('/storage/')) {
        url = url.replaceFirst(
          '/storage/',
          '/media/',
        );
      }

      // Handle paths returned without the domain.
      if (!url.startsWith('http://') &&
          !url.startsWith('https://')) {
        if (url.startsWith('/')) {
          url = 'https://marketfella.com$url';
        } else {
          url = 'https://marketfella.com/$url';
        }
      }

      // Handle an old URL that may contain /public/storage
      // after the domain.
      url = url.replaceFirst(
        '/public/storage/',
        '/media/',
      );

      // Handle URLs containing /storage after the domain.
      if (url.contains('/storage/')) {
        url = url.replaceFirst(
          '/storage/',
          '/media/',
        );
      }

      final uri = Uri.parse(url);

      debugPrint('Opening invoice PDF: $url');

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw Exception('Could not open PDF');
      }
    } catch (e) {
      debugPrint('PDF opening error: $e');

      _showMessage(
        'Unable to open the invoice PDF.',
        isError: true,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // MESSAGE
  // ---------------------------------------------------------------------------

  void _showMessage(
      String message, {
        bool isError = false,
      }) {
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
            Expanded(
              child: Text(message),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final invoices = _getFilteredInvoices();

    final allInvoices = _getInvoices();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: _buildAppBar(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;

          return SingleChildScrollView(
            padding: EdgeInsets.all(
              isDesktop ? 28 : 16,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1500),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSuccessHeader(),
                    const SizedBox(height: 20),
                    _buildPropertyCard(),
                    const SizedBox(height: 18),
                    _buildSummaryCards(
                      isDesktop,
                      allInvoices,
                    ),
                    const SizedBox(height: 22),
                    _buildResultsSection(
                      invoices,
                      allInvoices,
                      isDesktop,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // APP BAR
  // ---------------------------------------------------------------------------

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_rounded,
        ),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Invoice Run Results',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Monthly invoice generation summary',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SUCCESS HEADER
  // ---------------------------------------------------------------------------

  Widget _buildSuccessHeader() {
    final success = widget.result['success'] == true;

    final message =
        widget.result['message']?.toString() ?? 'Invoice run completed.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: success
              ? [
            Colors.green.shade600,
            Colors.green.shade800,
          ]
              : [
            Colors.red.shade600,
            Colors.red.shade800,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              success ? Icons.check_circle_rounded : Icons.error_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(width: 17),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  success ? 'Invoice Run Complete' : 'Invoice Run Failed',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PROPERTY
  // ---------------------------------------------------------------------------

  Widget _buildPropertyCard() {
    final propertyName = _property['name']?.toString() ?? 'Property';

    final location = _property['location']?.toString() ?? '-';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.apartment_rounded,
              color: Colors.blue.shade700,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  propertyName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 15,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      location,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SUMMARY
  //
  // Counts are resolved with the resilient `_readInt` helper and, if nothing
  // matches, they fall back to counting directly from the `invoices` array in
  // the response — which is always present and authoritative.
  // ---------------------------------------------------------------------------

  Widget _buildSummaryCards(
      bool isDesktop,
      List<Map<String, dynamic>> allInvoices,
      ) {
    // ---- Invoices ----
    final invoiceCount = _readInt(
      {...widget.result, ..._summary},
      const [
        'invoice_count',
        'invoices_count',
        'invoices_generated',
        'generated',
        'total_invoices',
      ],
      fallback: allInvoices.isNotEmpty
          ? allInvoices.length
          : _getInvoices().length,
    );

    // ---- PDFs ----
    // Falls back to counting invoices where pdf_generated == true.
    final pdfSuccessful = _readInt(
      {...widget.result, ..._pdfSummary, ..._summary},
      const [
        'successful_count',
        'success_count',
        'pdf_count',
        'pdfs_generated',
        'pdf_generated_count',
        'generated',
      ],
      fallback: _countPdfGenerated(allInvoices),
    );

    // ---- Emails ----
    // Falls back to counting invoices where email_sent == true.
    final emailSent = _readInt(
      {...widget.result, ..._emailSummary, ..._summary},
      const [
        'sent_count',
        'emails_sent',
        'email_sent_count',
        'sent',
        'delivered',
        'delivered_count',
      ],
      fallback: _countEmailSent(allInvoices),
    );

    // ---- Total amount ----
    // Sum of amounts across the invoice list if nothing else is provided.
    double totalAmount = 0;
    final rawTotal = _summary['total_amount'] ??
        widget.result['total_amount'] ??
        widget.result['amount'];

    if (rawTotal != null) {
      totalAmount = _getDouble(rawTotal);
    } else {
      for (final inv in allInvoices) {
        totalAmount += _getDouble(inv['amount']);
      }
    }

    final cards = [
      _buildSummaryCard(
        title: 'Invoices',
        value: '$invoiceCount',
        subtitle: 'Successfully created',
        icon: Icons.receipt_long_outlined,
        color: Colors.blue,
      ),
      _buildSummaryCard(
        title: 'PDFs',
        value: '$pdfSuccessful',
        subtitle: 'Generated successfully',
        icon: Icons.picture_as_pdf_outlined,
        color: Colors.orange,
      ),
      _buildSummaryCard(
        title: 'Emails',
        value: '$emailSent',
        subtitle: 'Successfully delivered',
        icon: Icons.mark_email_read_outlined,
        color: Colors.purple,
      ),
      _buildSummaryCard(
        title: 'Total Invoiced',
        value: _formatCurrency(totalAmount),
        subtitle: 'Invoice run value',
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
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(height: 13),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RESULTS SECTION
  // ---------------------------------------------------------------------------

  Widget _buildResultsSection(
      List<Map<String, dynamic>> invoices,
      List<Map<String, dynamic>> allInvoices,
      bool isDesktop,
      ) {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    Icons.fact_check_outlined,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Invoice Results',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${invoices.length} of ${allInvoices.length} invoices displayed',
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
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search unit, tenant, email or reference...',
                prefixIcon: const Icon(Icons.search_rounded),
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
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _buildFilters(),
          const SizedBox(height: 10),
          if (invoices.isEmpty)
            _buildEmptyState()
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: invoices
                    .map(
                      (invoice) => _buildInvoiceResultCard(invoice),
                )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FILTERS
  // ---------------------------------------------------------------------------

  Widget _buildFilters() {
    final filters = [
      'All',
      'Successful',
      'Email Failed',
      'PDF Failed',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: filters.map((filter) {
          final selected = _selectedFilter == filter;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  _selectedFilter = filter;
                });
              },
              selectedColor: Colors.blue.shade100,
              labelStyle: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // INVOICE RESULT CARD
  // ---------------------------------------------------------------------------

  Widget _buildInvoiceResultCard(Map<String, dynamic> invoice) {
    final unitNumber = _getUnitNumber(invoice);
    final tenantName = _getTenantName(invoice);
    final tenantEmail = _getTenantEmail(invoice);
    final displayReference = _getDisplayReference(invoice);

    final pdfGenerated = invoice['pdf_generated'] == true;

    final emailSent = invoice['email_sent'] == true;

    final emailError = invoice['email_error']?.toString();

    final pdfUrl = invoice['pdf_url']?.toString();

    final successful = pdfGenerated && emailSent;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: successful ? Colors.green.shade100 : Colors.orange.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildUnitBadge(unitNumber),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tenantName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tenantEmail,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _buildOverallStatus(successful),
            ],
          ),
          const SizedBox(height: 17),
          Wrap(
            spacing: 25,
            runSpacing: 10,
            children: [
              _buildDetailItem(
                'Reference',
                displayReference,
                Icons.tag_rounded,
              ),
              _buildDetailItem(
                'Amount',
                _formatCurrency(invoice['amount']),
                Icons.account_balance_wallet_outlined,
              ),
              _buildDetailItem(
                'Status',
                invoice['status']?.toString() ?? '-',
                Icons.info_outline_rounded,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(
            color: Colors.grey.shade200,
          ),
          const SizedBox(height: 12),
          _buildStatusRow(
            icon: Icons.receipt_long_outlined,
            title: 'Invoice Created',
            success: true,
            successText: 'Created successfully',
            failureText: 'Invoice creation failed',
          ),
          const SizedBox(height: 10),
          _buildStatusRow(
            icon: Icons.picture_as_pdf_outlined,
            title: 'PDF Generated',
            success: pdfGenerated,
            successText: 'PDF ready',
            failureText: 'PDF generation failed',
          ),
          const SizedBox(height: 10),
          _buildStatusRow(
            icon: Icons.mark_email_read_outlined,
            title: 'Email Delivery',
            success: emailSent,
            successText: 'Delivered successfully',
            failureText: emailError ?? 'Email delivery failed',
          ),
          if (pdfGenerated && pdfUrl != null && pdfUrl.isNotEmpty) ...[
            const SizedBox(height: 17),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () {
                  _openPdf(pdfUrl);
                },
                icon: const Icon(
                  Icons.picture_as_pdf_outlined,
                  size: 17,
                ),
                label: const Text('View PDF'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(
                    color: Colors.red.shade200,
                  ),
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

  // ---------------------------------------------------------------------------
  // STATUS COMPONENTS
  // ---------------------------------------------------------------------------

  Widget _buildOverallStatus(bool successful) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: successful ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(
            successful
                ? Icons.check_circle_rounded
                : Icons.warning_amber_rounded,
            size: 14,
            color: successful
                ? Colors.green.shade700
                : Colors.orange.shade700,
          ),
          const SizedBox(width: 5),
          Text(
            successful ? 'Complete' : 'Attention',
            style: TextStyle(
              color: successful
                  ? Colors.green.shade700
                  : Colors.orange.shade800,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow({
    required IconData icon,
    required String title,
    required bool success,
    required String successText,
    required String failureText,
  }) {
    final color = success ? Colors.green : Colors.red;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            icon,
            size: 17,
            color: color.shade600,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                success ? successText : failureText,
                style: TextStyle(
                  fontSize: 10,
                  color: success ? Colors.green.shade700 : Colors.red.shade700,
                ),
              ),
            ],
          ),
        ),
        Icon(
          success ? Icons.check_circle_rounded : Icons.cancel_rounded,
          color: success ? Colors.green.shade600 : Colors.red.shade600,
          size: 20,
        ),
      ],
    );
  }

  Widget _buildDetailItem(
      String label,
      String value,
      IconData icon,
      ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 15,
          color: Colors.grey.shade500,
        ),
        const SizedBox(width: 5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUnitBadge(String unitNumber) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(9),
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

  // ---------------------------------------------------------------------------
  // EMPTY
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(50),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 50,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 14),
          const Text(
            'No Results Found',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Try changing your search or filter.',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DECORATION
  // ---------------------------------------------------------------------------

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: Colors.grey.shade200,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.025),
          blurRadius: 18,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }
}