import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/vault_entry.dart';
import '../models/sync_conflict.dart';
import 'crypto_bridge.dart';

class StorageService {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docsDir.path, 'ironkey_mobile.db');

    return await openDatabase(
      dbPath,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            uid TEXT NOT NULL UNIQUE,
            encrypted_blob TEXT NOT NULL,
            rev INTEGER NOT NULL DEFAULT 1,
            deleted_at TEXT,
            device_id TEXT NOT NULL DEFAULT '',
            updated_at TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');

        await db.execute('CREATE INDEX idx_entries_uid ON entries(uid)');
        await db.execute('CREATE INDEX idx_entries_deleted ON entries(deleted_at)');

        await db.execute('''
          CREATE TABLE sync_conflicts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            entry_uid TEXT NOT NULL,
            device_id TEXT NOT NULL,
            detail_json TEXT NOT NULL,
            resolved INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE meta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE purged_uids (
            uid TEXT PRIMARY KEY,
            purged_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // --- Operações de Registros ----------------------------------------

  static Future<void> saveEntry(VaultEntry entry) async {
    final db = await database;
    final jsonStr = jsonEncode(entry.toSyncMap());
    final encryptedBlob = await CryptoBridge.encryptRecord(jsonStr);

    final cleanDeletedAt = (entry.deletedAt != null && entry.deletedAt!.trim().isNotEmpty)
        ? entry.deletedAt!.trim()
        : null;

    await db.insert(
      'entries',
      {
        'uid': entry.uid,
        'encrypted_blob': encryptedBlob,
        'rev': entry.rev,
        'deleted_at': cleanDeletedAt,
        'device_id': entry.deviceId,
        'updated_at': entry.updatedAt,
        'created_at': entry.createdAt,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<VaultEntry>> getAllEntries({bool includeDeleted = false}) async {
    final db = await database;
    final where = includeDeleted ? null : "(deleted_at IS NULL OR deleted_at = '' OR deleted_at = 'null')";
    final rows = await db.query('entries', where: where, orderBy: 'updated_at DESC');

    List<VaultEntry> list = [];
    for (final row in rows) {
      try {
        final blob = row['encrypted_blob'] as String;
        final jsonStr = await CryptoBridge.decryptRecord(blob);
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        
        // Assegura campos de envelope
        map['rev'] = row['rev'];
        map['deleted_at'] = row['deleted_at'];
        map['device_id'] = row['device_id'];
        map['updated_at'] = row['updated_at'];
        map['created_at'] = row['created_at'];

        final entry = VaultEntry.fromMap(map);
        if (includeDeleted || !entry.isDeleted) {
          list.add(entry);
        }
      } catch (e) {
        // Se falhar decifragem de um registro corrompido, pula ou reporta
      }
    }
    return list;
  }

  static Future<void> deleteEntry(String uid, {String deviceId = ''}) async {
    final db = await database;
    final rows = await db.query('entries', where: 'uid = ?', whereArgs: [uid], limit: 1);
    if (rows.isEmpty) return;

    final row = rows.first;
    final currentRev = row['rev'] as int;

    // Converte em tombstone mínimo apagando o payload e marcando deleted_at
    final tombstone = VaultEntry(
      uid: uid,
      title: 'Registro Excluído',
      rev: currentRev + 1,
      deletedAt: DateTime.now().toUtc().toIso8601String(),
      deviceId: deviceId,
    );

    await saveEntry(tombstone);
  }

  // --- Conflitos e Metadados -----------------------------------------

  static Future<void> logConflict(String entryUid, String deviceId, Map<String, dynamic> detail) async {
    final db = await database;
    await db.insert('sync_conflicts', {
      'entry_uid': entryUid,
      'device_id': deviceId,
      'detail_json': jsonEncode(detail),
      'resolved': 0,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  static Future<int> countPendingConflicts() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM sync_conflicts WHERE resolved = 0');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  static Future<List<SyncConflict>> listPendingConflicts() async {
    final db = await database;
    final rows = await db.query('sync_conflicts', where: 'resolved = 0', orderBy: 'created_at DESC');
    return rows.map((r) => SyncConflict(
      id: r['id'] as int,
      entryUid: r['entry_uid'] as String,
      deviceId: r['device_id'] as String,
      detail: jsonDecode(r['detail_json'] as String),
      resolved: false,
      createdAt: r['created_at'] as String,
    )).toList();
  }

  static Future<void> resolveAllConflicts() async {
    final db = await database;
    await db.update('sync_conflicts', {'resolved': 1}, where: 'resolved = 0');
  }

  static Future<String?> getMeta(String key) async {
    final db = await database;
    final rows = await db.query('meta', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
  }

  static Future<void> setMeta(String key, String value) async {
    final db = await database;
    await db.insert(
      'meta',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
