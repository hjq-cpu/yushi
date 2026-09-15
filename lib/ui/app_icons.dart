import 'package:flutter/material.dart';

/// 余时的功能图标表。界面只通过语义名称取图标，便于保持统一。
enum AppGlyph {
  today,
  week,
  projects,
  inbox,
  add,
  check,
  close,
  back,
  share,
  settings,
  clock,
  calendar,
  bike,
  book,
  more,
  download,
  upload,
  archive,
  edit,
  restore,
  target,
  pause,
  play,
  chevronRight,
  image,
  delete,
  insights,
}

class AppIcon extends StatelessWidget {
  const AppIcon(this.glyph, {super.key, this.size = 24, this.color});

  final AppGlyph glyph;
  final double size;
  final Color? color;

  static const Map<AppGlyph, IconData> _icons = {
    AppGlyph.today: Icons.wb_sunny_outlined,
    AppGlyph.week: Icons.calendar_view_week_outlined,
    AppGlyph.projects: Icons.layers_outlined,
    AppGlyph.inbox: Icons.inbox_outlined,
    AppGlyph.add: Icons.add_rounded,
    AppGlyph.check: Icons.check_rounded,
    AppGlyph.close: Icons.close_rounded,
    AppGlyph.back: Icons.arrow_back_ios_new_rounded,
    AppGlyph.share: Icons.ios_share_outlined,
    AppGlyph.settings: Icons.tune_rounded,
    AppGlyph.clock: Icons.schedule_outlined,
    AppGlyph.calendar: Icons.calendar_today_outlined,
    AppGlyph.bike: Icons.directions_bike_outlined,
    AppGlyph.book: Icons.menu_book_outlined,
    AppGlyph.more: Icons.more_horiz_rounded,
    AppGlyph.download: Icons.download_rounded,
    AppGlyph.upload: Icons.upload_rounded,
    AppGlyph.archive: Icons.archive_outlined,
    AppGlyph.edit: Icons.edit_outlined,
    AppGlyph.restore: Icons.restore_rounded,
    AppGlyph.target: Icons.track_changes_rounded,
    AppGlyph.pause: Icons.pause_rounded,
    AppGlyph.play: Icons.play_arrow_rounded,
    AppGlyph.chevronRight: Icons.chevron_right_rounded,
    AppGlyph.image: Icons.image_outlined,
    AppGlyph.delete: Icons.delete_outline_rounded,
    AppGlyph.insights: Icons.insights_rounded,
  };

  @override
  Widget build(BuildContext context) => Icon(
    _icons[glyph],
    size: size,
    color: color,
    opticalSize: size,
    weight: 400,
  );
}
