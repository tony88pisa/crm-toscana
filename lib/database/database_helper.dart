// lib/database/database_helper.dart — v6

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/prospect.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'crm_toscana.db');

    return await openDatabase(
      path,
      version: 6,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE prospects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        address TEXT NOT NULL,
        phone TEXT,
        website TEXT,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        province TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'nuovo',
        notes TEXT,
        created_at TEXT NOT NULL,
        last_contact_at TEXT,
        google_place_id TEXT UNIQUE,
        business_type TEXT,
        source TEXT,
        source_url TEXT,
        urgency TEXT DEFAULT 'unknown',
        verified INTEGER DEFAULT 0,
        estimated_open_date TEXT,
        confidence_score INTEGER DEFAULT 0,
        tags TEXT,
        vat_number TEXT,
        owner_name TEXT,
        email TEXT,
        extracted_phone TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE contact_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        prospect_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        outcome TEXT,
        FOREIGN KEY (prospect_id) REFERENCES prospects(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE api_usage (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        month TEXT NOT NULL,
        call_count INTEGER NOT NULL DEFAULT 0,
        UNIQUE(month)
      )
    ''');

    await db.execute('''
      CREATE TABLE blacklist (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        province TEXT NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE(name, province)
      )
    ''');

    await db.execute('CREATE INDEX idx_province ON prospects(province)');
    await db.execute('CREATE INDEX idx_status ON prospects(status)');
    await db.execute('CREATE INDEX idx_place_id ON prospects(google_place_id)');
    await db.execute('CREATE INDEX idx_urgency ON prospects(urgency)');
    await db.execute('CREATE INDEX idx_log_prospect ON contact_log(prospect_id)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try { await db.execute('ALTER TABLE prospects ADD COLUMN source TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE prospects ADD COLUMN source_url TEXT'); } catch (_) {}
    }
    if (oldVersion < 3) {
      try { await db.execute('ALTER TABLE prospects ADD COLUMN urgency TEXT DEFAULT \'unknown\''); } catch (_) {}
      try { await db.execute('ALTER TABLE prospects ADD COLUMN verified INTEGER DEFAULT 0'); } catch (_) {}
      try { await db.execute('ALTER TABLE prospects ADD COLUMN estimated_open_date TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE prospects ADD COLUMN confidence_score INTEGER DEFAULT 0'); } catch (_) {}
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS api_usage (
            id INTEGER PRIMARY KEY AUTOINCREMENT, month TEXT NOT NULL,
            call_count INTEGER NOT NULL DEFAULT 0, UNIQUE(month))
        ''');
      } catch (_) {}
    }
    if (oldVersion < 4) {
      try { await db.execute('ALTER TABLE prospects ADD COLUMN estimated_value INTEGER DEFAULT 0'); } catch (_) {}
      try { await db.execute('ALTER TABLE prospects ADD COLUMN tags TEXT'); } catch (_) {}
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS contact_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            prospect_id INTEGER NOT NULL,
            type TEXT NOT NULL,
            notes TEXT,
            created_at TEXT NOT NULL,
            outcome TEXT,
            FOREIGN KEY (prospect_id) REFERENCES prospects(id) ON DELETE CASCADE)
        ''');
      } catch (_) {}
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_log_prospect ON contact_log(prospect_id)'); } catch (_) {}
    }
    if (oldVersion < 5) {
      try { await db.execute('ALTER TABLE prospects ADD COLUMN vat_number TEXT'); } catch (_) {}
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS blacklist (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            province TEXT NOT NULL,
            created_at TEXT NOT NULL,
            UNIQUE(name, province)
          )
        ''');
      } catch (_) {}
    }
    if (oldVersion < 6) {
      try { await db.execute('ALTER TABLE prospects ADD COLUMN owner_name TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE prospects ADD COLUMN email TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE prospects ADD COLUMN extracted_phone TEXT'); } catch (_) {}
    }
  }

  // ─── API USAGE ──────────────────────────────────────────────────────────────

  Future<int> getApiUsageThisMonth() async {
    final db = await database;
    final month = _currentMonth();
    final r = await db.query('api_usage', where: 'month = ?', whereArgs: [month]);
    return r.isEmpty ? 0 : r.first['call_count'] as int;
  }

  Future<void> incrementApiUsage([int count = 1]) async {
    final db = await database;
    final month = _currentMonth();
    await db.rawInsert('''
      INSERT INTO api_usage (month, call_count) VALUES (?, ?)
      ON CONFLICT(month) DO UPDATE SET call_count = call_count + ?
    ''', [month, count, count]);
  }

  String _currentMonth() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  // ─── INSERT ────────────────────────────────────────────────────────────────

  Future<int> insertProspect(Prospect prospect) async {
    final db = await database;
    return await db.insert('prospects', prospect.toMap()..remove('id'),
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<int> insertProspects(List<Prospect> prospects) async {
    final db = await database;
    int inserted = 0;
    final batch = db.batch();
    for (final p in prospects) {
      batch.insert('prospects', p.toMap()..remove('id'),
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    final results = await batch.commit(noResult: false);
    for (final r in results) {
      if (r != null && (r as int) > 0) inserted++;
    }
    return inserted;
  }

  // ─── ANTI-DUPLICATE & BLACKLIST CHECK ──────────────────────────────────────

  Future<bool> isDuplicateOrBlacklisted(String name, String province) async {
    final db = await database;
    final searchName = name.toLowerCase();
    
    // Check blacklist first
    final blResult = await db.query('blacklist',
      where: 'LOWER(name) = ? AND province = ?',
      whereArgs: [searchName, province],
      limit: 1,
    );
    if (blResult.isNotEmpty) return true;

    // Check existing prospects
    final result = await db.query('prospects',
      where: 'LOWER(name) = ? AND province = ?',
      whereArgs: [searchName, province],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<int> insertNonDuplicate(Prospect prospect) async {
    final isDup = await isDuplicateOrBlacklisted(prospect.name, prospect.province);
    if (isDup) return 0;
    return await insertProspect(prospect);
  }

  Future<void> addToBlacklist(String name, String province) async {
    final db = await database;
    await db.insert(
      'blacklist',
      {
        'name': name,
        'province': province,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  // ─── READ ──────────────────────────────────────────────────────────────────

  Future<List<Prospect>> getAllProspects({
    String? province, ProspectStatus? status,
    String? searchQuery, LeadUrgency? urgency,
  }) async {
    final db = await database;
    String where = '1=1';
    List<dynamic> args = [];

    if (province != null && province != 'Tutte') {
      where += ' AND province = ?'; args.add(province);
    }
    if (status != null) {
      where += ' AND status = ?'; args.add(status.dbValue);
    }
    if (urgency != null) {
      where += ' AND urgency = ?'; args.add(urgency.dbValue);
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      where += ' AND (name LIKE ? OR address LIKE ?)';
      args.add('%$searchQuery%'); args.add('%$searchQuery%');
    }

    final maps = await db.query('prospects',
      where: where, whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at DESC');
    return maps.map((m) => Prospect.fromMap(m)).toList();
  }

  Future<List<Prospect>> getUnvisitedProspects() async {
    final db = await database;
    final maps = await db.query('prospects',
        where: "status IN ('nuovo', 'da_visitare')");
    return maps.map((m) => Prospect.fromMap(m)).toList();
  }

  Future<Prospect?> getProspectById(int id) async {
    final db = await database;
    final maps = await db.query('prospects', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Prospect.fromMap(maps.first);
  }

  Future<Map<String, int>> getStatsByStatus() async {
    final db = await database;
    final result = await db.rawQuery('SELECT status, COUNT(*) as count FROM prospects GROUP BY status');
    return {for (final r in result) r['status'] as String: r['count'] as int};
  }

  Future<int> getTotalCount() async {
    final db = await database;
    final r = await db.rawQuery('SELECT COUNT(*) as count FROM prospects');
    return r.first['count'] as int;
  }

  // ─── DASHBOARD STATS ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDashboardStats() async {
    final db = await database;
    final total = await getTotalCount();
    final statusStats = await getStatsByStatus();

    final weekAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
    final weekResult = await db.rawQuery(
      "SELECT COUNT(*) as count FROM prospects WHERE created_at > ?", [weekAgo]);
    final newThisWeek = weekResult.first['count'] as int;

    final followUpResult = await db.rawQuery('''
      SELECT COUNT(*) as count FROM prospects
      WHERE status NOT IN ('chiuso_vinto', 'chiuso_perso')
      AND (last_contact_at IS NULL OR last_contact_at < ?)
    ''', [DateTime.now().subtract(const Duration(days: 3)).toIso8601String()]);
    final needFollowUp = followUpResult.first['count'] as int;

    return {
      'total': total,
      'statusStats': statusStats,
      'newThisWeek': newThisWeek,
      'needFollowUp': needFollowUp,
    };
  }

  // ─── CONTACT LOG ──────────────────────────────────────────────────────────

  Future<int> addContactLog(ContactLog log) async {
    final db = await database;
    // Update last_contact_at on the prospect
    await db.update('prospects',
      {'last_contact_at': log.createdAt.toIso8601String()},
      where: 'id = ?', whereArgs: [log.prospectId]);
    return await db.insert('contact_log', log.toMap());
  }

  Future<List<ContactLog>> getContactLogs(int prospectId) async {
    final db = await database;
    final maps = await db.query('contact_log',
      where: 'prospect_id = ?', whereArgs: [prospectId],
      orderBy: 'created_at DESC');
    return maps.map((m) => ContactLog.fromMap(m)).toList();
  }

  Future<int> getContactCount(int prospectId) async {
    final db = await database;
    final r = await db.rawQuery(
      'SELECT COUNT(*) as count FROM contact_log WHERE prospect_id = ?',
      [prospectId]);
    return r.first['count'] as int;
  }

  // ─── UPDATE ────────────────────────────────────────────────────────────────

  Future<int> updateStatus(int id, ProspectStatus status, {String? notes}) async {
    final db = await database;
    final data = <String, dynamic>{
      'status': status.dbValue,
      'last_contact_at': DateTime.now().toIso8601String(),
    };
    if (notes != null) data['notes'] = notes;
    return await db.update('prospects', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateProspect(Prospect prospect) async {
    final db = await database;
    return await db.update('prospects', prospect.toMap(),
        where: 'id = ?', whereArgs: [prospect.id]);
  }

  Future<void> updateTags(int id, String tags) async {
    final db = await database;
    await db.update('prospects', {'tags': tags}, where: 'id = ?', whereArgs: [id]);
  }

  // ─── DELETE ────────────────────────────────────────────────────────────────

  Future<int> deleteProspect(int id) async {
    final db = await database;
    await db.delete('contact_log', where: 'prospect_id = ?', whereArgs: [id]);
    return await db.delete('prospects', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAll() async {
    final db = await database;
    await db.delete('contact_log');
    await db.delete('prospects');
  }
}
