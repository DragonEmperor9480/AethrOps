import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../widgets/loading_animation.dart';
import '../theme/app_theme.dart';
import '../utils/toast_utils.dart';

class EC2InstanceDetailsScreen extends StatefulWidget {
  final String instanceId;
  final String instanceName;
  final String state;
  final String? region;

  const EC2InstanceDetailsScreen({
    super.key,
    required this.instanceId,
    required this.instanceName,
    required this.state,
    this.region,
  });

  @override
  State<EC2InstanceDetailsScreen> createState() =>
      _EC2InstanceDetailsScreenState();
}

class _EC2InstanceDetailsScreenState extends State<EC2InstanceDetailsScreen> {
  Map<String, dynamic>? _instanceDetails;
  bool _loading = true;
  bool _operationInProgress = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInstanceDetails();
  }

  Future<void> _loadInstanceDetails() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final details = await ApiService.getEC2Instance(
        widget.instanceId,
        region: widget.region,
      );
      setState(() {
        _instanceDetails = details;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ToastUtils.show(context, '$label copied to clipboard', isError: false);
  }

  void _showSuccess(String message) {
    ToastUtils.show(context, message, isError: false);
  }

  void _showError(String message) {
    ToastUtils.show(context, message, isError: true);
  }

  Future<void> _startInstance() async {
    final confirm = await _showConfirmDialog(
      'Start Instance',
      'Are you sure you want to start this instance?',
      Icons.play_circle,
      AppTheme.successGreen,
    );

    if (confirm == true) {
      setState(() => _operationInProgress = true);
      try {
        await ApiService.startEC2Instance(widget.instanceId, region: widget.region);
        _showSuccess('Instance start initiated');
        await Future.delayed(const Duration(seconds: 2));
        await _loadInstanceDetails();
      } catch (e) {
        _showError('Failed to start instance: $e');
      } finally {
        setState(() => _operationInProgress = false);
      }
    }
  }

  Future<void> _stopInstance() async {
    final confirm = await _showConfirmDialog(
      'Stop Instance',
      'Are you sure you want to stop this instance?',
      Icons.stop_circle,
      AppTheme.warningAmber,
    );

    if (confirm == true) {
      setState(() => _operationInProgress = true);
      try {
        await ApiService.stopEC2Instance(widget.instanceId, region: widget.region);
        _showSuccess('Instance stop initiated');
        await Future.delayed(const Duration(seconds: 2));
        await _loadInstanceDetails();
      } catch (e) {
        _showError('Failed to stop instance: $e');
      } finally {
        setState(() => _operationInProgress = false);
      }
    }
  }

  Future<void> _rebootInstance() async {
    final confirm = await _showConfirmDialog(
      'Reboot Instance',
      'Are you sure you want to reboot this instance?',
      Icons.refresh,
      AppTheme.primaryBlue,
    );

    if (confirm == true) {
      setState(() => _operationInProgress = true);
      try {
        await ApiService.rebootEC2Instance(widget.instanceId, region: widget.region);
        _showSuccess('Instance reboot initiated');
        await Future.delayed(const Duration(seconds: 2));
        await _loadInstanceDetails();
      } catch (e) {
        _showError('Failed to reboot instance: $e');
      } finally {
        setState(() => _operationInProgress = false);
      }
    }
  }

  Future<void> _terminateInstance() async {
    final confirm = await _showConfirmDialog(
      'Terminate Instance',
      'Are you sure you want to TERMINATE this instance?\n\nThis action is IRREVERSIBLE and will permanently delete the instance!',
      Icons.delete_forever,
      AppTheme.errorRed,
      confirmText: 'TERMINATE',
      isDangerous: true,
    );

    if (confirm == true) {
      setState(() => _operationInProgress = true);
      try {
        await ApiService.terminateEC2Instance(widget.instanceId, region: widget.region);
        _showSuccess('Instance termination initiated');
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.pop(context, true); // Return to list and refresh
        }
      } catch (e) {
        _showError('Failed to terminate instance: $e');
        setState(() => _operationInProgress = false);
      }
    }
  }

  Future<bool?> _showConfirmDialog(
    String title,
    String message,
    IconData icon,
    Color color, {
    String confirmText = 'Confirm',
    bool isDangerous = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDangerous ? AppTheme.errorRed : color,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItemContent({
    required IconData icon,
    required String label,
    required Color color,
    bool isDangerous = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isDangerous ? AppTheme.errorRed : null,
          ),
        ),
      ],
    );
  }

  Color get _stateColor {
    switch (widget.state.toLowerCase()) {
      case 'running':
        return AppTheme.successGreen;
      case 'stopped':
        return AppTheme.errorRed;
      case 'pending':
      case 'stopping':
        return AppTheme.warningAmber;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Instance Details'),
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Actions',
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            offset: const Offset(0, 50),
            onSelected: (value) {
              switch (value) {
                case 'start':
                  _startInstance();
                  break;
                case 'stop':
                  _stopInstance();
                  break;
                case 'reboot':
                  _rebootInstance();
                  break;
                case 'terminate':
                  _terminateInstance();
                  break;
              }
            },
            itemBuilder: (context) {
              final state = widget.state.toLowerCase();
              final isRunning = state == 'running';
              final isStopped = state == 'stopped';
              final isPending = state == 'pending' || state == 'stopping';

              return [
                if (isStopped)
                  PopupMenuItem(
                    value: 'start',
                    child: _buildMenuItemContent(
                      icon: Icons.play_circle,
                      label: 'Start Instance',
                      color: AppTheme.successGreen,
                    ),
                  ),
                if (isRunning)
                  PopupMenuItem(
                    value: 'stop',
                    child: _buildMenuItemContent(
                      icon: Icons.stop_circle,
                      label: 'Stop Instance',
                      color: AppTheme.warningAmber,
                    ),
                  ),
                if (isRunning)
                  PopupMenuItem(
                    value: 'reboot',
                    child: _buildMenuItemContent(
                      icon: Icons.refresh,
                      label: 'Reboot Instance',
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                if (!isPending)
                  PopupMenuItem(
                    value: 'terminate',
                    child: _buildMenuItemContent(
                      icon: Icons.delete_forever,
                      label: 'Terminate Instance',
                      color: AppTheme.errorRed,
                      isDangerous: true,
                    ),
                  ),
              ];
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInstanceDetails,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Stack(
        children: [
          _loading
              ? const LoadingAnimation(message: 'Loading instance details')
              : _error != null
              ? _buildErrorState()
              : _buildDetailsContent(),
          if (_operationInProgress)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Processing action...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppTheme.errorRed),
          const SizedBox(height: 16),
          Text(
            'Failed to load instance details',
            style: TextStyle(
              fontSize: 18,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textTheme.bodyMedium?.color),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadInstanceDetails,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsContent() {
    if (_instanceDetails == null) return const SizedBox();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          _buildHeaderSection(),
          const SizedBox(height: 8),

          // Main Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOverviewSection(),
                const SizedBox(height: 16),
                _buildNetworkSection(),
                const SizedBox(height: 16),
                _buildStorageSection(),
                const SizedBox(height: 16),
                _buildSecuritySection(),
                const SizedBox(height: 16),
                _buildConfigurationSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          bottom: BorderSide(color: _stateColor.withValues(alpha: 0.2)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.instanceName.isEmpty ||
                              widget.instanceName == 'N/A'
                          ? 'Unnamed Instance'
                          : widget.instanceName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.instanceId,
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.textTheme.bodyMedium?.color,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          onPressed: () => _copyToClipboard(
                            widget.instanceId,
                            'Instance ID',
                          ),
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                          tooltip: 'Copy Instance ID',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _stateColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _stateColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  widget.state.toUpperCase(),
                  style: TextStyle(
                    color: _stateColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildQuickInfo(
                Icons.computer,
                _instanceDetails!['instance_type'] ?? 'N/A',
              ),
              _buildQuickInfo(
                Icons.architecture,
                _instanceDetails!['architecture'] ?? 'N/A',
              ),
              _buildQuickInfo(
                Icons.laptop_chromebook,
                _instanceDetails!['platform'] ?? 'N/A',
              ),
              _buildQuickInfo(
                Icons.access_time,
                _instanceDetails!['launch_time'] ?? 'N/A',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickInfo(IconData icon, String text) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: theme.textTheme.bodyMedium?.color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: theme.textTheme.bodyLarge?.color,
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewSection() {
    return _buildSection('Overview', Icons.info_outline, [
      _buildDetailRow('Instance Type', _instanceDetails!['instance_type']),
      _buildDetailRow('AMI ID', _instanceDetails!['image_id'], copyable: true),
      _buildDetailRow('Key Pair', _instanceDetails!['key_name'] ?? 'None'),
      _buildDetailRow(
        'Availability Zone',
        _instanceDetails!['availability_zone'],
      ),
      _buildDetailRow('Launch Time', _instanceDetails!['launch_time']),
      _buildDetailRow('Monitoring', _instanceDetails!['monitoring_state']),
      _buildDetailRow(
        'Virtualization Type',
        _instanceDetails!['virtualization_type'],
      ),
      if (_instanceDetails!['instance_lifecycle']?.toString().isNotEmpty ==
          true)
        _buildDetailRow('Lifecycle', _instanceDetails!['instance_lifecycle']),
    ]);
  }

  Widget _buildNetworkSection() {
    final publicIp = _instanceDetails!['public_ip'] ?? 'None';
    final privateIp = _instanceDetails!['private_ip'] ?? 'None';
    final interfaces =
        _instanceDetails!['network_interfaces'] as List<dynamic>? ?? [];

    return _buildSection('Network & Security', Icons.public, [
      _buildDetailRow('VPC ID', _instanceDetails!['vpc_id'], copyable: true),
      _buildDetailRow(
        'Subnet ID',
        _instanceDetails!['subnet_id'],
        copyable: true,
      ),
      _buildDetailRow('Public IP', publicIp, copyable: publicIp != 'None'),
      _buildDetailRow('Private IP', privateIp, copyable: privateIp != 'None'),
      if (interfaces.isNotEmpty) ...[
        const SizedBox(height: 8),
        const Text(
          'Network Interfaces',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 8),
        ...interfaces.map((ni) => _buildNetworkInterface(ni)),
      ],
    ]);
  }

  Widget _buildNetworkInterface(Map<String, dynamic> ni) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBackgroundDark : AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppTheme.borderColorDark : AppTheme.borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSubDetail(
            'Interface ID',
            ni['network_interface_id'],
            copyable: true,
          ),
          _buildSubDetail('MAC Address', ni['mac_address']),
          _buildSubDetail('Private IP', ni['private_ip']),
          if (ni['public_ip'] != null)
            _buildSubDetail('Public IP', ni['public_ip']),
        ],
      ),
    );
  }

  Widget _buildStorageSection() {
    final blockDevices =
        _instanceDetails!['block_devices'] as List<dynamic>? ?? [];

    return _buildSection('Storage', Icons.storage, [
      _buildDetailRow(
        'Root Device Type',
        _instanceDetails!['root_device_type'],
      ),
      _buildDetailRow(
        'Root Device Name',
        _instanceDetails!['root_device_name'],
      ),
      if (blockDevices.isNotEmpty) ...[
        const SizedBox(height: 8),
        const Text(
          'Block Devices',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 8),
        ...blockDevices.map((device) => _buildBlockDevice(device)),
      ],
    ]);
  }

  Widget _buildBlockDevice(Map<String, dynamic> device) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBackgroundDark : AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppTheme.borderColorDark : AppTheme.borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.disc_full, size: 16, color: AppTheme.ec2Color),
              const SizedBox(width: 6),
              Text(
                device['device_name'] ?? 'Unknown',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildSubDetail('Volume ID', device['volume_id'], copyable: true),
          _buildSubDetail('Status', device['status']),
          _buildSubDetail('Attached', device['attach_time']),
          _buildSubDetail(
            'Delete on Termination',
            device['delete_on_termination'].toString(),
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySection() {
    final securityGroups =
        _instanceDetails!['security_groups'] as List<dynamic>? ?? [];

    return _buildSection('Security', Icons.security, [
      if (securityGroups.isNotEmpty) ...[
        const Text(
          'Security Groups',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 8),
        ...securityGroups.map((sg) => _buildSecurityGroup(sg)),
      ] else
        Text(
          'No security groups',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
    ]);
  }

  Widget _buildSecurityGroup(Map<String, dynamic> sg) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBackgroundDark : AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppTheme.borderColorDark : AppTheme.borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSubDetail('Name', sg['group_name']),
          _buildSubDetail('Group ID', sg['group_id'], copyable: true),
        ],
      ),
    );
  }

  Widget _buildConfigurationSection() {
    final tags = _instanceDetails!['tags'] as Map<String, dynamic>? ?? {};

    return _buildSection('Configuration', Icons.settings, [
      if (tags.isNotEmpty) ...[
        const Text(
          'Tags',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 8),
        ...tags.entries.map((tag) => _buildTag(tag.key, tag.value)),
      ] else
        Text(
          'No tags',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
    ]);
  }

  Widget _buildTag(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryPurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              key,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryPurple,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppTheme.ec2Color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppTheme.textPrimaryDark
                        : AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value, {bool copyable = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayValue = value?.toString() ?? 'N/A';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: isDark
                    ? AppTheme.textSecondaryDark
                    : AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    displayValue,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppTheme.textPrimaryDark
                          : AppTheme.textPrimary,
                    ),
                  ),
                ),
                if (copyable && displayValue != 'N/A')
                  IconButton(
                    icon: Icon(
                      Icons.copy,
                      size: 14,
                      color: isDark
                          ? AppTheme.textMutedDark
                          : AppTheme.textMuted,
                    ),
                    onPressed: () => _copyToClipboard(displayValue, label),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    tooltip: 'Copy',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubDetail(String label, dynamic value, {bool copyable = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayValue = value?.toString() ?? 'N/A';

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: isDark
                  ? AppTheme.textSecondaryDark
                  : AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
          Flexible(
            child: Text(
              displayValue,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (copyable && displayValue != 'N/A')
            IconButton(
              icon: Icon(
                Icons.copy,
                size: 12,
                color: isDark ? AppTheme.textMutedDark : AppTheme.textMuted,
              ),
              onPressed: () => _copyToClipboard(displayValue, label),
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              tooltip: 'Copy',
            ),
        ],
      ),
    );
  }
}
