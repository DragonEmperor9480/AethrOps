import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/loading_animation.dart';
import '../theme/app_theme.dart';
import 'ec2_instance_details_screen.dart';

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
  bool _loading = false;
  bool _operationInProgress = false;
  String _filterState = 'all';

  @override
  void initState() {
    super.initState();
    _loadInstances();
  }

  Future<void> _loadInstances() async {
    setState(() => _loading = true);
    try {
      final instances = await ApiService.listEC2Instances();
      setState(() {
        _instances = instances.map((json) => EC2Instance.fromJson(json)).toList();
      });
    } catch (e) {
      _showError('Failed to load instances: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.successGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<EC2Instance> get _filteredInstances {
    if (_filterState == 'all') {
      return _instances;
    }
    return _instances.where((instance) => 
      instance.state.toLowerCase() == _filterState.toLowerCase()
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredInstances = _filteredInstances;

    return LoadingOverlay(
      isLoading: _operationInProgress,
      message: 'Processing...',
      child: Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        appBar: AppBar(
          title: const Text('EC2 Management'),
          elevation: 0,
          backgroundColor: Colors.white,
        ),
        body: Column(
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: AppTheme.ec2Color.withValues(alpha: 0.1),
                border: Border(
                  bottom: BorderSide(color: AppTheme.ec2Color.withValues(alpha: 0.2)),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.ec2Color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.developer_board, color: AppTheme.ec2Color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'EC2 Instances',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${filteredInstances.length} instance${filteredInstances.length != 1 ? 's' : ''} found',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _loadInstances,
                        tooltip: 'Refresh',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Filter chips
                  SingleChildScrollView(
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
                ],
              ),
            ),
            // Instances List
            Expanded(
              child: _loading
                  ? const LoadingAnimation(message: 'Loading instances')
                  : filteredInstances.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.developer_board_outlined,
                                  size: 80, color: Colors.grey[300]),
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
                          itemCount: filteredInstances.length,
                          itemBuilder: (context, index) {
                            final instance = filteredInstances[index];
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
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filterState = value);
      },
      backgroundColor: Colors.white,
      selectedColor: AppTheme.ec2Color.withValues(alpha: 0.2),
      checkmarkColor: AppTheme.ec2Color,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.ec2Color : AppTheme.textSecondary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected 
            ? AppTheme.ec2Color 
            : AppTheme.borderColor,
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
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EC2InstanceDetailsScreen(
                instanceId: instance.instanceId,
                instanceName: instance.name,
                state: instance.state,
              ),
            ),
          );
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
                          color: AppTheme.textSecondary,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // State badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                Expanded(child: _buildSimpleDetail('Type', instance.instanceType)),
                const SizedBox(width: 16),
                Expanded(child: _buildSimpleDetail('Platform', instance.platform)),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppTheme.textPrimary,
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
