import 'package:flutter/material.dart';
import 'package:hub/models/models.dart';
import 'package:hub/config/config.dart';
import 'package:hub/pages/pages.dart';
import 'package:hub/services/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ManageDesktopPage extends StatefulWidget {
  const ManageDesktopPage({super.key});

  @override
  State<ManageDesktopPage> createState() => _ManageDesktopPageState();
}

class _ManageDesktopPageState extends State<ManageDesktopPage> {
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
          margin: const EdgeInsets.all(20),
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
    final paybillCtrl = TextEditingController();
    final accountCtrl = TextEditingController();

    bool isSaving = false;

    String paymentMethod = 'mpesa_paybill';

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              final requiresPaybill =
                  paymentMethod == 'mpesa_paybill';

              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                titlePadding:
                const EdgeInsets.fromLTRB(24, 22, 24, 8),
                contentPadding:
                const EdgeInsets.fromLTRB(24, 12, 24, 8),
                actionsPadding:
                const EdgeInsets.fromLTRB(24, 8, 24, 20),

                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Palette.nestBlue.withValues(
                          alpha: .10,
                        ),
                        borderRadius:
                        BorderRadius.circular(10),
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
                  ],
                ),

                content: SizedBox(
                  width: 460,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildDialogTextField(
                          controller: nameCtrl,
                          label: 'Property Name',
                          hint: ' Green View Apartments',
                          icon: Icons.home_work_outlined,
                        ),

                        const SizedBox(height: 14),

                        _buildDialogTextField(
                          controller: typeCtrl,
                          label: 'Property Type',
                          hint: 'One Bedroom, Studio Apartment',
                          icon: Icons.category_outlined,
                        ),

                        const SizedBox(height: 14),

                        _buildDialogTextField(
                          controller: locationCtrl,
                          label: 'Location',
                          hint: ' Kilimani, Nairobi',
                          icon: Icons.location_on_outlined,
                        ),

                        const SizedBox(height: 14),

                        _buildDialogTextField(
                          controller: unitsCtrl,
                          label: 'Total Units',
                          hint: 'e.g. 24',
                          icon: Icons.grid_view_rounded,
                          keyboardType:
                          TextInputType.number,
                        ),

                        const SizedBox(height: 14),

                      ],
                    ),
                  ),
                ),

                actions: [
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () {
                      Navigator.of(
                        dialogContext,
                      ).pop();
                    },
                    child: const Text('Cancel'),
                  ),

                  const SizedBox(width: 8),

                  ElevatedButton.icon(
                    onPressed: isSaving
                        ? null
                        : () async {
                      final name =
                      nameCtrl.text.trim();

                      final type =
                      typeCtrl.text.trim();

                      final location =
                      locationCtrl.text.trim();

                      final units =
                      int.tryParse(
                        unitsCtrl.text.trim(),
                      );


                      /*
                          |--------------------------------------------------------------------------
                          | Validation
                          |--------------------------------------------------------------------------
                          */

                      if (name.isEmpty ||
                          type.isEmpty ||
                          location.isEmpty ||
                          units == null ||
                          units <= 0) {
                        _showSnackBar(
                          'Please enter valid property details.',
                          backgroundColor:
                          Colors.orange,
                        );
                        return;
                      }

                      setDialogState(() {
                        isSaving = true;
                      });

                      try {
                        await _apiService
                            .createProperty(
                          name: name,
                          type: type,
                          location: location,
                          totalUnits: units,
                        );

                        if (!mounted) {
                          return;
                        }

                        /*
                            |--------------------------------------------------------------------------
                            | Close dialog first
                            |--------------------------------------------------------------------------
                            */

                        Navigator.of(
                          dialogContext,
                        ).pop();

                        /*
                            |--------------------------------------------------------------------------
                            | Refresh after dialog has closed
                            |--------------------------------------------------------------------------
                            */

                        await _loadAllData();

                        if (!mounted) {
                          return;
                        }

                        _showSnackBar(
                          'Property created successfully.',
                          backgroundColor:
                          Colors.green,
                        );
                      } catch (e) {
                        if (!mounted) {
                          return;
                        }

                        setDialogState(() {
                          isSaving = false;
                        });

                        _showSnackBar(
                          'Failed to create property: $e',
                          backgroundColor:
                          Colors.red,
                        );
                      }
                    },

                    icon: isSaving
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child:
                      CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(
                      Icons.check_rounded,
                    ),

                    label: Text(
                      isSaving
                          ? 'Saving...'
                          : 'Save Property',
                    ),

                    style:
                    ElevatedButton.styleFrom(
                      backgroundColor:
                      Palette.nestBlue,
                      foregroundColor:
                      Colors.white,
                      padding:
                      const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape:
                      RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(9),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      /*
    |--------------------------------------------------------------------------
    | Dispose controllers ONLY after showDialog has completely finished.
    |--------------------------------------------------------------------------
    */

      nameCtrl.dispose();
      typeCtrl.dispose();
      locationCtrl.dispose();
      unitsCtrl.dispose();
      paybillCtrl.dispose();
      accountCtrl.dispose();
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
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
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
  // SUMMARY CARD
  // ============================================================

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.025),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withOpacity(.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PROPERTY TABLE
  // ============================================================

  Widget _buildPropertyTable(
      List<Nest> properties,
      ) {
    if (properties.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: MediaQuery.of(context).size.width * .75,
            ),
            child: DataTable(
              headingRowHeight: 52,
              dataRowMinHeight: 64,
              dataRowMaxHeight: 72,
              horizontalMargin: 22,
              columnSpacing: 34,
              headingRowColor: MaterialStateProperty.all(
                const Color(0xFFF8FAFC),
              ),
              columns: [
                const DataColumn(
                  label: Text(
                    'PROPERTY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey,
                    ),
                  ),
                ),
                const DataColumn(
                  label: Text(
                    'TYPE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey,
                    ),
                  ),
                ),
                const DataColumn(
                  label: Text(
                    'LOCATION',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey,
                    ),
                  ),
                ),
                const DataColumn(
                  label: Text(
                    'UNITS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey,
                    ),
                  ),
                ),
                const DataColumn(
                  label: Text(
                    'ACTION',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
              rows: properties.map((property) {
                return DataRow(
                  cells: [
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Palette.nestBlue.withOpacity(.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.apartment_rounded,
                              size: 19,
                              color: Palette.nestBlue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 180,
                            child: Text(
                              property.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F2937),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      _buildTypeBadge(property.type),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 5),
                          SizedBox(
                            width: 160,
                            child: Text(
                              property.location,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(.07),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${property.totalUnits} units',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Palette.nestBlue,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      ElevatedButton.icon(
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
                          Icons.visibility_outlined,
                          size: 16,
                        ),
                        label: const Text(
                          'View',
                          style: TextStyle(fontSize: 11),
                        ),
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor:
                          Palette.nestBlue.withOpacity(.08),
                          foregroundColor: Palette.nestBlue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
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
        color: Colors.purple.withOpacity(.08),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        type,
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(50),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: Palette.nestBlue.withOpacity(.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasFilters
                    ? Icons.search_off_rounded
                    : Icons.apartment_rounded,
                size: 36,
                color: Palette.nestBlue,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              hasFilters
                  ? 'No matching properties'
                  : 'No properties yet',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              hasFilters
                  ? 'Try changing your search or filter.'
                  : 'Add your first property to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
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
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear Filters'),
              ),
            ],
          ],
        ),
      ),
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
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
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
                      children: [
                        const Text(
                          'Manage Properties',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          isLoadingUser
                              ? 'Manage your properties and units'
                              : 'Welcome back, ${userFirstName ?? 'User'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _refreshData,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      size: 18,
                    ),
                    label: const Text('Refresh'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade800,
                      side: BorderSide(
                        color: Colors.grey.shade300,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _showAddPropertyDialog,
                    icon: const Icon(
                      Icons.add_rounded,
                      size: 19,
                    ),
                    label: const Text('Add Property'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Palette.nestBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // ==================================================
              // SUMMARY
              // ==================================================

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
              const SizedBox(height: 20),

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
                            color: Colors.black.withOpacity(.025),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // ======================================
                          // TABLE TOOLBAR
                          // ======================================

                          Padding(
                            padding: const EdgeInsets.all(18),
                            child: Row(
                              children: [
                                const Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Properties',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      'View and manage your properties',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                // Search
                                SizedBox(
                                  width: 260,
                                  height: 40,
                                  child: TextField(
                                    onChanged: (value) {
                                      setState(() {
                                        _searchQuery = value;
                                      });
                                    },
                                    style: const TextStyle(
                                      fontSize: 12,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Search properties...',
                                      hintStyle: const TextStyle(
                                        fontSize: 12,
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.search,
                                        size: 19,
                                      ),
                                      suffixIcon:
                                      _searchQuery.isNotEmpty
                                          ? IconButton(
                                        onPressed: () {
                                          setState(() {
                                            _searchQuery = '';
                                          });
                                        },
                                        icon: const Icon(
                                          Icons.close,
                                          size: 16,
                                        ),
                                      )
                                          : null,
                                      filled: true,
                                      fillColor:
                                      const Color(0xFFF8FAFC),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                        BorderRadius.circular(9),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding:
                                      const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Type Filter
                                Container(
                                  height: 40,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius:
                                    BorderRadius.circular(9),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedType,
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
                                            (type) =>
                                            DropdownMenuItem<String>(
                                              value: type,
                                              child: Text(
                                                type == 'All'
                                                    ? 'All Types'
                                                    : type,
                                              ),
                                            ),
                                      )
                                          .toList(),
                                      onChanged: (value) {
                                        if (value == null) {
                                          return;
                                        }

                                        setState(() {
                                          _selectedType = value;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),

                          // ======================================
                          // RESULTS INFO
                          // ======================================

                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              20,
                              12,
                              20,
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
                                    padding:
                                    const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Palette.nestBlue
                                          .withOpacity(.08),
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
                          // TABLE
                          // ======================================

                          Expanded(
                            child: _buildPropertyTable(
                              properties,
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

  // ============================================================
  // LOADING
  // ============================================================

  Widget _buildLoadingState() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildErrorState(String error) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(.08),
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
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
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
    );
  }
}