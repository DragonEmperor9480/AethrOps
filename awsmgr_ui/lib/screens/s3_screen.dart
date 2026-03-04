import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/bucket_info.dart';
import '../models/s3_object.dart';
import '../services/api_service.dart';
import '../services/download_service.dart';
import '../widgets/loading_animation.dart';
import '../widgets/list_header_with_search.dart';
import '../widgets/speed_dial_menu.dart';
import '../theme/app_theme.dart';
import '../utils/toast_utils.dart';
import 's3_browser_screen.dart';

class S3Screen extends StatefulWidget {
  const S3Screen({super.key});

  @override
  State<S3Screen> createState() => _S3ScreenState();
}


class _S3ScreenState extends State<S3Screen> {
  List<BucketInfo> _buckets = [];
  List<BucketInfo> _filteredBuckets = [];
  bool _loading = false;
  bool _operationInProgress = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterBuckets);
    _loadBuckets();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _filterBuckets() {
    setState(() {
      final query = _searchController.text.toLowerCase();
      _filteredBuckets = query.isEmpty
          ? _buckets
          : _buckets
                .where((bucket) => bucket.name.toLowerCase().contains(query))
                .toList();
    });
  }

  Future<void> _loadBuckets() async {
    setState(() => _loading = true);
    try {
      final bucketsStr = await ApiService.listS3Buckets();
      // Parse bucket info from the string
      // Format: "2024-11-14 10:30:00 bucket-name"
      final bucketList = bucketsStr
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map((line) {
            final parts = line.trim().split(' ');
            if (parts.length >= 3) {
              final date = parts[0];
              final time = parts[1];
              final name = parts.sublist(2).join(' ');
              return BucketInfo(name: name, creationDate: '$date $time');
            }
            return BucketInfo(name: line.trim(), creationDate: 'Unknown');
          })
          .toList();

      setState(() {
        _buckets = bucketList;
        _filteredBuckets = bucketList;
      });
    } catch (e) {
      _showError('Failed to load buckets: $e');
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

  Future<void> _createBucket() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.add_circle, color: AppTheme.primaryPurple),
            SizedBox(width: 8),
            Text('Create S3 Bucket'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Bucket Name',
                hintText: 'my-unique-bucket-name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.storage),
                helperText: 'Must be globally unique and DNS-compliant',
              ),
              autofocus: true,
            ),
          ],
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
      setState(() => _operationInProgress = true);
      try {
        await ApiService.createS3Bucket(result);
        _showSuccess('Bucket "$result" created successfully');
        await _loadBuckets();
      } catch (e) {
        _showError('Failed to create bucket: $e');
      } finally {
        setState(() => _operationInProgress = false);
      }
    }
  }

  Future<void> _deleteBucket(String bucketName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Delete Bucket'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to delete "$bucketName"?'),
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone. The bucket must be empty.',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _operationInProgress = true);
      try {
        await ApiService.deleteS3Bucket(bucketName);
        _showSuccess('Bucket "$bucketName" deleted successfully');
        await _loadBuckets();
      } catch (e) {
        _showError('Failed to delete bucket: $e');
      } finally {
        setState(() => _operationInProgress = false);
      }
    }
  }

  Future<void> _viewBucketObjects(String bucketName) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => S3BrowserScreen(bucketName: bucketName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _operationInProgress,
      message: 'Processing...',
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(title: const Text('S3 Management'), elevation: 0),
        floatingActionButton: SpeedDialMenu(
          closedIcon: Icons.menu,
          openIcon: Icons.close,
          backgroundColor: AppTheme.primaryPurple,
          items: [
            SpeedDialMenuItem(
              icon: Icons.add_box,
              label: 'Create Bucket',
              color: AppTheme.primaryPurple,
              onTap: _createBucket,
            ),
            SpeedDialMenuItem(
              icon: Icons.refresh,
              label: 'Refresh',
              color: AppTheme.primaryPurple,
              onTap: _loadBuckets,
            ),
          ],
        ),
        body: Column(
          children: [
            ListHeaderWithSearch(
              title: 'S3 Buckets',
              subtitle: '${_filteredBuckets.length} buckets',
              svgAsset:
                  'assets/icons/Arch_Amazon-Simple-Storage-Service_32.svg',
              iconBackgroundColor: AppTheme.primaryPurple.withValues(
                alpha: 0.15,
              ),
              iconColor: AppTheme.primaryPurple,
              searchController: _searchController,
              searchFocusNode: _searchFocusNode,
              searchHint: 'Search buckets by name...',
              headerBackgroundColor: AppTheme.primaryPurple.withValues(
                alpha: 0.08,
              ),
            ),
            Expanded(
              child: _loading
                  ? const LoadingAnimation(message: 'Loading buckets')
                  : _filteredBuckets.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.storage_outlined,
                            size: 80,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _buckets.isEmpty
                                ? 'No buckets found'
                                : 'No matching buckets',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _buckets.isEmpty
                                ? 'Create your first S3 bucket'
                                : 'Try a different search term',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                          if (_buckets.isEmpty) ...[
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _createBucket,
                              icon: const Icon(Icons.add),
                              label: const Text('Create Bucket'),
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredBuckets.length,
                      itemBuilder: (context, index) {
                        final bucket = _filteredBuckets[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            onTap: () => _viewBucketObjects(bucket.name),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ShaderMask(
                                          shaderCallback: (bounds) =>
                                              const LinearGradient(
                                                colors: [
                                                  Color(0xFF6366F1),
                                                  Color(0xFF8B5CF6),
                                                  Color(0xFFA855F7),
                                                ],
                                              ).createShader(bounds),
                                          child: Text(
                                            bucket.name,
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
                                              Icons.calendar_today,
                                              size: 12,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              bucket.creationDate,
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    color: AppTheme.errorRed,
                                    tooltip: 'Delete bucket',
                                    onPressed: () => _deleteBucket(bucket.name),
                                    style: IconButton.styleFrom(
                                      backgroundColor: AppTheme.errorRed
                                          .withValues(alpha: 0.1),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.chevron_right,
                                    color: Colors.grey[400],
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
        ),
      ),
    );
  }
}

class BucketObjectsScreen extends StatefulWidget {
  final String bucketName;

  const BucketObjectsScreen({super.key, required this.bucketName});

  @override
  State<BucketObjectsScreen> createState() => _BucketObjectsScreenState();
}




class _BucketObjectsScreenState extends State<BucketObjectsScreen> {
  List<S3Object> _objects = [];
  String _versioningStatus = 'Loading...';
  bool _loading = false;
  String? _downloadingKey;

  @override
  void initState() {
    super.initState();
    _loadObjects();
    _loadVersioningStatus();
  }

  @override
  void dispose() {
    // Ensure no setState calls happen after widget is unmounted
    super.dispose();
  }

  Future<void> _loadObjects() async {
    setState(() => _loading = true);
    try {
      final objectsStr = await ApiService.listS3Objects(widget.bucketName);
      // Parse objects from string
      // Format: "2024-11-14 10:30:00       1234 file.txt"
      final objectList = objectsStr
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map((line) {
            final parts = line.trim().split(RegExp(r'\s+'));
            if (parts.length >= 4) {
              final date = parts[0];
              final time = parts[1];
              final size = int.tryParse(parts[2]) ?? 0;
              final key = parts.sublist(3).join(' ');
              return S3Object(
                key: key,
                lastModified: '$date $time',
                size: size,
              );
            }
            return null;
          })
          .whereType<S3Object>()
          .toList();

      setState(() => _objects = objectList);
    } catch (e) {
      _showError('Failed to load objects: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadVersioningStatus() async {
    try {
      final result = await ApiService.getBucketVersioning(widget.bucketName);
      final status = result['status'] as String? ?? '';
      setState(() {
        _versioningStatus = status.isEmpty ? 'Disabled' : status;
      });
    } catch (e) {
      setState(() => _versioningStatus = 'Unknown');
    }
  }

  void _showError(String message) {
    ToastUtils.show(context, message, isError: true);
  }

  void _showSuccess(String message) {
    ToastUtils.show(context, message, isError: false);
  }

  Future<void> _downloadObject(S3Object object) async {
    debugPrint('===== _downloadObject called for: ${object.key} =====');
    setState(() => _downloadingKey = object.key);

    try {
      // Request storage permission first
      final hasPermission = await DownloadService.requestStoragePermission();

      if (!hasPermission) {
        _showError(DownloadService.getPermissionDeniedMessage());
        setState(() => _downloadingKey = null);
        return;
      }

      final bytes = await ApiService.downloadS3Object(
        widget.bucketName,
        object.key,
      );

      final fileName = object.key.split('/').last;

      // Save file using DownloadService
      final result = await DownloadService.saveToDownloads(
        bytes: bytes,
        fileName: fileName,
      );

      if (result['success']) {
        _showSuccess('Downloaded to ${result['displayPath']}');
      } else {
        _showError('Failed to save file: ${result['error']}');
      }
    } catch (e) {
      _showError('Failed to download: $e');
    } finally {
      setState(() => _downloadingKey = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text(widget.bucketName),
        elevation: 0,
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadObjects,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: AppTheme.primaryPurple.withValues(alpha: 0.1),
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.folder_open,
                    color: AppTheme.primaryPurple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Objects',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Files and folders in this bucket',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            _versioningStatus == 'Enabled'
                                ? Icons.check_circle
                                : Icons.cancel,
                            size: 14,
                            color: _versioningStatus == 'Enabled'
                                ? AppTheme.successGreen
                                : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Versioning: $_versioningStatus',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
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
          Expanded(
            child: _loading
                ? const LoadingAnimation(message: 'Loading objects')
                : _objects.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_open_outlined,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No objects found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This bucket is empty',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _objects.length,
                    itemBuilder: (context, index) {
                      final object = _objects[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: object.iconColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              object.icon,
                              color: object.iconColor,
                              size: 28,
                            ),
                          ),
                          title: Text(
                            object.key,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.storage,
                                    size: 12,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    object.formattedSize,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(
                                    Icons.access_time,
                                    size: 12,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      object.lastModified,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: _downloadingKey == object.key
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.download),
                                  color: AppTheme.primaryPurple,
                                  tooltip: 'Download',
                                  onPressed: () => _downloadObject(object),
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppTheme.primaryPurple
                                        .withValues(alpha: 0.1),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
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
