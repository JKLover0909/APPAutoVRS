import 'package:flutter/foundation.dart';
import '../services/local_database_service.dart';

class StatisticsProvider extends ChangeNotifier {
  final LocalDatabaseService _db = LocalDatabaseService();

  // Cached data
  Map<String, int> _defectData = {};
  List<Map<String, dynamic>> _lotStatistics = [];
  List<Map<String, dynamic>> _defectStatistics = [];
  List<Map<String, dynamic>> _lots = [];
  String _selectedLot = '';
  bool _isLoading = false;

  // Getters
  Map<String, int> get defectData => Map.unmodifiable(_defectData);
  List<Map<String, dynamic>> get lotStatistics =>
      List.unmodifiable(_lotStatistics);
  List<Map<String, dynamic>> get defectStatistics =>
      List.unmodifiable(_defectStatistics);
  List<Map<String, dynamic>> get lots => List.unmodifiable(_lots);
  String get selectedLot => _selectedLot;
  bool get isLoading => _isLoading;

  int get totalDefects =>
      _defectData.values.fold(0, (sum, value) => sum + value);

  // Initialize and load data from database
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      await loadDefectStatistics();
      await loadLotStatistics();
      await loadLots();
    } catch (e) {
      debugPrint('Error initializing StatisticsProvider: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load defect statistics from database
  Future<void> loadDefectStatistics() async {
    try {
      _defectData = await _db.getDefectStatistics();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading defect statistics: $e');
    }
  }

  // Load lot statistics from database
  Future<void> loadLotStatistics() async {
    try {
      final rawStats = await _db.getAllLotStatistics();
      _lotStatistics = rawStats.map((stat) {
        return {
          'lotId': 'LOT-${stat['id_lot']}',
          'lotName': 'Lot ${stat['id_lot']}',
          'boardCount': stat['actual_boards'] ?? 0,
          'ngRate':
              ((stat['ng_boards'] ?? 0) / (stat['actual_boards'] ?? 1)) * 100,
          'okCount': stat['ok_boards'] ?? 0,
          'ngCount': stat['ng_boards'] ?? 0,
          'createdDate': DateTime.now().toIso8601String().substring(0, 10),
          'falsePositiveRate': stat['fakeDef'] ?? 0.0,
        };
      }).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading lot statistics: $e');
    }
  }

  // Load available lots
  Future<void> loadLots() async {
    try {
      final allLots = await _db.getAllLots();
      _lots = allLots.map((lot) {
        return {
          'lot_id': 'LOT-${lot['id_lot']}',
          'model_id': lot['tbModelid_model'] ?? 1,
          'total_boards': lot['board_quantity'] ?? 0,
          'id_lot': lot['id_lot'],
        };
      }).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading lots: $e');
    }
  }

  // Get statistics for specific lot
  Future<Map<String, dynamic>?> getLotStatistics(int lotId) async {
    try {
      return await _db.getLotStatistics(lotId);
    } catch (e) {
      debugPrint('Error getting lot statistics: $e');
      return null;
    }
  }

  // Get defects for specific lot
  Future<List<Map<String, dynamic>>> getDefectsForLot(int lotId) async {
    try {
      final boards = await _db.getBoardsByLot(lotId);
      final defects = <Map<String, dynamic>>[];

      for (var board in boards) {
        final boardDefects = await _db.getDefectsByBoard(board['id_board']);
        for (var defect in boardDefects) {
          defects.add({
            'id': defect['id_defect'],
            'boardId': defect['tbBoardid_board'],
            'type': defect['type'],
            'judgment': defect['judgement'],
            'height': defect['height'],
            'width': defect['width'],
            'time': defect['time'],
            'coordinates': defect['coordinates'],
            'url_image': defect['url_image'],
          });
        }
      }

      return defects;
    } catch (e) {
      debugPrint('Error getting defects for lot: $e');
      return [];
    }
  }

  // Select lot for detailed view
  void selectLot(String lotId) {
    _selectedLot = lotId;
    notifyListeners();
  }

  // Load detailed defect statistics for a specific lot
  Future<void> loadLotDefectStatistics(int lotId) async {
    try {
      final boards = await _db.getBoardsByLot(lotId);
      final allDefects = <Map<String, dynamic>>[];

      for (final board in boards) {
        final defects = await _db.getDefectsByBoard(board['id_board']);
        allDefects.addAll(defects);
      }

      // Group defects by type and calculate statistics
      final defectTypes = <String, Map<String, int>>{};
      for (final defect in allDefects) {
        final type = defect['type'] ?? 'Unknown';
        if (!defectTypes.containsKey(type)) {
          defectTypes[type] = {'count': 0, 'total': 0};
        }
        defectTypes[type]!['count'] = defectTypes[type]!['count']! + 1;
        defectTypes[type]!['total'] = defectTypes[type]!['total']! + 1;
      }

      _defectStatistics = defectTypes.entries.map((entry) {
        return {
          'type': entry.key,
          'count': entry.value['count'],
          'percentage': allDefects.isNotEmpty
              ? (entry.value['count']! / allDefects.length * 100).toDouble()
              : 0.0,
        };
      }).toList();

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading defect statistics: $e');
    }
  }

  // Refresh all data
  Future<void> refreshData() async {
    await initialize();
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

  // Get summary statistics
  Map<String, dynamic> getSummaryStatistics() {
    final totalBoards = _lotStatistics.fold<int>(
      0,
      (sum, lot) => sum + (lot['boardCount'] as int),
    );
    final totalNg = _lotStatistics.fold<int>(
      0,
      (sum, lot) => sum + (lot['ngCount'] as int),
    );
    final totalOk = _lotStatistics.fold<int>(
      0,
      (sum, lot) => sum + (lot['okCount'] as int),
    );
    final overallNgRate = totalBoards > 0 ? (totalNg / totalBoards) * 100 : 0.0;

    return {
      'totalBoards': totalBoards,
      'totalOk': totalOk,
      'totalNg': totalNg,
      'overallNgRate': overallNgRate,
      'totalDefects': totalDefects,
      'totalLots': _lots.length,
    };
  }
}
