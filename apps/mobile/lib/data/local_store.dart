import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// Kullanıcı verisinin cihazdaki deposu. drift (SQLite) kullanılır; açılamazsa bellek içi depoya düşülür.
abstract class LocalStore {
  bool get persistent;
  Future<void> open();
  Future<String?> getKv(String key);
  Future<void> putKv(String key, String value);
  Future<void> addEvent(Map<String, Object?> e);
  Future<List<Map<String, Object?>>> allEvents();
  Future<void> markSynced(List<String> ids);
  Future<void> putCard(String targetId, Map<String, Object?> state, {bool dirty = true});
  Future<Map<String, Map<String, Object?>>> allCards();
  Future<List<String>> dirtyCards();
  Future<void> clearDirtyCards(List<String> ids);
  Future<void> wipe();
}

class _Db extends GeneratedDatabase {
  _Db(super.e);
  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];
  @override
  Iterable<DatabaseSchemaEntity> get allSchemaEntities => const [];
  @override
  int get schemaVersion => 1;
}

const _schema = [
  'CREATE TABLE IF NOT EXISTS kv (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
  'CREATE TABLE IF NOT EXISTS events (id TEXT PRIMARY KEY, body TEXT NOT NULL, answered_at TEXT NOT NULL, synced INTEGER NOT NULL DEFAULT 0)',
  'CREATE TABLE IF NOT EXISTS cards (target_id TEXT PRIMARY KEY, body TEXT NOT NULL, dirty INTEGER NOT NULL DEFAULT 1)',
  'CREATE INDEX IF NOT EXISTS events_time ON events (answered_at)',
];

class DriftStore implements LocalStore {
  late final _Db _db;
  @override
  bool get persistent => true;

  @override
  Future<void> open() async {
    _db = _Db(driftDatabase(
      name: 'lingora',
      web: DriftWebOptions(sqlite3Wasm: Uri.parse('sqlite3.wasm'), driftWorker: Uri.parse('drift_worker.js')),
    ));
    for (final s in _schema) {
      await _db.customStatement(s);
    }
  }

  @override
  Future<String?> getKv(String key) async {
    final rows = await _db.customSelect('SELECT value FROM kv WHERE key = ?', variables: [Variable.withString(key)]).get();
    return rows.isEmpty ? null : rows.first.data['value'] as String;
  }

  @override
  Future<void> putKv(String key, String value) =>
      _db.customStatement('INSERT INTO kv (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value', [key, value]);

  @override
  Future<void> addEvent(Map<String, Object?> e) => _db.customStatement(
        'INSERT OR IGNORE INTO events (id, body, answered_at, synced) VALUES (?, ?, ?, ?)',
        [e['id'], jsonEncode(e), e['answered_at'], (e['synced'] == true) ? 1 : 0],
      );

  @override
  Future<List<Map<String, Object?>>> allEvents() async {
    final rows = await _db.customSelect('SELECT body, synced FROM events ORDER BY answered_at').get();
    return rows.map((r) {
      final m = (jsonDecode(r.data['body'] as String) as Map).cast<String, Object?>();
      m['synced'] = (r.data['synced'] as int) == 1;
      return m;
    }).toList();
  }

  @override
  Future<void> markSynced(List<String> ids) async {
    for (final id in ids) {
      await _db.customStatement('UPDATE events SET synced = 1 WHERE id = ?', [id]);
    }
  }

  @override
  Future<void> putCard(String targetId, Map<String, Object?> state, {bool dirty = true}) => _db.customStatement(
        'INSERT INTO cards (target_id, body, dirty) VALUES (?, ?, ?) ON CONFLICT(target_id) DO UPDATE SET body = excluded.body, dirty = excluded.dirty',
        [targetId, jsonEncode(state), dirty ? 1 : 0],
      );

  @override
  Future<Map<String, Map<String, Object?>>> allCards() async {
    final rows = await _db.customSelect('SELECT target_id, body FROM cards').get();
    return {for (final r in rows) r.data['target_id'] as String: (jsonDecode(r.data['body'] as String) as Map).cast<String, Object?>()};
  }

  @override
  Future<List<String>> dirtyCards() async {
    final rows = await _db.customSelect('SELECT target_id FROM cards WHERE dirty = 1').get();
    return rows.map((r) => r.data['target_id'] as String).toList();
  }

  @override
  Future<void> clearDirtyCards(List<String> ids) async {
    for (final id in ids) {
      await _db.customStatement('UPDATE cards SET dirty = 0 WHERE target_id = ?', [id]);
    }
  }

  @override
  Future<void> wipe() async {
    await _db.customStatement('DELETE FROM kv');
    await _db.customStatement('DELETE FROM events');
    await _db.customStatement('DELETE FROM cards');
  }
}

/// Testler ve depolamanın açılamadığı durumlar için.
class MemoryStore implements LocalStore {
  final _kv = <String, String>{};
  final _events = <String, Map<String, Object?>>{};
  final _cards = <String, Map<String, Object?>>{};
  final _dirty = <String>{};
  @override
  bool get persistent => false;
  @override
  Future<void> open() async {}
  @override
  Future<String?> getKv(String key) async => _kv[key];
  @override
  Future<void> putKv(String key, String value) async => _kv[key] = value;
  @override
  Future<void> addEvent(Map<String, Object?> e) async => _events.putIfAbsent(e['id'] as String, () => Map.of(e));
  @override
  Future<List<Map<String, Object?>>> allEvents() async {
    final l = _events.values.map((e) => Map<String, Object?>.of(e)).toList();
    l.sort((a, b) => (a['answered_at'] as String).compareTo(b['answered_at'] as String));
    return l;
  }

  @override
  Future<void> markSynced(List<String> ids) async {
    for (final id in ids) {
      _events[id]?['synced'] = true;
    }
  }

  @override
  Future<void> putCard(String targetId, Map<String, Object?> state, {bool dirty = true}) async {
    _cards[targetId] = state;
    if (dirty) {
      _dirty.add(targetId);
    } else {
      _dirty.remove(targetId);
    }
  }

  @override
  Future<Map<String, Map<String, Object?>>> allCards() async => Map.of(_cards);
  @override
  Future<List<String>> dirtyCards() async => _dirty.toList();
  @override
  Future<void> clearDirtyCards(List<String> ids) async => _dirty.removeAll(ids);
  @override
  Future<void> wipe() async {
    _kv.clear();
    _events.clear();
    _cards.clear();
    _dirty.clear();
  }
}
