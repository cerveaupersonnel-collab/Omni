import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/media_gateway.dart';
import '../utils/format.dart';

class MediaThumb extends ConsumerStatefulWidget {
  const MediaThumb({super.key, required this.item, this.radius = 16});
  final MediaItem item;
  final double radius;

  @override
  ConsumerState<MediaThumb> createState() => _MediaThumbState();
}

class _MediaThumbState extends ConsumerState<MediaThumb> {
  late Future<Uint8List?> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(mediaGatewayProvider).thumbnail(widget.item);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<Uint8List?>(
            future: _future,
            builder: (context, snap) {
              final bytes = snap.data;
              if (bytes != null) return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
              return Container(
                color: Colors.white10,
                child: Icon(widget.item.isVideo ? Icons.movie_rounded : Icons.image_rounded, color: Colors.white38),
              );
            },
          ),
          if (widget.item.isVideo)
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_arrow_rounded, size: 14),
                    Text(formatDuration(Duration(milliseconds: widget.item.durationMs)), style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
