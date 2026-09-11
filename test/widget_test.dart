import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yushi/app_controller.dart';
import 'package:yushi/data/local_repository.dart';
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
    await tester.pumpAndSettle();
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
}
