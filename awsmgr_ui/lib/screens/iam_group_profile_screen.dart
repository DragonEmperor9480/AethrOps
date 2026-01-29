import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/loading_animation.dart';
import '../theme/app_theme.dart';
import '../utils/toast_utils.dart';

class IAMGroupProfileScreen extends StatefulWidget {
  final Map<String, dynamic> group;

  const IAMGroupProfileScreen({super.key, required this.group});

  @override
  State<IAMGroupProfileScreen> createState() => _IAMGroupProfileScreenState();
}

class _IAMGroupProfileScreenState extends State<IAMGroupProfileScreen> {
  Map<String, dynamic>? _dependencies;
  List<dynamic> _policies = [];
  bool _loading = true;
  bool _usersExpanded = false;
  bool _policiesExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadGroupDetails();
  }

  Future<void> _loadGroupDetails() async {
    setState(() => _loading = true);
    try {
      final groupname = widget.group['groupname'];
      final deps = await ApiService.checkGroupDependencies(groupname);
      final policies = await ApiService.listGroupPolicies(groupname);
      
      setState(() {
        _dependencies = deps;
        _policies = policies;
      });
    } catch (e) {
      _showError('Failed to load group details: $e');
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

  Future<void> _showAttachPoliciesDialog() async {
    final groupname = widget.group['groupname'];
    
    // Get currently attached policy ARNs
    final currentPolicyArns = _policies
        .map((p) => p['policy_arn']?.toString() ?? '')
        .where((arn) => arn.isNotEmpty)
        .toList();
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AttachGroupPoliciesDialog(
        groupname: groupname,
        currentPolicyArns: currentPolicyArns,
      ),
    );

    if (result != null) {
      final selectedArns = result['selected_arns'] as List<String>;
      final currentArns = result['current_arns'] as List<String>;

      // Show loading overlay
      setState(() => _loading = true);
      
      try {
        // Determine which policies to attach and detach
        final toAttach = selectedArns.where((arn) => !currentArns.contains(arn)).toList();
        final toDetach = currentArns.where((arn) => !selectedArns.contains(arn)).toList();

        int attachedCount = 0;
        int detachedCount = 0;

        // Attach new policies
        for (final arn in toAttach) {
          try {
            await ApiService.attachGroupPolicy(groupname, arn);
            attachedCount++;
          } catch (e) {
            _showError('Failed to attach policy: $e');
          }
        }

        // Detach removed policies
        for (final arn in toDetach) {
          try {
            await ApiService.detachGroupPolicy(groupname, arn);
            detachedCount++;
          } catch (e) {
            _showError('Failed to detach policy: $e');
          }
        }

        // Show success message
        if (attachedCount > 0 && detachedCount > 0) {
          _showSuccess('Attached $attachedCount, detached $detachedCount ${attachedCount + detachedCount == 1 ? 'policy' : 'policies'}');
        } else if (attachedCount > 0) {
          _showSuccess('Attached $attachedCount ${attachedCount == 1 ? 'policy' : 'policies'}');
        } else if (detachedCount > 0) {
          _showSuccess('Detached $detachedCount ${detachedCount == 1 ? 'policy' : 'policies'}');
        } else {
          _showSuccess('No changes needed');
        }

        await _loadGroupDetails();
      } catch (e) {
        _showError('Failed to sync policies: $e');
      } finally {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _showAddUsersDialog() async {
    final groupname = widget.group['groupname'];
    
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => AddUsersToGroupDialog(
        groupname: groupname,
        currentUsers: (_dependencies?['users'] as List?)?.cast<String>() ?? [],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() => _loading = true);
      
      try {
        int addedCount = 0;
        for (final username in result) {
          try {
            await ApiService.addUserToGroup(groupname, username);
            addedCount++;
          } catch (e) {
            _showError('Failed to add user $username: $e');
          }
        }

        if (addedCount > 0) {
          _showSuccess('Added $addedCount ${addedCount == 1 ? 'user' : 'users'} to group');
        }

        await _loadGroupDetails();
      } catch (e) {
        _showError('Failed to add users: $e');
      } finally {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupname = widget.group['groupname'] ?? '';
    final groupId = widget.group['group_id'] ?? '';
    final createDate = widget.group['create_date'] ?? '';
    final users = (_dependencies?['users'] as List?)?.cast<String>() ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(groupname),
        elevation: 0,
      ),
      body: _loading
          ? const LoadingAnimation(message: 'Loading group details...')
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Group Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade400, Colors.green.shade600],
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: Icon(
                            Icons.group,
                            size: 48,
                            color: Colors.green.shade600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          groupname,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'IAM Group',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Group Info Section
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Group Information'),
                        const SizedBox(height: 12),
                        _buildInfoCard([
                          _buildInfoRow(
                            Icons.fingerprint,
                            'Group ID',
                            groupId,
                          ),
                          _buildInfoRow(
                            Icons.calendar_today,
                            'Created',
                            createDate,
                          ),
                          _buildInfoRow(
                            Icons.people,
                            'Members',
                            '${users.length} ${users.length == 1 ? 'user' : 'users'}',
                          ),
                        ]),

                        const SizedBox(height: 24),

                        // Users Section
                        _buildCollapsibleSection(
                          title: 'Members',
                          count: users.length,
                          icon: Icons.people,
                          isExpanded: _usersExpanded,
                          onToggle: () => setState(() => _usersExpanded = !_usersExpanded),
                          emptyIcon: Icons.person_outlined,
                          emptyMessage: 'No users in this group',
                          isEmpty: users.isEmpty,
                          hasAction: true,
                          actionIcon: Icons.person_add,
                          actionLabel: 'Add',
                          onAction: _showAddUsersDialog,
                          child: Column(
                            children: users.map<Widget>((username) {
                              return _buildListItem(Icons.person, username);
                            }).toList(),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Attached Policies Section
                        _buildCollapsibleSection(
                          title: 'Attached Policies',
                          count: _policies.length,
                          icon: Icons.policy,
                          isExpanded: _policiesExpanded,
                          onToggle: () => setState(() => _policiesExpanded = !_policiesExpanded),
                          emptyIcon: Icons.policy_outlined,
                          emptyMessage: 'No policies attached',
                          isEmpty: _policies.isEmpty,
                          hasAction: true,
                          actionIcon: Icons.add,
                          actionLabel: 'Attach',
                          onAction: _showAttachPoliciesDialog,
                          child: Column(
                            children: _policies.map<Widget>((policy) {
                              final policyName = policy['policy_name']?.toString() ?? '';
                              final policyArn = policy['policy_arn']?.toString() ?? '';
                              return _buildListItem(Icons.policy, policyName, subtitle: policyArn);
                            }).toList(),
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.textTheme.bodyMedium?.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListItem(IconData icon, String title, {String? subtitle}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.successGreen.withValues(alpha: 0.2)
                  : Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: isDark ? AppTheme.successGreen : Colors.green.shade700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(icon, size: 48, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsibleSection({
    required String title,
    required int count,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onToggle,
    required IconData emptyIcon,
    required String emptyMessage,
    required bool isEmpty,
    Widget? child,
    bool hasAction = false,
    IconData? actionIcon,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          InkWell(
            onTap: isEmpty ? null : onToggle,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.successGreen.withValues(alpha: 0.2)
                          : AppTheme.successGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: AppTheme.successGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppTheme.textPrimaryDark
                                : AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          '$count ${count == 1 ? 'item' : 'items'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppTheme.textSecondaryDark
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasAction && onAction != null && !isEmpty)
                    IconButton(
                      icon: Icon(actionIcon ?? Icons.add, size: 18),
                      tooltip: actionLabel,
                      onPressed: onAction,
                      style: IconButton.styleFrom(
                        backgroundColor: isDark
                            ? AppTheme.primaryPurple.withValues(alpha: 0.2)
                            : AppTheme.purple100,
                        foregroundColor: isDark
                            ? AppTheme.primaryPurple
                            : AppTheme.purple700,
                      ),
                    ),
                  if (hasAction && onAction != null && !isEmpty)
                    const SizedBox(width: 8),
                  if (!isEmpty)
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: isDark
                          ? AppTheme.textSecondaryDark
                          : AppTheme.textSecondary,
                    ),
                ],
              ),
            ),
          ),
          if (isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark
                      ? theme.cardColor.withValues(alpha: 0.5)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(
                      emptyIcon,
                      size: 36,
                      color: theme.textTheme.bodyMedium?.color?.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      emptyMessage,
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color,
                        fontSize: 13,
                      ),
                    ),
                    if (hasAction && onAction != null)
                      const SizedBox(height: 12),
                    if (hasAction && onAction != null)
                      TextButton.icon(
                        onPressed: onAction,
                        icon: Icon(actionIcon ?? Icons.add, size: 16),
                        label: Text(actionLabel ?? 'Add'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primaryPurple,
                        ),
                      ),
                  ],
                ),
              ),
            )
          else if (isExpanded && child != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: child,
            ),
        ],
      ),
    );
  }
}


