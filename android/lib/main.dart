import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/download_provider.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/saved_preferences.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PaintingBinding.instance.imageCache.maximumSize = 80;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 20 * 1024 * 1024;
  LicenseRegistry.addLicense(() async* {
    for (final package in ['python', 'chaquopy', 'yt-dlp']) {
      final license = await rootBundle.loadString(
        'assets/licenses/$package.txt',
      );
      yield LicenseEntryWithLineBreaks([package], license);
    }
  });
  final preferences = await SharedPreferences.getInstance();
  final hasCompletedOnboarding =
      readSavedPreference<bool>(preferences, OnboardingScreen.preferenceKey) ??
      false;

  // Edge to edge mobile styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.bgSecondary,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => DownloadProvider())],
      child: TurboSaveApp(showOnboarding: !hasCompletedOnboarding),
    ),
  );
}

class TurboSaveApp extends StatelessWidget {
  final bool showOnboarding;

  const TurboSaveApp({super.key, this.showOnboarding = false});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<DownloadProvider, ThemeMode>(
      (provider) => provider.themeMode,
    );

    return MaterialApp(
      title: 'TurboSave',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      builder: (context, child) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isDesktop = screenWidth > 860;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
            systemNavigationBarColor: isDark
                ? AppTheme.darkBgSurface
                : AppTheme.lightBgSurface,
            systemNavigationBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
          ),
        );

        return Scaffold(
          backgroundColor: isDark
              ? const Color(0xFF090D14)
              : const Color(0xFFF1F5F9),
          body: Center(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 960 : double.infinity,
              ),
              decoration: isDesktop
                  ? BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      border: Border.symmetric(
                        vertical: BorderSide(
                          color: Theme.of(context).dividerColor
                              .withValues(alpha: 0.6),
                          width: 1,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.45)
                              : Colors.black.withValues(alpha: 0.05),
                          blurRadius: 32,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    )
                  : null,
              child: child!,
            ),
          ),
        );
      },
      home: showOnboarding
          ? const OnboardingScreen()
          : const MainNavigationScreen(),
    );
  }
}
