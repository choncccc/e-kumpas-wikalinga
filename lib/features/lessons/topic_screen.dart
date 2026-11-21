import 'package:flutter/material.dart';

import '../../data/learning_content.dart';
import '../../data/lesson_models.dart';
import '../../data/study_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pressable.dart';
import '../../widgets/sign_media.dart';
import '../../widgets/staggered_entrance.dart';
import 'bookmark_button.dart';
import 'bookmarked_keys.dart';
import 'category_screen.dart';

/// Signs in one topic as an accordion, after the "Alphabets" mockup. One sign
/// is open at a time; opening another closes the previous one. Opening a
/// sign counts it as studied.
class TopicScreen extends StatefulWidget {
  const TopicScreen({
    super.key,
    required this.category,
    required this.topic,
    required this.study,
    this.initialSignKey,
  });

  final LessonCategory category;
  final LessonTopic topic;
  final StudyRepository study;

  /// Sign to open (and scroll to) first, e.g. from search or bookmarks.
  final String? initialSignKey;

  @override
  State<TopicScreen> createState() => _TopicScreenState();
}

class _TopicScreenState extends State<TopicScreen>
    with BookmarkedKeys<TopicScreen> {
  late int? _open;
  final _openKey = GlobalKey();

  @override
  StudyRepository get study => widget.study;

  @override
  void initState() {
    super.initState();
    final signs = widget.topic.signs;
    final i = signs.indexWhere((s) => s.key == widget.initialSignKey);
    _open = signs.isEmpty ? null : (i < 0 ? 0 : i);
    _markOpenViewed();
    if (i > 0) {
      // Wait for the entrance animation to lay the list out, then scroll.
      Future.delayed(const Duration(milliseconds: 450), () {
        final ctx = _openKey.currentContext;
        if (mounted && ctx != null && ctx.mounted) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            alignment: 0.1,
          );
        }
      });
    }
  }

  void _markOpenViewed() {
    final i = _open;
    if (i != null) widget.study.markViewed(widget.topic.signs[i].key);
  }

  void _toggle(int i) {
    setState(() => _open = _open == i ? null : i);
    _markOpenViewed();
  }

  @override
  Widget build(BuildContext context) {
    final topic = widget.topic;
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            Row(
              children: [
                LessonBackButton(onTap: () => Navigator.of(context).maybePop()),
                const SizedBox(width: 12),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.mustard,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      topic.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppFonts.display,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        color: AppColors.ink,
                        height: 1.15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (topic.tagalog != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        topic.tagalog!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: AppColors.teal,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  Text(
                    '${widget.category.fullTitle} · ${topic.signs.length} '
                    '${topic.signs.length == 1 ? 'sign' : 'signs'}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.sage,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            StaggeredEntrance(
              delay: const Duration(milliseconds: 100),
              stagger: const Duration(milliseconds: 40),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < topic.signs.length; i++)
                  Padding(
                    key: _open == i ? _openKey : null,
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SignTile(
                      sign: topic.signs[i],
                      open: _open == i,
                      onToggle: () => _toggle(i),
                      bookmarked: isBookmarked(topic.signs[i].key),
                      onBookmark: () => toggleBookmark(topic.signs[i].key),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SignTile extends StatelessWidget {
  const SignTile({
    super.key,
    required this.sign,
    required this.open,
    required this.onToggle,
    required this.bookmarked,
    required this.onBookmark,
  });

  final Sign sign;
  final bool open;
  final VoidCallback onToggle;
  final bool bookmarked;
  final VoidCallback onBookmark;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: AppColors.iceMint,
        borderRadius: BorderRadius.circular(open ? 30 : 34),
        border: Border.all(color: AppColors.seafoam, width: 2),
        boxShadow: [
          if (open)
            BoxShadow(
              color: AppColors.seafoam.withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (open)
              AspectRatio(
                aspectRatio: 16 / 10,
                child: SignMedia(
                  asset: sign.media,
                  label: 'How to sign ${sign.term}',
                ),
              ),
            // The expand button and the bookmark are siblings, not nested,
            // so each is its own tap target and screen-reader button.
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    expanded: open,
                    label: sign.tagalog == null
                        ? sign.term
                        : '${sign.term}, in Filipino: ${sign.tagalog}',
                    excludeSemantics: true,
                    child: Pressable(
                      onTap: onToggle,
                      scale: 0.98,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 10, 0, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sign.term,
                                    style: const TextStyle(
                                      fontFamily: AppFonts.display,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 20,
                                      color: AppColors.teal,
                                      height: 1.2,
                                    ),
                                  ),
                                  if (sign.tagalog != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        sign.tagalog!,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontStyle: FontStyle.italic,
                                          color: AppColors.slate,
                                          height: 1.25,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            AnimatedRotation(
                              turns: open ? 0.5 : 0,
                              duration: const Duration(milliseconds: 320),
                              curve: Curves.easeOutBack,
                              child: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: AppColors.teal,
                                size: 34,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: BookmarkButton(
                    term: sign.term,
                    bookmarked: bookmarked,
                    onTap: onBookmark,
                  ),
                ),
              ],
            ),
            if (open) _Details(sign: sign),
          ],
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.sign});

  final Sign sign;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      if (sign.signOrder != null)
        _DetailRow(
          icon: Icons.format_list_numbered_rounded,
          label: 'Sign order',
          value: sign.signOrder!,
        ),
      if (sign.facialExpression != null)
        _DetailRow(
          icon: Icons.face_rounded,
          label: 'Facial expression',
          value: sign.facialExpression!,
        ),
      if (sign.signOrder == null &&
          sign.facialExpression == null &&
          sign.media == null)
        const _DetailRow(
          icon: Icons.back_hand_rounded,
          label: 'How to sign',
          value: 'Handshape, position and movement notes will appear here.',
          muted: true,
        ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.sage),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: value),
                ],
              ),
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: muted
                    ? AppColors.slate.withValues(alpha: 0.6)
                    : AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
