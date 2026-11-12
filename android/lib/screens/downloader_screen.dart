import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../services/media_policy.dart';
import 'legal_screen.dart';

import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/download_provider.dart';
import '../models/guide_targets.dart';
import '../theme/app_theme.dart';
import '../widgets/media_artwork.dart';
import '../widgets/turbosave_logo.dart';
import 'supported_sites_screen.dart';

class DownloaderScreen extends StatefulWidget {
  final VoidCallback onNavigateToDownloads;
  final String? draftLink;
  final ValueChanged<String>? onDraftChanged;
  final String? sharedLink;
  final int shareRevision;
  final VoidCallback? onShareHandled;
  final GuideTargets? guideTargets;
  const DownloaderScreen({
    super.key,
    required this.onNavigateToDownloads,
    this.draftLink,
    this.onDraftChanged,
    this.sharedLink,
    this.shareRevision = 0,
    this.onShareHandled,
    this.guideTargets,
  });

  @override
  State<DownloaderScreen> createState() => _DownloaderScreenState();
}

class _DownloaderScreenState extends State<DownloaderScreen> {
  final _url = TextEditingController();
  final _focus = FocusNode();
  bool _showingDetails = false;

  @override
  void initState() {
    super.initState();
    _url.text = widget.draftLink ?? widget.sharedLink ?? '';
    _url.addListener(() => widget.onDraftChanged?.call(_url.text));
    if (widget.shareRevision > 0)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onShareHandled?.call();
          _presentCurrentMedia();
        }
      });
  }

  @override
  void didUpdateWidget(covariant DownloaderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final link =
        widget.draftLink ??
        (widget.sharedLink != oldWidget.sharedLink ? widget.sharedLink : null);
    if (link != null && link != _url.text) _url.text = link;
    if (widget.shareRevision != oldWidget.shareRevision &&
        widget.shareRevision > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onShareHandled?.call();
          _presentCurrentMedia();
        }
      });
    }
  }

  @override
  void dispose() {
    _url.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final value = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim();
    if (!mounted || value == null || value.isEmpty) return;
    _url.text = value;
    if (mounted) await _inspect();
  }

  Future<void> _inspect() async {
    final value = _url.text.trim();
    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Paste a public post or direct HTTPS media link first.',
          ),
        ),
      );
      return;
    }
    _focus.unfocus();
    HapticFeedback.selectionClick();
    final provider = context.read<DownloadProvider>();
    await provider.fetchVideoMetadata(value);
    if (!mounted || provider.currentVideo == null) return;
    await _presentCurrentMedia();
  }

  Future<void> _presentCurrentMedia() async {
    if (!mounted || _showingDetails) return;
    final provider = context.read<DownloadProvider>();
    if (provider.currentVideo == null) return;
    if (MediaQuery.sizeOf(context).width < 620) {
      _showingDetails = true;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .88,
        ),
        backgroundColor: AppTheme.canvas(context),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        builder: (_) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: SingleChildScrollView(
              child: _MediaPanel(
                provider: provider,
                onStarted: () {
                  Navigator.pop(context);
                  HapticFeedback.mediumImpact();
                  widget.onNavigateToDownloads();
                },
              ),
            ),
          ),
        ),
      );
      _showingDetails = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DownloadProvider>();
    final width = MediaQuery.sizeOf(context).width;
    return ColoredBox(
      color: AppTheme.canvas(context),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            width > 700 ? 42 : 20,
            26,
            width > 700 ? 42 : 20,
            28,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(
                    activeCount: provider.activeTasks.length,
                    onActivity: widget.onNavigateToDownloads,
                    onSites: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const SupportedSitesScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'Your next download.\nMade simple.',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Paste a link, or share it here from another app. Review the quality before you save.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 28),
                  _LinkField(
                    key: widget.guideTargets?.linkField,
                    controller: _url,
                    focusNode: _focus,
                    loading: provider.isExtracting,
                    onPaste: _paste,
                    onGo: _inspect,
                    fetchKey: widget.guideTargets?.fetchButton,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'From another app: Share → More → TurboSave.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMut(context),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _QuickLinks(
                    onSelect: (url) {
                      _url.text = url;
                      _inspect();
                    },
                  ),
                  if (provider.recentLinks.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    Text(
                      'Recent links',
                      style: TextStyle(
                        color: AppTheme.text(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    ...provider.recentLinks
                        .take(3)
                        .map(
                          (link) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.history_rounded),
                            title: Text(
                              Uri.tryParse(link)?.host
                                      .replaceFirst('www.', '') ??
                                  link,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              link,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(
                              Icons.north_east_rounded,
                              size: 18,
                            ),
                            onTap: () {
                              _url.text = link;
                              _inspect();
                            },
                          ),
                        ),
                  ],
                  const SizedBox(height: 34),
                  AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 150),
                    child: provider.isExtracting
                        ? const _LoadingPanel(key: ValueKey('loading'))
                        : provider.errorMessage != null
                        ? _ErrorPanel(
                            key: const ValueKey('error'),
                            message: provider.errorMessage!,
                            onEdit: () {
                              provider.clearCurrentVideo();
                              _focus.requestFocus();
                            },
                            onRetry: _inspect,
                          )
                        : provider.currentVideo != null
                        ? width < 620
                              ? OutlinedButton.icon(
                                  key: ValueKey(provider.currentVideo!.id),
                                  onPressed: _presentCurrentMedia,
                                  icon: const Icon(Icons.video_file_outlined),
                                  label: const Text('Review formats'),
                                )
                              : _MediaPanel(
                                  key: ValueKey(provider.currentVideo!.id),
                                  provider: provider,
                                  onStarted: widget.onNavigateToDownloads,
                                )
                        : const _FeatureGrid(key: ValueKey('features')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int activeCount;
  final VoidCallback onActivity;
  final VoidCallback onSites;
  const _Header({
    required this.activeCount,
    required this.onActivity,
    required this.onSites,
  });
  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(
        child: Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: TurboSaveLogo(size: 34, borderRadius: 9, showText: true),
          ),
        ),
      ),
      if (activeCount > 0)
        IconButton(
          tooltip: '$activeCount active downloads',
          onPressed: onActivity,
          icon: Badge(
            label: Text('$activeCount'),
            child: const Icon(Icons.downloading_outlined),
          ),
        ),
      IconButton(
        tooltip: 'Sources',
        onPressed: onSites,
        icon: const Icon(Icons.apps_rounded, size: 17),
      ),
      IconButton(
        tooltip: 'Toggle theme',
        onPressed: context.read<DownloadProvider>().toggleTheme,
        icon: Icon(
          AppTheme.isDark(context)
              ? Icons.light_mode_rounded
              : Icons.dark_mode_rounded,
        ),
        style: IconButton.styleFrom(backgroundColor: AppTheme.surface(context)),
      ),
    ],
  );
}

