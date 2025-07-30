import 'package:flutter/foundation.dart';

class StatisticsProvider extends ChangeNotifier {
  // Defect type data
  final Map<String, int> _defectData = {
    'Hở mạch': 12,
    'Thiếu linh kiện': 19,
    'Nhiễu ảnh': 3,
    'Xước mạch': 8,
  };

  // Time-based statistics
  final List<Map<String, dynamic>> _hourlyData = [];
  String _selectedLot = '';
  DateTime _selectedDate = DateTime.now();

  // Getters
  Map<String, int> get defectData => Map.unmodifiable(_defectData);
  List<Map<String, dynamic>> get hourlyData => List.unmodifiable(_hourlyData);
  String get selectedLot => _selectedLot;
  DateTime get selectedDate => _selectedDate;

  int get totalDefects =>
      _defectData.values.fold(0, (sum, value) => sum + value);

  double get defectPercentage {
    const totalInspected = 1000; // Mock total
    return totalDefects > 0 ? (totalDefects / totalInspected) * 100 : 0.0;
  }

  void updateDefectCount(String defectType, int count) {
    _defectData[defectType] = count;
    notifyListeners();
  }

  void incrementDefectCount(String defectType) {
    _defectData[defectType] = (_defectData[defectType] ?? 0) + 1;
    notifyListeners();
  }

  void setSelectedLot(String lot) {
    _selectedLot = lot;
    _generateMockHourlyData();
    notifyListeners();
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    _generateMockHourlyData();
    notifyListeners();
  }

  void _generateMockHourlyData() {
    _hourlyData.clear();
    for (int hour = 0; hour < 24; hour++) {
      _hourlyData.add({
        'hour': hour,
        'total': (hour % 3 + 1) * 50, // Mock data
        'ok': (hour % 3 + 1) * 45,
        'ng': (hour % 3 + 1) * 5,
        'ngRate': 10.0 + (hour % 5) * 2,
      });
    }
  }

  // Chart data helpers
  List<Map<String, dynamic>> getDefectChartData() {
    return _defectData.entries
        .map(
          (entry) => {
            'label': entry.key,
            'value': entry.value,
            'color': _getDefectColor(entry.key),
          },
        )
        .toList();
  }

  int _getDefectColor(String defectType) {
    switch (defectType) {
      case 'Hở mạch':
        return 0xFFEF4444; // Red
      case 'Thiếu linh kiện':
        return 0xFF3B82F6; // Blue
      case 'Nhiễu ảnh':
        return 0xFF10B981; // Green
      case 'Xước mạch':
        return 0xFFF59E0B; // Yellow
      default:
        return 0xFF6B7280; // Gray
    }
  }

  void resetStatistics() {
    _defectData.clear();
    _defectData.addAll({
      'Hở mạch': 0,
      'Thiếu linh kiện': 0,
      'Nhiễu ảnh': 0,
      'Xước mạch': 0,
    });
    _hourlyData.clear();
    _selectedLot = '';
    notifyListeners();
  }
}
