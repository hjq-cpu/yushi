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
  bool searchOpen = false;
  final searchController = TextEditingController();
  final searchFocusNode = FocusNode();

  @override
  void dispose() {
    searchController.dispose();
    searchFocusNode.dispose();
    super.dispose();
  }

  void openSearch() {
    setState(() => searchOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) searchFocusNode.requestFocus();
    });
  }

  void closeSearch() {
    searchController.clear();
    searchFocusNode.unfocus();
    setState(() {
      query = '';
      searchOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final projects = controller.snapshot.projects
        .where((p) => p.status != ProjectStatus.archived)
        .toList();
    final selectedProjectId = projects.any((p) => p.id == projectId)
        ? projectId
        : null;
    final selectedProjectTitle = selectedProjectId == null
        ? null
        : projects.firstWhere((p) => p.id == selectedProjectId).title;
    final tasks = controller.openTasks
        .where(
          (t) =>
              (selectedProjectId == null || t.projectId == selectedProjectId) &&
              '${t.title} ${t.note}'.toLowerCase().contains(
                query.toLowerCase(),
              ),
        )
        .toList();
    final allProjectsValue = '__all_projects__';
    final doingTasks = tasks.where((t) => t.phase == TaskPhase.doing).toList();
    final pendingTasks = tasks
        .where((t) => t.phase == TaskPhase.pending)
        .toList();

    Widget phaseSection(
      String title,
      List<TaskItem> phaseTasks,
      String empty,
    ) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            if (phaseTasks.isEmpty) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  query.isNotEmpty || selectedProjectId != null
                      ? '没有匹配的事项'
                      : empty,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        for (final task in phaseTasks)
          TaskLine(controller: controller, task: task),
      ],
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        Row(
          children: [
            if (searchOpen)
              Expanded(
                child: TextField(
                  controller: searchController,
                  focusNode: searchFocusNode,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: '搜索事项',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    helperText: selectedProjectTitle == null
                        ? null
                        : '项目：${selectedProjectTitle.length > 20 ? '${selectedProjectTitle.substring(0, 20)}…' : selectedProjectTitle}',
                    helperMaxLines: 1,
                  ),
                  onChanged: (value) => setState(() => query = value),
                ),
              )
            else
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: selectedProjectId ?? allProjectsValue,
                    hint: const Text('全部项目'),
                    items: [
                      DropdownMenuItem<String>(
                        value: allProjectsValue,
                        child: Text('全部项目'),
                      ),
                      for (final project in projects)
                        DropdownMenuItem<String>(
                          value: project.id,
                          child: Text(
                            project.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(
                      () =>
                          projectId = value == allProjectsValue ? null : value,
                    ),
                  ),
                ),
              ),
            if (searchOpen)
              IconButton(
                tooltip: '关闭搜索',
                icon: const Icon(Icons.close),
                onPressed: closeSearch,
              )
            else ...[
              IconButton(
                tooltip: '搜索事项',
                icon: const Icon(Icons.search),
                onPressed: openSearch,
              ),
              IconButton(
                tooltip: '完成记录',
                icon: const Icon(Icons.history),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CompletedScreen(controller: controller),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        phaseSection('在做', doingTasks, '暂无进行中的事项'),
        const SizedBox(height: 16),
        phaseSection('待办', pendingTasks, '想到什么，随手记下'),
        if (controller.error != null) ...[
          const SizedBox(height: 12),
          Text(
            controller.error!,
            style: TextStyle(color: context.colors.danger),
          ),
        ],
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
