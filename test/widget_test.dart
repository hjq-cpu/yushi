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
  testWidgets('节奏页支持月份切换和返回本月', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    sqfliteFfiInit();
    final controller = AppController(
      LocalRepository(databaseFactory: databaseFactoryFfi),
    )..loading = false;
    final today = DateTime.now();
    await tester.pumpWidget(_appWithoutIntroduction(controller));
    await tester.tap(find.text('节奏'));
    await tester.pumpAndSettle();
    expect(find.textContaining('有安排，'), findsOneWidget);
    expect(find.text('先看真实可用的时间，再决定把这一周交给什么。'), findsOneWidget);
    expect(tester.getSize(find.text('周')).width, lessThan(40));
    await tester.tap(find.text('月'));
    await tester.pumpAndSettle();
    expect(find.text('${today.year} 年 ${today.month} 月'), findsOneWidget);
    expect(find.text('添加本月事项'), findsOneWidget);

    // Navigate through a full year, including February and the year boundary.
    for (var offset = 1; offset <= 13; offset++) {
      await tester.tap(find.byTooltip('上一月'));
      await tester.pumpAndSettle();
      final month = DateTime(today.year, today.month - offset);
      final days = DateTime(month.year, month.month + 1, 0).day;
      expect(find.text('${month.year} 年 ${month.month} 月'), findsOneWidget);
      expect(
        find.byKey(
          ValueKey(
            'calendar-${dateKey(DateTime(month.year, month.month, days))}',
          ),
        ),
        findsOneWidget,
      );
    }
    await tester.tap(find.byTooltip('下一月'));
    await tester.pumpAndSettle();
    final previousYear = DateTime(today.year, today.month - 12);
    expect(
      find.text('${previousYear.year} 年 ${previousYear.month} 月'),
      findsOneWidget,
    );
    await tester.tap(find.text('本月'));
    await tester.pumpAndSettle();
    expect(find.text('${today.year} 年 ${today.month} 月'), findsOneWidget);
    await tester.tap(find.text('周'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('上一周'));
    await tester.pumpAndSettle();
    expect(find.text('添加此周事项'), findsOneWidget);
    await tester.tap(find.text('本周'));
    await tester.pumpAndSettle();
    expect(find.text('添加本周事项'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('月历选择日期只展示当天事项', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    sqfliteFfiInit();
    final controller = AppController(
      LocalRepository(databaseFactory: databaseFactoryFfi),
    )..loading = false;
    final now = DateTime.now();
    final first = DateTime(now.year, now.month);
    final second = DateTime(now.year, now.month, 2);
    controller.snapshot = controller.snapshot.copyWith(
      tasks: [
        for (final day in [first, second])
          TaskItem(
            id: 'calendar-${day.day}',
            title: '月历事项${day.day}',
            status: TaskStatus.planned,
            plannedDate: day,
            createdAt: first,
            updatedAt: first,
          ),
      ],
    );
    await tester.pumpWidget(_appWithoutIntroduction(controller));
    await tester.tap(find.text('节奏'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('月'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('calendar-${dateKey(first)}')));
    await tester.pumpAndSettle();
    expect(find.text('月历事项1'), findsOneWidget);
    expect(find.text('月历事项2'), findsNothing);
    await tester.tap(find.byKey(ValueKey('calendar-${dateKey(second)}')));
    await tester.pumpAndSettle();
    expect(find.text('月历事项1'), findsNothing);
    expect(find.text('月历事项2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('节奏页可以分析当前周', (tester) async {
    sqfliteFfiInit();
    final repository = LocalRepository(databaseFactory: databaseFactoryFfi);
    final controller = AppController(repository)..loading = false;
    final today = dateOnly(DateTime.now());
    final task = TaskItem(
      id: 'weekly-analysis-task',
      title: '完成周分析',
      status: TaskStatus.planned,
      plannedDate: today,
      createdAt: today,
      updatedAt: today,
    );
    controller.snapshot = controller.snapshot.copyWith(
      tasks: [task],
      completions: [
        CompletionEntry(taskId: task.id, date: today, updatedAt: today),
      ],
    );

    await tester.pumpWidget(_appWithoutIntroduction(controller));
    await tester.tap(find.text('节奏'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('分析本周'));
    await tester.pumpAndSettle();

    expect(find.text('本周分析'), findsOneWidget);
    expect(find.text('安排次数'), findsOneWidget);
    expect(find.text('完成次数'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('留白 6 天'), findsOneWidget);
    expect(find.textContaining('完成 1 项'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
    await tester.tap(find.text('开始今天'));
    await tester.pumpAndSettle();
    expect(controller.snapshot.settings.onboardingCompleted, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(YushiApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('以后不再提示'));
    await tester.tap(find.text('以后不再提示'));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('开始今天'));
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
  testWidgets('首页首先呈现今天和快速记录', (tester) async {
    sqfliteFfiInit();
    final repository = LocalRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    final controller = AppController(repository);
    controller.loading = false;

    await tester.pumpWidget(_appWithoutIntroduction(controller));
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

  testWidgets('节奏页点击日期可添加并显示事项', (tester) async {
    sqfliteFfiInit();
    final repository = LocalRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    await tester.runAsync(() => repository.save(AppSnapshot.empty()));
    final controller = AppController(repository)..loading = false;

    await tester.pumpWidget(_appWithoutIntroduction(controller));
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

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('周末骑行'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('周末骑行'));
    await tester.pumpAndSettle();
    expect(find.text('标记完成'), findsOneWidget);
    await tester.tap(find.text('永久删除'));
    await tester.pumpAndSettle();
    expect(find.text('永久删除“周末骑行”？'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '永久删除'));
    await tester.pump();
    await tester.runAsync(() async {
      for (var i = 0; i < 100 && controller.snapshot.tasks.isNotEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    expect(controller.snapshot.tasks, isEmpty);
    expect(find.text('周末骑行'), findsNothing);
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
