import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import '../models/s3_item.dart';
import '../services/api_service.dart';
import '../services/s3_service.dart';
import '../services/download_service.dart';
import '../widgets/loading_animation.dart';
import '../widgets/list_header_with_search.dart';
import '../widgets/speed_dial_menu.dart';
import '../theme/app_theme.dart';
import '../utils/toast_utils.dart';
import 's3_file_viewer_screen.dart';

class S3BrowserScreen extends StatefulWidget {
  final String bucketName;

  const S3BrowserScreen({super.key, required this.bucketName});

  @override
  State<S3BrowserScreen> createState() => _S3BrowserScreenState();
}

enum SortOption { nameAsc, nameDesc, sizeAsc, sizeDesc, dateAsc, dateDesc }

class _S3BrowserScreenState extends State<S3BrowserScreen> {
  List<S3Item> _items = [];
  List<S3Item> _filteredItems = [];
  String _currentPrefix = '';
  bool _loading = false;
  String _searchQuery = '';
  String _lastSearchText = '';
  SortOption _sortOption = SortOption.nameAsc;
  final TextEditingController _searchController = TextEditingController();

  // Versioning and MFA Delete state
  bool _versioningEnabled = false;
  bool _mfaDeleteEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
    _loadVersioningStatus();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final text = _searchController.text;

    // Logic to detect if user is typing a path
    if (text.contains('/')) {
      final lastSlashIndex = text.lastIndexOf('/');
      final newPrefix = text.substring(0, lastSlashIndex + 1);
      final newQuery = text.substring(lastSlashIndex + 1);

      if (_currentPrefix != newPrefix) {
        setState(() {
          _currentPrefix = newPrefix;
          _searchQuery = newQuery;
        });
        _loadItems(keepSearch: true);
      } else if (_searchQuery != newQuery) {
        setState(() => _searchQuery = newQuery);
        _filterAndSortItems();
      }
    } else {
      // Logic to reset to root if user backspaces out of a path
      if (_currentPrefix.isNotEmpty && _lastSearchText.contains('/')) {
        setState(() {
          _currentPrefix = '';
          _searchQuery = text;
        });
        _loadItems(keepSearch: true);
      } else {
        if (_searchQuery != text) {
          setState(() => _searchQuery = text);
          _filterAndSortItems();
        }
      }
    }
    _lastSearchText = text;
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _breadcrumbs {
    if (_currentPrefix.isEmpty) return [];
    final parts = _currentPrefix.split('/').where((p) => p.isNotEmpty).toList();
    return parts;
  }

  void _navigateToBreadcrumb(int index) {
    final parts = _breadcrumbs;
    if (index < 0 || index >= parts.length) return;

    final newPath = '${parts.sublist(0, index + 1).join('/')}/';
    setState(() => _currentPrefix = newPath);
    _loadItems();
  }

  void _filterAndSortItems() {
    List<S3Item> filtered = _items;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((item) {
        return item.displayName.toLowerCase().contains(
          _searchQuery.toLowerCase(),
        );
      }).toList();
    }

