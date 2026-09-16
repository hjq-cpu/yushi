import 'dart:convert';

const _notProvided = Object();

enum TaskPhase { pending, doing, completed }

enum TaskStatus { inbox, active, planned, someday, archived }

enum ProjectStatus { active, paused, archived }

enum RecurrenceType { none, daily, weekdays, selectedWeekdays, weeklyTarget }

enum CompletionStatus { completed, skipped }

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
String dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
bool isSameDay(DateTime a, DateTime b) => dateKey(a) == dateKey(b);

class RecurrenceRule {
  const RecurrenceRule({
    this.type = RecurrenceType.none,
    this.weekdays = const [],
    this.weeklyTarget = 1,
  });

  final RecurrenceType type;
  final List<int> weekdays;
  final int weeklyTarget;

  RecurrenceRule copyWith({
    RecurrenceType? type,
    List<int>? weekdays,
    int? weeklyTarget,
  }) => RecurrenceRule(
    type: type ?? this.type,
    weekdays: List.unmodifiable(weekdays ?? this.weekdays),
    weeklyTarget: weeklyTarget ?? this.weeklyTarget,
  );

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'weekdays': weekdays,
    'weeklyTarget': weeklyTarget,
  };

  factory RecurrenceRule.fromJson(Map<String, dynamic> json) {
    final type = _enumValue(json, 'type', RecurrenceType.values);
    final rawDays = _list(json, 'weekdays');
    final days = rawDays
        .map((day) {
          if (day is! int || day < 1 || day > 7) {
            throw const FormatException('重复安排的星期必须是 1 至 7。');
          }
          return day;
        })
        .toList(growable: false);
    if (days.toSet().length != days.length ||
        (type == RecurrenceType.selectedWeekdays && days.isEmpty)) {
      throw const FormatException('重复安排的星期无效。');
    }
    return RecurrenceRule(
      type: type,
      weekdays: List.unmodifiable(days),
      weeklyTarget: _integer(json, 'weeklyTarget', min: 1, max: 7),
    );
  }
}

