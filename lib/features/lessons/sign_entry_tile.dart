import 'package:flutter/material.dart';

import '../../data/learning_content.dart';
import '../../data/lesson_models.dart';
import '../../data/lesson_repository.dart';
import '../../data/study_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pressable.dart';
import 'bookmark_button.dart';
import 'topic_screen.dart';

/// Opens a topic's sign list, optionally with one sign already open.
Future<void> openTopic(
  BuildContext context, {
  required LessonRepository lessons,
  required StudyRepository study,
  required String categoryId,
  required int topicId,
  String? signKey,
}) async {
  final topic = await lessons.topic(topicId);
  if (!context.mounted) return;
  if (topic == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('That lesson is no longer available.')),
    );
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute(
      settings: RouteSettings(name: 'Topic', arguments: topic.title),
      builder: (_) => TopicScreen(
        category: LearningContent.byId(categoryId),
        topic: topic,
        study: study,
        initialSignKey: signKey,
      ),
    ),
  );
}

/// One sign in a flat list (search results, bookmarks): the term, where it
/// lives, and a bookmark toggle. Tapping opens it inside its topic.
class SignEntryTile extends StatelessWidget {
  const SignEntryTile({
    super.key,
    required this.entry,
    required this.bookmarked,
    required this.onTap,
    required this.onBookmark,
    this.highlight = '',
  });

  final SignEntry entry;
  final bool bookmarked;
  final VoidCallback onTap;
  final VoidCallback onBookmark;

  /// Text to emphasise in the term, e.g. the search query.
  final String highlight;

  @override
  Widget build(BuildContext context) {
    final category = LearningContent.byId(entry.categoryId);
    final sign = entry.sign;
    // The open button and the bookmark are siblings, so each is its own tap
    // target and screen-reader button.
    return Container(
      decoration: BoxDecoration(
        color: AppColors.iceMint,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.seafoam.withValues(alpha: 0.7),
          width: 1.4,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: [
                sign.term,
                if (sign.tagalog != null) 'in Filipino: ${sign.tagalog}',
                category.title,
                entry.topicTitle,
              ].join(', '),
              excludeSemantics: true,
              child: Pressable(
                onTap: onTap,
                scale: 0.98,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: category.color,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          category.icon,
                          color: AppColors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _HighlightedText(
                              text: sign.term,
                              highlight: highlight,
                              style: const TextStyle(
                                fontFamily: AppFonts.display,
                                fontWeight: FontWeight.w600,
                                fontSize: 17,
                                color: AppColors.teal,
                                height: 1.2,
                              ),
                            ),
                            if (sign.tagalog != null)
                              _HighlightedText(
                                text: sign.tagalog!,
                                highlight: highlight,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontStyle: FontStyle.italic,
                                  color: AppColors.slate,
                                  height: 1.25,
                                ),
                              ),
                            const SizedBox(height: 2),
                            Text(
                              '${category.title} · ${entry.topicTitle}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.sage,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (sign.signOrder != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  sign.signOrder!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    letterSpacing: 0.3,
                                    color: AppColors.slate,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: BookmarkButton(
              term: sign.term,
              bookmarked: bookmarked,
              onTap: onBookmark,
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightedText extends StatelessWidget {
  const _HighlightedText({
    required this.text,
    required this.highlight,
    required this.style,
  });

  final String text;
  final String highlight;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final words = highlight
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map(RegExp.escape)
        .toList();
    if (words.isEmpty) return Text(text, style: style);

    final pattern = RegExp(words.join('|'), caseSensitive: false);
    final spans = <TextSpan>[];
    var last = 0;
    for (final m in pattern.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      spans.add(
        TextSpan(
          text: m[0],
          style: const TextStyle(
            backgroundColor: AppColors.butter,
            color: AppColors.ink,
          ),
        ),
      );
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(TextSpan(children: spans), style: style);
  }
}
