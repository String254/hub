import 'package:flutter/material.dart';
import 'package:hub/models/models.dart';
import 'package:hub/config/config.dart';
import 'package:hub/pages/pages.dart';
import 'package:hub/services/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ManageMobilePage extends StatefulWidget {
  const ManageMobilePage({super.key});

  @override
  State<ManageMobilePage> createState() => _ManageMobilePageState();
}

class _ManageMobilePageState extends State<ManageMobilePage> {
  late final ApiService _apiService;

  // ============================================================
  // USER
  // ============================================================

  String? userFirstName;
  bool isLoadingUser = true;

  // ============================================================
  // PROPERTY DATA
  // ============================================================

  Future<List<Nest>> _propertyFuture = Future.value(<Nest>[]);

  Future<PropertyResponse> _maintenanceFuture = Future.value(
    PropertyResponse(
      properties: [],
      totalUnits: 0,
      occupiedUnits: 0,
      vacantUnits: 0,
      units: [],
    ),
  );

  List<Nest> _propertyCache = [];
  List<PropertyDialog> _maintenanceProperties = [];

  // ============================================================
  // FILTERS
  // ============================================================

  String _searchQuery = '';
  String _selectedType = 'All';

  List<Nest> get _filteredProperties {
    List<Nest> properties = List.from(_propertyCache);

    // Search
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();

      properties = properties.where((property) {
        return property.name.toLowerCase().contains(query) ||
            property.type.toLowerCase().contains(query) ||
            property.location.toLowerCase().contains(query);
      }).toList();
    }

    // Type
    if (_selectedType != 'All') {
      properties = properties
          .where(
            (property) =>
        property.type.toLowerCase() ==
            _selectedType.toLowerCase(),
      )
          .toList();
    }

