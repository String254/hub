import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hub/models/models.dart';
import 'package:hub/services/services.dart';
import 'package:hub/config/config.dart';

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  late ApiService apiService;
  late DocumentService documentService;

  ScaffoldMessengerState? _messenger;

  List<Document> _allDocuments = [];
  List<Document> _filteredDocuments = [];

  bool _loading = false;
  bool _uploading = false;
  bool _loadingDialog = false;

  int _selectedPropertyId = -1;
  DocumentCategory? _selectedCategory;
  String _searchQuery = '';
  String _sortOption = 'Newest';

  String _dateFilter = 'All Time';
  int? _selectedMonth;
  int? _selectedYear;

  bool _isDeleting = false;

  // Filter panel visibility (hidden by default)
  bool _showFilters = false;

  late Future<PropertyResponse> _propertyFuture;

  // ─────────────────────────────────────────────────────────────
  // RESPONSIVE HELPERS
  // ─────────────────────────────────────────────────────────────

  bool get _isMobile => MediaQuery.of(context).size.width < 600;
  bool get _isTablet {
    final w = MediaQuery.of(context).size.width;
    return w >= 600 && w < 850;
  }

  double get _pagePadding => _isMobile ? 14 : 20;

  @override
  void initState() {
    super.initState();
    apiService = ApiService(baseUrl: baseUrl);
    documentService = DocumentService(baseUrl: baseUrl);
    _propertyFuture = apiService.fetchPropertyResponse(1);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initData());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.of(context);
  }

  Future<void> _initData() async {
    try {
      final props = await _propertyFuture;
      if (!mounted) return;
      if (props.properties.isNotEmpty) {
        setState(() => _selectedPropertyId = props.properties.first.id);
        await _fetchDocuments();
      }
    } catch (e) {
      debugPrint('Error loading properties: $e');
    }
  }

  Future<void> _fetchDocuments() async {
    if (_selectedPropertyId == -1) return;

    if (mounted) setState(() => _loading = true);

    try {
      final docs = await documentService.fetchDocuments(
        propertyId: _selectedPropertyId,
        category: null,
        search: null,
      );
      if (!mounted) return;
      setState(() => _allDocuments = docs);
      _applyFiltersAndSort();
    } catch (e) {
      debugPrint('Error fetching documents: $e');
      if (mounted) {
        _showSnackBar('Failed to load documents',
            backgroundColor: Colors.red);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFiltersAndSort() {
    List<Document> filtered = List<Document>.from(_allDocuments);

    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      filtered = filtered.where((doc) {
        return doc.name.toLowerCase().contains(query) ||
            _extractTenantName(doc.filePath)
                .toLowerCase()
                .contains(query) ||
            doc.category.toLowerCase().contains(query);
      }).toList();
    }

    if (_selectedCategory != null) {
      filtered = filtered
          .where((doc) => doc.category == _selectedCategory!.name)
          .toList();
    }

    if (_dateFilter == 'Monthly' && _selectedMonth != null) {
      filtered = filtered.where((doc) {
        final d = DateTime.tryParse(doc.createdAt.toString());
        return d != null && d.month == _selectedMonth;
      }).toList();
    }

    if (_dateFilter == 'Yearly' && _selectedYear != null) {
      filtered = filtered.where((doc) {
        final d = DateTime.tryParse(doc.createdAt.toString());
        return d != null && d.year == _selectedYear;
      }).toList();
    }

    switch (_sortOption) {
      case 'Newest':
        filtered.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
        break;
      case 'Oldest':
        filtered.sort((a, b) => a.createdAt!.compareTo(b.createdAt!));
        break;
      case 'Name':
        filtered.sort((a, b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
    }

    if (mounted) setState(() => _filteredDocuments = filtered);
  }

  void _clearFilters() {
    setState(() {
      _selectedCategory = null;
      _searchQuery = '';
      _dateFilter = 'All Time';
      _selectedMonth = null;
      _selectedYear = null;
      _sortOption = 'Newest';
    });
    _applyFiltersAndSort();
  }

  int get _activeFilterCount {
    int count = 0;
    if (_selectedCategory != null) count++;
    if (_searchQuery.trim().isNotEmpty) count++;
    if (_dateFilter != 'All Time') count++;
    return count;
  }

  String _extractTenantName(String filePath) {
    try {
      final parts = filePath.split('/');
      if (parts.length >= 4) {
        // ✅ Apply title-case conversion and hyphen cleanup
        return _formatName(parts[3]);
      }
    } catch (_) {}
    return '';
  }

  /// Formats a name by:
  ///   1. Replacing hyphens/underscores with spaces
  ///   2. Collapsing multiple spaces
  ///   3. Applying title case (first letter uppercase, rest lowercase)
  ///   4. Preserving all-caps words (e.g. acronyms like "MUCKENE")
  ///   5. Capitalizing the letter after an apostrophe (O'Brien, D'Angelo)
  ///
  /// Examples:
  ///   "zack-muchene"  → "Zack Muchene"
  ///   "zack_muchene"  → "Zack Muchene"
  ///   "john-o'brien"  → "John O'Brien"
  ///   "MARY-JANE"     → "Mary Jane"
  ///   "de-la-cruz"    → "De La Cruz"
  String _formatName(String input) {
    if (input.trim().isEmpty) return input;

    // Replace hyphens and underscores with spaces
    String cleaned = input
        .replaceAll('-', ' ')
        .replaceAll('_', ' ')
        .trim();

    // Collapse multiple spaces into one
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');

    // Title-case each word
    return cleaned
        .split(' ')
        .map((word) {
      if (word.isEmpty) return word;

      // Preserve all-caps acronyms (MUCKENE, KRA, etc.)
      if (word == word.toUpperCase() && word.length > 1) return word;

      // Capitalize first letter, lowercase rest
      String w = word[0].toUpperCase() + word.substring(1).toLowerCase();

      // Capitalize letter after apostrophe (O'Brien, D'Angelo)
      w = w.replaceAllMapped(
        RegExp(r"'(\w)"),
            (m) => "'${m[1]!.toUpperCase()}",
      );

      return w;
    })
        .join(' ');
  }

  String _toTitleCase(String input) {
    if (input.trim().isEmpty) return input;

    return input
        .split(' ')
        .map((word) {
      if (word.isEmpty) return word;
      if (word == word.toUpperCase() && word.length > 1) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    })
        .join(' ');
  }

  int _getCategoryCount(DocumentCategory category) {
    return _allDocuments
        .where((document) => document.category == category.name)
        .length;
  }

  String _getMonthName(int month) =>
      DateFormat.MMMM().format(DateTime(2024, month));

  List<int> _getAvailableYears() {
    final years = <int>{};
    for (final d in _allDocuments) {
      final date = DateTime.tryParse(d.createdAt.toString());
      if (date != null) years.add(date.year);
    }
    final r = years.toList();
    r.sort((a, b) => b.compareTo(a));
    return r;
  }

  void _showSnackBar(String message, {Color backgroundColor = Colors.blue}) {
    if (!mounted) return;
    final messenger = _messenger;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 12)),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ));
  }

  // ============================================================
  // RESPONSIVE GRID CONFIG
  // ============================================================

  int _getCrossAxisCount(double width) {
    if (width > 1600) return 6;
    if (width > 1300) return 5;
    if (width > 1050) return 4;
    if (width > 750) return 3;
    if (width > 500) return 2;
    return 2;
  }

  double _getChildAspectRatio(double width) {
    if (width > 1600) return 1.55;
    if (width > 1300) return 1.50;
    if (width > 1050) return 1.45;
    if (width > 850) return 1.35;
    if (width > 600) return 1.25;
    if (width > 400) return 1.10;
    return 1.00;
  }

  double _getGridSpacing(double width) {
    if (width > 1300) return 16;
    if (width > 600) return 14;
    return 10;
  }

  // ============================================================
  // BUILD — fully scrollable
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: Stack(
        children: [
          FutureBuilder<PropertyResponse>(
            future: _propertyFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                // ✅ Full-page animated loader
                return const _DocumentsLoader();
              }

              final hasError = snapshot.hasError;
              final noProperty =
                  !snapshot.hasData || snapshot.data!.properties.isEmpty;

              final properties =
                  snapshot.data?.properties ?? const <dynamic>[];

              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        _pagePadding,
                        _isMobile ? 12 : 20,
                        _pagePadding,
                        0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildHeader(),

                          if (!hasError && !noProperty) ...[
                            SizedBox(height: _isMobile ? 12 : 16),
                            _buildFilterToggleBar(),
                            if (_showFilters) ...[
                              SizedBox(height: _isMobile ? 10 : 12),
                              _buildFilterPanel(properties),
                            ],
                            SizedBox(height: _isMobile ? 10 : 14),
                            _buildSummaryRow(),
                            SizedBox(height: _isMobile ? 10 : 14),
                          ] else ...[
                            SizedBox(height: _isMobile ? 20 : 28),
                          ],
                        ],
                      ),
                    ),
                  ),

                  if (hasError)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding:
                        EdgeInsets.symmetric(horizontal: _pagePadding),
                        child:
                        _buildErrorState(snapshot.error.toString()),
                      ),
                    )
                  else if (noProperty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding:
                        EdgeInsets.symmetric(horizontal: _pagePadding),
                        child: _buildNoPropertyState(),
                      ),
                    )
                  else if (_loading)
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          _pagePadding,
                          0,
                          _pagePadding,
                          _isMobile ? 16 : 24,
                        ),
                        sliver: _buildLoadingSliver(),
                      )
                    else if (_filteredDocuments.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Padding(
                            padding:
                            EdgeInsets.symmetric(horizontal: _pagePadding),
                            child: _buildEmptyState(),
                          ),
                        )
                      else
                        _buildDocumentsGrid(),
                ],
              );
            },
          ),
          if (_loadingDialog) _buildDialogLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildDocumentsGrid() {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = _getCrossAxisCount(width);
    final aspectRatio = _getChildAspectRatio(width);
    final spacing = _getGridSpacing(width);

    final availableWidth = width - (_pagePadding * 2);
    final cardWidth =
        (availableWidth - (spacing * (crossAxisCount - 1))) / crossAxisCount;

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        _pagePadding,
        0,
        _pagePadding,
        _isMobile ? 16 : 24,
      ),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          childAspectRatio: aspectRatio,
        ),
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            final document = _filteredDocuments[index];
            return _DocumentCard(
              document: document,
              tenantName: _extractTenantName(document.filePath),
              onDelete: () => _confirmDelete(document),
              cardWidth: cardWidth,
            );
          },
          childCount: _filteredDocuments.length,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Filter toggle bar
  // ─────────────────────────────────────────────────────────────
  Widget _buildFilterToggleBar() {
    final hasActive = _activeFilterCount > 0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _isMobile ? 12 : 14,
        vertical: _isMobile ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECF2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() => _showFilters = !_showFilters);
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: _isMobile ? 10 : 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _showFilters
                      ? Palette.nestBlue.withValues(alpha: 0.10)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 17,
                      color: _showFilters
                          ? Palette.nestBlue
                          : const Color(0xFF475569),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: _isMobile ? 11 : 12,
                        fontWeight: FontWeight.w700,
                        color: _showFilters
                            ? Palette.nestBlue
                            : const Color(0xFF334155),
                      ),
                    ),
                    if (hasActive) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Palette.nestBlue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$_activeFilterCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 5),
                    Icon(
                      _showFilters
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: _showFilters
                          ? Palette.nestBlue
                          : const Color(0xFF64748B),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  if (_searchQuery.trim().isNotEmpty)
                    _buildActiveChip(
                      icon: Icons.search_rounded,
                      label: '"$_searchQuery"',
                      onClear: () {
                        setState(() => _searchQuery = '');
                        _applyFiltersAndSort();
                      },
                    ),
                  if (_selectedCategory != null)
                    _buildActiveChip(
                      icon: Icons.category_outlined,
                      label: _selectedCategory!.displayName,
                      onClear: () {
                        setState(() => _selectedCategory = null);
                        _applyFiltersAndSort();
                      },
                    ),
                  if (_dateFilter != 'All Time')
                    _buildActiveChip(
                      icon: Icons.calendar_month_outlined,
                      label: _dateFilter == 'Monthly'
                          ? (_selectedMonth != null
                          ? _getMonthName(_selectedMonth!)
                          : 'Monthly')
                          : (_selectedYear?.toString() ?? 'Yearly'),
                      onClear: () {
                        setState(() {
                          _dateFilter = 'All Time';
                          _selectedMonth = null;
                          _selectedYear = null;
                        });
                        _applyFiltersAndSort();
                      },
                    ),
                  if (_sortOption != 'Newest')
                    _buildActiveChip(
                      icon: Icons.sort_rounded,
                      label: 'Sort: $_sortOption',
                      onClear: () {
                        setState(() => _sortOption = 'Newest');
                        _applyFiltersAndSort();
                      },
                    ),
                  if (!hasActive)
                    Text(
                      '${_filteredDocuments.length} of ${_allDocuments.length} shown',
                      style: TextStyle(
                        fontSize: _isMobile ? 10.5 : 11,
                        color: const Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ),

          if (hasActive)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _clearFilters,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.clear_all_rounded,
                      size: 17,
                      color: Colors.red,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveChip({
    required IconData icon,
    required String label,
    required VoidCallback onClear,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Container(
        padding: const EdgeInsets.only(left: 8, right: 4, top: 5, bottom: 5),
        decoration: BoxDecoration(
          color: Palette.nestBlue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Palette.nestBlue.withValues(alpha: 0.20),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: Palette.nestBlue),
            const SizedBox(width: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 110),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Palette.nestBlue,
                ),
              ),
            ),
            const SizedBox(width: 2),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onClear,
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(
                    Icons.close_rounded,
                    size: 13,
                    color: Palette.nestBlue,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogLoadingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.35),
        child: Center(
          child: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 42,
                  height: 42,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor:
                    AlwaysStoppedAnimation<Color>(Palette.nestBlue),
                    backgroundColor:
                    Palette.nestBlue.withValues(alpha: 0.12),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Preparing upload...',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF344054))),
                const SizedBox(height: 4),
                const Text('Loading tenants and property details',
                    style: TextStyle(
                        fontSize: 10, color: Color(0xFF667085))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: _isMobile ? 38 : 42,
          height: _isMobile ? 38 : 42,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Palette.nestBlue,
              Palette.nestBlue.withValues(alpha: 0.7),
            ]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.folder_copy_outlined,
            color: Colors.white,
            size: _isMobile ? 20 : 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Documents',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: _isMobile ? 16 : 18,
                      fontWeight: FontWeight.w700,
                      fontFamily: "SF-Pro-Text-Bold",
                      color: const Color(0xFF1F2937))),
              const SizedBox(height: 3),
              Text(
                _isMobile
                    ? 'Manage your documents'
                    : 'Manage and organize your property documents',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: _isMobile ? 10.5 : 11,
                  color: const Color(0xFF667085),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        if (_isMobile)
          ElevatedButton(
            onPressed: _uploading ? null : _showUploadDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Palette.nestBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.all(10),
              minimumSize: const Size(42, 42),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9)),
            ),
            child: const Icon(Icons.cloud_upload_outlined, size: 19),
          )
        else
          ElevatedButton.icon(
            onPressed: _uploading ? null : _showUploadDialog,
            icon: const Icon(Icons.cloud_upload_outlined, size: 17),
            label: const Text('Upload Document',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Palette.nestBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9)),
            ),
          ),

        const SizedBox(width: 8),

        IconButton(
          tooltip: 'Refresh',
          onPressed: _loading ? null : _fetchDocuments,
          icon: const Icon(Icons.refresh_rounded, size: 21),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Palette.nestBlue,
            side: BorderSide(color: Colors.grey.shade200),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPanel(List<dynamic> properties) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(_isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8ECF2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded,
                  size: 14, color: Palette.nestBlue),
              const SizedBox(width: 6),
              const Text('Refine results',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF344054))),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() => _showFilters = false);
                },
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.close_rounded,
                      size: 16, color: Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _buildFilterFields(properties),

          if (_dateFilter == 'Monthly' || _dateFilter == 'Yearly') ...[
            const SizedBox(height: 12),
            _buildDateSelection(),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterFields(List<dynamic> properties) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    if (!isWide) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSearchField(),
          const SizedBox(height: 10),
          _buildPropertyDropdown(properties),
          const SizedBox(height: 10),
          _buildCategoryDropdown(),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildDateFilter()),
              const SizedBox(width: 10),
              Expanded(child: _buildSortDropdown()),
            ],
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(flex: 3, child: _buildSearchField()),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: _buildPropertyDropdown(properties)),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: _buildCategoryDropdown()),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: _buildDateFilter()),
        const SizedBox(width: 10),
        SizedBox(
          width: 120,
          height: 44,
          child: _buildSortDropdown(),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      style: const TextStyle(fontSize: 11),
      decoration: InputDecoration(
        hintText: 'Search tenants',
        hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF98A2B3)),
        prefixIcon: const Icon(Icons.search_rounded,
            size: 19, color: Color(0xFF667085)),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
          icon: const Icon(Icons.close, size: 17),
          onPressed: () {
            setState(() => _searchQuery = '');
            _applyFiltersAndSort();
          },
        )
            : null,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: Palette.nestBlue),
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      onChanged: (value) {
        setState(() => _searchQuery = value);
        _applyFiltersAndSort();
      },
    );
  }

  Widget _buildPropertyDropdown(List<dynamic> properties) {
    return DropdownButtonFormField<int>(
      initialValue: _selectedPropertyId == -1 ? null : _selectedPropertyId,
      decoration: _dropdownDecoration('Property', Icons.apartment_outlined),
      style: const TextStyle(fontSize: 11, color: Color(0xFF344054)),
      isExpanded: true,
      items: properties.map<DropdownMenuItem<int>>((property) {
        return DropdownMenuItem<int>(
          value: property.id,
          child: Text(property.name, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: (value) async {
        if (value == null) return;
        setState(() {
          _selectedPropertyId = value;
          _selectedCategory = null;
          _searchQuery = '';
          _dateFilter = 'All Time';
          _selectedMonth = null;
          _selectedYear = null;
        });
        await _fetchDocuments();
      },
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<DocumentCategory>(
      initialValue: _selectedCategory,
      decoration:
      _dropdownDecoration('Document Type', Icons.category_outlined),
      style: const TextStyle(fontSize: 11, color: Color(0xFF344054)),
      isExpanded: true,
      hint: const Text('All Types', style: TextStyle(fontSize: 11)),
      items: DocumentCategory.values.map((category) {
        final count = _getCategoryCount(category);
        return DropdownMenuItem<DocumentCategory>(
          value: category,
          child: Row(children: [
            Expanded(
                child: Text(category.displayName,
                    overflow: TextOverflow.ellipsis)),
            Text('$count',
                style: const TextStyle(fontSize: 9, color: Colors.grey)),
          ]),
        );
      }).toList(),
      onChanged: (value) {
        setState(() => _selectedCategory = value);
        _applyFiltersAndSort();
      },
    );
  }

  Widget _buildDateFilter() {
    return DropdownButtonFormField<String>(
      initialValue: _dateFilter,
      decoration:
      _dropdownDecoration('Period', Icons.calendar_month_outlined),
      style: const TextStyle(fontSize: 11, color: Color(0xFF344054)),
      isExpanded: true,
      items: const [
        DropdownMenuItem(
            value: 'All Time',
            child: Text('All Time', style: TextStyle(fontSize: 11))),
        DropdownMenuItem(
            value: 'Monthly',
            child: Text('Monthly', style: TextStyle(fontSize: 11))),
        DropdownMenuItem(
            value: 'Yearly',
            child: Text('Yearly', style: TextStyle(fontSize: 11))),
      ],
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          _dateFilter = value;
          if (value == 'Monthly') {
            _selectedMonth ??= DateTime.now().month;
            _selectedYear = null;
          } else if (value == 'Yearly') {
            final years = _getAvailableYears();
            _selectedYear ??=
            years.isNotEmpty ? years.first : DateTime.now().year;
            _selectedMonth = null;
          } else {
            _selectedMonth = null;
            _selectedYear = null;
          }
        });
        _applyFiltersAndSort();
      },
    );
  }

  Widget _buildDateSelection() {
    if (_dateFilter == 'Monthly') {
      return Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Palette.nestBlue.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Icon(Icons.calendar_month, size: 15, color: Palette.nestBlue),
            const SizedBox(width: 7),
            const Text('Month:',
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 150,
          child: DropdownButtonFormField<int>(
            initialValue: _selectedMonth,
            decoration: _smallDropdownDecoration(),
            style: const TextStyle(fontSize: 11, color: Color(0xFF344054)),
            items: List.generate(12, (i) {
              final m = i + 1;
              return DropdownMenuItem<int>(
                value: m,
                child: Text(_getMonthName(m),
                    style: const TextStyle(fontSize: 11)),
              );
            }),
            onChanged: (v) {
              setState(() => _selectedMonth = v);
              _applyFiltersAndSort();
            },
          ),
        ),
      ]);
    }

    if (_dateFilter == 'Yearly') {
      final years = _getAvailableYears();
      return Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Palette.nestBlue.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Icon(Icons.date_range, size: 15, color: Palette.nestBlue),
            const SizedBox(width: 7),
            const Text('Year:',
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 130,
          child: DropdownButtonFormField<int>(
            initialValue: _selectedYear,
            decoration: _smallDropdownDecoration(),
            style: const TextStyle(fontSize: 11, color: Color(0xFF344054)),
            items: years
                .map((y) => DropdownMenuItem<int>(
                value: y,
                child: Text(y.toString(),
                    style: const TextStyle(fontSize: 11))))
                .toList(),
            onChanged: (v) {
              setState(() => _selectedYear = v);
              _applyFiltersAndSort();
            },
          ),
        ),
      ]);
    }
    return const SizedBox.shrink();
  }

  Widget _buildSortDropdown() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButton<String>(
        value: _sortOption,
        isExpanded: true,
        underline: const SizedBox(),
        icon: const Icon(Icons.keyboard_arrow_down, size: 17),
        items: const [
          DropdownMenuItem(
              value: 'Newest',
              child: Text('Newest', style: TextStyle(fontSize: 10))),
          DropdownMenuItem(
              value: 'Oldest',
              child: Text('Oldest', style: TextStyle(fontSize: 10))),
          DropdownMenuItem(
              value: 'Name',
              child: Text('Name', style: TextStyle(fontSize: 10))),
        ],
        onChanged: (v) {
          if (v == null) return;
          setState(() => _sortOption = v);
          _applyFiltersAndSort();
        },
      ),
    );
  }

  InputDecoration _dropdownDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 10, color: Color(0xFF667085)),
      prefixIcon: Icon(icon, size: 17, color: const Color(0xFF667085)),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide(color: Palette.nestBlue),
      ),
    );
  }

  InputDecoration _smallDropdownDecoration() {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
    );
  }

  Widget _buildSummaryRow() {
    if (_isMobile) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSummaryCard(
            title: 'Total Documents',
            value: _allDocuments.length.toString(),
            icon: Icons.folder_outlined,
            color: Palette.nestBlue,
            fullWidth: true,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  title: 'Showing',
                  value: _filteredDocuments.length.toString(),
                  icon: Icons.filter_list_rounded,
                  color: Colors.orange.shade700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryCard(
                  title: 'Categories',
                  value: DocumentCategory.values
                      .where((c) =>
                      _allDocuments.any((d) => d.category == c.name))
                      .length
                      .toString(),
                  icon: Icons.category_outlined,
                  color: Colors.purple.shade600,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Row(children: [
      _buildSummaryCard(
        title: 'Total Documents',
        value: _allDocuments.length.toString(),
        icon: Icons.folder_outlined,
        color: Palette.nestBlue,
      ),
      const SizedBox(width: 10),
      _buildSummaryCard(
        title: 'Showing',
        value: _filteredDocuments.length.toString(),
        icon: Icons.filter_list_rounded,
        color: Colors.orange.shade700,
      ),
      const SizedBox(width: 10),
      _buildSummaryCard(
        title: 'Categories',
        value: DocumentCategory.values
            .where((c) => _allDocuments.any((d) => d.category == c.name))
            .length
            .toString(),
        icon: Icons.category_outlined,
        color: Colors.purple.shade600,
      ),
    ]);
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    bool fullWidth = false,
  }) {
    final card = Container(
      padding: EdgeInsets.symmetric(
        horizontal: _isMobile ? 12 : 14,
        vertical: _isMobile ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8ECF2)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 9, color: Color(0xFF667085))),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937))),
            ],
          ),
        ),
      ]),
    );

    if (fullWidth) {
      return SizedBox(width: double.infinity, child: card);
    }
    return _isMobile ? card : Expanded(child: card);
  }

  Widget _buildLoadingSliver() {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = _getCrossAxisCount(width);
    final aspectRatio = _getChildAspectRatio(width);
    final spacing = _getGridSpacing(width);

    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: aspectRatio,
      ),
      delegate: SliverChildBuilderDelegate(
            (_, __) => Container(
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(14)),
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            ),
          ),
        ),
        childCount: crossAxisCount * 2,
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline,
                    size: 36, color: Colors.red),
              ),
              const SizedBox(height: 15),
              const Text('Unable to load documents',
                  textAlign: TextAlign.center,
                  style:
                  TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 7),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(error,
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style:
                    const TextStyle(fontSize: 11, color: Colors.grey)),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _fetchDocuments,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Try Again',
                    style: TextStyle(fontSize: 11)),
              ),
            ]),
      ),
    );
  }

  Widget _buildNoPropertyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.apartment_outlined,
                size: 65, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            const Text('No properties found',
                textAlign: TextAlign.center,
                style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Add a property before managing documents.',
                textAlign: TextAlign.center,
                style:
                TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasFilters = _activeFilterCount > 0;
    return Center(
      child: Container(
        padding: EdgeInsets.all(_isMobile ? 22 : 30),
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Palette.nestBlue.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasFilters
                    ? Icons.filter_alt_off_outlined
                    : Icons.folder_open_outlined,
                size: 38,
                color: Palette.nestBlue,
              ),
            ),
            const SizedBox(height: 18),
            Text(hasFilters ? 'No matching documents' : 'No documents yet',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF344054))),
            const SizedBox(height: 7),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                  hasFilters
                      ? 'Try changing your filters or search criteria.'
                      : 'Upload your first document to get started.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF667085))),
            ),
            const SizedBox(height: 18),
            if (hasFilters)
              OutlinedButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('Clear Filters',
                    style: TextStyle(fontSize: 11)),
              )
            else
              ElevatedButton.icon(
                onPressed: _showUploadDialog,
                icon: const Icon(Icons.upload_file, size: 16),
                label: const Text('Upload Document',
                    style: TextStyle(fontSize: 11)),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Document document) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Delete Document',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "${document.name}"? '
                'This action cannot be undone.',
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 11),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'Delete',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    try {
      debugPrint('🗑️ Starting delete for document ID: ${document.id}');

      await documentService.deleteDocument(
        document.id.toString(),
      );

      if (!mounted) return;

      await _fetchDocuments();

      if (!mounted) return;

      _showSnackBar(
        'Document deleted successfully',
        backgroundColor: Colors.green,
      );
    } catch (e) {
      if (!mounted) return;

      debugPrint('❌ Delete failed from DocumentsPage: $e');

      _showSnackBar(
        'Delete failed: $e',
        backgroundColor: Colors.red,
      );
    }
  }

  Future<void> _showUploadDialog() async {
    if (_selectedPropertyId == -1) {
      _showSnackBar('Please select a property first',
          backgroundColor: Colors.orange);
      return;
    }

    setState(() => _loadingDialog = true);

    DocumentCategory? category;
    Uint8List? fileBytes;
    String? fileName;
    NewTenant? selectedTenant;
    List<NewTenant> tenants = [];
    String propertyName = '';

    try {
      final props = await _propertyFuture;
      final prop =
      props.properties.firstWhere((p) => p.id == _selectedPropertyId);
      propertyName = prop.name;
    } catch (_) {}

    try {
      tenants = await apiService.fetchTenantsByProperty(_selectedPropertyId);
    } catch (e) {
      debugPrint('Unable to load tenants: $e');
      tenants = [];
    }

    if (!mounted) return;
    setState(() => _loadingDialog = false);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              actionsPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              title: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Palette.nestBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(Icons.cloud_upload_outlined,
                      color: Palette.nestBlue, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Upload Document',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ]),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        initialValue: propertyName,
                        enabled: false,
                        style: const TextStyle(fontSize: 11),
                        decoration: InputDecoration(
                          labelText: 'Property',
                          labelStyle: const TextStyle(fontSize: 11),
                          prefixIcon: const Icon(Icons.apartment_outlined,
                              size: 18),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<NewTenant>(
                        initialValue: selectedTenant,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Tenant *',
                          labelStyle: const TextStyle(fontSize: 11),
                          prefixIcon: const Icon(Icons.person_outline,
                              size: 18),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        hint: Text(
                            tenants.isEmpty
                                ? 'No tenants found'
                                : 'Select tenant',
                            style: const TextStyle(fontSize: 11)),
                        items: tenants
                            .map((t) => DropdownMenuItem<NewTenant>(
                          value: t,
                          child: Text(_formatName(t.name),
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis),
                        ))
                            .toList(),
                        onChanged: tenants.isEmpty
                            ? null
                            : (v) =>
                            setStateDialog(() => selectedTenant = v),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<DocumentCategory>(
                        initialValue: category,
                        decoration: InputDecoration(
                          labelText: 'Category *',
                          labelStyle: const TextStyle(fontSize: 11),
                          prefixIcon: const Icon(Icons.category_outlined,
                              size: 18),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        hint: const Text('Select category',
                            style: TextStyle(fontSize: 11)),
                        items: DocumentCategory.values
                            .map((v) => DropdownMenuItem<DocumentCategory>(
                          value: v,
                          child: Text(v.displayName,
                              style:
                              const TextStyle(fontSize: 11)),
                        ))
                            .toList(),
                        onChanged: (v) =>
                            setStateDialog(() => category = v),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () async {
                          final result =
                          await FilePicker.platform.pickFiles(
                            allowMultiple: false,
                            withData: true,
                            type: FileType.any,
                          );
                          if (result != null && result.files.isNotEmpty) {
                            final file = result.files.single;
                            setStateDialog(() {
                              fileBytes = file.bytes;
                              fileName = file.name;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: fileName != null
                                ? Colors.green.withValues(alpha: 0.04)
                                : const Color(0xFFF9FAFB),
                            border: Border.all(
                                color: fileName != null
                                    ? Colors.green.withValues(alpha: 0.4)
                                    : Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: fileName != null
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : Colors.grey.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                  fileName != null
                                      ? Icons.insert_drive_file
                                      : Icons.upload_file,
                                  size: 20,
                                  color: fileName != null
                                      ? Colors.green
                                      : Colors.grey),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(fileName ?? 'Select document',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: fileName != null
                                              ? Colors.black87
                                              : Colors.grey.shade700),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 3),
                                  Text(
                                      fileName != null
                                          ? 'File selected'
                                          : 'Maximum file size: 10 MB',
                                      style: const TextStyle(
                                          fontSize: 9, color: Colors.grey)),
                                ],
                              ),
                            ),
                            if (fileName != null)
                              IconButton(
                                tooltip: 'Remove file',
                                icon: const Icon(Icons.close, size: 17),
                                onPressed: () => setStateDialog(() {
                                  fileBytes = null;
                                  fileName = null;
                                }),
                              ),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('* Required fields',
                          style:
                          TextStyle(fontSize: 9, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel',
                      style: TextStyle(fontSize: 11)),
                ),
                ElevatedButton.icon(
                  onPressed: (category != null &&
                      fileBytes != null &&
                      fileName != null &&
                      selectedTenant != null &&
                      !_uploading)
                      ? () async {
                    setState(() => _uploading = true);
                    try {
                      await documentService.uploadDocument(
                        propertyId: _selectedPropertyId,
                        tenantId: selectedTenant!.id,
                        name: selectedTenant!.name,
                        category: category!.name,
                        bytes: fileBytes!,
                        fileName: fileName!,
                      );
                      if (!mounted) return;
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                      await _fetchDocuments();
                      _showSnackBar(
                          'Document uploaded successfully',
                          backgroundColor: Colors.green);
                    } catch (e) {
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                      _showSnackBar('Upload failed: $e',
                          backgroundColor: Colors.red);
                    } finally {
                      if (mounted) setState(() => _uploading = false);
                    }
                  }
                      : null,
                  icon: _uploading
                      ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5, color: Colors.white))
                      : const Icon(Icons.cloud_upload_outlined, size: 16),
                  label: Text(_uploading ? 'Uploading...' : 'Upload',
                      style: const TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Palette.nestBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ==================================================================
// DOCUMENT CARD — compact, content-hugging info, no overflow
// ==================================================================

class _DocumentCard extends StatelessWidget {
  final Document document;
  final String tenantName;
  final VoidCallback onDelete;

  /// Width of the card in logical pixels, passed from the grid builder.
  final double cardWidth;

  const _DocumentCard({
    required this.document,
    required this.tenantName,
    required this.onDelete,
    required this.cardWidth,
  });

  // ─────────────────────────────────────────────────────────────
  // Size tiers driven by the card's own width
  // ─────────────────────────────────────────────────────────────

  bool get _isSmall => cardWidth < 180;
  bool get _isMedium => cardWidth >= 180 && cardWidth < 240;
  bool get _isLarge => cardWidth >= 240;

  // ─────────────────────────────────────────────────────────────
  // Responsive metrics
  // ─────────────────────────────────────────────────────────────

  double get _infoPadding {
    if (_isSmall) return 8;
    if (_isMedium) return 10;
    return 12;
  }

  double get _fallbackIconSize {
    if (_isSmall) return 38;
    if (_isMedium) return 46;
    return 54;
  }

  double get _fallbackIconInner {
    if (_isSmall) return 18;
    if (_isMedium) return 22;
    return 28;
  }

  double get _titleFontSize {
    if (_isSmall) return 10.5;
    if (_isMedium) return 11.5;
    return 12.5;
  }

  double get _tenantFontSize {
    if (_isSmall) return 8.5;
    if (_isMedium) return 9;
    return 9.5;
  }

  double get _dateFontSize {
    if (_isSmall) return 8;
    if (_isMedium) return 8.5;
    return 9;
  }

  double get _deleteIconSize {
    if (_isSmall) return 14;
    if (_isMedium) return 15;
    return 16;
  }

  double get _badgeFontSize {
    if (_isSmall) return 7;
    if (_isMedium) return 7.5;
    return 8;
  }

  double get _openBtnIconSize {
    if (_isSmall) return 12;
    if (_isMedium) return 13;
    return 14;
  }

  double get _openBtnPadding {
    if (_isSmall) return 5;
    if (_isMedium) return 6;
    return 6;
  }

  double get _radius {
    if (_isSmall) return 11;
    if (_isMedium) return 12;
    return 14;
  }

  // ─────────────────────────────────────────────────────────────
  // Format detection
  // ─────────────────────────────────────────────────────────────

  bool get _isImage {
    final cat = document.category.toLowerCase();
    if (cat == 'photo' || cat == 'image' || cat == 'picture') return true;

    final path = document.filePath.toLowerCase();
    return path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.gif') ||
        path.endsWith('.webp') ||
        path.endsWith('.bmp') ||
        path.endsWith('.jfif');
  }

  bool get _isPdf =>
      document.category.toLowerCase() == 'pdf' ||
          document.filePath.toLowerCase().endsWith('.pdf');

  String get _displayTitle {
    final cat = document.category.toLowerCase();
    final isInvoiceOrReceipt = cat == 'invoice' || cat == 'receipt';

    if (isInvoiceOrReceipt) {
      return _titleCase(document.name);
    }

    for (final c in DocumentCategory.values) {
      if (c.name.toLowerCase() == cat) return c.displayName;
    }

    if (cat.isEmpty) return _titleCase(document.name);
    return cat[0].toUpperCase() + cat.substring(1);
  }

  String _titleCase(String input) {
    if (input.trim().isEmpty) return input;

    final parts = input.split('_');
    if (parts.length >= 3) {
      input = '${parts[0]}_${parts[1]}';
    }

    String cleaned = input
        .replaceAll('-', ' ')
        .replaceAll('_', ' ')
        .trim();

    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');

    return cleaned
        .split(' ')
        .map((word) {
      if (word.isEmpty) return word;
      if (word == word.toUpperCase() && word.length > 1) return word;

      String w = word[0].toUpperCase() + word.substring(1).toLowerCase();
      w = w.replaceAllMapped(
        RegExp(r"'(\w)"),
            (m) => "'${m[1]!.toUpperCase()}",
      );
      return w;
    })
        .join(' ');
  }

  String get _safeUrl => Uri.encodeFull(document.url);

  Future<void> _openViewer(BuildContext context) async {
    try {
      final uri = Uri.parse(_safeUrl);
      final launched =
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Unable to open document'),
            backgroundColor: Colors.red));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Cannot open document: $e'),
            backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = document.createdAt;
    final formattedDate =
    date != null ? DateFormat('dd MMM yyyy').format(date) : 'Unknown date';
    final categoryColor = _getCategoryColor(document.category);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radius),
        side: const BorderSide(color: Color(0xFFE8ECF2)),
      ),
      child: InkWell(
        onTap: () => _openViewer(context),
        borderRadius: BorderRadius.circular(_radius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─────────────────────────────────────────
            // PREVIEW AREA — expands to fill remaining space
            // ─────────────────────────────────────────
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(_radius)),
                child: Container(
                  width: double.infinity,
                  color: const Color(0xFFF8FAFC),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_isImage)
                        Image.network(
                          _safeUrl,
                          fit: BoxFit.cover,
                          webHtmlElementStrategy:
                          WebHtmlElementStrategy.fallback,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => Center(
                            child: Container(
                              width: _fallbackIconSize,
                              height: _fallbackIconSize,
                              decoration: BoxDecoration(
                                color: categoryColor
                                    .withValues(alpha: 0.08),
                                borderRadius:
                                BorderRadius.circular(_radius),
                              ),
                              child: Icon(Icons.broken_image_outlined,
                                  size: _fallbackIconInner,
                                  color: categoryColor),
                            ),
                          ),
                        )
                      else
                        Center(
                          child: Container(
                            width: _fallbackIconSize,
                            height: _fallbackIconSize,
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(_radius),
                            ),
                            child: Icon(
                              _isPdf
                                  ? Icons.picture_as_pdf
                                  : Icons.insert_drive_file,
                              size: _fallbackIconInner,
                              color: categoryColor,
                            ),
                          ),
                        ),

                      // Category badge (top-left)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: _isSmall ? 5 : 6,
                            vertical: _isSmall ? 3 : 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(6),
                            border:
                            Border.all(color: Colors.grey.shade200),
                          ),
                          child: Text(
                            document.category.toUpperCase(),
                            style: TextStyle(
                              fontSize: _badgeFontSize,
                              fontWeight: FontWeight.w700,
                              color: categoryColor,
                            ),
                          ),
                        ),
                      ),

                      // Open-in-new button (top-right)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton(
                          tooltip: 'Open document',
                          onPressed: () => _openViewer(context),
                          icon: Icon(Icons.open_in_new,
                              size: _openBtnIconSize),
                          style: IconButton.styleFrom(
                            backgroundColor:
                            Colors.white.withValues(alpha: 0.92),
                            foregroundColor: Palette.nestBlue,
                            padding: EdgeInsets.all(_openBtnPadding),
                            minimumSize: Size.zero,
                            tapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ─────────────────────────────────────────
            // INFO AREA — hugs its content, NO flex, NO Spacer
            // ─────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                _infoPadding,
                _infoPadding - 2,
                _infoPadding,
                _infoPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Text(
                    _displayTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: _titleFontSize,
                      height: 1.15,
                      color: const Color(0xFF1F2937),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Tenant name
                  if (tenantName.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: _isSmall ? 10 : 11,
                          color: const Color(0xFF98A2B3),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            tenantName,
                            style: TextStyle(
                              fontSize: _tenantFontSize,
                              height: 1.1,
                              color: const Color(0xFF667085),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Date + Delete row
                  SizedBox(height: _isSmall ? 4 : 6),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: _isSmall ? 9 : 10,
                        color: const Color(0xFF98A2B3),
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          formattedDate,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: _dateFontSize,
                            height: 1.1,
                            color: const Color(0xFF98A2B3),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: onDelete,
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: EdgeInsets.all(_isSmall ? 2 : 3),
                          child: Icon(
                            Icons.delete_outline,
                            size: _deleteIconSize,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'lease':
      case 'lease_agreement':
        return Colors.blue;
      case 'invoice':
        return Colors.orange;
      case 'receipt':
        return Colors.green;
      case 'identification':
      case 'id':
        return Colors.purple;
      case 'maintenance':
        return Colors.red;
      case 'photo':
        return Colors.teal;
      default:
        return Colors.blueGrey;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// Animated full-page loading screen for DocumentsPage.
// Uses a folder/document theme with orbiting rings, a breathing
// core icon, cycling status messages, and a progress bar.
// ═══════════════════════════════════════════════════════════════
class _DocumentsLoader extends StatefulWidget {
  const _DocumentsLoader({
    this.messages = const [
      'Loading your documents...',
      'Fetching folders...',
      'Preparing previews...',
      'Almost ready...',
    ],
  });

  final List<String> messages;

  @override
  State<_DocumentsLoader> createState() => _DocumentsLoaderState();
}

class _DocumentsLoaderState extends State<_DocumentsLoader>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _spin;
  late final AnimationController _breathe;
  late final AnimationController _progress;
  late final AnimationController _entrance;

  int _messageIndex = 0;

  @override
  void initState() {
    super.initState();

    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _progress = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..forward();

    _cycleMessages();
  }

  Future<void> _cycleMessages() async {
    if (widget.messages.length < 2) return;

    while (mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;
      setState(() {
        _messageIndex = (_messageIndex + 1) % widget.messages.length;
      });
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _spin.dispose();
    _breathe.dispose();
    _progress.dispose();
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final blue = Palette.nestBlue;

    return Container(
      color: const Color(0xFFF5F7FB),
      child: Center(
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: _entrance,
            curve: Curves.easeOut,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildOrbit(blue),
              const SizedBox(height: 36),
              _buildWordmark(blue),
              const SizedBox(height: 14),
              _buildMessage(),
              const SizedBox(height: 24),
              _buildProgressBar(blue),
              const SizedBox(height: 18),
              _buildDots(blue),
            ],
          ),
        ),
      ),
    );
  }

  // ── Halo + spinning arcs + glowing core ──────────────────────
  Widget _buildOrbit(Color blue) {
    return SizedBox(
      width: 170,
      height: 170,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Expanding halo rings
          ...List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                final t = (_pulse.value + index / 3) % 1.0;
                final size = 84 + (t * 84);

                return Opacity(
                  opacity: (1 - t) * 0.35,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: blue, width: 1.6),
                    ),
                  ),
                );
              },
            );
          }),

          // Counter-rotating dotted ring
          RotationTransition(
            turns: ReverseAnimation(_spin),
            child: CustomPaint(
              size: const Size(152, 152),
              painter: _DocsLoaderDotsPainter(color: blue),
            ),
          ),

          // Spinning gradient arc
          RotationTransition(
            turns: _spin,
            child: CustomPaint(
              size: const Size(128, 128),
              painter: _DocsLoaderArcPainter(color: blue),
            ),
          ),

          // Breathing core — folder icon in a gradient circle
          AnimatedBuilder(
            animation: _breathe,
            builder: (context, child) {
              final t = Curves.easeInOut.transform(_breathe.value);
              return Transform.scale(
                scale: 0.96 + (t * 0.08),
                child: child,
              );
            },
            child: Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    blue,
                    Color.lerp(blue, Colors.black, 0.25)!,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: blue.withValues(alpha: 0.35),
                    blurRadius: 26,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.folder_copy_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordmark(Color blue) {
    return Column(
      children: [
        Text(
          'DOCUMENTS',
          style: TextStyle(
            fontSize: 15,
            letterSpacing: 6,
            fontWeight: FontWeight.w700,
            fontFamily: 'SF-Pro-Text-Bold',
            color: blue,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'PROPERTY FILES & RECORDS',
          style: TextStyle(
            fontSize: 8,
            letterSpacing: 2.5,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildMessage() {
    return SizedBox(
      height: 20,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: Text(
          widget.messages[_messageIndex],
          key: ValueKey<int>(_messageIndex),
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'SF-Pro-Text-Regular',
            color: Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(Color blue) {
    return SizedBox(
      width: 210,
      height: 4,
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          final value =
          (0.08 + Curves.easeOutCubic.transform(_progress.value) * 0.82)
              .clamp(0.0, 1.0);

          return ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 4,
              backgroundColor: blue.withValues(alpha: 0.10),
              valueColor: AlwaysStoppedAnimation<Color>(blue),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDots(Color blue) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final t = (_pulse.value + index * 0.18) % 1.0;
            final intensity =
            (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);
            final opacity = 0.20 + (intensity * 0.80);

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: blue.withValues(alpha: opacity),
              ),
            );
          }),
        );
      },
    );
  }
}

// ── Sweeping gradient arc ──────────────────────────────────────
class _DocsLoaderArcPainter extends CustomPainter {
  const _DocsLoaderArcPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.shortestSide * 0.032;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.05),
          color.withValues(alpha: 0.85),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect);

    canvas.drawArc(
      rect.deflate(stroke / 2),
      0,
      4.4,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _DocsLoaderArcPainter oldDelegate) =>
      oldDelegate.color != color;
}

// ── Fading dotted ring ─────────────────────────────────────────
class _DocsLoaderDotsPainter extends CustomPainter {
  const _DocsLoaderDotsPainter({
    required this.color,
    this.dotCount = 20,
  });

  final Color color;
  final int dotCount;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 3;
    final paint = Paint()..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(center.dx, center.dy);

    for (int i = 0; i < dotCount; i++) {
      canvas.rotate(6.28318 / dotCount);

      final fade = i / dotCount;
      paint.color = color.withValues(alpha: 0.04 + fade * 0.26);

      canvas.drawCircle(Offset(0, -radius), 1.6, paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DocsLoaderDotsPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.dotCount != dotCount;
}