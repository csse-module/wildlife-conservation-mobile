import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._init();
  static Database? _database;

  DBHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('offline_sync.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textNullable = 'TEXT';

    await db.execute('''
      CREATE TABLE offline_tasks (
        id $idType,
        type $textType,
        url $textType,
        method $textType,
        body $textType,
        imagePath $textNullable,
        created_at $textType
      )
    ''');
  }

  Future<int> insertTask(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('offline_tasks', row);
  }

  Future<List<Map<String, dynamic>>> getTasks() async {
    final db = await instance.database;
    return await db.query('offline_tasks', orderBy: 'created_at ASC');
  }

  Future<int> deleteTask(int id) async {
    final db = await instance.database;
    return await db.delete(
      'offline_tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> clearAllTasks() async {
    final db = await instance.database;
    return await db.delete('offline_tasks');
  }
}
