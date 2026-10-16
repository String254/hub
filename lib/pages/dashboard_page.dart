import 'package:flutter/material.dart';
import 'package:hub/responsive/dashboard_page/widgets.dart';

class DashboardResponsivePage extends StatefulWidget {
  const DashboardResponsivePage({super.key});

  @override
  State<DashboardResponsivePage> createState() => _DashboardResponsivePageState();
}

class _DashboardResponsivePageState extends State<DashboardResponsivePage> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
        body: ResponsiveLayout(mobileBody: DashboardMobilePage(), desktopBody: DashboardDesktopPage())
    );
  }
}
