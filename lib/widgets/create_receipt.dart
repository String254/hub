import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hub/services/services.dart';
import 'package:hub/models/models.dart';
import 'package:hub/config/config.dart';
import 'package:hub/pages/pages.dart';

class CreateReceiptScreen extends StatefulWidget {
  final int invoiceId;
  final String invoiceRef;

  const CreateReceiptScreen({
    super.key,
    required this.invoiceId,
    required this.invoiceRef,
  });

  @override
  State<CreateReceiptScreen> createState() => _CreateReceiptScreenState();
}

class _CreateReceiptScreenState extends State<CreateReceiptScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  late ApiPropertyService apiService;
  late Future<ApiInvoiceResponse> _invoiceFuture;

  double remainingBalance = 0.0;
  bool _isSubmitting = false;

  // ---------------------------------------------------------------------------
  // SAFE NUMBER PARSER
  // ---------------------------------------------------------------------------

  double safeParseDouble(dynamic input) {
    if (input == null) {
      return 0.0;
    }

    if (input is num) {
      return input.toDouble();
    }

    if (input is String) {
      final cleaned = input.replaceAll(',', '').trim();
      return double.tryParse(cleaned) ?? 0.0;
    }

    return 0.0;
  }

  // ---------------------------------------------------------------------------
  // INIT
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    apiService = ApiPropertyService(baseUrl: baseUrl);

    _invoiceFuture = apiService.fetchReceipt(widget.invoiceId);
  }

  // ---------------------------------------------------------------------------
  // DISPOSE
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // CREATE RECEIPT
  // ---------------------------------------------------------------------------

  Future<void> _handleCreateReceipt() async {
    if (_isSubmitting) {
      return;
    }

    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final enteredAmount = double.tryParse(
      _amountController.text.trim().replaceAll(',', ''),
    );

    if (enteredAmount == null || enteredAmount <= 0) {
      return;
    }

    // Prevent keyboard from remaining open
    FocusScope.of(context).unfocus();

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Remove any decimal suffix from invoice reference.
      //
      // Example:
      // 473033.00 -> 473033
      // 473033    -> 473033
      final cleanRef = widget.invoiceRef.split('.').first.trim();

      final request = CreateReceiptRequest(
        invoiceId: widget.invoiceId,
        ref: cleanRef,
        amount: enteredAmount,
        paymentDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      );

      // ---------------------------------------------------------------
      // CALL API
      // ---------------------------------------------------------------

      final response = await apiService.createReceipt(request);

      if (!mounted) {
        return;
      }

      // ---------------------------------------------------------------
      // NAVIGATE TO RECEIPT PAGE
      // ---------------------------------------------------------------

      setState(() {
        _isSubmitting = false;
      });

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ReceiptPage(
            invoiceRef: widget.invoiceRef,
            invoiceId: widget.invoiceId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to record payment: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    final isSmallScreen = screenSize.width < 600;
    final isMediumScreen = screenSize.width >= 600 && screenSize.width < 900;
    final isDesktop = screenSize.width >= 1200;

    final horizontalPadding =
    isSmallScreen ? 16.0 : (isMediumScreen ? 24.0 : 32.0);

    final contentMaxWidth =
    isDesktop ? 800.0 : (isMediumScreen ? 700.0 : 500.0);

    final cardPadding = isSmallScreen ? 16.0 : 24.0;

    final fontSize = isSmallScreen ? 13.0 : 14.0;

    final titleFontSize = isSmallScreen ? 16.0 : 18.0;

    final buttonHeight = isSmallScreen ? 48.0 : 54.0;

    final borderRadius = isSmallScreen ? 12.0 : 16.0;

    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Record Payment',
          style: TextStyle(
            fontSize: isSmallScreen ? 16 : 18,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue.shade700,
        centerTitle: !isSmallScreen,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxWidth),
                child: FutureBuilder<ApiInvoiceResponse>(
                  future: _invoiceFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildLoadingState(fontSize, isSmallScreen);
                    }

                    if (snapshot.hasError) {
                      return _buildErrorState(
                        snapshot.error.toString(),
                        horizontalPadding,
                        titleFontSize,
                        fontSize,
                        isSmallScreen,
                      );
                    }

                    if (!snapshot.hasData) {
                      return _buildErrorState(
                        'No invoice data was returned.',
                        horizontalPadding,
                        titleFontSize,
                        fontSize,
                        isSmallScreen,
                      );
                    }

                    final invoice = snapshot.data!;

                    final invoiceAmount = safeParseDouble(invoice.amount);

                    final totalPaid = safeParseDouble(invoice.totalPaid);

                    final balance = safeParseDouble(invoice.balance);

                    remainingBalance = balance;

                    final refNo = invoice.ref.toString();

                    return _buildForm(
                      invoiceAmount,
                      totalPaid,
                      balance,
                      refNo,
                      horizontalPadding,
                      cardPadding,
                      fontSize,
                      titleFontSize,
                      borderRadius,
                      buttonHeight,
                      isSmallScreen,
                      isDesktop,
                      invoice.invoiceDate,
                    );
                  },
                ),
              ),
            ),
          ),

          // Full-screen submitting overlay
          if (_isSubmitting) _buildSubmittingOverlay(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FORM
  // ---------------------------------------------------------------------------

  Widget _buildForm(
      double invoiceAmount,
      double totalPaid,
      double balance,
      String refNo,
      double horizontalPadding,
      double cardPadding,
      double fontSize,
      double titleFontSize,
      double borderRadius,
      double buttonHeight,
      bool isSmallScreen,
      bool isDesktop,
      String invoiceDate,
      ) {
    return ScrollConfiguration(
      behavior: const ScrollBehavior().copyWith(scrollbars: false),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(horizontalPadding),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // -----------------------------------------------------------
              // SUMMARY CARD
              // -----------------------------------------------------------

              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                child: Padding(
                  padding: EdgeInsets.all(cardPadding),
                  child: Column(
                    children: [
                      _buildSummaryRow(
                        'Invoice Amount',
                        'KES ${NumberFormat('#,##0').format(invoiceAmount)}',
                        isSmallScreen: isSmallScreen,
                      ),
                      SizedBox(height: isSmallScreen ? 8 : 12),
                      _buildSummaryRow(
                        'Total Paid',
                        'KES ${NumberFormat('#,##0').format(totalPaid)}',
                        color: Colors.green,
                        isSmallScreen: isSmallScreen,
                      ),
                      Divider(height: isSmallScreen ? 20 : 24),
                      _buildSummaryRow(
                        'Remaining Balance',
                        'KES ${NumberFormat('#,##0').format(balance)}',
                        color: balance == 0 ? Colors.green : Colors.orange,
                        isBold: true,
                        fontSize: isSmallScreen ? 16 : 18,
                        isSmallScreen: isSmallScreen,
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: isSmallScreen ? 20 : 24),

              // -----------------------------------------------------------
              // PAYMENT FORM
              // -----------------------------------------------------------

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(borderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: EdgeInsets.all(cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Information',
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: isSmallScreen ? 16 : 20),

                    _buildInfoRow(
                      icon: Icons.receipt,
                      label: 'Receipt Reference',
                      value: refNo.split('.').first,
                      isSmallScreen: isSmallScreen,
                    ),

                    SizedBox(height: isSmallScreen ? 12 : 16),

                    TextFormField(
                      controller: _amountController,
                      enabled: !_isSubmitting,
                      decoration: InputDecoration(
                        labelText: 'Amount Paid',
                        hintText: 'Enter amount',
                        prefixIcon: const Icon(
                          Icons.money,
                          color: Colors.blue,
                        ),
                        suffixText: 'KES',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.blue.shade700,
                            width: 2,
                          ),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter amount paid';
                        }

                        final amount = double.tryParse(
                          value.trim().replaceAll(',', ''),
                        );

                        if (amount == null) {
                          return 'Please enter a valid number';
                        }

                        if (amount <= 0) {
                          return 'Amount must be greater than 0';
                        }

                        if (amount > remainingBalance) {
                          return 'Amount cannot exceed remaining balance of '
                              'KES ${NumberFormat('#,##0').format(remainingBalance)}';
                        }

                        return null;
                      },
                    ),

                    SizedBox(height: isSmallScreen ? 12 : 16),

                    _buildInfoRow(
                      icon: Icons.calendar_today,
                      label: 'Payment Date',
                      value: DateFormat('dd MMMM yyyy').format(DateTime.now()),
                      isSmallScreen: isSmallScreen,
                    ),

                    SizedBox(height: isSmallScreen ? 12 : 16),

                    _buildInfoRow(
                      icon: Icons.event,
                      label: 'Due Date',
                      value: _formatInvoiceDate(invoiceDate),
                      isSmallScreen: isSmallScreen,
                    ),

                    SizedBox(height: isSmallScreen ? 24 : 32),

                    // -----------------------------------------------------
                    // BUTTONS
                    // -----------------------------------------------------

                    if (isDesktop)
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              label: 'Cancel',
                              onPressed: _isSubmitting
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              isPrimary: false,
                              height: buttonHeight,
                              borderRadius: borderRadius,
                            ),
                          ),

                          const SizedBox(width: 16),

                          Expanded(
                            child: _buildActionButton(
                              label: 'Record Payment',
                              onPressed: _isSubmitting
                                  ? null
                                  : _handleCreateReceipt,
                              isPrimary: true,
                              height: buttonHeight,
                              borderRadius: borderRadius,
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildActionButton(
                            label: 'Record Payment',
                            onPressed: _isSubmitting
                                ? null
                                : _handleCreateReceipt,
                            isPrimary: true,
                            height: buttonHeight,
                            borderRadius: borderRadius,
                          ),

                          SizedBox(height: isSmallScreen ? 8 : 12),

                          _buildActionButton(
                            label: 'Cancel',
                            onPressed: _isSubmitting
                                ? null
                                : () => Navigator.of(context).pop(),
                            isPrimary: false,
                            height: buttonHeight,
                            borderRadius: borderRadius,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FORMAT DATE
  // ---------------------------------------------------------------------------

  String _formatInvoiceDate(String invoiceDate) {
    try {
      return DateFormat('dd MMMM yyyy').format(DateTime.parse(invoiceDate));
    } catch (_) {
      return invoiceDate;
    }
  }

  // ---------------------------------------------------------------------------
  // LOADING STATE
  // ---------------------------------------------------------------------------

  Widget _buildLoadingState(double fontSize, bool isSmallScreen) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading invoice details...',
            style: TextStyle(
              fontSize: fontSize,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ERROR STATE
  // ---------------------------------------------------------------------------

  Widget _buildErrorState(
      String error,
      double horizontalPadding,
      double titleFontSize,
      double fontSize,
      bool isSmallScreen,
      ) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(horizontalPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red,
              size: isSmallScreen ? 48 : 64,
            ),

            const SizedBox(height: 16),

            Text(
              'Error Loading Invoice',
              style: TextStyle(
                fontSize: titleFontSize * 0.9,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            Text(
              error,
              style: TextStyle(
                fontSize: fontSize,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: () {
                setState(() {
                  _invoiceFuture = apiService.fetchReceipt(widget.invoiceId);
                });
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SUBMITTING OVERLAY
  // ---------------------------------------------------------------------------

  Widget _buildSubmittingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.45),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 32,
              vertical: 28,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.blue,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'Recording Payment...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'Please wait while we process\n'
                      'and generate your receipt.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // INFO ROW
  // ---------------------------------------------------------------------------

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isSmallScreen,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isSmallScreen ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: isSmallScreen ? 16 : 20,
              color: Colors.blue.shade700,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 11 : 12,
                    color: Colors.grey.shade600,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  value,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 13 : 14,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ACTION BUTTON
  // ---------------------------------------------------------------------------

  Widget _buildActionButton({
    required String label,
    required VoidCallback? onPressed,
    required bool isPrimary,
    required double height,
    required double borderRadius,
  }) {
    final disabled = onPressed == null;

    return SizedBox(
      width: double.infinity,
      height: height,
      child: isPrimary
          ? ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade700,
          disabledBackgroundColor: Colors.blue.shade300,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        child: disabled
            ? const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.white,
            ),
          ),
        )
            : Text(
          label,
          style: TextStyle(
            fontSize: height * 0.3,
            fontWeight: FontWeight.w400,
            color: Colors.white,
          ),
        ),
      )
          : OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey.shade400),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: height * 0.3,
            color: Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SUMMARY ROW
  // ---------------------------------------------------------------------------

  Widget _buildSummaryRow(
      String label,
      String value, {
        Color? color,
        bool isBold = false,
        double fontSize = 14,
        required bool isSmallScreen,
      }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isSmallScreen ? 13 : 14,
            color: Colors.grey.shade600,
          ),
        ),

        Text(
          value,
          style: TextStyle(
            fontSize: isSmallScreen ? fontSize - 1 : fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}