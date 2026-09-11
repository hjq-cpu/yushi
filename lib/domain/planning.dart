import 'models.dart';

export 'models.dart' show dateOnly, dateKey, isSameDay;

CompletionEntry? completionForDay(
  AppSnapshot snapshot,
  String taskId,
  DateTime day,
) {
  for (final entry in snapshot.completions) {
    if (entry.taskId == taskId && isSameDay(entry.date, day)) return entry;
  }
  return null;
}

bool isTaskCompleted(AppSnapshot snapshot, TaskItem task, DateTime day) {
  if (task.recurrence.type == RecurrenceType.none) {
    return snapshot.completions.any(
      (entry) =>
          entry.taskId == task.id &&
          entry.status == CompletionStatus.completed &&
          !dateOnly(entry.date).isAfter(dateOnly(day)),
    );
  }
  return completionForDay(snapshot, task.id, day)?.status ==
      CompletionStatus.completed;
}

DateTime weekStart(DateTime day, {int startsOn = DateTime.monday}) {
  final normalized = dateOnly(day);
  return DateTime(
    normalized.year,
    normalized.month,
    normalized.day - ((normalized.weekday - startsOn + 7) % 7),
  );
}

int weeklyCompletionCount(AppSnapshot snapshot, String taskId, DateTime day) {
  final start = weekStart(day, startsOn: snapshot.settings.weekStartsOn);
  final end = DateTime(start.year, start.month, start.day + 7);
  return snapshot.completions
      .where(
        (entry) =>
            entry.taskId == taskId &&
            entry.status == CompletionStatus.completed &&
            !dateOnly(entry.date).isBefore(start) &&
            dateOnly(entry.date).isBefore(end),
      )
      .map((entry) => dateKey(entry.date))
      .toSet()
      .length;
}

bool _eligible(AppSnapshot snapshot, TaskItem task) {
  if (task.status != TaskStatus.active && task.status != TaskStatus.planned) {
    return false;
  }
  if (task.projectId == null) return true;
  return snapshot.projects.any(
    (project) =>
        project.id == task.projectId && project.status == ProjectStatus.active,
  );
}

bool _dueOn(AppSnapshot snapshot, TaskItem task, DateTime day) {
  final planned = task.plannedDate;
  final current = dateOnly(day);
  if (planned != null && dateOnly(planned).isAfter(current)) return false;
  if (dateOnly(task.createdAt).isAfter(current)) return false;
  final entry = completionForDay(snapshot, task.id, current);
  // Keep today's completion visible even when it reaches the weekly target.
  if (entry != null) return true;
  switch (task.recurrence.type) {
    case RecurrenceType.none:
      return planned != null &&
          isSameDay(planned, current) &&
          !isTaskCompleted(snapshot, task, current);
    case RecurrenceType.daily:
      return true;
    case RecurrenceType.weekdays:
      return current.weekday <= DateTime.friday;
    case RecurrenceType.selectedWeekdays:
      return task.recurrence.weekdays.contains(current.weekday);
    case RecurrenceType.weeklyTarget:
      return weeklyCompletionCount(snapshot, task.id, current) <
          task.recurrence.weeklyTarget;
  }
}

List<TaskItem> tasksForDay(AppSnapshot snapshot, DateTime day) {
  final tasks = snapshot.tasks
      .where((task) => _eligible(snapshot, task) && _dueOn(snapshot, task, day))
      .toList();
  tasks.sort((a, b) {
    if (a.isFocus != b.isFocus) return a.isFocus ? -1 : 1;
    final byTime = (a.timeMinutes ?? 1440).compareTo(b.timeMinutes ?? 1440);
    if (byTime != 0) return byTime;
    final byCreation = a.createdAt.compareTo(b.createdAt);
    return byCreation != 0 ? byCreation : a.id.compareTo(b.id);
  });
  return tasks;
}

List<TaskItem> pendingAdjustments(AppSnapshot snapshot, DateTime day) {
  final current = dateOnly(day);
  final tasks = snapshot.tasks
      .where(
        (task) =>
            _eligible(snapshot, task) &&
            task.recurrence.type == RecurrenceType.none &&
            task.plannedDate != null &&
            dateOnly(task.plannedDate!).isBefore(current) &&
            !isTaskCompleted(snapshot, task, current),
      )
      .toList();
  tasks.sort((a, b) => a.plannedDate!.compareTo(b.plannedDate!));
  return tasks;
}

TaskItem? focusTaskForDay(AppSnapshot snapshot, DateTime day) {
  for (final task in tasksForDay(snapshot, day)) {
    final entry = completionForDay(snapshot, task.id, day);
    if (entry == null && !isTaskCompleted(snapshot, task, day)) return task;
  }
  return null;
}
