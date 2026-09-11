import 'package:flutter_test/flutter_test.dart';
import 'package:yushi/domain/models.dart';
import 'package:yushi/domain/planning.dart';

void main() {
  TaskItem task({
    required String id,
    required DateTime planned,
    RecurrenceRule recurrence = const RecurrenceRule(),
  }) => TaskItem(
    id: id,
    title: id,
    status: TaskStatus.planned,
    plannedDate: planned,
    recurrence: recurrence,
    createdAt: planned,
    updatedAt: planned,
  );

  test('未完成事项不会自动滚入第二天', () {
    final monday = DateTime(2026, 9, 7);
    final snapshot = AppSnapshot(
      tasks: [task(id: 'one', planned: monday)],
    );

    expect(tasksForDay(snapshot, monday), hasLength(1));
    expect(tasksForDay(snapshot, monday.add(const Duration(days: 1))), isEmpty);
    expect(
      pendingAdjustments(snapshot, monday.add(const Duration(days: 1))),
      hasLength(1),
    );
  });

  test('每周次数只计算当前周并且不结转欠账', () {
    final monday = DateTime(2026, 9, 7);
    final ride = task(
      id: 'ride',
      planned: monday.subtract(const Duration(days: 14)),
      recurrence: const RecurrenceRule(
        type: RecurrenceType.weeklyTarget,
        weeklyTarget: 2,
      ),
    );
    final snapshot = AppSnapshot(
      tasks: [ride],
      completions: [
        CompletionEntry(
          taskId: 'ride',
          date: monday.subtract(const Duration(days: 1)),
          updatedAt: monday,
        ),
        CompletionEntry(taskId: 'ride', date: monday, updatedAt: monday),
      ],
    );

    expect(weeklyCompletionCount(snapshot, 'ride', monday), 1);
    expect(
      tasksForDay(snapshot, monday.add(const Duration(days: 1))),
      hasLength(1),
    );
  });
}
