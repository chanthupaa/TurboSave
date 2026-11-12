import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/download_provider.dart';
import '../services/media_policy.dart';
import '../services/shared_link_service.dart';
import '../theme/app_theme.dart';
import '../widgets/turbosave_logo.dart';
import 'downloader_screen.dart';
import 'downloads_screen.dart';
import 'library_screen.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});
  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  int _index = 0;
  int _shareRevision = 0;
  int _handledShareRevision = 0;
  String? _sharedSource;
  String _draftLink = '';
  late final SharedLinkService _inbox;
  static const _labels = ['Home', 'Activity', 'Library', 'Settings'];
  static const _icons = [
    Icons.home_outlined,
    Icons.downloading_outlined,
    Icons.video_library_outlined,
    Icons.tune_rounded,
  ];
  static const _selectedIcons = [
    Icons.home_rounded,
    Icons.downloading_rounded,
    Icons.video_library_rounded,
    Icons.tune_rounded,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _inbox = SharedLinkService(onLink: _receive, onError: _shareError);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_inbox.start());
    });
  }

  void _shareError(String text) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        content: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Future<void> _receive(String link) async {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      _index = 0;
      _sharedSource = link;
      _draftLink = link;
    });
    final provider = context.read<DownloadProvider>();
    await provider.fetchVideoMetadata(link);
    if (!mounted || provider.currentVideo == null) return;
    setState(() {
      _index = 0;
      _shareRevision++;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_inbox.resume());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inbox.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (_index != index) setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final active = context.select<DownloadProvider, int>(
      (provider) => provider.activeCount,
    );
    final wide = MediaQuery.sizeOf(context).width >= 980;
    // Hidden tabs are unmounted, so their lists cannot rebuild on progress updates.
    final Widget page = switch (_index) {
      0 => DownloaderScreen(
        onNavigateToDownloads: () => _select(1),
        draftLink: _draftLink,
        onDraftChanged: (value) => _draftLink = value,
        sharedLink: _sharedSource,
        shareRevision: _shareRevision > _handledShareRevision
            ? _shareRevision
            : 0,
        onShareHandled: () {
          _handledShareRevision = _shareRevision;
        },
      ),
      1 => DownloadsScreen(onNavigateToHome: () => _select(0)),
      2 => LibraryScreen(onNavigateToHome: () => _select(0)),
      _ => const SettingsScreen(),
    };
    Widget icon(int index, {bool selected = false}) {
      final item = Icon(selected ? _selectedIcons[index] : _icons[index]);
      return index == 1 && active > 0
          ? Badge(label: Text('$active'), child: item)
          : item;
    }

    return Scaffold(
      backgroundColor: AppTheme.canvas(context),
      body: Row(
        children: [
          if (wide)
            SafeArea(
              child: NavigationRail(
                extended: true,
                backgroundColor: AppTheme.surface(context),
                selectedIndex: _index,
                onDestinationSelected: _select,
                leading: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
                  child: Column(
                    children: [
                      const TurboSaveLogo(size: 42),
                      const SizedBox(height: 12),
                      Text(
                        MediaPolicy.restricted ? 'TurboSave' : 'TurboSave Open',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                destinations: List.generate(
                  4,
                  (i) => NavigationRailDestination(
                    icon: icon(i),
                    selectedIcon: icon(i, selected: true),
                    label: Text(_labels[i]),
                  ),
                ),
              ),
            ),
          Expanded(
            child: KeyedSubtree(key: ValueKey(_index), child: page),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              backgroundColor: AppTheme.surface(context),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              height: 72,
              animationDuration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 150),
              selectedIndex: _index,
              onDestinationSelected: _select,
              destinations: List.generate(
                4,
                (i) => NavigationDestination(
                  icon: icon(i),
                  selectedIcon: icon(i, selected: true),
                  label: _labels[i],
                ),
              ),
            ),
    );
  }
}
