import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/download_task.dart';
import '../models/format_option.dart';
import '../models/video_item.dart';
import '../services/android_download_service.dart';
import '../services/media_policy.dart';
import '../services/saved_preferences.dart';
import '../services/video_parser_service.dart';
import '../utils/web_downloader.dart';

class DownloadProvider extends ChangeNotifier with WidgetsBindingObserver {
  final List<DownloadTask> _activeTasks = [];
  final List<DownloadTask> _completedTasks = [];
  final List<String> _recentLinks = [];
  SharedPreferences? _preferences;
  late final Future<void> ready;
  Timer? _poller;
  bool _disposed = false;
  bool _polling = false;
  bool _isExtracting = false;
  int _inspection = 0;
  String? _errorMessage;
  VideoItem? _currentVideo;
  FormatOption? _selectedFormat;
  ThemeMode _themeMode = ThemeMode.system;
  bool _wifiOnly = false;
  bool _rememberHistory = false;
  bool _websiteIcons = false;

  final Set<String> _retrying = {};
  final Set<String> _cancelling = {};
  final Map<int, (int, int)> _samples = {};
  final Map<int, double> _speeds = {};
  final Stopwatch _clock = Stopwatch()..start();
  bool _foreground = true;
  bool _starting = false;
  bool get isStarting => _starting;
  bool isRetrying(String id) => _retrying.contains(id);
  int get activeCount => _activeTasks.length;
  bool get isPolling => _poller != null;
  static const libraryLimit = 100;

  DownloadProvider() {
    WidgetsBinding.instance.addObserver(this);
    ready = _restoreState();
  }

  bool get _hasLiveDownloads => _activeTasks.any(
    (task) =>
        task.status == TaskStatus.queued ||
        task.status == TaskStatus.downloading ||
        task.status == TaskStatus.paused,
  );

