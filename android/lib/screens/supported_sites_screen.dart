import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/supported_sites_data.dart';
import '../providers/download_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/site_favicon.dart';

class SupportedSitesScreen extends StatefulWidget {
  const SupportedSitesScreen({super.key});
  @override
  State<SupportedSitesScreen> createState() => _SupportedSitesScreenState();
}

class _SupportedSitesScreenState extends State<SupportedSitesScreen> {
  final _search = TextEditingController();
  String category = 'All';
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _copy(BuildContext context, String address) async {
    await Clipboard.setData(ClipboardData(text: address));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Address copied. Open it in your browser.')),
    );
  }

  void _guidance(Map<String, String> site) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              site['name']!,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(site['note']!, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 16),
            Text(
              SupportedSitesData.linkLabel(site),
              style: const TextStyle(
                color: AppTheme.brandBlue,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              site['kind'] == 'file'
                  ? 'Open the official site, check the selected item’s terms, and copy its original HTTPS video, audio or image-file address. Paste that file address on Home—not a ZIP or streaming playlist.'
                  : 'Paste an individual public media page on Home. It must expose a complete downloadable file or a supported TikTok/Instagram slideshow, and you must have permission to save it.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            const Text(
              'Directory inclusion is not a verified download or Google Play approval. Login-only, protected and blocked content is unavailable.',
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () =>
                  _copy(context, site['url'] ?? 'https://${site['domain']}'),
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copy website address'),
            ),
            if (site['guidance'] != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _copy(context, site['guidance']!),
                icon: const Icon(Icons.policy_outlined),
                label: const Text('Copy licence / help address'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = <String>{
      'All',
      ...SupportedSitesData.allSites.map((site) => site['cat'] ?? 'Other'),
    }.toList();
    final filtered = SupportedSitesData.search(_search.text, category);
    final icons = context.select<DownloadProvider, bool>(
      (provider) => provider.websiteIcons,
    );
    return Scaffold(
      backgroundColor: AppTheme.canvas(context),
      appBar: AppBar(
        backgroundColor: AppTheme.canvas(context),
        title: const Text(
          'Explore sources',
          style: TextStyle(fontFamily: 'Manrope'),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Find your next source',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${SupportedSitesData.totalSitesCount} source examples—not a site limit or an approved-site list.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.surface(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.border(context)),
                          ),
                          child: const Text(
                            'Tap a source for link and licence guidance. Some need a media-file address. Downloads are not guaranteed.',
                            style: TextStyle(fontSize: 12, height: 1.5),
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Search name, domain or category',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _search.text.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Clear search',
                                    icon: const Icon(Icons.close_rounded),
                                    onPressed: () => setState(_search.clear),
                                  ),
                            fillColor: AppTheme.surface(context),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height:
                              (MediaQuery.textScalerOf(context).scale(14) + 26)
                                  .clamp(44.0, 100.0),
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: categories.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (_, index) {
                              final item = categories[index];
                              final selected = item == category;
                              return ChoiceChip(
                                label: Text(item),
                                selected: selected,
                                onSelected: (_) =>
                                    setState(() => category = item),
                                showCheckmark: false,
                                selectedColor: AppTheme.text(context),
                                backgroundColor: AppTheme.surface(context),
                                labelStyle: TextStyle(
                                  color: selected
                                      ? AppTheme.canvas(context)
                                      : AppTheme.textSec(context),
                                  fontWeight: FontWeight.w700,
                                ),
                                side: BorderSide(
                                  color: AppTheme.border(context),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '${filtered.length} examples',
                          style: TextStyle(
                            color: AppTheme.textMut(context),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (filtered.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No matching examples. Clear your search or try another category. You can also paste a public link on Home.',
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final site = filtered[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: AppTheme.surface(context),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: AppTheme.border(context)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _guidance(site),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SiteFavicon(
                                    name: site['name']!,
                                    domain: site['domain']!,
                                    category: site['cat'],
                                    size: 42,
                                    borderRadius: 11,
                                    enabled: icons,
                                  ),
                                  const SizedBox(width: 13),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          site['name']!,
                                          style: TextStyle(
                                            color: AppTheme.text(context),
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          site['domain']!,
                                          style: TextStyle(
                                            color: AppTheme.textMut(context),
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          site['note']!,
                                          style: TextStyle(
                                            color: AppTheme.textSec(context),
                                            fontSize: 12,
                                            height: 1.5,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          children: [
                                            _badge(context, site['cat']!),
                                            _badge(
                                              context,
                                              SupportedSitesData.linkLabel(
                                                site,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppTheme.textMut(context),
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }, childCount: filtered.length),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(BuildContext context, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: AppTheme.surfaceElevated(context),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: AppTheme.textSec(context),
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
