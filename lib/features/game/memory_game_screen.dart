import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/lesson_repository.dart';
import '../../data/study_repository.dart';
import '../../data/user_profile.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pressable.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/sign_media.dart';
import '../lessons/category_screen.dart' show LessonBackButton;
import 'memory_game.dart';
import 'memory_levels.dart';

/// Memory Card Flip from the mockup: match each blue sign card with the
/// green card that says what it means, ten pairs per level, two minutes on
/// the clock. Clearing a level unlocks the next one.
class MemoryGameScreen extends StatefulWidget {
  const MemoryGameScreen({
    super.key,
    required this.profile,
    required this.lessons,
    required this.study,
    this.random,
    this.timeLimit = const Duration(minutes: 2),
    this.levelSpecs = memoryLevelSpecs,
  });

  final UserProfile profile;
  final LessonRepository lessons;
  final StudyRepository study;
  final Random? random;
  final Duration timeLimit;
  final List<(String, List<MemoryItem>)> levelSpecs;

  @override
  State<MemoryGameScreen> createState() => _MemoryGameScreenState();
}

enum _Phase { loading, empty, playing, cleared, timeUp }

class _MemoryGameScreenState extends State<MemoryGameScreen> {
  static const _mismatchShown = Duration(milliseconds: 1600);

