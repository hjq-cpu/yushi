import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yushi/app_controller.dart';
import 'package:yushi/data/local_repository.dart';
import 'package:yushi/domain/models.dart';

void main() {
  test('旧完成记录迁移一次，重复任务历史保留，显式状态不再受日期影响', () {
    final date = DateTime(2020, 1, 1);
    final task = TaskItem(
      id: 'old',
      title: '旧事项',
      createdAt: date,
      updatedAt: date,
    );
    final json = AppSnapshot(
      tasks: [task],
      completions: [
        CompletionEntry(taskId: task.id, date: date, updatedAt: date),
      ],
    ).toJson();
    (json['tasks'] as List).single.remove('phase');
    final migrated = AppSnapshot.fromJson(json);
    expect(migrated.tasks.single.phase, TaskPhase.completed);
    expect(
      AppSnapshot.fromJson(migrated.toJson()).tasks.single.phase,
      TaskPhase.completed,
    );
    (json['tasks'] as List).single['recurrence'] = const RecurrenceRule(
      type: RecurrenceType.daily,
    ).toJson();
    final repeated = AppSnapshot.fromJson(json);
    expect(repeated.tasks.single.phase, TaskPhase.pending);
    expect(repeated.completions, hasLength(1));
    (json['tasks'] as List).single['phase'] = 'doing';
    expect(AppSnapshot.fromJson(json).tasks.single.phase, TaskPhase.doing);
  });

  test('开始、改日期、放下、归档恢复和跨天完成均保持持久状态', () async {
    sqfliteFfiInit();
    final repo = LocalRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    final c = AppController(repo);
    await c.initialize();
    await c.addTask(
      title: '持续的事情',
      plannedDate: DateTime(2020),
      deadline: DateTime(2030),
    );
    expect(c.openTasks.single.phase, TaskPhase.pending);
    await c.setPhase(c.openTasks.single, TaskPhase.doing);
    await c.postpone(c.openTasks.single, DateTime(2035));
    await c.reloadFromStorage();
    expect(c.openTasks.single.phase, TaskPhase.doing);
    await c.unschedule(c.openTasks.single);
    expect(c.openTasks.single.phase, TaskPhase.doing);
    expect(c.openTasks.single.deadline, DateTime(2030));
    await c.archiveTask(c.openTasks.single);
    expect(c.openTasks, isEmpty);
    await c.restoreTask(c.snapshot.tasks.single);
    expect(c.openTasks.single.phase, TaskPhase.doing);
    await c.setPhase(c.openTasks.single, TaskPhase.pending);
    await c.toggleComplete(c.openTasks.single, DateTime(2020));
    await c.reloadFromStorage();
    expect(c.openTasks, isEmpty);
    expect(c.completed(c.snapshot.tasks.single, DateTime(2050)), isTrue);
    await c.toggleComplete(c.snapshot.tasks.single, DateTime(2050));
    expect(c.openTasks.single.phase, TaskPhase.pending);
    expect(c.snapshot.completions, isEmpty);
    await repo.close();
    c.dispose();
  });
}
