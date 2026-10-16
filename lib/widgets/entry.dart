import 'package:flutter/material.dart';
import 'package:hub/config/config.dart';
import 'package:hub/pages/pages.dart';
import 'package:hub/services/services.dart';

class AppEntryPage extends StatefulWidget {
  const AppEntryPage({super.key});

  @override
  State<AppEntryPage> createState() => _AppEntryPageState();
}

class _AppEntryPageState extends State<AppEntryPage> {
  String? _error;

  @override
  void initState() {
    super.initState();

    // Wait until the first frame has been rendered before using
    // Navigator with this page's BuildContext.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  Future<void> _initialize() async {
    try {
      // =============================================================
      // CURRENT BROWSER URL
      // =============================================================

      final Uri uri = Uri.base;
      final List<String> segments = uri.pathSegments;

      // =============================================================
      // TENANT PORTAL ACCESS
      //
      // Supported URLs:
      //
      // https://domain.com/tenant/portal/access/{TOKEN}
      //
      // OR:
      //
      // https://domain.com/flutter/tenant/portal/access/{TOKEN}
      //
      // We search for "tenant" rather than assuming its position.
      // =============================================================

      final int tenantIndex = segments.indexOf('tenant');

      if (tenantIndex >= 0) {
        final bool hasPortalSegment =
            segments.length > tenantIndex + 1 &&
                segments[tenantIndex + 1] == 'portal';

        final bool hasAccessSegment =
            segments.length > tenantIndex + 2 &&
                segments[tenantIndex + 2] == 'access';

        final bool hasToken =
            segments.length > tenantIndex + 3 &&
                segments[tenantIndex + 3].trim().isNotEmpty;

        if (hasPortalSegment && hasAccessSegment && hasToken) {
          final String accessToken = segments[tenantIndex + 3].trim();

          if (!mounted) {
            return;
          }

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => TenantPortalAuthPage(
                accessToken: accessToken,
                service: TenantPortalService(
                  baseUrl: baseUrl,
                ),
              ),
            ),
          );

          return;
        }
      }

      // =============================================================
      // EXISTING TENANT SESSION
      //
      // If the tenant has previously authenticated successfully,
      // take them directly to the tenant portal.
      // =============================================================

      final bool hasSession = await TenantPortalStorage.hasValidSession();

      if (!mounted) {
        return;
      }

      if (hasSession) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => TenantPortalPage(
              service: TenantPortalService(
                baseUrl: baseUrl,
              ),
            ),
          ),
        );

        return;
      }

      // =============================================================
      // NORMAL KEJAHUB APPLICATION
      //
      // No tenant portal URL and no valid tenant session.
      // Open the normal sign-in screen.
      // =============================================================

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const SignInScreen(),
        ),
      );
    } catch (e, stackTrace) {
      // =============================================================
      // INITIALIZATION ERROR
      // =============================================================

      if (!mounted) {
        return;
      }

      setState(() {
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ===============================================================
    // ERROR SCREEN
    // ===============================================================

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Kejahub Portal'),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 56,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Unable to start Kejahub Portal',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  _error!,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _error = null;
                    });

                    _initialize();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ===============================================================
    // INITIAL LOADING
    // ===============================================================

    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}