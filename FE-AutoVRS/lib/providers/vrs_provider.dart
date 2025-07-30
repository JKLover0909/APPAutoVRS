import 'package:flutter/foundation.dart';

class VRSProvider extends ChangeNotifier {
  // Current system status
  String _systemStatus = 'OK';
  bool _isAutoMode = true;
  String _currentModel = '';
  int _totalCount = 0;
  int _okCount = 0;
  int _ngCount = 0;

  // Camera and alignment settings
  double _magnification = 1.0;
  double _lightLevel = 50.0;
  final List<Map<String, dynamic>> _alignmentPoints = [];
  int _currentAlignmentStep = 1;

  // Getters
  String get systemStatus => _systemStatus;
  bool get isAutoMode => _isAutoMode;
  String get currentModel => _currentModel;
  int get totalCount => _totalCount;
  int get okCount => _okCount;
  int get ngCount => _ngCount;
  double get ngRate => _totalCount > 0 ? (_ngCount / _totalCount) * 100 : 0.0;
  double get magnification => _magnification;
  double get lightLevel => _lightLevel;
  List<Map<String, dynamic>> get alignmentPoints =>
      List.unmodifiable(_alignmentPoints);
  int get currentAlignmentStep => _currentAlignmentStep;

  void setSystemStatus(String status) {
    _systemStatus = status;
    notifyListeners();
  }

  void toggleMode() {
    _isAutoMode = !_isAutoMode;
    notifyListeners();
  }

  void setCurrentModel(String model) {
    _currentModel = model;
    notifyListeners();
  }

  void updateCounts({int? total, int? ok, int? ng}) {
    if (total != null) _totalCount = total;
    if (ok != null) _okCount = ok;
    if (ng != null) _ngCount = ng;
    notifyListeners();
  }

  void incrementCount(bool isOK) {
    _totalCount++;
    if (isOK) {
      _okCount++;
    } else {
      _ngCount++;
    }
    notifyListeners();
  }

  void setMagnification(double value) {
    _magnification = value;
    notifyListeners();
  }

  void setLightLevel(double value) {
    _lightLevel = value;
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

  void resetSystem() {
    _totalCount = 0;
    _okCount = 0;
    _ngCount = 0;
    _systemStatus = 'OK';
    clearAlignmentPoints();
    notifyListeners();
  }
}
