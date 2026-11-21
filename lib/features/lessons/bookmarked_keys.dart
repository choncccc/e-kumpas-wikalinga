import 'package:flutter/widgets.dart';

import '../../data/study_repository.dart';

/// Keeps a screen's set of bookmarked sign keys in sync with the repository,
/// with optimistic toggling.
mixin BookmarkedKeys<T extends StatefulWidget> on State<T> {
  StudyRepository get study;

  Set<String> _bookmarked = const {};

  bool isBookmarked(String signKey) => _bookmarked.contains(signKey);

  @override
  void initState() {
    super.initState();
    study.addListener(_reloadBookmarks);
    _reloadBookmarks();
  }

  @override
  void dispose() {
    study.removeListener(_reloadBookmarks);
    super.dispose();
  }

  Future<void> _reloadBookmarks() async {
    final keys = await study.bookmarkedKeys();
    if (mounted) setState(() => _bookmarked = keys);
    onBookmarksChanged();
  }

  /// Called after every reload, for screens that list the bookmarks.
  void onBookmarksChanged() {}

  void toggleBookmark(String signKey) {
    final on = !_bookmarked.contains(signKey);
    setState(
      () => _bookmarked = on
          ? {..._bookmarked, signKey}
          : ({..._bookmarked}..remove(signKey)),
    );
    study.setBookmarked(signKey, on);
  }
}
