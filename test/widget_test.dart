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
}
