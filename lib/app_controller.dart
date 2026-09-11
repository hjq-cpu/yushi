import 'package:flutter/foundation.dart';

import 'data/local_repository.dart';
import 'domain/models.dart';
import 'domain/planning.dart';

class AppController extends ChangeNotifier {
  AppController(this.repository);

  final LocalRepository repository;
  AppSnapshot snapshot = AppSnapshot.empty();
  bool loading = true;
  String? error;

  Future<void> initialize() async {
    try {
      snapshot = await repository.load();
    } catch (e) {
      error = '本地数据读取失败：$e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  List<TaskItem> forDay(DateTime day) => tasksForDay(snapshot, day);
  TaskItem? focusForDay(DateTime day) => focusTaskForDay(snapshot, day);
  bool completed(TaskItem task, DateTime day) =>
      isTaskCompleted(snapshot, task, day);

  Future<void> addInbox(String title) async {
    final now = DateTime.now();
    final item = TaskItem(
      id: _id('task'),
      title: title.trim(),
      createdAt: now,
      updatedAt: now,
    );
    await _commit(snapshot.copyWith(tasks: [...snapshot.tasks, item]));
  }

  Future<void> addTask({
    required String title,
    required DateTime plannedDate,
    String note = '',
    String? projectId,
    int? timeMinutes,
    int estimateMins = 25,
    bool isFocus = false,
    bool isPrivate = false,
    DateTime? deadline,
    RecurrenceRule recurrence = const RecurrenceRule(),
  }) async {
    final now = DateTime.now();
    var tasks = snapshot.tasks;
    if (isFocus) {
      tasks = tasks
          .map(
            (task) =>
                task.plannedDate != null &&
                    isSameDay(task.plannedDate!, plannedDate)
                ? task.copyWith(isFocus: false)
                : task,
          )
          .toList();
    }
    final item = TaskItem(
      id: _id('task'),
      title: title.trim(),
      note: note.trim(),
      projectId: projectId,
      status: TaskStatus.planned,
      plannedDate: dateOnly(plannedDate),
      deadline: deadline == null ? null : dateOnly(deadline),
      timeMinutes: timeMinutes,
      estimateMins: estimateMins,
      isFocus: isFocus,
      isPrivate: isPrivate,
      recurrence: recurrence,
      createdAt: now,
      updatedAt: now,
    );
    await _commit(snapshot.copyWith(tasks: [...tasks, item]));
  }

  Future<void> toggleComplete(TaskItem task, DateTime day) async {
    final id = '${task.id}@${dateKey(day)}';
    final entries = [...snapshot.completions];
    final index = entries.indexWhere((entry) => entry.id == id);
    if (index >= 0 && entries[index].status == CompletionStatus.completed) {
      entries.removeAt(index);
    } else {
      final entry = CompletionEntry(
        taskId: task.id,
        date: dateOnly(day),
        updatedAt: DateTime.now(),
      );
      if (index >= 0) {
        entries[index] = entry;
      } else {
        entries.add(entry);
      }
    }
    await _commit(snapshot.copyWith(completions: entries));
  }

  Future<void> postpone(TaskItem task, DateTime day) async {
    final tasks = snapshot.tasks
        .map(
          (item) => item.id == task.id
              ? item.copyWith(
                  plannedDate: dateOnly(day),
                  isFocus: false,
                  status: TaskStatus.planned,
                  updatedAt: DateTime.now(),
                )
              : item,
        )
        .toList();
    await _commit(snapshot.copyWith(tasks: tasks));
  }

  Future<void> archiveTask(TaskItem task) async {
    final tasks = snapshot.tasks
        .map(
          (item) => item.id == task.id
              ? item.copyWith(
                  status: TaskStatus.archived,
                  updatedAt: DateTime.now(),
                )
              : item,
        )
        .toList();
    await _commit(snapshot.copyWith(tasks: tasks));
  }

  Future<void> restoreTask(TaskItem task) async {
    final tasks = snapshot.tasks
        .map(
          (item) => item.id == task.id
              ? item.copyWith(
                  status: item.plannedDate == null
                      ? TaskStatus.inbox
                      : TaskStatus.planned,
                  updatedAt: DateTime.now(),
                )
              : item,
        )
        .toList();
    await _commit(snapshot.copyWith(tasks: tasks));
  }

  Future<void> deleteTask(TaskItem task) async {
    await _commit(
      snapshot.copyWith(
        tasks: snapshot.tasks.where((item) => item.id != task.id).toList(),
        completions: snapshot.completions
            .where((entry) => entry.taskId != task.id)
            .toList(),
      ),
    );
  }

  Future<void> addProject(String title, String reason) async {
    final now = DateTime.now();
    final project = ProjectItem(
      id: _id('project'),
      title: title.trim(),
      reason: reason.trim(),
      createdAt: now,
      updatedAt: now,
    );
    await _commit(snapshot.copyWith(projects: [...snapshot.projects, project]));
  }

  Future<void> updateProject(ProjectItem project) async {
    final projects = snapshot.projects
        .map((item) => item.id == project.id ? project : item)
        .toList();
    await _commit(snapshot.copyWith(projects: projects));
  }

  Future<void> deleteProject(ProjectItem project) async {
    final taskIds = snapshot.tasks
        .where((task) => task.projectId == project.id)
        .map((task) => task.id)
        .toSet();
    await _commit(
      snapshot.copyWith(
        projects: snapshot.projects
            .where((item) => item.id != project.id)
            .toList(),
        tasks: snapshot.tasks
            .where((task) => !taskIds.contains(task.id))
            .toList(),
        completions: snapshot.completions
            .where((entry) => !taskIds.contains(entry.taskId))
            .toList(),
      ),
    );
  }

  Future<void> applyImport(String source, ImportMode mode) async {
    snapshot = await repository.importBackup(source, mode: mode);
    notifyListeners();
  }

  Future<void> _commit(AppSnapshot next) async {
    error = null;
    try {
      await repository.save(next);
      snapshot = next;
    } catch (e) {
      error = '保存失败：$e';
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
}