class _LinkField extends StatelessWidget {
  final Key? fetchKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool loading;
  final VoidCallback onPaste;
  final VoidCallback onGo;
  const _LinkField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.loading,
    required this.onPaste,
    required this.onGo,
    this.fetchKey,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
    decoration: BoxDecoration(
      color: AppTheme.surface(context),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppTheme.border(context)),
    ),
    child: Row(
      children: [
        Icon(Icons.link_rounded, color: AppTheme.textMut(context), size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onSubmitted: (_) => onGo(),
            style: TextStyle(
              color: AppTheme.text(context),
              fontWeight: FontWeight.w600,
            ),
            decoration: const InputDecoration(
              hintText: 'Paste a public post or media link',
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ),
        TextButton(onPressed: onPaste, child: const Text('Paste')),
        const SizedBox(width: 4),
        SizedBox(
          key: fetchKey,
          width: 48,
          height: 48,
          child: FilledButton(
            onPressed: loading ? null : onGo,
            style: FilledButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor: AppTheme.text(context),
              foregroundColor: AppTheme.canvas(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      semanticsLabel: 'Fetch video details',
                      semanticsValue: 'Loading',
                    ),
                  )
                : const Icon(
                    Icons.arrow_forward_rounded,
                    semanticLabel: 'Fetch video details',
                  ),
          ),
        ),
      ],
    ),
  );
}

