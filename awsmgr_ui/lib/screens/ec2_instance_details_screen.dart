import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../widgets/loading_animation.dart';
import '../theme/app_theme.dart';

class EC2InstanceDetailsScreen extends StatefulWidget {
  final String instanceId;
  final String instanceName;
  final String state;

  const EC2InstanceDetailsScreen({
    super.key,
    required this.instanceId,
    required this.instanceName,
    required this.state,
  });

  @override
  State<EC2InstanceDetailsScreen> createState() => _EC2InstanceDetailsScreenState();
}

class _EC2InstanceDetailsScreenState extends State<EC2InstanceDetailsScreen> {
  Map<String, dynamic>? _instanceDetails;
  bool _loading = true;
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
      final details = await ApiService.getEC2Instance(widget.instanceId);
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
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
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Instance Details'),
        elevation: 0,
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInstanceDetails,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const LoadingAnimation(message: 'Loading instance details')
          : _error != null
              ? _buildErrorState()
              : _buildDetailsContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppTheme.errorRed),
          const SizedBox(height: 16),
          Text(
            'Failed to load instance details',
            style: TextStyle(fontSize: 18, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
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
                      widget.instanceName.isEmpty || widget.instanceName == 'N/A'
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
                              color: AppTheme.textSecondary,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          onPressed: () => _copyToClipboard(widget.instanceId, 'Instance ID'),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              _buildQuickInfo(Icons.computer, _instanceDetails!['instance_type'] ?? 'N/A'),
              _buildQuickInfo(Icons.architecture, _instanceDetails!['architecture'] ?? 'N/A'),
              _buildQuickInfo(Icons.laptop_chromebook, _instanceDetails!['platform'] ?? 'N/A'),
              _buildQuickInfo(Icons.access_time, _instanceDetails!['launch_time'] ?? 'N/A'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
        ),
      ],
    );
  }

  Widget _buildOverviewSection() {
    return _buildSection(
      'Overview',
      Icons.info_outline,
      [
        _buildDetailRow('Instance Type', _instanceDetails!['instance_type']),
        _buildDetailRow('AMI ID', _instanceDetails!['image_id'], copyable: true),
        _buildDetailRow('Key Pair', _instanceDetails!['key_name'] ?? 'None'),
        _buildDetailRow('Availability Zone', _instanceDetails!['availability_zone']),
        _buildDetailRow('Launch Time', _instanceDetails!['launch_time']),
        _buildDetailRow('Monitoring', _instanceDetails!['monitoring_state']),
        _buildDetailRow('Virtualization Type', _instanceDetails!['virtualization_type']),
        if (_instanceDetails!['instance_lifecycle']?.toString().isNotEmpty == true)
          _buildDetailRow('Lifecycle', _instanceDetails!['instance_lifecycle']),
      ],
    );
  }

  Widget _buildNetworkSection() {
    final publicIp = _instanceDetails!['public_ip'] ?? 'None';
    final privateIp = _instanceDetails!['private_ip'] ?? 'None';
    final interfaces = _instanceDetails!['network_interfaces'] as List<dynamic>? ?? [];

    return _buildSection(
      'Network & Security',
      Icons.public,
      [
        _buildDetailRow('VPC ID', _instanceDetails!['vpc_id'], copyable: true),
        _buildDetailRow('Subnet ID', _instanceDetails!['subnet_id'], copyable: true),
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
      ],
    );
  }

  Widget _buildNetworkInterface(Map<String, dynamic> ni) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSubDetail('Interface ID', ni['network_interface_id'], copyable: true),
          _buildSubDetail('MAC Address', ni['mac_address']),
          _buildSubDetail('Private IP', ni['private_ip']),
          if (ni['public_ip'] != null) _buildSubDetail('Public IP', ni['public_ip']),
        ],
      ),
    );
  }

  Widget _buildStorageSection() {
    final blockDevices = _instanceDetails!['block_devices'] as List<dynamic>? ?? [];

    return _buildSection(
      'Storage',
      Icons.storage,
      [
        _buildDetailRow('Root Device Type', _instanceDetails!['root_device_type']),
        _buildDetailRow('Root Device Name', _instanceDetails!['root_device_name']),
        if (blockDevices.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'Block Devices',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          ...blockDevices.map((device) => _buildBlockDevice(device)),
        ],
      ],
    );
  }

  Widget _buildBlockDevice(Map<String, dynamic> device) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
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
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildSubDetail('Volume ID', device['volume_id'], copyable: true),
          _buildSubDetail('Status', device['status']),
          _buildSubDetail('Attached', device['attach_time']),
          _buildSubDetail('Delete on Termination', device['delete_on_termination'].toString()),
        ],
      ),
    );
  }

  Widget _buildSecuritySection() {
    final securityGroups = _instanceDetails!['security_groups'] as List<dynamic>? ?? [];

    return _buildSection(
      'Security',
      Icons.security,
      [
        if (securityGroups.isNotEmpty) ...[
          const Text(
            'Security Groups',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          ...securityGroups.map((sg) => _buildSecurityGroup(sg)),
        ] else
          const Text('No security groups', style: TextStyle(color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildSecurityGroup(Map<String, dynamic> sg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
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

    return _buildSection(
      'Configuration',
      Icons.settings,
      [
        if (tags.isNotEmpty) ...[
          const Text(
            'Tags',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          ...tags.entries.map((tag) => _buildTag(tag.key, tag.value)),
        ] else
          const Text('No tags', style: TextStyle(color: AppTheme.textSecondary)),
      ],
    );
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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
              style: const TextStyle(
                color: AppTheme.textSecondary,
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
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (copyable && displayValue != 'N/A')
                  IconButton(
                    icon: const Icon(Icons.copy, size: 14),
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
    final displayValue = value?.toString() ?? 'N/A';
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
          Flexible(
            child: Text(
              displayValue,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (copyable && displayValue != 'N/A')
            IconButton(
              icon: const Icon(Icons.copy, size: 12),
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
