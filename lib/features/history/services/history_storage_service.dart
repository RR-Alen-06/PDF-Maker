import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class HistoryItem {
  final int? id;
  final String title;
  final String filePath;
  final int fileSizeBytes;
  final int pageCount;
  final DateTime createdAt;

  const HistoryItem({
    this.id,
    required this.title,
    required this.filePath,
    required this.fileSizeBytes,
    required this.pageCount,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'file_path': filePath,
      'file_size_bytes': fileSizeBytes,
      'page_count': pageCount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory HistoryItem.fromMap(Map<String, dynamic> map) {
    return HistoryItem(
      id: map['id'] as int?,
      title: map['title'] as String,
      filePath: map['file_path'] as String,
      fileSizeBytes: map['file_size_bytes'] as int,
      pageCount: map['page_count'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  bool get fileExists => File(filePath).existsSync();
}

class HistoryStorageService {
  static final HistoryStorageService _instance = HistoryStorageService._internal();
  factory HistoryStorageService() => _instance;
  HistoryStorageService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'pdf_maker_history.db');

    try {
      return await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE history (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              file_path TEXT NOT NULL,
              file_size_bytes INTEGER NOT NULL,
              page_count INTEGER NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
        },
      );
    } catch (_) {
      // Suggestion 13: Delete corrupted storage and re-initialize empty database
      try {
        await deleteDatabase(path);
      } catch (_) {}

      return await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE history (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              file_path TEXT NOT NULL,
              file_size_bytes INTEGER NOT NULL,
              page_count INTEGER NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
        },
      );
    }
  }

  Future<int> addHistoryItem({
    required String title,
    required String filePath,
    required int fileSizeBytes,
    required int pageCount,
  }) async {
    final db = await database;
    return await db.insert('history', {
      'title': title,
      'file_path': filePath,
      'file_size_bytes': fileSizeBytes,
      'page_count': pageCount,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<HistoryItem>> getAllHistory() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'history',
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) => HistoryItem.fromMap(maps[i]));
  }

  Future<void> deleteHistoryItem(int id, String filePath) async {
    final db = await database;
    await db.delete('history', where: 'id = ?', whereArgs: [id]);
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> updateTitle(int id, String newTitle, String oldPath) async {
    final db = await database;
    final file = File(oldPath);
    if (await file.exists()) {
      final dir = file.parent.path;
      final newPath = p.join(dir, newTitle.endsWith('.pdf') ? newTitle : '$newTitle.pdf');
      await file.rename(newPath);
      await db.update(
        'history',
        {'title': newTitle, 'file_path': newPath},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }
}
