import 'package:flutter/foundation.dart';

import 'data/local_repository.dart';
import 'data/android_widget.dart';
import 'domain/models.dart';
import 'domain/planning.dart';

class AppController extends ChangeNotifier {
  AppController(this.repository) {
    AndroidWidget.bindReload(reloadFromStorage);
  }

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

  Future<void> reloadFromStorage() async {
    try {
      snapshot = await repository.load();
      error = null;
    } catch (e) {
      error = '本地数据读取失败：$e';
    } finally {
      notifyListeners();
    }
  }

  List<TaskItem> forDay(DateTime day) => tasksForDay(snapshot, day);
  TaskItem? focusForDay(DateTime day) => focusTaskForDay(snapshot, day);
  bool completed(TaskItem task, DateTime day) =>
      (snapshot.tasks.where((t) => t.id == task.id).firstOrNull ?? task)
          .phase ==
      TaskPhase.completed;

  Future<void> addInbox(String title) async {
    final now = DateTime.now();
    final item = TaskItem(
      id: _id('task'),
      title: title.trim(),
      estimateMins: 0,
      createdAt: now,
      updatedAt: now,
    );
    await _commit(snapshot.copyWith(tasks: [...snapshot.tasks, item]));
  }

  Future<void> addTask({
    required String title,
    TaskItem? existing,
    DateTime? plannedDate,
    String note = '',
    String? projectId,
    int? timeMinutes,
    int estimateMins = 0,
    bool isFocus = false,
    bool isPrivate = false,
    DateTime? deadline,
    RecurrenceRule recurrence = const RecurrenceRule(),
  }) async {
    final now = DateTime.now();
    var tasks = snapshot.tasks;
    if (isFocus && plannedDate != null) {
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
      id: existing?.id ?? _id('task'),
      title: title.trim(),
      note: note.trim(),
      projectId: projectId,
      status: existing?.status ?? TaskStatus.inbox,
      phase: existing?.phase ?? TaskPhase.pending,
      plannedDate: plannedDate == null ? null : dateOnly(plannedDate),
      deadline: deadline == null ? null : dateOnly(deadline),
      timeMinutes: plannedDate == null ? null : timeMinutes,
      estimateMins: estimateMins,
      isFocus: plannedDate != null && isFocus,
      isPrivate: isPrivate,
      recurrence:
          existing?.recurrence ??
          (plannedDate == null ? const RecurrenceRule() : recurrence),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await _commit(
      snapshot.copyWith(
        tasks: existing == null
            ? [...tasks, item]
            : tasks.map((t) => t.id == item.id ? item : t).toList(),
      ),
    );
  }

  Future<void> toggleComplete(TaskItem task, DateTime day) async {
    final current = snapshot.tasks.firstWhere((t) => t.id == task.id);
    final done = current.phase == TaskPhase.completed;
    final entries = snapshot.completions
        .where(
          (e) =>
              e.taskId != task.id ||
              (done
                  ? e.status != CompletionStatus.completed
                  : e.id != '${task.id}@${dateKey(day)}'),
        )
        .toList();
    if (!done) {
      entries.add(
        CompletionEntry(
          taskId: task.id,
          date: dateOnly(day),
          updatedAt: DateTime.now(),
        ),
      );
    }
    await _commit(
      snapshot.copyWith(
        tasks: snapshot.tasks
            .map(
              (t) => t.id == task.id
                  ? t.copyWith(
                      phase: done ? TaskPhase.pending : TaskPhase.completed,
                      updatedAt: DateTime.now(),
                    )
                  : t,
            )
            .toList(),
        completions: entries,
      ),
    );
  }

  List<TaskItem> get openTasks =>
      snapshot.tasks
          .where(
            (t) =>
                t.status != TaskStatus.archived &&
                t.phase != TaskPhase.completed &&
                !snapshot.projects.any(
                  (p) =>
                      p.id == t.projectId && p.status == ProjectStatus.archived,
                ),
          )
          .toList()
        ..sort((a, b) {
          final phase = (a.phase == TaskPhase.doing ? 0 : 1).compareTo(
            b.phase == TaskPhase.doing ? 0 : 1,
          );
          return phase != 0 ? phase : a.createdAt.compareTo(b.createdAt);
        });

  Future<void> setPhase(TaskItem task, TaskPhase phase) async {
    if (phase == TaskPhase.completed || task.phase == TaskPhase.completed) {
      throw ArgumentError('Use toggleComplete for completion changes');
    }
    await _commit(
      snapshot.copyWith(
        tasks: snapshot.tasks
            .map(
              (t) => t.id == task.id
                  ? t.copyWith(phase: phase, updatedAt: DateTime.now())
                  : t,
            )
            .toList(),
      ),
    );
  }

  Future<void> postpone(TaskItem task, DateTime day) async {
    final tasks = snapshot.tasks
        .map(
          (item) => item.id == task.id
              ? item.copyWith(
                  plannedDate: dateOnly(day),
                  isFocus: false,

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

  Future<void> unschedule(TaskItem task) => _commit(
    snapshot.copyWith(
      tasks: snapshot.tasks
          .map(
            (item) => item.id == task.id
                ? item.copyWith(
                    status: TaskStatus.inbox,
                    plannedDate: null,
                    timeMinutes: null,
                    isFocus: false,
                    recurrence: const RecurrenceRule(),
                    updatedAt: DateTime.now(),
                  )
                : item,
          )
          .toList(),
    ),
  );

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

  Future<void> leaveProgress(
    String projectId,
    String text,
    String nextStep,
  ) async {
    final project = snapshot.projects.firstWhere((p) => p.id == projectId);
    final now = DateTime.now();
    final entries = [...project.progress];
    // Preserve context from versions before the progress journal existed.
    if (entries.isEmpty && project.lastProgress.isNotEmpty) {
      entries.add(
        ProjectProgress(
          text: project.lastProgress,
          createdAt: project.updatedAt,
        ),
      );
    }
    if (text.trim().isNotEmpty) {
      entries.add(ProjectProgress(text: text.trim(), createdAt: now));
    }
    await updateProject(
      project.copyWith(
        lastProgress: text.trim().isEmpty ? project.lastProgress : text.trim(),
        nextStep: nextStep.trim(),
        progress: entries,
        updatedAt: now,
      ),
    );
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

  Future<void> dismissIntroductionPermanently() => _commit(
    snapshot.copyWith(
      settings: snapshot.settings.copyWith(onboardingCompleted: true),
    ),
  );

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
