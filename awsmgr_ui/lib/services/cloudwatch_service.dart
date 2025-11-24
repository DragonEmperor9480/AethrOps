import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class LogEntry {
  final String message;
  final String color;
  final DateTime timestamp;

  LogEntry({
    required this.message,
    required this.color,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      message: json['message'] ?? '',
      color: json['color'] ?? 'white',
    );
  }
}

class CloudWatchService {
  static const String baseUrl = 'http://localhost:9480/api';

  // List all Lambda functions
  static Future<List<String>> listLambdaFunctions() async {
    final response = await http.get(
      Uri.parse('$baseUrl/cloudwatch/lambda/functions'),
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<String>.from(data['functions'] ?? []);
    }
    throw Exception('Failed to load Lambda functions');
  }

  // Stream Lambda logs using Server-Sent Events
  static Stream<LogEntry> streamLambdaLogs(String functionName) async* {
    final url = '$baseUrl/cloudwatch/lambda/$functionName/logs';
    
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await request.send();
      
      if (response.statusCode != 200) {
        throw Exception('Failed to connect to log stream');
      }

      await for (var chunk in response.stream.transform(utf8.decoder)) {
        // Parse SSE data
        final lines = chunk.split('\n');
        for (var line in lines) {
          if (line.startsWith('data: ')) {
            final jsonStr = line.substring(6);
            try {
              final data = json.decode(jsonStr);
              if (data['type'] == 'log') {
                yield LogEntry.fromJson(data);
              } else if (data['type'] == 'error') {
                debugPrint('Stream error: ${data['error']}');
              }
            } catch (e) {
              debugPrint('Error parsing log entry: $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Stream error: $e');
      rethrow;
    }
  }
}
