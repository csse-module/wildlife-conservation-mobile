import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'wildlife_conservation.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE pending_incidents(
        id TEXT PRIMARY KEY,
        type TEXT,
        latitude REAL,
        longitude REAL,
        description TEXT,
        imagePath TEXT,
        timestamp TEXT
      )
    ''');
  }

  Future<int> insertIncident(Map<String, dynamic> incident) async {
    Database db = await database;
    return await db.insert(
      'pending_incidents',
      incident,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getPendingIncidents() async {
    Database db = await database;
    return await db.query('pending_incidents');
  }

  Future<int> deleteIncident(String id) async {
    Database db = await database;
    return await db.delete(
      'pending_incidents',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
