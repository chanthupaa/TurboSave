class FormatOption {
  final String id;
  final String label;
  final String resolution;
  final String ext;
  final String estimatedSize;
  final String? badge;
  final bool isAudioOnly;
  final bool isImage;
  final String qualityScore;
  final String? downloadUrl;
  final Map<String, String> httpHeaders;
  final String? audioUrl;
  final Map<String, String> audioHttpHeaders;
  final bool requiresMerge;
  final bool extracted;
  final int? bitrate;
  final String? language;

  const FormatOption({
    required this.id,
    required this.label,
    required this.resolution,
    required this.ext,
    required this.estimatedSize,
    this.badge,
    this.isAudioOnly = false,
    this.isImage = false,
    required this.qualityScore,
    this.downloadUrl,
    this.httpHeaders = const {},
    this.audioUrl,
    this.audioHttpHeaders = const {},
    this.requiresMerge = false,
    this.extracted = false,
    this.bitrate,
    this.language,
  });
}
