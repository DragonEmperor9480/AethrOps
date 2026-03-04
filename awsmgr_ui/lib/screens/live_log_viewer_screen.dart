import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';
import '../services/cloudwatch_service.dart';
import '../services/api_service.dart';
import '../utils/toast_utils.dart';

class LiveLogViewerScreen extends StatefulWidget {
  final String functionName;

  const LiveLogViewerScreen({super.key, required this.functionName});

  @override
  State<LiveLogViewerScreen> createState() => _LiveLogViewerScreenState();
}

class _LiveLogViewerScreenState extends State<LiveLogViewerScreen>
    with TickerProviderStateMixin {
  final List<LogEntry> _logs = [];
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<dynamic>? _logSubscription; // Changed to dynamic
  bool _isPaused = false;
  bool _autoScroll = true;
  bool _isSearchMode = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final List<int> _searchMatches = [];
  int _currentMatchIndex = -1;
  int _reconnectAttempts = 0;
  bool _isReconnecting = false;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late AnimationController _glitchController;
  late Animation<double> _pulseAnimation;
  DateTime _lastLogTime = DateTime.now();
  int _logsPerSecond = 0;
  Timer? _statsTimer;
  final List<int> _recentLogCounts = [];
  String? _sessionId; // Store session ID for download

  @override
  void initState() {
    super.initState();
    
    // Pulse animation for live indicator
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // Shimmer animation for loading state
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
    
    // Glitch effect for reconnecting state
    _glitchController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    // Stats timer for logs/sec calculation
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _logsPerSecond = _recentLogCounts.isEmpty
              ? 0
              : _recentLogCounts.reduce((a, b) => a + b) ~/
                  _recentLogCounts.length;
          _recentLogCounts.clear();
        });
      }
    });
    
    _startStreaming();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _logSubscription?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    _glitchController.dispose();
    _statsTimer?.cancel();
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
    setState(() {
      _isReconnecting = _reconnectAttempts > 0;
    });

    _logSubscription = CloudWatchService.streamLambdaLogs(widget.functionName)
        .listen(
          (event) {
            // Handle session ID
            if (event is Map && event['type'] == 'session') {
              setState(() {
                _sessionId = event['sessionId'];
              });
              debugPrint('Session ID captured: $_sessionId');
              return;
            }
            
            // Handle log entries
            if (event is LogEntry && !_isPaused) {
              setState(() {
                _logs.add(event);
                _lastLogTime = DateTime.now();
                _recentLogCounts.add(1);
                if (_recentLogCounts.length > 5) {
                  _recentLogCounts.removeAt(0);
                }
                _updateSearchMatches();
                // Reset reconnect attempts on successful data
                if (_reconnectAttempts > 0) {
                  _reconnectAttempts = 0;
                  _isReconnecting = false;
                }
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
              debugPrint('Stream error: $error');
              // Only show toast on first error, not on reconnect attempts
              if (_reconnectAttempts == 0) {
                ToastUtils.show(
                  context,
                  'Connection failed. Retrying...',
                  isError: true,
                );
              }
              _attemptReconnect();
            }
          },
          onDone: () {
            // Connection closed normally, attempt reconnect
            if (mounted) {
              debugPrint('Stream closed, reconnecting...');
              _attemptReconnect();
            }
          },
        );
  }

  // Helper to check if we can write to a directory
  Future<bool> _canWriteToDirectory(String path) async {
    try {
      final testFile = File('$path/.test_write');
      await testFile.writeAsString('test');
      await testFile.delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  void _downloadLogs() async {
    if (_sessionId == null) {
      ToastUtils.show(
        context, 
        'Session not ready. Please wait for logs to start streaming.', 
        isError: true,
      );
      return;
    }

    if (_logs.isEmpty) {
      ToastUtils.show(
        context,
        'No logs to download yet. Wait for logs to arrive.',
        isError: true,
      );
      return;
    }

    try {
      ToastUtils.show(context, 'Downloading logs...', isError: false);
      
      // Call backend API to download logs
      final logContent = await ApiService.downloadLogs(_sessionId!);
      
      // Get platform-specific Downloads directory
      String downloadsPath;
      
      if (Platform.isAndroid) {
        // Android: Try public Downloads first, fallback to app-specific storage
        try {
          downloadsPath = '/storage/emulated/0/Download';
          final testDir = Directory(downloadsPath);
          
          // Test if we can actually write to this directory
          if (!await testDir.exists() || !(await _canWriteToDirectory(downloadsPath))) {
            // Fallback to app-specific directory (no permission needed)
            downloadsPath = '/storage/emulated/0/Android/data/com.amrut.aethrops/files/Downloads';
            final appDir = Directory(downloadsPath);
            if (!await appDir.exists()) {
              // Last resort: internal storage
              downloadsPath = '/data/data/com.amrut.aethrops/files/Downloads';
            }
          }
        } catch (e) {
          // If all else fails, use app's internal storage
          downloadsPath = '/data/data/com.amrut.aethrops/files/Downloads';
        }
      } else if (Platform.isLinux) {
        // Linux: ~/Downloads
        final home = Platform.environment['HOME'] ?? Platform.environment['USER'];
        downloadsPath = '$home/Downloads';
      } else if (Platform.isWindows) {
        // Windows: C:\Users\{username}\Downloads
        final userProfile = Platform.environment['USERPROFILE'];
        downloadsPath = '$userProfile\\Downloads';
      } else if (Platform.isMacOS) {
        // macOS: ~/Downloads
        final home = Platform.environment['HOME'];
        downloadsPath = '$home/Downloads';
      } else {
        // Fallback: current directory
        downloadsPath = Directory.current.path;
      }
      
      // Generate filename
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final filename = '${widget.functionName}_$timestamp.log';
      final filePath = '$downloadsPath${Platform.pathSeparator}$filename';
      
      // Ensure Downloads directory exists
      final downloadsDir = Directory(downloadsPath);
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      
      // Write file to Downloads folder
      final file = File(filePath);
      await file.writeAsString(logContent);
      
      // Show user-friendly message
      final displayPath = Platform.isAndroid 
          ? 'Downloads/$filename' 
          : filePath;
      
      ToastUtils.show(
        context,
        'Downloaded: $displayPath',
        isError: false,
      );
      
      debugPrint('Saved ${logContent.length} bytes to $filePath');
    } catch (e) {
      ToastUtils.show(context, 'Download failed: $e', isError: true);
      debugPrint('Download error: $e');
    }
  }

  void _attemptReconnect() {
    if (!mounted) return;

    _reconnectAttempts++;
    
    // Trigger glitch effect
    _glitchController.forward(from: 0);
    
    // Exponential backoff: 1s, 2s, 4s, 8s, max 30s
    final delay = Duration(
      seconds: (1 << (_reconnectAttempts - 1)).clamp(1, 30),
    );

    setState(() {
      _isReconnecting = true;
    });

    Future.delayed(delay, () {
      if (mounted) {
        _startStreaming();
      }
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117), // GitHub dark theme
      appBar: AppBar(
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF30363D)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.functions,
                size: 16,
                color: Colors.greenAccent.shade400,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  widget.functionName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xFF161B22),
        foregroundColor: const Color(0xFFC9D1D9),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _sessionId != null ? _downloadLogs : null,
            tooltip: _sessionId != null 
                ? 'Download ${_logs.length} logs' 
                : 'Waiting for session...',
            color: _sessionId != null ? Colors.greenAccent : const Color(0xFF8B949E),
          ),
          IconButton(
            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
            onPressed: _togglePause,
            tooltip: _isPaused ? 'Resume' : 'Pause',
            color: _isPaused ? Colors.orange : const Color(0xFFC9D1D9),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _toggleSearchMode,
            tooltip: 'Search',
            color: _isSearchMode ? Colors.blueAccent : const Color(0xFFC9D1D9),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _resetLogs,
            tooltip: 'Clear',
            color: const Color(0xFFC9D1D9),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isSearchMode) _buildSearchBar(),
          _buildStatusBar(),
          Expanded(
            child: _logs.isEmpty ? _buildEmptyState() : _buildLogList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        border: Border(
          bottom: BorderSide(
            color: Colors.blueAccent.withOpacity(0.3),
            width: 2,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search,
            size: 18,
            color: Colors.blueAccent.shade400,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: const TextStyle(
                color: Color(0xFFC9D1D9),
                fontFamily: 'monospace',
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: 'Search logs... (regex supported)',
                hintStyle: TextStyle(
                  color: const Color(0xFF8B949E).withOpacity(0.5),
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _updateSearchMatches();
                });
              },
            ),
          ),
          if (_searchMatches.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: Colors.yellowAccent.withOpacity(0.3),
                ),
              ),
              child: Text(
                '${_currentMatchIndex + 1}/${_searchMatches.length}',
                style: TextStyle(
                  color: Colors.yellowAccent.shade400,
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up, size: 20),
            onPressed: _prevMatch,
            tooltip: 'Previous match (Shift+Enter)',
            color: const Color(0xFFC9D1D9),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 20),
            onPressed: _nextMatch,
            tooltip: 'Next match (Enter)',
            color: const Color(0xFFC9D1D9),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: _toggleSearchMode,
            tooltip: 'Close search (Esc)',
            color: const Color(0xFF8B949E),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    final timeSinceLastLog = DateTime.now().difference(_lastLogTime);
    final isActive = timeSinceLastLog.inSeconds < 5 && !_isPaused;
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        border: Border(
          bottom: BorderSide(
            color: _isPaused
                ? Colors.red.withOpacity(0.3)
                : _isReconnecting
                    ? Colors.orange.withOpacity(0.3)
                    : Colors.greenAccent.withOpacity(0.3),
            width: 2,
          ),
        ),
      ),
      child: Column(
        children: [
          // Main status bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // Status indicator
                _buildStatusIndicator(),
                const SizedBox(width: 8),
                // Always-visible fetching indicator
                if (!_isPaused) _buildFetchingIndicator(),
                const SizedBox(width: 8),
                // Metrics - wrapped in Expanded to prevent overflow
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: _buildMetrics(),
                  ),
                ),
              ],
            ),
          ),
          // Progress bar for reconnecting
          if (_isReconnecting) _buildReconnectingProgress(),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: (_isPaused
                      ? Colors.red
                      : _isReconnecting
                          ? Colors.orange
                          : Colors.greenAccent)
                  .withOpacity(0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: (_isPaused
                          ? Colors.red
                          : _isReconnecting
                              ? Colors.orange
                              : Colors.greenAccent.shade400)
                      .withOpacity(_isPaused ? 1.0 : _pulseAnimation.value),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _isPaused
                    ? 'PAUSED'
                    : _isReconnecting
                        ? 'RECONNECTING'
                        : 'LIVE',
                style: TextStyle(
                  color: _isPaused
                      ? Colors.red
                      : _isReconnecting
                          ? Colors.orange
                          : Colors.greenAccent.shade400,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  fontFamily: 'monospace',
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFetchingIndicator() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: Colors.blueAccent.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Rotating sync icon
              Transform.rotate(
                angle: _shimmerController.value * 2 * math.pi,
                child: Icon(
                  Icons.sync,
                  size: 14,
                  color: Colors.blueAccent.shade400,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Polling CloudWatch',
                style: TextStyle(
                  color: Colors.blueAccent.shade400,
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              // Animated dots
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (index) {
                  final delay = index * 0.3;
                  final value = (_shimmerController.value + delay) % 1.0;
                  final opacity = (math.sin(value * math.pi * 2) + 1) / 2;
                  
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.shade400.withOpacity(0.3 + opacity * 0.7),
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetrics() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Auto-scroll indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: _autoScroll 
                  ? Colors.blueAccent.withOpacity(0.3)
                  : const Color(0xFF30363D),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _autoScroll ? Icons.vertical_align_bottom : Icons.pan_tool,
                size: 12,
                color: _autoScroll ? Colors.blueAccent.shade400 : const Color(0xFF8B949E),
              ),
              const SizedBox(width: 4),
              Text(
                _autoScroll ? 'AUTO' : 'MANUAL',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: _autoScroll ? Colors.blueAccent.shade400 : const Color(0xFF8B949E),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Log count
        _buildMetricChip(
          icon: Icons.article_outlined,
          label: 'LOGS',
          value: _logs.length.toString(),
          color: Colors.cyanAccent,
        ),
        // Logs per second (only show if > 0)
        if (_logsPerSecond > 0) ...[
          const SizedBox(width: 8),
          _buildMetricChip(
            icon: Icons.speed,
            label: 'RATE',
            value: '$_logsPerSecond/s',
            color: Colors.greenAccent,
          ),
        ],
        // Search matches
        if (_searchMatches.isNotEmpty) ...[
          const SizedBox(width: 8),
          _buildMetricChip(
            icon: Icons.search,
            label: 'MATCHES',
            value: _searchMatches.length.toString(),
            color: Colors.yellowAccent,
          ),
        ],
      ],
    );
  }

  Widget _buildMetricChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontFamily: 'monospace',
              color: color.withOpacity(0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReconnectingProgress() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          height: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                (_shimmerController.value - 0.3).clamp(0.0, 1.0),
                _shimmerController.value,
                (_shimmerController.value + 0.3).clamp(0.0, 1.0),
              ],
              colors: [
                Colors.orange.withOpacity(0.0),
                Colors.orange,
                Colors.orange.withOpacity(0.0),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Loading animation
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.greenAccent.shade400,
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Main message
          Text(
            'Fetching logs...',
            style: TextStyle(
              color: const Color(0xFFC9D1D9),
              fontSize: 16,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          // Hint
          Text(
            'Invoke the Lambda function to see logs here',
            style: TextStyle(
              color: const Color(0xFF8B949E),
              fontSize: 13,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingDots() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            final delay = index * 0.15;
            final value = (_shimmerController.value + delay) % 1.0;
            final scale = 0.5 + ((math.sin(value * math.pi * 2) + 1) / 2) * 0.5;
            final opacity = 0.3 + ((math.sin(value * math.pi * 2) + 1) / 2) * 0.4;
            
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withOpacity(opacity),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildLogList() {
    return Container(
      color: const Color(0xFF0D1117),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
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

          // Animate new logs (last 5 entries)
          final isNewLog = index >= _logs.length - 5 && !_isPaused;
          
          return TweenAnimationBuilder<double>(
            key: ValueKey('log_$index'),
            duration: isNewLog
                ? const Duration(milliseconds: 400)
                : Duration.zero,
            tween: Tween(begin: isNewLog ? 0.0 : 1.0, end: 1.0),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, (1 - value) * 20),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isCurrentMatch
                          ? Colors.yellow.shade700.withOpacity(0.3)
                          : isMatch
                              ? Colors.yellow.shade900.withOpacity(0.2)
                              : index % 2 == 0
                                  ? const Color(0xFF161B22).withOpacity(0.5)
                                  : Colors.transparent,
                      border: Border(
                        left: BorderSide(
                          color: isNewLog
                              ? Colors.greenAccent.shade400.withOpacity(value)
                              : isCurrentMatch
                                  ? Colors.yellow.shade700
                                  : Colors.transparent,
                          width: isNewLog ? 3 : 2,
                        ),
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Line number
                        Container(
                          width: 50,
                          padding: const EdgeInsets.only(right: 12),
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: const Color(0xFF8B949E).withOpacity(0.5),
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        // Log content
                        Expanded(
                          child: _buildLogContent(log, isMatch, isCurrentMatch),
                        ),
                        // Copy button
                        const SizedBox(width: 8),
                        _buildCopyButton(log.message, index),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCopyButton(String content, int index) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          Clipboard.setData(ClipboardData(text: content));
          ToastUtils.show(
            context,
            'Copied to clipboard',
            isError: false,
          );
        },
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: const Color(0xFF30363D),
            ),
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

  Widget _buildLogContent(LogEntry log, bool isMatch, bool isCurrentMatch) {
    // Try to detect and parse JSON
    final jsonData = _tryParseJson(log.message);

    if (jsonData != null) {
      // It's JSON, render with syntax highlighting
      return _buildJsonLog(jsonData, isMatch, isCurrentMatch);
    } else if (_searchQuery.isNotEmpty && isMatch) {
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
    bool isMatch,
    bool isCurrentMatch,
  ) {
    final prefix = data['prefix'] as String;
    final jsonObj = data['json'];
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
    if (_searchQuery.isNotEmpty && isMatch) {
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
                  color: Colors.blueAccent.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.code,
                    size: 12,
                    color: Colors.blueAccent.shade400,
                  ),
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

  Widget _buildHighlightedText(String text, bool isCurrentMatch) {
    final textColor = isCurrentMatch ? Colors.black : Colors.white;
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