class _QuickLinks extends StatelessWidget {
  final ValueChanged<String> onSelect;
  const _QuickLinks({required this.onSelect});
  @override
  Widget build(BuildContext context) {
    const items = [('Try an open movie trailer', MediaPolicy.sampleUrl)];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (item) => ActionChip(
              label: Text(item.$1),
              onPressed: () => onSelect(item.$2),
              avatar: const Icon(Icons.north_east_rounded, size: 14),
              backgroundColor: AppTheme.surface(context),
              side: BorderSide(color: AppTheme.border(context)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({super.key});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, constraints) {
      final row = constraints.maxWidth > 620;
      final cards = const [
        _Feature(
          Icons.bolt_rounded,
          'Fast by default',
          'Multiple downloads, one clear queue.',
        ),
        _Feature(
          Icons.high_quality_rounded,
          'Quality first',
          'Save the original file without conversion.',
        ),
        _Feature(
          Icons.lock_outline_rounded,
          'On your device',
          'Files stay on your device.',
        ),
      ];
      if (row) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              Expanded(child: cards[i]),
              if (i < cards.length - 1) const SizedBox(width: 10),
            ],
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            cards[i],
            if (i < cards.length - 1) const SizedBox(height: 10),
          ],
        ],
      );
    },
  );
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _Feature(this.icon, this.title, this.body);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppTheme.surface(context),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppTheme.border(context)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.text(context)),
        const SizedBox(height: 24),
        Text(
          title,
          style: TextStyle(
            color: AppTheme.text(context),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          body,
          style: TextStyle(
            color: AppTheme.textMut(context),
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    ),
  );
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel({super.key});
  @override
  Widget build(BuildContext context) => Container(
    height: 190,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: AppTheme.text(context),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            minHeight: 5,
            color: AppTheme.brandBlue,
            backgroundColor: AppTheme.canvas(context).withValues(alpha: .18),
          ),
        ),
        const Spacer(),
        Icon(
          Icons.travel_explore_rounded,
          color: AppTheme.canvas(context),
          size: 30,
        ),
        const SizedBox(height: 12),
        Text(
          'Fetching video details…',
          style: TextStyle(
            color: AppTheme.canvas(context),
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Checking the source and available files',
          style: TextStyle(
            color: AppTheme.canvas(context).withValues(alpha: .72),
            fontSize: 12,
          ),
        ),
        const Spacer(),
      ],
    ),
  );
}

