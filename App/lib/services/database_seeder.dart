import 'local_database_service.dart';

class DatabaseSeeder {
  static final DatabaseSeeder _instance = DatabaseSeeder._internal();
  factory DatabaseSeeder() => _instance;
  DatabaseSeeder._internal();

  static bool _isSeeded = false;

  Future<void> seedDatabase() async {
    if (_isSeeded) {
      print('📋 Database already seeded, skipping...');
      return;
    }

    final db = LocalDatabaseService();
    
    try {
      // Seed Models
      await _seedModels(db);
      
      // Seed Lots
      await _seedLots(db);
      
      // Seed Boards
      await _seedBoards(db);
      
      // Seed Defects
      await _seedDefects(db);
      
      // Seed Config
      await _seedConfig(db);
      
      print('✅ Database seeded successfully');
      _isSeeded = true;
    } catch (e) {
      print('❌ Error seeding database: $e');
    }
  }

  Future<void> _seedModels(LocalDatabaseService db) async {
    final models = [
      {
        'line_size': 0.125,
        'space_size': 0.150,
        'url_gerber': '/models/MODEL-001.gerber',
      },
      {
        'line_size': 0.100,
        'space_size': 0.130,
        'url_gerber': '/models/MODEL-002.gerber',
      }
    ];

    for (var model in models) {
      await db.insertModel(model);
    }
  }

  Future<void> _seedLots(LocalDatabaseService db) async {
    final lots = [
      {
        'NG_rate': 0.08,
        'fakeDef': 0.02,
        'board_quantity': 500,
        'tbModelid': 1,
      },
      {
        'NG_rate': 0.12,
        'fakeDef': 0.01,
        'board_quantity': 750,
        'tbModelid': 2,
      },
      {
        'NG_rate': 0.05,
        'fakeDef': 0.03,
        'board_quantity': 320,
        'tbModelid': 1,
      }
    ];

    for (var lot in lots) {
      await db.insertLot(lot);
    }
  }

  Future<void> _seedBoards(LocalDatabaseService db) async {
    final boards = [
      // Lot 1 boards
      {'defect_quantity': 0, 'erro_quantity': 0, 'tbLotid_lot': 1},
      {'defect_quantity': 2, 'erro_quantity': 0, 'tbLotid_lot': 1},
      {'defect_quantity': 0, 'erro_quantity': 0, 'tbLotid_lot': 1},
      {'defect_quantity': 0, 'erro_quantity': 1, 'tbLotid_lot': 1},
      {'defect_quantity': 1, 'erro_quantity': 0, 'tbLotid_lot': 1},
      
      // Lot 2 boards
      {'defect_quantity': 0, 'erro_quantity': 0, 'tbLotid_lot': 2},
      {'defect_quantity': 0, 'erro_quantity': 0, 'tbLotid_lot': 2},
      {'defect_quantity': 2, 'erro_quantity': 1, 'tbLotid_lot': 2},
      
      // Lot 3 boards
      {'defect_quantity': 0, 'erro_quantity': 0, 'tbLotid_lot': 3},
      {'defect_quantity': 3, 'erro_quantity': 0, 'tbLotid_lot': 3},
    ];

    for (var board in boards) {
      await db.insertBoard(board);
    }
  }

  Future<void> _seedDefects(LocalDatabaseService db) async {
    final defects = [
      // Board 2 defects (2 defects)
      {'type': 'Hở mạch', 'judgement': 'NG', 'height': 12.5, 'width': 8.3, 'time': '2024-08-10 08:16:15', 'coordinates': '120.5,85.3', 'url_image': 1, 'tbBoardid_board': 2},
      {'type': 'Xước mạch', 'judgement': 'NG', 'height': 15.1, 'width': 7.7, 'time': '2024-08-10 08:16:15', 'coordinates': '200.1,150.7', 'url_image': 2, 'tbBoardid_board': 2},
      
      // Board 5 defects (1 defect)
      {'type': 'Thiếu linh kiện', 'judgement': 'NG', 'height': 20.2, 'width': 10.8, 'time': '2024-08-10 08:18:30', 'coordinates': '350.2,120.8', 'url_image': 3, 'tbBoardid_board': 5},
      
      // Board 8 defects (2 defects)
      {'type': 'Nhiễu ảnh', 'judgement': 'NG', 'height': 8.3, 'width': 5.1, 'time': '2024-08-09 09:12:00', 'coordinates': '180.3,95.1', 'url_image': 4, 'tbBoardid_board': 8},
      {'type': 'Hở mạch', 'judgement': 'NG', 'height': 14.9, 'width': 9.4, 'time': '2024-08-09 09:12:00', 'coordinates': '75.9,200.4', 'url_image': 5, 'tbBoardid_board': 8},
      
      // Board 10 defects (3 defects)
      {'type': 'Xước mạch', 'judgement': 'NG', 'height': 18.7, 'width': 6.2, 'time': '2024-08-08 10:06:00', 'coordinates': '310.7,165.2', 'url_image': 6, 'tbBoardid_board': 10},
      {'type': 'Thiếu linh kiện', 'judgement': 'NG', 'height': 22.6, 'width': 11.9, 'time': '2024-08-08 10:06:00', 'coordinates': '145.6,88.9', 'url_image': 7, 'tbBoardid_board': 10},
      {'type': 'Hở mạch', 'judgement': 'NG', 'height': 16.4, 'width': 7.1, 'time': '2024-08-08 10:06:00', 'coordinates': '265.4,132.1', 'url_image': 8, 'tbBoardid_board': 10},
    ];

    for (var defect in defects) {
      await db.insertDefect(defect);
    }
  }

  Future<void> _seedConfig(LocalDatabaseService db) async {
    final configs = [
      {'config_key': 'current_model', 'config_value': '1'},
      {'config_key': 'system_mode', 'config_value': 'auto'},
      {'config_key': 'magnification', 'config_value': '140'},
      {'config_key': 'light_level', 'config_value': '50'},
      {'config_key': 'dome_light', 'config_value': '50'},
      {'config_key': 'ring_light', 'config_value': '30'},
      {'config_key': 'back_light', 'config_value': '70'},
      {'config_key': 'side_light', 'config_value': '40'},
      {'config_key': 'system_status', 'config_value': 'OK'},
    ];

    for (var config in configs) {
      await db.insertConfig(config);
    }
  }

  Future<void> clearAllData() async {
    final db = LocalDatabaseService();
    
    try {
      await db.clearAllTables();
      print('✅ All data cleared from database');
    } catch (e) {
      print('❌ Error clearing database: $e');
    }
  }
}
