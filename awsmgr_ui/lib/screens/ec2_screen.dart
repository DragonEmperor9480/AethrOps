import 'package:flutter/material.dart';
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

  EC2Instance({
    required this.instanceId,
    required this.name,
    required this.state,
    required this.platform,
    required this.architecture,
    required this.instanceType,
  });

  factory EC2Instance.fromJson(Map<String, dynamic> json) {
    return EC2Instance(
      instanceId: json['instance_id'] ?? '',
      name: json['name'] ?? 'N/A',
      state: json['state'] ?? 'unknown',
      platform: json['platform'] ?? 'Unknown',
      architecture: json['architecture'] ?? 'Unknown',
      instanceType: json['instance_type'] ?? 'Unknown',
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

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterInstances);
    _loadInstances();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
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
    setState(() => _loading = true);
    try {
      final instances = await ApiService.listEC2Instances();
      setState(() {
        _instances = instances
            .map((json) => EC2Instance.fromJson(json))
            .toList();
        _filterInstances();
      });
    } catch (e) {
      _showError('Failed to load instances: $e');
    } finally {
      setState(() => _loading = false);
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
        appBar: AppBar(title: const Text('EC2 Management'), elevation: 0),
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
            // Filter pills outside header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All', 'all'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Running', 'running'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Stopped', 'stopped'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Pending', 'pending'),
                  ],
                ),
              ),
            ),
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

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterState == value;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        setState(() {
          _filterState = value;
          _filterInstances();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.purple400 : theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.purple400 : AppTheme.purple200,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.purple600,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
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
