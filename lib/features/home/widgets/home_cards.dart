import 'package:flutter/material.dart';

import '../../../data/learning_content.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/media_placeholder.dart';
import '../../../widgets/pressable.dart';

/// Search pill from the mockup: white with a mustard outline and a mustard
/// circle holding the magnifier. Tapping opens the Explore tab.
class HomeSearchBar extends StatelessWidget {
  const HomeSearchBar({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Search the terminology',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        scale: 0.98,
        child: Container(
          height: 54,
          padding: const EdgeInsets.all(5),
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
              const Expanded(
                child: Text(
                  'Search the terminology here…',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, color: AppColors.ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the six lesson-category tiles.
class CategoryTile extends StatelessWidget {
  const CategoryTile({super.key, required this.category, required this.onTap});

  final LessonCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: category.title,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: Hero(
          tag: 'category-${category.id}',
          // Fly a plain coloured card; the tile and the header lay out their
          // contents differently, so morphing the box alone looks cleanest.
          flightShuttleBuilder: (_, _, _, _, _) => Material(
            color: category.color,
            borderRadius: BorderRadius.circular(20),
          ),
          child: _TileFace(category: category),
        ),
      ),
    );
  }
}

class _TileFace extends StatelessWidget {
  const _TileFace({required this.category});

  final LessonCategory category;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: category.color,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(category.icon, color: AppColors.white, size: 38),
            const SizedBox(height: 4),
            Text(
              category.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: AppColors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card with an image slot and a cream caption pill (the Quiz and Games
/// cards), or just the image slot when [title] is null. The image is a
/// placeholder until the real artwork is added.
class FeatureCard extends StatelessWidget {
  const FeatureCard({
    super.key,
    required this.semanticLabel,
    this.placeholderColor = AppColors.seafoam,
    this.placeholderLabel,
    this.title,
    this.subtitle,
    this.onTap,
  });

  final String semanticLabel;
  final Color placeholderColor;
  final String? placeholderLabel;
  final String? title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        scale: 0.96,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              MediaPlaceholder(
                color: placeholderColor,
                label: placeholderLabel,
                compact: title != null,
                // With a caption, keep the icon clear of the pill.
                iconAlignment: title == null
                    ? Alignment.center
                    : Alignment.topRight,
              ),
              if (title != null)
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                    padding: const EdgeInsets.fromLTRB(12, 7, 12, 8),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.cream,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                            color: AppColors.ink,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.slate,
                            ),
                          ),
                      ],
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
