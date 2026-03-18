import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/s3_service.dart';
import '../theme/app_theme.dart';
import '../utils/toast_utils.dart';

class S3FileViewerScreen extends StatefulWidget {
  final String bucketName;
  final String objectKey;
  final String fileName;

  const S3FileViewerScreen({
    super.key,
    required this.bucketName,
    required this.objectKey,
    required this.fileName,
  });

  @override
  State<S3FileViewerScreen> createState() => _S3FileViewerScreenState();
}

class _S3FileViewerScreenState extends State<S3FileViewerScreen> {
  bool _loading = true;
  String? _error;
  Uint8List? _fileData;
  String? _textContent;
  FileType _fileType = FileType.unknown;
  double _loadingProgress = 0.0;
  int _bytesReceived = 0;
  int _totalBytes = 0;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  @override
  void dispose() {
    // Clear file data to free memory
    _fileData = null;
    _textContent = null;
    super.dispose();
  }

  FileType _detectFileType(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;

    // Images
    if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext)) {
      return FileType.image;
    }

    // Text files
    if ([
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
    ].contains(ext)) {
      return FileType.text;
    }

    // PDF
    if (ext == 'pdf') {
      return FileType.pdf;
    }

    return FileType.unknown;
  }

  Future<void> _loadFile() async {
    setState(() {
      _loading = true;
      _error = null;
      _loadingProgress = 0.0;
      _bytesReceived = 0;
      _totalBytes = 0;
    });

    try {
      _fileType = _detectFileType(widget.fileName);

      // Download with progress tracking
      final bytes = await S3Service.downloadWithProgress(
        widget.bucketName,
        widget.objectKey,
        (received, total) {
          if (mounted && total > 0) {
            // Throttle UI updates to every 2% for better performance
            final newProgress = received / total;
            if ((newProgress - _loadingProgress).abs() > 0.02 ||
                received == total) {
              setState(() {
                _bytesReceived = received;
                _totalBytes = total;
                _loadingProgress = newProgress;
              });
            }
          }
        },
      );

      if (!mounted) return;

      // Process data efficiently based on file type
      if (_fileType == FileType.text) {
        // Decode text in a compute isolate for large files
        if (bytes.length > 100000) {
          // 100KB threshold
          _textContent = await compute(_decodeText, bytes);
        } else {
          _textContent = String.fromCharCodes(bytes);
        }
        // Don't keep raw bytes for text files to save memory
        _fileData = null;
      } else {
        // For images and other binary files, use Uint8List directly
        _fileData = Uint8List.fromList(bytes);
      }

      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load file: $e';
        _loading = false;
      });
    }
  }

  // Static function for compute isolate
  static String _decodeText(List<int> bytes) {
    return String.fromCharCodes(bytes);
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _showError(String message) {
    if (!mounted) return;
    ToastUtils.show(context, message, isError: true);
  }

  Widget _buildContent() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: _loadingProgress > 0 ? _loadingProgress : null,
                      strokeWidth: 8,
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryPurple,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(_loadingProgress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryPurple,
                        ),
                      ),
                      if (_totalBytes > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${_formatBytes(_bytesReceived)} / ${_formatBytes(_totalBytes)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Loading file...',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              widget.fileName,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: AppTheme.errorRed),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadFile,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    switch (_fileType) {
      case FileType.image:
        return _buildImageViewer();
      case FileType.text:
        return _buildTextViewer();
      case FileType.pdf:
        return _buildPdfViewer();
      case FileType.unknown:
        return _buildUnsupportedViewer();
    }
  }

  Widget _buildImageViewer() {
    if (_fileData == null) return const SizedBox();

    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: Image.memory(
          _fileData!,
          fit: BoxFit.contain,
          // Enable caching for better performance
          cacheWidth: null,
          cacheHeight: null,
          // Use faster decoding
          isAntiAlias: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Failed to load image'),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTextViewer() {
    if (_textContent == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        _textContent!,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
      ),
    );
  }

  Widget _buildPdfViewer() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.picture_as_pdf, size: 80, color: AppTheme.errorRed),
          const SizedBox(height: 16),
          const Text(
            'PDF Viewer',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'PDF viewing requires additional plugin',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              _showError('PDF viewing not yet implemented');
            },
            icon: const Icon(Icons.download),
            label: const Text('Download to view'),
          ),
        ],
      ),
    );
  }

  Widget _buildUnsupportedViewer() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.insert_drive_file, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Preview not available',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'File type: ${widget.fileName.split('.').last.toUpperCase()}',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Go back'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.fileName),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFile,
            tooltip: 'Reload',
          ),
        ],
      ),
      body: _buildContent(),
    );
  }
}

enum FileType { image, text, pdf, unknown }