class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    this.note = '',
    this.projectId,
    this.status = TaskStatus.inbox,
    this.phase = TaskPhase.pending,
    this.plannedDate,
    this.deadline,
    this.timeMinutes,
    this.estimateMins = 25,
    this.isFocus = false,
    this.isPrivate = false,
    this.recurrence = const RecurrenceRule(),
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String note;
  final String? projectId;
  final TaskStatus status;
  final TaskPhase phase;
  final DateTime? plannedDate;
  final DateTime? deadline;
  final int? timeMinutes;
  final int estimateMins;
  final bool isFocus;
  final bool isPrivate;
  final RecurrenceRule recurrence;
  final DateTime createdAt;
  final DateTime updatedAt;

  TaskItem copyWith({
    String? id,
    String? title,
    String? note,
    Object? projectId = _notProvided,
    TaskStatus? status,
    TaskPhase? phase,
    Object? plannedDate = _notProvided,
    Object? deadline = _notProvided,
    Object? timeMinutes = _notProvided,
    int? estimateMins,
    bool? isFocus,
    bool? isPrivate,
    RecurrenceRule? recurrence,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => TaskItem(
    id: id ?? this.id,
    title: title ?? this.title,
    note: note ?? this.note,
    projectId: identical(projectId, _notProvided)
        ? this.projectId
        : projectId as String?,
    status: status ?? this.status,
    phase: phase ?? this.phase,
    plannedDate: identical(plannedDate, _notProvided)
        ? this.plannedDate
        : plannedDate as DateTime?,
    deadline: identical(deadline, _notProvided)
        ? this.deadline
        : deadline as DateTime?,
    timeMinutes: identical(timeMinutes, _notProvided)
        ? this.timeMinutes
        : timeMinutes as int?,
    estimateMins: estimateMins ?? this.estimateMins,
    isFocus: isFocus ?? this.isFocus,
    isPrivate: isPrivate ?? this.isPrivate,
    recurrence: recurrence ?? this.recurrence,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'note': note,
    'projectId': projectId,
    'status': status.name,
    'phase': phase.name,
    'plannedDate': plannedDate == null ? null : dateKey(plannedDate!),
    'deadline': deadline == null ? null : dateKey(deadline!),
    'timeMinutes': timeMinutes,
    'estimateMins': estimateMins,
    'isFocus': isFocus,
    'isPrivate': isPrivate,
    'recurrence': recurrence.toJson(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory TaskItem.fromJson(Map<String, dynamic> json) => TaskItem(
    id: _string(json, 'id', nonEmpty: true),
    title: _string(json, 'title', nonEmpty: true),
    note: _string(json, 'note'),
    projectId: _nullableString(json, 'projectId'),
    status: _enumValue(json, 'status', TaskStatus.values),
    phase: json.containsKey('phase')
        ? _enumValue(json, 'phase', TaskPhase.values)
        : TaskPhase.pending,
    plannedDate: _nullableDate(json, 'plannedDate'),
    deadline: _nullableDate(json, 'deadline'),
    timeMinutes: json['timeMinutes'] == null
        ? null
        : _integer(json, 'timeMinutes', min: 0, max: 1439),
    estimateMins: _integer(json, 'estimateMins', min: 0, max: 1440),
    isFocus: _boolean(json, 'isFocus'),
    isPrivate: _boolean(json, 'isPrivate'),
    recurrence: RecurrenceRule.fromJson(_object(json['recurrence'])),
    createdAt: _timestamp(json, 'createdAt'),
    updatedAt: _timestamp(json, 'updatedAt'),
  );
}

class ProjectProgress {
  const ProjectProgress({required this.text, required this.createdAt});
  final String text;
  final DateTime createdAt;
  Map<String, dynamic> toJson() => {
    'text': text,
    'createdAt': createdAt.toIso8601String(),
  };
  factory ProjectProgress.fromJson(Map<String, dynamic> json) =>
      ProjectProgress(
        text: _string(json, 'text', nonEmpty: true),
        createdAt: _timestamp(json, 'createdAt'),
      );
}

class ProjectItem {
  const ProjectItem({
    required this.id,
    required this.title,
    this.reason = '',
    this.weekGoal = '',
    this.lastProgress = '',
    this.nextStep = '',
    this.progress = const [],
    this.status = ProjectStatus.active,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String reason;
  final String weekGoal;
  final String lastProgress;
  final String nextStep;
  final List<ProjectProgress> progress;
  final ProjectStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProjectItem copyWith({
    String? id,
    String? title,
    String? reason,
    String? weekGoal,
    String? lastProgress,
    String? nextStep,
    List<ProjectProgress>? progress,
    ProjectStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ProjectItem(
    id: id ?? this.id,
    title: title ?? this.title,
    reason: reason ?? this.reason,
    weekGoal: weekGoal ?? this.weekGoal,
    lastProgress: lastProgress ?? this.lastProgress,
    nextStep: nextStep ?? this.nextStep,
    progress: List.unmodifiable(progress ?? this.progress),
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'reason': reason,
    'weekGoal': weekGoal,
    'lastProgress': lastProgress,
    'nextStep': nextStep,
    'progress': progress.map((entry) => entry.toJson()).toList(),
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory ProjectItem.fromJson(Map<String, dynamic> json) => ProjectItem(
    id: _string(json, 'id', nonEmpty: true),
    title: _string(json, 'title', nonEmpty: true),
    reason: _string(json, 'reason'),
    weekGoal: _string(json, 'weekGoal'),
    lastProgress: json.containsKey('lastProgress')
        ? _string(json, 'lastProgress')
        : '',
    nextStep: json.containsKey('nextStep') ? _string(json, 'nextStep') : '',
    progress: json.containsKey('progress')
        ? List.unmodifiable(
            _list(
              json,
              'progress',
            ).map((entry) => ProjectProgress.fromJson(_object(entry))),
          )
        : const [],
    status: _enumValue(json, 'status', ProjectStatus.values),
    createdAt: _timestamp(json, 'createdAt'),
    updatedAt: _timestamp(json, 'updatedAt'),
  );
}

class CompletionEntry {
  const CompletionEntry({
    required this.taskId,
    required this.date,
    this.status = CompletionStatus.completed,
    this.note = '',
    required this.updatedAt,
  });

  final String taskId;
  final DateTime date;
  final CompletionStatus status;
  final String note;
  final DateTime updatedAt;
  String get id => '$taskId@${dateKey(date)}';

  CompletionEntry copyWith({
    String? taskId,
    DateTime? date,
    CompletionStatus? status,
    String? note,
    DateTime? updatedAt,
  }) => CompletionEntry(
    taskId: taskId ?? this.taskId,
    date: date ?? this.date,
    status: status ?? this.status,
    note: note ?? this.note,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'taskId': taskId,
    'date': dateKey(date),
    'status': status.name,
    'note': note,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory CompletionEntry.fromJson(Map<String, dynamic> json) {
    final entry = CompletionEntry(
      taskId: _string(json, 'taskId', nonEmpty: true),
      date: _date(_string(json, 'date')),
      status: _enumValue(json, 'status', CompletionStatus.values),
      note: _string(json, 'note'),
      updatedAt: _timestamp(json, 'updatedAt'),
    );
    if (_string(json, 'id', nonEmpty: true) != entry.id) {
      throw const FormatException('完成记录的 ID 与任务日期不一致。');
    }
    return entry;
  }
}

class AppSettings {
  const AppSettings({
    this.theme = 'cobalt',
    this.weekStartsOn = 1,
    this.onboardingCompleted = false,
    this.notificationsEnabled = false,
  });

  final String theme;
  final int weekStartsOn;
  final bool onboardingCompleted;
  final bool notificationsEnabled;

  AppSettings copyWith({
    String? theme,
    int? weekStartsOn,
    bool? onboardingCompleted,
    bool? notificationsEnabled,
  }) => AppSettings(
    theme: theme ?? this.theme,
    weekStartsOn: weekStartsOn ?? this.weekStartsOn,
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
  );

  Map<String, dynamic> toJson() => {
    'theme': theme,
    'weekStartsOn': weekStartsOn,
    'onboardingCompleted': onboardingCompleted,
    'notificationsEnabled': notificationsEnabled,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    theme: _string(json, 'theme', nonEmpty: true),
    weekStartsOn: _integer(json, 'weekStartsOn', min: 1, max: 7),
    onboardingCompleted: _boolean(json, 'onboardingCompleted'),
    notificationsEnabled: _boolean(json, 'notificationsEnabled'),
  );
}

class AppSnapshot {
  AppSnapshot({
    List<TaskItem> tasks = const [],
    List<ProjectItem> projects = const [],
    List<CompletionEntry> completions = const [],
    this.settings = const AppSettings(),
  }) : tasks = List.unmodifiable(tasks),
       projects = List.unmodifiable(projects),
       completions = List.unmodifiable(completions);

  factory AppSnapshot.empty() => AppSnapshot();
  final List<TaskItem> tasks;
  final List<ProjectItem> projects;
  final List<CompletionEntry> completions;
  final AppSettings settings;

  AppSnapshot copyWith({
    List<TaskItem>? tasks,
    List<ProjectItem>? projects,
    List<CompletionEntry>? completions,
    AppSettings? settings,
  }) => AppSnapshot(
    tasks: tasks ?? this.tasks,
    projects: projects ?? this.projects,
    completions: completions ?? this.completions,
    settings: settings ?? this.settings,
  );

  Map<String, dynamic> toJson() => {
    'tasks': tasks.map((item) => item.toJson()).toList(),
    'projects': projects.map((item) => item.toJson()).toList(),
    'completions': completions.map((item) => item.toJson()).toList(),
    'settings': settings.toJson(),
  };

  factory AppSnapshot.fromJson(Map<String, dynamic> json) {
    final tasks = _list(
      json,
      'tasks',
    ).map((item) => TaskItem.fromJson(_object(item))).toList();
    final projects = _list(
      json,
      'projects',
    ).map((item) => ProjectItem.fromJson(_object(item))).toList();
    final completions = _list(
      json,
      'completions',
    ).map((item) => CompletionEntry.fromJson(_object(item))).toList();
    // Legacy one-off completions become persistent state. Repeating tasks stay
    // pending; their historical records are retained without generating copies.
    final rawTasks = _list(json, 'tasks');
    for (var i = 0; i < tasks.length; i++) {
      if (!_object(rawTasks[i]).containsKey('phase') &&
          tasks[i].recurrence.type == RecurrenceType.none &&
          completions.any(
            (e) =>
                e.taskId == tasks[i].id &&
                e.status == CompletionStatus.completed,
          )) {
        tasks[i] = tasks[i].copyWith(phase: TaskPhase.completed);
      }
    }
    final taskIds = tasks.map((task) => task.id).toSet();
    final projectIds = projects.map((project) => project.id).toSet();
    if (taskIds.length != tasks.length ||
        projectIds.length != projects.length ||
        completions.map((entry) => entry.id).toSet().length !=
            completions.length) {
      throw const FormatException('备份中存在重复 ID。');
    }
    if (tasks.any(
      (task) => task.projectId != null && !projectIds.contains(task.projectId),
    )) {
      throw const FormatException('任务引用了不存在的项目。');
    }
    if (completions.any((entry) => !taskIds.contains(entry.taskId))) {
      throw const FormatException('完成记录引用了不存在的任务。');
    }
    return AppSnapshot(
      tasks: tasks,
      projects: projects,
      completions: completions,
      settings: AppSettings.fromJson(_object(json['settings'])),
    );
  }

  /// Uses canonical field ordering for backup preview conflict detection.
  String encode() => jsonEncode(toJson());
}

Map<String, dynamic> _object(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('备份对象结构无效。');
  }
  return value;
}

List<dynamic> _list(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) throw FormatException('字段 $key 必须是列表。');
  return value;
}

String _string(Map<String, dynamic> json, String key, {bool nonEmpty = false}) {
  final value = json[key];
  if (value is! String || (nonEmpty && value.trim().isEmpty)) {
    throw FormatException('字段 $key 必须是${nonEmpty ? '非空' : ''}文本。');
  }
  return value;
}

String? _nullableString(Map<String, dynamic> json, String key) =>
    json[key] == null ? null : _string(json, key, nonEmpty: true);

int _integer(
  Map<String, dynamic> json,
  String key, {
  required int min,
  required int max,
}) {
  final value = json[key];
  if (value is! int || value < min || value > max) {
    throw FormatException('字段 $key 必须是 $min 至 $max 的整数。');
  }
  return value;
}

bool _boolean(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('字段 $key 必须是布尔值。');
  return value;
}

T _enumValue<T extends Enum>(
  Map<String, dynamic> json,
  String key,
  List<T> values,
) {
  final name = _string(json, key);
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw FormatException('字段 $key 含有不支持的值。');
}

DateTime _date(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('日期必须使用 YYYY-MM-DD 格式。');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null || dateKey(parsed) != value) {
    throw const FormatException('备份中存在无效日期。');
  }
  return dateOnly(parsed);
}

DateTime? _nullableDate(Map<String, dynamic> json, String key) =>
    json[key] == null ? null : _date(_string(json, key));

DateTime _timestamp(Map<String, dynamic> json, String key) {
  final value = _string(json, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !value.contains('T')) {
    throw FormatException('字段 $key 不是有效的时间。');
  }
  return parsed;
}
