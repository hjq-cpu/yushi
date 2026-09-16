import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yushi/app_controller.dart';
import 'package:yushi/data/local_repository.dart';
import 'package:yushi/domain/models.dart';
import 'package:yushi/ui/app.dart';

void main() {
  testWidgets('首页不展示排期格子，项目留下的过程进入足迹', (tester) async {
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
    expect(find.text('此刻，随你。'), findsOneWidget);
    await tester.tap(find.text('打开看看 →'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '留下一点进展'), '试了两种颜色');
    await tester.enterText(
      find.widgetWithText(TextField, '下次可以从哪开始（可选）'),
      '看看混色效果',
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('留下这段记录'));
      for (
        var i = 0;
        i < 100 && controller.snapshot.projects.single.progress.isEmpty;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    expect(controller.snapshot.projects.single.progress.single.text, '试了两种颜色');
    await tester.tap(find.byTooltip('关闭项目'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('足迹'));
    await tester.pumpAndSettle();
    expect(find.text('试了两种颜色'), findsOneWidget);
    expect(find.text('完成率'), findsNothing);
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
    expect(find.text('记一个约定'), findsOneWidget);
    expect(find.text('去骑行'), findsOneWidget);
    expect(find.textContaining('无安排 · 点击添加'), findsNothing);
    await tester.tap(find.text('去骑行'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('取消安排，保留想法'));
    await tester.runAsync(() async {
      await tester.tap(find.text('取消安排，保留想法'));
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
    expect(find.text('这段时间没有注明日期的事。'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(repository.close);
    controller.dispose();
  });
}
