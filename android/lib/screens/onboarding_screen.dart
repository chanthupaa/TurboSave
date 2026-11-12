import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/guide_targets.dart';
import '../theme/app_theme.dart';
import 'downloader_screen.dart';
import 'legal_screen.dart';
import 'main_navigation_screen.dart';

class OnboardingScreen extends StatefulWidget {
  static const preferenceKey = 'onboarding_complete_v2';
  final bool isReplay;

  const OnboardingScreen({super.key, this.isReplay = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _targets = GuideTargets();
  int _step = 0;
  bool _finishing = false;
  Rect? _highlightedTarget;

  static const _steps = [
    _GuideStep(
      'Get details',
      'This is the real Home link box. Tap Paste to read your clipboard, or share a public media link to TurboSave from another app.',
    ),
    _GuideStep(
      'Get details',
      'Tap the arrow to fetch the title, thumbnail and available files. Then choose Video or Audio, select a quality, and tap Start download.',
      showDownloadChoices: true,
    ),
    _GuideStep(
      'Use the bottom bar',
      'Home starts downloads. Activity shows progress. Library opens saved files. Settings contains this guide whenever you need it.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _refreshTarget();
  }

  GlobalKey get _target => switch (_step) {
    0 => _targets.linkField,
    1 => _targets.fetchButton,
    _ => _targets.navigation,
  };

  void _refreshTarget() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderObject = _target.currentContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) return;
      final rect = renderObject.localToGlobal(Offset.zero) & renderObject.size;
      setState(() => _highlightedTarget = rect);
    });
  }

  void _next() {
    if (_step == _steps.length - 1) {
      _finish();
      return;
    }
    setState(() {
      _step++;
      _highlightedTarget = null;
    });
    _refreshTarget();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    if (widget.isReplay) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _finishing = true);
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!await preferences.setBool(OnboardingScreen.preferenceKey, true)) {
        throw StateError('Could not save onboarding preference');
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const MainNavigationScreen()),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _finishing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save your preference. Please try again.'),
        ),
      );
    }
  }

  void _legal(bool privacy) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => LegalScreen(privacy: privacy)),
  );

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      AbsorbPointer(
        child: ExcludeSemantics(child: _GuideBackground(targets: _targets)),
      ),
      Positioned.fill(
        child: _GuideOverlay(
          target: _highlightedTarget,
          step: _step,
          total: _steps.length,
          data: _steps[_step],
          finishing: _finishing,
          replay: widget.isReplay,
          onSkip: _finish,
          onNext: _next,
          onPrivacy: () => _legal(true),
          onTerms: () => _legal(false),
        ),
      ),
    ],
  );
}

class _GuideBackground extends StatelessWidget {
  final GuideTargets targets;

  const _GuideBackground({required this.targets});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.canvas(context),
    body: DownloaderScreen(onNavigateToDownloads: () {}, guideTargets: targets),
    bottomNavigationBar: NavigationBar(
      key: targets.navigation,
      backgroundColor: AppTheme.surface(context),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 72,
      selectedIndex: 0,
      onDestinationSelected: (_) {},
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.downloading_outlined),
          selectedIcon: Icon(Icons.downloading_rounded),
          label: 'Activity',
        ),
        NavigationDestination(
          icon: Icon(Icons.video_library_outlined),
          selectedIcon: Icon(Icons.video_library_rounded),
          label: 'Library',
        ),
        NavigationDestination(
          icon: Icon(Icons.tune_rounded),
          selectedIcon: Icon(Icons.tune_rounded),
          label: 'Settings',
        ),
      ],
    ),
  );
}

class _GuideOverlay extends StatelessWidget {
  final Rect? target;
  final int step;
  final int total;
  final _GuideStep data;
  final bool finishing;
  final bool replay;
  final VoidCallback onSkip;
  final VoidCallback onNext;
  final VoidCallback onPrivacy;
  final VoidCallback onTerms;

  const _GuideOverlay({
    required this.target,
    required this.step,
    required this.total,
    required this.data,
    required this.finishing,
    required this.replay,
    required this.onSkip,
    required this.onNext,
    required this.onPrivacy,
    required this.onTerms,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final highlighted = target?.inflate(7);
      final bubbleAbove =
          highlighted != null && highlighted.bottom + 285 > size.height;
      final top = highlighted == null
          ? size.height * .22
          : bubbleAbove
          ? math.max(24.0, highlighted.top - 250)
          : math.min(highlighted.bottom + 18, size.height - 260);
      final reduceMotion = MediaQuery.disableAnimationsOf(context);

      return Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _SpotlightPainter(highlighted)),
            ),
            Positioned(
              left: 18,
              right: 18,
              top: top,
              child: AnimatedSwitcher(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, .04),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: _GuideCard(
                  key: ValueKey(step),
                  step: step,
                  total: total,
                  data: data,
                  arrowDown: bubbleAbove,
                  finishing: finishing,
                  onNext: onNext,
                  onPrivacy: onPrivacy,
                  onTerms: onTerms,
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextButton(
                    onPressed: finishing ? null : onSkip,
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    child: Text(replay ? 'Close' : 'Skip'),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _GuideCard extends StatelessWidget {
  final int step;
  final int total;
  final _GuideStep data;
  final bool arrowDown;
  final bool finishing;
  final VoidCallback onNext;
  final VoidCallback onPrivacy;
  final VoidCallback onTerms;

  const _GuideCard({
    super.key,
    required this.step,
    required this.total,
    required this.data,
    required this.arrowDown,
    required this.finishing,
    required this.onNext,
    required this.onPrivacy,
    required this.onTerms,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppTheme.surface(context),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppTheme.border(context)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 24,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              arrowDown
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: AppTheme.brandBlue,
            ),
            const SizedBox(width: 10),
            Text(
              'Step ${step + 1} of $total',
              style: TextStyle(
                color: AppTheme.textMut(context),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(data.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 7),
        Text(
          data.body,
          style: TextStyle(color: AppTheme.textSec(context), height: 1.45),
        ),
        if (data.showDownloadChoices) ...[
          const SizedBox(height: 12),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _GuidePill('Video'),
              _GuidePill('Audio'),
              _GuidePill('Start download'),
            ],
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: finishing ? null : onNext,
            child: Text(
              finishing
                  ? 'Opening…'
                  : step == total - 1
                  ? 'Done'
                  : 'Continue',
            ),
          ),
        ),
        if (step == total - 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(onPressed: onPrivacy, child: const Text('Privacy')),
              TextButton(onPressed: onTerms, child: const Text('Terms')),
            ],
          ),
      ],
    ),
  );
}

class _GuidePill extends StatelessWidget {
  final String text;
  const _GuidePill(this.text);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: AppTheme.canvas(context),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: AppTheme.border(context)),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: AppTheme.text(context),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _SpotlightPainter extends CustomPainter {
  final Rect? target;
  const _SpotlightPainter(this.target);

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Path()..addRect(Offset.zero & size);
    if (target != null) {
      overlay.addRRect(
        RRect.fromRectAndRadius(target!, const Radius.circular(18)),
      );
      overlay.fillType = PathFillType.evenOdd;
    }
    canvas.drawPath(overlay, Paint()..color = const Color(0xB8000000));
    if (target != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(target!, const Radius.circular(18)),
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.target != target;
}

class _GuideStep {
  final String title;
  final String body;
  final bool showDownloadChoices;

  const _GuideStep(this.title, this.body, {this.showDownloadChoices = false});
}
