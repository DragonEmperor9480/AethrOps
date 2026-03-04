import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../widgets/loading_animation.dart';
import '../widgets/list_header_with_search.dart';
import '../widgets/speed_dial_menu.dart';
import '../theme/app_theme.dart';
import '../utils/toast_utils.dart';
import 'ec2_instance_details_screen.dart';
import 'ec2_launch_screen.dart';

class EC2Screen extends StatefulWidget {
  const EC2Screen({super.key});

  @override
  State<EC2Screen> createState() => _EC2ScreenState();
}

class EC2Instance {
  final String instanceId;
  final String name;
  final String state;
  final String platform;
  final String architecture;
  final String instanceType;
  final String? region;

  EC2Instance({
    required this.instanceId,
    required this.name,
    required this.state,
    required this.platform,
    required this.architecture,
    required this.instanceType,
    this.region,
  });

  factory EC2Instance.fromJson(Map<String, dynamic> json) {
    return EC2Instance(
      instanceId: json['instance_id'] ?? '',
      name: json['name'] ?? 'N/A',
      state: json['state'] ?? 'unknown',
      platform: json['platform'] ?? 'Unknown',
      architecture: json['architecture'] ?? 'Unknown',
      instanceType: json['instance_type'] ?? 'Unknown',
      region: json['region'],
    );
  }

