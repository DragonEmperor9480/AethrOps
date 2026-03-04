import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ec2_launch_request.dart';
import '../services/ec2_service.dart';
import '../services/api_service.dart';
import '../providers/aws_config_provider.dart';
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
  List<dynamic> _amis = [];

  // Selections
  String? _selectedAmiId;
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
    _loadInitialData();
  }

  @override
  void dispose() {
    // Ensure no setState calls happen after widget is unmounted
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoadingData = true);
    try {
      // Get AWS config from provider
      final awsConfig = Provider.of<AwsConfigProvider>(context, listen: false);
      
      // Initialize if not already done (loads regions and current region in parallel)
      if (awsConfig.currentRegion == null) {
        await awsConfig.initialize();
      }
      
      setState(() {
        _regions = awsConfig.availableRegions;
        _selectedRegion = awsConfig.currentRegion;
      });
      
      // Load resources for the default region
      await _loadRegionResources();
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

  Future<void> _loadRegionResources() async {
    if (_selectedRegion == null) return;
    
    setState(() => _isLoadingData = true);
    try {
      final results = await Future.wait([
        Ec2Service.listKeyPairs(region: _selectedRegion),
        Ec2Service.listVpcs(region: _selectedRegion),
        Ec2Service.listSubnets(region: _selectedRegion),
        Ec2Service.listSecurityGroups(region: _selectedRegion),
        Ec2Service.listAMIs(region: _selectedRegion),
      ]);

      setState(() {
        _keyPairs = results[0] ?? [];
        _vpcs = results[1] ?? [];
        _subnets = results[2] ?? [];
        _securityGroups = results[3] ?? [];
        _amis = results[4] ?? [];
        _isLoadingData = false;

        // Reset selections when region changes
        _selectedKeyPair = null;
        _selectedVpc = null;
        _selectedSubnet = null;
        _selectedSecurityGroups.clear();
        _selectedAmiId = null;

        // Auto-select Default VPC, or first available
        if (_vpcs.isNotEmpty) {
          final defaultVpc = _vpcs.firstWhere(
            (vpc) => vpc['is_default'] == true,
            orElse: () => _vpcs.first,
          );
          _selectedVpc = defaultVpc['vpc_id'];
        }
        
        // Auto-select first AMI if available
        if (_amis.isNotEmpty && !_useCustomAmi) {
          _selectedAmiId = _amis.first['image_id'];
        }
      });
      
      // Show warnings for empty resources
      if (mounted) {
        if (_amis.isEmpty) {
          ToastUtils.show(
            context,
            'No AMIs found in $_selectedRegion. You can enter a custom AMI ID.',
            isError: false,
          );
        }
        if (_vpcs.isEmpty) {
          ToastUtils.show(
            context,
            'No VPCs found in $_selectedRegion. Please create a VPC first.',
            isError: true,
          );
        }
      }
    } catch (e) {
      setState(() => _isLoadingData = false);
      if (mounted) {
        ToastUtils.show(
          context,
          'Failed to load resources for region: $e',
          isError: true,
        );
      }
    }
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
    
    // Validate region is selected
    if (_selectedRegion == null) {
      ToastUtils.show(context, 'Please select a region', isError: true);
      return;
    }
    
    // Validate VPC exists
    if (_vpcs.isEmpty) {
      ToastUtils.show(
        context, 
        'No VPCs available in $_selectedRegion. Please create a VPC first.',
        isError: true,
      );
      return;
    }
    
    // Determine which AMI to use
    String amiId;
    if (_useCustomAmi) {
      if (_customAmiId.isEmpty) {
        ToastUtils.show(context, 'Please enter an AMI ID', isError: true);
        return;
      }
      amiId = _customAmiId;
    } else {
      if (_selectedAmiId == null) {
        if (_amis.isEmpty) {
          ToastUtils.show(
            context, 
            'No AMIs available. Please enter a custom AMI ID.',
            isError: true,
          );
          return;
        }
        ToastUtils.show(context, 'Please select an AMI', isError: true);
        return;
      }
      amiId = _selectedAmiId!;
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
                    // === Row 1: Name, Region, Instance Type ===
                    Text(
                      'Basic Configuration',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Instance Name (full width)
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Instance Name',
                        hintText: 'My-Web-Server',
                        border: const OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: primaryColor, width: 2),
                        ),
                        prefixIcon: const Icon(Icons.label_outline),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                      onChanged: (val) => _instanceName = val,
                    ),
                    const SizedBox(height: 16),
                    
                    // Region and Instance Type side by side
                    Row(
                      children: [
                        // Region
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedRegion,
                            isExpanded: true,
                            menuMaxHeight: 300,
                            decoration: InputDecoration(
                              labelText: 'Region',
                              border: const OutlineInputBorder(),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: primaryColor, width: 2),
                              ),
                              prefixIcon: Icon(Icons.public, size: 20),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            ),
                            items: _regions.map((region) {
                              return DropdownMenuItem<String>(
                                value: region,
                                child: Text(region, style: const TextStyle(fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null && val != _selectedRegion) {
                                setState(() => _selectedRegion = val);
                                _loadRegionResources();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Instance Type
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _instanceType,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Instance Type',
                              border: const OutlineInputBorder(),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: primaryColor, width: 2),
                              ),
                              prefixIcon: Icon(Icons.memory, size: 20),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            ),
                            items: _instanceTypes.map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(
                                  type,
                                  style: const TextStyle(fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => _instanceType = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // === Row 2: AMI and Key Pair ===
                    Text(
                      'AMI & Authentication',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // AMI Selector
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_useCustomAmi)
                                TextFormField(
                                  decoration: InputDecoration(
                                    labelText: 'AMI ID',
                                    hintText: 'ami-xxxxx',
                                    border: const OutlineInputBorder(),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: primaryColor, width: 2),
                                    ),
                                    prefixIcon: const Icon(Icons.image, size: 20),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                  ),
                                  onChanged: (val) => _customAmiId = val,
                                  validator: (val) {
                                    if (_useCustomAmi && (val == null || val.isEmpty)) {
                                      return 'Enter AMI ID';
                                    }
                                    if (_useCustomAmi && !val!.startsWith('ami-')) {
                                      return 'Must start with "ami-"';
                                    }
                                    return null;
                                  },
                                )
                              else
                                _amis.isEmpty
                                  ? Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.orange),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.warning, color: Colors.orange, size: 20),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'No AMIs found',
                                              style: TextStyle(color: Colors.orange, fontSize: 12),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : DropdownButtonFormField<String>(
                                      value: _selectedAmiId,
                                      isExpanded: true,
                                      menuMaxHeight: 300,
                                      decoration: InputDecoration(
                                        labelText: 'AMI',
                                        border: const OutlineInputBorder(),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(color: primaryColor, width: 2),
                                        ),
                                        prefixIcon: const Icon(Icons.image, size: 20),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                      ),
                                      items: _amis.map((ami) {
                                        return DropdownMenuItem<String>(
                                          value: ami['image_id'],
                                          child: Text(
                                            ami['name'] ?? ami['image_id'],
                                            style: const TextStyle(fontSize: 13),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) => setState(() => _selectedAmiId = val),
                                      validator: (val) {
                                        if (!_useCustomAmi && val == null) {
                                          return 'Select AMI';
                                        }
                                        return null;
                                      },
                                    ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () => setState(() => _useCustomAmi = !_useCustomAmi),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _useCustomAmi ? Icons.check_box : Icons.check_box_outline_blank,
                                        size: 18,
                                        color: primaryColor,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Custom AMI',
                                        style: TextStyle(fontSize: 12, color: primaryColor),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Key Pair
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonFormField<String>(
                                value: _selectedKeyPair,
                                isExpanded: true,
                                menuMaxHeight: 300,
                                decoration: InputDecoration(
                                  labelText: 'Key Pair',
                                  border: const OutlineInputBorder(),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: primaryColor, width: 2),
                                  ),
                                  prefixIcon: const Icon(Icons.vpn_key, size: 20),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                ),
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: null,
                                    child: Text(
                                      'None',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  ..._keyPairs.map((kp) {
                                    return DropdownMenuItem<String>(
                                      value: kp['key_name'],
                                      child: Text(
                                        kp['key_name'],
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (val) => setState(() => _selectedKeyPair = val),
                              ),
                              if (_keyPairs.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    'No key pairs found',
                                    style: TextStyle(fontSize: 11, color: Colors.blue),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // === Configure Storage ===
                    Text(
                      'Configure Storage',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
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
                            _vpcs.isEmpty
                              ? Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.red),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.error, color: Colors.red),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'No VPCs found in $_selectedRegion. Please create a VPC first.',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : DropdownButtonFormField<String>(
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
