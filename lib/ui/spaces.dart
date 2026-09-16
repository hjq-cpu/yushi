part of 'app.dart';

void _openDates(BuildContext context, AppController controller) => Navigator.of(
  context,
).push(MaterialPageRoute(builder: (_) => DatesScreen(controller: controller)));
String _phaseName(TaskItem task) => switch (task.phase) {
  TaskPhase.pending => '待办',
  TaskPhase.doing => '在做',
  TaskPhase.completed => '已完成',
};
String _taskMetadata(AppSnapshot snapshot, TaskItem task) => [
  if (task.projectId != null) _projectName(snapshot, task),
  if (task.plannedDate != null)
    '约定 ${_fullDate(task.plannedDate!)}${task.timeMinutes == null ? '' : ' ${_time(task.timeMinutes!)}'}',
  if (task.deadline != null) '截止 ${_fullDate(task.deadline!)}',
].join(' · ');

class TaskLine extends StatelessWidget {
  const TaskLine({super.key, required this.controller, required this.task});
  final AppController controller;
  final TaskItem task;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    minVerticalPadding: 4,
    visualDensity: const VisualDensity(vertical: -2),
    leading: IconButton(
      tooltip: task.phase == TaskPhase.completed ? '撤销完成' : '完成事项',
      icon: Icon(
        task.phase == TaskPhase.completed
            ? Icons.check_circle
            : Icons.radio_button_unchecked,
        color: task.phase == TaskPhase.doing
            ? context.colors.cobalt
            : context.colors.secondary,
      ),
      onPressed: () async {
        try {
          await controller.toggleComplete(task, DateTime.now());
        } catch (e) {
          if (context.mounted) _snack(context, '保存失败：$e');
        }
      },
    ),
    title: Text(
      task.title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    ),
    subtitle: _taskMetadata(controller.snapshot, task).isEmpty
        ? null
        : Text(_taskMetadata(controller.snapshot, task)),
    onTap: () => _showTaskDetails(context, controller, task, DateTime.now()),
  );
}

class NowScreen extends StatefulWidget {
  const NowScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<NowScreen> createState() => _NowScreenState();
}

class _NowScreenState extends State<NowScreen> {
  String query = '';
  String? projectId;
  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final tasks = controller.openTasks
        .where(
          (t) =>
              (projectId == null || t.projectId == projectId) &&
              '${t.title} ${t.note}'.toLowerCase().contains(
                query.toLowerCase(),
              ),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      children: [
        Text('一件一件，慢慢来。', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 10),
        const Text('事情留在这里，按自己的步调继续。'),
        const SizedBox(height: 24),
        QuickCapture(controller: controller),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CompletedScreen(controller: controller),
                ),
              ),
              child: const Text('完成记录'),
            ),
            TextButton(
              onPressed: () => showTaskEditor(context, controller),
              child: const Text('添加详细事项'),
            ),
          ],
        ),
        TextField(
          decoration: const InputDecoration(
            hintText: '搜索事项',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) => setState(() => query = value),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('全部项目'),
                selected: projectId == null,
                onSelected: (_) => setState(() => projectId = null),
              ),
              for (final project in controller.snapshot.projects.where(
                (p) => p.status != ProjectStatus.archived,
              ))
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ChoiceChip(
                    label: Text(project.title),
                    selected: projectId == project.id,
                    onSelected: (_) => setState(() => projectId = project.id),
                  ),
                ),
            ],
          ),
        ),
        for (final phase in [TaskPhase.doing, TaskPhase.pending]) ...[
          const SizedBox(height: 28),
          Text(
            phase == TaskPhase.doing ? '在做' : '待办',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (!tasks.any((t) => t.phase == phase))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                query.isNotEmpty || projectId != null
                    ? '没有匹配的事项'
                    : phase == TaskPhase.doing
                    ? '想开始时，从待办里选一件。'
                    : '想到什么，随手记下。',
              ),
            ),
          for (final task in tasks.where((t) => t.phase == phase))
            TaskLine(controller: controller, task: task),
        ],
        if (controller.error != null)
          Text(
            controller.error!,
            style: TextStyle(color: context.colors.danger),
          ),
      ],
    );
  }
}

class CompletedScreen extends StatelessWidget {
  const CompletedScreen({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final tasks =
          controller.snapshot.tasks
              .where(
                (t) =>
                    t.phase == TaskPhase.completed &&
                    t.status != TaskStatus.archived,
              )
              .toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return Scaffold(
        appBar: AppBar(
          title: const Text('完成记录'),
          actions: [
            IconButton(
              tooltip: '历史记录',
              icon: const Icon(Icons.history),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('历史记录')),
                    body: FootprintsScreen(controller: controller),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (tasks.isEmpty) const Text('完成的事情会留在这里。'),
            for (final task in tasks)
              TaskLine(controller: controller, task: task),
          ],
        ),
      );
    },
  );
}

