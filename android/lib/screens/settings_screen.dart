import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/legal_content.dart';
import '../services/media_policy.dart';
import '../providers/download_provider.dart';
import '../theme/app_theme.dart';
import 'legal_screen.dart';
import 'onboarding_screen.dart';
import 'supported_sites_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _legal(BuildContext context, bool privacy) => Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => LegalScreen(privacy: privacy)),
  );

  Future<void> _clear(BuildContext context, DownloadProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear private records?'),
        content: const Text(
          'Remove recent links and library records from TurboSave. '
          'Your saved files and Android download records will remain. Active transfers continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep records'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear records'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await provider.clearPrivateRecords();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Local history cleared. Saved files were kept.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DownloadProvider>();
    return ColoredBox(
      color: AppTheme.canvas(context),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Settings',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${MediaPolicy.variantLabel} edition · Local downloads',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 30),
                  const _Label('APPEARANCE'),
                  _Panel(
                    children: [
                      _ThemePicker(
                        mode: provider.themeMode,
                        onChanged: provider.setThemeMode,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const _Label('DOWNLOADS'),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(
                      'Battery-friendly by default: Android handles transfers, progress checks stop in the background, and the library keeps up to 100 local records.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMut(context),
                      ),
                    ),
                  ),
                  _Panel(
                    children: [
                      _SwitchRow(
                        icon: Icons.wifi_rounded,
                        title: 'Wi-Fi only',
                        subtitle: 'Applies to new Android downloads',
                        value: provider.wifiOnly,
                        onChanged: provider.toggleWifiOnly,
                      ),
                      const _Divider(),
                      _InfoRow(
                        icon: Icons.folder_outlined,
                        title: 'Download location',
                        value: provider.storagePath,
                      ),
                      const _Divider(),
                      _ActionRow(
                        icon: Icons.article_outlined,
                        title: 'Open-source licenses',
                        onTap: () => showLicensePage(
                          context: context,
                          applicationName: 'TurboSave',
                          applicationVersion: LegalContent.version,
                        ),
                      ),
                      const _Divider(),
                      const _InfoRow(
                        icon: Icons.high_quality_outlined,
                        title: 'File quality',
                        value: 'Original, unchanged',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const _Label('PRIVACY'),
                  _Panel(
                    children: [
                      _SwitchRow(
                        icon: Icons.history_rounded,
                        title: 'Remember recent links',
                        subtitle: 'Store up to 5 links locally; links with query parameters are excluded',
                        value: provider.rememberHistory,
                        onChanged: provider.toggleHistory,
                      ),
                      const _Divider(),
                      _SwitchRow(
                        icon: Icons.language_rounded,
                        title: 'Website favicons',
                        subtitle: 'Google receives directory domains and your IP to retrieve icons',
                        value: provider.websiteIcons,
                        onChanged: provider.toggleWebsiteIcons,
                      ),
                      const _Divider(),
                      _ActionRow(
                        icon: Icons.cleaning_services_outlined,
                        title: 'Clear history and library records',
                        onTap: () => _clear(context, provider),
                      ),
                      const _Divider(),
                      _ActionRow(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Privacy policy',
                        onTap: () => _legal(context, true),
                      ),
                      const _Divider(),
                      _ActionRow(
                        icon: Icons.description_outlined,
                        title: 'Terms of use',
                        onTap: () => _legal(context, false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const _Label('ABOUT'),
                  _Panel(
                    children: [
                      _ActionRow(
                        icon: Icons.menu_book_outlined,
                        title: 'User guide',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                const OnboardingScreen(isReplay: true),
                          ),
                        ),
                      ),
                      const _Divider(),
                      _ActionRow(
                        icon: Icons.apps_rounded,
                        title: 'Explore sources',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const SupportedSitesScreen(),
                          ),
                        ),
                      ),
                      const _Divider(),
                      const _InfoRow(
                        icon: Icons.info_outline_rounded,
                        title: 'Version',
                        value: LegalContent.version,
                      ),
                      if (LegalContent.supportEmail.isNotEmpty) ...[
                        const _Divider(),
                        const _InfoRow(
                          icon: Icons.mail_outline,
                          title: 'Support and copyright contact',
                          value: LegalContent.supportEmail,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Save only media you own or have permission to download. A public link does not establish copyright permission. '
                    'TurboSave is independent of the listed source organisations.',
                    style: TextStyle(
                      color: AppTheme.textSec(context),
                      fontSize: 12,
                      height: 1.5,
                    ),
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

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 9),
    child: Text(
      text,
      style: TextStyle(
        color: AppTheme.textMut(context),
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.3,
      ),
    ),
  );
}

class _Panel extends StatelessWidget {
  final List<Widget> children;
  const _Panel({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppTheme.surface(context),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppTheme.border(context)),
    ),
    child: Column(children: children),
  );
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, indent: 58, color: AppTheme.border(context));
}

class _ThemePicker extends StatelessWidget {
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;
  const _ThemePicker({required this.mode, required this.onChanged});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(10),
    child: Row(
      children: ThemeMode.values
          .map(
            (item) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: InkWell(
                  onTap: () => onChanged(item),
                  borderRadius: BorderRadius.circular(11),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: mode == item
                          ? AppTheme.text(context)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      item.name[0].toUpperCase() + item.name.substring(1),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: mode == item
                            ? AppTheme.canvas(context)
                            : AppTheme.textSec(context),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    ),
  );
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 11, 10, 11),
    child: Row(
      children: [
        Icon(icon, size: 21, color: AppTheme.textSec(context)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppTheme.text(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppTheme.textMut(context),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: AppTheme.text(context),
          activeThumbColor: AppTheme.canvas(context),
        ),
      ],
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Icon(icon, size: 21, color: AppTheme.textSec(context)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: AppTheme.text(context),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(color: AppTheme.textMut(context), fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, size: 21, color: AppTheme.textSec(context)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: AppTheme.text(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppTheme.textMut(context)),
        ],
      ),
    ),
  );
}