    return properties;
  }

  List<String> get _propertyTypes {
    final types = _propertyCache
        .map((property) => property.type.trim())
        .where((type) => type.isNotEmpty)
        .toSet()
        .toList();

    types.sort();

    return ['All', ...types];
  }

  // ============================================================
  // MAINTENANCE FORM
  // ============================================================

  PropertyDialog? _selectedProperty;
  String? _selectedHouse;
  String? _selectedSubject;

  final TextEditingController _descCtrl = TextEditingController();

  bool _submittingMaintenance = false;
  bool _addingProperty = false;

  final List<String> _subjectOptions = const [
    'Plumbing Issue',
    'Electrical Issue',
    'Roof Leakage',
    'Pest Control',
    'General Repairs',
  ];

  // ============================================================
  // RESPONSIVE HELPERS
  // ============================================================

  bool get _isMobile => MediaQuery.of(context).size.width < 600;
  bool get _isTablet {
    final w = MediaQuery.of(context).size.width;
    return w >= 600 && w < 850;
  }

  double get _pagePadding => _isMobile ? 14 : 20;

  // ============================================================
  // LIFECYCLE
  // ============================================================

  @override
  void initState() {
    super.initState();

    _apiService = ApiService(baseUrl: baseUrl);

    _loadUserData();
    _loadAllData();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // USER
  // ============================================================

  Future<String?> getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      return prefs.getString('user_id') ??
          prefs.getString('userId') ??
          prefs.getString('id');
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final fullName = prefs.getString('name');

      if (fullName != null && fullName.isNotEmpty) {
        userFirstName = fullName.split(' ').first;
      } else {
        userFirstName = prefs.getString('first_name') ??
            prefs.getString('firstName') ??
            'User';
      }
    } catch (_) {
      userFirstName = 'User';
    }

    if (!mounted) return;

    setState(() {
      isLoadingUser = false;
    });
  }

  // ============================================================
  // LOAD DATA
  // ============================================================

  Future<void> _loadAllData() async {
    try {
      final userIdStr = await getUserId();
      final int? userId = int.tryParse(userIdStr ?? '');

      final propertyFuture = _apiService.fetchPropertiesData();

      Future<PropertyResponse> maintenanceFuture;

      if (userId != null) {
        maintenanceFuture = _apiService.fetchPropertyResponse(userId);
      } else {
        maintenanceFuture = Future.value(
          PropertyResponse(
            properties: [],
            totalUnits: 0,
            occupiedUnits: 0,
            vacantUnits: 0,
            units: [],
          ),
        );
      }

      if (mounted) {
        setState(() {
          _propertyFuture = propertyFuture;
          _maintenanceFuture = maintenanceFuture;
        });
      }

      final props = await propertyFuture;
      final maintResp = await maintenanceFuture;

      if (!mounted) return;

      setState(() {
        _propertyCache = props;
        _maintenanceProperties = maintResp.properties;
      });
    } catch (e) {
      debugPrint('Error loading property data: $e');

      if (!mounted) return;

      setState(() {
        _propertyCache = [];
        _maintenanceProperties = [];
      });
    }
  }

  Future<void> _refreshData() async {
    await _loadAllData();

    if (!mounted) return;

    _showSnackBar(
      'Property data refreshed',
      backgroundColor: Colors.green,
    );
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _showSnackBar(
      String message, {
        Color backgroundColor = Colors.blue,
      }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(_isMobile ? 12 : 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
  }

  // ============================================================
  // ADD PROPERTY
  // ============================================================

  Future<void> _showAddPropertyDialog() async {
    final nameCtrl = TextEditingController();
    final typeCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final unitsCtrl = TextEditingController();

    bool isSaving = false;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return Dialog(
                insetPadding: EdgeInsets.symmetric(
                  horizontal: _isMobile ? 12 : 24,
                  vertical: 24,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Container(
                  width: 460,
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.85,
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Palette.nestBlue.withValues(alpha: .10),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.apartment_rounded,
                              color: Palette.nestBlue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Add Property',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: isSaving
                                ? null
                                : () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Fields
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              _buildDialogTextField(
                                controller: nameCtrl,
                                label: 'Property Name',
                                hint: 'Green View Apartments',
                                icon: Icons.home_work_outlined,
                              ),
                              const SizedBox(height: 12),
                              _buildDialogTextField(
                                controller: typeCtrl,
                                label: 'Property Type',
                                hint: 'One Bedroom, Studio Apartment',
                                icon: Icons.category_outlined,
                              ),
                              const SizedBox(height: 12),
                              _buildDialogTextField(
                                controller: locationCtrl,
                                label: 'Location',
                                hint: 'Kilimani, Nairobi',
                                icon: Icons.location_on_outlined,
                              ),
                              const SizedBox(height: 12),
                              _buildDialogTextField(
                                controller: unitsCtrl,
                                label: 'Total Units',
                                hint: 'e.g. 24',
                                icon: Icons.grid_view_rounded,
                                keyboardType: TextInputType.number,
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Actions
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: isSaving
                                  ? null
                                  : () =>
                                  Navigator.of(dialogContext).pop(),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9),
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                final name = nameCtrl.text.trim();
                                final type = typeCtrl.text.trim();
                                final location =
                                locationCtrl.text.trim();
                                final units = int.tryParse(
                                  unitsCtrl.text.trim(),
                                );

                                if (name.isEmpty ||
                                    type.isEmpty ||
                                    location.isEmpty ||
                                    units == null ||
                                    units <= 0) {
                                  _showSnackBar(
                                    'Please enter valid property details.',
                                    backgroundColor: Colors.orange,
                                  );
                                  return;
                                }

                                setDialogState(() {
                                  isSaving = true;
                                });

                                try {
                                  await _apiService.createProperty(
                                    name: name,
                                    type: type,
                                    location: location,
                                    totalUnits: units,
                                  );

                                  if (!mounted) return;

                                  Navigator.of(dialogContext).pop();

                                  await _loadAllData();

                                  if (!mounted) return;

                                  _showSnackBar(
                                    'Property created successfully.',
                                    backgroundColor: Colors.green,
                                  );
                                } catch (e) {
                                  if (!mounted) return;

                                  setDialogState(() {
                                    isSaving = false;
                                  });

                                  _showSnackBar(
                                    'Failed to create property: $e',
                                    backgroundColor: Colors.red,
                                  );
                                }
                              },
                              icon: isSaving
                                  ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                                  : const Icon(
                                Icons.check_rounded,
                                size: 18,
                              ),
                              label: Text(
                                isSaving ? 'Saving...' : 'Save Property',
                                style: const TextStyle(fontSize: 13),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Palette.nestBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      nameCtrl.dispose();
      typeCtrl.dispose();
      locationCtrl.dispose();
      unitsCtrl.dispose();
    }
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(fontSize: 13),
        hintStyle: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade400,
        ),
        prefixIcon: Icon(icon, size: 19),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: Colors.grey.shade300,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SUMMARY CARD (responsive)
  // ============================================================

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(_isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .025),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: _isMobile ? 40 : 46,
            height: _isMobile ? 40 : 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: _isMobile ? 19 : 22,
            ),
          ),
          SizedBox(width: _isMobile ? 10 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: _isMobile ? 10.5 : 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: _isMobile ? 17 : 21,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: _isMobile ? 9 : 10,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PROPERTY CARD (replaces DataTable row)
  // ============================================================

  Widget _buildPropertyCard(Nest property) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PropertyResponsivePage(
                property: property,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: EdgeInsets.only(bottom: _isMobile ? 10 : 12),
          padding: EdgeInsets.all(_isMobile ? 12 : 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.grey.shade200,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .025),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row — icon + name + view button
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Palette.nestBlue.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.apartment_rounded,
                      size: 20,
                      color: Palette.nestBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          property.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 12,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                property.location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Palette.nestBlue.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: IconButton(
                      tooltip: 'View property',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PropertyResponsivePage(
                              property: property,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 13,
                        color: Palette.nestBlue,
                      ),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Bottom row — type badge + units badge
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildTypeBadge(property.type),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: .07),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.grid_view_rounded,
                          size: 12,
                          color: Palette.nestBlue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${property.totalUnits} units',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Palette.nestBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeBadge(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        type,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.purple,
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    final hasFilters =
        _searchQuery.isNotEmpty || _selectedType != 'All';

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(_isMobile ? 24 : 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: _isMobile ? 66 : 76,
                      height: _isMobile ? 66 : 76,
                      decoration: BoxDecoration(
                        color: Palette.nestBlue.withValues(alpha: .08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        hasFilters
                            ? Icons.search_off_rounded
                            : Icons.apartment_rounded,
                        size: _isMobile ? 30 : 36,
                        color: Palette.nestBlue,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      hasFilters
                          ? 'No matching properties'
                          : 'No properties yet',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: _isMobile ? 15 : 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: Text(
                        hasFilters
                            ? 'Try changing your search or filter.'
                            : 'Add your first property to get started.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    if (hasFilters) ...[
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _selectedType = 'All';
                          });
                        },
                        icon: const Icon(Icons.clear_all, size: 18),
                        label: const Text(
                          'Clear Filters',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            _pagePadding,
            _isMobile ? 12 : 16,
            _pagePadding,
            _isMobile ? 12 : 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==================================================
              // HEADER
              // ==================================================

              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Manage Properties',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: _isMobile ? 17 : 21,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isLoadingUser
                              ? 'Manage your properties and units'
                              : 'Welcome back, ${userFirstName ?? 'User'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: _isMobile ? 11 : 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Refresh
                  if (_isTablet)
                    OutlinedButton.icon(
                      onPressed: _refreshData,
                      icon: const Icon(
                        Icons.refresh_rounded,
                        size: 17,
                      ),
                      label: const Text(
                        'Refresh',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade800,
                        side: BorderSide(
                          color: Colors.grey.shade300,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: Colors.grey.shade300,
                        ),
                      ),
                      child: IconButton(
                        onPressed: _refreshData,
                        icon: const Icon(
                          Icons.refresh_rounded,
                          size: 19,
                          color: Colors.black87,
                        ),
                        padding: const EdgeInsets.all(10),
                        constraints: const BoxConstraints(),
                        tooltip: 'Refresh',
                      ),
                    ),

                  const SizedBox(width: 8),

                  // Add
                  if (_isTablet)
                    ElevatedButton.icon(
                      onPressed: _showAddPropertyDialog,
                      icon: const Icon(
                        Icons.add_rounded,
                        size: 18,
                      ),
                      label: const Text(
                        'Add Property',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Palette.nestBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                    )
                  else
                    ElevatedButton(
                      onPressed: _showAddPropertyDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Palette.nestBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(10),
                        minimumSize: const Size(42, 42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        size: 20,
                      ),
                    ),
                ],
              ),

              SizedBox(height: _isMobile ? 14 : 20),

              // ==================================================
              // SUMMARY CARDS
              // ==================================================

              if (_isMobile)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSummaryCard(
                      title: 'Properties',
                      value: _propertyCache.length.toString(),
                      subtitle: 'Total properties',
                      icon: Icons.apartment_rounded,
                      color: Palette.nestBlue,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            title: 'Units',
                            value: _propertyCache
                                .fold<int>(
                              0,
                                  (sum, property) =>
                              sum + property.totalUnits,
                            )
                                .toString(),
                            subtitle: 'Total units',
                            icon: Icons.grid_view_rounded,
                            color: Colors.purple,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSummaryCard(
                            title: 'Types',
                            value: (_propertyCache
                                .map((p) => p.type)
                                .toSet()
                                .length)
                                .toString(),
                            subtitle: 'Categories',
                            icon: Icons.category_outlined,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    _buildSummaryCard(
                      title: 'Properties',
                      value: _propertyCache.length.toString(),
                      subtitle: 'Total properties',
                      icon: Icons.apartment_rounded,
                      color: Palette.nestBlue,
                    ),
                    const SizedBox(width: 14),
                    _buildSummaryCard(
                      title: 'Units',
                      value: _propertyCache
                          .fold<int>(
                        0,
                            (sum, property) =>
                        sum + property.totalUnits,
                      )
                          .toString(),
                      subtitle: 'Total units',
                      icon: Icons.grid_view_rounded,
                      color: Colors.purple,
                    ),
                    const SizedBox(width: 14),
                    _buildSummaryCard(
                      title: 'Property Types',
                      value: (_propertyCache
                          .map((p) => p.type)
                          .toSet()
                          .length)
                          .toString(),
                      subtitle: 'Different categories',
                      icon: Icons.category_outlined,
                      color: Colors.orange,
                    ),
                  ],
                ),

              SizedBox(height: _isMobile ? 14 : 20),

              // ==================================================
              // MAIN CARD
              // ==================================================

              Expanded(
                child: FutureBuilder<List<Nest>>(
                  future: _propertyFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return _buildLoadingState();
                    }

                    if (snapshot.hasError) {
                      return _buildErrorState(
                        snapshot.error.toString(),
                      );
                    }

                    if (snapshot.hasData) {
                      _propertyCache = snapshot.data!;
                    }

                    final properties = _filteredProperties;

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey.shade200,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .025),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // ======================================
                          // TOOLBAR
                          // ======================================

                          Padding(
                            padding: EdgeInsets.all(_isMobile ? 14 : 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Properties',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'View and manage your properties',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),

                                SizedBox(height: _isMobile ? 12 : 14),

                                // Search + filter
                                if (_isMobile)
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: double.infinity,
                                        height: 42,
                                        child: _buildSearchField(),
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 42,
                                        child: _buildTypeDropdown(),
                                      ),
                                    ],
                                  )
                                else
                                  Row(
                                    children: [
                                      Expanded(
                                        child: SizedBox(
                                          height: 40,
                                          child: _buildSearchField(),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      SizedBox(
                                        height: 40,
                                        child: _buildTypeDropdown(),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),

                          const Divider(height: 1),

                          // ======================================
                          // RESULTS INFO
                          // ======================================

                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              _isMobile ? 14 : 20,
                              12,
                              _isMobile ? 14 : 20,
                              10,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '${properties.length} ${properties.length == 1 ? 'property' : 'properties'}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                if (_searchQuery.isNotEmpty ||
                                    _selectedType != 'All') ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Palette.nestBlue
                                          .withValues(alpha: .08),
                                      borderRadius:
                                      BorderRadius.circular(5),
                                    ),
                                    child: const Text(
                                      'Filtered',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: Palette.nestBlue,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // ======================================
                          // PROPERTY LIST
                          // ======================================

                          Expanded(
                            child: properties.isEmpty
                                ? _buildEmptyState()
                                : ListView.builder(
                              padding: EdgeInsets.fromLTRB(
                                _isMobile ? 12 : 16,
                                0,
                                _isMobile ? 12 : 16,
                                _isMobile ? 12 : 16,
                              ),
                              itemCount: properties.length,
                              itemBuilder: (context, index) {
                                return _buildPropertyCard(
                                  properties[index],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
      style: const TextStyle(fontSize: 12.5),
      decoration: InputDecoration(
        hintText: 'Search properties...',
        hintStyle: const TextStyle(fontSize: 12.5),
        prefixIcon: const Icon(Icons.search, size: 19),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
          onPressed: () {
            setState(() {
              _searchQuery = '';
            });
          },
          icon: const Icon(Icons.close, size: 16),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        )
            : null,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
        ),
      ),
    );
  }

  Widget _buildTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedType,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 18,
          ),
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black87,
          ),
          items: _propertyTypes
              .map(
                (type) => DropdownMenuItem<String>(
              value: type,
              child: Text(
                type == 'All' ? 'All Types' : type,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
              .toList(),
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              _selectedType = value;
            });
          },
        ),
      ),
    );
  }

  // ============================================================
  // LOADING STATE
  // ============================================================

  Widget _buildLoadingState() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                        ),
                      ),
                      SizedBox(height: 14),
                      Text(
                        'Loading properties...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState(String error) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(_isMobile ? 20 : 30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: .08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Unable to load properties',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Text(
                          error,
                          textAlign: TextAlign.center,
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadAllData,
                        icon: const Icon(Icons.refresh, size: 17),
                        label: const Text('Try Again'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Palette.nestBlue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}