import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class LocalDatabaseService {
  static final LocalDatabaseService _instance =
      LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  Database? _db;
  bool _isInitializing = false;

  Future<Database> get database async {
    // Nếu database đã được khởi tạo, trả về ngay
    if (_db != null && _db!.isOpen) {
      return _db!;
    }

    // Nếu đang khởi tạo, đợi
    if (_isInitializing) {
      while (_isInitializing) {
        await Future.delayed(Duration(milliseconds: 10));
      }
      if (_db != null && _db!.isOpen) {
        return _db!;
      }
    }

    // Khởi tạo database
    _isInitializing = true;
    try {
      _db = await _initDatabase();
      return _db!;
    } finally {
      _isInitializing = false;
    }
  }

  Future<Database> _initDatabase() async {
    String path;

    try {
      if (Platform.isWindows) {
        // Sử dụng thư mục Documents của user
        final userProfile =
            Platform.environment['USERPROFILE'] ?? 'C:\\Users\\Default';
        final documentsDir = Directory(
          join(userProfile, 'Documents', 'AutoVRS'),
        );

        // Tạo thư mục nếu không tồn tại
        if (!await documentsDir.exists()) {
          await documentsDir.create(recursive: true);
        }

        path = join(documentsDir.path, 'autovrs.db');
      } else {
        final dbPath = await getDatabasesPath();
        final dbDir = Directory(dirname(join(dbPath, 'autovrs.db')));
        if (!await dbDir.exists()) {
          await dbDir.create(recursive: true);
        }
        path = join(dbPath, 'autovrs.db');
      }

      debugPrint('Database path: $path');

      return await openDatabase(
        path,
        version: 1,
        onCreate: _createTables,
        onOpen: (db) {
          debugPrint('Database opened successfully');
        },
      );
    } catch (e) {
      debugPrint('Error creating database: $e');
      rethrow;
    }
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tbModel (
        id_model INTEGER PRIMARY KEY AUTOINCREMENT,
        line_size REAL,
        space_size REAL,
        url_gerber TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE tbLot (
        id_lot INTEGER PRIMARY KEY AUTOINCREMENT,
        NG_rate REAL,
        fakeDef REAL,
        board_quantity INTEGER,
        tbModelid_model INTEGER,
        FOREIGN KEY (tbModelid_model) REFERENCES tbModel(id_model)
      )
    ''');

    await db.execute('''
      CREATE TABLE tbBoard (
        id_board INTEGER PRIMARY KEY AUTOINCREMENT,
        defect_quantity INTEGER,
        erro_quantity INTEGER,
        tbLotid_lot INTEGER,
        FOREIGN KEY (tbLotid_lot) REFERENCES tbLot(id_lot)
      )
    ''');

    await db.execute('''
      CREATE TABLE tbDefect (
        id_defect INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT,
        judgement TEXT,
        height REAL,
        width REAL,
        time TEXT,
        coordinates TEXT,
        url_image INTEGER,
        tbBoardid_board INTEGER,
        FOREIGN KEY (tbBoardid_board) REFERENCES tbBoard(id_board)
      )
    ''');

    await db.execute('''
      CREATE TABLE tbConfig (
        config_key TEXT PRIMARY KEY,
        config_value TEXT
      )
    ''');

    debugPrint('Database tables created successfully');
  }

  Future<String> get databasePath async {
    if (Platform.isWindows) {
      final userProfile =
          Platform.environment['USERPROFILE'] ?? 'C:\\Users\\Default';
      final documentsDir = Directory(join(userProfile, 'Documents', 'AutoVRS'));
      return join(documentsDir.path, 'autovrs.db');
    } else {
      final dbPath = await getDatabasesPath();
      return join(dbPath, 'autovrs.db');
    }
  }

  // ========== MODEL OPERATIONS ==========
  Future<int> insertModel(Map<String, dynamic> model) async {
    final db = await database;
    final id_model = await db.insert(
      'tbModel',
      model,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return id_model;
  }

  Future<List<Map<String, dynamic>>> getAllModels() async {
    final db = await database;
    return await db.query('tbModel');
  }

  /// Delete a model by its id_model. Returns number of rows deleted.
  Future<int> deleteModel(int id) async {
    final db = await database;
    return await db.delete('tbModel', where: 'id_model = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>?> getModelById(int id) async {
    final db = await database;
    final results = await db.query(
      'tbModel',
      where: 'id_model = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>?> getActiveModel() async {
    final db = await database;
    // Just return the first model for now since there's no is_active column
    final results = await db.query('tbModel', limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  // ========== LOT OPERATIONS ==========
  Future<int> insertLot(Map<String, dynamic> lot) async {
    final db = await database;
    return await db.insert(
      'tbLot',
      lot,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getAllLots() async {
    final db = await database;
    return await db.query('tbLot', orderBy: 'id_lot DESC');
  }

  Future<Map<String, dynamic>?> getLotById(int idLot) async {
    final db = await database;
    final results = await db.query(
      'tbLot',
      where: 'id_lot = ?',
      whereArgs: [idLot],
    );
    return results.isNotEmpty ? results.first : null;
  }

  // ========== BOARD OPERATIONS ==========
  Future<int> insertBoard(Map<String, dynamic> board) async {
    final db = await database;
    return await db.insert(
      'tbBoard',
      board,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getAllBoards() async {
    final db = await database;
    return await db.query('tbBoard', orderBy: 'id_board DESC');
  }

  Future<List<Map<String, dynamic>>> getBoardsByLot(int idLot) async {
    final db = await database;
    return await db.query(
      'tbBoard',
      where: 'tbLotid_lot = ?',
      whereArgs: [idLot],
      orderBy: 'id_board DESC',
    );
  }

  Future<Map<String, dynamic>?> getBoardById(int idBoard) async {
    final db = await database;
    final results = await db.query(
      'tbBoard',
      where: 'id_board = ?',
      whereArgs: [idBoard],
    );
    return results.isNotEmpty ? results.first : null;
  }

  // ========== DEFECT OPERATIONS ==========
  Future<int> insertDefect(Map<String, dynamic> defect) async {
    final db = await database;
    return await db.insert(
      'tbDefect',
      defect,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getAllDefects() async {
    final db = await database;
    return await db.query('tbDefect', orderBy: 'time DESC');
  }

  Future<List<Map<String, dynamic>>> getDefectsByBoard(int idBoard) async {
    final db = await database;
    return await db.query(
      'tbDefect',
      where: 'tbBoardid_board = ?',
      whereArgs: [idBoard],
      // Order by primary key (insertion order) for deterministic processing
      orderBy: 'id_defect ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getDefectsByType(String defectType) async {
    final db = await database;
    return await db.query(
      'tbDefect',
      where: 'type = ?',
      whereArgs: [defectType],
      orderBy: 'time DESC',
    );
  }

  /// Update fields of a defect row by its id_defect.
  /// Returns number of rows affected.
  Future<int> updateDefect(int idDefect, Map<String, dynamic> fields) async {
    final db = await database;
    return await db.update(
      'tbDefect',
      fields,
      where: 'id_defect = ?',
      whereArgs: [idDefect],
    );
  }

  // ========== CONFIG OPERATIONS ==========
  Future<int> insertConfig(Map<String, dynamic> config) async {
    final db = await database;
    return await db.insert(
      'tbConfig',
      config,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getAllConfigs() async {
    final db = await database;
    return await db.query('tbConfig');
  }

  Future<String?> getConfigValue(String key) async {
    final db = await database;
    final results = await db.query(
      'tbConfig',
      where: 'config_key = ?',
      whereArgs: [key],
    );
    return results.isNotEmpty ? results.first['config_value'] as String? : null;
  }

  Future<int> updateConfig(String key, String value) async {
    final db = await database;
    return await db.update(
      'tbConfig',
      {'config_value': value},
      where: 'config_key = ?',
      whereArgs: [key],
    );
  }

  // ========== STATISTICS OPERATIONS ==========
  Future<Map<String, int>> getDefectStatistics() async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT type, COUNT(*) as count 
      FROM tbDefect 
      GROUP BY type
    ''');

    final Map<String, int> stats = {};
    for (var row in results) {
      // Defensive handling: row['type'] may be null in some DB rows.
      final key = row['type'] != null ? row['type'].toString() : 'Unknown';

      // `count` should be an int, but be defensive in case it's returned as String.
      int count = 0;
      if (row['count'] is int) {
        count = row['count'] as int;
      } else if (row['count'] != null) {
        count = int.tryParse(row['count'].toString()) ?? 0;
      }

      stats[key] = count;
    }
    return stats;
  }

  Future<Map<String, dynamic>> getLotStatistics(int idLot) async {
    final db = await database;

    // Get total boards for this lot
    final totalResult = await db.rawQuery(
      '''
      SELECT COUNT(*) as total FROM tbBoard WHERE tbLotid_lot = ?
    ''',
      [idLot],
    );
    final total = totalResult.first['total'] as int;

    // Get boards with defects (defect_quantity > 0)
    final ngResult = await db.rawQuery(
      '''
      SELECT COUNT(*) as ng FROM tbBoard WHERE tbLotid_lot = ? AND defect_quantity > 0
    ''',
      [idLot],
    );
    final ng = ngResult.first['ng'] as int;

    final ok = total - ng;
    final ngRate = total > 0 ? (ng / total) * 100 : 0.0;

    return {'total': total, 'ok': ok, 'ng': ng, 'ngRate': ngRate};
  }

  Future<List<Map<String, dynamic>>> getAllLotStatistics() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        l.id_lot,
        l.board_quantity,
        l.NG_rate,
        l.fakeDef,
        COUNT(b.id_board) as actual_boards,
        SUM(CASE WHEN b.defect_quantity > 0 THEN 1 ELSE 0 END) as ng_boards,
        SUM(CASE WHEN b.defect_quantity = 0 THEN 1 ELSE 0 END) as ok_boards
      FROM tbLot l
      LEFT JOIN tbBoard b ON l.id_lot = b.tbLotid_lot
      GROUP BY l.id_lot
      ORDER BY l.id_lot DESC
    ''');
  }

  // ========== UTILITY OPERATIONS ==========
  Future<void> clearAllTables() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('tbDefect');
      await txn.delete('tbBoard');
      await txn.delete('tbLot');
      await txn.delete('tbModel');
      await txn.delete('tbConfig');
    });
  }

  Future<Map<String, dynamic>> getDatabaseInfo() async {
    final db = await database;

    final modelCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM tbModel'),
        ) ??
        0;
    final lotCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM tbLot'),
        ) ??
        0;
    final boardCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM tbBoard'),
        ) ??
        0;
    final defectCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM tbDefect'),
        ) ??
        0;
    final configCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM tbConfig'),
        ) ??
        0;

    return {
      'models': modelCount,
      'lots': lotCount,
      'boards': boardCount,
      'defects': defectCount,
      'configs': configCount,
    };
  }

  // Close database
  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }

  Future<Map<String, dynamic>?> getFirstLotByModelId(String idModel) async {
    final db = await database;
    final lots = await db.query(
      'tbLot',
      where: 'tbModelid_model = ?',
      whereArgs: [idModel],
      orderBy: 'id_lot ASC',
    );
    return lots.isNotEmpty ? lots.first : null;
  }

  Future<Map<String, dynamic>?> getFirstBoardByLotId(String idLot) async {
    final db = await database;
    final boards = await db.query(
      'tbBoard',
      where: 'tbLotid_lot = ?',
      whereArgs: [idLot],
      orderBy: 'id_board ASC',
    );
    return boards.isNotEmpty ? boards.first : null;
  }
}
