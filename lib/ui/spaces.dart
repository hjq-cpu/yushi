part of 'app.dart';

void _openDates(BuildContext context, AppController controller) => Navigator.of(
  context,
).push(MaterialPageRoute(builder: (_) => DatesScreen(controller: controller)));

void _openIdeas(BuildContext context, AppController controller) => Navigator.of(
  context,
).push(MaterialPageRoute(builder: (_) => IdeasScreen(controller: controller)));

class NowScreen extends StatelessWidget {
  const NowScreen({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final projects =
        controller.snapshot.projects
            .where((p) => p.status == ProjectStatus.active)
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final today = controller.forDay(DateTime.now());
    final ideas = _openIdeasFor(controller);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
      children: [
        Text('此刻，随你。', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 12),
        const Text('有想法就记下，想继续时再回来。'),
        const SizedBox(height: 28),
        QuickCapture(controller: controller),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => showTaskEditor(context, controller),
            child: const Text('多写一点'),
          ),
        ),
        const SizedBox(height: 28),
        Text('在意的方向', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        if (projects.isEmpty)
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: YushiColors.focus,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('一个项目、一门爱好，或一件一直惦记的事。'),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => _addProject(context, controller),
                  child: const Text('放下一件在意的事'),
                ),
              ],
            ),
          ),
        for (final project in projects.take(2))
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _openProject(context, controller, project),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: YushiColors.paper,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: YushiColors.rule),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.title,
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(fontSize: 24),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      project.lastProgress.isNotEmpty
                          ? '上次留下：${project.lastProgress}'
                          : project.reason.isNotEmpty
                          ? project.reason
                          : '还没有留下记录，随时可以开始。',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (project.nextStep.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          project.nextStep,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: YushiColors.cobalt),
                        ),
                      ),
                    const SizedBox(height: 18),
                    const Text(
                      '打开看看 →',
                      style: TextStyle(color: YushiColors.cobalt),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (projects.length > 2) const Text('其他方向保留在「在意」里。'),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: Text(
                '随手留下',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton(
              onPressed: () => _openIdeas(context, controller),
              child: const Text('全部想法'),
            ),
          ],
        ),
        if (ideas.isEmpty) const Text('这里不需要整理成任务。'),
        for (final idea in ideas.take(3))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(idea.title),
            subtitle: idea.note.isEmpty
                ? null
                : Text(idea.note, maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: () =>
                _showTaskDetails(context, controller, idea, DateTime.now()),
          ),
        const SizedBox(height: 28),
        if (today.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('今天有约定'),
            subtitle: const Text('你主动注明日期的事'),
            children: [
              for (final task in today)
                ListTile(
                  title: Text(task.title),
                  subtitle: task.timeMinutes == null
                      ? null
                      : Text(_time(task.timeMinutes!)),
                  onTap: () => _showTaskDetails(
                    context,
                    controller,
                    task,
                    DateTime.now(),
                  ),
                ),
              TextButton(
                onPressed: () => _openDates(context, controller),
                child: const Text('查看日期'),
              ),
            ],
          ),
        if (controller.error != null)
          Text(
            controller.error!,
            style: const TextStyle(color: YushiColors.danger),
          ),
      ],
    );
  }
}

List<TaskItem> _openIdeasFor(AppController controller) {
  final items = controller.snapshot.tasks
      .where(
        (t) =>
            t.status != TaskStatus.archived &&
            t.plannedDate == null &&
            !controller.completed(t, DateTime.now()) &&
            (t.projectId == null ||
                controller.snapshot.projects.any(
                  (p) =>
                      p.id == t.projectId && p.status == ProjectStatus.active,
                )),
      )
      .toList();
  items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return items;
}

