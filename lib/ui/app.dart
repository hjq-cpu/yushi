import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app_controller.dart';
import '../data/local_repository.dart';
import '../data/android_widget.dart';
import '../domain/models.dart';
import '../domain/planning.dart';
import 'app_icons.dart';
import 'theme.dart';

class YushiApp extends StatelessWidget {
  const YushiApp({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '余时',
    debugShowCheckedModeBanner: false,
    theme: buildYushiTheme(),
    home: HomeShell(controller: controller),
  );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller});
  final AppController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  bool introductionHandled = false;

  void scheduleIntroduction() {
    if (introductionHandled || widget.controller.error != null) return;
    introductionHandled = true;
    if (widget.controller.snapshot.settings.onboardingCompleted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _IntroductionDialog(controller: widget.controller),
      );
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      if (widget.controller.loading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      scheduleIntroduction();
      final pages = [
        TodayScreen(controller: widget.controller),
        WeekScreen(controller: widget.controller),
        ProjectsScreen(controller: widget.controller),
      ];
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          titleSpacing: 22,
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '余时',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontFamily: 'NotoSerifSC',
                  fontWeight: FontWeight.w600,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(width: 9),
              const Padding(
                padding: EdgeInsets.only(bottom: 3),
                child: Text(
                  'YU SHI',
                  style: TextStyle(
                    fontFamily: null,
                    fontSize: 10,
                    letterSpacing: 1.6,
                    color: YushiColors.secondary,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      SharePlanScreen(controller: widget.controller),
                ),
              ),
              icon: const AppIcon(AppGlyph.image, size: 19),
              label: const Text('分享今天'),
            ),
            IconButton(
              tooltip: '设置与数据',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(controller: widget.controller),
                ),
              ),
              icon: const AppIcon(AppGlyph.settings),
            ),
            const SizedBox(width: 8),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(
              height: 1,
              indent: 22,
              endIndent: 22,
              color: YushiColors.ink,
            ),
          ),
        ),
        body: SafeArea(top: false, child: pages[index]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          backgroundColor: YushiColors.paper,
          indicatorColor: YushiColors.focus,
          onDestinationSelected: (value) => setState(() => index = value),
          destinations: const [
            NavigationDestination(icon: AppIcon(AppGlyph.today), label: '今天'),
            NavigationDestination(icon: AppIcon(AppGlyph.week), label: '节奏'),
            NavigationDestination(
              icon: AppIcon(AppGlyph.projects),
              label: '项目',
            ),
          ],
        ),
      );
    },
  );
}

class _IntroductionDialog extends StatefulWidget {
  const _IntroductionDialog({required this.controller});
  final AppController controller;

  @override
  State<_IntroductionDialog> createState() => _IntroductionDialogState();
}

class _IntroductionDialogState extends State<_IntroductionDialog> {
  bool neverAgain = false;
  bool saving = false;
  String? error;

  Future<void> continueToToday() async {
    if (saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      if (neverAgain) await widget.controller.dismissIntroductionPermanently();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = '偏好保存失败，请重试';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AlertDialog(
      scrollable: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/branding/app-icon.png',
              width: 48,
              height: 48,
            ),
          ),
          const SizedBox(height: 18),
          const Text('给在意的事，留一点时间'),
        ],
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('工作之外，你还有想做的项目、想学的东西，以及需要照顾的生活。余时帮助你从这些事情里，选出今天值得投入的一步。'),
          const SizedBox(height: 18),
          const Text('有所选择', style: TextStyle(fontWeight: FontWeight.w700)),
          const Text('今天先推进一件重要的事，让具体行动有一个起点。'),
          const SizedBox(height: 12),
          const Text('适可而止', style: TextStyle(fontWeight: FontWeight.w700)),
          const Text('写下做到哪里就够了。完成之后，也可以安心停下。'),
          const SizedBox(height: 12),
          const Text('允许留白', style: TextStyle(fontWeight: FontWeight.w700)),
          const Text('骑行、学习、陪伴和休息，都值得拥有时间。计划改变时，也允许自己调整。'),
          const SizedBox(height: 16),
          if (error != null)
            Text(error!, style: const TextStyle(color: YushiColors.danger)),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Row(
          children: [
            Expanded(
              child: MergeSemantics(
                child: InkWell(
                  onTap: saving
                      ? null
                      : () => setState(() => neverAgain = !neverAgain),
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: [
                      Checkbox(
                        value: neverAgain,
                        onChanged: saving
                            ? null
                            : (value) =>
                                  setState(() => neverAgain = value ?? false),
                      ),
                      const Flexible(
                        child: Text('以后不再提示', style: TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: saving ? null : continueToToday,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: Text(saving ? '保存中…' : '开始今天'),
            ),
          ],
        ),
      ],
    ),
  );
}

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(DateTime.now());
    final tasks = controller.forDay(today);
    final focus = controller.focusForDay(today);
    final others = tasks.where((task) => task.id != focus?.id).toList();
    final pending = tasks
        .where((task) => !controller.completed(task, today))
        .length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 34),
      children: [
        Row(
          children: [
            Text(
              _fullDate(today),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(letterSpacing: .7),
            ),
            const Spacer(),
            Text(
              '今日 / ${pending.toString().padLeft(2, '0')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: '把时间留给\n'),
              TextSpan(
                text: '在意的事。',
                style: Theme.of(
                  context,
                ).textTheme.headlineLarge?.copyWith(color: YushiColors.cobalt),
              ),
            ],
          ),
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 22),
        if (focus != null)
          FocusCard(
            task: focus,
            completed: controller.completed(focus, today),
            project: _projectName(controller.snapshot, focus),
            onComplete: () =>
                _run(context, () => controller.toggleComplete(focus, today)),
            onAdjust: () => _showAdjust(context, controller, focus, today),
          )
        else
          EmptyFocusCard(
            onAdd: () => showTaskEditor(
              context,
              controller,
              initialDate: today,
              focus: true,
            ),
          ),
        if (others.isNotEmpty) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              Text('今天还安排了', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Text(
                '${others.length} 件',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...others.map(
            (task) => TaskLine(
              task: task,
              project: _projectName(controller.snapshot, task),
              completed: controller.completed(task, today),
              onTap: () => _showTaskDetails(context, controller, task, today),
              onComplete: () =>
                  _run(context, () => controller.toggleComplete(task, today)),
            ),
          ),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () =>
              showTaskEditor(context, controller, initialDate: today),
          icon: const AppIcon(AppGlyph.add, size: 20),
          label: const Text('添加今天要做的事'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            side: const BorderSide(color: YushiColors.rule),
          ),
        ),
        const SizedBox(height: 10),
        QuickCapture(controller: controller),
        if (controller.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              controller.error!,
              style: const TextStyle(color: YushiColors.danger),
            ),
          ),
      ],
    );
  }
}

