import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/download_task.dart';
import '../providers/download_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/media_artwork.dart';

class DownloadsScreen extends StatelessWidget {
  final VoidCallback onNavigateToHome;
  const DownloadsScreen({super.key, required this.onNavigateToHome});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DownloadProvider>();
    final tasks = provider.activeTasks;
    final failed = tasks
        .where((task) => task.status == TaskStatus.failed)
        .length;
    final running = tasks.length - failed;
    return _Page(
      title: 'Activity',
      subtitle: tasks.isEmpty
          ? 'Nothing downloading right now.'
          : running == 0
          ? '$failed ${failed == 1 ? 'download needs' : 'downloads need'} attention'
          : failed == 0
          ? '$running ${running == 1 ? 'item' : 'items'} in progress'
          : '$running in progress · $failed need attention',
      child: tasks.isEmpty
          ? _Empty(
              icon: Icons.downloading_rounded,
              title: 'Your queue is clear',
              body: 'Start with a permitted public post or direct media file. Android handles transfers and notifications.',
              action: 'Save something',
              onTap: onNavigateToHome,
            )
          : Column(
              children: tasks
                  .map((task) => _TaskCard(task: task, provider: provider))
                  .toList(),
            ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final DownloadTask task;
  final DownloadProvider provider;
  const _TaskCard({required this.task, required this.provider});
  @override
  Widget build(BuildContext context) {
    final failed = task.status == TaskStatus.failed;
    final retrying = provider.isRetrying(task.id);
    final status = retrying
        ? 'Checking source…'
        : switch (task.status) {
            TaskStatus.enqueuing => 'Starting with Android',
            TaskStatus.queued => 'Queued',
            TaskStatus.downloading => 'Downloading',
            TaskStatus.paused => 'Waiting for network',
            TaskStatus.completed => 'Saved',
            TaskStatus.failed => 'Needs attention',
          };
    return Material(
      color: AppTheme.surface(context),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: MediaArtwork(
                    thumbnailUrl: task.video.thumbnailUrl,
                    audio: task.format.isAudioOnly,
                    width: 96,
                    height: 64,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.text(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${task.format.label} · $status',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMut(context),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: failed
                      ? 'Remove failed download'
                      : 'Cancel download',
                  onPressed: task.status == TaskStatus.enqueuing
                      ? null
                      : () => provider.cancelTask(task.id),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            LinearProgressIndicator(
              value:
                  task.totalBytes == 'Size unavailable' &&
                      task.status == TaskStatus.downloading
                  ? null
                  : task.progress,
              minHeight: 6,
              borderRadius: BorderRadius.circular(6),
              backgroundColor: AppTheme.surfaceElevated(context),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    failed ? 'Download did not finish' : task.speed,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.text(context),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${(task.progress * 100).round()}%',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${task.downloadedBytes} / ${task.totalBytes}${task.eta == '--' ? '' : ' · ${task.eta} remaining'}',
              style: TextStyle(fontSize: 11, color: AppTheme.textMut(context)),
            ),
            if (failed) ...[
              const SizedBox(height: 10),
              Text(
                task.error ?? 'Try checking the link again.',
                style: const TextStyle(
                  color: AppTheme.accentRose,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: retrying ? null : () => provider.retryTask(task.id),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(retrying ? 'Checking…' : 'Retry download'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _Page({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppTheme.canvas(context),
    child: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            subtitle,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                child,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String action;
  final VoidCallback onTap;
  const _Empty({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
    decoration: BoxDecoration(
      color: AppTheme.surface(context),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppTheme.border(context)),
    ),
    child: Column(
      children: [
        Icon(icon, size: 38, color: AppTheme.text(context)),
        const SizedBox(height: 20),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 7),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.text(context),
            foregroundColor: AppTheme.canvas(context),
          ),
          child: Text(action),
        ),
      ],
    ),
  );
}
