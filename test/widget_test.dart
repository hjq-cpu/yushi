import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yushi/app_controller.dart';
import 'package:yushi/data/local_repository.dart';
import 'package:yushi/domain/models.dart';
import 'package:yushi/ui/app.dart';

void main() {
  testWidgets('首页首先呈现今天和快速记录', (tester) async {
    sqfliteFfiInit();
    final repository = LocalRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    final controller = AppController(repository);
    controller.loading = false;

    await tester.pumpWidget(YushiApp(controller: controller));
    await tester.pump();

    expect(find.textContaining('把时间留给'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('今天'), findsOneWidget);
  });

  testWidgets('创建项目后安全关闭弹窗并显示项目', (tester) async {
    sqfliteFfiInit();
    final repository = LocalRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    final controller = AppController(repository)..loading = false;

    await tester.pumpWidget(YushiApp(controller: controller));
    await tester.tap(find.text('项目'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('新建项目'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.first, '骑行计划');
    await tester.enterText(fields.last, '让身体和注意力重新流动');
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();

    expect(find.text('骑行计划'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await repository.close();
  });

  testWidgets('节奏页点击日期可添加并显示事项', (tester) async {
    sqfliteFfiInit();
    final repository = LocalRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    await tester.runAsync(() => repository.save(AppSnapshot.empty()));
    final controller = AppController(repository)..loading = false;

    await tester.pumpWidget(YushiApp(controller: controller));
    await tester.tap(find.text('节奏'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加本周事项'));
    await tester.pumpAndSettle();

    expect(find.text('安排一件具体的事'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '周末骑行');
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller?.text,
      '周末骑行',
    );
    await tester.tap(find.widgetWithText(FilledButton, '加入计划'));
    await tester.pump();
    expect(find.text('保存中…'), findsOneWidget);
    await tester.runAsync(() async {
      for (var i = 0; i < 100 && controller.snapshot.tasks.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();

    expect(controller.snapshot.tasks.single.title, '周末骑行');
    expect(find.text('安排一件具体的事'), findsNothing);
    expect(find.textContaining('已加入'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.runAsync(repository.close);
  });

  testWidgets('归档项目后移入归档区并可恢复', (tester) async {
    sqfliteFfiInit();
    final repository = LocalRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    final now = DateTime(2026, 9, 11);
    final project = ProjectItem(
      id: 'project-archive',
      title: '旧项目',
      createdAt: now,
      updatedAt: now,
    );
    final task = TaskItem(
      id: 'task-in-project',
      title: '旧任务',
      projectId: project.id,
      status: TaskStatus.planned,
      plannedDate: now,
      createdAt: now,
      updatedAt: now,
    );
    final completion = CompletionEntry(
      taskId: task.id,
      date: now,
      updatedAt: now,
    );
    final snapshot = AppSnapshot(
      projects: [project],
      tasks: [task],
      completions: [completion],
    );
    await tester.runAsync(() => repository.save(snapshot));
    final controller = AppController(repository)
      ..snapshot = snapshot
      ..loading = false;

    await tester.pumpWidget(YushiApp(controller: controller));
    await tester.tap(find.text('项目'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('管理项目'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('归档'));
    await tester.pump();
    await tester.runAsync(() async {
      for (
        var i = 0;
        i < 100 &&
            controller.snapshot.projects.single.status !=
                ProjectStatus.archived;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();

    expect(controller.snapshot.projects.single.status, ProjectStatus.archived);
    expect(find.text('已归档项目（1）'), findsOneWidget);
    expect(find.textContaining('项目已归档'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('已归档项目（1）'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('管理已归档项目'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('永久删除'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 条任务和 1 条完成记录'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '永久删除'));
    await tester.pump();
    await tester.runAsync(() async {
      for (var i = 0; i < 100 && controller.snapshot.projects.isNotEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();

    expect(controller.snapshot.projects, isEmpty);
    expect(controller.snapshot.tasks, isEmpty);
    expect(controller.snapshot.completions, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.runAsync(repository.close);
  });
}
