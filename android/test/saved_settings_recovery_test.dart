import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videodownloader/main.dart' as app;
import 'package:videodownloader/providers/download_provider.dart';
import 'package:videodownloader/screens/main_navigation_screen.dart';
import 'package:videodownloader/screens/onboarding_screen.dart';
import 'package:videodownloader/services/android_download_service.dart';
import 'package:videodownloader/services/shared_link_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const source = 'https://example.com/clip.mp4';
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Map<String, Object> record(int id, {bool completed = false}) => {
    'id': 'saved_$id',
    'nativeId': id,
    'title': 'Saved clip',
    'sourceUrl': source,
    'ext': 'mp4',
    'formatId': 'original',
    'size': '1 MB',
    'createdAt': '2026-10-29T00:00:00Z',
    'status': completed ? 'completed' : 'queued',
    if (completed) 'filePath': 'content://downloads/$id',
  };

  Map<String, Object> validSettings() => {
    'theme_mode': 'dark',
    'wifi_only': true,
    'remember_history_v2': true,
    'website_icons_v2': true,
    'recent_links_v2': <String>[source],
    'queue_v2': jsonEncode([record(11)]),
    'library_v2': jsonEncode([record(12, completed: true)]),
    'unrelated_preference': 'keep this',
  };

  void installMocks(Map<String, Object> values) {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues(values);
    messenger.setMockMethodCallHandler(
      AndroidDownloadService.channel,
      (call) async => call.method == 'query' ? [] : null,
    );
    messenger.setMockMethodCallHandler(
      SharedLinkService.channel,
      (call) async => call.method == 'getPendingShares' ? [] : null,
    );
  }

  void clearMocks() {
    messenger.setMockMethodCallHandler(AndroidDownloadService.channel, null);
    messenger.setMockMethodCallHandler(SharedLinkService.channel, null);
    debugDefaultTargetPlatformOverride = null;
  }

  void recoveryCase(
    String name, {
    Map<String, Object> overrides = const {},
    ThemeMode theme = ThemeMode.dark,
    bool wifi = true,
    bool history = true,
    bool icons = true,
    List<String> links = const [source],
    int queued = 1,
    int saved = 1,
  }) {
    testWidgets(name, (tester) async {
      final initial = {...validSettings(), ...overrides};
      installMocks(initial);
      final provider = DownloadProvider();
      try {
        await provider.ready;
        expect(provider.themeMode, theme);
        expect(provider.wifiOnly, wifi);
        expect(provider.rememberHistory, history);
        expect(provider.websiteIcons, icons);
        expect(provider.recentLinks, links);
        expect(provider.activeTasks, hasLength(queued));
        expect(provider.completedTasks, hasLength(saved));
        if (queued > 0) {
          expect(provider.activeTasks.single.nativeDownloadId, 11);
        }
        if (saved > 0) {
          expect(
            provider.completedTasks.single.filePath,
            'content://downloads/12',
          );
        }
        final prefs = await SharedPreferences.getInstance();
        for (final entry in initial.entries) {
          expect(
            prefs.get(entry.key),
            entry.value,
            reason: 'Recovery must not erase or rewrite ${entry.key}.',
          );
        }
      } finally {
        provider.dispose();
        clearMocks();
      }
    });
  }

  recoveryCase('valid settings and both download collections are preserved');
  recoveryCase(
    'wrong-type theme falls back without losing valid settings or downloads',
    overrides: {'theme_mode': false},
    theme: ThemeMode.light,
  );
  recoveryCase(
    'unknown theme name retains the existing safe fallback',
    overrides: {'theme_mode': 'future-theme'},
    theme: ThemeMode.light,
  );
  recoveryCase(
    'wrong-type Wi-Fi setting falls back without resetting sibling records',
    overrides: {'wifi_only': 'true'},
    wifi: false,
  );
  recoveryCase(
    'wrong-type history setting defaults off and preserves stored history',
    overrides: {'remember_history_v2': 1},
    history: false,
    links: [],
  );
  recoveryCase(
    'wrong-type website icons setting defaults off without resetting siblings',
    overrides: {
      'website_icons_v2': <String>['invalid'],
    },
    icons: false,
  );
  recoveryCase(
    'wrong-type history list does not prevent task restoration',
    overrides: {'recent_links_v2': 42},
    links: [],
  );
  recoveryCase(
    'history list with a non-string item is ignored safely',
    overrides: {
      'recent_links_v2': <Object>[source, 42],
    },
    links: [],
  );
  recoveryCase(
    'valid history in a broadly typed list remains readable',
    overrides: {
      'recent_links_v2': <Object>[source],
    },
  );
  recoveryCase(
    'wrong-type queue does not hide the valid saved Library',
    overrides: {'queue_v2': 42},
    queued: 0,
  );
  recoveryCase(
    'wrong-type Library does not hide the valid queue',
    overrides: {'library_v2': false},
    saved: 0,
  );
  recoveryCase(
    'malformed queue JSON does not hide the valid Library',
    overrides: {'queue_v2': '{invalid json'},
    queued: 0,
  );
  recoveryCase(
    'wrong JSON Library shape does not hide the valid queue',
    overrides: {'library_v2': '{}'},
    saved: 0,
  );

  for (final state in ['missing', 'false', 'true', 'invalid']) {
    testWidgets('actual startup handles $state onboarding preference', (
      tester,
    ) async {
      final initial = <String, Object>{};
      if (state != 'missing') {
        initial[OnboardingScreen.preferenceKey] = state == 'invalid'
            ? 'true'
            : state == 'true';
      }
      installMocks(initial);
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1;
      try {
        await tester.pumpWidget(const SizedBox.shrink());
        await app.main();
        await tester.pumpAndSettle();
        expect(
          find.byType(OnboardingScreen),
          state == 'true' ? findsNothing : findsOneWidget,
        );
        expect(
          find.byType(MainNavigationScreen),
          state == 'true' ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        clearMocks();
      }
    });
  }
}
