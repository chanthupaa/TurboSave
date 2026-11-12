import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videodownloader/providers/download_provider.dart';
import 'package:videodownloader/screens/downloader_screen.dart';
import 'package:videodownloader/screens/main_navigation_screen.dart';
import 'package:videodownloader/screens/onboarding_screen.dart';
import 'package:videodownloader/screens/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('a fresh install follows the phone theme by default', (
    tester,
  ) async {
    final provider = DownloadProvider();
    addTearDown(provider.dispose);
    await provider.ready;

    expect(provider.themeMode, ThemeMode.system);
  });

  testWidgets('Settings replays the same button-by-button user guide', (
    tester,
  ) async {
    final provider = DownloadProvider();
    addTearDown(provider.dispose);
    await provider.ready;
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('User guide'), 200);
    await tester.tap(find.text('User guide'));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(find.text('Paste'), findsOneWidget);
    expect(find.text('Get details'), findsOneWidget);
    expect(find.text('Replay product tour'), findsNothing);
  });

  testWidgets('first-run guide points out controls step by step', (
    tester,
  ) async {
    final provider = DownloadProvider();
    addTearDown(provider.dispose);
    await provider.ready;
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DownloaderScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(MainNavigationScreen), findsNothing);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Paste'), findsOneWidget);
    expect(find.text('Get details'), findsOneWidget);
    expect(find.text('Step 1 of 3'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Video'), findsOneWidget);
    expect(find.text('Audio'), findsOneWidget);
    expect(find.text('Start download'), findsOneWidget);
    expect(find.text('Step 2 of 3'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Step 3 of 3'), findsOneWidget);
  });

  testWidgets('skipping the first-run guide remembers completion', (
    tester,
  ) async {
    final provider = DownloadProvider();
    addTearDown(provider.dispose);
    await provider.ready;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.byType(MainNavigationScreen), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        OnboardingScreen.preferenceKey,
      ),
      isTrue,
    );
  });
}