  _Phase _phase = _Phase.loading;
  List<MemoryLevel> _levels = const [];
  Map<int, Duration> _best = const {};
  MemoryGame? _game;
  late Duration _remaining;
  bool _started = false;
  bool _newBest = false;
  Timer? _clock;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _clock?.cancel();
    _hide?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final signs = await widget.lessons.allSigns();
    final best = await widget.study.gameLevels();
    if (!mounted) return;
    _levels = resolveMemoryLevels(signs, specs: widget.levelSpecs);
    _best = best;
    if (_levels.isEmpty) {
      setState(() => _phase = _Phase.empty);
      return;
    }
    // Pick up at the first level not cleared yet.
    final next = _levels.firstWhere(
      (l) => !_best.containsKey(l.number),
      orElse: () => _levels.last,
    );
    _startLevel(next);
  }

  bool _unlocked(MemoryLevel l) =>
      l.number == 1 || _best.containsKey(l.number - 1);

  void _startLevel(MemoryLevel level) {
    _clock?.cancel();
    _hide?.cancel();
    setState(() {
      _game = MemoryGame(level, random: widget.random);
      _remaining = widget.timeLimit;
      _started = false;
      _newBest = false;
      _phase = _Phase.playing;
    });
  }

  void _tick() {
    if (!mounted || _phase != _Phase.playing) return;
    final next = _remaining - const Duration(seconds: 1);
    if (next <= Duration.zero) {
      _clock?.cancel();
      _hide?.cancel();
      setState(() {
        _remaining = Duration.zero;
        _phase = _Phase.timeUp;
      });
      HapticFeedback.heavyImpact();
    } else {
      setState(() => _remaining = next);
    }
  }

  void _flip(int index) {
    final game = _game;
    if (game == null || _phase != _Phase.playing) return;
    if (!_started) {
      // The clock starts with the first card, not when the screen opens.
      _started = true;
      _clock = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
    _hide?.cancel();
    final result = game.flip(index);
    switch (result) {
      case FlipResult.ignored:
        return;
      case FlipResult.flipped:
        HapticFeedback.selectionClick();
      case FlipResult.matched:
        HapticFeedback.lightImpact();
      case FlipResult.mismatched:
        _hide = Timer(_mismatchShown, () {
          if (!mounted) return;
          setState(game.hideMismatch);
        });
    }
    setState(() {});
    if (game.isComplete) _clear(game);
  }

  Future<void> _clear(MemoryGame game) async {
    _clock?.cancel();
    final time = widget.timeLimit - _remaining;
    final number = game.level.number;
    final previous = _best[number];
    setState(() {
      _phase = _Phase.cleared;
      _newBest = previous == null || time < previous;
      if (_newBest) _best = {..._best, number: time};
    });
    await widget.study.saveGameLevel(number, time);
  }

  MemoryLevel? get _nextLevel {
    final game = _game;
    if (game == null) return null;
    return _levels.where((l) => l.number == game.level.number + 1).firstOrNull;
  }

  Future<void> _pickLevel() async {
    final picked = await showModalBottomSheet<MemoryLevel>(
      context: context,
      backgroundColor: AppColors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _LevelSheet(
        levels: _levels,
        best: _best,
        current: _game?.level.number,
        unlocked: _unlocked,
      ),
    );
    if (picked != null && mounted) _startLevel(picked);
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    switch (_phase) {
      case _Phase.loading:
        body = const Center(
          child: CircularProgressIndicator(color: AppColors.teal),
        );
      case _Phase.empty:
        body = const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'The game needs the sign videos, and none are available.',
              textAlign: TextAlign.center,
            ),
          ),
        );
      case _Phase.playing || _Phase.cleared || _Phase.timeUp:
        body = _buildGame(_game!);
    }
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Column(
        children: [
          _Header(profile: widget.profile),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _buildGame(MemoryGame game) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final over = _phase != _Phase.playing;
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 4, 14, 12 + bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              decoration: BoxDecoration(
                color: AppColors.iceMint,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.seafoam, width: 2),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _Pill(
                        onTap: _pickLevel,
                        semanticLabel:
                            'Level ${game.level.number}, ${game.level.title}. '
                            'Change level',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Level ${_roman(game.level.number)}'),
                            const SizedBox(width: 2),
                            const Icon(
                              Icons.arrow_drop_down_rounded,
                              color: AppColors.white,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _Pill(
                            icon: Icons.schedule_rounded,
                            semanticLabel:
                                'Time remaining ${_clockText(_remaining)}',
                            child: Text(
                              'Time Remaining: ${_clockText(_remaining)}',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 22,
                    child: Text(
                      _started
                          ? game.level.title
                          : 'Tap a card to start the clock',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.sage,
                      ),
                    ),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      child: over
                          ? _Result(
                              key: ValueKey(_phase),
                              cleared: _phase == _Phase.cleared,
                              found: game.found.length,
                              total: game.level.pairs.length,
                              time: widget.timeLimit - _remaining,
                              tries: game.tries,
                              newBest: _newBest,
                              best: _best[game.level.number],
                              level: game.level,
                              next: _phase == _Phase.cleared
                                  ? _nextLevel
                                  : null,
                              onReplay: () => _startLevel(game.level),
                              onNext: (l) => _startLevel(l),
                            )
                          : _Board(
                              key: ValueKey(game),
                              game: game,
                              onFlip: _flip,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _FoundTray(game: game),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: _NewGameButton(onTap: () => _startLevel(game.level)),
          ),
        ],
      ),
    );
  }
}

