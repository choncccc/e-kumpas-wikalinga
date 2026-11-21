import 'package:flutter/material.dart';

import '../../data/lesson_models.dart';
import '../../data/lesson_repository.dart';
import '../../data/study_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../lessons/bookmarked_keys.dart';
import '../lessons/sign_entry_tile.dart';

/// Bookmark tab: every saved sign, newest first.
class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({
    super.key,
    required this.lessons,
    required this.study,
    required this.onExplore,
  });

  final LessonRepository lessons;
  final StudyRepository study;
  final VoidCallback onExplore;

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen>
    with BookmarkedKeys<BookmarksScreen> {
  List<SignEntry>? _entries;

  @override
  StudyRepository get study => widget.study;

  @override
  void onBookmarksChanged() => _load();

  Future<void> _load() async {
    final entries = await widget.study.bookmarks();
    if (mounted) setState(() => _entries = entries);
  }

  void _remove(SignEntry e) {
    toggleBookmark(e.sign.key);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Removed “${e.sign.term}”.'),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 110),
          action: SnackBarAction(
            label: 'Undo',
            textColor: AppColors.mustard,
            onPressed: () => widget.study.setBookmarked(e.sign.key, true),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = 120 + MediaQuery.paddingOf(context).bottom;
    final entries = _entries;

    return ColoredBox(
      color: AppColors.cream,
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bookmarks',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entries == null || entries.isEmpty
                          ? 'Signs you save show up here.'
                          : '${entries.length} saved '
                                '${entries.length == 1 ? 'sign' : 'signs'}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.slate,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (entries == null)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.teal),
                ),
              )
            else if (entries.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyBookmarks(
                  onExplore: widget.onExplore,
                  bottom: bottom,
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, bottom),
                sliver: SliverList.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final e = entries[i];
                    return SignEntryTile(
                      key: ValueKey(e.sign.key),
                      entry: e,
                      bookmarked: isBookmarked(e.sign.key),
                      onBookmark: () => _remove(e),
                      onTap: () => openTopic(
                        context,
                        lessons: widget.lessons,
                        study: widget.study,
                        categoryId: e.categoryId,
                        topicId: e.topicId,
                        signKey: e.sign.key,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBookmarks extends StatelessWidget {
  const _EmptyBookmarks({required this.onExplore, required this.bottom});

  final VoidCallback onExplore;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(32, 0, 32, bottom),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.butter,
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Icon(
              Icons.bookmark_add_rounded,
              size: 48,
              color: AppColors.teal,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Nothing saved yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.display,
              fontWeight: FontWeight.w700,
              fontSize: 24,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the bookmark on any sign to keep it here for quick review.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: AppColors.slate, height: 1.4),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onExplore,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.teal,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            ),
            icon: const Icon(Icons.search_rounded),
            label: const Text('Find signs'),
          ),
        ],
      ),
    );
  }
}