// Attach Group Policies Dialog
class AttachGroupPoliciesDialog extends StatefulWidget {
  final String groupname;
  final List<String> currentPolicyArns;

  const AttachGroupPoliciesDialog({
    super.key,
    required this.groupname,
    this.currentPolicyArns = const [],
  });

  @override
  State<AttachGroupPoliciesDialog> createState() => _AttachGroupPoliciesDialogState();
}

class _AttachGroupPoliciesDialogState extends State<AttachGroupPoliciesDialog> {
  List<dynamic> _policies = [];
  List<dynamic> _filteredPolicies = [];
  final Set<String> _selectedPolicyArns = {};
  final List<String> _currentPolicyArns = [];
  bool _loading = true;
  String _searchQuery = '';
  String _scopeFilter = 'All';

  @override
  void initState() {
    super.initState();
    // Store currently attached policy ARNs
    _currentPolicyArns.addAll(widget.currentPolicyArns);
    _selectedPolicyArns.addAll(widget.currentPolicyArns);
    _loadPolicies();
  }

  Future<void> _loadPolicies() async {
    setState(() => _loading = true);
    try {
      final policies = await ApiService.listIAMPolicies(scope: _scopeFilter);
      setState(() {
        _policies = policies;
        _filterPolicies();
      });
    } catch (e) {
      if (mounted) {
        ToastUtils.show(context, 'Failed to load policies: $e', isError: true);
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  void _filterPolicies() {
    setState(() {
      _filteredPolicies = _policies.where((policy) {
        final policyName = (policy['policy_name'] ?? '').toString().toLowerCase();
        final policyArn = (policy['policy_arn'] ?? '').toString().toLowerCase();
        final query = _searchQuery.toLowerCase();
        return policyName.contains(query) || policyArn.contains(query);
      }).toList();

      // Sort: attached policies first, then by name
      _filteredPolicies.sort((a, b) {
        final aArn = (a['policy_arn'] ?? '').toString();
        final bArn = (b['policy_arn'] ?? '').toString();
        final aAttached = _currentPolicyArns.contains(aArn);
        final bAttached = _currentPolicyArns.contains(bArn);

        // If one is attached and the other isn't, attached comes first
        if (aAttached && !bAttached) return -1;
        if (!aAttached && bAttached) return 1;

        // Otherwise sort by policy name
        final aName = (a['policy_name'] ?? '').toString();
        final bName = (b['policy_name'] ?? '').toString();
        return aName.compareTo(bName);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 700,
        height: 600,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.policy, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attach Policies',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        Text(
                          'Select policies to attach to ${widget.groupname}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Search and Filter
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search policies...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      _searchQuery = value;
                      _filterPolicies();
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Scope: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'All', label: Text('All')),
                          ButtonSegment(value: 'AWS', label: Text('AWS')),
                          ButtonSegment(value: 'Local', label: Text('Custom')),
                        ],
                        selected: {_scopeFilter},
                        onSelectionChanged: (Set<String> selected) {
                          setState(() => _scopeFilter = selected.first);
                          _loadPolicies();
                        },
                      ),
                      const Spacer(),
                      Text(
                        '${_selectedPolicyArns.length} selected',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Policies List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredPolicies.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.policy_outlined, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty ? 'No policies found' : 'No matching policies',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredPolicies.length,
                          itemBuilder: (context, index) {
                            final policy = _filteredPolicies[index];
                            final policyArn = policy['policy_arn']?.toString() ?? '';
                            final policyName = policy['policy_name']?.toString() ?? '';
                            final isAWSManaged = policy['is_aws_managed'] == true;
                            final isSelected = _selectedPolicyArns.contains(policyArn);
                            final isAlreadyAttached = _currentPolicyArns.contains(policyArn);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              color: isSelected ? AppTheme.successGreen.withValues(alpha: 0.1) : null,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: isSelected
                                    ? BorderSide(color: AppTheme.successGreen, width: 2)
                                    : BorderSide.none,
                              ),
                              child: CheckboxListTile(
                                value: isSelected,
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedPolicyArns.add(policyArn);
                                    } else {
                                      _selectedPolicyArns.remove(policyArn);
                                    }
                                  });
                                },
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        policyName,
                                        style: const TextStyle(fontWeight: FontWeight.w500),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (isAlreadyAttached)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.successGreen.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Attached',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: AppTheme.successGreen,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    if (isAWSManaged) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.warningAmber.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'AWS',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: AppTheme.warningAmber,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Text(
                                  policyArn,
                                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                dense: true,
                              ),
                            );
                          },
                        ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context, {
                          'selected_arns': _selectedPolicyArns.toList(),
                          'current_arns': _currentPolicyArns,
                        });
                      },
                      icon: const Icon(Icons.sync, size: 18),
                      label: const Text('Apply Changes'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// Add Users to Group Dialog
class AddUsersToGroupDialog extends StatefulWidget {
  final String groupname;
  final List<String> currentUsers;

  const AddUsersToGroupDialog({
    super.key,
    required this.groupname,
    this.currentUsers = const [],
  });

  @override
  State<AddUsersToGroupDialog> createState() => _AddUsersToGroupDialogState();
}

class _AddUsersToGroupDialogState extends State<AddUsersToGroupDialog> {
  List<dynamic> _users = [];
  List<dynamic> _filteredUsers = [];
  final Set<String> _selectedUsers = {};
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final users = await ApiService.listIAMUsers();
      setState(() {
        _users = users;
        _filterUsers();
      });
    } catch (e) {
      if (mounted) {
        ToastUtils.show(context, 'Failed to load users: $e', isError: true);
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  void _filterUsers() {
    setState(() {
      _filteredUsers = _users.where((user) {
        final username = (user['username'] ?? '').toString().toLowerCase();
        final query = _searchQuery.toLowerCase();
        // Filter out users already in the group
        final isInGroup = widget.currentUsers.contains(user['username']);
        return username.contains(query) && !isInGroup;
      }).toList();

      // Sort by username
      _filteredUsers.sort((a, b) {
        final aName = (a['username'] ?? '').toString();
        final bName = (b['username'] ?? '').toString();
        return aName.compareTo(bName);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 600,
        height: 600,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person_add, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Users to Group',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        Text(
                          'Select users to add to ${widget.groupname}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Search
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search users...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        _searchQuery = value;
                        _filterUsers();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_selectedUsers.length} selected',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Users List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredUsers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_outlined, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty 
                                    ? 'All users are already in this group' 
                                    : 'No matching users',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = _filteredUsers[index];
                            final username = user['username']?.toString() ?? '';
                            final userId = user['user_id']?.toString() ?? '';
                            final isSelected = _selectedUsers.contains(username);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              color: isSelected ? AppTheme.successGreen.withValues(alpha: 0.1) : null,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: isSelected
                                    ? BorderSide(color: AppTheme.successGreen, width: 2)
                                    : BorderSide.none,
                              ),
                              child: CheckboxListTile(
                                value: isSelected,
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedUsers.add(username);
                                    } else {
                                      _selectedUsers.remove(username);
                                    }
                                  });
                                },
                                title: Text(
                                  username,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                subtitle: Text(
                                  userId,
                                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                ),
                                secondary: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.iamColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.person, size: 20, color: AppTheme.iamColor),
                                ),
                                dense: true,
                              ),
                            );
                          },
                        ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _selectedUsers.isEmpty
                          ? null
                          : () {
                              Navigator.pop(context, _selectedUsers.toList());
                            },
                      icon: const Icon(Icons.person_add, size: 18),
                      label: Text('Add ${_selectedUsers.length} ${_selectedUsers.length == 1 ? 'User' : 'Users'}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
