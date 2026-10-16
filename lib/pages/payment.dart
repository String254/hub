import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hub/config/config.dart';
import 'package:hub/models/models.dart';
import 'package:intl/intl.dart';
import 'package:hub/services/services.dart';
import 'package:screenshot/screenshot.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ReceiptPage extends StatefulWidget {
  final String invoiceRef;
  final int invoiceId;
  const ReceiptPage({super.key, required this.invoiceRef, required this.invoiceId});

  @override
  State<ReceiptPage> createState() => _ReceiptPageState();
}

class _ReceiptPageState extends State<ReceiptPage> {
  final ApiPropertyService _apiService = ApiPropertyService(baseUrl: baseUrl);
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSaving = false;
  String userFirstName = 'User';
  String userFullName = 'User';
  String userEmail = '';
  String userPhone = '';
  bool isLoadingUser = true;

  /// The receipt "paper" sits on this colour, and the punched notches on the
  /// perforation lines are painted with it so they read as real cut-outs.
  Color get _pageBackground => Colors.grey.shade50;

  /// A2 is used as the PDF page size and as the on-screen proportions.
  static const double _a2WidthMm = 420.0;
  static const double _a2HeightMm = 594.0;
  static const double _a2AspectRatio = _a2WidthMm / _a2HeightMm; // ≈ 0.7071

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final fullName = prefs.getString('name');

      // Full name
      if (fullName != null && fullName.trim().isNotEmpty) {
        userFullName = fullName.trim();

        // First name extracted from full name
        userFirstName = fullName.trim().split(' ').first;
      } else {
        // Fallbacks
        userFullName = prefs.getString('full_name') ??
            prefs.getString('fullName') ??
            'User';

        userFirstName = prefs.getString('first_name') ??
            prefs.getString('firstName') ??
            userFullName.split(' ').first;
      }

      // Email
      userEmail = prefs.getString('email') ?? '';

