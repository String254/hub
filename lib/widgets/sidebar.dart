import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:flutter/material.dart';
import 'package:hub/config/config.dart';
import 'package:sidebarx/sidebarx.dart';
import 'package:hub/pages/pages.dart';

class NavigationSideBar extends StatelessWidget {
  NavigationSideBar({super.key});

  final _controller = SidebarXController(selectedIndex: 0, extended: true);
  final _key = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final isSmallScreen = MediaQuery.of(context).size.width < 600;
        return Scaffold(
          key: _key,
          appBar: isSmallScreen
              ? AppBar(
            backgroundColor: Palette.theme,
            leading: IconButton(
              onPressed: () {
                _key.currentState?.openDrawer();
              },
              icon: const Icon(Icons.menu),
            ),
          )
              : null,
          drawer: SideBar(controller: _controller),
          body: Row(
            children: [
              if (!isSmallScreen) SideBar(controller: _controller),
              Expanded(
                child: Center(
                  child: _ScreensExample(
                    controller: _controller,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class SideBar extends StatelessWidget {
  const SideBar({
    super.key,
    required SidebarXController controller,
  }) : _controller = controller;

  final SidebarXController _controller;

  @override
  Widget build(BuildContext context) {
    return SidebarX(
      controller: _controller,
      theme: SidebarXTheme(
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: canvasColor,
          borderRadius: BorderRadius.circular(20),
        ),
        hoverColor: scaffoldBackgroundColor,
        textStyle: TextStyle(
          color: Colors.white.withOpacity(0.7),
          fontSize: 13, // Reduced for more items
        ),
        selectedTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 13, // Reduced for more items
        ),
        itemTextPadding: const EdgeInsets.only(left: 30, top: 8, bottom: 8),
        selectedItemTextPadding: const EdgeInsets.only(left: 30, top: 8, bottom: 8),
        itemDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: canvasColor),
        ),
        selectedItemDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: actionColor.withOpacity(0.37),
          ),
          gradient: const LinearGradient(
            colors: [accentCanvasColor, canvasColor],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.28),
              blurRadius: 30,
            )
          ],
        ),
        iconTheme: IconThemeData(
          color: Colors.white.withOpacity(0.7),
          size: 20,
        ),
        selectedIconTheme: const IconThemeData(
          color: Colors.white,
          size: 20,
        ),
      ),
      extendedTheme: const SidebarXTheme(
        width: 200,
        // height: 700, // Uncomment and adjust if needed
        decoration: BoxDecoration(
          color: canvasColor,
        ),
      ),
      footerDivider: divider,
      headerBuilder: (context, extended) {
        return SizedBox(
          height: 50,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Image.asset('assets/images/logo.png'),
          ),
        );
      },
      items: [
        const SidebarXItem(
          icon: BootstrapIcons.grid_1x2_fill,
          label: 'Dashboard',
        ),
        const SidebarXItem(
          icon: BootstrapIcons.houses,
          label: 'Manage',
        ),
        const SidebarXItem(
          icon: BootstrapIcons.graph_up_arrow,
          label: 'Analytics',
        ),
        const SidebarXItem(
          icon: BootstrapIcons.file_earmark_bar_graph,
          label: 'Documents',
        ),
        const SidebarXItem(
          icon: BootstrapIcons.gear,
          label: 'Maintenance',
        ),
        const SidebarXItem(
          icon: BootstrapIcons.bell,
          label: 'Notifications',
        ),
        const SidebarXItem(
          icon: BootstrapIcons.robot,
          label: 'AI Assistant',
        ),

      ],
    );
  }
}

class _ScreensExample extends StatelessWidget {
  const _ScreensExample({super.key, required this.controller});

  final SidebarXController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final pageTitle = _getTitleByIndex(controller.selectedIndex);
        switch (controller.selectedIndex) {
          case 0:
            return const DashboardResponsivePage();
          case 1:
            return const ManageResponsivePage();
          case 2:
            return const InsightsPage();
          case 3:
            return const DocumentsPage();
          case 4:
            return const MaintenancePage();
          case 5:
            return NotificationsPage();
          case 6:
            return const ChatPage();
          default:
            return Text(
              pageTitle,
              style: theme.textTheme.headlineSmall,
            );
        }
      },
    );
  }
}

String _getTitleByIndex(int index) {
  switch (index) {
    case 0:
      return 'Dashboard';
    case 1:
      return 'Manage';
    case 2:
      return 'Payments';
    case 3:
      return 'Insights';
    case 4:
      return 'Reports';
    case 5:
      return 'AI Assistant';
    case 6:
      return 'Notifications'; // Add this
    default:
      return 'Not found page';
  }
}

// Keep your constants at the bottom
const primaryColor = Color(0xFF47D5C1);
const canvasColor = Color(0xFF049B96);
const scaffoldBackgroundColor = Color(0xFF19F1B0);
const accentCanvasColor = Color(0xFF5EA896);
const white = Colors.white;
final actionColor = const Color(0xFF05F3C8).withOpacity(0.6);
final divider = Divider(color: white.withOpacity(0.3), height: 1);