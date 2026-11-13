enum VideoPreset {
  whatsappStatus('WhatsApp Status', '720p, balanced quality and size', 720, 2000000),
  tiktok('TikTok', '1080p, high quality for vertical video', 1080, 5000000),
  maxSaving('Max saving', '480p, smallest file', 480, 1000000);

  const VideoPreset(this.title, this.description, this.targetShortSide, this.bitrate);

  final String title;
  final String description;

  /// Short side of the output in pixels (never upscaled).
  final int targetShortSide;

  /// Maximum video bitrate in bits per second.
  final int bitrate;
}

class VideoInfo {
  const VideoInfo({required this.width, required this.height, required this.durationMs, required this.bitrate, required this.size});
  final int width;
  final int height;
  final int durationMs;
  final int bitrate;
  final int size;
}

class CompressionResult {
  const CompressionResult({required this.outputPath, required this.size});
  final String outputPath;
  final int size;
}
