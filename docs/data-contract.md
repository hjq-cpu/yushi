# 本地数据与界面契约

首版使用不可变 Dart 模型与 SQLite。所有业务数据保留稳定 ID；日期按手机本地日历日保存，计划日与真实截止日是两个独立字段。

## 导入方式

`import 'package:yushi/domain/models.dart';`

`import 'package:yushi/domain/planning.dart';`

`import 'package:yushi/data/local_repository.dart';`

当前 Flutter 包名为 `yushi`。

## 模型

- `TaskItem({required String id, required String title, String note = '', String? projectId, TaskStatus status = TaskStatus.inbox, DateTime? plannedDate, DateTime? deadline, int? timeMinutes, int estimateMins = 25, bool isFocus = false, bool isPrivate = false, RecurrenceRule recurrence = const RecurrenceRule(), required DateTime createdAt, required DateTime updatedAt})`
- `TaskStatus`: `inbox, active, planned, someday, archived`。
- `ProjectItem({required String id, required String title, String reason = '', String weekGoal = '', ProjectStatus status = ProjectStatus.active, required DateTime createdAt, required DateTime updatedAt})`
- `ProjectStatus`: `active, paused, archived`。
- `RecurrenceRule({RecurrenceType type = RecurrenceType.none, List<int> weekdays = const [], int weeklyTarget = 1})`
- `RecurrenceType`: `none, daily, weekdays, selectedWeekdays, weeklyTarget`。星期一为 1、星期日为 7。
- `CompletionEntry({required String taskId, required DateTime date, CompletionStatus status = CompletionStatus.completed, String note = '', required DateTime updatedAt})`；`id` 为 `taskId@YYYY-MM-DD`，同一任务同一天只有一个记录。
- `CompletionStatus`: `completed, skipped`。
- `AppSettings({String theme = 'cobalt', int weekStartsOn = 1, bool onboardingCompleted = false, bool notificationsEnabled = false})`。
- `AppSnapshot({List<TaskItem> tasks = const [], List<ProjectItem> projects = const [], List<CompletionEntry> completions = const [], AppSettings settings = const AppSettings()})`。

上述对象提供 `toJson/fromJson`、`copyWith`；`AppSnapshot.empty()`。可空字段的 `copyWith(plannedDate: null)` 等会真正清除字段。

## 领域函数

- `dateOnly(DateTime value)`、`dateKey(DateTime value)`、`isSameDay(DateTime a, DateTime b)`。
- `tasksForDay(AppSnapshot snapshot, DateTime day)`：返回当天计划或重复安排，按重点、时间和创建时间排序；当天已完成事项仍包含在结果中。收集箱、以后再做、归档，以及暂停/归档项目中的任务不自动排入今天。
- `completionForDay(AppSnapshot snapshot, String taskId, DateTime day)` → `CompletionEntry?`。
- `isTaskCompleted(AppSnapshot snapshot, TaskItem task, DateTime day)` → `bool`。
- `weeklyCompletionCount(AppSnapshot snapshot, String taskId, DateTime day)` → 本周完成天数，不累加上周欠账。
- `pendingAdjustments(AppSnapshot snapshot, DateTime day)` → 过去计划日仍未完成的非重复任务，不自动改到今天。
- `focusTaskForDay(AppSnapshot snapshot, DateTime day)` → 当天未完成/未跳过事项中的第一件，优先显式重点。

## 存储接口

`LocalRepository({DatabaseFactory? databaseFactory, String? databasePath, Directory? backupDirectory})` 可直接无参数构造，首次读写自动打开数据库。

- `Future<AppSnapshot> load()`
- `Future<void> save(AppSnapshot snapshot)`：校验后，事务保存全部内容。
- `Future<File> exportBackup()`：导出到应用备份目录，返回可分享的 JSON 文件。
- `Future<ImportPreview> previewImport(String jsonText)`：严格校验，返回 `snapshot, exportedAt, newTasks, newProjects, newCompletions, duplicateCount, conflictCount`；不会修改数据。
- `Future<AppSnapshot> importBackup(String jsonText, {ImportMode mode = ImportMode.merge})`：默认合并；相同 ID 保留当前记录与当前设置。替换模式必须先成功写入当前数据备份，再事务替换。返回实际保存后的完整快照。
- `Future<void> close()`。
- `ImportMode`: `merge, replace`。
- `BackupValidationException`：含可显示给用户的 `message`。无效 JSON、版本、字段、重复 ID 或无效项目/任务引用均拒绝。

JSON 顶层为 `format: 'yushi.backup', version: 1, exportedAt, data`。不包含数据库路径等设备字段。

## 编辑与完成

界面修改快照后调用 `save`。完成或跳过任务时，按 `CompletionEntry.id` 替换/插入当天记录，再保存。撤销完成则删除该记录。重复规则继续有效；非重复任务一旦完成，不再显示在以后日期的候选中。历史完成时间不会改变任务的原计划日或真实截止日。