class DatesScreen extends StatelessWidget {
  const DatesScreen({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final tasks =
          controller.openTasks
              .where((t) => t.plannedDate != null || t.deadline != null)
              .toList()
            ..sort(
              (a, b) => (a.plannedDate ?? a.deadline!).compareTo(
                b.plannedDate ?? b.deadline!,
              ),
            );
      return Scaffold(
        appBar: AppBar(title: const Text('有日期的事')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text('日期是一条信息，不改变事项的状态。'),
            const SizedBox(height: 20),
            if (tasks.isEmpty) const Text('还没有注明约定或截止日期的事项。'),
            for (final task in tasks)
              TaskLine(controller: controller, task: task),
          ],
        ),
      );
    },
  );
}

class FootprintsScreen extends StatelessWidget {
  const FootprintsScreen({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final entries =
        <({DateTime date, String title, String text, VoidCallback open})>[];
    for (final project in controller.snapshot.projects) {
      final progress =
          project.progress.isEmpty && project.lastProgress.isNotEmpty
          ? [
              ProjectProgress(
                text: project.lastProgress,
                createdAt: project.updatedAt,
              ),
            ]
          : project.progress;
      for (final note in progress) {
        entries.add((
          date: note.createdAt,
          title: project.title,
          text: note.text,
          open: () => _openProject(context, controller, project),
        ));
      }
    }
    for (final record in controller.snapshot.completions.where(
      (e) => e.status == CompletionStatus.completed,
    )) {
      final task = controller.snapshot.tasks
          .where((t) => t.id == record.taskId)
          .firstOrNull;
      if (task != null) {
        entries.add((
          date: record.updatedAt,
          title: '做过的一件事',
          text: task.title,
          open: () => _showTaskDetails(context, controller, task, record.date),
        ));
      }
    }
    entries.sort((a, b) => b.date.compareTo(a.date));
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
      children: [
        Text('原来，\n走过这些。', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 16),
        const Text('尝试、发现，或做过的一件小事，都可以留下。'),
        const SizedBox(height: 36),
        if (entries.isEmpty) const Text('还没有留下足迹。等你想记的时候再来。'),
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 28),
            child: InkWell(
              onTap: entry.open,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_fullDate(entry.date)} · ${entry.title}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    entry.text,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class ProjectSpaceSheet extends StatefulWidget {
  const ProjectSpaceSheet({
    super.key,
    required this.controller,
    required this.project,
  });
  final AppController controller;
  final ProjectItem project;
  @override
  State<ProjectSpaceSheet> createState() => _ProjectSpaceSheetState();
}

class _ProjectSpaceSheetState extends State<ProjectSpaceSheet> {
  final progress = TextEditingController();
  late final next = TextEditingController(text: widget.project.nextStep);
  bool busy = false;
  @override
  void dispose() {
    progress.dispose();
    next.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      await widget.controller.leaveProgress(
        widget.project.id,
        progress.text,
        next.text,
      );
      if (mounted) {
        progress.clear();
        _snack(context, '已留下，下次还在这里');
      }
    } catch (e) {
      if (mounted) _snack(context, '保存失败：$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final project =
          widget.controller.snapshot.projects
              .where((p) => p.id == widget.project.id)
              .firstOrNull ??
          widget.project;
      return PopScope(
        canPop: !busy,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            8,
            24,
            MediaQuery.viewInsetsOf(context).bottom + 28,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      project.title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭项目',
                    onPressed: busy ? null : () => Navigator.pop(context),
                    icon: const AppIcon(AppGlyph.close),
                  ),
                ],
              ),
              if (project.reason.isNotEmpty) Text(project.reason),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: () => showTaskEditor(
                  context,
                  widget.controller,
                  projectId: project.id,
                ),
                icon: const AppIcon(AppGlyph.add),
                label: const Text('添加项目事项'),
              ),
              for (final phase in [
                TaskPhase.doing,
                TaskPhase.pending,
                TaskPhase.completed,
              ]) ...[
                Text(
                  phase == TaskPhase.doing
                      ? '在做'
                      : phase == TaskPhase.pending
                      ? '待办'
                      : '已完成',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final task in widget.controller.snapshot.tasks.where(
                  (t) =>
                      t.projectId == project.id &&
                      t.status != TaskStatus.archived &&
                      t.phase == phase,
                ))
                  TaskLine(controller: widget.controller, task: task),
                const SizedBox(height: 16),
              ],
              ExpansionTile(
                title: const Text('项目笔记（可选）'),
                children: [
                  if (project.lastProgress.isNotEmpty) ...[
                    Text('上次留下', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Text(project.lastProgress),
                    const SizedBox(height: 24),
                  ],
                  TextField(
                    controller: next,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: '下次可以从哪开始（可选）',
                      hintText: '留一条线索，不需要承诺',
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: progress,
                    minLines: 2,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: '留下一点进展',
                      hintText: '试过什么、发现什么、卡在哪里…',
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: busy ? null : save,
                    child: Text(busy ? '保存中…' : '留下这段记录'),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
              if (project.progress.isNotEmpty)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('之前留下的记录'),
                  children: [
                    for (final entry in project.progress.reversed)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(entry.text),
                        subtitle: Text(_fullDate(entry.createdAt)),
                      ),
                  ],
                ),
              if (project.weekGoal.isNotEmpty) Text('早先记下：${project.weekGoal}'),
            ],
          ),
        ),
      );
    },
  );
}
