import 'package:flutter/material.dart';
import 'package:hub/models/models.dart';
import 'package:hub/services/services.dart';
import 'package:hub/config/config.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class MaintenanceDashboard extends StatefulWidget {
  final Future<PropertyResponse> propertyResponseFuture;

  const MaintenanceDashboard({super.key, required this.propertyResponseFuture});

  @override
  State<MaintenanceDashboard> createState() => _MaintenanceDashboardState();
}

class _MaintenanceDashboardState extends State<MaintenanceDashboard> {
  late Future<List<MaintenanceIssue>> _issuesFuture;
  List<MaintenanceIssue> _allIssues = [];
  List<MaintenanceIssue> _filteredIssues = [];
  bool _isLoading = true;
  String? _errorMessage;

  String? _selectedProperty;
  String? _selectedStatus;

  final List<String> _statuses = ['open', 'in_progress', 'resolved'];

  @override
  void initState() {
    super.initState();
    _loadIssues();
  }

  void _loadIssues() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    _issuesFuture = ApiService(baseUrl: baseUrl).fetchMaintenanceIssues();

    _issuesFuture.then((issues) {
      if (mounted) {
        setState(() {
          _allIssues = issues;
          _filteredIssues = issues;
          _isLoading = false;
        });
      }
    }).catchError((error) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load maintenance issues';
          _isLoading = false;
        });
      }
    });
  }

  void _applyFilters() {
    setState(() {
      _filteredIssues = _allIssues.where((issue) {
        bool matchesProperty = _selectedProperty == null || issue.propertyName == _selectedProperty;
        bool matchesStatus = _selectedStatus == null || issue.status == _selectedStatus;
        return matchesProperty && matchesStatus;
      }).toList();
    });
  }

  String _formatDate(String dateStr) {
    try {
      final DateTime date = DateTime.parse(dateStr);
      final DateFormat formatter = DateFormat('dd/MMM');
      return formatter.format(date);
    } catch (e) {
      return dateStr;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return SizedBox( // ✅ Wrap everything in SizedBox for explicit size
      width: double.infinity,
      height: 1000, // ✅ Explicit height to prevent sizing issues
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filters section
              _buildFiltersSection(),
              const SizedBox(height: 16),

              // Main content
              Expanded(
                child: _buildMainContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFiltersSection() {
    return FutureBuilder<PropertyResponse>(
      future: widget.propertyResponseFuture,
      builder: (context, snapshot) {
        final propertyNames = snapshot.data?.properties.map((p) => p.name).toList() ?? [];

        return Container(
          height: 50,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              const Text('Filter: ', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),

              // Property filter
              DropdownButton<String>(
                value: _selectedProperty,
                hint: const Text('All Properties'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All', style: TextStyle(fontSize: 14),)),
                  ...propertyNames.map((name) => DropdownMenuItem(value: name, child: Text(name, style: TextStyle(fontSize: 14),))).toList(),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedProperty = value;
                  });
                  _applyFilters();
                },
                icon: const Icon(Icons.arrow_drop_down, size: 20),
                underline: Container(),
              ),

              const SizedBox(width: 16),

              // Status filter
              DropdownButton<String>(
                value: _selectedStatus,
                hint: const Text('All Statuses'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All', style: TextStyle(fontSize: 14),)),
                  ..._statuses.map((status) => DropdownMenuItem(value: status, child: Text(_formatStatus(status), style: TextStyle(fontSize: 14),))).toList(),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedStatus = value;
                  });
                  _applyFilters();
                },
                icon: const Icon(Icons.arrow_drop_down, size: 20),
                underline: Container(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 0.9,));
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadIssues,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_filteredIssues.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.build, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('No maintenance issues found'),
            const SizedBox(height: 8),
            const Text('Submit a new request to see it here', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            // Summary cards
            SizedBox(
              height: 100,
              child: _buildSummaryCards(constraints.maxWidth),
            ),

            const SizedBox(height: 16),

            // Charts
            SizedBox(
              height: 300,
              child: _buildCharts(constraints.maxWidth),
            ),

            const SizedBox(height: 16),

            // Issues list header
            Align(
              alignment: AlignmentGeometry.centerLeft,
              child: const Text(
                'Recent Issues',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),

            // Issues list
            Expanded(
              child: _buildIssuesList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCards(double maxWidth) {
    final openCount = _filteredIssues.where((i) => i.status == 'open').length;
    final inProgressCount = _filteredIssues.where((i) => i.status == 'in_progress').length;
    final resolvedCount = _filteredIssues.where((i) => i.status == 'resolved').length;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (maxWidth > 600) {
          return Row(
            children: [
              _buildSummaryCard('Open', openCount, Colors.red.shade400),
              const SizedBox(width: 12),
              _buildSummaryCard('In Progress', inProgressCount, Colors.orange.shade500),
              const SizedBox(width: 12),
              _buildSummaryCard('Resolved', resolvedCount, Colors.green.shade500),
            ],
          );
        } else {
          return Column(
            children: [
              _buildSummaryCard('Open', openCount, Colors.red.shade400),
              const SizedBox(height: 8),
              _buildSummaryCard('In Progress', inProgressCount, Colors.orange.shade500),
              const SizedBox(height: 8),
              _buildSummaryCard('Resolved', resolvedCount, Colors.green.shade500),
            ],
          );
        }
      },
    );
  }

  Widget _buildSummaryCard(String title, int count, Color color) {
    return Expanded(
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: color.withValues(alpha: 0.1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color),
              ),
              const SizedBox(height: 4),
              Text(
                count.toString(),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCharts(double maxWidth) {
    final openCount = _filteredIssues.where((i) => i.status == 'open').length;
    final inProgressCount = _filteredIssues.where((i) => i.status == 'in_progress').length;
    final resolvedCount = _filteredIssues.where((i) => i.status == 'resolved').length;

    final overallData = [
      _ChartData('Open', openCount),
      _ChartData('In Progress', inProgressCount),
      _ChartData('Resolved', resolvedCount),
    ];

    final propertyCounts = <String, int>{};
    for (var issue in _filteredIssues) {
      propertyCounts[issue.propertyName] = (propertyCounts[issue.propertyName] ?? 0) + 1;
    }
    final propertyData = propertyCounts.entries
        .map((e) => _ChartData(e.key, e.value))
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        if (maxWidth > 800) {
          return Row(
            children: [
              Expanded(
                child: _buildStatusChart(overallData),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildPropertyChart(propertyData),
              ),
            ],
          );
        } else {
          return Column(
            children: [
              Expanded(
                child: _buildStatusChart(overallData),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _buildPropertyChart(propertyData),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildStatusChart(List<_ChartData> data) {
    if (data.every((item) => item.y == 0)) {
      return const Center(child: Text('No data available'));
    }

    return SfCartesianChart(
      title: ChartTitle(
        text: 'Status Distribution',
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
      primaryXAxis: CategoryAxis(
        labelRotation: 0,
        labelStyle: const TextStyle(fontSize: 10),
      ),
      primaryYAxis: NumericAxis(
        labelFormat: '{value}',
        labelStyle: const TextStyle(fontSize: 10),
      ),
      legend: const Legend(isVisible: false),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CartesianSeries<_ChartData, String>>[
        ColumnSeries<_ChartData, String>(
          dataSource: data,
          xValueMapper: (_ChartData data, _) => data.x,
          yValueMapper: (_ChartData data, _) => data.y,
          name: 'Count',
          color: Colors.blue.shade400,
          borderRadius: BorderRadius.circular(4),
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            labelPosition: ChartDataLabelPosition.outside,
            textStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
          ),
        )
      ],
    );
  }

  Widget _buildPropertyChart(List<_ChartData> data) {
    if (data.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    return SfCartesianChart(
      title: ChartTitle(
        text: 'Property Distribution',
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
      primaryXAxis: CategoryAxis(
        labelRotation: 45,
        labelStyle: const TextStyle(fontSize: 10),
        labelIntersectAction: AxisLabelIntersectAction.hide,
      ),
      primaryYAxis: NumericAxis(
        labelFormat: '{value}',
        labelStyle: const TextStyle(fontSize: 10),
        title: AxisTitle(text: ''), // Add this to remove the y-axis label
      ),
      legend: const Legend(isVisible: false),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CartesianSeries<_ChartData, String>>[
        BarSeries<_ChartData, String>(
          dataSource: data,
          xValueMapper: (_ChartData data, _) => data.x,
          yValueMapper: (_ChartData data, _) => data.y,
          name: 'Count',
          color: Colors.green.shade400,
          borderRadius: BorderRadius.circular(4),
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            labelPosition: ChartDataLabelPosition.outside,
            textStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
          ),
        )
      ],
    );
  }

  Widget _buildIssuesList() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _filteredIssues.length,
        itemBuilder: (context, index) {
          final issue = _filteredIssues[index];
          return _buildIssueItem(issue);
        },
      ),
    );
  }

  Widget _buildIssueItem(MaintenanceIssue issue) {
    Color statusColor;
    IconData statusIcon;

    switch (issue.status) {
      case 'open':
        statusColor = Colors.red.shade400;
        statusIcon = Icons.report_problem;
        break;
      case 'in_progress':
        statusColor = Colors.orange.shade500;
        statusIcon = Icons.build;
        break;
      case 'resolved':
        statusColor = Colors.green.shade500;
        statusIcon = Icons.check_circle;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(
          '${issue.propertyName} ➸ ${issue.houseNo}',
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        subtitle: Text(
          issue.subject,
          style: const TextStyle(fontSize: 12),
        ),
        leading: Icon(statusIcon, color: statusColor, size: 20),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 12, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            _formatStatus(issue.status),
                            style: TextStyle(fontSize: 10, color: statusColor),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Reported: ${_formatDate(issue.createdAt.toString()).split(' ').first}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w300),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Description',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  issue.description,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'open':
        return 'Open';
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      default:
        return status;
    }
  }
}

class _ChartData {
  final String x;
  final int y;

  _ChartData(this.x, this.y);
}
