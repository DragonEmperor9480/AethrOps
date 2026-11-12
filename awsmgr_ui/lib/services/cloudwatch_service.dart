import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'backend_service.dart';

class LogEntry {
  final String message;
  final DateTime timestamp;

  // Cache for pre-parsed structures to optimize UI list scroll performance.
  // The JSON part of the line: a Map (object) or a List (array).
  final Object? parsedJson;
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
      // An object or an array; a cast to Map threw on arrays and the line was
      // dropped
      parsedJson: parsed?['json'],
      jsonPrefix: parsed != null ? parsed['prefix'] as String? : null,
    );
  }

  /// The most opening brackets tried per line, so a long line full of
  /// brackets does not decode the rest of the line hundreds of times.
  static const int _maxJsonStarts = 20;

  /// Finds a JSON object or array that runs to the end of [text], and returns
  /// it with the text before it.
  ///
  /// Every `{` or `[` that could open it is tried from left to right, so a
  /// Python line such as `[INFO] ... {"a": 1}` finds the object after the
  /// `[INFO]` tag. Text that is not valid JSON is never shown as JSON.
  static Map<String, dynamic>? _tryParseJson(String text) {
    final trimmed = text.trimRight();
    if (trimmed.isEmpty) return null;
    final String open;
    switch (trimmed[trimmed.length - 1]) {
      case '}':
        open = '{';
      case ']':
        open = '[';
      default:
        return null;
    }

    var tries = 0;
    for (
      var start = trimmed.indexOf(open);
      start != -1 && tries < _maxJsonStarts;
      start = trimmed.indexOf(open, start + 1), tries++
    ) {
      try {
        final decoded = json.decode(trimmed.substring(start));
        if (decoded is Map || decoded is List) {
          return {'prefix': text.substring(0, start), 'json': decoded};
        }
      } on FormatException {
        // Not JSON from here; try the next bracket
      }
    }
    return null;
  }
}

class CloudWatchService {
  static String get baseUrl => '${BackendService.baseUrl}/api';

  // Stream Lambda logs using Server-Sent Events with proper SSE parsing
  // Yields either LogEntry or Map with sessionId
  static Stream<dynamic> streamLambdaLogs(String functionName) async* {
    final url =
        '$baseUrl/cloudwatch/lambda/${Uri.encodeComponent(functionName)}/logs';

    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await BackendService.client.send(request);

      if (response.statusCode != 200) {
        final errorResponse = await http.Response.fromStream(response);
        throw Exception(
          ApiService.errorMessage(
            errorResponse,
            'Failed to connect to log stream',
          ),
        );
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