  Color get stateColor {
    switch (state.toLowerCase()) {
      case 'running':
        return AppTheme.successGreen;
      case 'stopped':
        return AppTheme.errorRed;
      case 'pending':
      case 'stopping':
        return AppTheme.warningAmber;
      case 'terminated':
      case 'shutting-down':
        return Colors.grey;
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData get stateIcon {
    switch (state.toLowerCase()) {
      case 'running':
        return Icons.play_circle;
      case 'stopped':
        return Icons.stop_circle;
      case 'pending':
      case 'stopping':
        return Icons.pending;
      case 'terminated':
      case 'shutting-down':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }
}

class _EC2ScreenState extends State<EC2Screen> {
  List<EC2Instance> _instances = [];
  List<EC2Instance> _filteredInstances = [];
  bool _loading = false;
  final bool _operationInProgress = false;
  String _filterState = 'all';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  // Multi-region settings
  bool _showDashboard = false;
  bool _showAllRegions = false;
  Map<String, dynamic>? _dashboardData;
  bool _dashboardLoading = false;
  String? _selectedRegion; // Selected region when All Regions is disabled
  List<String> _availableRegions = []; // List of available regions

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterInstances);
    _loadSettings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    // Set loading state at the start
    setState(() => _loading = true);
    
    final prefs = await SharedPreferences.getInstance();
    
    // First, get the current region from backend
    try {
      final config = await ApiService.getAWSConfig();
      final currentRegion = config['region'] as String?;
      
      setState(() {
        _showDashboard = prefs.getBool('ec2_show_dashboard') ?? false;
        _showAllRegions = prefs.getBool('ec2_show_all_regions') ?? false;
        
        // Always use current region from backend as default
        // Ignore saved region if it doesn't match current config
        _selectedRegion = currentRegion;
      });
      
      // Save the current region
      if (currentRegion != null) {
        await prefs.setString('ec2_selected_region', currentRegion);
      }
    } catch (e) {
      // Fallback to saved settings if API fails
      setState(() {
        _showDashboard = prefs.getBool('ec2_show_dashboard') ?? false;
        _showAllRegions = prefs.getBool('ec2_show_all_regions') ?? false;
        _selectedRegion = prefs.getString('ec2_selected_region');
      });
    }
    
    // Load available regions
    await _loadAvailableRegions();
    
    // Load both dashboard and instances in parallel
    final futures = <Future>[];
    
    if (_showDashboard) {
      futures.add(_loadDashboard());
    }
    futures.add(_loadInstances());
    
    // Wait for all to complete
    await Future.wait(futures);
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ec2_show_dashboard', _showDashboard);
    await prefs.setBool('ec2_show_all_regions', _showAllRegions);
    if (_selectedRegion != null) {
      await prefs.setString('ec2_selected_region', _selectedRegion!);
    }
  }

  Future<void> _loadAvailableRegions() async {
    try {
      final regions = await ApiService.listAWSRegions();
      
      setState(() {
        _availableRegions = regions;
      });
    } catch (e) {
      // Silently fail, regions will be empty
    }
  }

  void _filterInstances() {
    setState(() {
      var instances = _instances;

      // Filter by state
      if (_filterState != 'all') {
        instances = instances
            .where(
              (instance) =>
                  instance.state.toLowerCase() == _filterState.toLowerCase(),
            )
            .toList();
      }

      // Filter by search
      if (_searchController.text.isNotEmpty) {
        final query = _searchController.text.toLowerCase();
        instances = instances.where((instance) {
          return instance.name.toLowerCase().contains(query) ||
              instance.instanceId.toLowerCase().contains(query) ||
              instance.instanceType.toLowerCase().contains(query);
        }).toList();
      }

      _filteredInstances = instances;
    });
  }

  Future<void> _loadInstances() async {
    try {
      final instances = _showAllRegions
          ? await ApiService.listEC2InstancesAllRegions()
          : await ApiService.listEC2Instances(region: _selectedRegion);
      
      // Store instances (can be empty list)
      _instances = instances
          .map((json) => EC2Instance.fromJson(json))
          .toList();
      _filterInstances();
      
      // Only hide loading if dashboard is not enabled or not loading
      if (!_showDashboard || !_dashboardLoading) {
        setState(() => _loading = false);
      }
    } catch (e) {
      // Don't show error toast, just set empty list
      // The UI will show "No instances found" message
      setState(() {
        _instances = [];
        _filteredInstances = [];
        _loading = false;
      });
    }
  }

  void _showError(String message) {
    ToastUtils.show(context, message, isError: true);
  }

  void _showSuccess(String message) {
    ToastUtils.show(context, message, isError: false);
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _operationInProgress,
      message: 'Processing...',
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('EC2 Management'),
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _showSettingsBottomSheet,
              tooltip: 'Settings',
            ),
          ],
        ),
        floatingActionButton: SpeedDialMenu(
          items: [
            SpeedDialMenuItem(
              icon: Icons.rocket_launch,
              label: 'Launch Instance',
              color: AppTheme.ec2Color,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const Ec2LaunchScreen()),
                );
                _loadInstances(); // Refresh list on return
              },
            ),
            SpeedDialMenuItem(
              icon: Icons.refresh,
              label: 'Refresh',
              color: AppTheme.primaryPurple,
              onTap: _loadInstances,
            ),
          ],
        ),
        body: Column(
          children: [
            ListHeaderWithSearch(
              title: 'EC2 Instances',
              subtitle:
                  _searchController.text.isNotEmpty || _filterState != 'all'
                  ? '${_filteredInstances.length} instances (filtered)'
                  : '${_instances.length} instances',
              svgAsset: 'assets/icons/Res_Amazon-EC2_Instances_48.svg',
              iconBackgroundColor: AppTheme.primaryPurple.withValues(
                alpha: 0.15,
              ),
              iconColor: AppTheme.primaryPurple,
              searchController: _searchController,
              searchFocusNode: _searchFocusNode,
              searchHint: 'Search instances by name, ID or type...',
              headerBackgroundColor: AppTheme.primaryPurple.withValues(
                alpha: 0.08,
              ),
            ),
            // Dashboard Widget
            if (_showDashboard)
              _buildDashboardWidget(),
            // Instances List
            Expanded(
              child: _loading
                  ? const LoadingAnimation(message: 'Loading instances')
                  : _filteredInstances.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.developer_board_outlined,
                            size: 80,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _filterState == 'all'
                                ? 'No instances found'
                                : 'No $_filterState instances',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _filterState == 'all'
                                ? 'Your EC2 instances will appear here'
                                : 'Try changing the filter',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredInstances.length,
                      itemBuilder: (context, index) {
                        final instance = _filteredInstances[index];
                        return _buildInstanceCard(instance);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstanceCard(EC2Instance instance) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: instance.stateColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EC2InstanceDetailsScreen(
                instanceId: instance.instanceId,
                instanceName: instance.name,
                state: instance.state,
                region: instance.region ?? _selectedRegion,
              ),
            ),
          );
          // Refresh list if instance was terminated or action was performed
          if (result == true) {
            _loadInstances();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Instance Name and State Badge
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          instance.name.isEmpty || instance.name == 'N/A'
                              ? 'Unnamed Instance'
                              : instance.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          instance.instanceId,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // State badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: instance.stateColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: instance.stateColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          instance.stateIcon,
                          size: 12,
                          color: instance.stateColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          instance.state.toUpperCase(),
                          style: TextStyle(
                            color: instance.stateColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Region badge when showing all regions
              if (_showAllRegions && instance.region != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.public,
                        size: 12,
                        color: AppTheme.primaryPurple,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        instance.region!,
                        style: TextStyle(
                          color: AppTheme.primaryPurple,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              // Instance details - Type and Platform side by side
              Row(
                children: [
                  Expanded(
                    child: _buildSimpleDetail('Type', instance.instanceType),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSimpleDetail('Platform', instance.platform),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _buildSimpleDetail('Architecture', instance.architecture),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleDetail(String label, String value) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            color: theme.textTheme.bodyMedium?.color,
            fontSize: 13,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: theme.textTheme.bodyLarge?.color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardWidget() {
    // Don't show dashboard widget at all if loading or no data yet
    if (_dashboardLoading) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryPurple.withValues(alpha: 0.1),
              AppTheme.purple400.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primaryPurple.withValues(alpha: 0.2),
          ),
        ),
        child: _buildDashboardSkeleton(),
      );
    }
    
    // Only show dashboard content if we have data
    if (_dashboardData == null) {
      return const SizedBox.shrink(); // Don't show anything if no data
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryPurple.withValues(alpha: 0.1),
            AppTheme.purple400.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryPurple.withValues(alpha: 0.2),
        ),
      ),
      child: _buildDashboardContent(),
    );
  }

  Widget _buildDashboardSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header skeleton
        Row(
          children: [
            Icon(
              Icons.public,
              color: AppTheme.primaryPurple.withValues(alpha: 0.3),
              size: 16,
            ),
            const SizedBox(width: 6),
            Container(
              width: 100,
              height: 13,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        
        // 2x2 Grid skeleton
        Row(
          children: [
            Expanded(
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDashboardContent() {
    final totalInstances = _dashboardData?['total_instances'] ?? 0;
    final instancesByState = _dashboardData?['instances_by_state'] as Map<String, dynamic>? ?? {};
    final currentRegion = _dashboardData?['current_region'] ?? 'N/A';
    final instancesByRegion = _dashboardData?['instances_by_region'] as Map<String, dynamic>? ?? {};
    
    // Total widget is always independent (shows global count)
    final totalCount = totalInstances;
    
    // Dashboard counts depend on "All Regions" setting
    String displayRegion;
    int regionCount;
    int runningCount;
    int stoppedCount;
    
    if (_showAllRegions) {
      // Show all regions data
      displayRegion = 'All Regions';
      regionCount = totalInstances;
      runningCount = (instancesByState['running'] ?? 0) + (instancesByState['pending'] ?? 0);
      stoppedCount = instancesByState['stopped'] ?? 0;
    } else {
      // Show selected region data
      displayRegion = _selectedRegion ?? currentRegion;
      
      // Use the loaded instances (which are already filtered by region)
      regionCount = _instances.length;
      runningCount = _instances.where((i) => 
        i.state.toLowerCase() == 'running' || i.state.toLowerCase() == 'pending'
      ).length;
      stoppedCount = _instances.where((i) => 
        i.state.toLowerCase() == 'stopped'
      ).length;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Minimal header
        Row(
          children: [
            Icon(Icons.public, color: AppTheme.primaryPurple, size: 16),
            const SizedBox(width: 6),
            const Text(
              'Global Overview',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 10),
        
        // 2x2 Grid of clickable metrics
        Row(
          children: [
            Expanded(
              child: _buildClickableMetricCard(
                totalCount.toString(),
                'Total',
                Icons.dns_rounded,
                AppTheme.primaryPurple,
                'all',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildRegionMetricCard(
                regionCount.toString(),
                displayRegion,
                Icons.location_on,
                AppTheme.purple400,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildClickableMetricCard(
                runningCount.toString(),
                'Running',
                Icons.play_circle_filled,
                AppTheme.successGreen,
                'running',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildClickableMetricCard(
                stoppedCount.toString(),
                'Stopped',
                Icons.stop_circle,
                AppTheme.errorRed,
                'stopped',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRegionMetricCard(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    final isSelected = _filterState == 'all';
    
    return InkWell(
      onTap: () {
        // Just filter to show all instances
        setState(() {
          _filterState = 'all';
          _filterInstances();
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.5)
                : color.withValues(alpha: 0.25),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      height: 1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClickableMetricCard(
    String value,
    String label,
    IconData icon,
    Color color,
    String filterState,
  ) {
    final isSelected = _filterState == filterState;
    
    return InkWell(
      onTap: () {
        setState(() {
          _filterState = filterState;
          _filterInstances();
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.5)
                : color.withValues(alpha: 0.25),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      height: 1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'EC2 Settings',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              SwitchListTile(
                title: const Text('Show Dashboard'),
                subtitle: const Text('Display EC2 statistics and metrics'),
                value: _showDashboard,
                onChanged: (value) {
                  setModalState(() => _showDashboard = value);
                  setState(() => _showDashboard = value);
                  _saveSettings();
                  if (value) {
                    _loadDashboard();
                  } else {
                    setState(() {
                      _dashboardData = null;
                      _dashboardLoading = false;
                    });
                  }
                },
              ),
              const Divider(),
              SwitchListTile(
                title: const Text('All Regions'),
                subtitle: Text(_showAllRegions
                    ? 'Showing instances from all regions'
                    : 'Showing instances from ${_selectedRegion ?? _dashboardData?['current_region'] ?? "loading..."}'),
                value: _showAllRegions,
                onChanged: (value) {
                  setModalState(() => _showAllRegions = value);
                  setState(() => _showAllRegions = value);
                  _saveSettings();
                  _loadInstances();
                  // Refresh dashboard if enabled
                  if (_showDashboard) {
                    _loadDashboard();
                  }
                },
              ),
              // Show region selector when All Regions is disabled
              if (!_showAllRegions && _availableRegions.isNotEmpty) ...[
                const Divider(),
                ListTile(
                  leading: Icon(Icons.location_on, color: AppTheme.primaryPurple),
                  title: const Text('Select Region'),
                  subtitle: Text(_selectedRegion ?? _dashboardData?['current_region'] ?? 'Loading...'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.pop(context);
                    _showRegionSelectorModal();
                  },
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showRegionSelectorModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.public, color: AppTheme.primaryPurple, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Select Region',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _availableRegions.length,
                itemBuilder: (context, index) {
                  final region = _availableRegions[index];
                  final isSelected = _selectedRegion == region;
                  return ListTile(
                    leading: Icon(
                      Icons.location_on,
                      color: isSelected ? AppTheme.primaryPurple : Colors.grey,
                    ),
                    title: Text(
                      region,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppTheme.primaryPurple : null,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check, color: AppTheme.primaryPurple)
                        : null,
                    onTap: () async {
                      // Close modal first
                      Navigator.pop(context);
                      
                      // Then update state
                      setState(() {
                        _selectedRegion = region;
                      });
                      
                      await _saveSettings();
                      _loadInstances();
                      
                      // Refresh dashboard if enabled
                      if (_showDashboard) {
                        _loadDashboard();
                      }
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _loadDashboard() async {
    setState(() => _dashboardLoading = true);
    try {
      final dashboard = await ApiService.getEC2Dashboard();
      setState(() {
        _dashboardData = dashboard;
        _dashboardLoading = false;
        // Hide main loading when dashboard is done
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _dashboardLoading = false;
        _loading = false;
      });
      _showError('Failed to load dashboard: $e');
    }
  }
}

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final String message;
  final Widget child;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.message,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.5),
            child: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(message),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
