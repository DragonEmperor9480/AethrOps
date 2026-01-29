import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import '../services/cloudwatch_service.dart';
import '../utils/toast_utils.dart';

class LiveLogViewerScreen extends StatefulWidget {
  final String functionName;

  const LiveLogViewerScreen({super.key, required this.functionName});

  @override
  State<LiveLogViewerScreen> createState() => _LiveLogViewerScreenState();
}

class _LiveLogViewerScreenState extends State<LiveLogViewerScreen> {
  final List<LogEntry> _logs = [];
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<LogEntry>? _logSubscription;
  bool _isPaused = false;
  bool _autoScroll = true;
  bool _isSearchMode = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final List<int> _searchMatches = [];
  int _currentMatchIndex = -1;

  @override
  void initState() {
    super.initState();
    _startStreaming();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _logSubscription?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;

      // Enable auto-scroll if user scrolls to bottom
      if (currentScroll >= maxScroll - 50) {
        if (!_autoScroll) {
          setState(() {
            _autoScroll = true;
          });
        }
      } else {
        // Disable auto-scroll if user scrolls up
        if (_autoScroll) {
          setState(() {
            _autoScroll = false;
          });
        }
      }
    }
  }

  void _startStreaming() {
    _logSubscription = CloudWatchService.streamLambdaLogs(widget.functionName)
        .listen(
          (logEntry) {
            if (!_isPaused) {
              setState(() {
                _logs.add(logEntry);
                _updateSearchMatches();
              });

              if (_autoScroll && _scrollController.hasClients) {
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    );
                  }
                });
              }
            }
          },
          onError: (error) {
            if (mounted) {
              ToastUtils.show(context, 'Stream error: $error', isError: true);
            }
          },
        );
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });
  }

  void _resetLogs() {
    setState(() {
      _logs.clear();
      _searchMatches.clear();
      _currentMatchIndex = -1;
    });
  }

  void _toggleSearchMode() {
    setState(() {
      _isSearchMode = !_isSearchMode;
      if (_isSearchMode) {
        _searchFocusNode.requestFocus();
      } else {
        _searchQuery = '';
        _searchController.clear();
        _searchMatches.clear();
        _currentMatchIndex = -1;
      }
    });
  }

  void _updateSearchMatches() {
    if (_searchQuery.isEmpty) {
      setState(() {
        _searchMatches.clear();
        _currentMatchIndex = -1;
      });
      return;
    }

    final oldMatchCount = _searchMatches.length;
    _searchMatches.clear();
    final query = _searchQuery.toLowerCase();

    for (int i = 0; i < _logs.length; i++) {
      if (_logs[i].message.toLowerCase().contains(query)) {
        _searchMatches.add(i);
      }
    }

    setState(() {
      if (_searchMatches.isNotEmpty) {
        // If this is a new search or we had no matches before, go to first match
        if (_currentMatchIndex == -1 || oldMatchCount == 0) {
          _currentMatchIndex = 0;
          _scrollToMatch();
        }
        // If current index is out of bounds, adjust it
        else if (_currentMatchIndex >= _searchMatches.length) {
          _currentMatchIndex = _searchMatches.length - 1;
          _scrollToMatch();
        }
      } else {
        _currentMatchIndex = -1;
      }
    });
  }

  void _nextMatch() {
    if (_searchMatches.isEmpty) return;

    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _searchMatches.length;
      _scrollToMatch();
    });
  }

  void _prevMatch() {
    if (_searchMatches.isEmpty) return;

    setState(() {
      _currentMatchIndex--;
      if (_currentMatchIndex < 0) {
        _currentMatchIndex = _searchMatches.length - 1;
      }
      _scrollToMatch();
    });
  }

  void _scrollToMatch() {
    if (_currentMatchIndex < 0 || _currentMatchIndex >= _searchMatches.length) {
      return;
    }

    if (!_scrollController.hasClients) return;

    final matchLine = _searchMatches[_currentMatchIndex];

    // Disable auto-scroll when searching
    _autoScroll = false;

    // Calculate scroll position to center the match (like TUI does)
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final viewportHeight = _scrollController.position.viewportDimension;
    final estimatedLineHeight =
        40.0; // Conservative estimate for variable height logs

    // Center the match in viewport
    final targetPosition =
        (matchLine * estimatedLineHeight) - (viewportHeight / 2);

    // Clamp to valid range
    final maxScroll = _scrollController.position.maxScrollExtent;
    final minScroll = _scrollController.position.minScrollExtent;
    final clampedPosition = targetPosition.clamp(minScroll, maxScroll);

    // Scroll to position
    _scrollController.animateTo(
      clampedPosition,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Color _getColorFromString(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'red':
        return Colors.red;
      case 'yellow':
        return Colors.yellow.shade700;
      case 'green':
        return Colors.green;
      case 'cyan':
        return Colors.cyan;
      case 'blue':
        return Colors.blue;
      case 'magenta':
        return Colors.purple;
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Live Tail: ${widget.functionName}',
          style: const TextStyle(fontSize: 16),
        ),
        backgroundColor: Colors.grey.shade900,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
            onPressed: _togglePause,
            tooltip: _isPaused ? 'Resume' : 'Pause',
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _toggleSearchMode,
            tooltip: 'Search',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetLogs,
            tooltip: 'Reset',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isSearchMode) _buildSearchBar(),
          _buildStatusBar(),
          Expanded(child: _logs.isEmpty ? _buildEmptyState() : _buildLogList()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.teal.shade900,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search logs...',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                border: InputBorder.none,
                suffixText: _searchMatches.isNotEmpty
                    ? '${_currentMatchIndex + 1}/${_searchMatches.length}'
                    : null,
                suffixStyle: const TextStyle(color: Colors.white),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _updateSearchMatches();
                });
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_upward, color: Colors.white),
            onPressed: _prevMatch,
            tooltip: 'Previous match',
          ),
          IconButton(
            icon: const Icon(Icons.arrow_downward, color: Colors.white),
            onPressed: _nextMatch,
            tooltip: 'Next match',
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: _toggleSearchMode,
            tooltip: 'Close search',
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: _isPaused ? Colors.red.shade900 : Colors.green.shade900,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _isPaused ? Colors.red : Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _isPaused ? 'PAUSED' : 'LIVE',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '|',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          ),
          const SizedBox(width: 16),
          Text(
            _autoScroll ? 'AUTO' : 'MANUAL',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Text(
            'Logs: ${_logs.length}',
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.hourglass_empty,
            size: 64,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Waiting for logs...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Invoke the Lambda function to see logs',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      itemCount: _logs.length,
      itemBuilder: (context, index) {
        final log = _logs[index];
        final isMatch =
            _searchQuery.isNotEmpty &&
            log.message.toLowerCase().contains(_searchQuery.toLowerCase());
        final isCurrentMatch =
            isMatch &&
            _searchMatches.isNotEmpty &&
            _currentMatchIndex >= 0 &&
            _currentMatchIndex < _searchMatches.length &&
            _searchMatches[_currentMatchIndex] == index;

        return Container(
          key: ValueKey('log_$index'),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          color: isCurrentMatch
              ? Colors.yellow.shade700
              : isMatch
              ? Colors.yellow.shade900.withValues(alpha: 0.3)
              : Colors.transparent,
          child: _buildLogContent(log, isMatch, isCurrentMatch),
        );
      },
    );
  }

  Widget _buildLogContent(LogEntry log, bool isMatch, bool isCurrentMatch) {
    // Try to detect and parse JSON
    final jsonData = _tryParseJson(log.message);

    if (jsonData != null) {
      // It's JSON, render with syntax highlighting
      return _buildJsonLog(jsonData, log.color, isMatch, isCurrentMatch);
    } else if (_searchQuery.isNotEmpty && isMatch) {
      // Regular text with search highlighting
      return _buildHighlightedText(log.message, log.color, isCurrentMatch);
    } else {
      // Regular text
      return SelectableText(
        log.message,
        style: TextStyle(
          color: _getColorFromString(log.color),
          fontFamily: 'monospace',
          fontSize: 13,
        ),
      );
    }
  }

  Map<String, dynamic>? _tryParseJson(String text) {
    // Try to find JSON in the text - look for { or [ anywhere in the line
    final jsonStartIndex = text.indexOf('{');
    final arrayStartIndex = text.indexOf('[');

    int startIndex = -1;
    if (jsonStartIndex != -1 && arrayStartIndex != -1) {
      startIndex = jsonStartIndex < arrayStartIndex
          ? jsonStartIndex
          : arrayStartIndex;
    } else if (jsonStartIndex != -1) {
      startIndex = jsonStartIndex;
    } else if (arrayStartIndex != -1) {
      startIndex = arrayStartIndex;
    }

    if (startIndex == -1) {
      return null;
    }

    // Extract the JSON part
    final jsonPart = text.substring(startIndex).trim();

    try {
      final decoded = json.decode(jsonPart);
      return {'prefix': text.substring(0, startIndex), 'json': decoded};
    } catch (e) {
      // Not valid JSON, might be Go struct format like {Key:Value}
      // Try to convert Go struct format to JSON
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

  Map<String, dynamic>? _convertGoStructToJson(String goStruct) {
    // Convert Go struct format like "Key:Value Key2:Value2" to JSON
    try {
      final result = <String, dynamic>{};
      final pairs = goStruct.split(RegExp(r'\s+(?=[A-Z])'));

      for (final pair in pairs) {
        final colonIndex = pair.indexOf(':');
        if (colonIndex == -1) continue;

        final key = pair.substring(0, colonIndex).trim();
        final value = pair.substring(colonIndex + 1).trim();

        if (key.isEmpty) continue;

        // Try to parse value as number
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

  Widget _buildJsonLog(
    Map<String, dynamic> data,
    String color,
    bool isMatch,
    bool isCurrentMatch,
  ) {
    final prefix = data['prefix'] as String;
    final jsonObj = data['json'];
    final prettyJson = const JsonEncoder.withIndent('  ').convert(jsonObj);

    final spans = <TextSpan>[];

    // Add prefix (timestamp, log level, etc.) in original color
    if (prefix.isNotEmpty) {
      spans.add(
        TextSpan(
          text: prefix,
          style: TextStyle(
            color: _getColorFromString(color),
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
    if (_searchQuery.isNotEmpty && isMatch) {
      spans.addAll(_buildHighlightedJsonSpans(prettyJson, isCurrentMatch));
    } else {
      spans.addAll(_buildJsonSpans(prettyJson, 0));
    }

    return SelectableText.rich(TextSpan(children: spans));
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
    final query = _searchQuery.toLowerCase();
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

  Widget _buildHighlightedText(String text, String color, bool isCurrentMatch) {
    final textColor = isCurrentMatch
        ? Colors.black
        : _getColorFromString(color);
    final query = _searchQuery.toLowerCase();
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
