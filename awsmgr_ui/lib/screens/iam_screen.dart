import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/aws_config_dialog.dart';
import '../widgets/loading_animation.dart';
import '../widgets/speed_dial_menu.dart';
import '../widgets/list_header_with_search.dart';
import '../widgets/iam/iam_dialogs.dart';
import '../utils/toast_utils.dart';
import 'iam_user_profile_screen.dart';
import 'iam_group_profile_screen.dart';

class IAMScreen extends StatefulWidget {
  const IAMScreen({super.key});

  @override
  State<IAMScreen> createState() => _IAMScreenState();
}

class _IAMScreenState extends State<IAMScreen> {
  int _currentIndex = 0;
  List<dynamic> _users = [];
  List<dynamic> _groups = [];
  List<dynamic> _filteredUsers = [];
  bool _loading = false;
  bool _operationInProgress = false;
  bool _selectionMode = false;
  final Set<String> _selectedUsers = {};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterUsers);
    _loadData();
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = _users;
      } else {
        _filteredUsers = _users.where((user) {
          final username = (user['username'] ?? '').toString().toLowerCase();
          final userId = (user['user_id'] ?? '').toString().toLowerCase();
          return username.contains(query) || userId.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final users = await ApiService.listIAMUsers();
      final groups = await ApiService.listIAMGroups();
      if (!mounted) return;
      setState(() {
        _users = users;
        _groups = groups;
        _filteredUsers = users;
      });
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to load data: $e');
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    if (message.contains('AWS credentials not configured')) {
      _showAWSConfigDialog();
    } else {
      ToastUtils.show(context, message, isError: true);
    }
  }

  void _showSuccess(String message) {
    ToastUtils.show(context, message, isError: false);
  }

  Future<void> _showAWSConfigDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AWSConfigDialog(),
    );

    if (result == true) {
      _loadData();
    }
  }

  Future<void> _createUser() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const CreateUserDialog(),
    );

    if (result != null && result['username'] != null) {
      if (!mounted) return;
      setState(() => _operationInProgress = true);
      try {
        await ApiService.createIAMUser(
          result['username'],
          password: result['password'],
          requireReset: result['require_reset'] ?? false,
        );

        if (!mounted) return;
        setState(() => _operationInProgress = false);

        // Show credentials dialog only if password was set
        if (mounted &&
            result['password'] != null &&
            result['password'].isNotEmpty) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => CredentialsDialog(
              credentials: [
                {
                  'username': result['username']!,
                  'password': result['password']!,
                },
              ],
            ),
          );
        } else {
          // Show success message for user without password
          _showSuccess('User "${result['username']}" created successfully');
        }

        await _loadData();
      } catch (e) {
        if (!mounted) return;
        setState(() => _operationInProgress = false);
        _showError('Failed to create user: $e');
      }
    }
  }

  Future<void> _createMultipleUsers() async {
    final result = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (context) => const BatchCreateUsersDialog(),
    );

    if (result != null && result.isNotEmpty) {
      if (!mounted) return;
      setState(() => _operationInProgress = true);
      try {
        final response = await ApiService.createMultipleIAMUsers(result);

        final successCount = response['success_count'] ?? 0;
        final failureCount = response['failure_count'] ?? 0;
        final results = response['results'] as List;

        if (!mounted) return;
        setState(() => _operationInProgress = false);

        // Prepare credentials for successful users with passwords
        final credentials = <Map<String, String>>[];
        for (int i = 0; i < results.length; i++) {
          final apiResult = results[i];
          final inputData = result[i];
          if (apiResult['Success'] == true && inputData['password'] != null) {
            credentials.add({
              'username': apiResult['Username'],
              'password': inputData['password'],
            });
          }
        }

        // Show credentials dialog first if there are any
        if (mounted && credentials.isNotEmpty) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => CredentialsDialog(credentials: credentials),
          );
        }

        // Then show detailed results dialog
        if (mounted) {
          await showDialog(
            context: context,
            builder: (context) => BatchResultsDialog(
              successCount: successCount,
              failureCount: failureCount,
              results: results,
            ),
          );
        }

        await _loadData();
      } catch (e) {
        if (!mounted) return;
        setState(() => _operationInProgress = false);
        _showError('Failed to create users: $e');
      }
    }
  }

  Future<void> _batchDeleteUsers() async {
    if (_selectedUsers.isEmpty) return;

    final usernames = _selectedUsers.toList();

    // Check dependencies for all selected users
    if (!mounted) return;
    setState(() => _operationInProgress = true);
    late List<dynamic> dependencies;

    try {
      dependencies = await ApiService.checkMultipleUserDependencies(usernames);
    } catch (e) {
      if (!mounted) return;
      setState(() => _operationInProgress = false);
      _showError('Failed to check dependencies: $e');
      return;
    }

    if (!mounted) return;
    setState(() => _operationInProgress = false);

    // Show dependencies dialog and get confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          BatchDeleteConfirmationDialog(dependencies: dependencies),
    );

    if (confirmed == true) {
      if (!mounted) return;
      setState(() => _operationInProgress = true);

      try {
        // Prepare delete requests with force flag
        final deleteRequests = usernames.map((username) {
          return {
            'username': username,
            'force': true, // Always force delete to remove dependencies
          };
        }).toList();

        final response = await ApiService.deleteMultipleIAMUsers(
          deleteRequests,
        );

        final successCount = response['success_count'] ?? 0;
        final failureCount = response['failure_count'] ?? 0;
        final results = response['results'] as List;

        if (!mounted) return;
        setState(() => _operationInProgress = false);

        // Show results dialog
        if (mounted) {
          await showDialog(
            context: context,
            builder: (context) => BatchDeleteResultsDialog(
              successCount: successCount,
              failureCount: failureCount,
              results: results,
            ),
          );
        }

        // Clear selection and exit selection mode
        if (!mounted) return;
        setState(() {
          _selectedUsers.clear();
          _selectionMode = false;
        });

        await _loadData();
      } catch (e) {
        if (!mounted) return;
        setState(() => _operationInProgress = false);
        _showError('Failed to delete users: $e');
      }
    }
  }

  Future<void> _deleteUser(String username) async {
    // First check dependencies
    if (!mounted) return;
    setState(() => _operationInProgress = true);
    late Map<String, dynamic> dependencies;

    try {
      dependencies = await ApiService.checkUserDependencies(username);
    } catch (e) {
      if (!mounted) return;
      setState(() => _operationInProgress = false);
      _showError('Failed to check user dependencies: $e');
      return;
    }

    if (!mounted) return;
    setState(() => _operationInProgress = false);

    final hasDeps =
        (dependencies['groups'] as List?)?.isNotEmpty == true ||
        (dependencies['managed_policies'] as List?)?.isNotEmpty == true ||
        (dependencies['inline_policies'] as List?)?.isNotEmpty == true ||
        (dependencies['access_keys'] as List?)?.isNotEmpty == true ||
        dependencies['has_login_profile'] == true;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              hasDeps ? Icons.warning : Icons.delete,
              color: hasDeps ? Colors.orange : Colors.red,
            ),
            const SizedBox(width: 8),
            const Text('Delete User'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to delete "$username"?'),
              const SizedBox(height: 8),
              if (hasDeps) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info, color: Colors.orange, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'User has dependencies:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if ((dependencies['groups'] as List?)?.isNotEmpty ==
                          true) ...[
                        const Text(
                          'Groups:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        ...(dependencies['groups'] as List).map(
                          (g) => Text('  • $g'),
                        ),
                        const SizedBox(height: 4),
                      ],
                      if ((dependencies['managed_policies'] as List?)
                              ?.isNotEmpty ==
                          true) ...[
                        const Text(
                          'Managed Policies:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        ...(dependencies['managed_policies'] as List).map(
                          (p) => Text('  • $p'),
                        ),
                        const SizedBox(height: 4),
                      ],
                      if ((dependencies['inline_policies'] as List?)
                              ?.isNotEmpty ==
                          true) ...[
                        const Text(
                          'Inline Policies:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        ...(dependencies['inline_policies'] as List).map(
                          (p) => Text('  • $p'),
                        ),
                        const SizedBox(height: 4),
                      ],
                      if ((dependencies['access_keys'] as List?)?.isNotEmpty ==
                          true) ...[
                        const Text(
                          'Access Keys:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        ...(dependencies['access_keys'] as List).map(
                          (k) => Text('  • $k'),
                        ),
                        const SizedBox(height: 4),
                      ],
                      if (dependencies['has_login_profile'] == true) ...[
                        const Text(
                          '• Has login profile',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'All dependencies will be removed automatically.',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              const Text(
                'This action cannot be undone.',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete),
            label: Text(hasDeps ? 'Remove All & Delete' : 'Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      setState(() => _operationInProgress = true);
      try {
        await ApiService.deleteIAMUser(username, force: hasDeps);
        if (!mounted) return;
        _showSuccess('User "$username" deleted successfully');
        await _loadData();
      } catch (e) {
        if (!mounted) return;
        _showError('Failed to delete user: $e');
      } finally {
        if (!mounted) return;
        setState(() => _operationInProgress = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _operationInProgress,
      message: 'Processing...',
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(title: const Text('IAM Management'), elevation: 0),
        body: _currentIndex == 0 ? _buildUsersTab() : _buildGroupsTab(),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
              _selectionMode = false;
              _selectedUsers.clear();
              _searchController.clear();
            });
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Users'),
            BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Groups'),
          ],
        ),
        floatingActionButton: _currentIndex == 0 && !_selectionMode
            ? SpeedDialMenu(
                items: [
                  SpeedDialMenuItem(
                    icon: Icons.person_add,
                    label: 'Create User',
                    color: AppTheme.purple400,
                    onTap: _createUser,
                  ),
                  SpeedDialMenuItem(
                    icon: Icons.group_add,
                    label: 'Batch Create',
                    color: AppTheme.accentMint,
                    onTap: _createMultipleUsers,
                  ),
                  SpeedDialMenuItem(
                    icon: Icons.delete_sweep,
                    label: 'Batch Delete',
                    color: AppTheme.errorRed,
                    onTap: () {
                      setState(() {
                        _selectionMode = true;
                        _selectedUsers.clear();
                      });
                    },
                  ),
                  SpeedDialMenuItem(
                    icon: Icons.refresh,
                    label: 'Refresh',
                    color: AppTheme.accentCoral,
                    onTap: _loadData,
                  ),
                ],
              )
            : _currentIndex == 1
            ? SpeedDialMenu(
                items: [
                  SpeedDialMenuItem(
                    icon: Icons.group_add,
                    label: 'Create Group',
                    color: AppTheme.purple400,
                    onTap: _createGroup,
                  ),
                  SpeedDialMenuItem(
                    icon: Icons.refresh,
                    label: 'Refresh',
                    color: AppTheme.accentCoral,
                    onTap: _loadData,
                  ),
                ],
              )
            : null,
      ),
    );
  }

  Widget _buildUsersTab() {
    return Column(
      children: [
        if (!_selectionMode)
          ListHeaderWithSearch(
            title: 'IAM Users',
            subtitle: '${_filteredUsers.length} users',
            svgAsset:
                'assets/icons/Arch_AWS-Identity-and-Access-Management_32.svg',
            iconBackgroundColor: AppTheme.purple100,
            iconColor: AppTheme.purple600,
            searchController: _searchController,
            searchFocusNode: _searchFocusNode,
            searchHint: 'Search users by username or ID...',
          )
        else
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: AppTheme.accentCoral.withValues(alpha: 0.1),
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.accentCoral.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.accentCoral.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.checklist, color: AppTheme.accentCoral),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Users',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${_selectedUsers.length} selected',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _selectedUsers.isNotEmpty
                            ? _batchDeleteUsers
                            : null,
                        icon: const Icon(Icons.delete, size: 18),
                        label: Text('Delete (${_selectedUsers.length})'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: AppTheme.errorRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectionMode = false;
                            _selectedUsers.clear();
                          });
                        },
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Cancel'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        Expanded(
          child: _loading
              ? const LoadingAnimation(message: 'Loading users')
              : _filteredUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _searchController.text.isNotEmpty
                            ? Icons.search_off
                            : Icons.people_outline,
                        size: 80,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchController.text.isNotEmpty
                            ? 'No users found'
                            : 'No users found',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _searchController.text.isNotEmpty
                            ? 'Try a different search term'
                            : 'Create your first IAM user',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                      if (_searchController.text.isEmpty) ...[
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _createUser,
                          icon: const Icon(Icons.add),
                          label: const Text('Create User'),
                        ),
                      ],
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = _filteredUsers[index];
                    final username = user['username'] ?? '';
                    final isSelected = _selectedUsers.contains(username);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: isSelected ? 3 : 1,
                      color: isSelected ? AppTheme.purple50 : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: isSelected
                            ? BorderSide(color: AppTheme.purple400, width: 2)
                            : BorderSide(color: Colors.grey.shade200, width: 1),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _selectionMode
                            ? () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedUsers.remove(username);
                                  } else {
                                    _selectedUsers.add(username);
                                  }
                                });
                              }
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        IAMUserProfileScreen(user: user),
                                  ),
                                );
                              },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // Leading - checkbox only in selection mode
                              if (_selectionMode)
                                Checkbox(
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
                                ),
                              if (_selectionMode) const SizedBox(width: 16),
                              // Content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ShaderMask(
                                      shaderCallback: (bounds) =>
                                          const LinearGradient(
                                            colors: [
                                              Color(0xFF6366F1),
                                              Color(0xFF8B5CF6),
                                              Color(0xFFA855F7),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ).createShader(bounds),
                                      child: Text(
                                        user['username'] ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 20,
                                          color: Colors.white,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.fingerprint,
                                          size: 14,
                                          color: Colors.grey[500],
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            user['user_id'] ?? '',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (user['create_date'] != null) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today,
                                            size: 14,
                                            color: Colors.grey[500],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            user['create_date'],
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // Trailing
                              if (!_selectionMode)
                                PopupMenuButton<String>(
                                  tooltip: 'Actions',
                                  icon: Icon(
                                    Icons.more_vert,
                                    size: 20,
                                    color: Colors.grey[600],
                                  ),
                                  onSelected: (value) {
                                    if (value == 'delete') {
                                      _deleteUser(username);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                            color: Colors.red,
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            'Delete User',
                                            style: TextStyle(color: Colors.red),
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
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildGroupsTab() {
    return Column(
      children: [
        ListHeaderWithSearch(
          title: 'IAM Groups',
          subtitle: '${_groups.length} groups',
          icon: Icons.group,
          iconBackgroundColor: AppTheme.purple200,
          iconColor: AppTheme.purple600,
          searchController: _searchController,
          searchFocusNode: _searchFocusNode,
          searchHint: 'Search groups by name or ID...',
        ),
        Expanded(
          child: _loading
              ? const LoadingAnimation(message: 'Loading groups')
              : _groups.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.group_outlined,
                        size: 80,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No groups found',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _groups.length,
                  itemBuilder: (context, index) {
                    final group = _groups[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200, width: 1),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _showGroupDetails(group),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // Content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ShaderMask(
                                      shaderCallback: (bounds) =>
                                          const LinearGradient(
                                            colors: [
                                              Color(0xFF6366F1),
                                              Color(0xFF8B5CF6),
                                              Color(0xFFA855F7),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ).createShader(bounds),
                                      child: Text(
                                        group['groupname'] ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 20,
                                          color: Colors.white,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.fingerprint,
                                          size: 14,
                                          color: Colors.grey[500],
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            group['group_id'] ?? '',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Trailing
                              PopupMenuButton<String>(
                                tooltip: 'Actions',
                                icon: Icon(
                                  Icons.more_vert,
                                  size: 20,
                                  color: Colors.grey[600],
                                ),
                                onSelected: (value) {
                                  if (value == 'delete') {
                                    _deleteGroup(group['groupname'] ?? '');
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                          color: Colors.red,
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          'Delete Group',
                                          style: TextStyle(color: Colors.red),
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
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _createGroup() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.group_add, color: Colors.green),
            SizedBox(width: 8),
            Text('Create IAM Group'),
          ],
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Group Name *',
            hintText: 'Enter group name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.group),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, controller.text),
            icon: const Icon(Icons.add),
            label: const Text('Create'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      if (!mounted) return;
      setState(() => _operationInProgress = true);
      try {
        await ApiService.createIAMGroup(result);
        if (!mounted) return;
        _showSuccess('Group "$result" created successfully');
        await _loadData();
      } catch (e) {
        if (!mounted) return;
        _showError('Failed to create group: $e');
      } finally {
        if (!mounted) return;
        setState(() => _operationInProgress = false);
      }
    }
  }

  Future<void> _deleteGroup(String groupname) async {
    // Check dependencies first
    if (!mounted) return;
    setState(() => _operationInProgress = true);
    late Map<String, dynamic> dependencies;

    try {
      dependencies = await ApiService.checkGroupDependencies(groupname);
    } catch (e) {
      if (!mounted) return;
      setState(() => _operationInProgress = false);
      _showError('Failed to check group dependencies: $e');
      return;
    }

    if (!mounted) return;
    setState(() => _operationInProgress = false);

    final users = dependencies['users'] as List? ?? [];
    final policies = dependencies['attached_policies'] as List? ?? [];
    final hasDeps = users.isNotEmpty || policies.isNotEmpty;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              hasDeps ? Icons.warning : Icons.delete,
              color: hasDeps ? Colors.orange : Colors.red,
            ),
            const SizedBox(width: 8),
            const Text('Delete Group'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to delete "$groupname"?'),
              const SizedBox(height: 8),
              if (hasDeps) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info, color: Colors.orange, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Group has dependencies:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (users.isNotEmpty) ...[
                        const Text(
                          'Users:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        ...users.map((u) => Text('  • $u')),
                        const SizedBox(height: 4),
                      ],
                      if (policies.isNotEmpty) ...[
                        const Text(
                          'Attached Policies:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        ...policies.map(
                          (p) => Text('  • ${p.split('/').last}'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'All dependencies will be removed automatically.',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              const Text(
                'This action cannot be undone.',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete),
            label: Text(hasDeps ? 'Remove All & Delete' : 'Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      setState(() => _operationInProgress = true);
      try {
        await ApiService.deleteIAMGroup(groupname, force: hasDeps);
        if (!mounted) return;
        _showSuccess('Group "$groupname" deleted successfully');
        await _loadData();
      } catch (e) {
        if (!mounted) return;
        _showError('Failed to delete group: $e');
      } finally {
        if (!mounted) return;
        setState(() => _operationInProgress = false);
      }
    }
  }

  Future<void> _showGroupDetails(Map<String, dynamic> group) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IAMGroupProfileScreen(group: group),
      ),
    );

    // Reload data in case changes were made
    await _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
}