class _ErrorPanel extends StatelessWidget {
  final String message;
  final VoidCallback onEdit;
  final VoidCallback onRetry;
  const _ErrorPanel({
    super.key,
    required this.message,
    required this.onEdit,
    required this.onRetry,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: const Color(0xFFFFE8E5),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFB42318)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Color(0xFF7A271A),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton(onPressed: onEdit, child: const Text('Edit link')),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _MediaPanel extends StatefulWidget {
  final DownloadProvider provider;
  final VoidCallback onStarted;
  const _MediaPanel({
    super.key,
    required this.provider,
    required this.onStarted,
  });
  @override
  State<_MediaPanel> createState() => _MediaPanelState();
}

class _MediaPanelState extends State<_MediaPanel> {
  bool _starting = false;
  bool _showAllFormats = false;
  final Set<String> _selectedImages = {};

  @override
  void initState() {
    super.initState();
    _selectedImages.addAll(
      widget.provider.currentVideo?.formats
              .where((format) => format.isImage)
              .map((format) => format.id) ??
          const [],
    );
  }

  Future<void> _clearMatchingClipboard(String sourceUrl) async {
    try {
      final copied = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
      if (copied?.trim() == sourceUrl.trim()) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    } catch (error) {
      debugPrint('Could not clear the downloaded source link: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DownloadProvider>();
    final video = provider.currentVideo;
    if (video == null) return const SizedBox.shrink();
    final selected = provider.selectedFormat;
    final kind = selected?.isImage == true
        ? _MediaKind.images
        : selected?.isAudioOnly == true
        ? _MediaKind.audio
        : _MediaKind.video;
    final imageFormats = video.formats
        .where((format) => format.isImage)
        .toList();
    final audio = kind == _MediaKind.audio;
    final choices = video.formats
        .where((format) => !format.isImage && format.isAudioOnly == audio)
        .toList();
    final availableKinds = <_MediaKind>[
      if (video.formats.any((format) => !format.isImage && !format.isAudioOnly))
        _MediaKind.video,
      if (video.formats.any((format) => format.isAudioOnly)) _MediaKind.audio,
      if (imageFormats.isNotEmpty) _MediaKind.images,
    ];
    return Material(
      color: AppTheme.surface(context),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: MediaArtwork(
                    thumbnailUrl: kind == _MediaKind.images
                        ? imageFormats.first.downloadUrl ?? video.thumbnailUrl
                        : video.thumbnailUrl,
                    headers: kind == _MediaKind.images
                        ? imageFormats.first.httpHeaders
                        : const {},
                    audio: kind == _MediaKind.audio,
                    image: kind == _MediaKind.images,
                    width: 132,
                    height: 88,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.platformName.toUpperCase(),
                        style: TextStyle(
                          color: AppTheme.textMut(context),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.text(context),
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '${video.author}  •  ${video.duration}',
                        style: TextStyle(
                          color: AppTheme.textMut(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Available complete files',
              style: TextStyle(
                color: AppTheme.text(context),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (availableKinds.length > 1 || imageFormats.isNotEmpty) ...[
              SegmentedButton<_MediaKind>(
                segments: [
                  if (availableKinds.contains(_MediaKind.video))
                    const ButtonSegment(
                      value: _MediaKind.video,
                      icon: Icon(Icons.videocam_outlined),
                      label: Text('Video'),
                    ),
                  if (availableKinds.contains(_MediaKind.audio))
                    const ButtonSegment(
                      value: _MediaKind.audio,
                      icon: Icon(Icons.audiotrack),
                      label: Text('Audio'),
                    ),
                  if (availableKinds.contains(_MediaKind.images))
                    const ButtonSegment(
                      value: _MediaKind.images,
                      icon: Icon(Icons.photo_library_outlined),
                      label: Text('Images'),
                    ),
                ],
                selected: {kind},
                onSelectionChanged: _starting
                    ? null
                    : (value) => provider.selectFormat(
                        video.formats.firstWhere(
                          (format) => switch (value.single) {
                            _MediaKind.video =>
                              !format.isImage && !format.isAudioOnly,
                            _MediaKind.audio => format.isAudioOnly,
                            _MediaKind.images => format.isImage,
                          },
                        ),
                      ),
              ),
              const SizedBox(height: 12),
            ],
            if (kind == _MediaKind.images) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_selectedImages.length} selected',
                      style: TextStyle(
                        color: AppTheme.textSec(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _starting
                        ? null
                        : () => setState(() {
                            if (_selectedImages.length == imageFormats.length) {
                              _selectedImages.clear();
                            } else {
                              _selectedImages
                                ..clear()
                                ..addAll(imageFormats.map((item) => item.id));
                            }
                          }),
                    child: Text(
                      _selectedImages.length == imageFormats.length
                          ? 'Clear all'
                          : 'Select all',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 520 ? 4 : 3;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: imageFormats.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemBuilder: (context, index) {
                      final format = imageFormats[index];
                      final selected = _selectedImages.contains(format.id);
                      return Semantics(
                        button: true,
                        selected: selected,
                        label: 'Image ${index + 1} of ${imageFormats.length}',
                        child: Material(
                          color: AppTheme.surfaceElevated(context),
                          borderRadius: BorderRadius.circular(12),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            key: ValueKey('slideshow-image-${index + 1}'),
                            onTap: _starting
                                ? null
                                : () => setState(() {
                                    if (!selected) {
                                      _selectedImages.add(format.id);
                                    } else {
                                      _selectedImages.remove(format.id);
                                    }
                                  }),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                MediaArtwork(
                                  image: true,
                                  thumbnailUrl: format.downloadUrl ?? '',
                                  headers: format.httpHeaders,
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: IgnorePointer(
                                    child: Checkbox(
                                      value: selected,
                                      onChanged: (_) {},
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ] else ...[
              Text(
                'Choose quality',
                style: TextStyle(
                  color: AppTheme.textSec(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (
                    var index = 0;
                    index <
                        (_showAllFormats
                            ? choices.length
                            : choices.length.clamp(0, 4));
                    index++
                  )
                    ChoiceChip(
                      selected:
                          provider.selectedFormat?.id == choices[index].id,
                      onSelected: _starting
                          ? null
                          : (_) => provider.selectFormat(choices[index]),
                      label: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            choices[index].label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            index == 0
                                ? '${choices[index].estimatedSize} · Best available'
                                : choices[index].estimatedSize,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  if (choices.length > 4)
                    TextButton.icon(
                      onPressed: _starting
                          ? null
                          : () => setState(
                              () => _showAllFormats = !_showAllFormats,
                            ),
                      icon: Icon(
                        _showAllFormats
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                      ),
                      label: Text(
                        _showAllFormats
                            ? 'Show fewer'
                            : 'Show ${choices.length - 4} more',
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 9),
            Text(
              'Original complete files. No upscaling or background conversion.',
              style: TextStyle(fontSize: 11, color: AppTheme.textMut(context)),
            ),
            const SizedBox(height: 18),
            Text(
              'I own this file or have permission to download it.',
              style: TextStyle(
                color: AppTheme.text(context),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'By starting the download, you confirm this and agree to preserve any required attribution.',
              style: TextStyle(
                color: AppTheme.textSec(context),
                fontSize: 12,
                height: 1.45,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const LegalScreen(privacy: false),
                ),
              ),
              child: const Text('Read permitted-use terms'),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    _starting ||
                        provider.isStarting ||
                        provider.selectedFormat == null ||
                        (kind == _MediaKind.images && _selectedImages.isEmpty)
                    ? null
                    : () async {
                        setState(() => _starting = true);
                        final success = kind == _MediaKind.images
                            ? await provider.startDownloads(
                                imageFormats
                                    .where(
                                      (format) =>
                                          _selectedImages.contains(format.id),
                                    )
                                    .toList(),
                                rightsConfirmed: true,
                              )
                            : await provider.startDownload(
                                rightsConfirmed: true,
                              );
                        if (!context.mounted) return;
                        setState(() => _starting = false);
                        if (success && !kIsWeb) {
                          await _clearMatchingClipboard(video.sourceUrl);
                          if (!mounted) return;
                          widget.onStarted();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? 'Opened in your browser. Check its download list; TurboSave cannot confirm the save.'
                                    : provider.errorMessage ??
                                          'Could not start download.',
                              ),
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.download_rounded),
                label: Text(
                  _starting
                      ? 'Checking file…'
                      : kind == _MediaKind.images
                      ? 'Download selected'
                      : kIsWeb
                      ? 'Open file in browser'
                      : 'Start download',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.text(context),
                  foregroundColor: AppTheme.canvas(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _MediaKind { video, audio, images }
