import 'package:flutter/material.dart';
import 'dart:async';
import '../services/cloudwatch_service.dart';
import '../theme/app_theme.dart';
import '../widgets/loading_animation.dart';
import 'live_log_viewer_screen.dart';

class CloudWatchScreen extends StatefulWidget {
  const CloudWatchScreen({super.key});

  @override
  State<CloudWatchScreen> createState() => _CloudWatchScreenState();
}

class _CloudWatchScreenState extends State<CloudWatchScreen> {
  List<String> _functions = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFunctions();
  }

  Future<void> _loadFunctions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final functions = await CloudWatchService.listLambdaFunctions();
      setState(() {
        _functions = functions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('CloudWatch'),
        backgroundColor: AppTheme.cloudwatchColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: LoadingAnimation())
          : _error != null
              ? _buildError(theme, isDark)
              : _buildFunctionList(theme, isDark),
    );
  }

  Widget _buildError(ThemeData theme, bool isDark) {
    final textColor = isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary;
    final secondaryColor = isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.errorRed,
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading Functions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: secondaryColor,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadFunctions,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.cloudwatchColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFunctionList(ThemeData theme, bool isDark) {
    final textColor = isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary;
    final secondaryColor = isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary;
    final cardColor = isDark ? AppTheme.cardBackgroundDark : AppTheme.cardBackground;
    final borderColor = isDark ? AppTheme.borderColorDark : AppTheme.borderColor;
    
    if (_functions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.functions,
              size: 64,
              color: secondaryColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No Lambda Functions Found',
              style: TextStyle(
                fontSize: 18,
                color: secondaryColor,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.cloudwatchColor.withValues(alpha: isDark ? 0.15 : 0.1),
            border: Border(
              bottom: BorderSide(
                color: AppTheme.cloudwatchColor.withValues(alpha: 0.2),
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                color: AppTheme.cloudwatchColor,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lambda Functions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  Text(
                    '${_functions.length} function${_functions.length != 1 ? 's' : ''} available',
                    style: TextStyle(
                      fontSize: 14,
                      color: secondaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _functions.length,
            itemBuilder: (context, index) {
              final function = _functions[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: isDark ? 0 : 2,
                color: cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: borderColor),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LiveLogViewerScreen(
                          functionName: function,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.cloudwatchColor.withValues(alpha: isDark ? 0.2 : 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.functions,
                            color: AppTheme.cloudwatchColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                function,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tap to view live logs',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: secondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: secondaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
