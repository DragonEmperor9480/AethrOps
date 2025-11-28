import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../services/s3_service.dart';
import '../services/download_service.dart';
import '../widgets/loading_animation.dart';
import '../widgets/progress_dialog.dart';
import '../widgets/list_header_with_search.dart';
import '../widgets/speed_dial_menu.dart';
import '../theme/app_theme.dart';

class S3BrowserScreen extends StatefulWidget {
  final String bucketName;

  const S3BrowserScreen({super.key, required this.bucketName});

  @override
  State<S3BrowserScreen> createState() => _S3BrowserScreenState();
}

class S3Item {
  final String key;
  final int size;
  final String lastModified;
  final bool isFolder;

  S3Item({
    required this.key,
    required this.size,
    required this.lastModified,
    required this.isFolder,
  });

  factory S3Item.fromJson(Map<String, dynamic> json) {
    return S3Item(
      key: json['Key'] ?? '',
      size: json['Size'] ?? 0,
      lastModified: json['LastModified'] ?? '',
      isFolder: json['IsFolder'] ?? false,
    );
  }

  String get displayName {
    if (key.isEmpty) return '';
    final parts = key.split('/');
    if (isFolder) {
      return parts.length > 1 ? parts[parts.length - 2] : parts[0];
    }
    return parts.last;
  }

