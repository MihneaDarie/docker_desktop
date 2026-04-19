class ImageSpec {
  final String id;
  final String tag;
  final int sizeBytes;
  final DateTime created;

  ImageSpec({
    required this.id,
    required this.tag,
    required this.sizeBytes,
    required this.created,
  });

  String get shortId => id.length > 12 ? id.substring(0, 12) : id;
}