  void _updatePolling() {
    if (_disposed ||
        !_foreground ||
        !VideoParserService.isAndroid ||
        !_hasLiveDownloads) {
      _poller?.cancel();
      _poller = null;
      return;
    }
    _poller ??= Timer.periodic(
      const Duration(seconds: 2),
      (_) => _refreshDownloads(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _updatePolling();
    if (_foreground && _hasLiveDownloads) unawaited(_refreshDownloads());
  }

  ThemeMode get themeMode => _themeMode;
  List<DownloadTask> get activeTasks => List.unmodifiable(_activeTasks);
  List<DownloadTask> get completedTasks => List.unmodifiable(_completedTasks);
  List<String> get recentLinks => List.unmodifiable(_recentLinks);
  bool get isExtracting => _isExtracting;
  String? get errorMessage => _errorMessage;
  VideoItem? get currentVideo => _currentVideo;
  FormatOption? get selectedFormat => _selectedFormat;
  bool get wifiOnly => _wifiOnly;
  bool get rememberHistory => _rememberHistory;
  bool get websiteIcons => _websiteIcons;
  String get storagePath =>
      kIsWeb ? 'Browser download location' : 'Downloads/TurboSave';
  double get totalSpeedMBs =>
      _speeds.values.fold<double>(0, (a, b) => a + b) / 1000000;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> fetchVideoMetadata(String url) async {
    await ready;
    final request = ++_inspection;
    _isExtracting = true;
    _errorMessage = null;
    _currentVideo = null;
    _selectedFormat = null;
    _notify();
    try {
      final video = await VideoParserService.extractVideoInfo(url);
      if (_disposed || request != _inspection) return;
      _currentVideo = video;
      _selectedFormat = video.formats.first;
      if (_rememberHistory && Uri.parse(url).query.isEmpty) {
        _recentLinks.remove(url);
        _recentLinks.insert(0, url);
        if (_recentLinks.length > 5) _recentLinks.removeLast();
        await _preferences?.setStringList('recent_links_v2', _recentLinks);
      }
    } catch (error) {
      if (request == _inspection) _errorMessage = _message(error);
    } finally {
      if (request == _inspection) {
        _isExtracting = false;
        _notify();
      }
    }
  }

  String _message(Object error) {
    if (error is PlatformException) {
      return error.message ?? 'Android could not complete this operation.';
    }
    if (error is FormatException) return error.message.toString();
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _restoreState() async {
    final prefs = await SharedPreferences.getInstance();
    if (_disposed) return;
    _preferences = prefs;
    final hasThemePreference = prefs.containsKey('theme_mode');
    final themeName = readSavedPreference<String>(prefs, 'theme_mode');
    _themeMode = ThemeMode.values.firstWhere(
      (mode) => mode.name == themeName,
      orElse: () => hasThemePreference ? ThemeMode.light : ThemeMode.system,
    );
    _wifiOnly = readSavedPreference<bool>(prefs, 'wifi_only') ?? false;
    _rememberHistory =
        readSavedPreference<bool>(prefs, 'remember_history_v2') ?? false;
    _websiteIcons =
        readSavedPreference<bool>(prefs, 'website_icons_v2') ?? false;
    if (_rememberHistory) {
      _recentLinks.addAll(readSavedStringList(prefs, 'recent_links_v2'));
    }
    // v2 deliberately does not import the old simulated library/queue records.
    // No physical files are removed by this metadata migration.
    var reconciled = false;
    for (final entry in const [('library_v2', true), ('queue_v2', false)]) {
      final data = readSavedPreference<String>(prefs, entry.$1);
      if (data == null) continue;
      try {
        final records = jsonDecode(data);
        if (records is! List) {
          throw const FormatException('Expected a saved record list.');
        }
        for (final json in records.take(entry.$2 ? libraryLimit : 20)) {
          try {
            final record = Map<String, dynamic>.from(json as Map);
            if (entry.$2) {
              final source = Uri.tryParse(record['sourceUrl'] as String? ?? '');
              if (source != null && (source.hasQuery || source.hasFragment)) {
                record['sourceUrl'] = source
                    .replace(query: '', fragment: '')
                    .toString();
                reconciled = true;
              }
              if ((record['thumbnailUrl'] as String? ?? '').isNotEmpty) {
                record['thumbnailUrl'] = '';
                reconciled = true;
              }
            }
            final task = _taskFromJson(record);
            if (entry.$2 && task.nativeDownloadId == null) continue;
            if (!entry.$2 &&
                (task.status == TaskStatus.enqueuing ||
                    (task.nativeDownloadId == null &&
                        task.status != TaskStatus.failed))) {
              task.status = TaskStatus.failed;
              task.error = 'The app closed while starting this download. Check Android Downloads before retrying: Android may already have accepted the file.';
              reconciled = true;
            }
            (entry.$2 ? _completedTasks : _activeTasks).add(task);
          } catch (_) {
            developer.log(
              'Ignoring an invalid saved record in "${entry.$1}".',
              name: 'TurboSave.preferences',
            );
          }
        }
      } catch (_) {
        developer.log(
          'Ignoring invalid saved records in "${entry.$1}".',
          name: 'TurboSave.preferences',
        );
      }
    }
    if (reconciled) {
      await _persistTasks();
    } else {
      // Startup stays responsive; later saves wait for this cleanup in order.
      _pendingSave = _reconcileNativeRecords(_retainedNativeIds(), force: true);
    }
    _notify();
    if (VideoParserService.isAndroid) await _refreshDownloads();
    _updatePolling();
  }

  Future<void> _pendingSave = Future.value();
  Set<int>? _nativeRetention = <int>{};
  List<int> _retainedNativeIds() => {
    for (final task in [..._completedTasks.take(libraryLimit), ..._activeTasks])
      if (task.nativeDownloadId != null) task.nativeDownloadId!,
  }.toList();

  Future<void> _reconcileNativeRecords(
    List<int> retainedIds, {
    bool force = false,
  }) async {
    if (!VideoParserService.isAndroid) return;
    final retained = retainedIds.toSet();
    if (!force && setEquals(_nativeRetention, retained)) return;
    try {
      await AndroidDownloadService.reconcile(retainedIds);
      _nativeRetention = retained;
    } catch (error, stack) {
      _nativeRetention = null;
      developer.log(
        'Could not reconcile native download records; saved tasks are retained. Cleanup will retry on the next save or startup.',
        name: 'TurboSave.downloads',
        error: error,
        stackTrace: stack,
      );
    }
  }

  Future<void> _persistTasks() {
    _pendingSave = _pendingSave.catchError((Object _) {}).then((_) async {
      final library = jsonEncode(
        _completedTasks.take(libraryLimit).map(_taskToJson).toList(),
      );
      final queue = jsonEncode(_activeTasks.map(_taskToJson).toList());
      final retainedIds = _retainedNativeIds();
      final prefs = _preferences ?? await SharedPreferences.getInstance();
      _preferences = prefs;
      if (!await prefs.setString('library_v2', library) ||
          !await prefs.setString('queue_v2', queue)) {
        throw StateError(
          'Could not save download records. Check device storage.',
        );
      }
      await _reconcileNativeRecords(retainedIds);
    });
    return _pendingSave;
  }

  Map<String, dynamic> _taskToJson(DownloadTask task) => {
    'id': task.id,
    'nativeId': task.nativeDownloadId,
    'title': task.video.title,
    'sourceUrl': task.status == TaskStatus.completed
        ? Uri.parse(task.video.sourceUrl)
              .replace(query: '', fragment: '')
              .toString()
        : task.video.sourceUrl,
    'ext': task.format.ext,
    'formatId': task.format.id,
    'formatLabel': task.format.label,
    'resolution': task.format.resolution,
    'extracted': task.format.extracted,
    'audioOnly': task.format.isAudioOnly,
    'imageOnly': task.format.isImage,
    'collectionId': task.collectionId,
    'collectionIndex': task.collectionIndex,
    'collectionCount': task.collectionCount,
    'size': task.totalBytes,
    'progress': task.progress,
    'status': task.status.name,
    'createdAt': task.createdAt.toIso8601String(),
    'completedAt': task.completedAt?.toIso8601String(),
    'filePath': task.filePath,
    'error': task.error,
    'thumbnailUrl': task.status == TaskStatus.completed
        ? ''
        : task.video.thumbnailUrl,
    'bitrate': task.format.bitrate,
    'language': task.format.language,
    if (task.status != TaskStatus.completed && task.audioUrl != null)
      'audioUrl': task.audioUrl,
    if (task.status != TaskStatus.completed && task.audioHeaders.isNotEmpty)
      'audioHeaders': task.audioHeaders,
  };

  (String?, Map<String, String>) _audioForFormat(FormatOption format) {
    return (format.audioUrl, Map<String, String>.of(format.audioHttpHeaders));
  }

  DownloadTask _taskFromJson(Map<String, dynamic> json) {
    final uri = MediaPolicy.validate(json['sourceUrl'] as String);
    final format = FormatOption(
      id: json['formatId'] as String? ?? 'original',
      label: json['formatLabel'] as String? ?? 'Original ${json['ext']}',
      resolution: json['resolution'] as String? ?? 'Original',
      ext: json['ext'] as String,
      estimatedSize: json['size'] as String,
      isAudioOnly:
          json['audioOnly'] as bool? ??
          MediaPolicy.audioExtensions.contains(json['ext']),
      isImage:
          json['imageOnly'] as bool? ??
          MediaPolicy.imageExtensions.contains(json['ext']),
      qualityScore: 'Original',
      downloadUrl: uri.toString(),
      extracted: json['extracted'] == true,
      bitrate: (json['bitrate'] as num?)?.toInt(),
      language: json['language'] as String?,
    );
    return DownloadTask(
      id: json['id'] as String,
      nativeDownloadId: (json['nativeId'] as num?)?.toInt(),
      audioUrl: json['audioUrl'] as String?,
      audioHeaders: json['audioHeaders'] is Map
          ? Map<String, String>.from(json['audioHeaders'] as Map)
          : const {},
      video: VideoItem(
        id: uri.toString(),
        title: json['title'] as String,
        author: uri.host,
        authorAvatar: '',
        sourceUrl: uri.toString(),
        thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
        duration: 'Original file',
        views: '',
        uploadDate: '',
        platform: VideoPlatform.direct,
        formats: [format],
      ),
      format: format,
      status: TaskStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => TaskStatus.queued,
      ),
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      totalBytes: json['size'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
      filePath: json['filePath'] as String?,
      error: json['error'] as String?,
      collectionId: json['collectionId'] as String?,
      collectionIndex: (json['collectionIndex'] as num?)?.toInt(),
      collectionCount: (json['collectionCount'] as num?)?.toInt(),
    );
  }

  void selectFormat(FormatOption format) {
    if (_currentVideo?.formats.contains(format) ?? false) {
      _selectedFormat = format;
    }
    _notify();
  }

  void clearCurrentVideo() {
    ++_inspection;
    _currentVideo = null;
    _selectedFormat = null;
    _isExtracting = false;
    _errorMessage = null;
    _notify();
  }

  /// Permission is checked at the provider boundary, not only in the UI.
  Future<bool> startDownload({required bool rightsConfirmed}) async {
    final format = _selectedFormat;
    if (format == null) {
      _errorMessage = 'Choose a file to download.';
      _notify();
      return false;
    }
    return startDownloads([format], rightsConfirmed: rightsConfirmed);
  }

  Future<bool> startDownloads(
    List<FormatOption> requested, {
    required bool rightsConfirmed,
  }) async {
    await ready;
    if (_starting) return false;
    final currentVideo = _currentVideo;
    final selected = requested.toSet().toList();
    if (!rightsConfirmed || currentVideo == null || selected.isEmpty) {
      _errorMessage =
          'Confirm that you own this file or have permission to download it.';
      _notify();
      return false;
    }
    if (selected.any((format) => format.downloadUrl == null)) {
      _errorMessage =
          'One selected file is no longer available. Fetch the link again.';
      _notify();
      return false;
    }
    if (_activeTasks.any(
      (task) =>
          task.status == TaskStatus.failed &&
          task.video.sourceUrl == currentVideo.sourceUrl &&
          selected.any((format) => format.id == task.format.id),
    )) {
      _errorMessage = 'This file and quality are already in Activity. Retry or remove that item first.';
      _notify();
      return false;
    }
    if (_activeTasks.length + selected.length > 20) {
      _errorMessage = 'The queue can hold 20 files. Finish or remove items, or select fewer images.';
      _notify();
      return false;
    }
    _starting = true;
    _notify();
    final tasks = <DownloadTask>[];
    try {
      _errorMessage = null;
      var video = currentVideo;
      var formats = selected;
      if (MediaPolicy.classify(video.sourceUrl).$2 ==
          MediaLinkKind.sourcePage) {
        final fresh = await VideoParserService.extractVideoInfo(
          video.sourceUrl,
        );
        formats = [
          for (final requested in selected)
            fresh.formats.firstWhere(
              (candidate) => candidate.id == requested.id,
              orElse: () => throw const FormatException(
                'A selected file is no longer available. Fetch the link again.',
              ),
            ),
        ];
        video = fresh;
      }
      for (final format in formats) {
        MediaPolicy.validate(format.downloadUrl!);
        final mediaUri = Uri.tryParse(format.downloadUrl!);
        if (mediaUri?.scheme != 'https' ||
            mediaUri!.host.isEmpty ||
            !MediaPolicy.extensions.contains(format.ext)) {
          throw const FormatException('The extracted file URL is invalid.');
        }
        final audioUrl = _audioForFormat(format).$1;
        if (audioUrl != null) {
          final audioUri = Uri.tryParse(audioUrl);
          if (audioUri?.scheme != 'https' || audioUri!.host.isEmpty) {
            throw const FormatException('The extracted audio URL is invalid.');
          }
        }
      }
      if (kIsWeb) {
        if (formats.length > 1) {
          throw const FormatException(
            'Slideshow downloads are available in the Android app.',
          );
        }
        if (formats.single.httpHeaders.isNotEmpty ||
            _audioForFormat(formats.single).$1 != null) {
          throw const FormatException(
            'This site requires download headers the browser cannot send. Use the Android app.',
          );
        }
        downloadOnWeb(formats.single.downloadUrl!);
        // A browser handoff is never reported as a completed saved file.
        return true;
      }
      if (!VideoParserService.isAndroid) {
        throw const FormatException(
          'File downloads are available on Android. Use the browser for previews.',
        );
      }
      final collectionId = formats.any((format) => format.isImage)
          ? 'collection_${List.generate(3, (_) => Random.secure().nextInt(1 << 32).toRadixString(16).padLeft(8, '0')).join()}'
          : null;
      for (var index = 0; index < formats.length; index++) {
        final format = formats[index];
        final (audioUrl, audioHeaders) = _audioForFormat(format);
        final task = DownloadTask(
          id: 'local_${List.generate(4, (_) => Random.secure().nextInt(1 << 32).toRadixString(16).padLeft(8, '0')).join()}',
          video: video,
          format: format,
          audioUrl: audioUrl,
          audioHeaders: audioHeaders,
          status: TaskStatus.enqueuing,
          totalBytes: format.estimatedSize,
          createdAt: DateTime.now(),
          speed: 'Starting with Android',
          collectionId: collectionId,
          collectionIndex: collectionId == null ? null : index + 1,
          collectionCount: collectionId == null ? null : formats.length,
        );
        tasks.add(task);
        _activeTasks.insert(0, task);
      }
      await _persistTasks();
      if (_disposed) return false;
      _notify();
      var accepted = 0;
      for (final task in tasks) {
        try {
          final id = await AndroidDownloadService.enqueue(
            task.format.downloadUrl!,
            task.collectionIndex == null
                ? video.title
                : '${video.title} ${task.collectionIndex} of ${task.collectionCount}',
            _wifiOnly,
            ext: task.format.ext,
            extracted: task.format.extracted,
            headers: task.format.httpHeaders,
            audioUrl: task.audioUrl,
            audioHeaders: task.audioHeaders,
          );
          task.nativeDownloadId = id;
          task.status = TaskStatus.queued;
          task.speed = 'Waiting for Android';
          accepted++;
        } catch (error) {
          task.status = TaskStatus.failed;
          task.error = _message(error);
          _errorMessage = task.error;
        }
        await _persistTasks();
      }
      _updatePolling();
      _notify();
      return accepted > 0;
    } catch (error) {
      _errorMessage = _message(error);
      for (final task in tasks) {
        task.status = TaskStatus.failed;
        task.error = _errorMessage;
      }
      if (tasks.isNotEmpty) {
        try {
          await _persistTasks();
        } catch (saveError, stack) {
          developer.log(
            'Could not save the failed start.',
            name: 'TurboSave.downloads',
            error: saveError,
            stackTrace: stack,
          );
        }
      }
      _notify();
      return false;
    } finally {
      _starting = false;
      _notify();
    }
  }

  Future<List<Map<String, dynamic>>> _queryDownloadSnapshots(
    List<int> ids,
  ) async {
    try {
      return await AndroidDownloadService.query(ids);
    } on PlatformException catch (error, stack) {
      if (error.code != 'MEDIA_ERROR') rethrow;
      developer.log(
        'Batch download query failed; checking each ID separately.',
        name: 'TurboSave.downloads',
        error: error,
        stackTrace: stack,
      );
      // Older native hosts throw for a stale ID instead of returning unknown.
      final snapshots = <Map<String, dynamic>>[];
      for (final id in ids) {
        if (_disposed || !_foreground) break;
        try {
          snapshots.addAll(await AndroidDownloadService.query([id]));
        } catch (error, stack) {
          developer.log(
            'Download query failed for ID $id.',
            name: 'TurboSave.downloads',
            error: error,
            stackTrace: stack,
          );
          final unknown =
              error is PlatformException &&
              error.code == 'MEDIA_ERROR' &&
              error.message == 'This download does not belong to this app.';
          snapshots.add({'id': id, 'status': unknown ? 'unknown' : 'error'});
        }
      }
      return snapshots;
    }
  }

  Future<void> _refreshDownloads() async {
    if (_disposed || !_foreground || _polling || _activeTasks.isEmpty) return;
    _polling = true;
    try {
      final pending = _activeTasks
          .where(
            (task) =>
                task.status != TaskStatus.failed &&
                task.status != TaskStatus.enqueuing &&
                task.nativeDownloadId != null &&
                !_cancelling.contains(task.id) &&
                !_retrying.contains(task.id),
          )
          .map((task) => task.nativeDownloadId!)
          .toList();
      if (pending.isEmpty) return;
      final snapshots = await _queryDownloadSnapshots(pending);
      if (_disposed) return;
      final before = jsonEncode(
        _activeTasks
            .map(
              (task) => [
                task.nativeDownloadId,
                task.status.name,
                task.progress,
                task.speed,
                task.eta,
                task.error,
              ],
            )
            .toList(),
      );
      bool save = false;
      for (final data in snapshots) {
        final matches = _activeTasks.where(
          (task) => task.nativeDownloadId == data['id'],
        );
        if (matches.isEmpty) continue;
        final task = matches.first;
        // A pending cancel owns the result; a late snapshot must not save its file.
        if (_cancelling.contains(task.id)) continue;
        if (data['status'] == 'error') {
          developer.log(
            'Android could not query download ID ${data['id']}; it will be checked again.',
            name: 'TurboSave.downloads',
            error: data['errorType'] ?? data['error'],
          );
          continue;
        }
        final bytes = (data['bytes'] as num?)?.toInt() ?? 0;
        final total = (data['total'] as num?)?.toInt() ?? -1;
        final nativeId = task.nativeDownloadId!;
        final previous = _samples[nativeId];
        final now = _clock.elapsedMilliseconds;
        double? speed;
        if (previous != null && now > previous.$2 && bytes >= previous.$1) {
          speed = (bytes - previous.$1) * 1000 / (now - previous.$2);
        }
        _samples[nativeId] = (bytes, now);
        if (speed != null) _speeds[nativeId] = speed;
        task.eta = speed != null && speed > 0 && total >= bytes
            ? '${((total - bytes) / speed).ceil()} sec'
            : '--';
        task.progress = total > 0 ? (bytes / total).clamp(0, 1) : 0;
        task.downloadedBytes = '${(bytes / 1048576).toStringAsFixed(1)} MB';
        task.totalBytes = total > 0
            ? '${(total / 1048576).toStringAsFixed(1)} MB'
            : 'Size unavailable';
        switch (data['status']) {
          case 'completed':
            final uri =
                (data['finalUri'] ?? data['contentUri'] ?? data['uri'])
                    as String?;
            if (uri == null || uri.isEmpty) {
              task.status = TaskStatus.failed;
              task.error = 'Android could not locate the saved file.';
            } else {
              task.status = TaskStatus.completed;
              task.progress = 1;
              task.filePath = uri;
              task.completedAt = DateTime.now();
              _activeTasks.remove(task);
              _completedTasks.insert(0, task);
              if (_completedTasks.length > libraryLimit)
                _completedTasks.removeRange(
                  libraryLimit,
                  _completedTasks.length,
                );
              _samples.remove(nativeId);
              _speeds.remove(nativeId);
            }
            save = true;
          case 'unknown':
          case 'failed':
            if (task.status != TaskStatus.failed) save = true;
            task.status = TaskStatus.failed;
            task.error = data['status'] == 'unknown'
                ? 'Android no longer recognises this download. Retry it to start a new transfer.'
                : data['error'] as String? ?? 'Download failed. Try again.';
            _samples.remove(nativeId);
            _speeds.remove(nativeId);
          case 'paused':
            task.status = TaskStatus.paused;
            task.speed = data['error'] as String? ?? 'Waiting for network';
            _samples.remove(nativeId);
            _speeds.remove(nativeId);
          case 'downloading':
            task.status = TaskStatus.downloading;
            task.speed = speed == null
                ? 'Measuring…'
                : speed >= 1000000
                ? '${(speed / 1000000).toStringAsFixed(1)} MB/s'
                : '${(speed / 1000).toStringAsFixed(0)} KB/s';
          default:
            task.status = TaskStatus.queued;
            task.speed = 'Waiting for Android';
        }
      }
      if (save) await _persistTasks();
      final after = jsonEncode(
        _activeTasks
            .map(
              (task) => [
                task.nativeDownloadId,
                task.status.name,
                task.progress,
                task.speed,
                task.eta,
                task.error,
              ],
            )
            .toList(),
      );
      if (save || before != after) _notify();
    } catch (error, stack) {
      developer.log(
        'Could not refresh Android downloads.',
        name: 'TurboSave.downloads',
        error: error,
        stackTrace: stack,
      );
    } finally {
      _polling = false;
      _updatePolling();
    }
  }

  Future<void> cancelTask(String id) async {
    final tasks = _activeTasks.where((task) => task.id == id);
    if (tasks.isEmpty) return;
    final task = tasks.first;
    if (task.status == TaskStatus.enqueuing || !_cancelling.add(id)) return;
    try {
      if (task.nativeDownloadId != null) {
        try {
          await AndroidDownloadService.cancel(task.nativeDownloadId!);
        } on PlatformException catch (error) {
          // A missing native owner has nothing to cancel; remove only our failed record.
          if (task.status != TaskStatus.failed ||
              error.code != 'MEDIA_ERROR' ||
              error.message != 'This download does not belong to this app.') {
            rethrow;
          }
        }
      }
      _activeTasks.remove(task);
      _samples.remove(task.nativeDownloadId);
      _speeds.remove(task.nativeDownloadId);
      await _persistTasks();
    } catch (error) {
      _errorMessage = _message(error);
    } finally {
      _cancelling.remove(id);
      _updatePolling();
    }
    _notify();
  }

  Future<void> retryTask(String id) async {
    final matches = _activeTasks.where((task) => task.id == id);
    if (matches.isEmpty) return;
    final task = matches.first;
    if (task.status != TaskStatus.failed ||
        _cancelling.contains(id) ||
        !_retrying.add(id))
      return;
    final oldId = task.nativeDownloadId;
    task.error = null;
    _notify();
    try {
      final isPage =
          MediaPolicy.classify(task.video.sourceUrl).$2 ==
          MediaLinkKind.sourcePage;
      final fresh = isPage
          ? await VideoParserService.extractVideoInfo(task.video.sourceUrl)
          : task.video;
      final format = isPage
          ? fresh.formats.firstWhere(
              (candidate) => candidate.id == task.format.id,
              orElse: () => throw const FormatException(
                'This quality is no longer available. Fetch the link again.',
              ),
            )
          : task.format;
      final (freshAudioUrl, freshAudioHeaders) = _audioForFormat(format);
      final audioUrl = isPage ? freshAudioUrl : freshAudioUrl ?? task.audioUrl;
      final audioHeaders = isPage
          ? freshAudioHeaders
          : freshAudioUrl == null
          ? task.audioHeaders
          : freshAudioHeaders;
      if (audioUrl != null) {
        final audioUri = Uri.tryParse(audioUrl);
        if (audioUri?.scheme != 'https' || audioUri!.host.isEmpty) {
          throw const FormatException('The extracted audio URL is invalid.');
        }
      }
      if (_disposed || !_activeTasks.contains(task) || _cancelling.contains(id))
        return;
      task.status = TaskStatus.enqueuing;
      task.nativeDownloadId = null;
      await _persistTasks();
      if (_disposed) return;
      _notify();
      final newId = await AndroidDownloadService.enqueue(
        format.downloadUrl ?? task.video.sourceUrl,
        task.video.title,
        _wifiOnly,
        ext: format.ext,
        extracted: format.extracted,
        headers: format.httpHeaders,
        audioUrl: audioUrl,
        audioHeaders: audioHeaders,
      );
      task.nativeDownloadId = newId;
      task.format = format;
      task.audioUrl = audioUrl;
      task.audioHeaders = audioHeaders;
      task.status = TaskStatus.queued;
      task.error = null;
      task.progress = 0;
      await _persistTasks();
      try {
        if (oldId != null) await AndroidDownloadService.cancel(oldId);
      } catch (_) {
        /* Keep tracking the replacement even if old-record cleanup fails. */
      }
    } catch (error) {
      _errorMessage = _message(error);
      task.status = TaskStatus.failed;
      task.error = _errorMessage;
      task.nativeDownloadId ??= oldId;
      await _persistTasks();
    } finally {
      _retrying.remove(id);
      _updatePolling();
    }
    _notify();
  }

  Future<void> openFile(DownloadTask task, {bool share = false}) async {
    if (task.filePath == null) return;
    final nativeId = task.nativeDownloadId;
    if (nativeId == null) {
      throw StateError('This saved file has no Android download ID.');
    }
    await AndroidDownloadService.open(
      nativeId,
      task.filePath!,
      {
            'mp4': task.format.isAudioOnly ? 'audio/mp4' : 'video/mp4',
            'webm': task.format.isAudioOnly ? 'audio/webm' : 'video/webm',
            'mov': task.format.isAudioOnly ? 'audio/*' : 'video/quicktime',
            'mkv': task.format.isAudioOnly
                ? 'audio/x-matroska'
                : 'video/x-matroska',
            'mp3': 'audio/mpeg',
            'm4a': 'audio/mp4',
            'ogg': 'audio/ogg',
            'oga': 'audio/ogg',
            'wav': 'audio/wav',
            'flac': 'audio/flac',
            'jpg': 'image/jpeg',
            'jpeg': 'image/jpeg',
            'png': 'image/png',
            'webp': 'image/webp',
          }[task.format.ext] ??
          'application/octet-stream',
      share: share,
    );
  }

  Future<void> openGallery(List<DownloadTask> tasks) async {
    final ordered =
        tasks
            .where(
              (task) =>
                  task.format.isImage &&
                  task.nativeDownloadId != null &&
                  task.filePath != null,
            )
            .toList()
          ..sort(
            (a, b) =>
                (a.collectionIndex ?? 0).compareTo(b.collectionIndex ?? 0),
          );
    if (ordered.isEmpty) {
      throw StateError('This saved slideshow has no available images.');
    }
    await AndroidDownloadService.openGallery([
      for (final task in ordered)
        {
          'id': task.nativeDownloadId!,
          'uri': task.filePath!,
          'mimeType': switch (task.format.ext) {
            'png' => 'image/png',
            'webp' => 'image/webp',
            _ => 'image/jpeg',
          },
        },
    ]);
  }

  Future<bool> deleteCompletedTask(String id) async {
    await ready;
    // Serialize removal with other saves; keep the visible record until durable.
    final removal = _pendingSave.catchError((Object _) {}).then((_) async {
      final remaining = _completedTasks.where((task) => task.id != id);
      final prefs = _preferences ?? await SharedPreferences.getInstance();
      if (!await prefs.setString(
        'library_v2',
        jsonEncode(remaining.take(libraryLimit).map(_taskToJson).toList()),
      )) {
        throw StateError(
          'Could not save library removal. Check device storage.',
        );
      }
      // Only remove our record. Saved files remain in Android Downloads.
      _completedTasks.removeWhere((task) => task.id == id);
      await _reconcileNativeRecords(_retainedNativeIds());
    });
    _pendingSave = removal;
    try {
      await removal;
    } catch (error, stack) {
      _errorMessage = 'Could not remove this Library entry. Check device storage and try again.';
      developer.log(
        'Could not save Library removal.',
        name: 'TurboSave.downloads',
        error: error,
        stackTrace: stack,
      );
      _notify();
      return false;
    }
    _notify();
    return true;
  }

  Future<void> clearPrivateRecords() async {
    await ready;
    _recentLinks.clear();
    _completedTasks.clear();
    await _preferences?.remove('recent_links_v2');
    // Remove obsolete preview metadata too. No download files are deleted.
    for (final key in ['recent_links', 'completed_library', 'paused_queue']) {
      await _preferences?.remove(key);
    }
    await _persistTasks();
    _notify();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _notify();
    _preferences?.setString('theme_mode', mode.name);
  }

  void toggleTheme() {
    final dark =
        _themeMode == ThemeMode.dark ||
        (_themeMode == ThemeMode.system &&
            WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                Brightness.dark);
    setThemeMode(dark ? ThemeMode.light : ThemeMode.dark);
  }

  void toggleWifiOnly(bool value) {
    _wifiOnly = value;
    _notify();
    _preferences?.setBool('wifi_only', value);
  }

  void toggleHistory(bool value) {
    _rememberHistory = value;
    if (!value) {
      _recentLinks.clear();
      _preferences?.remove('recent_links_v2');
    }
    _preferences?.setBool('remember_history_v2', value);
    _notify();
  }

  void toggleWebsiteIcons(bool value) {
    _websiteIcons = value;
    _preferences?.setBool('website_icons_v2', value);
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _poller?.cancel();
    _poller = null;
    // System transfers intentionally continue; Android owns their lifecycle.
    super.dispose();
  }
}
