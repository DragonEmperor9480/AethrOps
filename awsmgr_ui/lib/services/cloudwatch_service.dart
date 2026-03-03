import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class LogEntry {
  final String message;
  final DateTime timestamp;

  LogEntry({
    required this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      message: json['message'] ?? '',
      timestamp: json['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'])
          : null,
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

  // Stream Lambda logs using Server-Sent Events with proper SSE parsing
  static Stream<LogEntry> streamLambdaLogs(String functionName) async* {
    final url = '$baseUrl/cloudwatch/lambda/$functionName/logs';
    
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await request.send();
      
      if (response.statusCode != 200) {
        throw Exception('Failed to connect to log stream');
      }

      String buffer = '';
      await for (var chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk;
        
        // Process complete SSE events (ending with \n\n)
        while (buffer.contains('\n\n')) {
          final eventEnd = buffer.indexOf('\n\n');
          final eventBlock = buffer.substring(0, eventEnd);
          buffer = buffer.substring(eventEnd + 2);
          
          // Parse the event block
          String? eventId;
          String? data;
          
          for (var line in eventBlock.split('\n')) {
            if (line.startsWith('id: ')) {
              eventId = line.substring(4);
            } else if (line.startsWith('data: ')) {
              data = line.substring(6);
            } else if (line.startsWith(':')) {
              // Keepalive comment, ignore
              continue;
            }
          }
          
          if (data != null) {
            try {
              final jsonData = json.decode(data);
              if (jsonData['type'] == 'log') {
                yield LogEntry.fromJson(jsonData);
              } else if (jsonData['type'] == 'error') {
                debugPrint('Stream error: ${jsonData['error']}');
                throw Exception(jsonData['error']);
              } else if (jsonData['type'] == 'connected') {
                debugPrint('Connected to log stream: ${jsonData['function']}');
              }
            } catch (e) {
              if (e is Exception) rethrow;
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
