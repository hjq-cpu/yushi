import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yushi/app_controller.dart';
import 'package:yushi/data/local_repository.dart';
import 'package:yushi/domain/models.dart';
import 'package:yushi/ui/app.dart';

void main() {
  testWidgets('系统切换时首页和已打开的详情同步变化，分享画布保持浅色', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 940));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final c = AppController(
      LocalRepository(databaseFactory: databaseFactoryFfi),
    )..loading = false;
    final now = DateTime.now();
    c.snapshot = AppSnapshot(
      settings: const AppSettings(onboardingCompleted: true),
      tasks: [
        TaskItem(id: 'test', title: '测试深色事项', createdAt: now, updatedAt: now),
      ],
    );
    addTearDown(c.dispose);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpWidget(YushiApp(controller: c));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byTooltip('搜索事项'))).brightness,
      Brightness.light,
    );
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    final dark = Theme.of(tester.element(find.byTooltip('搜索事项')));
    expect(dark.brightness, Brightness.dark);
    expect(dark.scaffoldBackgroundColor.computeLuminance(), lessThan(0.05));
    expect(
      dark.textTheme.bodyLarge!.color!.computeLuminance(),
      greaterThan(0.6),
    );
    await tester.ensureVisible(find.text('测试深色事项'));
    await tester.tap(find.text('测试深色事项'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('开始做'))).brightness,
      Brightness.dark,
    );
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('开始做'))).brightness,
      Brightness.light,
    );
    await tester.tap(find.byTooltip('关闭事项详情'));
    await tester.pumpAndSettle();
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('分享待办'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('分享我的待办'))).brightness,
      Brightness.dark,
    );
    expect(
      Theme.of(tester.element(find.text('我的待办'))).brightness,
      Brightness.light,
    );
    expect(tester.takeException(), isNull);
  });
}
