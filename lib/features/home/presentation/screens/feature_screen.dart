import 'package:flutter/material.dart';

import '../../../chat_pdf/presentation/chat_pdf_screen.dart';
import '../../../cleaner/presentation/cleaner_screen.dart';
import '../../../compressor/presentation/compressor_screen.dart';
import '../../../scan/presentation/scan_screen.dart';
import '../../../vault/presentation/vault_screen.dart';
import '../../domain/home_card_id.dart';

/// Maps a home card to its real screen (fade transition, Hero icon).
class FeatureScreen {
  FeatureScreen._();

  static Route<void> route(HomeCardId card) => PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => _screenFor(card),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
      );

  static Widget _screenFor(HomeCardId card) {
    switch (card) {
      case HomeCardId.scan:
        return const ScanScreen();
      case HomeCardId.chatPdf:
        return const ChatPdfScreen();
      case HomeCardId.cleaner:
        return const CleanerScreen();
      case HomeCardId.compressor:
        return const CompressorScreen();
      case HomeCardId.vault:
        return const VaultScreen();
    }
  }
}
