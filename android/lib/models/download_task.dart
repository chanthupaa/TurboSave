import 'format_option.dart';
import 'video_item.dart';

enum TaskStatus { enqueuing, queued, downloading, paused, completed, failed }

class DownloadTask {
  final String id;
  final VideoItem video;
  FormatOption format;
  TaskStatus status;
  double progress; // 0.0 to 1.0
  String speed; // e.g. "4.8 MB/s"
  String downloadedBytes; // e.g. "12.4 MB"
  String totalBytes; // e.g. "36.2 MB"
  String eta; // e.g. "4s"
  final DateTime createdAt;
  DateTime? completedAt;
  String? filePath;
  int? nativeDownloadId;
  String? audioUrl;
  Map<String, String> audioHeaders;
  String? error;
  final String? collectionId;
  final int? collectionIndex;
  final int? collectionCount;

  DownloadTask({
    required this.id,
    required this.video,
    required this.format,
    this.status = TaskStatus.queued,
    this.progress = 0.0,
    this.speed = '0.0 KB/s',
    this.downloadedBytes = '0 MB',
    required this.totalBytes,
    this.eta = '--',
    required this.createdAt,
    this.completedAt,
    this.filePath,
    this.nativeDownloadId,
    this.audioUrl,
    this.audioHeaders = const {},
    this.error,
    this.collectionId,
    this.collectionIndex,
    this.collectionCount,
  });

  bool get isDone => status == TaskStatus.completed;
  bool get isActive => status == TaskStatus.downloading;
  bool get isPaused => status == TaskStatus.paused;
}
