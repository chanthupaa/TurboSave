import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/download_task.dart';
import '../providers/download_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/media_artwork.dart';

class LibraryScreen extends StatefulWidget {
  final VoidCallback onNavigateToHome;
  const LibraryScreen({super.key, required this.onNavigateToHome});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _search = TextEditingController();
  String query = '';

  Future<void> _openEntry(
    DownloadProvider provider,
    _LibraryEntry entry,
  ) async {
    try {
      if (entry.isSlideshow) {
        await provider.openGallery(entry.tasks);
      } else {
        await provider.openFile(entry.tasks.first);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'File unavailable or unsupported. Check Android Downloads.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _removeEntry(
    DownloadProvider provider,
    _LibraryEntry entry,
  ) async {
    for (final task in entry.tasks) {
      if (!await provider.deleteCompletedTask(task.id)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not remove this Library entry. Check device storage and try again.',
              ),
            ),
          );
        }
        return;
      }
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DownloadProvider>();
    final grouped = <String, _LibraryEntry>{};
    for (final task in provider.completedTasks) {
      final key = task.collectionId ?? task.id;
      (grouped[key] ??= _LibraryEntry([])).tasks.add(task);
    }
    for (final entry in grouped.values) {
      entry.tasks.sort(
        (a, b) => (a.collectionIndex ?? 0).compareTo(b.collectionIndex ?? 0),
      );
    }
    final items = grouped.values
        .where((item) => item.title.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return ColoredBox(
      color: AppTheme.canvas(context),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Library',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${provider.completedTasks.length} saved items · Files stay in Downloads',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 22),
                        TextField(
                          controller: _search,
                          onChanged: (value) => setState(() => query = value),
                          decoration: InputDecoration(
                            hintText: 'Search saved media',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: query.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Clear search',
                                    onPressed: () {
                                      _search.clear();
                                      setState(() => query = '');
                                    },
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyLibrary(onTap: widget.onNavigateToHome),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.crossAxisExtent >= 740
                            ? 3
                            : constraints.crossAxisExtent >= 480
                            ? 2
                            : 1;
                        return SliverGrid(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _MediaCard(
                              entry: items[index],
                              onOpen: () => _openEntry(provider, items[index]),
                              onDelete: () =>
                                  _removeEntry(provider, items[index]),
                            ),
                            childCount: items.length,
                          ),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                                childAspectRatio: 1.3,
                              ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryEntry {
  final List<DownloadTask> tasks;
  const _LibraryEntry(this.tasks);

  DownloadTask get first => tasks.first;
  String get title => first.video.title;
  bool get isSlideshow => first.collectionId != null && first.format.isImage;
}

class _MediaCard extends StatelessWidget {
  final _LibraryEntry entry;
  final Future<void> Function() onOpen;
  final VoidCallback onDelete;
  const _MediaCard({
    required this.entry,
    required this.onOpen,
    required this.onDelete,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: entry.isSlideshow
        ? 'View ${entry.title} slideshow'
        : 'Play ${entry.title}',
    child: Material(
      color: AppTheme.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppTheme.border(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MediaArtwork(
                    audio: entry.first.format.isAudioOnly,
                    image: entry.isSlideshow,
                    thumbnailUrl: entry.first.video.thumbnailUrl,
                  ),
                  if (!entry.isSlideshow)
                    Positioned(
                      left: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          entry.first.video.duration,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.text(context),
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          entry.isSlideshow
                              ? '${entry.tasks.length} images'
                              : '${entry.first.format.label}  •  ${entry.first.format.estimatedSize}',
                          style: TextStyle(
                            color: AppTheme.textMut(context),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'delete') {
                        onDelete();
                      } else if (value == 'open') {
                        await onOpen();
                      } else if (value == 'copy') {
                        Clipboard.setData(
                          ClipboardData(text: entry.first.video.sourceUrl),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Source link copied.')),
                        );
                      } else if (value == 'path') {
                        Clipboard.setData(
                          ClipboardData(text: entry.first.filePath ?? ''),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('File location copied.'),
                          ),
                        );
                      } else if (value == 'share') {
                        try {
                          await context.read<DownloadProvider>().openFile(
                            entry.first,
                            share: true,
                          );
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'File unavailable or no compatible app is installed. Check Android Downloads.',
                                ),
                              ),
                            );
                          }
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'open',
                        child: Text('Open saved file'),
                      ),
                      PopupMenuItem(
                        value: 'share',
                        child: Text('Share saved file'),
                      ),
                      PopupMenuItem(
                        value: 'copy',
                        child: Text('Copy source link'),
                      ),
                      PopupMenuItem(
                        value: 'path',
                        child: Text('Copy file location'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Remove library record'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _EmptyLibrary extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyLibrary({required this.onTap});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
    decoration: BoxDecoration(
      color: AppTheme.surface(context),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppTheme.border(context)),
    ),
    child: Column(
      children: [
        const Icon(Icons.video_library_outlined, size: 40),
        const SizedBox(height: 18),
        Text('Nothing here yet', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 7),
        Text(
          'Finished downloads will live here.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: onTap,
          child: const Text('Save your first item'),
        ),
      ],
    ),
  );
}
