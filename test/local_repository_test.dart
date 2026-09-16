import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yushi/data/local_repository.dart';
import 'package:yushi/domain/models.dart';
import 'package:yushi/app_controller.dart';

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

  test('无日期记录不会进入今天，取消安排保留内容和真实截止日', () async {
    final controller = AppController(repository);
    await controller.initialize();
    final now = DateTime.now();
    await controller.addTask(title: '试试新的想法', note: '先查资料');
    expect(controller.snapshot.tasks.single.plannedDate, isNull);
    expect(controller.snapshot.tasks.single.estimateMins, 0);
    expect(controller.forDay(now), isEmpty);
    await controller.postpone(controller.snapshot.tasks.single, now);
    expect(controller.forDay(now), hasLength(1));
    await controller.unschedule(controller.snapshot.tasks.single);
    expect(controller.forDay(now), isEmpty);
    expect((await repository.load()).tasks.single.note, '先查资料');
    await controller.addTask(
      title: '有真实期限',
      plannedDate: now,
      deadline: now.add(const Duration(days: 10)),
      recurrence: const RecurrenceRule(type: RecurrenceType.daily),
    );
    final scheduled = controller.snapshot.tasks.last;
    await controller.unschedule(scheduled);
    final restored = (await repository.load()).tasks.last;
    expect(restored.deadline, scheduled.deadline);
    expect(restored.recurrence.type, RecurrenceType.none);
    controller.dispose();
  });

  test('旧备份可读取，项目线索在备份导入及重启后保留', () async {
    final now = DateTime.now();
    final project = ProjectItem(
      id: 'p',
      title: '余时',
      lastProgress: '整理了首页',
      nextStep: '试用记录入口',
      createdAt: now,
      updatedAt: now,
    );
    final old = project.toJson()
      ..remove('lastProgress')
      ..remove('nextStep')
      ..remove('progress');
    expect(ProjectItem.fromJson(old).lastProgress, isEmpty);
    expect(ProjectItem.fromJson(old).nextStep, isEmpty);
    expect(ProjectItem.fromJson(old).progress, isEmpty);
    await repository.save(AppSnapshot(projects: [project]));
    final file = await repository.exportBackup();
    final source = await file.readAsString();
    await repository.save(AppSnapshot.empty());
    await repository.importBackup(source);
    final loaded = await repository.load();
    expect(loaded.projects.single.lastProgress, project.lastProgress);
    expect(loaded.projects.single.nextStep, project.nextStep);
  });

  test('无日期事项隔天可以撤销完成并重新出现在想法里', () async {
    final controller = AppController(repository);
    await controller.initialize();
    await controller.addInbox('试着画一张');
    final task = controller.snapshot.tasks.single;
    final yesterday = dateOnly(
      DateTime.now(),
    ).subtract(const Duration(days: 1));
    await controller.toggleComplete(task, yesterday);
    expect(controller.completed(task, DateTime.now()), isTrue);
    await controller.toggleComplete(task, DateTime.now());
    expect(controller.completed(task, DateTime.now()), isFalse);
    expect(controller.snapshot.completions, isEmpty);
    expect((await repository.load()).tasks.single.status, TaskStatus.inbox);
    controller.dispose();
  });

  test('项目进展连续追加，旧上下文与新足迹均可从备份恢复', () async {
    final now = DateTime.now();
    final original = ProjectItem(
      id: 'journal-project',
      title: '绘画',
      lastProgress: '旧版的起点',
      createdAt: now,
      updatedAt: now,
    );
    await repository.save(AppSnapshot(projects: [original]));
    final controller = AppController(repository);
    await controller.initialize();
    await controller.leaveProgress(original.id, '尝试了混色', '画一片叶子');
    await controller.leaveProgress(original.id, '发现纸张吸水太快', '换一种纸');
    await controller.leaveProgress(original.id, '', '下次再试');
    final project = controller.snapshot.projects.single;
    expect(project.progress.map((p) => p.text), ['旧版的起点', '尝试了混色', '发现纸张吸水太快']);
    expect(project.lastProgress, '发现纸张吸水太快');
    expect(project.nextStep, '下次再试');
    final backup = await repository.exportBackup();
    final source = await backup.readAsString();
    await repository.save(AppSnapshot.empty());
    await controller.applyImport(source, ImportMode.merge);
    expect(controller.snapshot.projects.single.progress, hasLength(3));
    controller.dispose();
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
