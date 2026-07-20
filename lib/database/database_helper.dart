import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/alarm_model.dart';
import '../config/constants.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);
    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ${AppConstants.tableName} (
        ${AppConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${AppConstants.colTitle} TEXT NOT NULL,
        ${AppConstants.colLatitude} REAL NOT NULL,
        ${AppConstants.colLongitude} REAL NOT NULL,
        ${AppConstants.colRadius} REAL NOT NULL,
        ${AppConstants.colIsActive} INTEGER NOT NULL DEFAULT 1,
        ${AppConstants.colCreatedAt} TEXT NOT NULL,
        ${AppConstants.colIsOneTime} INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        ALTER TABLE ${AppConstants.tableName}
        ADD COLUMN ${AppConstants.colIsOneTime} INTEGER NOT NULL DEFAULT 0
      ''');
    }
  }

  Future<int> insertAlarm(AlarmModel alarm) async {
    final db = await database;
    return db.insert(
      AppConstants.tableName,
      alarm.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateAlarm(AlarmModel alarm) async {
    final db = await database;
    return db.update(
      AppConstants.tableName,
      alarm.toMap(),
      where: '${AppConstants.colId} = ?',
      whereArgs: [alarm.id],
    );
  }

  Future<int> deleteAlarm(int id) async {
    final db = await database;
    return db.delete(
      AppConstants.tableName,
      where: '${AppConstants.colId} = ?',
      whereArgs: [id],
    );
  }

  Future<List<AlarmModel>> getAllAlarms() async {
    final db = await database;
    final maps = await db.query(
      AppConstants.tableName,
      orderBy: '${AppConstants.colCreatedAt} DESC',
    );
    return maps.map((m) => AlarmModel.fromMap(m)).toList();
  }

  Future<AlarmModel?> getAlarmById(int id) async {
    final db = await database;
    final maps = await db.query(
      AppConstants.tableName,
      where: '${AppConstants.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return AlarmModel.fromMap(maps.first);
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _db = null;
  }
}
