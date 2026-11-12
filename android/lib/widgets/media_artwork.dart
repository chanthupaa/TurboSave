import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/media_policy.dart';

/// Direct files do not supply a thumbnail. Show honest local artwork without
/// making a request to an unrelated stock-image or avatar host.
class MediaArtwork extends StatelessWidget {
  final bool audio;
  final bool image;
  final double? width;
  final double? height;
  final String thumbnailUrl;
  final Map<String, String> headers;
  const MediaArtwork({
    super.key,
    this.audio = false,
    this.image = false,
    this.width,
    this.height,
    this.thumbnailUrl = '',
    this.headers = const {},
  });

  @override
  Widget build(BuildContext context) {
    Widget fallback() => Icon(
      image
          ? Icons.image_outlined
          : audio
          ? Icons.audio_file_outlined
          : Icons.video_file_outlined,
      color: AppTheme.textSec(context),
      size: 32,
    );
    var valid = false;
    try {
      valid =
          thumbnailUrl.isNotEmpty &&
          MediaPolicy.validate(thumbnailUrl).scheme == 'https';
    } on FormatException {
      /* Use local artwork for unsafe URLs. */
    }
    return Container(
      width: width,
      height: height,
      color: AppTheme.surfaceElevated(context),
      child: valid
          ? Image.network(
              thumbnailUrl,
              headers: headers,
              fit: BoxFit.cover,
              cacheWidth: 320,
              errorBuilder: (_, _, _) => fallback(),
            )
          : fallback(),
    );
  }
}
