import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sq;

import '../domain/models.dart';

enum ImportMode { merge, replace }

class BackupValidationException implements Exception {
  const BackupValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ImportPreview {
  const ImportPreview({
    required this.snapshot,
    required this.exportedAt,
    required this.newTasks,
    required this.newProjects,
    required this.newCompletions,
    required this.duplicateCount,
    required this.conflictCount,
  });

  final AppSnapshot snapshot;
  final DateTime exportedAt;
  final int newTasks;
  final int newProjects;
  final int newCompletions;
  final int duplicateCount;
  final int conflictCount;
}

class LocalRepository {
  LocalRepository({
    sq.DatabaseFactory? databaseFactory,
    String? databasePath,
    Directory? backupDirectory,
  }) : _factory = databaseFactory ?? sq.databaseFactory,
       _databasePath = databasePath,
       _backupDirectory = backupDirectory;

  final sq.DatabaseFactory _factory;
  final String? _databasePath;
  final Directory? _backupDirectory;
  sq.Database? _database;

  Future<sq.Database> _open() async {
    if (_database != null) return _database!;
    final path =
        _databasePath ?? p.join(await sq.getDatabasesPath(), 'yushi.sqlite');
    _database = await _factory.openDatabase(
      path,
      options: sq.OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE app_state (id INTEGER PRIMARY KEY CHECK (id = 1), snapshot TEXT NOT NULL)',
          );
        },
      ),
    );
    return _database!;
  }

  Future<AppSnapshot> load() async {
    final db = await _open();
    final rows = await db.query('app_state', where: 'id = ?', whereArgs: [1]);
    if (rows.isEmpty) return AppSnapshot.empty();
    try {
      final raw = jsonDecode(rows.single['snapshot']! as String);
      return AppSnapshot.fromJson(_asObject(raw));
    } on FormatException catch (error) {
      throw BackupValidationException('本地数据无法读取：${error.message}');
    }
  }

  Future<void> save(AppSnapshot snapshot) async {
    final validated = _validateSnapshot(snapshot);
    final db = await _open();
    await db.transaction((txn) async {
      await txn.insert('app_state', {
        'id': 1,
        'snapshot': jsonEncode(validated.toJson()),
      }, conflictAlgorithm: sq.ConflictAlgorithm.replace);
    });
  }

  Future<File> exportBackup() async {
    final directory =
        _backupDirectory ??
        Directory(
          p.join((await getApplicationDocumentsDirectory()).path, 'backups'),
        );
    await directory.create(recursive: true);
    final now = DateTime.now();
    final stamp = now.toIso8601String().replaceAll(':', '-').split('.').first;
    final file = File(p.join(directory.path, 'yushi-$stamp.json'));
    final payload = {
      'format': 'yushi.backup',
      'version': 1,
      'exportedAt': now.toIso8601String(),
      'data': (await load()).toJson(),
    };
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
    return file;
  }

  Future<ImportPreview> previewImport(String jsonText) async {
    final imported = _decodeBackup(jsonText);
    final current = await load();
    final taskDiff = _diff(
      current.tasks.map((e) => MapEntry(e.id, jsonEncode(e.toJson()))),
      imported.snapshot.tasks.map(
        (e) => MapEntry(e.id, jsonEncode(e.toJson())),
      ),
    );
    final projectDiff = _diff(
      current.projects.map((e) => MapEntry(e.id, jsonEncode(e.toJson()))),
      imported.snapshot.projects.map(
        (e) => MapEntry(e.id, jsonEncode(e.toJson())),
      ),
    );
    final completionDiff = _diff(
      current.completions.map((e) => MapEntry(e.id, jsonEncode(e.toJson()))),
      imported.snapshot.completions.map(
        (e) => MapEntry(e.id, jsonEncode(e.toJson())),
      ),
    );
    return ImportPreview(
      snapshot: imported.snapshot,
      exportedAt: imported.exportedAt,
      newTasks: taskDiff.newItems,
      newProjects: projectDiff.newItems,
      newCompletions: completionDiff.newItems,
      duplicateCount:
          taskDiff.duplicates +
          projectDiff.duplicates +
          completionDiff.duplicates,
      conflictCount:
          taskDiff.conflicts + projectDiff.conflicts + completionDiff.conflicts,
    );
  }

  Future<AppSnapshot> importBackup(
    String jsonText, {
    ImportMode mode = ImportMode.merge,
  }) async {
    final imported = _decodeBackup(jsonText).snapshot;
    if (mode == ImportMode.replace) {
      await exportBackup();
      await save(imported);
      return imported;
    }
    final current = await load();
    final taskMap = {for (final item in imported.tasks) item.id: item};
    for (final item in current.tasks) {
      taskMap[item.id] = item;
    }
    final projectMap = {for (final item in imported.projects) item.id: item};
    for (final item in current.projects) {
      projectMap[item.id] = item;
    }
    final completionMap = {
      for (final item in imported.completions) item.id: item,
    };
    for (final item in current.completions) {
      completionMap[item.id] = item;
    }
    final merged = AppSnapshot(
      tasks: taskMap.values.toList(),
      projects: projectMap.values.toList(),
      completions: completionMap.values.toList(),
      settings: current.settings,
    );
    await save(merged);
    return merged;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  AppSnapshot _validateSnapshot(AppSnapshot snapshot) {
    try {
      return AppSnapshot.fromJson(snapshot.toJson());
    } on FormatException catch (error) {
      throw BackupValidationException(error.message);
    }
  }

  _DecodedBackup _decodeBackup(String source) {
    try {
      final root = _asObject(jsonDecode(source));
      if (root['format'] != 'yushi.backup' || root['version'] != 1) {
        throw const FormatException('这不是受支持的余时备份文件。');
      }
      final exportedAt = DateTime.tryParse(root['exportedAt'] as String? ?? '');
      if (exportedAt == null) throw const FormatException('备份时间无效。');
      return _DecodedBackup(
        snapshot: AppSnapshot.fromJson(_asObject(root['data'])),
        exportedAt: exportedAt,
      );
    } on FormatException catch (error) {
      throw BackupValidationException(error.message);
    } on TypeError {
      throw const BackupValidationException('备份文件结构无效。');
    }
  }
}

Map<String, dynamic> _asObject(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('备份文件结构无效。');
  }
  return value;
}

class _DecodedBackup {
  const _DecodedBackup({required this.snapshot, required this.exportedAt});
  final AppSnapshot snapshot;
  final DateTime exportedAt;
}

class _Diff {
  const _Diff(this.newItems, this.duplicates, this.conflicts);
  final int newItems;
  final int duplicates;
  final int conflicts;
}

_Diff _diff(
  Iterable<MapEntry<String, String>> current,
  Iterable<MapEntry<String, String>> incoming,
) {
  final existing = Map<String, String>.fromEntries(current);
  var fresh = 0;
  var duplicate = 0;
  var conflict = 0;
  for (final entry in incoming) {
    if (!existing.containsKey(entry.key)) {
      fresh++;
    } else if (existing[entry.key] == entry.value) {
      duplicate++;
    } else {
      conflict++;
    }
  }
  return _Diff(fresh, duplicate, conflict);
}
