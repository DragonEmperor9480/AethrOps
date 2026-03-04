import 'package:flutter/material.dart';
import '../models/ec2_launch_request.dart';
import '../services/ec2_service.dart';
import '../theme/app_theme.dart';
import '../utils/toast_utils.dart';

class Ec2LaunchScreen extends StatefulWidget {
  const Ec2LaunchScreen({super.key});

  @override
  State<Ec2LaunchScreen> createState() => _Ec2LaunchScreenState();
}

class _Ec2LaunchScreenState extends State<Ec2LaunchScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isLoadingData = true;

  // Data Lists
  List<dynamic> _keyPairs = [];
  List<dynamic> _subnets = [];
  List<dynamic> _vpcs = [];
  List<dynamic> _securityGroups = [];
  List<String> _regions = [];

  // Selections
  AmiOption? _selectedAmi;
  String _instanceName = '';
  String _instanceType = 't2.micro';
  String? _selectedKeyPair;
  String? _selectedVpc;
  String? _selectedSubnet;
  final List<String> _selectedSecurityGroups = [];
  String? _selectedRegion;
  String _customAmiId = '';
  bool _useCustomAmi = false;

  String _userData = '';
  int _storageSize = 8; // Default 8 GB
  String _volumeType = 'gp3';

  // Hardcoded AMIs
  final List<AmiOption> _amiOptions = [
    const AmiOption(
      name: 'Amazon Linux 2023',
      imageId: 'ami-08d7aabbb50c2c24e',
      description:
          'Amazon Linux 2023 AMI 2023.3.20240131.0 x86_64 HVM kernel-6.1',
      architecture: 'x86_64',
      assetPath: 'assets/ami-assets/Amazon_Web_Services_Logo.svg.png',
    ),
    const AmiOption(
      name: 'Ubuntu Server 22.04 LTS',
      imageId: 'ami-0ecb62995f68bb549',
      description:
          'Canonical, Ubuntu, 22.04 LTS, amd64 jammy image build on 2023-12-07',
      architecture: 'x86_64',
      assetPath: 'assets/ami-assets/Logo-ubuntu_cof-orange-hex.svg.png',
    ),
  ];

  // Hardcoded Instance Types for now
  final List<String> _instanceTypes = [
    't2.micro',
    't2.small',
    't2.medium',
    't3.micro',
    't3.small',
    't3.medium',
  ];

  @override
  void initState() {
    super.initState();
    _selectedAmi = _amiOptions[0];
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoadingData = true);
    try {
      final results = await Future.wait([
        Ec2Service.listKeyPairs(),
        Ec2Service.listVpcs(),
        Ec2Service.listSubnets(),
        Ec2Service.listSecurityGroups(),
        Ec2Service.listRegions(),
      ]);

      setState(() {
        _keyPairs = results[0];
        _vpcs = results[1];
        _subnets = results[2];
        _securityGroups = results[3];
        _regions = List<String>.from(results[4]);
        _isLoadingData = false;

        // Auto-select Default VPC, or first available
        if (_vpcs.isNotEmpty) {
          final defaultVpc = _vpcs.firstWhere(
            (vpc) => vpc['is_default'] == true,
            orElse: () => _vpcs.first,
          );
          _selectedVpc = defaultVpc['vpc_id'];
        }
      });
    } catch (e) {
      setState(() => _isLoadingData = false);
      if (mounted) {
        ToastUtils.show(
          context,
          'Failed to load AWS resources: $e',
          isError: true,
        );
      }
    }
  }

  Future<void> _launchInstance() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Determine which AMI to use
    String amiId;
    if (_useCustomAmi) {
      if (_customAmiId.isEmpty) {
        ToastUtils.show(context, 'Please enter an AMI ID', isError: true);
        return;
      }
      amiId = _customAmiId;
    } else {
      if (_selectedAmi == null) {
        ToastUtils.show(context, 'Please select an AMI', isError: true);
        return;
      }
      amiId = _selectedAmi!.imageId;
    }

    setState(() => _isLoading = true);

    try {
      final request = Ec2LaunchRequest(
        imageId: amiId,
        instanceType: _instanceType,
        keyName: _selectedKeyPair,
        subnetId: _selectedSubnet,
        securityGroupIds: _selectedSecurityGroups.isNotEmpty
            ? _selectedSecurityGroups
            : null,
        userData: _userData,
        tags: {'Name': _instanceName.isEmpty ? 'New-Instance' : _instanceName},
        volumeSize: _storageSize,
        volumeType: _volumeType,
        minCount: 1,
        maxCount: 1,
        region: _selectedRegion,
      );

      final result = await Ec2Service.launchInstance(request);

      if (mounted) {
        ToastUtils.show(
          context,
          'Instance is booting up... ID: ${result['instance_id']}',
          isError: false,
        );
        Navigator.pop(context); // Return to previous screen
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.show(context, 'Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Theme colors
    final primaryColor = AppTheme.ec2Color;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Launch EC2 Instance'),
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: _isLoadingData
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // === 1. Name & AMI ===
                    Text(
                      'Name and AMI',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Instance Name',
                        hintText: 'My-Web-Server',
                        border: const OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: primaryColor, width: 2),
                        ),
                        prefixIcon: const Icon(Icons.label_outline),
                      ),
                      onChanged: (val) => _instanceName = val,
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Select AMI',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    
                    // Warning for non-default region
                    if (_selectedRegion != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.warningAmber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.warningAmber.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: AppTheme.warningAmber,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'AMI IDs are region-specific. The pre-selected AMIs may not work in ${_selectedRegion}. Use custom AMI ID for other regions.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.warningAmber,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // Toggle for custom AMI
                    SwitchListTile(
                      title: const Text('Use Custom AMI ID'),
                      subtitle: const Text('Enter AMI ID manually'),
                      value: _useCustomAmi,
                      onChanged: (value) => setState(() => _useCustomAmi = value),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 12),
                    
                    if (_useCustomAmi)
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'AMI ID',
                          hintText: 'ami-xxxxxxxxxxxxxxxxx',
                          border: const OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: primaryColor, width: 2),
                          ),
                          prefixIcon: const Icon(Icons.image),
                        ),
                        onChanged: (val) => _customAmiId = val,
                        validator: (val) {
                          if (_useCustomAmi && (val == null || val.isEmpty)) {
                            return 'Please enter an AMI ID';
                          }
                          if (_useCustomAmi && !val!.startsWith('ami-')) {
                            return 'AMI ID must start with "ami-"';
                          }
                          return null;
                        },
                      )
                    else
                      SizedBox(
                        height: 220,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _amiOptions.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final ami = _amiOptions[index];
                            final isSelected = _selectedAmi == ami;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedAmi = ami),
                              child: Container(
                                width: 180,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? primaryColor.withOpacity(0.1)
                                      : Theme.of(context).cardColor,
                                  border: Border.all(
                                    color: isSelected
                                        ? primaryColor
                                        : Theme.of(context).dividerColor,
                                    width: isSelected ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.05),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: ami.assetPath != null
                                          ? Image.asset(
                                              ami.assetPath!,
                                              fit: BoxFit.contain,
                                            )
                                          : Icon(
                                              Icons.computer,
                                              color: isSelected
                                                  ? primaryColor
                                                  : Colors.grey,
                                              size: 28,
                                            ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      ami.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Expanded(
                                      child: Center(
                                        child: Text(
                                          ami.description,
                                          textAlign: TextAlign.center,
                                          maxLines: 4,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(fontSize: 10),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Chip(
                                      label: Text(ami.architecture),
                                      labelStyle: const TextStyle(fontSize: 10),
                                      visualDensity: VisualDensity.compact,
                                      backgroundColor: isSelected
                                          ? primaryColor.withOpacity(0.2)
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 32),

                    // === 2. Instance Type ===
                    Text(
                      'Instance Type',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _instanceType,
                      decoration: InputDecoration(
                        labelText: 'Instance Type',
                        border: const OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: primaryColor, width: 2),
                        ),
                      ),
                      items: _instanceTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(
                            type +
                                (type == 't2.micro'
                                    ? ' (Free Tier eligible)'
                                    : ''),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _instanceType = val!),
                    ),
                    const SizedBox(height: 32),

                    // === 2.5. Region Selection ===
                    Text(
                      'Region',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String?>(
                      value: _selectedRegion,
                      decoration: InputDecoration(
                        labelText: 'Launch Region',
                        helperText: 'Leave empty to use current region',
                        border: const OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: primaryColor, width: 2),
                        ),
                        prefixIcon: const Icon(Icons.public),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Current Region (Default)'),
                        ),
                        ..._regions.map((region) {
                          return DropdownMenuItem<String>(
                            value: region,
                            child: Text(region),
                          );
                        }),
                      ],
                      onChanged: (val) => setState(() => _selectedRegion = val),
                    ),
                    const SizedBox(height: 32),

                    // === 3. Key Pair ===
                    Text(
                      'Key Pair (Login)',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedKeyPair,
                      decoration: InputDecoration(
                        labelText: 'Key Pair name',
                        helperText:
                            'Select a key pair to securely connect to your instance',
                        border: const OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: primaryColor, width: 2),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text(
                            'Proceed without a key pair (Not recommended)',
                          ),
                        ),
                        ..._keyPairs.map((kp) {
                          return DropdownMenuItem<String>(
                            value: kp['key_name'],
                            child: Text(kp['key_name']),
                          );
                        }),
                      ],
                      onChanged: (val) =>
                          setState(() => _selectedKeyPair = val),
                    ),
                    const SizedBox(height: 32),

                    // === 4. Configure Storage ===
                    Text(
                      'Configure Storage',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.storage, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Root Volume',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Size (GiB)',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelMedium,
                                      ),
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        initialValue: _storageSize.toString(),
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          border: OutlineInputBorder(),
                                          suffixText: 'GiB',
                                          helperText:
                                              'Free tier eligible up to 30 GiB',
                                        ),
                                        onChanged: (val) {
                                          final size = int.tryParse(val);
                                          if (size != null) {
                                            setState(() => _storageSize = size);
                                          }
                                        },
                                        validator: (val) {
                                          final size = int.tryParse(val ?? '');
                                          if (size == null || size < 8) {
                                            return 'Min 8 GiB';
                                          }
                                          if (size > 16384) {
                                            return 'Max 16 TiB';
                                          }
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Volume Type',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelMedium,
                                      ),
                                      const SizedBox(height: 8),
                                      DropdownButtonFormField<String>(
                                        value: _volumeType,
                                        isExpanded: true,
                                        decoration: const InputDecoration(
                                          border: OutlineInputBorder(),
                                          helperText: ' ', // Maintain alignment
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical:
                                                16, // Match height of TextFormField
                                          ),
                                        ),
                                        items:
                                            [
                                                  'gp3',
                                                  'gp2',
                                                  'io1',
                                                  'io2',
                                                  'sc1',
                                                  'st1',
                                                  'standard',
                                                ]
                                                .map(
                                                  (type) => DropdownMenuItem(
                                                    value: type,
                                                    child: Text(
                                                      type,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() => _volumeType = val);
                                          }
                                        },
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
                    const SizedBox(height: 32),

                    // === 5. Network Settings ===
                    Text(
                      'Network Settings',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            // VPC
                            DropdownButtonFormField<String>(
                              initialValue: _selectedVpc,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'VPC',
                                border: OutlineInputBorder(),
                              ),
                              items: _vpcs.map((vpc) {
                                final name = vpc['name'] != ''
                                    ? ' (${vpc['name']})'
                                    : '';
                                final isDefault = vpc['is_default'] == true;
                                return DropdownMenuItem<String>(
                                  value: vpc['vpc_id'],
                                  child: Text(
                                    '${vpc['vpc_id']}$name${isDefault ? ' (Default)' : ''}',
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedVpc = val;
                                  _selectedSubnet =
                                      null; // Reset subnet on VPC change
                                });
                              },
                            ),
                            const SizedBox(height: 16),

                            // Subnet
                            DropdownButtonFormField<String?>(
                              initialValue: _selectedSubnet,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Subnet',
                                helperText:
                                    'Leave empty for no preference (Auto-assign Public IP)',
                                border: OutlineInputBorder(),
                              ),
                              // Filter subnets by selected VPC
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('No Preference'),
                                ),
                                ..._subnets
                                    .where((s) => s['vpc_id'] == _selectedVpc)
                                    .map((sn) {
                                      final name = sn['name'] != ''
                                          ? ' (${sn['name']})'
                                          : '';
                                      return DropdownMenuItem<String?>(
                                        value: sn['subnet_id'],
                                        child: Text(
                                          '${sn['subnet_id']} - ${sn['availability_zone']}$name',
                                        ),
                                      );
                                    }),
                              ],
                              onChanged: (val) =>
                                  setState(() => _selectedSubnet = val),
                            ),
                            const SizedBox(height: 16),

                            // Security Groups (Simple Multi-select Dialog Trigger)
                            InkWell(
                              onTap: () async {
                                final availableSgs = _securityGroups
                                    .where((sg) => sg['vpc_id'] == _selectedVpc)
                                    .toList();

                                await showDialog(
                                  context: context,
                                  builder: (context) {
                                    return StatefulBuilder(
                                      builder: (context, setDialogState) {
                                        return AlertDialog(
                                          title: const Text(
                                            'Select Security Groups',
                                          ),
                                          content: SizedBox(
                                            width: double.maxFinite,
                                            child: availableSgs.isEmpty
                                                ? const Padding(
                                                    padding: EdgeInsets.all(
                                                      16.0,
                                                    ),
                                                    child: Text(
                                                      'No security groups found for this VPC.',
                                                      style: TextStyle(
                                                        fontStyle:
                                                            FontStyle.italic,
                                                      ),
                                                    ),
                                                  )
                                                : ListView.builder(
                                                    shrinkWrap: true,
                                                    itemCount:
                                                        availableSgs.length,
                                                    itemBuilder: (context, index) {
                                                      final sg =
                                                          availableSgs[index];
                                                      final id = sg['group_id'];
                                                      final isSelected =
                                                          _selectedSecurityGroups
                                                              .contains(id);
                                                      return CheckboxListTile(
                                                        title: Text(
                                                          sg['group_name'],
                                                        ),
                                                        subtitle: Text(id),
                                                        value: isSelected,
                                                        onChanged: (bool? value) {
                                                          setDialogState(() {
                                                            if (value == true) {
                                                              _selectedSecurityGroups
                                                                  .add(id);
                                                            } else {
                                                              _selectedSecurityGroups
                                                                  .remove(id);
                                                            }
                                                          });
                                                        },
                                                      );
                                                    },
                                                  ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: const Text('Done'),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                );
                                // Update parent UI to show correct count
                                setState(() {});
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Security Groups',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.arrow_drop_down),
                                ),
                                child: Text(
                                  _selectedSecurityGroups.isEmpty
                                      ? 'Select Security Groups'
                                      : '${_selectedSecurityGroups.length} selected',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // === 5. Advanced (User Data) ===
                    ExpansionTile(
                      title: const Text('Advanced Details'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: TextFormField(
                            maxLines: 5,
                            decoration: const InputDecoration(
                              labelText: 'User Data (Optional)',
                              hintText: '#!/bin/bash\nyum update -y',
                              border: OutlineInputBorder(),
                              alignLabelWithHint: true,
                            ),
                            onChanged: (val) => _userData = val,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),

                    // === Launch Button ===
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _launchInstance,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.black, // Dark text on orange
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 3,
                                ),
                              )
                            : const Text(
                                'Launch Instance',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}
