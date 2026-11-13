class ScanDoc {
  const ScanDoc({required this.id, required this.createdAt, required this.pagePaths, required this.text});

  final String id;
  final DateTime createdAt;
  final List<String> pagePaths;
  final String text;

  String get title {
    String two(int n) => n.toString().padLeft(2, '0');
    final d = createdAt;
    return 'Scan ${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }
}