class FocusCard extends StatelessWidget {
  const FocusCard({
    super.key,
    required this.task,
    required this.completed,
    required this.project,
    required this.onComplete,
    required this.onAdjust,
  });
  final TaskItem task;
  final bool completed;
  final String project;
  final VoidCallback onComplete;
  final VoidCallback onAdjust;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 13),
    decoration: const BoxDecoration(
      color: YushiColors.focus,
      border: Border.fromBorderSide(BorderSide(color: YushiColors.rule)),
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(5),
        topRight: Radius.circular(24),
        bottomLeft: Radius.circular(5),
        bottomRight: Radius.circular(5),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              completed ? '✓' : '01',
              style: const TextStyle(
                fontFamily: null,
                fontSize: 25,
                color: YushiColors.cobalt,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                completed ? '已经完成 · $project' : '本周选定 · $project',
                style: const TextStyle(
                  fontFamily: null,
                  fontSize: 12,
                  letterSpacing: .5,
                  color: YushiColors.cobalt,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          completed ? '这一份，已经完成。' : task.title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 7),
        Text(
          completed
              ? '今天的重点可以在这里收尾。'
              : (task.note.isEmpty ? '完成这一个具体步骤，就可以收尾。' : task.note),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (!completed) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              const AppIcon(
                AppGlyph.clock,
                size: 17,
                color: YushiColors.secondary,
              ),
              const SizedBox(width: 6),
              Text(
                '约 ${task.estimateMins} 分钟 · 一次具体的推进',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onComplete,
          icon: AppIcon(
            completed ? AppGlyph.restore : AppGlyph.check,
            size: 19,
            color: Colors.white,
          ),
          label: Text(completed ? '恢复为待办' : '完成这一步'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
        ),
        TextButton(
          onPressed: onAdjust,
          child: Text(completed ? '留下下一步' : '调整今天'),
        ),
      ],
    ),
  );
}

class EmptyFocusCard extends StatelessWidget {
  const EmptyFocusCard({super.key, required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: YushiColors.focus,
      border: Border.all(color: YushiColors.rule),
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(24),
        topLeft: Radius.circular(5),
        bottomLeft: Radius.circular(5),
        bottomRight: Radius.circular(5),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '今天留白',
          style: TextStyle(
            fontFamily: null,
            fontSize: 12,
            letterSpacing: .5,
            color: YushiColors.cobalt,
          ),
        ),
        const SizedBox(height: 12),
        Text('还没有选定重点。', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 7),
        Text(
          '可以保留空白，也可以选择一件真正值得推进的事。',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const AppIcon(AppGlyph.target, color: Colors.white),
          label: const Text('选一件重点'),
        ),
      ],
    ),
  );
}

