import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AwsConfigProvider extends ChangeNotifier {
  String? _currentRegion;
  List<String> _availableRegions = [];
  bool _isLoading = false;

  String? get currentRegion => _currentRegion;
  List<String> get availableRegions => _availableRegions;
  bool get isLoading => _isLoading;

  /// Initialize AWS config from backend
  Future<void> initialize() async {
    _isLoading = true;
    // Schedule notification for after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });

    try {
      // Load regions and config in parallel
      final results = await Future.wait([
        ApiService.listAWSRegions(),
        ApiService.getAWSConfig(),
      ]);
      
      _availableRegions = results[0] as List<String>;
      final config = results[1] as Map<String, dynamic>;
      final region = config['region'] as String?;
      
      if (region != null) {
        _currentRegion = region;
        // Save to local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('aws_current_region', region);
      }
    } catch (e) {
      // Fallback to saved region if API fails
      final prefs = await SharedPreferences.getInstance();
      _currentRegion = prefs.getString('aws_current_region');
    } finally {
      _isLoading = false;
      // Schedule notification for after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  /// Update current region
  Future<void> setRegion(String region) async {
    if (_currentRegion == region) return;
    
    _currentRegion = region;
    notifyListeners();

    // Save to local storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('aws_current_region', region);
  }

  /// Reload region from backend (useful after login)
  Future<void> reload() async {
    await initialize();
  }
}
