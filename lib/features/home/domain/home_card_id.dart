import 'package:flutter/material.dart';

enum HomeCardId {
  scan('Omni Scan', 'Scan, crop and extract text', Icons.document_scanner_rounded, 'scan'),
  chatPdf('Chat with PDF', 'Ask questions about any PDF', Icons.picture_as_pdf_rounded, 'chat_pdf'),
  cleaner('Omni Clean', 'Free up storage space', Icons.cleaning_services_rounded, 'cleaner'),
  compressor('Video Compressor', 'Shrink videos for sharing', Icons.movie_filter_rounded, 'compressor'),
  vault('Secure Vault', 'Hide photos and videos', Icons.lock_rounded, 'vault');

  const HomeCardId(this.title, this.subtitle, this.icon, this.serverName);

  final String title;
  final String subtitle;
  final IconData icon;

  /// Feature key used by the server for daily usage counters.
  final String serverName;
}

class HomeLayout {
  const HomeLayout({required this.order, required this.hidden});

  factory HomeLayout.initial() => const HomeLayout(order: HomeCardId.values, hidden: <HomeCardId>{});

  final List<HomeCardId> order;
  final Set<HomeCardId> hidden;

  HomeLayout copyWith({List<HomeCardId>? order, Set<HomeCardId>? hidden}) =>
      HomeLayout(order: order ?? this.order, hidden: hidden ?? this.hidden);
}
