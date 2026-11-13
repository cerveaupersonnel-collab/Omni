class ProStatus {
  const ProStatus({required this.isPro, this.expiresAt});
  final bool isPro;
  final DateTime? expiresAt;

  static const ProStatus free = ProStatus(isPro: false);
}
