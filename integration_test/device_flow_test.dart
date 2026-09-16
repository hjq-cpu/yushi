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

  testWidgets('真机：待办、在做、完成撤销、重载、分享与备份', (tester) async {
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

    await tester.enterText(
      find.widgetWithText(TextField, '想到什么，先记下来…'),
      '测试事项：周末试试水彩',
    );
    await tap(find.widgetWithText(TextButton, '记下'));
    await waitFor(() => controller.snapshot.tasks.isNotEmpty);
    expect(controller.snapshot.tasks.single.phase, TaskPhase.pending);
    await tap(find.text('测试事项：周末试试水彩'));
    await tap(find.text('开始做'));
    await waitFor(
      () => controller.snapshot.tasks.single.phase == TaskPhase.doing,
    );
    await controller.reloadFromStorage();
    expect(controller.snapshot.tasks.single.phase, TaskPhase.doing);
    await tap(find.byTooltip('完成事项'));
    await waitFor(() => controller.openTasks.isEmpty);
    await tap(find.text('完成记录'));
    await tap(find.byTooltip('撤销完成'));
    await waitFor(() => controller.openTasks.isNotEmpty);
    await tap(find.byTooltip('Back'));
    await tap(find.byTooltip('分享待办'));
    expect(find.text('测试事项：周末试试水彩'), findsOneWidget);
    final backup = await repository.exportBackup();
    final restored = await repository.importBackup(await backup.readAsString());
    expect(restored.tasks.single.phase, TaskPhase.pending);
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('persistent-todo-share');
    expect(tester.takeException(), isNull);
  });
}
