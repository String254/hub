import 'package:flutter/material.dart';
import 'package:hub/models/nest.dart';
import 'package:hub/responsive/property_page/widgets.dart';

class PropertyResponsivePage extends StatefulWidget {
  final Nest property;
  const PropertyResponsivePage({super.key, required this.property});

  @override
  State<PropertyResponsivePage> createState() => _PropertyResponsivePageState();
}

class _PropertyResponsivePageState extends State<PropertyResponsivePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: ResponsiveLayout(mobileBody: PropertyDetailsMobilePage(property: widget.property,), desktopBody: PropertyDetailsDesktopPage(property: widget.property,))
    );
  }
}
