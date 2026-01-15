import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/email_config_service.dart';
import '../theme/app_theme.dart';
import '../widgets/aws_config_dialog.dart';
import '../widgets/loading_animation.dart';
import '../widgets/speed_dial_menu.dart';
import '../widgets/list_header_with_search.dart';
import 'iam_user_profile_screen.dart';
import 'iam_group_profile_screen.dart';

class IAMScreen extends StatefulWidget {
  const IAMScreen({super.key});

  @override
  State<IAMScreen> createState() => _IAMScreenState();
}

class _IAMScreenState extends State<IAMScreen> with TickerProviderStateMixin {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
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

// Create User Dialog with password validation
class CreateUserDialog extends StatefulWidget {
  const CreateUserDialog({super.key});

  @override
  State<CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<CreateUserDialog> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _setPassword = false;
  bool _requireReset = false;
  bool _obscurePassword = true;

  // Password validation states
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validatePassword);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _validatePassword() {
    final password = _passwordController.text;
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
    });
  }

  bool get _isPasswordValid =>
      !_setPassword ||
      (_hasMinLength && _hasUppercase && _hasLowercase && _hasNumber);

  bool get _canCreate =>
      _usernameController.text.isNotEmpty && _isPasswordValid;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.person_add, color: Colors.blue),
          SizedBox(width: 8),
          Text('Create IAM User'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Username field
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Username *',
                hintText: 'Enter username',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.person),
              ),
              autofocus: true,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Set password checkbox
            CheckboxListTile(
              value: _setPassword,
              onChanged: (value) {
                setState(() {
                  _setPassword = value ?? false;
                  if (!_setPassword) {
                    _passwordController.clear();
                    _requireReset = false;
                  }
                });
              },
              title: const Text('Set initial password'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),

            // Password field (shown only if checkbox is checked)
            if (_setPassword) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password *',
                  hintText: 'Enter password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Password requirements
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Password Requirements:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildRequirement('At least 8 characters', _hasMinLength),
                    _buildRequirement(
                      'One uppercase letter (A-Z)',
                      _hasUppercase,
                    ),
                    _buildRequirement(
                      'One lowercase letter (a-z)',
                      _hasLowercase,
                    ),
                    _buildRequirement('One number (0-9)', _hasNumber),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Require reset checkbox
              CheckboxListTile(
                value: _requireReset,
                onChanged: (value) {
                  setState(() => _requireReset = value ?? false);
                },
                title: const Text('Require password reset at first login'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _canCreate
              ? () {
                  Navigator.pop(context, {
                    'username': _usernameController.text,
                    'password': _setPassword ? _passwordController.text : null,
                    'require_reset': _requireReset,
                  });
                }
              : null,
          icon: const Icon(Icons.add),
          label: const Text('Create'),
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRequirement(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: met ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: met ? Colors.green : Colors.grey.shade600,
              fontWeight: met ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

// Batch Create Users Dialog
class BatchCreateUsersDialog extends StatefulWidget {
  const BatchCreateUsersDialog({super.key});

  @override
  State<BatchCreateUsersDialog> createState() => _BatchCreateUsersDialogState();
}

class _BatchCreateUsersDialogState extends State<BatchCreateUsersDialog> {
  final List<_UserEntry> _users = [_UserEntry()];
  final _scrollController = ScrollController();

  void _addUser() {
    setState(() => _users.add(_UserEntry()));
    // Scroll to bottom after adding
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _removeUser(int index) {
    if (_users.length > 1) {
      setState(() => _users.removeAt(index));
    }
  }

  bool get _canCreate {
    return _users.every((user) => user.isValid);
  }

  List<Map<String, dynamic>> _getUsersData() {
    return _users.map((user) => user.toJson()).toList();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (var user in _users) {
      user.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
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
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.group_add, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Batch Create Users',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Create multiple IAM users at once',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
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

            // Users list
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _users.length,
                itemBuilder: (context, index) {
                  return _UserEntryWidget(
                    key: ValueKey(_users[index]),
                    entry: _users[index],
                    index: index,
                    canRemove: _users.length > 1,
                    onRemove: () => _removeUser(index),
                    onChanged: () => setState(() {}),
                  );
                },
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _addUser,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add User'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_users.length} user(s)',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
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
                          onPressed: _canCreate
                              ? () => Navigator.pop(context, _getUsersData())
                              : null,
                          icon: const Icon(Icons.group_add, size: 18),
                          label: const Text('Create All'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
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

// User Entry Model
class _UserEntry {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool setPassword = false;
  bool requireReset = false;
  bool obscurePassword = true;

  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;

  bool get isValid {
    if (usernameController.text.isEmpty) return false;
    if (setPassword) {
      return _hasMinLength && _hasUppercase && _hasLowercase && _hasNumber;
    }
    return true;
  }

  void validatePassword() {
    final password = passwordController.text;
    _hasMinLength = password.length >= 8;
    _hasUppercase = password.contains(RegExp(r'[A-Z]'));
    _hasLowercase = password.contains(RegExp(r'[a-z]'));
    _hasNumber = password.contains(RegExp(r'[0-9]'));
  }

  Map<String, dynamic> toJson() {
    return {
      'username': usernameController.text,
      if (setPassword) 'password': passwordController.text,
      if (setPassword) 'require_reset': requireReset,
    };
  }

  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
  }
}

// User Entry Widget
class _UserEntryWidget extends StatefulWidget {
  final _UserEntry entry;
  final int index;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _UserEntryWidget({
    super.key,
    required this.entry,
    required this.index,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<_UserEntryWidget> createState() => _UserEntryWidgetState();
}

class _UserEntryWidgetState extends State<_UserEntryWidget> {
  @override
  void initState() {
    super.initState();
    widget.entry.passwordController.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    widget.entry.validatePassword();
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '#${widget.index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: widget.entry.usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username *',
                      hintText: 'Enter username',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.person, size: 20),
                      isDense: true,
                    ),
                    onChanged: (_) => widget.onChanged(),
                  ),
                ),
                if (widget.canRemove) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.red,
                    onPressed: widget.onRemove,
                    tooltip: 'Remove',
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: widget.entry.setPassword,
              onChanged: (value) {
                setState(() {
                  widget.entry.setPassword = value ?? false;
                  if (!widget.entry.setPassword) {
                    widget.entry.passwordController.clear();
                    widget.entry.requireReset = false;
                  }
                });
                widget.onChanged();
              },
              title: const Text('Set password', style: TextStyle(fontSize: 14)),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            ),
            if (widget.entry.setPassword) ...[
              TextField(
                controller: widget.entry.passwordController,
                obscureText: widget.entry.obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password *',
                  hintText: 'Enter password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.lock, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      widget.entry.obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        widget.entry.obscurePassword =
                            !widget.entry.obscurePassword;
                      });
                    },
                  ),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _buildChip('8+ chars', widget.entry._hasMinLength),
                  _buildChip('A-Z', widget.entry._hasUppercase),
                  _buildChip('a-z', widget.entry._hasLowercase),
                  _buildChip('0-9', widget.entry._hasNumber),
                ],
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: widget.entry.requireReset,
                onChanged: (value) {
                  setState(() => widget.entry.requireReset = value ?? false);
                  widget.onChanged();
                },
                title: const Text(
                  'Require reset',
                  style: TextStyle(fontSize: 13),
                ),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, bool met) {
    return Chip(
      label: Text(
        label,
        style: TextStyle(fontSize: 11, color: met ? Colors.green : Colors.grey),
      ),
      avatar: Icon(
        met ? Icons.check_circle : Icons.cancel,
        size: 14,
        color: met ? Colors.green : Colors.grey,
      ),
      backgroundColor: met ? Colors.green.shade50 : Colors.grey.shade100,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}

// Batch Results Dialog
class BatchResultsDialog extends StatelessWidget {
  final int successCount;
  final int failureCount;
  final List results;

  const BatchResultsDialog({
    super.key,
    required this.successCount,
    required this.failureCount,
    required this.results,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            failureCount == 0 ? Icons.check_circle : Icons.info,
            color: failureCount == 0 ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          const Text('Batch Creation Results'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStat('Total', results.length, Colors.blue),
                  _buildStat('Success', successCount, Colors.green),
                  if (failureCount > 0)
                    _buildStat('Failed', failureCount, Colors.red),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Details:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // Results list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final result = results[index];
                  final success = result['Success'] ?? false;
                  final username = result['Username'] ?? '';
                  final error = result['Error'] ?? '';

                  return ListTile(
                    dense: true,
                    leading: Icon(
                      success ? Icons.check_circle : Icons.error,
                      color: success ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    title: Text(username),
                    subtitle: !success
                        ? Text(error, style: const TextStyle(fontSize: 12))
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildStat(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

// Credentials Dialog
class CredentialsDialog extends StatefulWidget {
  final List<Map<String, String?>> credentials;

  const CredentialsDialog({super.key, required this.credentials});

  @override
  State<CredentialsDialog> createState() => _CredentialsDialogState();
}

class _CredentialsDialogState extends State<CredentialsDialog> {
  final Set<int> _visiblePasswords = {};
  bool _sending = false;

  void _togglePasswordVisibility(int index) {
    setState(() {
      if (_visiblePasswords.contains(index)) {
        _visiblePasswords.remove(index);
      } else {
        _visiblePasswords.add(index);
      }
    });
  }

  Future<void> _sendViaEmail(Map<String, String?> credential) async {
    // Check if email config exists
    final hasConfig = await EmailConfigService.hasEmailConfig();
    if (!hasConfig) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please configure email settings first'),
            backgroundColor: AppTheme.warningAmber,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
      return;
    }

    // Ask for recipient email
    final emailController = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.email_rounded, color: AppTheme.primaryPurple),
            ),
            const SizedBox(width: 12),
            const Text('Send Credentials'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send credentials for ${credential['username']} via email',
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Recipient Email',
                hintText: 'user@example.com',
                prefixIcon: const Icon(Icons.alternate_email_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: AppTheme.primaryPurple, width: 2),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (emailController.text.contains('@')) {
                Navigator.pop(context, emailController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Next'),
          ),
        ],
      ),
    );

    if (email == null || email.isEmpty) return;

    // Confirm email
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.warningAmber),
            SizedBox(width: 12),
            Text('Confirm Email'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure this is the correct email address?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.email_outlined, color: AppTheme.primaryPurple),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      email,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Send'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Send email
    setState(() => _sending = true);
    try {
      await ApiService.sendUserCredentialsEmail(
        username: credential['username']!,
        password: credential['password']!,
        email: email,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text('Credentials sent to $email'),
              ],
            ),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send email: $e'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } finally {
      setState(() => _sending = false);
    }
  }

  void _downloadCredentials() {
    final buffer = StringBuffer();
    buffer.writeln('IAM User Credentials');
    buffer.writeln('Generated: ${DateTime.now()}');
    buffer.writeln('=' * 50);
    buffer.writeln();

    for (var cred in widget.credentials) {
      buffer.writeln('Username: ${cred['username']}');
      if (cred['password'] != null && cred['password']!.isNotEmpty) {
        buffer.writeln('Password: ${cred['password']}');
      }
      buffer.writeln('-' * 50);
    }

    // Copy to clipboard
    final content = buffer.toString();
    Clipboard.setData(ClipboardData(text: content));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text('All credentials copied to clipboard!'),
          ],
        ),
        backgroundColor: AppTheme.successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('$label copied to clipboard'),
          ],
        ),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildCredentialField({
    required BuildContext context,
    required String label,
    required String value,
    required bool isPassword,
    VoidCallback? onCopy,
    VoidCallback? onToggleVisibility,
    bool isVisible = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    isVisible ? value : '•' * 20,
                    style: TextStyle(
                      fontFamily: isPassword ? 'monospace' : null,
                      fontSize: 15,
                      letterSpacing: (isPassword && !isVisible) ? 1 : 0,
                      fontWeight: isPassword ? FontWeight.w500 : FontWeight.w400,
                      color: Colors.grey[900],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 24,
                color: Colors.grey.shade300,
              ),
              if (isPassword && onToggleVisibility != null)
                IconButton(
                  icon: Icon(
                    isVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 18,
                    color: Colors.grey[600],
                  ),
                  tooltip: isVisible ? 'Hide' : 'Show',
                  onPressed: onToggleVisibility,
                  splashRadius: 20,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 48),
                ),
              if (isPassword)
                 Container(
                  width: 1,
                  height: 24,
                  color: Colors.grey.shade300,
                ),
              IconButton(
                icon: Icon(Icons.copy_rounded, size: 18, color: Colors.grey[600]),
                tooltip: 'Copy $label',
                onPressed: onCopy,
                splashRadius: 20,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 48),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter out credentials without passwords
    final credsWithPasswords = widget.credentials
        .where((c) => c['password'] != null && c['password']!.isNotEmpty)
        .toList();

    if (credsWithPasswords.isEmpty) {
      // No passwords to show, just close
      Future.microtask(() => Navigator.pop(context));
      return const SizedBox.shrink();
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        width: 550,
        constraints: const BoxConstraints(maxHeight: 700),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.successGreen.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: AppTheme.successGreen,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'User Created Successfully',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.warningAmber.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.warningAmber.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 20,
                          color: Colors.orange[800],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'These credentials will not be available again. Please copy or download them now.',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: Colors.orange[900],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const Divider(height: 1),

            // Credentials list
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(24),
                itemCount: credsWithPasswords.length,
                separatorBuilder: (context, index) => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Divider(),
                ),
                itemBuilder: (context, index) {
                  final cred = credsWithPasswords[index];
                  final username = cred['username'] ?? '';
                  final password = cred['password'] ?? '';
                  final isVisible = _visiblePasswords.contains(index);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCredentialField(
                        context: context,
                        label: 'Username',
                        value: username,
                        isPassword: false,
                        onCopy: () => _copyToClipboard(username, 'Username'),
                      ),
                      const SizedBox(height: 16),
                      _buildCredentialField(
                        context: context,
                        label: 'Console Password',
                        value: password,
                        isPassword: true,
                        isVisible: isVisible,
                        onToggleVisibility: () => _togglePasswordVisibility(index),
                        onCopy: () => _copyToClipboard(password, 'Password'),
                      ),
                    ],
                  );
                },
              ),
            ),

            const Divider(height: 1),

            // Footer Buttons
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _downloadCredentials,
                          icon: const Icon(Icons.copy_all_rounded, size: 18),
                          label: const Text('Copy All Credentials'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            foregroundColor: AppTheme.textPrimary,
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _sending
                              ? null
                              : () async {
                                  for (var cred in credsWithPasswords) {
                                    await _sendViaEmail(cred);
                                  }
                                },
                           icon: _sending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.email_outlined, size: 18),
                          label: Text(_sending ? 'Sending...' : 'Email Credentials'),
                           style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            foregroundColor: AppTheme.primaryPurple,
                            side: const BorderSide(color: AppTheme.primaryPurple),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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

