import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/learning_content.dart';
import '../../data/lesson_models.dart';
import '../../data/lesson_repository.dart';
import '../../data/study_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pressable.dart';
import '../lessons/bookmarked_keys.dart';
import '../lessons/sign_entry_tile.dart';

/// Explore tab: search every sign, or browse all topics when the box is empty.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({
    super.key,
    required this.lessons,
    required this.study,
    required this.searchFocus,
  });

  final LessonRepository lessons;
  final StudyRepository study;

  /// Owned by the shell so the home search bar can focus it.
  final FocusNode searchFocus;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with BookmarkedKeys<ExploreScreen> {
  final _query = TextEditingController();
  Timer? _debounce;

  /// The query [_results] belong to; null while nothing has been searched.
  String? _resultsFor;
  List<SignEntry> _results = const [];
  late final Future<List<(LessonCategory, List<LessonTopic>)>> _browse =
      _loadBrowse();

  @override
  StudyRepository get study => widget.study;

  @override
  void initState() {
    super.initState();
    _query.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<List<(LessonCategory, List<LessonTopic>)>> _loadBrowse() async => [
    for (final c in LearningContent.categories)
      (c, await widget.lessons.topicsFor(c.id)),
  ];

  void _onQueryChanged() {
    _debounce?.cancel();
    final q = _query.text.trim();
    if (q.isEmpty) {
      setState(() {
        _resultsFor = null;
        _results = const [];
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 180), () => _search(q));
  }

  Future<void> _search(String q) async {
    final results = await widget.lessons.search(q);
    // Ignore a slow answer to a query the user has already changed.
    if (!mounted || _query.text.trim() != q) return;
    setState(() {
      _resultsFor = q;
      _results = results;
    });
  }

  void _open(String categoryId, int topicId, [String? signKey]) {
    widget.searchFocus.unfocus();
    openTopic(
      context,
      lessons: widget.lessons,
      study: widget.study,
      categoryId: categoryId,
      topicId: topicId,
      signKey: signKey,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = 120 + MediaQuery.paddingOf(context).bottom;
    final searching = _query.text.trim().isNotEmpty;

    return ColoredBox(
      color: AppColors.cream,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Explore',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Find any sign, phrase or medical term.',
                    style: TextStyle(fontSize: 14, color: AppColors.slate),
                  ),
                  const SizedBox(height: 16),
                  _SearchField(
                    controller: _query,
                    focusNode: widget.searchFocus,
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                child: searching ? _buildResults(bottom) : _buildBrowse(bottom),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(double bottom) {
    final q = _resultsFor;
    if (q == null) {
      return const Center(
        key: ValueKey('searching'),
        child: CircularProgressIndicator(color: AppColors.teal),
      );
    }
    if (_results.isEmpty) {
      return ListView(
        key: const ValueKey('empty'),
        padding: EdgeInsets.fromLTRB(32, 48, 32, bottom),
        children: [
          const Icon(Icons.search_off_rounded, size: 56, color: AppColors.sage),
          const SizedBox(height: 12),
          Text(
            'No signs match “$q”.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppFonts.display,
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try a shorter word, like “pain” or “water”.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.slate),
          ),
        ],
      );
    }
    return ListView.separated(
      key: const ValueKey('results'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottom),
      itemCount: _results.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i == 0) {
          final n = _results.length;
          return Text(
            '$n ${n == 1 ? 'sign' : 'signs'}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.sage,
            ),
          );
        }
        final e = _results[i - 1];
        return SignEntryTile(
          entry: e,
          highlight: q,
          bookmarked: isBookmarked(e.sign.key),
          onBookmark: () => toggleBookmark(e.sign.key),
          onTap: () => _open(e.categoryId, e.topicId, e.sign.key),
        );
      },
    );
  }

  Widget _buildBrowse(double bottom) {
    return FutureBuilder(
      key: const ValueKey('browse'),
      future: _browse,
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(child: Text('Couldn’t load the lessons.'));
        }
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.teal),
          );
        }
        return ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, 20, 20, bottom),
          children: [
            for (final (category, topics) in snap.data!) ...[
              Row(
                children: [
                  Icon(category.icon, color: category.color, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      category.fullTitle,
                      style: const TextStyle(
                        fontFamily: AppFonts.display,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in topics)
                    _TopicChip(
                      topic: t,
                      color: category.color,
                      onTap: () => _open(category.id, t.id),
                    ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ],
        );
      },
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.fromLTRB(5, 5, 8, 5),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: AppColors.mustard, width: 1.6),
        boxShadow: [
          BoxShadow(
            color: AppColors.mustard.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: AppColors.mustard,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_rounded,
              color: AppColors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 15, color: AppColors.ink),
              decoration: const InputDecoration(
                hintText: 'Search the terminology here…',
                hintStyle: TextStyle(fontSize: 15, color: AppColors.slate),
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => controller.text.isEmpty
                ? const SizedBox.shrink()
                : Semantics(
                    button: true,
                    label: 'Clear search',
                    excludeSemantics: true,
                    child: Pressable(
                      onTap: controller.clear,
                      scale: 0.85,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.close_rounded,
                          color: AppColors.slate,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TopicChip extends StatelessWidget {
  const _TopicChip({
    required this.topic,
    required this.color,
    required this.onTap,
  });

  final LessonTopic topic;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = topic.signs.length;
    return Semantics(
      button: true,
      label: '${topic.title}, $n signs',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        scale: 0.94,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: color.withValues(alpha: 0.55),
              width: 1.4,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  topic.title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$n',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