class TaskLine extends StatelessWidget {
  const TaskLine({
    super.key,
    required this.task,
    required this.project,
    required this.completed,
    required this.onTap,
    required this.onComplete,
  });
  final TaskItem task;
  final String project;
  final bool completed;
  final VoidCallback onTap;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: YushiColors.rule)),
    ),
    child: Row(
      children: [
        IconButton(
          tooltip: completed ? '恢复待办' : '完成',
          onPressed: onComplete,
          icon: completed
              ? const CircleAvatar(
                  radius: 11,
                  backgroundColor: YushiColors.cobalt,
                  child: AppIcon(AppGlyph.check, size: 15, color: Colors.white),
                )
              : Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: YushiColors.secondary),
                  ),
                ),
        ),
        Expanded(
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                decoration: completed
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: completed
                                    ? YushiColors.secondary
                                    : YushiColors.ink,
                              ),
                        ),
                      ),
                      if (task.timeMinutes != null)
                        Text(
                          _time(task.timeMinutes!),
                          style: const TextStyle(
                            fontFamily: null,
                            color: YushiColors.cobalt,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$project · 约 ${task.estimateMins} 分钟${task.deadline != null ? ' · 截止 ${_monthDay(task.deadline!)}' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class QuickCapture extends StatefulWidget {
  const QuickCapture({super.key, required this.controller});
  final AppController controller;
  @override
  State<QuickCapture> createState() => _QuickCaptureState();
}

class _QuickCaptureState extends State<QuickCapture> {
  final text = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: text,
    textInputAction: TextInputAction.done,
    onSubmitted: (_) => submit(),
    decoration: InputDecoration(
      hintText: '想到什么，先记下来…',
      prefixIcon: const Padding(
        padding: EdgeInsets.all(13),
        child: AppIcon(AppGlyph.inbox, size: 20),
      ),
      suffixIcon: TextButton(
        onPressed: busy ? null : submit,
        child: const Text('记下'),
      ),
    ),
  );
  Future<void> submit() async {
    final value = text.text.trim();
    if (value.isEmpty) return;
    setState(() => busy = true);
    try {
      await widget.controller.addInbox(value);
      text.clear();
      if (mounted) _snack(context, '已放入收集箱，安排可以以后再说');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  DateTime _anchor = dateOnly(DateTime.now());
  bool _monthly = false;

  AppController get controller => widget.controller;

  void _move(int direction) => setState(() {
    _anchor = _monthly
        ? DateTime(_anchor.year, _anchor.month + direction)
        : DateTime(_anchor.year, _anchor.month, _anchor.day + direction * 7);
  });

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(DateTime.now());
    final start = _monthly
        ? DateTime(_anchor.year, _anchor.month)
        : weekStart(
            _anchor,
            startsOn: controller.snapshot.settings.weekStartsOn,
          );
    final dayCount = _monthly
        ? DateTime(start.year, start.month + 1, 0).day
        : 7;
    final end = DateTime(start.year, start.month, start.day + dayCount);
    final isCurrent = !today.isBefore(start) && today.isBefore(end);
    final period = _monthly ? '月' : '周';
    final label = isCurrent ? '本$period' : '此$period';
    return ListView(
      key: ValueKey('${dateKey(start)}-$_monthly'),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 34),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${start.year} · 时间与生活',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final monthly in [false, true])
                      Semantics(
                        selected: _monthly == monthly,
                        button: true,
                        child: InkWell(
                          onTap: () => setState(() => _monthly = monthly),
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: Center(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _monthly == monthly
                                      ? YushiColors.focus
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  monthly ? '月' : '周',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: _monthly == monthly
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: _monthly == monthly
                                        ? YushiColors.cobalt
                                        : YushiColors.secondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: '有安排，\n'),
                  const TextSpan(
                    text: '也有余地。',
                    style: TextStyle(color: YushiColors.cobalt),
                  ),
                ],
              ),
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 10),
            Text(
              '先看真实可用的时间，再决定把这一$period交给什么。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                IconButton(
                  tooltip: '上一$period',
                  onPressed: () => _move(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    _monthly
                        ? '${start.year} 年 ${start.month} 月'
                        : '${start.month}.${start.day} — ${DateTime(start.year, start.month, start.day + 6).month}.${DateTime(start.year, start.month, start.day + 6).day}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  tooltip: '下一$period',
                  onPressed: () => _move(1),
                  icon: const Icon(Icons.chevron_right),
                ),
                TextButton(
                  onPressed: isCurrent
                      ? null
                      : () => setState(() => _anchor = today),
                  child: Text('本$period'),
                ),
              ],
            ),
            if (_monthly) ...[
              const SizedBox(height: 8),
              _MonthCalendar(
                month: start,
                selected: _anchor,
                controller: controller,
                onSelected: (day) => setState(() => _anchor = day),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (!_monthly)
                  TextButton.icon(
                    onPressed: () => _showWeekAnalysis(
                      context,
                      controller,
                      start,
                      isCurrent: isCurrent,
                    ),
                    icon: const AppIcon(AppGlyph.insights, size: 20),
                    label: Text(isCurrent ? '分析本周' : '分析此周'),
                  ),
                FilledButton.tonalIcon(
                  onPressed: () => showTaskEditor(
                    context,
                    controller,
                    initialDate: _monthly
                        ? _anchor
                        : (isCurrent ? today : start),
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    backgroundColor: YushiColors.focus,
                    foregroundColor: YushiColors.cobalt,
                  ),
                  icon: const AppIcon(AppGlyph.add, size: 20),
                  label: Text('添加$label事项'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_monthly) ...[
          Text(
            _fullDate(_anchor),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _DaySection(
            day: _anchor,
            tasks: controller.forDay(_anchor),
            controller: controller,
          ),
        ] else
          for (var i = 0; i < dayCount; i++)
            _DaySection(
              day: DateTime(start.year, start.month, start.day + i),
              tasks: controller.forDay(
                DateTime(start.year, start.month, start.day + i),
              ),
              controller: controller,
            ),
        const SizedBox(height: 16),
        Text(
          '空白，也是计划的一部分。',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: YushiColors.cobalt),
        ),
      ],
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.selected,
    required this.controller,
    required this.onSelected,
  });

  final DateTime month;
  final DateTime selected;
  final AppController controller;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final startsOn = controller.snapshot.settings.weekStartsOn;
    final offset = (month.weekday - startsOn + 7) % 7;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final rows = (offset + days + 6) ~/ 7;
    final today = dateOnly(DateTime.now());
    return Column(
      children: [
        Row(
          children: List.generate(
            7,
            (column) => Expanded(
              child: Center(
                child: Text(
                  const [
                    '一',
                    '二',
                    '三',
                    '四',
                    '五',
                    '六',
                    '日',
                  ][(startsOn - 1 + column) % 7],
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (var row = 0; row < rows; row++)
          Row(
            children: List.generate(7, (column) {
              final number = row * 7 + column - offset + 1;
              if (number < 1 || number > days) {
                return const Expanded(child: SizedBox(height: 56));
              }
              final day = DateTime(month.year, month.month, number);
              final tasks = controller.forDay(day);
              final chosen = isSameDay(day, selected);
              final isToday = isSameDay(day, today);
              final allDone =
                  tasks.isNotEmpty &&
                  tasks.every((task) => controller.completed(task, day));
              return Expanded(
                child: Semantics(
                  selected: chosen,
                  button: true,
                  label:
                      '${_fullDate(day)}，${tasks.length} 项安排${isToday ? '，今天' : ''}',
                  child: InkWell(
                    key: ValueKey('calendar-${dateKey(day)}'),
                    onTap: () => onSelected(day),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      constraints: const BoxConstraints(minHeight: 56),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: chosen ? YushiColors.cobalt : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: isToday && !chosen
                            ? Border.all(color: YushiColors.cobalt)
                            : null,
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$number',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: chosen || isToday
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: chosen ? Colors.white : YushiColors.ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            tasks.isEmpty ? '' : '${tasks.length}项',
                            style: TextStyle(
                              fontSize: 10,
                              color: chosen
                                  ? Colors.white
                                  : (allDone
                                        ? YushiColors.success
                                        : YushiColors.cobalt),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
      ],
    );
  }
}

class _WeekAnalysis {
  const _WeekAnalysis({
    required this.scheduled,
    required this.completed,
    required this.blankDays,
    this.bestDay,
    this.bestDayCompleted = 0,
  });

  final int scheduled;
  final int completed;
  final int blankDays;
  final DateTime? bestDay;
  final int bestDayCompleted;

  int get completionRate =>
      scheduled == 0 ? 0 : (completed * 100 / scheduled).round();
}

_WeekAnalysis _analyzeWeek(AppController controller, DateTime start) {
  var scheduled = 0;
  var completed = 0;
  var blankDays = 0;
  DateTime? bestDay;
  var bestDayCompleted = 0;
  for (var i = 0; i < 7; i++) {
    final day = DateTime(start.year, start.month, start.day + i);
    final taskIds = controller.forDay(day).map((task) => task.id).toSet();
    final completedIds = controller.snapshot.completions
        .where(
          (entry) =>
              isSameDay(entry.date, day) &&
              entry.status == CompletionStatus.completed,
        )
        .map((entry) => entry.taskId)
        .toSet();
    taskIds.addAll(completedIds);
    scheduled += taskIds.length;
    completed += completedIds.length;
    if (taskIds.isEmpty) blankDays++;
    if (completedIds.length > bestDayCompleted) {
      bestDay = day;
      bestDayCompleted = completedIds.length;
    }
  }
  return _WeekAnalysis(
    scheduled: scheduled,
    completed: completed,
    blankDays: blankDays,
    bestDay: bestDay,
    bestDayCompleted: bestDayCompleted,
  );
}

Future<void> _showWeekAnalysis(
  BuildContext context,
  AppController controller,
  DateTime start, {
  required bool isCurrent,
}) async {
  final analysis = _analyzeWeek(controller, start);
  final end = DateTime(start.year, start.month, start.day + 6);
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: YushiColors.background,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isCurrent ? '本周分析' : '此周分析',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '${_monthDay(start)} — ${_monthDay(end)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _AnalysisMetric(
                    value: '${analysis.scheduled}',
                    label: '安排次数',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _AnalysisMetric(
                    value: '${analysis.completed}',
                    label: '完成次数',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _AnalysisMetric(
                    value: '${analysis.completionRate}%',
                    label: '完成率',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const AppIcon(AppGlyph.insights),
              title: const Text('完成最多的一天'),
              subtitle: Text(
                analysis.bestDay == null
                    ? '还没有完成记录'
                    : '${_fullDate(analysis.bestDay!)} · 完成 ${analysis.bestDayCompleted} 项',
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const AppIcon(AppGlyph.calendar),
              title: Text('留白 ${analysis.blankDays} 天'),
              subtitle: const Text('没有安排的日子，也算在这一周里'),
            ),
            if (analysis.scheduled == 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '这一周还没有安排，可以先留白，也可以从一件小事开始。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _AnalysisMetric extends StatelessWidget {
  const _AnalysisMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
    decoration: BoxDecoration(
      color: YushiColors.paper,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: YushiColors.rule),
    ),
    child: Column(
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: YushiColors.cobalt),
        ),
        const SizedBox(height: 3),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.day,
    required this.tasks,
    required this.controller,
  });
  final DateTime day;
  final List<TaskItem> tasks;
  final AppController controller;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => showTaskEditor(context, controller, initialDate: day),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: YushiColors.rule)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _weekdayShort(day),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: isSameDay(day, DateTime.now())
                        ? YushiColors.cobalt
                        : YushiColors.ink,
                  ),
                ),
                Text(
                  '${day.day}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Expanded(
            child: tasks.isEmpty
                ? Text(
                    '留白 · 点击添加',
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final task in tasks)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: InkWell(
                            onTap: () => _showTaskDetails(
                              context,
                              controller,
                              task,
                              day,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  if (task.isFocus)
                                    const Padding(
                                      padding: EdgeInsets.only(right: 6),
                                      child: AppIcon(
                                        AppGlyph.target,
                                        size: 15,
                                        color: YushiColors.cobalt,
                                      ),
                                    ),
                                  Expanded(
                                    child: Text(
                                      task.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            decoration:
                                                controller.completed(task, day)
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                    ),
                                  ),
                                  if (task.timeMinutes != null)
                                    Text(
                                      _time(task.timeMinutes!),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          const AppIcon(
            AppGlyph.chevronRight,
            size: 18,
            color: YushiColors.secondary,
          ),
        ],
      ),
    ),
  );
}

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final projects = controller.snapshot.projects;
    final currentProjects = projects
        .where((project) => project.status != ProjectStatus.archived)
        .toList();
    final archivedProjects = projects
        .where((project) => project.status == ProjectStatus.archived)
        .toList();
    final inbox = controller.snapshot.tasks
        .where((task) => task.status == TaskStatus.inbox)
        .toList();
    final archivedTasks = controller.snapshot.tasks
        .where((task) => task.status == TaskStatus.archived)
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 34),
      children: [
        Text('选择与保留', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 13),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: '知道在做什么，\n'),
              TextSpan(
                text: '也知道为何。',
                style: Theme.of(
                  context,
                ).textTheme.headlineLarge?.copyWith(color: YushiColors.cobalt),
              ),
            ],
          ),
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 22),
        if (currentProjects.isEmpty)
          Text(
            archivedProjects.isEmpty
                ? '还没有项目。项目用来保存长期方向，今天只需要做下一步。'
                : '当前没有进行中的项目，已归档内容保留在下方。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        for (var i = 0; i < currentProjects.length; i++)
          _ProjectRow(
            project: currentProjects[i],
            index: i + 1,
            controller: controller,
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _addProject(context, controller),
          icon: const AppIcon(AppGlyph.add),
          label: const Text('新建项目'),
        ),
        if (archivedProjects.isNotEmpty) ...[
          const SizedBox(height: 10),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            leading: const AppIcon(AppGlyph.archive),
            title: Text('已归档项目（${archivedProjects.length}）'),
            subtitle: const Text('保留历史，需要时可以恢复'),
            children: [
              for (var i = 0; i < archivedProjects.length; i++)
                _ProjectRow(
                  project: archivedProjects[i],
                  index: i + 1,
                  controller: controller,
                ),
            ],
          ),
        ],
        if (archivedTasks.isNotEmpty) ...[
          const SizedBox(height: 10),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            leading: const AppIcon(AppGlyph.archive),
            title: Text('已归档任务（${archivedTasks.length}）'),
            subtitle: const Text('可以恢复，也可以永久删除'),
            children: [
              for (final task in archivedTasks)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(task.title),
                  subtitle: Text(_projectName(controller.snapshot, task)),
                  trailing: PopupMenuButton<_ArchivedTaskAction>(
                    tooltip: '管理已归档任务',
                    onSelected: (action) => _handleArchivedTaskAction(
                      context,
                      controller,
                      task,
                      action,
                    ),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: _ArchivedTaskAction.restore,
                        child: Text('恢复'),
                      ),
                      PopupMenuItem(
                        value: _ArchivedTaskAction.delete,
                        child: Text('永久删除'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 25),
        Row(
          children: [
            const AppIcon(AppGlyph.inbox, size: 20),
            const SizedBox(width: 8),
            Text('收集箱', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            Text(
              '${inbox.length}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (inbox.isEmpty)
          Text(
            '想到的事情可以先放这里，不必马上安排。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ...inbox.map(
          (task) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(task.title),
            trailing: IconButton(
              onPressed: () => _scheduleInbox(context, controller, task),
              icon: const AppIcon(AppGlyph.calendar),
            ),
          ),
        ),
      ],
    );
  }
}

enum _ProjectAction { restore, pause, archive, delete }

enum _ArchivedTaskAction { restore, delete }

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({
    required this.project,
    required this.index,
    required this.controller,
  });
  final ProjectItem project;
  final int index;
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final active = controller.snapshot.tasks
        .where(
          (task) =>
              task.projectId == project.id &&
              task.status != TaskStatus.archived,
        )
        .length;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: YushiColors.rule)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 38,
            child: Text(
              index.toString().padLeft(2, '0'),
              style: const TextStyle(
                fontFamily: null,
                fontSize: 18,
                color: YushiColors.cobalt,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (project.reason.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      '在意：${project.reason}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    '$active 个未归档任务 · ${_projectStatus(project.status)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<_ProjectAction>(
            tooltip: project.status == ProjectStatus.archived
                ? '管理已归档项目'
                : '管理项目',
            icon: const AppIcon(AppGlyph.more),
            onSelected: (action) =>
                _handleProjectAction(context, controller, project, action),
            itemBuilder: (_) => [
              if (project.status != ProjectStatus.active)
                const PopupMenuItem(
                  value: _ProjectAction.restore,
                  child: Text('恢复为进行中'),
                ),
              if (project.status != ProjectStatus.paused &&
                  project.status != ProjectStatus.archived)
                const PopupMenuItem(
                  value: _ProjectAction.pause,
                  child: Text('暂停'),
                ),
              if (project.status != ProjectStatus.archived)
                const PopupMenuItem(
                  value: _ProjectAction.archive,
                  child: Text('归档'),
                ),
              if (project.status == ProjectStatus.archived)
                const PopupMenuItem(
                  value: _ProjectAction.delete,
                  child: Text('永久删除'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class SharePlanScreen extends StatefulWidget {
  const SharePlanScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<SharePlanScreen> createState() => _SharePlanScreenState();
}

class _SharePlanScreenState extends State<SharePlanScreen> {
  final key = GlobalKey();
  bool includePrivate = false;
  bool includeTimes = true;
  bool busy = false;

  List<TaskItem> get tasks {
    final all = widget.controller.forDay(dateOnly(DateTime.now()));
    return all.where((task) => includePrivate || !task.isPrivate).toList();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('分享今日计划')),
    body: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        RepaintBoundary(
          key: key,
          child: PlanPoster(
            controller: widget.controller,
            tasks: tasks,
            includeTimes: includeTimes,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : save,
                icon: const AppIcon(AppGlyph.download),
                label: const Text('保存图片'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: busy ? null : share,
                icon: const AppIcon(AppGlyph.share, color: Colors.white),
                label: const Text('分享'),
              ),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: includeTimes,
          onChanged: (value) => setState(() => includeTimes = value),
          title: const Text('显示时间和时长'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: includePrivate,
          onChanged: (value) => setState(() => includePrivate = value),
          title: const Text('包含标记为私密的事项'),
          subtitle: const Text('默认不会分享私密事项和任务备注'),
        ),
      ],
    ),
  );

  Future<Uint8List> capture() async {
    await precacheImage(
      const AssetImage('assets/branding/app-icon.png'),
      context,
    );
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ratio = (12000 / boundary.size.height).clamp(1.0, 3.0);
    final image = await boundary.toImage(pixelRatio: ratio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('图片生成失败');
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      final bytes = await capture();
      await Gal.putImageBytes(
        bytes,
        name: '余时-今日计划-${dateKey(DateTime.now())}',
      );
      if (mounted) _snack(context, '今日计划已保存到相册');
    } catch (e) {
      if (mounted) _snack(context, '保存失败：$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> share() async {
    setState(() => busy = true);
    try {
      final bytes = await capture();
      final directory = await getTemporaryDirectory();
      final file = File(
        p.join(directory.path, '余时-今日计划-${dateKey(DateTime.now())}.png'),
      );
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(title: '余时 · 今日计划', files: [XFile(file.path)]),
      );
    } catch (e) {
      if (mounted) _snack(context, '分享面板打开失败：$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class PlanPoster extends StatelessWidget {
  const PlanPoster({
    super.key,
    required this.controller,
    required this.tasks,
    required this.includeTimes,
  });
  final AppController controller;
  final List<TaskItem> tasks;
  final bool includeTimes;
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: YushiColors.cobalt, width: 6)),
    ),
    padding: const EdgeInsets.fromLTRB(26, 28, 26, 30),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'TODAY / 今日',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 13,
                color: YushiColors.cobalt,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const Spacer(),
            Text(
              '${tasks.length.toString().padLeft(2, '0')} 件安排',
              style: const TextStyle(
                fontFamily: null,
                fontSize: 10,
                letterSpacing: 2,
                color: YushiColors.secondary,
              ),
            ),
          ],
        ),
        const Divider(height: 28, color: YushiColors.ink),
        Text('今日计划', style: Theme.of(context).textTheme.headlineMedium),
        Text(
          _fullDate(DateTime.now()),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 28),
        if (tasks.isEmpty) ...[
          Text('今天留白。', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('给自己一点从容的空间。', style: Theme.of(context).textTheme.bodyMedium),
        ] else
          for (var i = 0; i < tasks.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: YushiColors.rule)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      (i + 1).toString().padLeft(2, '0'),
                      style: const TextStyle(
                        fontFamily: null,
                        color: YushiColors.cobalt,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tasks[i].title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                decoration:
                                    controller.completed(
                                      tasks[i],
                                      DateTime.now(),
                                    )
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${tasks[i].isFocus ? '今日重点 · ' : ''}${_projectName(controller.snapshot, tasks[i])}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (includeTimes)
                          Text(
                            [
                              if (tasks[i].timeMinutes != null)
                                _time(tasks[i].timeMinutes!),
                              '约 ${tasks[i].estimateMins} 分钟',
                              controller.completed(tasks[i], DateTime.now())
                                  ? '已完成'
                                  : '待完成',
                            ].join(' · '),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        const SizedBox(height: 34),
        Text(
          '有所选择，也有所留白。',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: YushiColors.cobalt),
        ),
        const SizedBox(height: 28),
        const Divider(height: 1),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/branding/app-icon.png',
                width: 38,
                height: 38,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '余时',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '把时间留给在意的事',
                    style: TextStyle(
                      fontSize: 10,
                      color: YushiColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${dateKey(DateTime.now())}\n${_time(DateTime.now().hour * 60 + DateTime.now().minute)} 生成',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 10,
                height: 1.6,
                color: YushiColors.secondary,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? importSource;
  ImportPreview? preview;
  bool busy = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('设置与数据')),
    body: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        if (Platform.isAndroid)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const AppIcon(AppGlyph.today, color: YushiColors.cobalt),
            title: const Text('添加今日待办小组件'),
            subtitle: const Text('在桌面查看待办；事项标题会显示在桌面上'),
            onTap: () async {
              try {
                final supported = await AndroidWidget.pin();
                if (context.mounted) {
                  _snack(
                    context,
                    supported ? '请在桌面弹窗中确认添加' : '请长按桌面空白处 → 小组件 → 余时',
                  );
                }
              } catch (_) {
                if (context.mounted) _snack(context, '请长按桌面空白处 → 小组件 → 余时');
              }
            },
          ),
        Text('数据，留在自己手里。', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          '所有任务保存在本机。你可以随时导出完整 JSON 备份。',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        _SettingsAction(
          icon: AppGlyph.download,
          title: '导出完整备份',
          subtitle: '项目、任务、排期、重复规则、完成记录和设置',
          onTap: busy ? null : export,
        ),
        _SettingsAction(
          icon: AppGlyph.upload,
          title: '导入备份',
          subtitle: '先检查内容，再选择合并或完整替换',
          onTap: busy ? null : pickImport,
        ),
        if (preview != null)
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: YushiColors.focus,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('备份可导入', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 7),
                Text(
                  '新增 ${preview!.newTasks} 个任务、${preview!.newProjects} 个项目、${preview!.newCompletions} 条记录；重复 ${preview!.duplicateCount}，冲突 ${preview!.conflictCount}。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: busy ? null : () => apply(ImportMode.merge),
                  child: const Text('合并，冲突保留当前内容'),
                ),
                TextButton(
                  onPressed: busy ? null : () => apply(ImportMode.replace),
                  child: const Text('完整替换（先自动备份当前数据）'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 22),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const AppIcon(AppGlyph.today),
          title: const Text('本地提醒'),
          subtitle: const Text('提醒入口已预留；接入系统通知权限后启用'),
          trailing: Switch(value: false, onChanged: null),
        ),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: AppIcon(AppGlyph.image),
          title: Text('App 图标'),
          subtitle: Text('开放时间环 · 钴蓝与白色'),
        ),
      ],
    ),
  );

  Future<void> export() async {
    setState(() => busy = true);
    try {
      final file = await widget.controller.repository.exportBackup();
      await SharePlus.instance.share(
        ShareParams(title: '余时数据备份', files: [XFile(file.path)]),
      );
    } catch (e) {
      if (mounted) _snack(context, '备份失败：$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> pickImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null) return;
    setState(() => busy = true);
    try {
      final picked = result.files.single;
      final source = picked.bytes != null
          ? String.fromCharCodes(picked.bytes!)
          : await File(picked.path!).readAsString();
      final found = await widget.controller.repository.previewImport(source);
      setState(() {
        importSource = source;
        preview = found;
      });
    } catch (e) {
      if (mounted) _snack(context, '无法导入：$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> apply(ImportMode mode) async {
    if (importSource == null) return;
    setState(() => busy = true);
    try {
      await widget.controller.applyImport(importSource!, mode);
      if (mounted) {
        _snack(context, '导入完成');
        setState(() {
          preview = null;
          importSource = null;
        });
      }
    } catch (e) {
      if (mounted) _snack(context, '导入失败，当前数据未改变：$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class _SettingsAction extends StatelessWidget {
  const _SettingsAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final AppGlyph icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 5),
    leading: AppIcon(icon, color: YushiColors.cobalt),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const AppIcon(AppGlyph.chevronRight),
    onTap: onTap,
  );
}

Future<void> showTaskEditor(
  BuildContext context,
  AppController controller, {
  required DateTime initialDate,
  bool focus = false,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: YushiColors.background,
    builder: (_) => TaskEditorSheet(
      controller: controller,
      initialDate: initialDate,
      initialFocus: focus,
    ),
  );
}

class TaskEditorSheet extends StatefulWidget {
  const TaskEditorSheet({
    super.key,
    required this.controller,
    required this.initialDate,
    required this.initialFocus,
  });
  final AppController controller;
  final DateTime initialDate;
  final bool initialFocus;
  @override
  State<TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<TaskEditorSheet> {
  final title = TextEditingController();
  final note = TextEditingController();
  late DateTime day;
  late bool focus;
  bool private = false;
  bool busy = false;
  int estimate = 25;
  int? timeMinutes;
  String? projectId;
  RecurrenceType recurrence = RecurrenceType.none;
  @override
  void initState() {
    super.initState();
    day = dateOnly(widget.initialDate);
    focus = widget.initialFocus;
  }

  @override
  void dispose() {
    title.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      22,
      14,
      22,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: YushiColors.rule,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  '安排一件具体的事',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: busy ? null : save,
                child: Text(busy ? '保存中…' : '加入计划'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: title,
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: '要做什么'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: note,
            maxLines: 2,
            decoration: const InputDecoration(labelText: '做到哪里就够了（可选）'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const AppIcon(AppGlyph.calendar),
                  title: const Text('计划日期'),
                  subtitle: Text(_monthDay(day)),
                  onTap: pickDate,
                ),
              ),
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const AppIcon(AppGlyph.clock),
                  title: const Text('时间'),
                  subtitle: Text(
                    timeMinutes == null ? '不限定' : _time(timeMinutes!),
                  ),
                  onTap: pickTime,
                ),
              ),
            ],
          ),
          DropdownButtonFormField<int>(
            initialValue: estimate,
            decoration: const InputDecoration(labelText: '预计时长'),
            items: const [10, 15, 25, 30, 45, 60, 90]
                .map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text('$value 分钟')),
                )
                .toList(),
            onChanged: (value) => setState(() => estimate = value ?? 25),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: projectId,
            decoration: const InputDecoration(labelText: '所属项目（可选）'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('无项目')),
              ...widget.controller.snapshot.projects
                  .where((project) => project.status == ProjectStatus.active)
                  .map(
                    (project) => DropdownMenuItem<String?>(
                      value: project.id,
                      child: Text(project.title),
                    ),
                  ),
            ],
            onChanged: (value) => setState(() => projectId = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<RecurrenceType>(
            initialValue: recurrence,
            decoration: const InputDecoration(labelText: '重复'),
            items: const [
              DropdownMenuItem(value: RecurrenceType.none, child: Text('不重复')),
              DropdownMenuItem(value: RecurrenceType.daily, child: Text('每天')),
              DropdownMenuItem(
                value: RecurrenceType.weekdays,
                child: Text('工作日'),
              ),
              DropdownMenuItem(
                value: RecurrenceType.weeklyTarget,
                child: Text('每周一次'),
              ),
            ],
            onChanged: (value) =>
                setState(() => recurrence = value ?? RecurrenceType.none),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('设为当天重点'),
            subtitle: const Text('当天只突出一件重点，其他安排仍会显示'),
            value: focus,
            onChanged: (value) => setState(() => focus = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('私密事项'),
            subtitle: const Text('生成分享图片时默认隐藏'),
            value: private,
            onChanged: (value) => setState(() => private = value),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  Future<void> pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: day,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (value != null) setState(() => day = value);
  }

  Future<void> pickTime() async {
    final value = await showTimePicker(
      context: context,
      initialTime: timeMinutes == null
          ? TimeOfDay.now()
          : TimeOfDay(hour: timeMinutes! ~/ 60, minute: timeMinutes! % 60),
    );
    if (value != null) {
      setState(() => timeMinutes = value.hour * 60 + value.minute);
    }
  }

  Future<void> save() async {
    if (title.text.trim().isEmpty) {
      _snack(context, '请先写下要做什么');
      return;
    }
    setState(() => busy = true);
    try {
      await widget.controller.addTask(
        title: title.text,
        note: note.text,
        plannedDate: day,
        projectId: projectId,
        timeMinutes: timeMinutes,
        estimateMins: estimate,
        isFocus: focus,
        isPrivate: private,
        recurrence: RecurrenceRule(type: recurrence, weeklyTarget: 1),
      );
      if (mounted) {
        _snack(context, '已加入 ${_monthDay(day)}的计划');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _snack(context, '保存失败：$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

Future<void> _showTaskDetails(
  BuildContext context,
  AppController controller,
  TaskItem task,
  DateTime day,
) async {
  final pageContext = context;
  var busy = false;
  String? failure;
  final completed = controller.completed(task, day);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: YushiColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) {
        Future<void> perform(Future<void> Function() action) async {
          if (busy) return;
          setSheetState(() {
            busy = true;
            failure = null;
          });
          try {
            await action();
            if (sheetContext.mounted) Navigator.pop(sheetContext);
          } catch (_) {
            if (sheetContext.mounted)
              setSheetState(() {
                busy = false;
                failure = '保存失败，请重试';
              });
          }
        }

        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: completed
                            ? YushiColors.success.withValues(alpha: 0.08)
                            : YushiColors.focus,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        completed ? '已完成' : '待完成',
                        style: TextStyle(
                          color: completed
                              ? YushiColors.success
                              : YushiColors.cobalt,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: '关闭事项详情',
                      onPressed: busy
                          ? null
                          : () => Navigator.pop(sheetContext),
                      icon: const AppIcon(AppGlyph.close, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  task.title,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(fontSize: 26),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: YushiColors.background,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _fullDate(day),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        [
                          _projectName(controller.snapshot, task),
                          if (task.timeMinutes != null)
                            _time(task.timeMinutes!),
                          '约 ${task.estimateMins} 分钟',
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (task.note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(task.note),
                  ),
                if (failure != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      failure!,
                      style: const TextStyle(color: YushiColors.danger),
                    ),
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: busy
                        ? null
                        : () => perform(
                            () => controller.toggleComplete(task, day),
                          ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: AppIcon(
                      completed ? AppGlyph.restore : AppGlyph.check,
                      size: 22,
                    ),
                    label: Text(busy ? '保存中…' : (completed ? '撤销完成' : '标记完成')),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: busy
                            ? null
                            : () => perform(() => controller.archiveTask(task)),
                        style: TextButton.styleFrom(
                          foregroundColor: YushiColors.secondary,
                        ),
                        icon: const AppIcon(AppGlyph.archive, size: 20),
                        label: const Text('归档'),
                      ),
                    ),
                    Container(height: 18, width: 1, color: YushiColors.rule),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: busy
                            ? null
                            : () async {
                                Navigator.pop(sheetContext);
                                // Use the page context after the sheet closes.
                                await _confirmDeleteTask(
                                  pageContext,
                                  controller,
                                  task,
                                );
                              },
                        style: TextButton.styleFrom(
                          foregroundColor: YushiColors.danger,
                        ),
                        icon: const AppIcon(
                          AppGlyph.delete,
                          color: YushiColors.danger,
                        ),
                        label: const Text('永久删除'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Future<void> _showAdjust(
  BuildContext context,
  AppController controller,
  TaskItem task,
  DateTime day,
) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: YushiColors.background,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        22,
        22,
        MediaQuery.viewInsetsOf(sheetContext).bottom + 22,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('按今天的实际情况', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            '可以改到明天，或者今天先放下。真实截止日期不会被改变。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 15),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const AppIcon(AppGlyph.calendar),
            title: const Text('改到明天'),
            onTap: () async {
              await controller.postpone(task, day.add(const Duration(days: 1)));
              if (sheetContext.mounted) Navigator.pop(sheetContext);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const AppIcon(AppGlyph.archive),
            title: const Text('暂时放下'),
            subtitle: const Text('归档任务，以后仍可在备份中保留'),
            onTap: () async {
              try {
                await controller.archiveTask(task);
                if (sheetContext.mounted) {
                  _snack(sheetContext, '已归档任务，记录仍然保留');
                  Navigator.pop(sheetContext);
                }
              } catch (error) {
                if (sheetContext.mounted) {
                  _snack(sheetContext, '归档失败：$error');
                }
              }
            },
          ),
          InputDecorator(
            decoration: const InputDecoration(labelText: '下次从哪里继续？'),
            child: Text(task.note.isEmpty ? '还没有记录' : task.note),
          ),
        ],
      ),
    ),
  );
}

Future<void> _addProject(BuildContext context, AppController controller) =>
    showDialog<void>(
      context: context,
      builder: (_) => _AddProjectDialog(controller: controller),
    );

class _AddProjectDialog extends StatefulWidget {
  const _AddProjectDialog({required this.controller});

  final AppController controller;

  @override
  State<_AddProjectDialog> createState() => _AddProjectDialogState();
}

class _AddProjectDialogState extends State<_AddProjectDialog> {
  final title = TextEditingController();
  final reason = TextEditingController();
  bool saving = false;

  @override
  void dispose() {
    title.dispose();
    reason.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (title.text.trim().isEmpty || saving) return;
    setState(() => saving = true);
    try {
      await widget.controller.addProject(title.text, reason.text);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() => saving = false);
        _snack(context, '创建失败：$error');
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('新建项目'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: title,
          autofocus: true,
          decoration: const InputDecoration(labelText: '项目名称'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: reason,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => save(),
          decoration: const InputDecoration(labelText: '为什么在意它（可选）'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: saving ? null : save,
        child: Text(saving ? '保存中…' : '创建'),
      ),
    ],
  );
}

Future<void> _handleProjectAction(
  BuildContext context,
  AppController controller,
  ProjectItem project,
  _ProjectAction action,
) async {
  if (action == _ProjectAction.delete) {
    await _confirmDeleteProject(context, controller, project);
    return;
  }
  final status = switch (action) {
    _ProjectAction.restore => ProjectStatus.active,
    _ProjectAction.pause => ProjectStatus.paused,
    _ProjectAction.archive => ProjectStatus.archived,
    _ProjectAction.delete => throw StateError('删除操作应单独处理'),
  };
  try {
    await controller.updateProject(
      project.copyWith(status: status, updatedAt: DateTime.now()),
    );
    if (context.mounted) {
      final message = switch (status) {
        ProjectStatus.active => '项目已恢复',
        ProjectStatus.paused => '项目已暂停',
        ProjectStatus.archived => '项目已归档，可从“已归档项目”恢复',
      };
      _snack(context, message);
    }
  } catch (error) {
    if (context.mounted) _snack(context, '操作失败：$error');
  }
}

Future<void> _confirmDeleteProject(
  BuildContext context,
  AppController controller,
  ProjectItem project,
) async {
  final taskIds = controller.snapshot.tasks
      .where((task) => task.projectId == project.id)
      .map((task) => task.id)
      .toSet();
  final recordCount = controller.snapshot.completions
      .where((entry) => taskIds.contains(entry.taskId))
      .length;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('永久删除“${project.title}”？'),
      content: Text('将同时删除 ${taskIds.length} 条任务和 $recordCount 条完成记录。此操作无法撤销。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: FilledButton.styleFrom(backgroundColor: YushiColors.danger),
          child: const Text('永久删除'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await controller.deleteProject(project);
    if (messenger.mounted) {
      messenger.showSnackBar(const SnackBar(content: Text('项目及关联记录已删除')));
    }
  } catch (error) {
    if (messenger.mounted) {
      messenger.showSnackBar(SnackBar(content: Text('删除失败：$error')));
    }
  }
}

Future<void> _handleArchivedTaskAction(
  BuildContext context,
  AppController controller,
  TaskItem task,
  _ArchivedTaskAction action,
) async {
  if (action == _ArchivedTaskAction.delete) {
    await _confirmDeleteTask(context, controller, task);
    return;
  }
  try {
    await controller.restoreTask(task);
    if (context.mounted) _snack(context, '任务已恢复');
  } catch (error) {
    if (context.mounted) _snack(context, '恢复失败：$error');
  }
}

Future<void> _confirmDeleteTask(
  BuildContext context,
  AppController controller,
  TaskItem task,
) async {
  final recordCount = controller.snapshot.completions
      .where((entry) => entry.taskId == task.id)
      .length;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('永久删除“${task.title}”？'),
      content: Text('将同时删除 $recordCount 条完成记录。此操作无法撤销。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: FilledButton.styleFrom(backgroundColor: YushiColors.danger),
          child: const Text('永久删除'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await controller.deleteTask(task);
    if (messenger.mounted) {
      messenger.showSnackBar(const SnackBar(content: Text('任务及完成记录已删除')));
    }
  } catch (error) {
    if (messenger.mounted) {
      messenger.showSnackBar(SnackBar(content: Text('删除失败：$error')));
    }
  }
}

Future<void> _scheduleInbox(
  BuildContext context,
  AppController controller,
  TaskItem task,
) async {
  final today = dateOnly(DateTime.now());
  final tasks = controller.snapshot.tasks
      .map(
        (item) => item.id == task.id
            ? item.copyWith(
                status: TaskStatus.planned,
                plannedDate: today,
                updatedAt: DateTime.now(),
              )
            : item,
      )
      .toList();
  await controller.repository.save(controller.snapshot.copyWith(tasks: tasks));
  await controller.initialize();
  if (context.mounted) _snack(context, '已安排到今天');
}

Future<void> _run(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } catch (e) {
    if (context.mounted) _snack(context, '操作失败：$e');
  }
}

void _snack(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));

String _projectName(AppSnapshot snapshot, TaskItem task) {
  if (task.projectId == null) {
    return task.recurrence.type == RecurrenceType.none ? '个人' : '长期计划';
  }
  for (final project in snapshot.projects) {
    if (project.id == task.projectId) return project.title;
  }
  return '项目';
}

String _projectStatus(ProjectStatus status) => switch (status) {
  ProjectStatus.active => '进行中',
  ProjectStatus.paused => '已暂停',
  ProjectStatus.archived => '已归档',
};
String _time(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
String _monthDay(DateTime value) => '${value.month} 月 ${value.day} 日';
String _weekdayShort(DateTime value) =>
    const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][value.weekday - 1];
String _fullDate(DateTime value) =>
    '${value.month} 月 ${value.day} 日 · ${_weekdayShort(value)}';