class IdeasScreen extends StatelessWidget {
  const IdeasScreen({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('随手留下')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('想法可以一直是想法。'),
          const SizedBox(height: 24),
          QuickCapture(controller: controller),
          const SizedBox(height: 24),
          for (final task in _openIdeasFor(controller))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(task.title),
              subtitle: task.note.isEmpty ? null : Text(task.note),
              onTap: () =>
                  _showTaskDetails(context, controller, task, DateTime.now()),
            ),
        ],
      ),
    ),
  );
}

class DatesScreen extends StatefulWidget {
  const DatesScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<DatesScreen> createState() => _DatesScreenState();
}

class _DatesScreenState extends State<DatesScreen> {
  DateTime? selected;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final today = dateOnly(DateTime.now());
      final days = selected == null
          ? List.generate(
              30,
              (i) => DateTime(today.year, today.month, today.day + i),
            )
          : [selected!];
      final populated = days
          .where((d) => widget.controller.forDay(d).isNotEmpty)
          .toList();
      final earlier = pendingAdjustments(widget.controller.snapshot, today);
      return Scaffold(
        appBar: AppBar(
          title: const Text('有日期的事'),
          actions: [
            IconButton(
              tooltip: '分享今天',
              icon: const AppIcon(AppGlyph.image),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      SharePlanScreen(controller: widget.controller),
                ),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              '只放需要日期的事。',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            const Text('约定、出行，或你主动安排的事情。其他内容留在想法和项目里。'),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton(
                  onPressed: () => showTaskEditor(
                    context,
                    widget.controller,
                    initialDate: selected ?? today,
                  ),
                  child: const Text('记一个约定'),
                ),
                TextButton(
                  onPressed: () async {
                    final value = await showDatePicker(
                      context: context,
                      initialDate: selected ?? today,
                      firstDate: today.subtract(const Duration(days: 3650)),
                      lastDate: today.add(const Duration(days: 3650)),
                    );
                    if (value != null && mounted) {
                      setState(() => selected = value);
                    }
                  },
                  child: Text(selected == null ? '查找日期' : _fullDate(selected!)),
                ),
                if (selected != null)
                  TextButton(
                    onPressed: () => setState(() => selected = null),
                    child: const Text('近期安排'),
                  ),
              ],
            ),
            const SizedBox(height: 32),
            if (selected == null) const Text('接下来 30 天'),
            if (populated.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Text('这段时间没有注明日期的事。'),
              ),
            for (final day in populated)
              Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fullDate(day),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    for (final task in widget.controller.forDay(day))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(task.title),
                        subtitle: Text(
                          widget.controller.completed(task, day)
                              ? '已做过'
                              : task.timeMinutes == null
                              ? '未指定时刻'
                              : _time(task.timeMinutes!),
                        ),
                        onTap: () => _showTaskDetails(
                          context,
                          widget.controller,
                          task,
                          day,
                        ),
                      ),
                  ],
                ),
              ),
            if (selected == null && earlier.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('以前注明的日期'),
                subtitle: const Text('保留原处，不自动延到今天'),
                children: [
                  for (final task in earlier)
                    ListTile(
                      title: Text(task.title),
                      subtitle: Text(_fullDate(task.plannedDate!)),
                      onTap: () => _showTaskDetails(
                        context,
                        widget.controller,
                        task,
                        today,
                      ),
                    ),
                ],
              ),
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
              if (project.status == ProjectStatus.active)
                TextButton.icon(
                  onPressed: busy
                      ? null
                      : () => showTaskEditor(
                          context,
                          widget.controller,
                          projectId: project.id,
                        ),
                  icon: const AppIcon(AppGlyph.add),
                  label: const Text('记下相关想法'),
                ),
              for (final task in widget.controller.snapshot.tasks.where(
                (t) =>
                    t.projectId == project.id &&
                    t.status != TaskStatus.archived,
              ))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(task.title),
                  subtitle: task.plannedDate == null
                      ? null
                      : Text(_fullDate(task.plannedDate!)),
                  onTap: () => _showTaskDetails(
                    context,
                    widget.controller,
                    task,
                    DateTime.now(),
                  ),
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
