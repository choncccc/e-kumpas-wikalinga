import 'package:flutter/material.dart';

import '../../data/learning_content.dart';
import '../../data/lesson_models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/media_placeholder.dart';
import '../../widgets/pressable.dart';
import '../../widgets/staggered_entrance.dart';
import 'category_screen.dart';

/// Signs in one topic as an accordion, after the "Alphabets" mockup. One sign
/// is open at a time; opening another closes the previous one.
class TopicScreen extends StatefulWidget {
  const TopicScreen({super.key, required this.category, required this.topic});

  final LessonCategory category;
  final LessonTopic topic;

  @override
  State<TopicScreen> createState() => _TopicScreenState();
}

class _TopicScreenState extends State<TopicScreen> {
  int? _open = 0;

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
              child: Text(
                '${widget.category.fullTitle} · ${topic.signs.length} '
                '${topic.signs.length == 1 ? 'sign' : 'signs'}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.sage,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            StaggeredEntrance(
              delay: const Duration(milliseconds: 100),
              stagger: const Duration(milliseconds: 40),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < topic.signs.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SignTile(
                      sign: topic.signs[i],
                      open: _open == i,
                      onToggle: () =>
                          setState(() => _open = _open == i ? null : i),
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
  });

  final Sign sign;
  final bool open;
  final VoidCallback onToggle;

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
              const AspectRatio(
                aspectRatio: 16 / 10,
                child: MediaPlaceholder(
                  kind: MediaKind.video,
                  color: AppColors.seafoam,
                ),
              ),
            Semantics(
              button: true,
              expanded: open,
              label: sign.term,
              excludeSemantics: true,
              child: Pressable(
                onTap: onToggle,
                scale: 0.98,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 16, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          sign.term,
                          style: const TextStyle(
                            fontFamily: AppFonts.display,
                            fontWeight: FontWeight.w600,
                            fontSize: 20,
                            color: AppColors.teal,
                            height: 1.2,
                          ),
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
      if (sign.signOrder == null && sign.facialExpression == null)
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
