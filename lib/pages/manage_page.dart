import 'package:flutter/material.dart';
import 'package:hub/responsive/manage_page/widgets.dart';

class ManageResponsivePage extends StatefulWidget {
  const ManageResponsivePage({Key? key}) : super(key: key);

  @override
  State<ManageResponsivePage> createState() => _ManageResponsivePageState();
}

class _ManageResponsivePageState extends State<ManageResponsivePage> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
        body: ResponsiveLayout(mobileBody: ManageMobilePage(), desktopBody: ManageDesktopPage())
    );
  }
}