String _clockText(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

String _roman(int n) =>
    const [
      'I',
      'II',
      'III',
      'IV',
      'V',
      'VI',
      'VII',
      'VIII',
      'IX',
      'X',
    ].elementAtOrNull(n - 1) ??
    '$n';

class _Header extends StatelessWidget {
  const _Header({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      color: AppColors.mist,
      padding: EdgeInsets.fromLTRB(16, top + 10, 16, 12),
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          LessonBackButton(onTap: () => Navigator.of(context).maybePop()),
          const SizedBox(width: 12),
          ProfileAvatar(
            nickname: profile.nickname,
            photoPath: profile.photoPath,
            size: 40,
            ring: false,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'Memory Card Flip Game',
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dark green pill for the level and timer, as in the mockup.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.child,
    required this.semanticLabel,
    this.icon,
    this.onTap,
  });

  final Widget child;
  final String semanticLabel;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.forest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppColors.white, size: 16),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: DefaultTextStyle.merge(
                style: const TextStyle(
                  fontFamily: AppFonts.display,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                  color: AppColors.white,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      excludeSemantics: true,
      child: onTap == null
          ? pill
          : Pressable(onTap: onTap!, scale: 0.95, child: pill),
    );
  }
}

/// The cards, sized so every row fits without scrolling.
class _Board extends StatelessWidget {
  const _Board({super.key, required this.game, required this.onFlip});

  final MemoryGame game;
  final ValueChanged<int> onFlip;

  static const _cols = 4;
  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    final rows = (game.cards.length / _cols).ceil();
    return LayoutBuilder(
      builder: (context, box) {
        final w = (box.maxWidth - _gap * (_cols - 1)) / _cols;
        final h = min((box.maxHeight - _gap * (rows - 1)) / rows, w * 1.6);
        return Center(
          child: Wrap(
            spacing: _gap,
            runSpacing: _gap,
            children: [
              for (var i = 0; i < game.cards.length; i++)
                SizedBox(
                  key: ValueKey('memory-card-$i'),
                  width: w,
                  height: h,
                  child: _FlipCard(
                    card: game.cards[i],
                    pair: game.level.pairs[game.cards[i].pair],
                    faceUp: game.isFaceUp(i),
                    matched: game.isMatched(i),
                    onTap: () => onFlip(i),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _FlipCard extends StatelessWidget {
  const _FlipCard({
    required this.card,
    required this.pair,
    required this.faceUp,
    required this.matched,
    required this.onTap,
  });

  final MemoryCard card;
  final MemoryPair pair;
  final bool faceUp;
  final bool matched;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final kind = card.isSign ? 'Sign card' : 'Meaning card';
    final String label;
    if (!faceUp) {
      label = '$kind, face down';
    } else if (card.isSign) {
      label = matched ? 'Matched sign: ${pair.label}' : 'Sign card, showing';
    } else {
      label = matched
          ? 'Matched: ${pair.label}'
          : 'Meaning card: ${pair.label}';
    }
    return Semantics(
      button: !faceUp,
      label: label,
      excludeSemantics: true,
      // Long-press a face-up sign card to watch it large; it doesn't count
      // as a move.
      onLongPressHint: faceUp && card.isSign ? 'Watch larger' : null,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: faceUp && card.isSign
            ? () => _showLarge(context, pair, revealed: matched)
            : null,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: faceUp ? 1 : 0),
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 380),
          curve: Curves.easeInOutCubic,
          builder: (context, t, _) {
            final showFront = t >= 0.5;
            // Turn about the vertical axis; the front is drawn after the
            // half-way point, mirrored back so it reads the right way.
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0015)
                ..rotateY(pi * t),
              child: showFront
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationY(pi),
                      child: _CardFront(
                        card: card,
                        pair: pair,
                        matched: matched,
                      ),
                    )
                  : _CardBack(isSign: card.isSign),
            );
          },
        ),
      ),
    );
  }
}

/// The card's sign, big enough to follow the handshape. The meaning is only
/// shown once the pair is matched, so peeking doesn't give it away.
void _showLarge(
  BuildContext context,
  MemoryPair pair, {
  required bool revealed,
}) {
  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: AppColors.white,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Same framing as the cards: a white margin round a rounded panel,
          // with the clip or photo fitted whole inside it.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ColoredBox(
                  color: _blue[0].withValues(alpha: 0.2),
                  child: SignMedia(
                    asset: pair.sign.media,
                    label: revealed ? 'How to sign ${pair.label}' : 'Sign card',
                    color: Colors.transparent,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    revealed
                        ? [pair.label, ?pair.sign.tagalog].join(' · ')
                        : 'Which green card means this?',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.forest,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// White margin between a card's border and its picture or text.
const _mediaInset = 5.0;

const _blue = [Color(0xFF62D2D6), Color(0xFF2F8FA0)];
const _green = [Color(0xFFA6DFA3), Color(0xFF6DB582)];

class _CardBack extends StatelessWidget {
  const _CardBack({required this.isSign});

  final bool isSign;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isSign ? _blue : _green,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.slate.withValues(alpha: 0.18),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(6),
            // Different marks, not just colours: a hand for the sign cards,
            // letters for the meaning cards.
            child: isSign
                ? Icon(
                    Icons.back_hand_rounded,
                    size: 40,
                    color: AppColors.white.withValues(alpha: 0.9),
                  )
                : Text(
                    'Aa',
                    style: TextStyle(
                      fontFamily: AppFonts.display,
                      fontWeight: FontWeight.w700,
                      fontSize: 30,
                      color: AppColors.white.withValues(alpha: 0.92),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _CardFront extends StatelessWidget {
  const _CardFront({
    required this.card,
    required this.pair,
    required this.matched,
  });

  final MemoryCard card;
  final MemoryPair pair;
  final bool matched;

  @override
  Widget build(BuildContext context) {
    final colors = card.isSign ? _blue : _green;
    final Widget face;
    if (card.isSign) {
      // Only cards being looked at play; matched ones settle on a still so
      // the board isn't running ten videos. Clips, photos and stills all sit
      // in the same padded, rounded panel, fitted whole (not cropped), so
      // every card has the same white margin whatever the media's shape.
      final panel = colors[0].withValues(alpha: 0.2);
      face = ColoredBox(
        color: AppColors.white,
        child: Padding(
          padding: const EdgeInsets.all(_mediaInset),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: ColoredBox(
              color: panel,
              child: matched
                  ? Image.asset(
                      pair.sign.poster!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    )
                  : SignMedia(
                      asset: pair.sign.media,
                      label: 'Sign card',
                      showControls: false,
                      // The panel already provides the backdrop.
                      color: Colors.transparent,
                    ),
            ),
          ),
        ),
      );
    } else {
      face = ColoredBox(
        color: AppColors.white,
        child: Padding(
          padding: const EdgeInsets.all(_mediaInset + 1),
          child: Center(
            child: Text(
              pair.label,
              textAlign: TextAlign.center,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                height: 1.15,
                color: AppColors.forest,
              ),
            ),
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors[1], width: 3),
        color: colors[0],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedOpacity(
              opacity: matched ? 0.6 : 1,
              duration: const Duration(milliseconds: 250),
              child: face,
            ),
            if (card.isSign && !matched)
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  margin: const EdgeInsets.all(_mediaInset + 2),
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.zoom_in_rounded,
                    size: 14,
                    color: AppColors.teal,
                  ),
                ),
              ),
            if (matched)
              const Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: EdgeInsets.all(_mediaInset - 1),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.forest,
                    size: 20,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Found matches": each pair found so far, newest first, with its Tagalog.
class _FoundTray extends StatelessWidget {
  const _FoundTray({required this.game});

  final MemoryGame game;

  @override
  Widget build(BuildContext context) {
    final found = game.found.reversed.toList();
    return Container(
      height: 104,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: AppColors.iceMint,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.seafoam, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.forest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'FOUND MATCHES  ${game.found.length}/${game.level.pairs.length}',
              style: const TextStyle(
                fontFamily: AppFonts.display,
                fontWeight: FontWeight.w600,
                fontSize: 11.5,
                letterSpacing: 0.4,
                color: AppColors.white,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: found.isEmpty
                ? const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Match a blue sign card with the green card that says '
                      'what it means.',
                      style: TextStyle(fontSize: 12.5, color: AppColors.slate),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: found.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final pair = game.level.pairs[found[i]];
                      return _FoundChip(key: ValueKey(found[i]), pair: pair);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FoundChip extends StatelessWidget {
  const _FoundChip({super.key, required this.pair});

  final MemoryPair pair;

  @override
  Widget build(BuildContext context) {
    final tagalog = pair.sign.tagalog;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: MediaQuery.of(context).disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      builder: (context, s, child) => Transform.scale(scale: s, child: child),
      child: Container(
        width: 168,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.leaf, width: 1.5),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 46,
                height: double.infinity,
                child: Image.asset(
                  pair.sign.poster!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const ColoredBox(color: AppColors.seafoam),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pair.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      height: 1.15,
                      color: AppColors.forest,
                    ),
                  ),
                  if (tagalog != null)
                    Text(
                      tagalog,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: AppColors.slate,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewGameButton extends StatelessWidget {
  const _NewGameButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'New game',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: AppColors.mustard,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.olive,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text(
              'NEW GAME',
              style: TextStyle(
                fontFamily: AppFonts.display,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: 0.6,
                color: AppColors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown in place of the board when a level ends.
class _Result extends StatelessWidget {
  const _Result({
    super.key,
    required this.cleared,
    required this.found,
    required this.total,
    required this.time,
    required this.tries,
    required this.newBest,
    required this.best,
    required this.level,
    required this.next,
    required this.onReplay,
    required this.onNext,
  });

  final bool cleared;
  final int found;
  final int total;
  final Duration time;
  final int tries;
  final bool newBest;
  final Duration? best;
  final MemoryLevel level;
  final MemoryLevel? next;
  final VoidCallback onReplay;
  final ValueChanged<MemoryLevel> onNext;

  @override
  Widget build(BuildContext context) {
    final String title;
    final String detail;
    if (cleared) {
      title = 'Level ${_roman(level.number)} cleared!';
      detail =
          'All $total pairs in ${_clockText(time)}, $tries tries.'
          '${newBest
              ? '\nNew best time!'
              : best == null
              ? ''
              : '\nBest: ${_clockText(best!)}'}'
          '${next == null ? '\nThat was the last level.' : ''}';
    } else {
      title = 'Time’s up';
      detail = 'You found $found of $total pairs. Try again?';
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              cleared ? Icons.emoji_events_rounded : Icons.hourglass_bottom,
              size: 64,
              color: cleared ? AppColors.mustard : AppColors.sage,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppFonts.display,
                fontWeight: FontWeight.w700,
                fontSize: 26,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14.5,
                height: 1.4,
                color: AppColors.slate,
              ),
            ),
            const SizedBox(height: 20),
            if (next != null) ...[
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                ),
                onPressed: () => onNext(next!),
                child: Text(
                  'Next: Level ${_roman(next!.number)} · ${next!.title}',
                ),
              ),
              const SizedBox(height: 8),
            ],
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.teal,
                side: const BorderSide(color: AppColors.teal, width: 1.5),
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
              ),
              onPressed: onReplay,
              child: Text(cleared ? 'Play this level again' : 'Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelSheet extends StatelessWidget {
  const _LevelSheet({
    required this.levels,
    required this.best,
    required this.current,
    required this.unlocked,
  });

  final List<MemoryLevel> levels;
  final Map<int, Duration> best;
  final int? current;
  final bool Function(MemoryLevel) unlocked;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Text(
              'Choose a level',
              style: TextStyle(
                fontFamily: AppFonts.display,
                fontWeight: FontWeight.w700,
                fontSize: 22,
                color: AppColors.ink,
              ),
            ),
          ),
          for (final l in levels)
            Builder(
              builder: (context) {
                final open = unlocked(l);
                final time = best[l.number];
                return ListTile(
                  enabled: open,
                  selected: l.number == current,
                  selectedTileColor: AppColors.iceMint,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: open ? AppColors.forest : AppColors.cloud,
                    foregroundColor: AppColors.white,
                    child: Text(
                      _roman(l.number),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  title: Text(
                    l.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    !open
                        ? 'Clear level ${_roman(l.number - 1)} to unlock'
                        : time == null
                        ? '${l.pairs.length} pairs'
                        : 'Cleared · best ${_clockText(time)}',
                  ),
                  trailing: Icon(
                    !open
                        ? Icons.lock_rounded
                        : time != null
                        ? Icons.check_circle_rounded
                        : Icons.play_circle_rounded,
                    color: open ? AppColors.teal : AppColors.cloud,
                  ),
                  onTap: open ? () => Navigator.of(context).pop(l) : null,
                );
              },
            ),
        ],
      ),
    );
  }
}