    // Apply sorting
    switch (_sortOption) {
      case SortOption.nameAsc:
        filtered.sort((a, b) {
          if (a.isFolder && !b.isFolder) return -1;
          if (!a.isFolder && b.isFolder) return 1;
          return a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          );
        });
        break;
      case SortOption.nameDesc:
        filtered.sort((a, b) {
          if (a.isFolder && !b.isFolder) return -1;
          if (!a.isFolder && b.isFolder) return 1;
          return b.displayName.toLowerCase().compareTo(
            a.displayName.toLowerCase(),
          );
        });
        break;
      case SortOption.sizeAsc:
        filtered.sort((a, b) {
          if (a.isFolder && !b.isFolder) return -1;
          if (!a.isFolder && b.isFolder) return 1;
          return a.size.compareTo(b.size);
        });
        break;
      case SortOption.sizeDesc:
        filtered.sort((a, b) {
          if (a.isFolder && !b.isFolder) return -1;
          if (!a.isFolder && b.isFolder) return 1;
          return b.size.compareTo(a.size);
        });
        break;
      case SortOption.dateAsc:
        filtered.sort((a, b) {
          if (a.isFolder && !b.isFolder) return -1;
          if (!a.isFolder && b.isFolder) return 1;
          return a.lastModified.compareTo(b.lastModified);
        });
        break;
      case SortOption.dateDesc:
        filtered.sort((a, b) {
          if (a.isFolder && !b.isFolder) return -1;
          if (!a.isFolder && b.isFolder) return 1;
          return b.lastModified.compareTo(a.lastModified);
        });
        break;
    }

    setState(() => _filteredItems = filtered);
  }

  Future<void> _loadItems({bool keepSearch = false}) async {
    setState(() => _loading = true);
    try {
      final items = await ApiService.listS3ItemsWithPrefix(
        widget.bucketName,
        _currentPrefix,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        if (!keepSearch) {
          _searchQuery = '';
          _lastSearchText = '';
          _searchController.clear();
        }
      });
      _filterAndSortItems();
    } catch (e) {
      if (mounted) _showError('Failed to load items: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadVersioningStatus() async {
    if (!mounted) return;
    try {
      final versioningStatus = await ApiService.getBucketVersioning(
        widget.bucketName,
      );
      final mfaStatus = await ApiService.getBucketMFADelete(widget.bucketName);

      if (!mounted) return;
      setState(() {
        _versioningEnabled = versioningStatus['status'] == 'Enabled';
        _mfaDeleteEnabled = mfaStatus['mfa_delete'] == 'Enabled';
      });
    } catch (e) {
      debugPrint('Failed to load versioning status: $e');
    } finally {
      if (mounted) {
      }
    }
  }

  Future<void> _toggleVersioning(bool value) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              value ? Icons.history : Icons.warning,
              color: value ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 12),
            Text(value ? 'Enable Versioning?' : 'Disable Versioning?'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value
                    ? 'Enabling versioning will:'
                    : 'Disabling versioning will:',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (value) ...[
                const Text('• Keep multiple versions of objects'),
                const Text('• Allow recovery of deleted objects'),
                const Text('• Enable MFA Delete protection'),
                const Text('• May increase storage costs'),
              ] else ...[
                const Text('• Stop creating new object versions'),
                const Text('• Existing versions will be kept'),
                const Text('• Disable MFA Delete protection'),
                const Text('• Cannot be fully reversed'),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: value ? Colors.blue.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: value
                        ? Colors.blue.shade200
                        : Colors.orange.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: value
                          ? Colors.blue.shade700
                          : Colors.orange.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        value
                            ? 'This is a recommended security practice for production buckets.'
                            : 'This action cannot be fully undone. Proceed with caution.',
                        style: TextStyle(
                          fontSize: 12,
                          color: value
                              ? Colors.blue.shade900
                              : Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: value ? Colors.green : Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text(value ? 'Enable' : 'Disable'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ApiService.setBucketVersioning(
        widget.bucketName,
        value ? 'Enabled' : 'Suspended',
      );

      if (!mounted) return;
      setState(() => _versioningEnabled = value);

      // If disabling versioning, also disable MFA delete
      if (!value && _mfaDeleteEnabled) {
        if (!mounted) return;
        setState(() => _mfaDeleteEnabled = false);
      }

      _showSuccess('Versioning ${value ? 'enabled' : 'disabled'} successfully');
    } catch (e) {
      _showError('Failed to update versioning: $e');
    } finally {
      if (mounted) {
      }
    }
  }

  Future<void> _toggleMFADelete(bool value) async {
    if (!_versioningEnabled) {
      _showError('Versioning must be enabled before configuring MFA Delete');
      return;
    }

    // Check if MFA device is configured
    try {
      final mfaDevice = await ApiService.getMFADevice();
      if (mfaDevice['configured'] != true) {
        _showError('Please configure MFA device in Settings first');
        return;
      }
    } catch (e) {
      _showError('Please configure MFA device in Settings first');
      return;
    }

    // Show MFA token dialog
    final mfaToken = await _showMFATokenDialog();
    if (mfaToken == null || !mounted) return;

    try {
      await ApiService.updateBucketMFADelete(
        widget.bucketName,
        value ? 'Enabled' : 'Disabled',
        mfaToken,
      );

      if (!mounted) return;
      setState(() => _mfaDeleteEnabled = value);
      _showSuccess('MFA Delete ${value ? 'enabled' : 'disabled'} successfully');
    } catch (e) {
      _showError('Failed to update MFA Delete: $e');
    } finally {
      if (mounted) {
      }
    }
  }

  Future<String?> _showMFATokenDialog() async {
    if (!mounted) return null;

    return showDialog<String>(
      context: context,
      builder: (context) => _MFATokenDialog(),
    );
  }

  void _navigateToFolder(String folderKey) {
    setState(() => _currentPrefix = folderKey);
    _loadItems();
  }

  void _navigateBack() {
    if (_currentPrefix.isEmpty) return;

    final parts = _currentPrefix.split('/');
    parts.removeLast(); // Remove empty string after last /
    if (parts.isNotEmpty) {
      parts.removeLast(); // Remove current folder
      setState(
        () => _currentPrefix = parts.isEmpty ? '' : '${parts.join('/')}/',
      );
    } else {
      setState(() => _currentPrefix = '');
    }
    _loadItems();
  }

  void _showError(String message) {
    if (!mounted) return;
    ToastUtils.show(context, message, isError: true);
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ToastUtils.show(context, message, isError: false);
  }

  Future<void> _uploadFile() async {
    StreamController<double>? progressController;
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result == null) return;

      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;
      final fileSize = await file.length();

      // Create progress stream controller
      progressController = StreamController<double>.broadcast();

      if (!mounted) return;
      
      // Show loading animation
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => LoadingAnimation(
          message: 'Uploading $fileName',
          showQuote: true,
        ),
      );

      // Small delay to ensure dialog is ready
      await Future.delayed(const Duration(milliseconds: 50));

      // Initialize progress
      if (!progressController.isClosed) {
        progressController.add(0.0);
      }

      // Track real-time progress from backend
      await S3Service.uploadWithProgress(
        widget.bucketName,
        _currentPrefix + fileName,
        file,
        (sent, total) {
          if (total > 0 && !progressController!.isClosed) {
            final progress = sent / total;
            progressController.add(progress);
            debugPrint(
              'Upload progress: ${(progress * 100).toStringAsFixed(1)}%',
            );
          }
        },
      );

      // Ensure we reach 100%
      if (!progressController.isClosed) {
        progressController.add(1.0);
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Close progress stream
      if (!progressController.isClosed) {
        await progressController.close();
      }

      // Hide progress dialog
      if (mounted) Navigator.of(context).pop();

      _showSuccess('Uploaded: $fileName');
      await _loadItems();
    } catch (e) {
      // Close progress stream if open
      if (progressController != null && !progressController.isClosed) {
        await progressController.close();
      }
      // Hide progress dialog if showing
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showError('Upload failed: $e');
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  bool _canPreviewFile(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    return [
      'jpg',
      'jpeg',
      'png',
      'gif',
      'bmp',
      'webp',
      'txt',
      'md',
      'log',
      'json',
      'xml',
      'yaml',
      'yml',
      'csv',
      'html',
      'css',
      'js',
      'ts',
      'dart',
      'py',
      'java',
      'go',
      'c',
      'cpp',
      'h',
      'sh',
      'bat',
      'sql',
      'env',
      'pdf',
    ].contains(ext);
  }

  void _viewFile(S3Item item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => S3FileViewerScreen(
          bucketName: widget.bucketName,
          objectKey: item.key,
          fileName: item.displayName,
        ),
      ),
    );
    // File viewer closed, data is automatically cleared when screen is disposed
  }

  Future<void> _downloadFile(S3Item item) async {
    // Request storage permission first
    final hasPermission = await DownloadService.requestStoragePermission();

    if (!hasPermission) {
      _showError(DownloadService.getPermissionDeniedMessage());
      return;
    }

    if (!mounted) return;

    // Create progress stream controller
    final progressController = StreamController<double>();
    int bytesReceived = 0;
    int totalBytes = 0;

    // Show animated progress dialog with real progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StreamBuilder<double>(
        stream: progressController.stream,
        builder: (context, snapshot) {
          final progress = snapshot.data ?? 0.0;
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 8,
                          backgroundColor: Colors.grey[200],
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTheme.primaryPurple,
                          ),
                        ),
                      ),
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryPurple,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Downloading File',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  item.displayName,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                if (totalBytes > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${_formatBytes(bytesReceived)} / ${_formatBytes(totalBytes)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );

    try {
      final bytes = await S3Service.downloadWithProgress(
        widget.bucketName,
        item.key,
        (received, total) {
          if (total > 0) {
            bytesReceived = received;
            totalBytes = total;
            progressController.add(received / total);
          }
        },
      );

      // Save file using DownloadService
      final result = await DownloadService.saveToDownloads(
        bytes: bytes,
        fileName: item.displayName,
      );

      // Close progress stream
      await progressController.close();

      // Hide progress dialog
      if (mounted) Navigator.of(context).pop();

      if (result['success']) {
        _showSuccess('Downloaded to ${result['displayPath']}');
      } else {
        _showError('Failed to save file: ${result['error']}');
      }
    } catch (e) {
      // Close progress stream
      await progressController.close();

      // Hide progress dialog if showing
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showError('Download failed: $e');
    }
  }

  Future<void> _deleteItem(S3Item item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Delete Item'),
          ],
        ),
        content: Text('Are you sure you want to delete "${item.displayName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      
      // Show loading animation
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => LoadingAnimation(
          message: 'Deleting ${item.displayName}',
          showQuote: true,
        ),
      );

      try {
        await ApiService.deleteS3Object(widget.bucketName, item.key);

        if (mounted) Navigator.of(context).pop();

        _showSuccess('Deleted: ${item.displayName}');
        await _loadItems();
      } catch (e) {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        _showError('Delete failed: $e');
      }
    }
  }

  Future<void> _createFolder() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.create_new_folder, color: AppTheme.s3Color),
            SizedBox(width: 8),
            Text('Create Folder'),
          ],
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Folder Name',
            hintText: 'my-folder',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.folder),
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
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      if (!mounted) return;
      
      // Show loading animation
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => LoadingAnimation(
          message: 'Creating folder $result',
          showQuote: true,
        ),
      );

      try {
        await ApiService.createS3Folder(
          widget.bucketName,
          _currentPrefix + result,
        );

        if (mounted) Navigator.of(context).pop();

        _showSuccess('Created folder: $result');
        await _loadItems();
      } catch (e) {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        _showError('Create folder failed: $e');
      }
    }
  }

  Widget _buildBreadcrumbs() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppTheme.borderColorDark : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              setState(() => _currentPrefix = '');
              _loadItems();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _currentPrefix.isEmpty
                    ? AppTheme.s3Color.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.home,
                    size: 16,
                    color: _currentPrefix.isEmpty
                        ? AppTheme.s3Color
                        : theme.textTheme.bodyMedium?.color,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.bucketName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: _currentPrefix.isEmpty
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: _currentPrefix.isEmpty
                          ? AppTheme.s3Color
                          : theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_breadcrumbs.isNotEmpty) ...[
            for (int i = 0; i < _breadcrumbs.length; i++) ...[
              Icon(
                Icons.chevron_right,
                size: 16,
                color: theme.textTheme.bodyMedium?.color,
              ),
              InkWell(
                onTap: () => _navigateToBreadcrumb(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: i == _breadcrumbs.length - 1
                        ? AppTheme.s3Color.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _breadcrumbs[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: i == _breadcrumbs.length - 1
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: i == _breadcrumbs.length - 1
                          ? AppTheme.s3Color
                          : theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: _currentPrefix.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentPrefix.isNotEmpty) {
          _navigateBack();
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        floatingActionButton: SpeedDialMenu(
          closedIcon: Icons.menu,
          openIcon: Icons.close,
          backgroundColor: AppTheme.primaryPurple,
          items: [
            SpeedDialMenuItem(
              icon: Icons.upload_file,
              label: 'Upload File',
              color: AppTheme.primaryPurple,
              onTap: _uploadFile,
            ),
            SpeedDialMenuItem(
              icon: Icons.create_new_folder,
              label: 'Create Folder',
              color: AppTheme.primaryPurple,
              onTap: _createFolder,
            ),
            if (_currentPrefix.isEmpty) ...[
              SpeedDialMenuItem(
                icon: Icons.history,
                label: _versioningEnabled
                    ? 'Disable Versioning'
                    : 'Enable Versioning',
                color: _versioningEnabled
                    ? AppTheme.successGreen
                    : AppTheme.primaryPurple,
                onTap: () => _toggleVersioning(!_versioningEnabled),
              ),
              if (_versioningEnabled)
                SpeedDialMenuItem(
                  icon: Icons.security,
                  label: _mfaDeleteEnabled
                      ? 'Disable MFA Delete'
                      : 'Enable MFA Delete',
                  color: _mfaDeleteEnabled
                      ? Colors.orange
                      : AppTheme.primaryPurple,
                  onTap: () => _toggleMFADelete(!_mfaDeleteEnabled),
                ),
            ],
          ],
        ),
        appBar: AppBar(
          title: Text(widget.bucketName),
          elevation: 0,
          leading: _currentPrefix.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _navigateBack,
                  tooltip: 'Go back',
                )
              : null,
          automaticallyImplyLeading: _currentPrefix.isEmpty,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadItems,
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: Column(
          children: [
            if (_currentPrefix.isNotEmpty || _breadcrumbs.isNotEmpty)
              _buildBreadcrumbs(),
            ListHeaderWithSearch(
              title: widget.bucketName,
              subtitle:
                  '${_filteredItems.length} items${_searchQuery.isNotEmpty ? " (filtered)" : ""}',
              icon: Icons.storage,
              iconBackgroundColor: AppTheme.primaryPurple.withValues(
                alpha: 0.15,
              ),
              iconColor: AppTheme.primaryPurple,
              searchController: _searchController,
              searchHint: 'Search files and folders...',
              headerBackgroundColor: AppTheme.primaryPurple.withValues(
                alpha: 0.08,
              ),
              actionWidget: PopupMenuButton<SortOption>(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.primaryPurple.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Icon(
                    Icons.sort,
                    size: 20,
                    color: AppTheme.primaryPurple,
                  ),
                ),
                tooltip: 'Sort by',
                onSelected: (option) {
                  setState(() => _sortOption = option);
                  _filterAndSortItems();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: SortOption.nameAsc,
                    child: Row(
                      children: [
                        Icon(
                          Icons.sort_by_alpha,
                          size: 18,
                          color: AppTheme.primaryPurple,
                        ),
                        const SizedBox(width: 12),
                        const Text('Name (A-Z)'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: SortOption.nameDesc,
                    child: Row(
                      children: [
                        Icon(
                          Icons.sort_by_alpha,
                          size: 18,
                          color: AppTheme.primaryPurple,
                        ),
                        const SizedBox(width: 12),
                        const Text('Name (Z-A)'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: SortOption.sizeAsc,
                    child: Row(
                      children: [
                        Icon(
                          Icons.data_usage,
                          size: 18,
                          color: AppTheme.primaryPurple,
                        ),
                        const SizedBox(width: 12),
                        const Text('Size (Smallest)'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: SortOption.sizeDesc,
                    child: Row(
                      children: [
                        Icon(
                          Icons.data_usage,
                          size: 18,
                          color: AppTheme.primaryPurple,
                        ),
                        const SizedBox(width: 12),
                        const Text('Size (Largest)'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: SortOption.dateAsc,
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 18,
                          color: AppTheme.primaryPurple,
                        ),
                        const SizedBox(width: 12),
                        const Text('Date (Oldest)'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: SortOption.dateDesc,
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 18,
                          color: AppTheme.primaryPurple,
                        ),
                        const SizedBox(width: 12),
                        const Text('Date (Newest)'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const LoadingAnimation(message: 'Loading items...')
                  : _filteredItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchQuery.isNotEmpty
                                ? Icons.search_off
                                : Icons.folder_open_outlined,
                            size: 80,
                            color: theme.textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No matching items'
                                : 'No items found',
                            style: TextStyle(
                              fontSize: 18,
                              color: theme.textTheme.bodyMedium?.color,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Try a different search term'
                                : 'Upload files or create folders',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color
                                  ?.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            onTap: item.isFolder
                                ? () => _navigateToFolder(item.key)
                                : (_canPreviewFile(item.displayName)
                                      ? () => _viewFile(item)
                                      : null),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: item.iconColor.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      item.icon,
                                      color: item.iconColor,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.displayName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            if (!item.isFolder) ...[
                                              Icon(
                                                Icons.storage,
                                                size: 12,
                                                color: Colors.grey[600],
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                item.formattedSize,
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                            ],
                                            if (item
                                                .lastModified
                                                .isNotEmpty) ...[
                                              Icon(
                                                Icons.access_time,
                                                size: 12,
                                                color: Colors.grey[600],
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  item.lastModified,
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!item.isFolder) ...[
                                    IconButton(
                                      icon: const Icon(Icons.download),
                                      color: AppTheme.primaryPurple,
                                      tooltip: 'Download',
                                      onPressed: () => _downloadFile(item),
                                      style: IconButton.styleFrom(
                                        backgroundColor: AppTheme.primaryPurple
                                            .withValues(alpha: 0.1),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    color: AppTheme.errorRed,
                                    tooltip: 'Delete',
                                    onPressed: () => _deleteItem(item),
                                    style: IconButton.styleFrom(
                                      backgroundColor: AppTheme.errorRed
                                          .withValues(alpha: 0.1),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                  if (item.isFolder) ...[
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.chevron_right,
                                      color: Colors.grey[400],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// MFA Token Dialog Widget
class _MFATokenDialog extends StatefulWidget {
  @override
  State<_MFATokenDialog> createState() => _MFATokenDialogState();
}

class _MFATokenDialogState extends State<_MFATokenDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter MFA Token'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the 6-digit code from your MFA device:'),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'MFA Token',
                hintText: '123456',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                if (value.length == 6) {
                  Navigator.pop(context, value);
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_controller.text.length == 6) {
              Navigator.pop(context, _controller.text);
            }
          },
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
