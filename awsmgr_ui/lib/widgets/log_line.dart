import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/cloudwatch_service.dart';
import '../utils/toast_utils.dart';

/// The text of one line in the live log viewer: plain text, or the prefix
/// and syntax-coloured JSON, with search matches highlighted.
class LogLineContent extends StatelessWidget {
  final LogEntry log;
  final String searchQuery;
  final bool isMatch;
  final bool isCurrentMatch;

  const LogLineContent({
    super.key,
    required this.log,
    required this.searchQuery,
    required this.isMatch,
    required this.isCurrentMatch,
  });

  @override
  Widget build(BuildContext context) => _buildLogContent(context);

  Widget _buildLogContent(BuildContext context) {
    if (log.parsedJson != null) {
      // It's JSON (pre-parsed at ingestion time), render with syntax highlighting
      return _buildJsonLog(
        context,
        log.jsonPrefix ?? '',
        log.parsedJson!,
        isMatch,
        isCurrentMatch,
      );
    } else if (searchQuery.isNotEmpty && isMatch) {
      // Regular text with search highlighting
      return _buildHighlightedText(log.message, isCurrentMatch);
    } else {
      // Regular text
      return SelectableText(
        log.message,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'monospace',
          fontSize: 13,
        ),
      );
    }
  }

  Widget _buildJsonLog(
    BuildContext context,
    String prefix,
    Object jsonObj,
    bool isMatch,
    bool isCurrentMatch,
  ) {
    final prettyJson = const JsonEncoder.withIndent('  ').convert(jsonObj);

    final spans = <TextSpan>[];

    // Add prefix (timestamp, log level, etc.) in white
    if (prefix.isNotEmpty) {
      spans.add(
        TextSpan(
          text: prefix,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'monospace',
            fontSize: 13,
          ),
        ),
      );
    }

    // Add newline before JSON for better formatting
    if (prefix.isNotEmpty) {
      spans.add(const TextSpan(text: '\n'));
    }

    // Add JSON with syntax highlighting
    if (searchQuery.isNotEmpty && isMatch) {
      spans.addAll(_buildHighlightedJsonSpans(prettyJson, isCurrentMatch));
    } else {
      spans.addAll(_buildJsonSpans(prettyJson, 0));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText.rich(TextSpan(children: spans)),
        const SizedBox(height: 8),
        // Copy JSON button
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: prettyJson));
              ToastUtils.show(
                context,
                'JSON copied to clipboard',
                isError: false,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: Colors.blueAccent.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.code, size: 12, color: Colors.blueAccent.shade400),
                  const SizedBox(width: 4),
                  Text(
                    'Copy JSON',
                    style: TextStyle(
                      color: Colors.blueAccent.shade400,
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<TextSpan> _buildJsonSpans(String json, int indent) {
    final spans = <TextSpan>[];
    final lines = json.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      spans.addAll(_parseJsonLine(line));
      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return spans;
  }

  List<TextSpan> _parseJsonLine(String line) {
    final spans = <TextSpan>[];
    final regex = RegExp(
      r'("(?:[^"\\]|\\.)*")|' // Strings
      r'(\btrue\b|\bfalse\b|\bnull\b)|' // Booleans and null
      r'(-?\d+\.?\d*)|' // Numbers
      r'([{}[\],:])|' // Structural characters
      r'(\s+)', // Whitespace
    );

    int lastIndex = 0;
    for (final match in regex.allMatches(line)) {
      // Add any text before the match
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: line.substring(lastIndex, match.start),
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'monospace',
              fontSize: 13,
            ),
          ),
        );
      }

      final matchText = match.group(0)!;
      Color textColor;
      FontWeight? fontWeight;

      if (match.group(1) != null) {
        // String (including keys)
        if (matchText.endsWith('":')) {
          // It's a key - use cyan/aqua color to distinguish from values
          textColor = Colors.cyan.shade300;
          fontWeight = FontWeight.bold;
        } else {
          // It's a string value - use green
          textColor = Colors.green.shade300;
        }
      } else if (match.group(2) != null) {
        // Boolean or null - use purple/magenta
        textColor = Colors.purple.shade300;
        fontWeight = FontWeight.bold;
      } else if (match.group(3) != null) {
        // Number
        textColor = Colors.orange.shade300;
      } else if (match.group(4) != null) {
        // Structural characters
        textColor = Colors.grey.shade400;
      } else {
        // Whitespace
        textColor = Colors.white;
      }

      spans.add(
        TextSpan(
          text: matchText,
          style: TextStyle(
            color: textColor,
            fontFamily: 'monospace',
            fontSize: 13,
            fontWeight: fontWeight,
          ),
        ),
      );

      lastIndex = match.end;
    }

    // Add any remaining text
    if (lastIndex < line.length) {
      spans.add(
        TextSpan(
          text: line.substring(lastIndex),
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'monospace',
            fontSize: 13,
          ),
        ),
      );
    }

    return spans;
  }

  List<TextSpan> _buildHighlightedJsonSpans(String json, bool isCurrentMatch) {
    final query = searchQuery.toLowerCase();
    final jsonLower = json.toLowerCase();

    final spans = <TextSpan>[];
    int start = 0;

    while (start < json.length) {
      final index = jsonLower.indexOf(query, start);
      if (index == -1) {
        // No more matches, add remaining JSON with syntax highlighting
        final remaining = json.substring(start);
        spans.addAll(_parseJsonLine(remaining));
        break;
      }

      // Add JSON before match with syntax highlighting
      if (index > start) {
        final before = json.substring(start, index);
        spans.addAll(_parseJsonLine(before));
      }

      // Add highlighted match
      spans.add(
        TextSpan(
          text: json.substring(index, index + query.length),
          style: TextStyle(
            color: Colors.black,
            backgroundColor: isCurrentMatch
                ? Colors.orange.shade400
                : Colors.yellow.shade600,
            fontFamily: 'monospace',
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      start = index + query.length;
    }

    return spans;
  }

  Widget _buildHighlightedText(String text, bool isCurrentMatch) {
    final textColor = isCurrentMatch ? Colors.black : Colors.white;
    final query = searchQuery.toLowerCase();
    final textLower = text.toLowerCase();

    final spans = <TextSpan>[];
    int start = 0;

    while (start < text.length) {
      final index = textLower.indexOf(query, start);
      if (index == -1) {
        // No more matches, add remaining text
        spans.add(
          TextSpan(
            text: text.substring(start),
            style: TextStyle(
              color: textColor,
              fontFamily: 'monospace',
              fontSize: 13,
            ),
          ),
        );
        break;
      }

      // Add text before match
      if (index > start) {
        spans.add(
          TextSpan(
            text: text.substring(start, index),
            style: TextStyle(
              color: textColor,
              fontFamily: 'monospace',
              fontSize: 13,
            ),
          ),
        );
      }

      // Add highlighted match
      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: TextStyle(
            color: isCurrentMatch ? Colors.black : Colors.black,
            backgroundColor: isCurrentMatch
                ? Colors.orange.shade400
                : Colors.yellow.shade600,
            fontFamily: 'monospace',
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      start = index + query.length;
    }

    return SelectableText.rich(TextSpan(children: spans));
  }
}

/// The copy button at the end of a log line.
class LogCopyButton extends StatelessWidget {
  final String content;

  const LogCopyButton({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          Clipboard.setData(ClipboardData(text: content));
          ToastUtils.show(context, 'Copied to clipboard', isError: false);
        },
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: const Color(0xFF30363D)),
          ),
          child: Icon(
            Icons.content_copy,
            size: 14,
            color: const Color(0xFF8B949E),
          ),
        ),
      ),
    );
  }
}
