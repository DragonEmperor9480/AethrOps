import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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
