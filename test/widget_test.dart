import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yushi/app_controller.dart';
import 'package:yushi/data/local_repository.dart';
import 'package:yushi/domain/models.dart';
import 'package:yushi/ui/app.dart';

Widget _appWithoutIntroduction(AppController controller) {
  controller.snapshot = controller.snapshot.copyWith(
    settings: controller.snapshot.settings.copyWith(onboardingCompleted: true),
  );
  return YushiApp(controller: controller);
}

void main() {
  testWidgets('理念偏好保存后重新启动不再提示', (tester) async {
    sqfliteFfiInit();
    final repository = LocalRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    await tester.runAsync(() => repository.save(AppSnapshot.empty()));
    final controller = AppController(repository)..loading = false;
    await tester.pumpWidget(YushiApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.text('给在意的事，留一点时间'), findsOneWidget);
    await tester.tap(find.text('开始使用'));
    await tester.pumpAndSettle();
    expect(controller.snapshot.settings.onboardingCompleted, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(YushiApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('以后不再提示'));
    await tester.tap(find.text('以后不再提示'));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('开始使用'));
      for (
        var i = 0;
        i < 100 && !controller.snapshot.settings.onboardingCompleted;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    final restored = AppController(repository);
    await tester.runAsync(restored.initialize);
    expect(restored.snapshot.settings.onboardingCompleted, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(YushiApp(controller: restored));
    await tester.pumpAndSettle();
    expect(find.text('给在意的事，留一点时间'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(repository.close);
  });
  testWidgets('计划长图包含全部事项及底部品牌', (tester) async {
    sqfliteFfiInit();
    final controller = AppController(
      LocalRepository(databaseFactory: databaseFactoryFfi),
    );
    final now = DateTime.now();
    final tasks = List.generate(
      30,
      (i) => TaskItem(
        id: 'poster-$i',
        title: '今日事项 ${i + 1}',
        createdAt: now,
        updatedAt: now,
      ),
    );
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 360,
                child: PlanPoster(
                  controller: controller,
                  tasks: tasks,
                  includeTimes: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('今日事项 30'), findsOneWidget);
    expect(find.text('余时'), findsOneWidget);
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final rendered = await boundary.toImage();
    expect(rendered.height, greaterThan(2000));
    expect(rendered.height, boundary.size.height.ceil());
    rendered.dispose();
    expect(tester.takeException(), isNull);
  });
  testWidgets('首页呈现待办与快速记录', (tester) async {
    sqfliteFfiInit();
    final repository = LocalRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    final controller = AppController(repository);
    controller.loading = false;

    await tester.pumpWidget(_appWithoutIntroduction(controller));
    await tester.pump();

    expect(find.text('一件一件，慢慢来。'), findsOneWidget);
    expect(find.widgetWithText(TextField, '想到什么，先记下来…'), findsOneWidget);
    expect(find.text('待办'), findsWidgets);
  });

  testWidgets('创建项目后安全关闭弹窗并显示项目', (tester) async {
    sqfliteFfiInit();
    final repository = LocalRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    final controller = AppController(repository)..loading = false;

    await tester.pumpWidget(_appWithoutIntroduction(controller));
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

    await tester.pumpWidget(_appWithoutIntroduction(controller));
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
