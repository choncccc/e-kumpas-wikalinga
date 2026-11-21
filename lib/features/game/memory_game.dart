import 'dart:math';

import 'memory_levels.dart';

/// A card on the board: the blue side of a pair shows the sign, the green
/// side shows what it means.
class MemoryCard {
  const MemoryCard({required this.pair, required this.isSign});

  /// Index into [MemoryLevel.pairs].
  final int pair;

  /// Blue sign card (true) or green meaning card (false).
  final bool isSign;
}

enum FlipResult {
  /// Nothing happened: the card is already up or matched, or the game is over.
  ignored,

  /// First card of a try is up.
  flipped,

  /// Second card made a pair; both stay up.
  matched,

  /// Second card didn't match. Both stay up until [MemoryGame.hideMismatch]
  /// or the next flip, so the player can look at them.
  mismatched,
}

/// Rules of Memory Card Flip, without any UI: flip two cards, keep them if
/// they are the sign and the meaning of the same word.
class MemoryGame {
  MemoryGame(this.level, {Random? random})
    : cards = [
        for (var i = 0; i < level.pairs.length; i++) ...[
          MemoryCard(pair: i, isSign: true),
          MemoryCard(pair: i, isSign: false),
        ],
      ]..shuffle(random ?? Random());

  final MemoryLevel level;
  final List<MemoryCard> cards;

  final List<int> _up = [];
  final List<int> _found = [];
  int _tries = 0;

  /// Indices of unmatched cards that are face up (at most two).
  List<int> get faceUp => List.unmodifiable(_up);

  /// Pairs found, in the order they were found.
  List<int> get found => List.unmodifiable(_found);

  /// Completed tries (two cards turned).
  int get tries => _tries;

  bool get isComplete => _found.length == level.pairs.length;

  /// Whether two non-matching cards are waiting to be turned back.
  bool get hasMismatch => _up.length == 2;

  bool isMatched(int index) => _found.contains(cards[index].pair);

  bool isFaceUp(int index) => isMatched(index) || _up.contains(index);

  FlipResult flip(int index) {
    if (isComplete || isFaceUp(index)) return FlipResult.ignored;
    // Turning a new card puts a shown mismatch away first.
    if (hasMismatch) _up.clear();
    _up.add(index);
    if (_up.length == 1) return FlipResult.flipped;

    _tries++;
    final a = cards[_up[0]], b = cards[_up[1]];
    if (a.pair == b.pair) {
      _found.add(a.pair);
      _up.clear();
      return FlipResult.matched;
    }
    return FlipResult.mismatched;
  }

  void hideMismatch() {
    if (hasMismatch) _up.clear();
  }
}
