import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videodownloader/main.dart';
import 'package:videodownloader/providers/download_provider.dart';
import 'package:videodownloader/screens/downloader_screen.dart';
import 'package:videodownloader/services/android_download_service.dart';
import 'package:videodownloader/services/shared_link_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  Completer<Map<String, Object>>? inspection;
  var inspectCalls = 0;

  void uiCase(
    String name,
    Future<void> Function(WidgetTester, DownloadProvider) body, {
    ThemeMode mode = ThemeMode.light,
    Brightness brightness = Brightness.light,
  }) {
    testWidgets(name, (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      SharedPreferences.setMockInitialValues({'theme_mode': mode.name});
      inspection = null;
      inspectCalls = 0;
      messenger.setMockMethodCallHandler(AndroidDownloadService.channel, (
        call,
      ) async {
        if (call.method == 'inspect') {
          inspectCalls++;
          return inspection == null
              ? {'bytes': 1024}
              : await inspection!.future;
        }
        if (call.method == 'reconcile') return null;
        throw StateError('Unexpected native call: ${call.method}');
      });
      messenger.setMockMethodCallHandler(
        SharedLinkService.channel,
        (call) async => call.method == 'getPendingShares' ? [] : null,
      );
      final provider = DownloadProvider();
      try {
        await provider.ready;
        tester.view.physicalSize = const Size(800, 1000);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: provider,
            child: const TurboSaveApp(),
          ),
        );
        await tester.pumpAndSettle();
        await body(tester, provider);
        expect(tester.takeException(), isNull);
      } finally {
        if (inspection != null && !inspection!.isCompleted) {
          inspection!.complete({'bytes': 1024});
          await tester.pump();
        }
        await tester.pumpWidget(const SizedBox.shrink());
        provider.dispose();
        messenger.setMockMethodCallHandler(
          AndroidDownloadService.channel,
          null,
        );
        messenger.setMockMethodCallHandler(SharedLinkService.channel, null);
        tester.platformDispatcher.clearPlatformBrightnessTestValue();
        debugDefaultTargetPlatformOverride = null;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    });
  }

  uiCase('fetch action keeps one accessible name while loading and disabled', (
    tester,
    provider,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final button = find.byType(FilledButton).first;
      expect(
        tester.getSemantics(button).getSemanticsData().label,
        'Fetch video details',
      );
      expect(
        tester.getSemantics(button).flagsCollection.isEnabled,
        Tristate.isTrue,
      );
      inspection = Completer<Map<String, Object>>();
      await tester.enterText(
        find.byType(TextField).first,
        'https://example.com/clip.mp4',
      );
      await tester.tap(button);
      await tester.pump();
      expect(provider.isExtracting, isTrue);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Fetching video details…'), findsOneWidget);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      expect(
        tester.getSemantics(button).getSemanticsData().label,
        'Fetch video details',
      );
      expect(
        tester.getSemantics(button).flagsCollection.isEnabled,
        Tristate.isFalse,
      );
      inspection!.complete({'bytes': 1024});
      await tester.pumpAndSettle();
      expect(provider.isExtracting, isFalse);
      expect(
        tester.getSemantics(button).getSemanticsData().label,
        'Fetch video details',
      );
      expect(inspectCalls, 1);
    } finally {
      semantics.dispose();
    }
  });

  uiCase('keyboard traversal reaches and activates the fetch button', (
    tester,
    provider,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.enterText(
        find.byType(TextField).first,
        'https://example.com/clip.mp4',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final button = find.byType(FilledButton).first;
      expect(
        tester.getSemantics(button).flagsCollection.isFocused,
        Tristate.isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(provider.currentVideo, isNotNull);
      expect(inspectCalls, 1);
    } finally {
      semantics.dispose();
    }
  });

  for (final mode in ThemeMode.values) {
    for (final brightness in Brightness.values) {
      uiCase(
        'theme $mode under $brightness toggles visible appearance and persists',
        (tester, provider) async {
          final before = mode == ThemeMode.system
              ? brightness
              : mode == ThemeMode.dark
              ? Brightness.dark
              : Brightness.light;
          Brightness visible() =>
              Theme.of(tester.element(find.byType(DownloaderScreen)))
                  .brightness;
          expect(visible(), before);
          final expected = before == Brightness.dark
              ? ThemeMode.light
              : ThemeMode.dark;
          provider.toggleTheme();
          await tester.pumpAndSettle();
          expect(provider.themeMode, expected);
          expect(
            visible(),
            before == Brightness.dark ? Brightness.light : Brightness.dark,
          );
          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getString('theme_mode'), expected.name);
          provider.toggleTheme();
          await tester.pumpAndSettle();
          expect(visible(), before);
          provider.setThemeMode(ThemeMode.system);
          await tester.pumpAndSettle();
          expect(visible(), brightness);
          expect(prefs.getString('theme_mode'), 'system');
        },
        mode: mode,
        brightness: brightness,
      );
    }
  }
}
