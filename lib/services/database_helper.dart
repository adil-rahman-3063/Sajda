import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    } else if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String path = join(await getDatabasesPath(), 'prayer_tracker_v2.db');
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    // Stores daily prayer records
    // id: auto-increment primary key
    // date: YYYY-MM-DD string
    // fajr: 0 (missed), 1 (offered)
    // dhuhr: 0 (missed), 1 (offered)
    // asr: 0 (missed), 1 (offered)
    // maghrib: 0 (missed), 1 (offered)
    // isha: 0 (missed), 1 (offered)
    await db.execute('''
      CREATE TABLE prayer_records(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT UNIQUE,
        fajr INTEGER DEFAULT 0,
        dhuhr INTEGER DEFAULT 0,
        asr INTEGER DEFAULT 0,
        maghrib INTEGER DEFAULT 0,
        isha INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE user_profile(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        age INTEGER,
        image_path TEXT
      )
    ''');
  }

  // ... (previous prayer methods)

  Future<int> saveUserProfile(String name, int age, String? imagePath) async {
    final db = await database;
    // Check if profile exists
    final List<Map<String, dynamic>> maps = await db.query('user_profile');
    if (maps.isEmpty) {
      return await db.insert('user_profile', {
        'name': name,
        'age': age,
        'image_path': imagePath,
      });
    } else {
      return await db.update(
        'user_profile',
        {'name': name, 'age': age, 'image_path': imagePath},
        where: 'id = ?',
        whereArgs: [maps.first['id']],
      );
    }
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('user_profile');
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  Future<int> insertOrUpdatePrayer(
    String date,
    String prayerName,
    bool isCompleted,
  ) async {
    final db = await database;
    int status = isCompleted ? 1 : 0;

    // Check if record exists for the date
    final List<Map<String, dynamic>> maps = await db.query(
      'prayer_records',
      where: 'date = ?',
      whereArgs: [date],
    );

    if (maps.isEmpty) {
      // Insert new record
      return await db.insert('prayer_records', {
        'date': date,
        prayerName: status,
      });
    } else {
      // Update existing record
      return await db.update(
        'prayer_records',
        {prayerName: status},
        where: 'date = ?',
        whereArgs: [date],
      );
    }
  }

  Future<Map<String, dynamic>?> getDailyRecord(String date) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'prayer_records',
      where: 'date = ?',
      whereArgs: [date],
    );

    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getAllRecords() async {
    final db = await database;
    return await db.query('prayer_records', orderBy: "date DESC");
  }
}
