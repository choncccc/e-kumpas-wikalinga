import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Stand-in for tabs that aren't built yet.
class ComingSoonTab extends StatelessWidget {
  const ComingSoonTab({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ColoredBox(
      color: AppColors.cream,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 100),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.butter,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Icon(icon, size: 48, color: AppColors.teal),
                ),
                const SizedBox(height: 20),
                Text(title, style: text.headlineLarge),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: text.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
