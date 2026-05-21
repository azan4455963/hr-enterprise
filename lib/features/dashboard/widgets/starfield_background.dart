import 'dart:math';

import 'package:flutter/material.dart';

class StarfieldBackground extends StatelessWidget {
  const StarfieldBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(decoration: BoxDecoration(gradient: _gradient)),
        const _StarsLayer(),
        child,
      ],
    );
  }
}

const _gradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF0D0D2B), Color(0xFF1A1A5E), Color(0xFF0D2D5E)],
  stops: [0.0, 0.4, 1.0],
);

class _StarsLayer extends StatelessWidget {
  const _StarsLayer();

  static final _stars = List.generate(60, (i) {
    final r = Random(i);
    return (
      left: r.nextDouble(),
      top: r.nextDouble(),
      size: r.nextDouble() * 2 + 1,
      opacity: r.nextDouble() * 0.4 + 0.1,
    );
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, size) {
          return Stack(
            children: [
              for (final s in _stars)
                Positioned(
                  left: s.left * size.maxWidth,
                  top: s.top * size.maxHeight,
                  child: Container(
                    width: s.size,
                    height: s.size,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: s.opacity),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
