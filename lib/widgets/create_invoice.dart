import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hub/config/config.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:hub/models/models.dart';
import 'package:hub/services/services.dart';
import 'package:screenshot/screenshot.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InvoicePage extends StatefulWidget {
  final int unitId;
  final int propertyId;
  final String propertyName;
  final int tenantId;
  final String houseNo;
  final String tenantName;
  final String tenantEmail;
  final String paybillNumber;
  final String accountNumber;
  final double waterBill;
  final double serviceCost;

  const InvoicePage({
    super.key,
    required this.unitId,
    required this.propertyId,
    required this.houseNo,
    required this.propertyName,
    required this.tenantId,
    required this.tenantName,
    required this.tenantEmail,
    required this.paybillNumber,
    required this.accountNumber,
    required this.waterBill,
    required this.serviceCost,
  });

  @override
  State<InvoicePage> createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage> {
  late ApiService apiService;
  late Future<UnitDetails> unitFuture;
  final String invoiceNumber = _generateInvoiceNumber();
  late double serviceCost;

  final ScreenshotController _screenshotController = ScreenshotController();

  String userFirstName = 'User';
  String userFullName = 'User';
  String userEmail = '';
  String userPhone = '';

  bool isLoadingUser = true;

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final fullName = prefs.getString('name');

      if (fullName != null && fullName.trim().isNotEmpty) {
        userFullName = fullName.trim();
        userFirstName = fullName.trim().split(' ').first;
      } else {
        userFullName = prefs.getString('full_name') ??
            prefs.getString('fullName') ??
            'User';

        userFirstName = prefs.getString('first_name') ??
            prefs.getString('firstName') ??
            userFullName.split(' ').first;
      }

      userEmail = prefs.getString('email') ?? '';
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

  static String _generateInvoiceNumber() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
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

  String todayDate() {
    final today = DateTime.now();
    return DateFormat('MMMM d, yyyy').format(today);
  }

  String dueDate() {
    final now = DateTime.now();
    final nextMonth = DateTime(
      now.month == 12 ? now.year + 1 : now.year,
      now.month == 12 ? 1 : now.month + 1,
      5,
    );
    return DateFormat('MMMM d, yyyy').format(nextMonth);
  }

  String currentAndNextMonth() {
    final now = DateTime.now();

    final currentMonth = DateFormat('MMM').format(now);

    final nextMonth = DateFormat('MMM').format(
      DateTime(now.year, now.month + 1),
    );

    return '$currentMonth/ $nextMonth ${now.year}';
  }

  @override
  void initState() {
    super.initState();
    todayDate();
    _loadUserData();
    apiService = ApiService(baseUrl: baseUrl);
    unitFuture = apiService.fetchUnitDetails(widget.unitId);
    serviceCost = widget.waterBill + widget.serviceCost;
  }

  // Preview PDF
  Future<void> _previewPdfOnWeb() async {
    await _withLoading(() async {
      final Uint8List? imageBytes = await _screenshotController.capture();

      if (imageBytes != null) {
        final pdf = pw.Document();
        final image = pw.MemoryImage(imageBytes);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Center(
                child: pw.Image(image),
              );
            },
          ),
        );

        await Printing.layoutPdf(onLayout: (format) async => pdf.save());
      }
    });
  }

  // Download PDF
  Future<void> _downloadPdfOnWeb() async {
    await _withLoading(() async {
      final Uint8List? imageBytes = await _screenshotController.capture();

      if (imageBytes != null) {
        final pdf = pw.Document();
        final image = pw.MemoryImage(imageBytes);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Center(
                child: pw.Image(image),
              );
            },
          ),
        );

        await Printing.sharePdf(
          bytes: await pdf.save(),
          filename: 'invoice_$invoiceNumber.pdf',
        );
      }
    });
  }

  // Save invoice + upload PDF
  Future<void> _saveInvoice() async {
    await _withLoading(() async {
      /*
      |--------------------------------------------------------------------------
      | 1. Create invoice in Laravel
      |--------------------------------------------------------------------------
      */

      final response = await apiService.createInvoice(
        tenantId: widget.tenantId,
        refNo: double.parse(invoiceNumber),
        service: serviceCost,
        invoiceMonth: dueDate(),
      );

      if (response.error != null) {
        throw Exception(response.error!);
      }

      /*
      |--------------------------------------------------------------------------
      | 2. Generate PDF
      |--------------------------------------------------------------------------
      */

      final pdfBytes = await _generateInvoicePdf();

      if (pdfBytes == null) {
        throw Exception('Unable to generate invoice PDF.');
      }

      /*
      |--------------------------------------------------------------------------
      | 3. Upload PDF to Laravel
      |--------------------------------------------------------------------------
      */

      await _uploadPdfToLaravel(pdfBytes);
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white),
            SizedBox(width: 10),
            Expanded(
              child: Text('Invoice created and emailed successfully'),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 1400));

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  // Upload PDF silently
  Future<void> _uploadPdfToLaravel(Uint8List pdfBytes) async {
    final url = Uri.parse(uploadInvoice);

    final request = http.MultipartRequest('POST', url);

    request.fields['property_name'] = widget.propertyName;
    request.fields['property_id'] = widget.propertyId.toString();

    request.fields['tenant_id'] = widget.tenantId.toString();
    request.fields['tenant_name'] = widget.tenantName;
    request.fields['tenant_email'] = widget.tenantEmail;

    request.fields['unit_id'] = widget.unitId.toString();
    request.fields['unit_number'] = widget.houseNo.toString();

    request.fields['invoice_number'] = invoiceNumber;
    request.fields['invoice_date'] = todayDate();
    request.fields['due_date'] = dueDate();

    request.fields['invoice_period'] = currentAndNextMonth();

    request.fields['greeting_name'] = widget.tenantName.split(' ').first;

    request.fields['management_name'] = '${widget.propertyName} Management';

    final pdfFile = http.MultipartFile.fromBytes(
      'invoice',
      pdfBytes,
      filename: 'invoice_$invoiceNumber.pdf',
      contentType: MediaType('application', 'pdf'),
    );

    request.files.add(pdfFile);

    final response = await request.send();

    final responseBody = await response.stream.bytesToString();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Invoice upload failed: $responseBody');
    }

    late final Map<String, dynamic> responseData;

    try {
      final decoded = jsonDecode(responseBody);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
          'Laravel response is not a JSON object.',
        );
      }

      responseData = decoded;
    } catch (e) {
      rethrow;
    }

    final bool success = responseData['success'] == true;

    final String? error = responseData['error']?.toString();

    final String? message = responseData['message']?.toString();

    final dynamic emailResponse = responseData['email'];

    bool emailSent = false;
    String? emailError;

    if (emailResponse is Map) {
      emailSent = emailResponse['sent'] == true;

      if (emailResponse['error'] != null) {
        emailError = emailResponse['error'].toString();
      }
    }

    if (!success) {
      final failureMessage = error ?? message ?? 'Invoice upload failed.';

      throw Exception(failureMessage);
    }

    if (!emailSent) {
      if (emailError != null && emailError.trim().isNotEmpty) {
        throw Exception(
          'Invoice was saved, but the email could not be sent: '
              '$emailError',
        );
      }

      throw Exception(
        'Invoice was saved, but the email could not be sent.',
      );
    }
  }

  // Generic loading wrapper with a cool animated overlay
  Future<void> _withLoading(Future<void> Function() action) async {
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => const _InvoiceLoadingOverlay(),
    );

    try {
      await action();
      navigator.pop();
    } catch (e) {
      navigator.pop();
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text('Error: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<Uint8List?> _generateInvoicePdf() async {
    try {
      final Uint8List? imageBytes = await _screenshotController.capture();

      if (imageBytes == null) {
        return null;
      }

      final pdf = pw.Document();

      final image = pw.MemoryImage(
        imageBytes,
      );

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(
                image,
                fit: pw.BoxFit.contain,
              ),
            );
          },
        ),
      );

      return await pdf.save();
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              children: [
                Screenshot(
                  controller: _screenshotController,
                  child: _buildInvoiceCard(context),
                ),
                const SizedBox(height: 30),
                Wrap(
                  spacing: 12,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _previewPdfOnWeb,
                      icon: const Icon(Icons.remove_red_eye_rounded),
                      label: const Text("Preview"),
                    ),
                    ElevatedButton.icon(
                      onPressed: _downloadPdfOnWeb,
                      icon: const Icon(Icons.download),
                      label: const Text("Download PDF"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16.0, right: 16.0),
        child: FloatingActionButton.extended(
          onPressed: _saveInvoice,
          backgroundColor: Palette.nestBlue,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          icon: const Icon(Icons.send_and_archive_outlined, size: 20),
          label: const Text(
            'Send',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildInvoiceCard(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 800),
      padding: const EdgeInsets.all(32.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A1A1A).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 40),
          _buildDetails(),
          const SizedBox(height: 40),
          _buildItemTable(),
          const SizedBox(height: 32),
          _buildTotal(),
          const SizedBox(height: 40),
          _buildFooter(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header — acronym badge replaces the old logo asset.
  // ---------------------------------------------------------------------------
  Widget _buildHeader() {
    // Prefer the acronym from the loaded unit's property name if we have it,
    // otherwise fall back to the widget's propertyName.
    final propertyForBadge = widget.propertyName.trim().isNotEmpty
        ? widget.propertyName
        : 'Property';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ----- LEFT: acronym badge + issuer details ------------------------
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPropertyAcronymBadge(propertyForBadge),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      propertyForBadge.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: 0.4,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      userFullName,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: -0.3,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    if (userEmail.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        userEmail,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    if (userPhone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        userPhone,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 20),

        // ----- RIGHT: invoice title + number -------------------------------
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'INVOICE',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Palette.nestBlue,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: Palette.nestBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Palette.nestBlue.withValues(alpha: 0.20),
                ),
              ),
              child: Text(
                '#$invoiceNumber',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Palette.nestBlue,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Circular badge with the property initials (e.g. "Villa Apartment" → "VA").
  Widget _buildPropertyAcronymBadge(String propertyName) {
    final acronym = _propertyAcronym(propertyName);
    const size = 62.0;

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
            color: Palette.nestBlue.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        acronym,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 22,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  Widget _buildDetails() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade50,
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: FutureBuilder<UnitDetails>(
              future: unitFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingSection();
                }

                if (snapshot.hasError) {
                  return _buildErrorSection(snapshot.error.toString());
                }

                if (!snapshot.hasData) {
                  return _buildNoDataSection();
                }

                final unit = snapshot.data!;
                return _buildBilledToSection(unit);
              },
            ),
          ),
          Container(
            width: 1,
            height: 120,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            color: Colors.grey.shade300,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildDetailRow('DATE OF ISSUE:', todayDate()),
                const SizedBox(height: 12),
                _buildDetailRow('DUE DATE:', dueDate()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BILLED TO',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 16),
        const SizedBox(
          height: 20,
          width: 120,
          child: LinearProgressIndicator(),
        ),
      ],
    );
  }

  Widget _buildErrorSection(String error) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BILLED TO',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Error loading data',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          error,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildNoDataSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BILLED TO',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'No tenant information',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildBilledToSection(UnitDetails unit) {
    final tenantName = unit.tenantName?.toString().trim().isNotEmpty == true
        ? unit.tenantName!.toString().trim()
        : widget.tenantName.trim().isNotEmpty
        ? widget.tenantName.trim()
        : 'Tenant';

    final propertyName =
    unit.propertyName?.toString().trim().isNotEmpty == true
        ? unit.propertyName!.toString().trim()
        : widget.propertyName.trim().isNotEmpty
        ? widget.propertyName.trim()
        : 'Property';

    final houseNo = unit.houseNo?.toString().trim().isNotEmpty == true
        ? unit.houseNo!.toString().trim()
        : widget.houseNo.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BILLED TO',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),

        const SizedBox(height: 16),

        Text(
          tenantName,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Color(0xFF1A1A1A),
          ),
        ),

        const SizedBox(height: 8),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 16,
              color: Colors.grey.shade500,
            ),
            const SizedBox(width: 6),

            Expanded(
              child: Text(
                propertyName,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                ),
                softWrap: true,
                maxLines: 3,
                overflow: TextOverflow.visible,
              ),
            ),
          ],
        ),

        const SizedBox(height: 4),

        Row(
          children: [
            Icon(
              Icons.home,
              size: 16,
              color: Colors.grey.shade500,
            ),
            const SizedBox(width: 6),

            Text(
              houseNo,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailRow(String title, String value, {TextStyle? valueStyle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: valueStyle ??
              const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Color(0xFF1A1A1A),
              ),
        ),
      ],
    );
  }

  Widget _buildItemTable() {
    return FutureBuilder<UnitDetails>(
      future: unitFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.red.shade100),
              borderRadius: BorderRadius.circular(8),
              color: Colors.red.shade50,
            ),
            child: Text(
              'Error loading items: ${snapshot.error}',
              style: TextStyle(color: Colors.red.shade700),
            ),
          );
        }

        if (!snapshot.hasData) {
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('No items available'),
          );
        }

        final unit = snapshot.data!;
        final rent = double.tryParse(unit.rentAmount.toString()) ?? 0.0;

        final items = [
          {'description': 'Rent Bill', 'amount': rent},
          {'description': 'Water Bill', 'amount': widget.waterBill},
          {'description': 'Service Cost', 'amount': widget.serviceCost},
        ];

        return Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.grey.shade200,
          ),
          child: DataTable(
            columnSpacing: 20,
            horizontalMargin: 0,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            columns: [
              DataColumn(
                label: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 12.0, horizontal: 5.0),
                  child: Text(
                    'ITEM DESCRIPTION',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              DataColumn(
                label: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 12.0, horizontal: 5.0),
                  child: Text(
                    'AMOUNT',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade800,
                      fontSize: 13,
                    ),
                  ),
                ),
                numeric: true,
              ),
            ],
            rows: items.map((item) {
              return DataRow(
                cells: [
                  DataCell(
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12.0, horizontal: 5.0),
                      child: Text(
                        item['description'].toString(),
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12.0, horizontal: 5.0),
                      child: Text(
                        'Ksh ${NumberFormat.decimalPattern().format(item['amount'])}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildTotal() {
    return FutureBuilder<UnitDetails>(
      future: unitFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox();
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Unable to calculate total'),
          );
        }

        final unit = snapshot.data!;
        final rent = double.tryParse(unit.rentAmount.toString()) ?? 0.0;
        final subtotal = rent + widget.waterBill + widget.serviceCost;
        const taxRate = 0.0;
        final tax = subtotal * taxRate;
        final total = subtotal + tax;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildTotalRow(
                    'Subtotal:',
                    'Ksh ${NumberFormat.decimalPattern().format(subtotal)}',
                    isBold: false,
                  ),
                  const SizedBox(height: 12),
                  _buildTotalRow(
                    'Tax (7%):',
                    'Ksh ${NumberFormat.decimalPattern().format(tax)}',
                    isBold: false,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 1,
                    width: 200,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  _buildTotalRow(
                    'TOTAL:',
                    'Ksh ${NumberFormat.decimalPattern().format(total)}',
                    isBold: true,
                    totalColor: Palette.nestBlue,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTotalRow(String label, String value,
      {required bool isBold, Color? totalColor}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: isBold ? 16 : 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        const SizedBox(width: 20),
        Text(
          value,
          style: TextStyle(
            color: totalColor ?? const Color(0xFF1A1A1A),
            fontSize: isBold ? 16 : 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    final paybillNumber = widget.paybillNumber?.trim() ?? '';
    final accountNumber = widget.accountNumber?.trim() ?? '';

    final hasPaybill = paybillNumber.isNotEmpty;
    final hasAccount = accountNumber.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.blue.shade50,
        border: Border.all(
          color: Colors.blue.shade100,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Colors.blue.shade700,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Payment Instructions',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.blue.shade800,
                  fontSize: 15,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            'Thank you for your business. Please ensure payment is made by the due date to avoid any late fees.',
            style: TextStyle(
              color: Colors.blue.shade800,
              fontSize: 14,
              height: 1.5,
            ),
          ),

          if (hasPaybill || hasAccount) ...[
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blue.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.blue.shade700,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'M-Pesa Payment',
                        style: TextStyle(
                          color: Colors.blue.shade800,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  if (hasPaybill)
                    Row(
                      children: [
                        SizedBox(
                          width: 90,
                          child: Text(
                            'Paybill:',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            paybillNumber,
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),

                  if (hasPaybill && hasAccount)
                    const SizedBox(height: 8),

                  if (hasAccount)
                    Row(
                      children: [
                        SizedBox(
                          width: 90,
                          child: Text(
                            'Account:',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '$accountNumber#${widget.houseNo}',
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// INVOICE LOADING OVERLAY — animated, brand-styled modal loader
// ============================================================================

class _InvoiceLoadingOverlay extends StatefulWidget {
  const _InvoiceLoadingOverlay();

  @override
  State<_InvoiceLoadingOverlay> createState() => _InvoiceLoadingOverlayState();
}

class _InvoiceLoadingOverlayState extends State<_InvoiceLoadingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  final List<String> _steps = const [
    'Creating invoice...',
    'Generating PDF...',
    'Uploading & sending email...',
  ];

  int _currentStep = 0;

  @override
  void initState() {
    super.initState();

    _tick();
  }

  void _tick() async {
    while (mounted && _currentStep < _steps.length - 1) {
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() => _currentStep++);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 30,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Palette.nestBlue.withValues(alpha: 0.22),
                blurRadius: 40,
                spreadRadius: -8,
                offset: const Offset(0, 18),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _ctrl,
                builder: (_, _) {
                  final t = _ctrl.value;
                  final pulse = 1.0 + (0.10 * (1 - (t * 2 - 1).abs()));
                  final glow = 0.18 + (0.22 * (1 - (t * 2 - 1).abs()));

                  return Transform.rotate(
                    angle: t * 6.28318,
                    child: Transform.scale(
                      scale: pulse,
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Palette.nestBlue,
                              Color.lerp(Palette.nestBlue, Colors.white, 0.25)!,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Palette.nestBlue.withValues(alpha: glow),
                              blurRadius: 26,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 22),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.25),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: Text(
                  _steps[_currentStep],
                  key: ValueKey(_currentStep),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: Color(0xFF1A1A1A),
                    letterSpacing: -0.1,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              AnimatedBuilder(
                animation: _ctrl,
                builder: (_, _) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (i) {
                      final offset = i * 0.2;
                      final t = (_ctrl.value + offset) % 1.0;
                      final scale = 0.6 + 0.5 * (1 - (t * 2 - 1).abs());
                      final opacity = 0.35 + 0.65 * (1 - (t * 2 - 1).abs());

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 9,
                            height: 9,
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
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}