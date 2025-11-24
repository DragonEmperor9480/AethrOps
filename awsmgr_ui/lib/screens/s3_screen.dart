import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../services/api_service.dart';
import '../widgets/loading_animation.dart';
import '../theme/app_theme.dart';
import 's3_browser_screen.dart';

class S3Screen extends StatefulWidget {
  const S3Screen({super.key});

  @override
  State<S3Screen> createState() => _S3ScreenState();
}

class BucketInfo {
  final String name;
  final String creationDate;

  BucketInfo({
    required this.name,
    required this.creationDate,
  });
}

class _S3ScreenState extends State<S3Screen> {
  List<BucketInfo> _buckets = [];
  bool _loading = false;
  bool _operationInProgress = false;

  @override
  void initState() {
    super.initState();
    _loadBuckets();
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
              return BucketInfo(
                name: name,
                creationDate: '$date $time',
              );
            }
            return BucketInfo(name: line.trim(), creationDate: 'Unknown');
          })
          .toList();
      
      setState(() => _buckets = bucketList);
    } catch (e) {
      _showError('Failed to load buckets: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showError(String message) {
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

  Future<void> _createBucket() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.add_circle, color: AppTheme.s3Color),
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
        backgroundColor: AppTheme.backgroundLight,
        appBar: AppBar(
          title: const Text('S3 Management'),
          elevation: 0,
          backgroundColor: Colors.white,
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: AppTheme.s3Color.withValues(alpha: 0.1),
                border: Border(
                  bottom: BorderSide(color: AppTheme.s3Color.withValues(alpha: 0.2)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.s3Color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.storage, color: AppTheme.s3Color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'S3 Buckets',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_buckets.length} buckets found',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _createBucket,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Bucket'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadBuckets,
                    tooltip: 'Refresh',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const LoadingAnimation(message: 'Loading buckets')
                  : _buckets.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.storage_outlined,
                                  size: 80, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(
                                'No buckets found',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Create your first S3 bucket',
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: _createBucket,
                                icon: const Icon(Icons.add),
                                label: const Text('Create Bucket'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _buckets.length,
                          itemBuilder: (context, index) {
                            final bucket = _buckets[index];
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
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              AppTheme.s3Color.withValues(alpha: 0.8),
                                              AppTheme.s3Color,
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.storage,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              bucket.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Icon(Icons.calendar_today,
                                                    size: 12, color: Colors.grey[600]),
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
                                          backgroundColor: AppTheme.errorRed.withValues(alpha: 0.1),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(Icons.chevron_right, color: Colors.grey[400]),
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

class S3Object {
  final String key;
  final String lastModified;
  final int size;

  S3Object({
    required this.key,
    required this.lastModified,
    required this.size,
  });

  String get extension {
    final parts = key.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  IconData get icon {
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return Icons.folder_zip;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'svg':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'mkv':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
      case 'flac':
        return Icons.audio_file;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'txt':
      case 'md':
        return Icons.text_snippet;
      case 'json':
      case 'xml':
      case 'yaml':
      case 'yml':
        return Icons.code;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color get iconColor {
    switch (extension) {
      case 'pdf':
        return Colors.red;
      case 'zip':
      case 'rar':
      case '7z':
        return Colors.orange;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Colors.purple;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Colors.blue;
      case 'mp3':
      case 'wav':
        return Colors.green;
      case 'doc':
      case 'docx':
        return Colors.blue.shade700;
      case 'xls':
      case 'xlsx':
        return Colors.green.shade700;
      default:
        return Colors.grey;
    }
  }

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
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

  Future<void> _downloadObject(S3Object object) async {
    setState(() => _downloadingKey = object.key);
    
    try {
      final bytes = await ApiService.downloadS3Object(widget.bucketName, object.key);
      
      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
      } else {
        directory = await getDownloadsDirectory();
      }
      
      if (directory == null) {
        throw Exception('Could not access downloads folder');
      }
      
      final fileName = object.key.split('/').last;
      final filePath = '${directory.path}/$fileName';
      
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      
      _showSuccess('Downloaded: $fileName');
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
              color: AppTheme.s3Color.withValues(alpha: 0.1),
              border: Border(
                bottom: BorderSide(color: AppTheme.s3Color.withValues(alpha: 0.2)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.s3Color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.folder_open, color: AppTheme.s3Color),
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
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
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
                            Icon(Icons.folder_open_outlined,
                                size: 80, color: Colors.grey[300]),
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
                                      Icon(Icons.storage,
                                          size: 12, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Text(
                                        object.formattedSize,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Icon(Icons.access_time,
                                          size: 12, color: Colors.grey[600]),
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
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : IconButton(
                                      icon: const Icon(Icons.download),
                                      color: AppTheme.primaryPurple,
                                      tooltip: 'Download',
                                      onPressed: () => _downloadObject(object),
                                      style: IconButton.styleFrom(
                                        backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.1),
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
