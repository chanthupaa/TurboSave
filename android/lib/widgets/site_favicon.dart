import 'package:flutter/material.dart';

import 'brand_logo.dart';

/// Displays the favicon published by a platform for its own domain.
/// Falls back to TurboSave's vector identity when the network icon is absent.
class SiteFavicon extends StatelessWidget {
  final String name;
  final String domain;
  final String? category;
  final double size;
  final double borderRadius;
  final bool enabled;

  const SiteFavicon({
    super.key,
    required this.name,
    required this.domain,
    this.category,
    this.size = 42,
    this.borderRadius = 11,
    this.enabled = false,
  });

  String get _cleanDomain {
    final value = domain.trim().toLowerCase();
    final uri = Uri.tryParse(
      value.startsWith('http://') || value.startsWith('https://')
          ? value
          : 'https://$value',
    );
    return (uri?.host.isNotEmpty ?? false) ? uri!.host : value;
  }

  String get _faviconUrl => Uri.https(
    'www.google.com',
    '/s2/favicons',
    <String, String>{'domain_url': 'https://$_cleanDomain', 'sz': '128'},
  ).toString();

  Widget _fallback() => BrandLogo(
    name: name,
    domain: domain,
    category: category,
    size: size,
    borderRadius: borderRadius,
    showShadow: false,
  );

  @override
  Widget build(BuildContext context) {
    if (!enabled) return _fallback();
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius * 0.68),
        child: Image.network(
          _faviconUrl,
          width: size,
          height: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) return child;
            return _fallback();
          },
          errorBuilder: (_, _, _) => _fallback(),
        ),
      ),
    );
  }
}
