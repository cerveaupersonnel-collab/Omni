import 'dart:math' as math;

import 'package:flutter/material.dart';

class DonutSegment {
  const DonutSegment(this.value, this.color);
  final double value;
  final Color color;
}

class StorageDonut extends StatelessWidget {
  const StorageDonut({super.key, required this.segments, required this.centerTop, required this.centerBottom});

  final List<DonutSegment> segments;
  final String centerTop;
  final String centerBottom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 190,
      height: 190,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (_, t, __) => CustomPaint(size: const Size(190, 190), painter: _DonutPainter(segments, t)),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(centerTop, style: theme.textTheme.titleLarge),
              Text(centerBottom, style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.segments, this.progress);
  final List<DonutSegment> segments;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 24.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final total = segments.fold<double>(0, (a, s) => a + s.value);
    if (total <= 0) return;
    const gap = 0.03;
    var start = -math.pi / 2;
    for (final s in segments) {
      if (s.value <= 0) continue;
      final sweep = (s.value / total) * 2 * math.pi * progress;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = s.color;
      canvas.drawArc(rect, start, math.max(0.0, sweep - gap), false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.progress != progress || old.segments != segments;
}
