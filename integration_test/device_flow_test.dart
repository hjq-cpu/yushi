import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:yushi/app_controller.dart';
import 'package:yushi/data/local_repository.dart';
import 'package:yushi/domain/models.dart';
import 'package:yushi/ui/app.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('真机：记录、项目线索、安排与取消、备份恢复、分享预览', (tester) async {
    final temp = await getTemporaryDirectory();
    final directory = await Directory(
      p.join(temp.path, 'device-qa'),
    ).create(recursive: true);
    final repository = LocalRepository(
      databasePath: p.join(
        directory.path,
        'qa-${DateTime.now().microsecondsSinceEpoch}.sqlite',
      ),
      backupDirectory: directory,
    );
    final controller = AppController(repository);
    await controller.initialize();
    controller.snapshot = controller.snapshot.copyWith(
      settings: const AppSettings(onboardingCompleted: true),
    );
    await repository.save(controller.snapshot);
    addTearDown(() async {
      await repository.close();
      controller.dispose();
    });

    Future<void> settle() async {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
    }

    Future<void> tap(Finder finder) async {
      await settle();
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await settle();
    }

    Future<void> waitFor(bool Function() condition) async {
      for (var i = 0; i < 100 && !condition(); i++) {
        await settle();
      }
      expect(condition(), isTrue, reason: '等待真实存储完成');
    }

    await tester.pumpWidget(YushiApp(controller: controller));
    await settle();

    await tester.enterText(find.byType(TextField), '测试想法：周末试试水彩');
    await tap(find.widgetWithText(TextButton, '记下'));
    await waitFor(() => controller.snapshot.tasks.isNotEmpty);
    expect(controller.snapshot.tasks.single.plannedDate, isNull);
    expect(controller.forDay(DateTime.now()), isEmpty);
    await tap(find.text('放下一件在意的事'));
    await tester.enterText(find.widgetWithText(TextField, '项目名称'), '测试项目：学习绘画');
    await tester.enterText(
      find.widgetWithText(TextField, '为什么在意它（可选）'),
      '观察生活',
    );
    await tap(find.widgetWithText(FilledButton, '创建'));
    await waitFor(() => controller.snapshot.projects.isNotEmpty);
    expect(controller.snapshot.projects, hasLength(1));
    await tap(find.text('打开看看 →'));
    await tester.enterText(find.widgetWithText(TextField, '留下一点进展'), '试了两种颜色');
    await tester.enterText(
      find.widgetWithText(TextField, '下次可以从哪开始（可选）'),
      '看看混色效果',
    );
    await tap(find.text('留下这段记录'));
    await waitFor(
      () => controller.snapshot.projects.single.progress.isNotEmpty,
    );
    await tap(find.byTooltip('关闭项目'));
    expect(controller.snapshot.projects.single.nextStep, '看看混色效果');

    await tap(find.byTooltip('有日期的事'));
    await tap(find.text('记一个约定'));
    await tester.enterText(find.widgetWithText(TextField, '要做什么'), '测试安排：整理画具');

    await tap(find.widgetWithText(FilledButton, '加入计划'));
    await waitFor(() => controller.forDay(DateTime.now()).isNotEmpty);
    expect(controller.forDay(DateTime.now()).single.title, '测试安排：整理画具');
    await tap(find.text('测试安排：整理画具'));
    await tap(find.text('取消安排，保留想法'));
    await waitFor(() => controller.forDay(DateTime.now()).isEmpty);
    expect(controller.snapshot.tasks.last.status, TaskStatus.inbox);
    await tap(find.byTooltip('Back'));

    await tap(find.text('打开看看 →'));
    await tap(find.text('记下相关想法'));
    await tester.enterText(
      find.widgetWithText(TextField, '要做什么'),
      '测试线索：查一下颜料',
    );
    await tap(find.widgetWithText(FilledButton, '记下'));
    await waitFor(() => controller.snapshot.tasks.length == 3);
    expect(
      controller.snapshot.tasks.last.projectId,
      controller.snapshot.projects.single.id,
    );
    expect(controller.snapshot.tasks.last.plannedDate, isNull);
    await tap(find.byTooltip('关闭项目'));

    final today = dateOnly(DateTime.now());
    await controller.addTask(title: '测试分享：骑行', plannedDate: today);
    await controller.addTask(
      title: '测试私密内容',
      plannedDate: today,
      isPrivate: true,
    );
    await settle();
    await tap(find.byTooltip('有日期的事'));
    await tap(find.byTooltip('分享今天'));
    expect(find.text('测试分享：骑行'), findsOneWidget);
    expect(find.text('测试私密内容'), findsNothing);
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('v030-share-device');
    Navigator.of(tester.element(find.byType(PlanPoster))).pop();
    await settle();

    // Exercise Android's real SQLite and filesystem without touching yushi.sqlite.
    final backup = await repository.exportBackup();
    final source = await backup.readAsString();
    final preview = await repository.previewImport(source);
    expect(preview.newProjects, 0);
    await repository.close();
    await controller.reloadFromStorage();
    expect(controller.snapshot.projects.single.lastProgress, '试了两种颜色');
    expect(controller.snapshot.tasks, hasLength(5));
    await repository.save(AppSnapshot.empty());
    await controller.applyImport(source, ImportMode.merge);
    expect(controller.snapshot.projects.single.nextStep, '看看混色效果');
    expect(controller.snapshot.tasks, hasLength(5));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
