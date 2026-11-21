import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/pressable.dart';

/// Ribbon toggle that pops when a sign is saved.
class BookmarkButton extends StatelessWidget {
  const BookmarkButton({
    super.key,
    required this.term,
    required this.bookmarked,
    required this.onTap,
    this.color = AppColors.teal,
  });

  final String term;
  final bool bookmarked;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: bookmarked,
      label: bookmarked ? 'Remove $term from bookmarks' : 'Bookmark $term',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        scale: 0.8,
        child: SizedBox(
          width: 44,
          height: 44,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
              child: child,
            ),
            child: Icon(
              bookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              key: ValueKey(bookmarked),
              color: bookmarked ? AppColors.mustard : color,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}
