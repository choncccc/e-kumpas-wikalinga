import 'package:flutter/material.dart';

/// Fades and slides its children up one after another when first built.
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({
    super.key,
    required this.children,
    this.delay = Duration.zero,
    this.stagger = const Duration(milliseconds: 70),
    this.itemDuration = const Duration(milliseconds: 520),
    this.offset = 28,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  final List<Widget> children;
  final Duration delay;
  final Duration stagger;
  final Duration itemDuration;
  final double offset;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  Duration get _total =>
      widget.delay +
      widget.stagger * (widget.children.length - 1).clamp(0, 1 << 20) +
      widget.itemDuration;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _total)..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = _total.inMicroseconds.toDouble();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: widget.crossAxisAlignment,
      children: [
        for (var i = 0; i < widget.children.length; i++) _item(i, totalMs),
      ],
    );
  }

  Widget _item(int i, double totalMs) {
    final start = (widget.delay + widget.stagger * i).inMicroseconds / totalMs;
    final end = start + widget.itemDuration.inMicroseconds / totalMs;
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        start.clamp(0, 1),
        end.clamp(0, 1),
        curve: Curves.easeOutCubic,
      ),
    );
    return AnimatedBuilder(
      animation: curved,
      child: widget.children[i],
      builder: (context, child) => Opacity(
        opacity: curved.value,
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - curved.value)),
          child: child,
        ),
      ),
    );
  }
}
