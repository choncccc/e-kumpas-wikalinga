import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/lesson_models.dart';
import '../../data/study_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../lessons/category_screen.dart' show LessonBackButton;
import '../onboarding/widgets/step_parts.dart' show formatLongDate;

/// Everything the learner opened or tapped on this device, newest first,
/// grouped by day. Can be copied as text or cleared.
class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({
    super.key,
    required this.study,
    this.clock = DateTime.now,
  });

  final StudyRepository study;
  final DateTime Function() clock;

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  List<ActivityEntry>? _entries;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await widget.study.activity();
    if (mounted) setState(() => _entries = entries);
  }

  static String _time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}';

  static String _date(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';

  String _dayLabel(DateTime day) {
    final now = widget.clock();
    final today = DateTime(now.year, now.month, now.day);
    final days = today.difference(day).inDays;
    if (days == 0) return 'Today';
    if (days == 1) return 'Yesterday';
    return formatLongDate(day);
  }

  Future<void> _copy() async {
    final entries = _entries ?? const [];
    final text = [
      for (final e in entries.reversed)
        ['${_date(e.at)} ${_time(e.at)}', e.action, ?e.detail].join('\t'),
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Copied ${entries.length} entries')));
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear activity log?'),
        content: const Text(
          'This deletes every entry on this device. It can’t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Clear',
              style: TextStyle(color: AppColors.coral),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.study.clearActivity();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    final top = MediaQuery.paddingOf(context).top;
    final empty = entries != null && entries.isEmpty;

    // Day headings between rows.
    final rows = <Widget>[];
    DateTime? day;
    for (final e in entries ?? const <ActivityEntry>[]) {
      final d = DateTime(e.at.year, e.at.month, e.at.day);
      if (d != day) {
        day = d;
        rows.add(_DayHeading(_dayLabel(d)));
      }
      rows.add(_EntryRow(entry: e, time: _time(e.at)));
    }

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Column(
        children: [
          Container(
            color: AppColors.mist,
            padding: EdgeInsets.fromLTRB(16, top + 10, 8, 12),
            child: Row(
              children: [
                LessonBackButton(onTap: () => Navigator.of(context).maybePop()),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Activity log',
                    style: TextStyle(
                      fontFamily: AppFonts.display,
                      fontWeight: FontWeight.w900,
                      fontSize: 26,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy as text',
                  onPressed: entries == null || empty ? null : _copy,
                  icon: const Icon(Icons.copy_rounded, color: AppColors.teal),
                ),
                IconButton(
                  tooltip: 'Clear log',
                  onPressed: entries == null || empty ? null : _clear,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.coral,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: entries == null
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.teal),
                  )
                : empty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Nothing logged yet. Opening the app, lessons, signs, '
                        'quizzes and games will show up here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.slate),
                      ),
                    ),
                  )
                : RefreshIndicator(
                    color: AppColors.teal,
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: EdgeInsets.fromLTRB(
                        16,
                        8,
                        16,
                        24 + MediaQuery.paddingOf(context).bottom,
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                          child: Text(
                            '${entries.length} entries, newest first. '
                            'Stored only on this device.',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.slate,
                            ),
                          ),
                        ),
                        ...rows,
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DayHeading extends StatelessWidget {
  const _DayHeading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: AppFonts.display,
          fontWeight: FontWeight.w700,
          fontSize: 17,
          color: AppColors.teal,
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.time});

  final ActivityEntry entry;
  final String time;

  static IconData _icon(String action) {
    final a = action.toLowerCase();
    if (a.startsWith('app ')) return Icons.phone_android_rounded;
    if (a.contains('quiz')) return Icons.quiz_rounded;
    if (a.contains('memory') || a.contains('card flip')) {
      return Icons.style_rounded;
    }
    if (a.contains('bookmark')) return Icons.bookmark_rounded;
    if (a.contains('sign')) return Icons.sign_language_rounded;
    if (a.contains('search')) return Icons.search_rounded;
    if (a.contains('tab')) return Icons.tab_rounded;
    if (a.contains('profile')) return Icons.person_rounded;
    return Icons.open_in_new_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final detail = entry.detail;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 66,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                time,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.slate,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          Icon(_icon(entry.action), size: 18, color: AppColors.seafoam),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.action,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.ink,
                  ),
                ),
                if (detail != null && detail.isNotEmpty)
                  Text(
                    detail,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.slate,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
