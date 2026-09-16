import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yushi/app_controller.dart';
import 'package:yushi/data/local_repository.dart';
import 'package:yushi/domain/models.dart';
import 'package:yushi/ui/app.dart';

void main() {
  testWidgets('首页展示持久事项，搜索过滤，完成后移入记录', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    sqfliteFfiInit();
    final repository = LocalRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    final controller = AppController(repository);
    await tester.runAsync(() async {
      await controller.initialize();
      await controller.addProject('绘画', '喜欢颜色');
      await controller.dismissIntroductionPermanently();
    });
    await tester.pumpWidget(YushiApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.text('节奏'), findsNothing);
    expect(find.text('今天的安排'), findsNothing);
    expect(find.text('一件一件，慢慢来。'), findsOneWidget);
    await tester.runAsync(() async {
      await controller.addTask(
        title: '画一张速写',
        projectId: controller.snapshot.projects.single.id,
      );
      await controller.setPhase(
        controller.snapshot.tasks.single,
        TaskPhase.doing,
      );
    });
    await tester.pumpAndSettle();
    expect(find.text('画一张速写'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '搜索事项'), '不存在');
    await tester.pumpAndSettle();
    expect(find.text('画一张速写'), findsNothing);
    await tester.enterText(find.widgetWithText(TextField, '搜索事项'), '');
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await controller.toggleComplete(
        controller.snapshot.tasks.single,
        DateTime.now(),
      );
    });
    await tester.pumpAndSettle();
    expect(find.text('画一张速写'), findsNothing);
    await tester.tap(find.text('完成记录'));
    await tester.pumpAndSettle();
    expect(find.text('画一张速写'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(repository.close);
    controller.dispose();
  });

  testWidgets('日期作为独立入口，只展示有安排的日子，并能取消安排', (tester) async {
    sqfliteFfiInit();
    final repository = LocalRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    final controller = AppController(repository);
    await tester.runAsync(() async {
      await controller.initialize();
      await controller.dismissIntroductionPermanently();
      await controller.addTask(title: '去骑行', plannedDate: DateTime.now());
    });
    await tester.pumpWidget(YushiApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('有日期的事'));
    await tester.pumpAndSettle();
    expect(find.text('日期是一条信息，不改变事项的状态。'), findsOneWidget);
    expect(find.text('去骑行'), findsOneWidget);
    expect(find.textContaining('无安排 · 点击添加'), findsNothing);
    await tester.tap(find.text('去骑行'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('移除约定日期'));
    await tester.runAsync(() async {
      await tester.tap(find.text('移除约定日期'));
      for (
        var i = 0;
        i < 100 && controller.snapshot.tasks.single.plannedDate != null;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    expect(controller.snapshot.tasks.single.status, TaskStatus.inbox);
    expect(find.text('去骑行'), findsNothing);
    expect(find.text('还没有注明约定或截止日期的事项。'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(repository.close);
    controller.dispose();
  });
}
