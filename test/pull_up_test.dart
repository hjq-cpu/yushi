import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yushi/ui/app.dart';

Widget _pullUpHarness({required ValueChanged<int> add}) => MaterialApp(
  home: Scaffold(
    body: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [SizedBox(height: 48, child: Text('内容事项'))],
    ),
    bottomNavigationBar: PullUpToAdd(
      onAdd: () async => add(1),
      child: NavigationBar(
        destinations: [
          NavigationDestination(icon: Icon(Icons.list), label: '待办'),
          NavigationDestination(icon: Icon(Icons.folder), label: '项目'),
        ],
      ),
    ),
  ),
);

void main() {
  testWidgets('底部导航上拉后只在释放时打开一次', (tester) async {
    var opened = 0;
    await tester.pumpWidget(_pullUpHarness(add: (value) => opened += value));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(NavigationBar)),
    );
    await gesture.moveBy(const Offset(0, -140));
    await tester.pump();
    expect(opened, 0);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('小于阈值、反向取消和内容列表上拉都不会打开', (tester) async {
    var opened = 0;
    await tester.pumpWidget(_pullUpHarness(add: (value) => opened += value));
    await tester.pumpAndSettle();

    final short = await tester.startGesture(
      tester.getCenter(find.byType(NavigationBar)),
    );
    await short.moveBy(const Offset(0, -40));
    await short.up();
    await tester.pumpAndSettle();
    expect(opened, 0);

    final reverse = await tester.startGesture(
      tester.getCenter(find.byType(NavigationBar)),
    );
    await reverse.moveBy(const Offset(0, -100));
    await reverse.moveBy(const Offset(0, 60));
    await reverse.up();
    await tester.pumpAndSettle();
    expect(opened, 0);

    await tester.drag(find.byType(ListView), const Offset(0, -160));
    await tester.pumpAndSettle();
    expect(opened, 0);
    expect(tester.takeException(), isNull);
  });
}