  String get formattedSize {
    if (isFolder) return '';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  IconData get icon {
    if (isFolder) return Icons.folder;
    
    final ext = key.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
        return Icons.audio_file;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'txt':
      case 'md':
        return Icons.text_snippet;
      case 'json':
      case 'xml':
        return Icons.code;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color get iconColor {
    if (isFolder) return Colors.amber;
    
    final ext = key.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Colors.red;
      case 'zip':
      case 'rar':
        return Colors.orange;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Colors.purple;
      case 'mp4':
      case 'avi':
        return Colors.blue;
      case 'mp3':
      case 'wav':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

enum SortOption { nameAsc, nameDesc, sizeAsc, sizeDesc, dateAsc, dateDesc }

class _S3BrowserScreenState extends State<S3BrowserScreen> {
  List<S3Item> _items = [];
  List<S3Item> _filteredItems = [];
  String _currentPrefix = '';
  bool _loading = false;
  String _searchQuery = '';
  SortOption _sortOption = SortOption.nameAsc;
  final TextEditingController _searchController = TextEditingController();
  
  // Versioning and MFA Delete state
  bool _versioningEnabled = false;
  bool _mfaDeleteEnabled = false;
  bool _loadingVersioning = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
    _loadVersioningStatus();
  }

  @override
  void dispose() {
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
    
    final newPath = parts.sublist(0, index + 1).join('/') + '/';
    setState(() => _currentPrefix = newPath);
    _loadItems();
  }

  void _filterAndSortItems() {
    List<S3Item> filtered = _items;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((item) {
        return item.displayName.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Apply sorting
    switch (_sortOption) {
      case SortOption.nameAsc:
        filtered.sort((a, b) {
          if (a.isFolder && !b.isFolder) return -1;
          if (!a.isFolder && b.isFolder) return 1;
          return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
        });
        break;
      case SortOption.nameDesc:
        filtered.sort((a, b) {
          if (a.isFolder && !b.isFolder) return -1;
          if (!a.isFolder && b.isFolder) return 1;
          return b.displayName.toLowerCase().compareTo(a.displayName.toLowerCase());
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

  Future<void> _loadItems() async {
    setState(() => _loading = true);
    try {
      final items = await ApiService.listS3ItemsWithPrefix(
        widget.bucketName,
        _currentPrefix,
      );
      setState(() {
        _items = items;
        _searchQuery = '';
        _searchController.clear();
      });
      _filterAndSortItems();
    } catch (e) {
      _showError('Failed to load items: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadVersioningStatus() async {
    if (!mounted) return;
    setState(() => _loadingVersioning = true);
    try {
      final versioningStatus = await ApiService.getBucketVersioning(widget.bucketName);
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
        setState(() => _loadingVersioning = false);
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
                  color: value ? Colors.blue.shade200 : Colors.orange.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: value ? Colors.blue.shade700 : Colors.orange.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      value
                          ? 'This is a recommended security practice for production buckets.'
                          : 'This action cannot be fully undone. Proceed with caution.',
                      style: TextStyle(
                        fontSize: 12,
                        color: value ? Colors.blue.shade900 : Colors.orange.shade900,
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

    setState(() => _loadingVersioning = true);
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
        setState(() => _loadingVersioning = false);
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

    setState(() => _loadingVersioning = true);
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
        setState(() => _loadingVersioning = false);
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
      setState(() => _currentPrefix = parts.isEmpty ? '' : '${parts.join('/')}/');
    } else {
      setState(() => _currentPrefix = '');
    }
    _loadItems();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.successGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
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

      // Show animated progress dialog with real progress
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AnimatedProgressDialog(
          title: 'Uploading File',
          message: '$fileName (${_formatBytes(fileSize)})',
          progressStream: progressController!.stream,
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
            print('Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
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

  Future<void> _downloadFile(S3Item item) async {
    // Request storage permission first
    final hasPermission = await DownloadService.requestStoragePermission();
    
    if (!hasPermission) {
      _showError(DownloadService.getPermissionDeniedMessage());
      return;
    }

    // Create progress stream controller
    final progressController = StreamController<double>();

    // Show animated progress dialog with real progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AnimatedProgressDialog(
        title: 'Downloading File',
        message: '${item.displayName} (${item.formattedSize})',
        progressStream: progressController.stream,
      ),
    );

    try {
      final bytes = await S3Service.downloadWithProgress(
        widget.bucketName,
        item.key,
        (received, total) {
          if (total > 0) {
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
      // Show animated progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AnimatedProgressDialog(
          title: 'Deleting Item',
          message: item.displayName,
        ),
      );

      try {
        await ApiService.deleteS3Object(widget.bucketName, item.key);

        // Hide progress dialog
        if (mounted) Navigator.of(context).pop();

        _showSuccess('Deleted: ${item.displayName}');
        await _loadItems();
      } catch (e) {
        // Hide progress dialog if showing
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
      // Show animated progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AnimatedProgressDialog(
          title: 'Creating Folder',
          message: result,
        ),
      );

      try {
        await ApiService.createS3Folder(
          widget.bucketName,
          _currentPrefix + result,
        );

        // Hide progress dialog
        if (mounted) Navigator.of(context).pop();

        _showSuccess('Created folder: $result');
        await _loadItems();
      } catch (e) {
        // Hide progress dialog if showing
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        _showError('Create folder failed: $e');
      }
    }
  }

  Widget _buildBreadcrumbs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
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
                        : Colors.grey.shade600,
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
                          : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_breadcrumbs.isNotEmpty) ...[
            for (int i = 0; i < _breadcrumbs.length; i++) ...[
              Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade400),
              InkWell(
                onTap: () => _navigateToBreadcrumb(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                          : Colors.grey.shade700,
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
    return Scaffold(
        backgroundColor: AppTheme.backgroundLight,
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
                label: _versioningEnabled ? 'Disable Versioning' : 'Enable Versioning',
                color: _versioningEnabled ? AppTheme.successGreen : AppTheme.primaryPurple,
                onTap: () => _toggleVersioning(!_versioningEnabled),
              ),
              if (_versioningEnabled)
                SpeedDialMenuItem(
                  icon: Icons.security,
                  label: _mfaDeleteEnabled ? 'Disable MFA Delete' : 'Enable MFA Delete',
                  color: _mfaDeleteEnabled ? Colors.orange : AppTheme.primaryPurple,
                  onTap: () => _toggleMFADelete(!_mfaDeleteEnabled),
                ),
            ],
          ],
        ),
        appBar: AppBar(
          title: Text(widget.bucketName),
          elevation: 0,
          backgroundColor: Colors.white,
          actions: [
            if (_currentPrefix.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.arrow_upward),
                onPressed: _navigateBack,
                tooltip: 'Go back',
              ),
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
              subtitle: '${_filteredItems.length} items${_searchQuery.isNotEmpty ? " (filtered)" : ""}',
              icon: Icons.storage,
              iconBackgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.15),
              iconColor: AppTheme.primaryPurple,
              searchController: _searchController,
              searchHint: 'Search files and folders...',
              headerBackgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.08),
              actionWidget: PopupMenuButton<SortOption>(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.2)),
                  ),
                  child: const Icon(Icons.sort, size: 20, color: AppTheme.primaryPurple),
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
                        Icon(Icons.sort_by_alpha, size: 18, color: AppTheme.primaryPurple),
                        const SizedBox(width: 12),
                        const Text('Name (A-Z)'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: SortOption.nameDesc,
                    child: Row(
                      children: [
                        Icon(Icons.sort_by_alpha, size: 18, color: AppTheme.primaryPurple),
                        const SizedBox(width: 12),
                        const Text('Name (Z-A)'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: SortOption.sizeAsc,
                    child: Row(
                      children: [
                        Icon(Icons.data_usage, size: 18, color: AppTheme.primaryPurple),
                        const SizedBox(width: 12),
                        const Text('Size (Smallest)'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: SortOption.sizeDesc,
                    child: Row(
                      children: [
                        Icon(Icons.data_usage, size: 18, color: AppTheme.primaryPurple),
                        const SizedBox(width: 12),
                        const Text('Size (Largest)'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: SortOption.dateAsc,
                    child: Row(
                      children: [
                        Icon(Icons.access_time, size: 18, color: AppTheme.primaryPurple),
                        const SizedBox(width: 12),
                        const Text('Date (Oldest)'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: SortOption.dateDesc,
                    child: Row(
                      children: [
                        Icon(Icons.access_time, size: 18, color: AppTheme.primaryPurple),
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
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty 
                                    ? 'No matching items' 
                                    : 'No items found',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _searchQuery.isNotEmpty 
                                    ? 'Try a different search term' 
                                    : 'Upload files or create folders',
                                style: TextStyle(color: Colors.grey[500]),
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
                                    : null,
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: item.iconColor.withValues(alpha: 0.1),
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
                                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                                  Icon(Icons.storage,
                                                      size: 12, color: Colors.grey[600]),
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
                                                if (item.lastModified.isNotEmpty) ...[
                                                  Icon(Icons.access_time,
                                                      size: 12, color: Colors.grey[600]),
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
                                            backgroundColor:
                                                AppTheme.primaryPurple.withValues(alpha: 0.1),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
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
                                          backgroundColor:
                                              AppTheme.errorRed.withValues(alpha: 0.1),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                      if (item.isFolder) ...[
                                        const SizedBox(width: 8),
                                        Icon(Icons.chevron_right, color: Colors.grey[400]),
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
