import 'package:flutter/foundation.dart';
import '../services/local_database_service.dart';

class VRSProvider extends ChangeNotifier {
  final LocalDatabaseService _db = LocalDatabaseService();
  
  // Current system status
  String _systemStatus = 'Loading...';
  bool _isAutoMode = true;
  String _currentModel = '';
  String _currentModelName = '';
  int _totalCount = 0;
  int _okCount = 0;
  int _ngCount = 0;

  // Camera and alignment settings
  double _magnification = 140.0;
  double _lightLevel = 50.0;
  final List<Map<String, dynamic>> _alignmentPoints = [];
  int _currentAlignmentStep = 1;

  // Initialize data from database
  bool _isInitialized = false;

  // Getters
  String get systemStatus => _systemStatus;
  bool get isAutoMode => _isAutoMode;
  String get currentModel => _currentModel;
  String get currentModelName => _currentModelName;
  int get totalCount => _totalCount;
  int get okCount => _okCount;
  int get ngCount => _ngCount;
  double get ngRate => _totalCount > 0 ? (_ngCount / _totalCount) * 100 : 0.0;
  double get magnification => _magnification;
  double get lightLevel => _lightLevel;
  List<Map<String, dynamic>> get alignmentPoints =>
      List.unmodifiable(_alignmentPoints);
  int get currentAlignmentStep => _currentAlignmentStep;
  bool get isInitialized => _isInitialized;

  // Initialize provider with database data
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _loadSystemConfig();
      await _loadCurrentModel();
      await _loadStatistics();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing VRSProvider: $e');
    }
  }

  Future<void> _loadSystemConfig() async {
    try {
      final systemStatus = await _db.getConfigValue('system_status');
      final systemMode = await _db.getConfigValue('system_mode');
      final magnification = await _db.getConfigValue('magnification');
      final lightLevel = await _db.getConfigValue('light_level');

      _systemStatus = systemStatus ?? 'OK';
      _isAutoMode = (systemMode ?? 'auto') == 'auto';
      _magnification = double.tryParse(magnification ?? '140') ?? 140.0;
      _lightLevel = double.tryParse(lightLevel ?? '50') ?? 50.0;
    } catch (e) {
      debugPrint('Error loading system config: $e');
    }
  }

  Future<void> _loadCurrentModel() async {
    try {
      final currentModelId = await _db.getConfigValue('current_model');
      if (currentModelId != null) {
        final modelId = int.tryParse(currentModelId);
        if (modelId != null) {
          final model = await _db.getModelById(modelId);
          if (model != null) {
            _currentModel = model['id'].toString();
            _currentModelName = 'Model ${model['id']}';
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading current model: $e');
    }
  }

  Future<void> _loadStatistics() async {
    try {
      // Calculate total statistics from all boards
      final allBoards = await _db.getAllBoards();
      _totalCount = allBoards.length;
      _okCount = allBoards.where((board) => (board['defect_quantity'] as int) == 0).length;
      _ngCount = allBoards.where((board) => (board['defect_quantity'] as int) > 0).length;
    } catch (e) {
      debugPrint('Error loading statistics: $e');
    }
  }

  Future<void> setSystemStatus(String status) async {
    _systemStatus = status;
    await _db.updateConfig('system_status', status);
    notifyListeners();
  }

  Future<void> toggleMode() async {
    _isAutoMode = !_isAutoMode;
    await _db.updateConfig('system_mode', _isAutoMode ? 'auto' : 'manual');
    notifyListeners();
  }

  Future<void> setCurrentModel(String modelId) async {
    try {
      final id = int.tryParse(modelId);
      if (id != null) {
        final model = await _db.getModelById(id);
        if (model != null) {
          _currentModel = model['id'].toString();
          _currentModelName = 'Model ${model['id']}';
          await _db.updateConfig('current_model', modelId);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error setting current model: $e');
    }
  }

  Future<void> updateCounts({int? total, int? ok, int? ng}) async {
    if (total != null) _totalCount = total;
    if (ok != null) _okCount = ok;
    if (ng != null) _ngCount = ng;
    notifyListeners();
  }

  Future<void> incrementCount(bool isOK) async {
    _totalCount++;
    if (isOK) {
      _okCount++;
    } else {
      _ngCount++;
    }
    notifyListeners();
  }

  Future<void> setMagnification(double value) async {
    _magnification = value;
    await _db.updateConfig('magnification', value.toString());
    notifyListeners();
  }

  Future<void> setLightLevel(double value) async {
    _lightLevel = value;
    await _db.updateConfig('light_level', value.toString());
    notifyListeners();
  }

  void addAlignmentPoint(double x, double y, String label) {
    _alignmentPoints.add({
      'x': x,
      'y': y,
      'label': label,
      'step': _currentAlignmentStep,
    });
    notifyListeners();
  }

  void clearAlignmentPoints() {
    _alignmentPoints.clear();
    _currentAlignmentStep = 1;
    notifyListeners();
  }

  void setAlignmentStep(int step) {
    _currentAlignmentStep = step;
    notifyListeners();
  }

  void nextAlignmentStep() {
    if (_currentAlignmentStep < 4) {
      _currentAlignmentStep++;
      notifyListeners();
    }
  }

  Future<void> resetSystem() async {
    _totalCount = 0;
    _okCount = 0;
    _ngCount = 0;
    _systemStatus = 'OK';
    await _db.updateConfig('system_status', 'OK');
    clearAlignmentPoints();
    notifyListeners();
  }

  // Get available models from database
  Future<List<Map<String, dynamic>>> getAvailableModels() async {
    return await _db.getAllModels();
  }

  // Refresh data from database
  Future<void> refreshData() async {
    await _loadSystemConfig();
    await _loadCurrentModel();
    await _loadStatistics();
    notifyListeners();
  }
}
