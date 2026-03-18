import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/loading_animation.dart';
import '../theme/app_theme.dart';
import '../utils/toast_utils.dart';

class IAMUserProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const IAMUserProfileScreen({super.key, required this.user});

  @override
  State<IAMUserProfileScreen> createState() => _IAMUserProfileScreenState();
}

class _IAMUserProfileScreenState extends State<IAMUserProfileScreen> {
  Map<String, dynamic>? _dependencies;
  List<dynamic> _groups = [];
  bool _loading = true;

  // Expansion states for collapsible sections
  bool _groupsExpanded = false;
  bool _accessKeysExpanded = false;
  bool _managedPoliciesExpanded = false;
  bool _inlinePoliciesExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
  }

  Future<void> _loadUserDetails() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final username = widget.user['username'];
      final deps = await ApiService.checkUserDependencies(username);
      final groups = await ApiService.getUserGroups(username);

      if (!mounted) return;
      setState(() {
        _dependencies = deps;
        _groups = groups;
      });
    } catch (e) {
      if (mounted) {
        _showError('Failed to load user details: $e');
      }
    } finally {
      if (!mounted) return;
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
    final username = widget.user['username'];

    // Get currently attached policy names (not ARNs)
    final currentPolicyNames =
        (_dependencies?['managed_policies'] as List?)
            ?.map((p) => p.toString())
            .toList() ??
        [];

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AttachPoliciesDialog(
        username: username,
        currentPolicyNames: currentPolicyNames,
      ),
    );

    if (result != null) {
      final selectedArns = result['selected_arns'] as List<String>;
      final currentArns = result['current_arns'] as List<String>;

      if (!mounted) return;
      setState(() => _loading = true);
      try {
        final response = await ApiService.syncUserPolicies(
          username,
          selectedArns,
          currentArns,
        );

        final attachedCount = response['attached_count'] ?? 0;
        final detachedCount = response['detached_count'] ?? 0;
        final success = response['success'] ?? false;

        if (mounted) {
          if (success) {
            if (attachedCount > 0 && detachedCount > 0) {
              _showSuccess(
                'Attached $attachedCount, detached $detachedCount ${attachedCount + detachedCount == 1 ? 'policy' : 'policies'}',
              );
            } else if (attachedCount > 0) {
              _showSuccess(
                'Attached $attachedCount ${attachedCount == 1 ? 'policy' : 'policies'}',
              );
            } else if (detachedCount > 0) {
              _showSuccess(
                'Detached $detachedCount ${detachedCount == 1 ? 'policy' : 'policies'}',
              );
            } else {
              _showSuccess('No changes needed');
            }
          } else {
            _showError('Some operations failed. Check details.');
          }
        }

        await _loadUserDetails();
      } catch (e) {
        if (mounted) {
          _showError('Failed to sync policies: $e');
        }
      } finally {
        if (!mounted) return;
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final username = widget.user['username'] ?? '';
    final userId = widget.user['user_id'] ?? '';
    final createDate = widget.user['create_date'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(username),
        elevation: 0,
        backgroundColor: isDark
            ? AppTheme.cardBackgroundDark
            : AppTheme.cardBackground,
      ),
      body: _loading
          ? const LoadingAnimation(message: 'Loading user details...')
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppTheme.primaryPurple, AppTheme.purple600],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Avatar with glow
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(44),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.3),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            size: 52,
                            color: AppTheme.purple600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Username
                        Text(
                          username,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_user_rounded,
                                size: 16,
                                color: Colors.white.withValues(alpha: 0.95),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'IAM User',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // User Info Section
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('User Information'),
                        const SizedBox(height: 12),
                        _buildInfoCard([
                          _buildInfoRow(Icons.fingerprint, 'User ID', userId),
                          _buildInfoRow(
                            Icons.calendar_today,
                            'Created',
                            createDate,
                          ),
                          _buildInfoRow(
                            Icons.login,
                            'Login Profile',
                            _dependencies?['has_login_profile'] == true
                                ? 'Enabled'
                                : 'Disabled',
                            valueColor:
                                _dependencies?['has_login_profile'] == true
                                ? Colors.green
                                : Colors.grey,
                          ),
                        ]),

                        const SizedBox(height: 24),

                        // Groups Section
                        _buildCollapsibleSection(
                          title: 'Groups',
                          count: _groups.length,
                          icon: Icons.group,
                          isExpanded: _groupsExpanded,
                          onToggle: () => setState(
                            () => _groupsExpanded = !_groupsExpanded,
                          ),
                          emptyIcon: Icons.group_outlined,
                          emptyMessage: 'Not a member of any groups',
                          isEmpty: _groups.isEmpty,
                          child: _groups.isEmpty
                              ? null
                              : Column(
                                  children: _groups.map<Widget>((group) {
                                    return _buildListItem(
                                      Icons.group,
                                      group.toString(),
                                    );
                                  }).toList(),
                                ),
                        ),

                        const SizedBox(height: 16),

                        // Access Keys Section
                        _buildCollapsibleSection(
                          title: 'Access Keys',
                          count:
                              (_dependencies?['access_keys'] as List?)
                                  ?.length ??
                              0,
                          icon: Icons.vpn_key,
                          isExpanded: _accessKeysExpanded,
                          onToggle: () => setState(
                            () => _accessKeysExpanded = !_accessKeysExpanded,
                          ),
                          emptyIcon: Icons.vpn_key_outlined,
                          emptyMessage: 'No access keys',
                          isEmpty:
                              (_dependencies?['access_keys'] as List?)
                                  ?.isEmpty ??
                              true,
                          child:
                              (_dependencies?['access_keys'] as List?)
                                      ?.isEmpty ??
                                  true
                              ? null
                              : Column(
                                  children:
                                      (_dependencies!['access_keys'] as List)
                                          .map<Widget>((key) {
                                            return _buildListItem(
                                              Icons.vpn_key,
                                              key.toString(),
                                            );
                                          })
                                          .toList(),
                                ),
                        ),

                        const SizedBox(height: 16),

                        // Managed Policies Section
                        _buildCollapsibleSection(
                          title: 'Managed Policies',
                          count:
                              (_dependencies?['managed_policies'] as List?)
                                  ?.length ??
                              0,
                          icon: Icons.policy,
                          isExpanded: _managedPoliciesExpanded,
                          onToggle: () => setState(
                            () => _managedPoliciesExpanded =
                                !_managedPoliciesExpanded,
                          ),
                          emptyIcon: Icons.policy_outlined,
                          emptyMessage: 'No managed policies attached',
                          isEmpty:
                              (_dependencies?['managed_policies'] as List?)
                                  ?.isEmpty ??
                              true,
                          hasAction: true,
                          actionIcon: Icons.add,
                          actionLabel: 'Attach',
                          onAction: _showAttachPoliciesDialog,
                          child:
                              (_dependencies?['managed_policies'] as List?)
                                      ?.isEmpty ??
                                  true
                              ? null
                              : Column(
                                  children:
                                      (_dependencies!['managed_policies']
                                              as List)
                                          .map<Widget>((policy) {
                                            return _buildListItem(
                                              Icons.policy,
                                              policy.toString(),
                                            );
                                          })
                                          .toList(),
                                ),
                        ),

                        const SizedBox(height: 16),

                        // Inline Policies Section
                        _buildCollapsibleSection(
                          title: 'Inline Policies',
                          count:
                              (_dependencies?['inline_policies'] as List?)
                                  ?.length ??
                              0,
                          icon: Icons.description,
                          isExpanded: _inlinePoliciesExpanded,
                          onToggle: () => setState(
                            () => _inlinePoliciesExpanded =
                                !_inlinePoliciesExpanded,
                          ),
                          emptyIcon: Icons.description_outlined,
                          emptyMessage: 'No inline policies',
                          isEmpty:
                              (_dependencies?['inline_policies'] as List?)
                                  ?.isEmpty ??
                              true,
                          child:
                              (_dependencies?['inline_policies'] as List?)
                                      ?.isEmpty ??
                                  true
                              ? null
                              : Column(
                                  children:
                                      (_dependencies!['inline_policies']
                                              as List)
                                          .map<Widget>((policy) {
                                            return _buildListItem(
                                              Icons.description,
                                              policy.toString(),
                                            );
                                          })
                                          .toList(),
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
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                          ? AppTheme.primaryBlue.withValues(alpha: 0.2)
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: isDark
                          ? AppTheme.primaryBlue
                          : Colors.blue.shade700,
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

  Widget _buildInfoCard(List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBackgroundDark : AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? AppTheme.purple600.withValues(alpha: 0.2)
              : AppTheme.purple200,
          width: 1.5,
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.primaryPurple.withValues(alpha: 0.15)
                  : AppTheme.purple100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isDark ? AppTheme.primaryPurple : AppTheme.purple700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppTheme.textMutedDark : AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color:
                        valueColor ??
                        (isDark
                            ? AppTheme.textPrimaryDark
                            : AppTheme.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListItem(IconData icon, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardBackgroundDark : AppTheme.purple50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? AppTheme.purple600.withValues(alpha: 0.2)
              : AppTheme.purple200.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isDark ? AppTheme.primaryPurple : AppTheme.purple700,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(icon, size: 48, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text(
                message,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Attach Policies Dialog
class AttachPoliciesDialog extends StatefulWidget {
  final String username;
  final List<String> currentPolicyNames;

  const AttachPoliciesDialog({
    super.key,
    required this.username,
    this.currentPolicyNames = const [],
  });

  @override
  State<AttachPoliciesDialog> createState() => _AttachPoliciesDialogState();
}

class _AttachPoliciesDialogState extends State<AttachPoliciesDialog> {
  List<dynamic> _policies = [];
  List<dynamic> _filteredPolicies = [];
  final Set<String> _selectedPolicyArns = {};
  final Set<String> _attachedPolicyNames = {};
  final List<String> _currentPolicyArns = [];
  bool _loading = true;
  String _searchQuery = '';
  String _scopeFilter = 'All';

  @override
  void initState() {
    super.initState();
    // Store currently attached policy names
    _attachedPolicyNames.addAll(widget.currentPolicyNames);
    _loadPolicies();
  }

  Future<void> _loadPolicies() async {
    setState(() => _loading = true);
    try {
      final policies = await ApiService.listIAMPolicies(scope: _scopeFilter);
      setState(() {
        _policies = policies;

        // Pre-select policies that are already attached (match by name)
        // Also build the current ARNs list
        _currentPolicyArns.clear();
        for (var policy in _policies) {
          final policyName = policy['policy_name']?.toString() ?? '';
          final policyArn = policy['policy_arn']?.toString() ?? '';
          if (_attachedPolicyNames.contains(policyName)) {
            _selectedPolicyArns.add(policyArn);
            _currentPolicyArns.add(policyArn);
          }
        }

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
        final policyName = (policy['policy_name'] ?? '')
            .toString()
            .toLowerCase();
        final policyArn = (policy['policy_arn'] ?? '').toString().toLowerCase();
        final query = _searchQuery.toLowerCase();
        return policyName.contains(query) || policyArn.contains(query);
      }).toList();

      // Sort: attached policies first, then by name
      _filteredPolicies.sort((a, b) {
        final aName = (a['policy_name'] ?? '').toString();
        final bName = (b['policy_name'] ?? '').toString();
        final aAttached = _attachedPolicyNames.contains(aName);
        final bAttached = _attachedPolicyNames.contains(bName);

        // If one is attached and the other isn't, attached comes first
        if (aAttached && !bAttached) return -1;
        if (!aAttached && bAttached) return 1;

        // Otherwise sort by policy name
        return aName.compareTo(bName);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark
          ? AppTheme.cardBackgroundDark
          : AppTheme.cardBackground,
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
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryPurple.withValues(
                      alpha: isDark ? 0.3 : 0.15,
                    ),
                    AppTheme.purple600.withValues(alpha: isDark ? 0.2 : 0.1),
                  ],
                ),
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
                      color: AppTheme.primaryPurple,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.policy_rounded,
                      color: Colors.white,
                    ),
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
                            color: isDark
                                ? AppTheme.textPrimaryDark
                                : AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Select policies to attach to ${widget.username}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppTheme.textMutedDark
                                : AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    color: isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondary,
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
                      const Text(
                        'Scope: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
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
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.resolveWith((
                            states,
                          ) {
                            if (states.contains(WidgetState.selected)) {
                              return AppTheme.primaryPurple;
                            }
                            return null;
                          }),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_selectedPolicyArns.length} selected',
                        style: TextStyle(
                          color: isDark
                              ? AppTheme.textSecondaryDark
                              : AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
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
                          Icon(
                            Icons.policy_outlined,
                            size: 64,
                            color: isDark
                                ? AppTheme.purple600.withValues(alpha: 0.3)
                                : AppTheme.purple200,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty
                                ? 'No policies found'
                                : 'No matching policies',
                            style: TextStyle(
                              color: isDark
                                  ? AppTheme.textMutedDark
                                  : AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredPolicies.length,
                      itemBuilder: (context, index) {
                        final policy = _filteredPolicies[index];
                        final policyArn =
                            policy['policy_arn']?.toString() ?? '';
                        final policyName =
                            policy['policy_name']?.toString() ?? '';
                        final isAWSManaged = policy['is_aws_managed'] == true;
                        final isSelected = _selectedPolicyArns.contains(
                          policyArn,
                        );
                        final isAlreadyAttached = _attachedPolicyNames.contains(
                          policyName,
                        );

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 0,
                          color: isSelected
                              ? (isDark
                                    ? AppTheme.primaryPurple.withValues(
                                        alpha: 0.15,
                                      )
                                    : AppTheme.purple50)
                              : (isDark ? AppTheme.cardBackgroundDark : null),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: isSelected
                                ? BorderSide(
                                    color: AppTheme.primaryPurple,
                                    width: 2,
                                  )
                                : BorderSide(
                                    color: isDark
                                        ? AppTheme.purple600.withValues(
                                            alpha: 0.2,
                                          )
                                        : Colors.grey.shade200,
                                  ),
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
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (isAlreadyAttached)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.successGreen.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: AppTheme.successGreen.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      'Attached',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isDark
                                            ? AppTheme.successGreen.withValues(
                                                alpha: 0.9,
                                              )
                                            : AppTheme.successGreen,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                if (isAWSManaged) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.warningAmber.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: AppTheme.warningAmber.withValues(
                                          alpha: 0.4,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      'AWS',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isDark
                                            ? AppTheme.warningAmber
                                            : Colors.orange.shade900,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              policyArn,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppTheme.textMutedDark
                                    : AppTheme.textMuted,
                              ),
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
                color: isDark
                    ? AppTheme.backgroundDark
                    : AppTheme.purple50.withValues(alpha: 0.3),
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? AppTheme.purple600.withValues(alpha: 0.2)
                        : AppTheme.purple200,
                  ),
                ),
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
                      label: Text('Apply (${_selectedPolicyArns.length})'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
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