      // Phone
      userPhone = prefs.getString('phone') ?? '';
    } catch (_) {
      userFullName = 'User';
      userFirstName = 'User';
      userEmail = '';
      userPhone = '';
    }

    if (!mounted) return;

    setState(() {
      isLoadingUser = false;
    });
  }

  double parseAmount(dynamic value) {
    if (value == null) return 0.0;

    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }

    return 0.0;
  }

  // ---------------------------------------------------------------------------
  // Property acronym — "Villa Apartment" → "VA", "Zen Apartments" → "ZA",
  // single word "Villa" → "VI".
  // ---------------------------------------------------------------------------
  String _propertyAcronym(String name) {
    final cleaned = name.trim().replaceAll(RegExp(r'[^A-Za-z0-9\s]'), '');
    if (cleaned.isEmpty) return '?';

    final parts = cleaned
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '?';

    if (parts.length == 1) {
      final word = parts.first;
      return (word.length >= 2 ? word.substring(0, 2) : word).toUpperCase();
    }

    return parts.take(2).map((p) => p[0]).join().toUpperCase();
  }

  // ---------------------------------------------------------------------------
  // A2 PDF PAGE BUILDER
  // ---------------------------------------------------------------------------
  pw.Page _buildA2Page(pw.MemoryImage image) {
    // A2 = 420 × 594 mm (ISO 216)
    const a2 = PdfPageFormat(
      420 * PdfPageFormat.mm,
      594 * PdfPageFormat.mm,
      marginAll: 24,
    );

    return pw.Page(
      pageFormat: a2,
      build: (pw.Context context) {
        return pw.Center(
          child: pw.Image(
            image,
            fit: pw.BoxFit.contain,
          ),
        );
      },
    );
  }

  Future<Uint8List?> _captureReceipt() async {
    return _screenshotController.capture(
      pixelRatio: 3.0,
      delay: const Duration(milliseconds: 50),
    );
  }

  Future<void> _previewPdf() async {
    await _withLoading(() async {
      final Uint8List? imageBytes = await _captureReceipt();
      if (imageBytes != null) {
        final pdf = pw.Document();
        final image = pw.MemoryImage(imageBytes);

        pdf.addPage(_buildA2Page(image));

        await Printing.layoutPdf(onLayout: (format) async => pdf.save());
      }
    });
  }

  Future<void> _downloadPdf() async {
    await _withLoading(() async {
      final Uint8List? imageBytes = await _captureReceipt();
      if (imageBytes != null) {
        final pdf = pw.Document();
        final image = pw.MemoryImage(imageBytes);

        pdf.addPage(_buildA2Page(image));

        await Printing.sharePdf(
          bytes: await pdf.save(),
          filename: 'receipt_${widget.invoiceRef.split('.').first}.pdf',
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Uploads the A2 receipt PDF to Laravel.
  // ---------------------------------------------------------------------------
  Future<bool> _uploadPdfToLaravel(
      ApiInvoiceResponse invoice,
      ) async {
    final Uint8List? imageBytes = await _captureReceipt();

    if (imageBytes == null) {
      throw Exception(
        'Failed to capture receipt screenshot.',
      );
    }

    final pdf = pw.Document();
    final image = pw.MemoryImage(imageBytes);
    pdf.addPage(_buildA2Page(image));
    final pdfBytes = await pdf.save();

    final url = Uri.parse(uploadReceipt);

    final request = http.MultipartRequest(
      'POST',
      url,
    );

    request.fields['property_name'] = invoice.unit.property.name;
    request.fields['tenant_name'] = invoice.unit.tenant.name;
    request.fields['tenant_email'] = invoice.unit.tenant.email;
    request.fields['unit_number'] = invoice.unit.unitNumber.toString();
    request.fields['receipt_number'] = widget.invoiceRef.split('.').first;
    request.fields['receipt_date'] =
        DateFormat('dd/MM/yyyy').format(DateTime.now());
    request.fields['amount'] = invoice.amount.toString();
    request.fields['receipt_period'] =
        DateFormat('MMM yyyy').format(DateTime.now());

    final pdfFile = http.MultipartFile.fromBytes(
      'receipt',
      pdfBytes,
      filename: 'receipt_${widget.invoiceRef.split('.').first}.pdf',
      contentType: MediaType(
        'application',
        'pdf',
      ),
    );

    request.files.add(pdfFile);

    try {
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Receipt upload failed: $responseBody',
        );
      }

      final responseData = jsonDecode(responseBody);

      if (responseData['success'] != true) {
        throw Exception(
          responseData['error'] ?? 'Receipt upload failed',
        );
      }

      if (responseData['email_sent'] != true) {
        throw Exception(
          responseData['email_error'] ??
              'Receipt was uploaded, but the email could not be sent.',
        );
      }

      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Receipt error: $e',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // On success: show a green "Saved and sent successfully" snackbar and
  // navigate back TWO screens (ReceiptPage -> CreateReceiptScreen -> origin).
  // ---------------------------------------------------------------------------
  Future<void> _saveReceipt(ApiInvoiceResponse invoice) async {
    bool success = false;

    await _withLoading(() async {
      success = await _uploadPdfToLaravel(invoice);
    });

    if (!success || !mounted) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // Pop 1: ReceiptPage -> CreateReceiptScreen
    navigator.pop();

    // Pop 2: CreateReceiptScreen -> previous page (origin screen)
    if (navigator.canPop()) {
      navigator.pop();
    }

    // Show the confirmation on the destination screen so the user actually
    // sees it after we've navigated away.
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Saved and sent successfully'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _withLoading(Future<void> Function() action) async {
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(strokeWidth: 0.8),
      ),
    );

    try {
      await action();
      navigator.pop();
    } catch (e) {
      navigator.pop();
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final isMediumScreen = screenSize.width >= 600 && screenSize.width < 900;
    final isDesktop = screenSize.width >= 1200;
    final horizontalPadding =
    isSmallScreen ? 16.0 : (isMediumScreen ? 24.0 : 32.0);

    final contentMaxWidth =
    isSmallScreen ? screenSize.width : (isDesktop ? 900.0 : 780.0);

    return Scaffold(
      backgroundColor: _pageBackground,
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: contentMaxWidth),
          child: FutureBuilder<ApiInvoiceResponse>(
            future: _apiService.fetchReceipt(widget.invoiceId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingState();
              }

              if (snapshot.hasError) {
                return _buildErrorState(snapshot.error.toString());
              }

              final invoice = snapshot.data!;
              final isPaid = invoice.status.toLowerCase() == 'paid';

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  horizontalPadding,
                  horizontalPadding,
                  32,
                ),
                child: Column(
                  children: [
                    Screenshot(
                      controller: _screenshotController,
                      child: _buildReceiptCard(
                        invoice,
                        isPaid,
                        isSmallScreen,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildActionButtons(invoice),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Action buttons
  // ---------------------------------------------------------------------------

  Widget _buildActionButtons(ApiInvoiceResponse invoice) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: _previewPdf,
          icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
          label: const Text('Preview'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.blue.shade700,
            side: BorderSide(color: Colors.blue.shade200),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: _downloadPdf,
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('Download'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.blue.shade700,
            side: BorderSide(color: Colors.blue.shade200),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => _saveReceipt(invoice),
          icon: const Icon(Icons.send_rounded, size: 18),
          style: ElevatedButton.styleFrom(
            backgroundColor: Palette.nestBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          label: const Text('Send Receipt'),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // The receipt "paper"
  // ---------------------------------------------------------------------------

  Widget _buildReceiptCard(
      ApiInvoiceResponse invoice,
      bool isPaid,
      bool isSmallScreen,
      ) {
    final receiptNo = 'INV-${invoice.ref.toString().split('.').first}';
    final hPad = isSmallScreen ? 18.0 : 34.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(18),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---------------------------------------------------------------- HEADER
          Padding(
            padding:
            EdgeInsets.fromLTRB(hPad, isSmallScreen ? 24 : 36, hPad, 24),
            child: _buildHeader(
              invoice,
              isPaid,
              isSmallScreen,
            ),
          ),

          _buildPerforation(),

          // -------------------------------------------------- SUMMARY (SIDE BY SIDE)
          Padding(
            padding: EdgeInsets.fromLTRB(hPad, 24, hPad, 24),
            child: _buildSummaryRow(
              invoice,
              isPaid,
              isSmallScreen,
              receiptNo,
            ),
          ),

          // -------------------------------------------------------- PAYMENT HISTORY
          if (invoice.receipts.isNotEmpty) ...[
            _buildPerforation(),
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 24, hPad, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel(
                    'PAYMENT HISTORY (${invoice.receipts.length})',
                    Icons.history_rounded,
                  ),
                  const SizedBox(height: 8),
                  ...invoice.receipts.asMap().entries.map((entry) {
                    final index = entry.key;
                    final receipt = entry.value;

                    return Column(
                      children: [
                        _buildReceiptRow(receipt, invoice, isSmallScreen),
                        if (index < invoice.receipts.length - 1)
                          _dashedLine(
                            color: Colors.grey.shade200,
                            dashWidth: 3,
                            dashGap: 4,
                            thickness: 1,
                          ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],

          _buildPerforation(),

          // ---------------------------------------------------------------- FOOTER
          Padding(
            padding:
            EdgeInsets.fromLTRB(hPad, 26, hPad, isSmallScreen ? 28 : 38),
            child: _buildFooter(isSmallScreen),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Summary row — Receipt Summary + Amount Summary, side by side on wide screens
  // ---------------------------------------------------------------------------

  Widget _buildSummaryRow(
      ApiInvoiceResponse invoice,
      bool isPaid,
      bool isSmallScreen,
      String receiptNo,
      ) {
    final receiptSummary = _buildReceiptSummary(
      invoice,
      isPaid,
      isSmallScreen,
      receiptNo,
    );
    final amountSummary = _buildAmountSummary(invoice, isSmallScreen);

    if (isSmallScreen) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          receiptSummary,
          const SizedBox(height: 24),
          amountSummary,
        ],
      );
    }

    // IntrinsicHeight makes both columns stretch to the taller one so the
    // section dividers line up nicely.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: receiptSummary),
          Container(
            width: 1,
            color: Colors.grey.shade200,
            margin: const EdgeInsets.symmetric(horizontal: 24),
          ),
          Expanded(child: amountSummary),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Receipt Summary
  // ---------------------------------------------------------------------------

  Widget _buildReceiptSummary(
      ApiInvoiceResponse invoice,
      bool isPaid,
      bool isSmallScreen,
      String receiptNo,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('RECEIPT SUMMARY', Icons.description_outlined),
        const SizedBox(height: 14),
        _detailRow(
          'Receipt No.',
          receiptNo,
          isSmallScreen: isSmallScreen,
        ),
        _detailRow(
          'Issued On',
          _formatDate(DateTime.now().toIso8601String()),
          isSmallScreen: isSmallScreen,
        ),
        _detailRow(
          'Tenant',
          invoice.unit.tenant.name,
          isSmallScreen: isSmallScreen,
        ),
        _detailRow(
          'Unit',
          invoice.unit.unitNumber,
          isSmallScreen: isSmallScreen,
        ),
        _detailRow(
          'Due Date',
          _formatDate(invoice.invoiceDate),
          isSmallScreen: isSmallScreen,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Amount Summary
  // ---------------------------------------------------------------------------

  Widget _buildAmountSummary(
      ApiInvoiceResponse invoice,
      bool isSmallScreen,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('AMOUNT SUMMARY', Icons.receipt_long_outlined),
        const SizedBox(height: 14),
        _detailRow(
          'Invoice Amount',
          _money(invoice.amountAsDouble),
          isSmallScreen: isSmallScreen,
          valueColor: Colors.grey.shade900,
        ),
        _detailRow(
          'Total Paid',
          _money(invoice.totalPaid),
          isSmallScreen: isSmallScreen,
          valueColor: Colors.green.shade700,
        ),
        const SizedBox(height: 16),
        _buildBalanceBanner(invoice, isSmallScreen),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Header — now includes a circular acronym badge for the property
  // ---------------------------------------------------------------------------

  Widget _buildHeader(
      ApiInvoiceResponse invoice,
      bool isPaid,
      bool isSmallScreen,
      ) {
    return Column(
      children: [
        _buildPropertyAcronymBadge(
          invoice.unit.property.name,
          isSmallScreen,
        ),
        const SizedBox(height: 18),
        Text(
          invoice.unit.property.name.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isSmallScreen ? 14 : 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            color: Colors.grey.shade900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'OFFICIAL PAYMENT RECEIPT',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 2.6,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 20),
        _buildStatusPill(invoice.status, isPaid, isSmallScreen),
      ],
    );
  }

  /// Circular badge with the property initials (e.g. "Villa Apartment" → "VA").
  Widget _buildPropertyAcronymBadge(String propertyName, bool isSmallScreen) {
    final acronym = _propertyAcronym(propertyName);
    final size = isSmallScreen ? 62.0 : 78.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Palette.nestBlue,
            Color.lerp(Palette.nestBlue, Colors.black, 0.25) ??
                Palette.nestBlue,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Palette.nestBlue.withAlpha(70),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        acronym,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: isSmallScreen ? 22 : 28,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  Widget _buildStatusPill(String status, bool isPaid, bool isSmallScreen) {
    final color = isPaid ? Colors.green : Colors.orange;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 14 : 20,
        vertical: isSmallScreen ? 7 : 10,
      ),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPaid ? Icons.verified_rounded : Icons.schedule_rounded,
            size: isSmallScreen ? 14 : 17,
            color: color.shade700,
          ),
          const SizedBox(width: 7),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: color.shade700,
              fontWeight: FontWeight.w700,
              fontSize: isSmallScreen ? 10.5 : 12,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Footer
  // ---------------------------------------------------------------------------

  Widget _buildFooter(bool isSmallScreen) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_rounded,
            color: Colors.green.shade700,
            size: 20,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Thank you for your payment',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isSmallScreen ? 13.5 : 16,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'This is a system-generated receipt and does not require a signature.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isSmallScreen ? 11 : 12,
            height: 1.5,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Building blocks
  // ---------------------------------------------------------------------------

  /// Section title — now rendered in the brand blue.
  Widget _sectionLabel(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Palette.nestBlue),
        const SizedBox(width: 7),
        Text(
          text,
          style: const TextStyle(
            fontSize: 10.5,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w800,
            color: Palette.nestBlue,
          ),
        ),
      ],
    );
  }

  /// A label / dotted-leader / value row — the signature receipt look.
  Widget _detailRow(
      String label,
      String value, {
        required bool isSmallScreen,
        Color? valueColor,
        FontWeight valueWeight = FontWeight.w700,
        bool showLeader = true,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isSmallScreen ? 12 : 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
              height: 1.15,
            ),
          ),
          if (showLeader) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: _dashedLine(
                  color: Colors.grey.shade300,
                  dashWidth: 2,
                  dashGap: 3.5,
                  thickness: 1,
                ),
              ),
            ),
          ],
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isSmallScreen ? 12.5 : 13.5,
                fontWeight: valueWeight,
                color: valueColor ?? Colors.grey.shade900,
                height: 1.15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceBanner(ApiInvoiceResponse invoice, bool isSmallScreen) {
    final isSettled = invoice.balance == 0;
    final color = isSettled ? Colors.green : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Balance Due',
            style: TextStyle(
              fontSize: isSmallScreen ? 12 : 13,
              fontWeight: FontWeight.w700,
              color: color.shade800,
            ),
          ),
          Text(
            _money(invoice.balance),
            style: TextStyle(
              fontSize: isSmallScreen ? 15 : 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: color.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(
      dynamic receipt,
      ApiInvoiceResponse invoice,
      bool isSmallScreen,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.check_rounded,
              size: 20,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Receipt #${invoice.ref.toString().split('.').first}-${receipt.id}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: isSmallScreen ? 12 : 13,
                    color: Colors.grey.shade900,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: isSmallScreen ? 11 : 12,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _formatDate(receipt.paymentDate),
                      style: TextStyle(
                        fontSize: isSmallScreen ? 11 : 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _money(parseAmount(receipt.amount)),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: isSmallScreen ? 12.5 : 13.5,
              color: Colors.green.shade700,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Perforation + dashed line
  // ---------------------------------------------------------------------------

  /// A torn/tear line with punched notches on both edges of the paper.
  Widget _buildPerforation() {
    return SizedBox(
      height: 10,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _dashedLine(
                  color: Palette.nestBlue,
                  dashWidth: 5,
                  dashGap: 4.5,
                  thickness: 0.5,
                ),
              ),
            ),
          ),
          Positioned(
            left: -11,
            top: 0,
            child: _notch(),
          ),
          Positioned(
            right: -11,
            top: 0,
            child: _notch(),
          ),
        ],
      ),
    );
  }

  Widget _notch() {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: _pageBackground,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _dashedLine({
    Color? color,
    double dashWidth = 5,
    double dashGap = 4,
    double thickness = 1.2,
  }) {
    return SizedBox(
      height: thickness,
      width: double.infinity,
      child: CustomPaint(
        painter: _DashedLinePainter(
          color: color ?? Colors.grey.shade300,
          dashWidth: dashWidth,
          dashGap: dashGap,
          thickness: thickness,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // States
  // ---------------------------------------------------------------------------

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading receipt details...'),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Error Loading Receipt',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => setState(() {}),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _money(double amount) {
    return 'KES ${NumberFormat('#,##0').format(parseAmount(amount))}';
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }
}

/// Paints a horizontal dashed line.
class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter({
    required this.color,
    this.dashWidth = 5,
    this.dashGap = 4,
    this.thickness = 1.2,
  });

  final Color color;
  final double dashWidth;
  final double dashGap;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    final y = size.height / 2;
    double x = 0;

    while (x < size.width) {
      final end = (x + dashWidth) > size.width ? size.width : (x + dashWidth);
      canvas.drawLine(Offset(x, y), Offset(end, y), paint);
      x += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color ||
          oldDelegate.dashWidth != dashWidth ||
          oldDelegate.dashGap != dashGap ||
          oldDelegate.thickness != thickness;
}