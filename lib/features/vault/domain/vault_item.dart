class VaultItem {
  const VaultItem({
    required this.id,
    required this.fileName,
    required this.displayName,
    required this.isVideo,
    required this.size,
    required this.addedAt,
  });

  factory VaultItem.fromJson(Map<String, dynamic> j) => VaultItem(
        id: j['id'] as String,
        fileName: j['fileName'] as String,
        displayName: j['displayName'] as String,
        isVideo: j['isVideo'] == true,
        size: (j['size'] as num?)?.toInt() ?? 0,
        addedAt: DateTime.fromMillisecondsSinceEpoch((j['addedAt'] as num).toInt()),
      );

  final String id;

  /// Random name used on disk (the original name is only kept in the private index).
  final String fileName;
  final String displayName;
  final bool isVideo;
  final int size;
  final DateTime addedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'displayName': displayName,
        'isVideo': isVideo,
        'size': size,
        'addedAt': addedAt.millisecondsSinceEpoch,
      };
}
