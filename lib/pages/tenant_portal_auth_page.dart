import 'package:flutter/material.dart';
import 'package:hub/pages/pages.dart';
import 'package:hub/services/services.dart';

class TenantPortalAuthPage extends StatefulWidget {
  final String accessToken;
  final TenantPortalService service;

  const TenantPortalAuthPage({
    super.key,
    required this.accessToken,
    required this.service,
  });

  @override
  State<TenantPortalAuthPage> createState() =>
      _TenantPortalAuthPageState();
}

class _TenantPortalAuthPageState
    extends State<TenantPortalAuthPage> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await widget.service.authenticate(
        widget.accessToken,
      );

      //debugPrint('Tenant portal authentication successful');
      //debugPrint('Tenant ID: ${result.user.id}');
      //debugPrint('Session expires: ${result.expiresAt}');

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TenantPortalPage(
            service: widget.service,
          ),
        ),
      );
    } on TenantPortalAuthException catch (e) {
      debugPrint('Tenant portal authentication error: ${e.message}');

      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e, stackTrace) {
      debugPrint('Tenant portal unexpected error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Unable to authenticate your tenant portal.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(
                maxWidth: 420,
              ),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: const Color(0xFFE7EBF0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: 0.04,
                    ),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: _loading
                  ? _buildLoading()
                  : _buildError(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF2FF),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.apartment_rounded,
            color: Color(0xFF1769E0),
            size: 30,
          ),
        ),

        const SizedBox(height: 22),

        const Text(
          'Welcome to Kejahub',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: Color(0xFF172033),
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          'Securely connecting to your tenant portal...',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF6B7280),
            height: 1.5,
          ),
        ),

        const SizedBox(height: 24),

        const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Color(0xFF1769E0),
          ),
        ),

        const SizedBox(height: 18),

        const Text(
          'Please wait',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9CA3AF),
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3F0),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFD95545),
            size: 30,
          ),
        ),

        const SizedBox(height: 20),

        const Text(
          'Unable to access portal',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF172033),
          ),
        ),

        const SizedBox(height: 8),

        Text(
          _error ??
              'The portal link may be invalid or expired.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            height: 1.5,
          ),
        ),

        const SizedBox(height: 22),

        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _loading ? null : _authenticate,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1769E0),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Try again',
              style: TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}