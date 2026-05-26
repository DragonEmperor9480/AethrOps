import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'backend_service.dart';

class LogEntry {
  final String message;
  final DateTime timestamp;
  
  // Cache for pre-parsed structures to optimize UI list scroll performance
  final Map<String, dynamic>? parsedJson;
  final String? jsonPrefix;

  LogEntry({
    required this.message,
    DateTime? timestamp,
    this.parsedJson,
    this.jsonPrefix,
  }) : timestamp = timestamp ?? DateTime.now();

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    final rawMessage = json['message'] ?? '';
    final parsed = _tryParseJson(rawMessage);
    
    return LogEntry(
      message: rawMessage,
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'])
          : null,
      parsedJson: parsed != null ? parsed['json'] as Map<String, dynamic>? : null,
      jsonPrefix: parsed != null ? parsed['prefix'] as String? : null,
    );
  }

  static Map<String, dynamic>? _tryParseJson(String text) {
    final jsonStartIndex = text.indexOf('{');
    final arrayStartIndex = text.indexOf('[');

    int startIndex = -1;
    if (jsonStartIndex != -1 && arrayStartIndex != -1) {
      startIndex = jsonStartIndex < arrayStartIndex ? jsonStartIndex : arrayStartIndex;
    } else if (jsonStartIndex != -1) {
      startIndex = jsonStartIndex;
    } else if (arrayStartIndex != -1) {
      startIndex = arrayStartIndex;
    }

    if (startIndex == -1) {
      return null;
    }

    final jsonPart = text.substring(startIndex).trim();

    try {
      final decoded = json.decode(jsonPart);
      return {'prefix': text.substring(0, startIndex), 'json': decoded};
    } catch (e) {
      // Not valid JSON, try to convert Go struct format like {Key:Value}
      final goStructMatch = RegExp(r'\{([^}]+)\}').firstMatch(jsonPart);
      if (goStructMatch != null) {
        final structContent = goStructMatch.group(1)!;
        final converted = _convertGoStructToJson(structContent);
        if (converted != null) {
          return {'prefix': text.substring(0, startIndex), 'json': converted};
        }
      }
      return null;
    }
  }

  static Map<String, dynamic>? _convertGoStructToJson(String goStruct) {
    try {
      final result = <String, dynamic>{};
      final pairs = goStruct.split(RegExp(r'\s+(?=[A-Z])'));

      for (final pair in pairs) {
        final colonIndex = pair.indexOf(':');
        if (colonIndex == -1) continue;

        final key = pair.substring(0, colonIndex).trim();
        final value = pair.substring(colonIndex + 1).trim();

        if (key.isEmpty) continue;

        final numValue = num.tryParse(value);
        if (numValue != null) {
          result[key] = numValue;
        } else if (value.toLowerCase() == 'true') {
          result[key] = true;
        } else if (value.toLowerCase() == 'false') {
          result[key] = false;
        } else if (value.toLowerCase() == 'null') {
          result[key] = null;
        } else {
          result[key] = value;
        }
      }

      return result.isEmpty ? null : result;
    } catch (e) {
      return null;
    }
  }
}

class CloudWatchService {
  static String get baseUrl => '${BackendService.baseUrl}/api';

  // Stream Lambda logs using Server-Sent Events with proper SSE parsing
  // Yields either LogEntry or Map with sessionId
  static Stream<dynamic> streamLambdaLogs(String functionName) async* {
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
          String? data;

          for (var line in eventBlock.split('\n')) {
            if (line.startsWith('id: ')) {
              // Event ID - not currently used but part of SSE spec
              continue;
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
                // Yield session ID as a special event
                yield {'type': 'session', 'sessionId': jsonData['sessionId']};
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