// Batch Delete Confirmation Dialog
class BatchDeleteConfirmationDialog extends StatelessWidget {
  final List<dynamic> dependencies;

  const BatchDeleteConfirmationDialog({super.key, required this.dependencies});

  @override
  Widget build(BuildContext context) {
    // Count users with dependencies
    int usersWithDeps = 0;
    for (var dep in dependencies) {
      final deps = dep['dependencies'];
      if (deps != null) {
        final hasDeps =
            (deps['groups'] as List?)?.isNotEmpty == true ||
            (deps['managed_policies'] as List?)?.isNotEmpty == true ||
            (deps['inline_policies'] as List?)?.isNotEmpty == true ||
            (deps['access_keys'] as List?)?.isNotEmpty == true ||
            deps['has_login_profile'] == true;
        if (hasDeps) usersWithDeps++;
      }
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            usersWithDeps > 0 ? Icons.warning : Icons.delete,
            color: usersWithDeps > 0 ? Colors.orange : Colors.red,
          ),
          const SizedBox(width: 8),
          const Text('Confirm Batch Delete'),
        ],
      ),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You are about to delete ${dependencies.length} user(s).',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (usersWithDeps > 0) ...[
                const SizedBox(height: 16),
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
                      Row(
                        children: [
                          const Icon(
                            Icons.info,
                            color: Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$usersWithDeps user(s) have dependencies',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'All dependencies will be automatically removed before deletion.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Users with dependencies:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...dependencies
                    .where((dep) {
                      final deps = dep['dependencies'];
                      if (deps == null) return false;
                      return (deps['groups'] as List?)?.isNotEmpty == true ||
                          (deps['managed_policies'] as List?)?.isNotEmpty ==
                              true ||
                          (deps['inline_policies'] as List?)?.isNotEmpty ==
                              true ||
                          (deps['access_keys'] as List?)?.isNotEmpty == true ||
                          deps['has_login_profile'] == true;
                    })
                    .map((dep) {
                      final username = dep['username'];
                      final deps = dep['dependencies'];
                      return ExpansionTile(
                        dense: true,
                        title: Text(
                          username,
                          style: const TextStyle(fontSize: 14),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 16, bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if ((deps['groups'] as List?)?.isNotEmpty ==
                                    true)
                                  _buildDepList('Groups', deps['groups']),
                                if ((deps['managed_policies'] as List?)
                                        ?.isNotEmpty ==
                                    true)
                                  _buildDepList(
                                    'Policies',
                                    deps['managed_policies'],
                                  ),
                                if ((deps['inline_policies'] as List?)
                                        ?.isNotEmpty ==
                                    true)
                                  _buildDepList(
                                    'Inline Policies',
                                    deps['inline_policies'],
                                  ),
                                if ((deps['access_keys'] as List?)
                                        ?.isNotEmpty ==
                                    true)
                                  _buildDepList(
                                    'Access Keys',
                                    deps['access_keys'],
                                  ),
                                if (deps['has_login_profile'] == true)
                                  const Text(
                                    '• Has login profile',
                                    style: TextStyle(fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }),
              ],
              const SizedBox(height: 16),
              const Text(
                'This action cannot be undone.',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
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
          label: const Text('Delete All'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildDepList(String title, List items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title:',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          ...items.map(
            (item) => Text('  • $item', style: const TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

// Batch Delete Results Dialog
class BatchDeleteResultsDialog extends StatelessWidget {
  final int successCount;
  final int failureCount;
  final List results;

  const BatchDeleteResultsDialog({
    super.key,
    required this.successCount,
    required this.failureCount,
    required this.results,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            failureCount == 0 ? Icons.check_circle : Icons.info,
            color: failureCount == 0 ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          const Text('Batch Deletion Results'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStat('Total', results.length, Colors.blue),
                  _buildStat('Deleted', successCount, Colors.green),
                  if (failureCount > 0)
                    _buildStat('Failed', failureCount, Colors.red),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Details:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // Results list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final result = results[index];
                  final success = result['Success'] ?? false;
                  final username = result['Username'] ?? '';
                  final error = result['Error'] ?? '';

                  return ListTile(
                    dense: true,
                    leading: Icon(
                      success ? Icons.check_circle : Icons.error,
                      color: success ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    title: Text(username),
                    subtitle: !success
                        ? Text(error, style: const TextStyle(fontSize: 12))
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildStat(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
