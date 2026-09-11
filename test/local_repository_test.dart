import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yushi/data/local_repository.dart';
import 'package:yushi/domain/models.dart';

void main() {
  late Directory temporary;
  late LocalRepository repository;

  setUp(() async {
    sqfliteFfiInit();
    temporary = await Directory.systemTemp.createTemp('yushi-test-');
    repository = LocalRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
      backupDirectory: temporary,
    );
  });

  tearDown(() async {
    await repository.close();
    await temporary.delete(recursive: true);
  });

  test('备份可导出、预览并合并且不重复', () async {
    final now = DateTime(2026, 9, 11, 10);
    final snapshot = AppSnapshot(
      tasks: [
        TaskItem(
          id: 'task-1',
          title: '骑行 30 分钟',
          status: TaskStatus.planned,
          plannedDate: now,
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );
    await repository.save(snapshot);
    final backup = await repository.exportBackup();
    final source = await backup.readAsString();
    final preview = await repository.previewImport(source);

    expect(preview.newTasks, 0);
    expect(preview.duplicateCount, 1);
    final imported = await repository.importBackup(source);
    expect(imported.tasks, hasLength(1));
  });

  test('损坏或版本不支持的备份不会改动本地数据', () async {
    final source = jsonEncode({
      'format': 'yushi.backup',
      'version': 99,
      'exportedAt': DateTime.now().toIso8601String(),
      'data': {},
    });

    expect(
      () => repository.previewImport(source),
      throwsA(isA<BackupValidationException>()),
    );
    expect((await repository.load()).tasks, isEmpty);
  });
}
