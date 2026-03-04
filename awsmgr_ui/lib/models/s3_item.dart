import 'package:flutter/material.dart';

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
