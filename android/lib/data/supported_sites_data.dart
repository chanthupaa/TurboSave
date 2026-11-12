/// Featured examples for discovery, not an allowlist or a verified-site count.
/// Any public HTTPS page may be attempted; individual posts and formats can fail.
class SupportedSitesData {
  static const allSites = <Map<String, String>>[
    {
      'name': 'Pexels',
      'domain': 'pexels.com',
      'cat': 'Stock',
      'kind': 'file',
      'note': 'Use an original video-file link. Check the Pexels licence and rights of people or brands shown.',
      'url': 'https://www.pexels.com/videos/',
      'guidance': 'https://www.pexels.com/license/',
    },
    {
      'name': 'Pixabay',
      'domain': 'pixabay.com',
      'cat': 'Stock',
      'kind': 'file',
      'note': 'Use a complete video or audio-file link. Read the content licence; standalone redistribution is restricted.',
      'url': 'https://pixabay.com/videos/',
      'guidance': 'https://pixabay.com/service/license-summary/',
    },
    {
      'name': 'Mixkit',
      'domain': 'mixkit.co',
      'cat': 'Stock',
      'kind': 'file',
      'note': 'Use the original media-file link. Free and Restricted licences differ; check the selected item.',
      'url': 'https://mixkit.co/free-stock-video/',
      'guidance': 'https://mixkit.co/license/',
    },
    {
      'name': 'Coverr',
      'domain': 'coverr.co',
      'cat': 'Stock',
      'kind': 'file',
      'note': 'Use an original file you are permitted to download. Do not resell clips or build a competing stock library.',
      'url': 'https://coverr.co/',
      'guidance': 'https://coverr.co/license',
    },
    {
      'name': 'NASA Media Library',
      'domain': 'images.nasa.gov',
      'cat': 'Space',
      'kind': 'file',
      'note': 'Use an original video or audio-file link. Read NASA guidelines and any third-party credits.',
      'url': 'https://images.nasa.gov/',
      'guidance': 'https://www.nasa.gov/nasa-brand-center/images-and-media/',
    },
    {
      'name': 'NASA Visualizations',
      'domain': 'svs.gsfc.nasa.gov',
      'cat': 'Space',
      'kind': 'file',
      'note': 'Choose a downloadable movie file, not an image sequence or live stream. Check the asset credits.',
      'url': 'https://svs.gsfc.nasa.gov/',
      'guidance': 'https://svs.gsfc.nasa.gov/help/',
    },
    {
      'name': 'ESO Video Archive',
      'domain': 'eso.org',
      'cat': 'Space',
      'kind': 'file',
      'note': 'Use a complete video-file link. Preserve the stated credits and check exceptions to the general licence.',
      'url': 'https://www.eso.org/public/videos/',
      'guidance': 'https://www.eso.org/public/outreach/copyright/',
    },
    {
      'name': 'ESA / Hubble',
      'domain': 'esahubble.org',
      'cat': 'Space',
      'kind': 'file',
      'note': 'Use a downloadable video file with its full credit. Music and third-party material may have different terms.',
      'url': 'https://esahubble.org/videos/',
      'guidance': 'https://esahubble.org/copyright/',
    },
    {
      'name': 'ESA / Webb',
      'domain': 'esawebb.org',
      'cat': 'Space',
      'kind': 'file',
      'note': 'Use an original video-file link and preserve its credit. Review the rights attached to the individual asset.',
      'url': 'https://esawebb.org/videos/',
      'guidance': 'https://esawebb.org/copyright/',
    },
    {
      'name': 'MIT OpenCourseWare',
      'domain': 'ocw.mit.edu',
      'cat': 'Education',
      'kind': 'file',
      'note': 'Use an authorised downloadable lecture file. YouTube embeds remain blocked; check attribution and noncommercial terms.',
      'url': 'https://ocw.mit.edu/',
      'guidance': 'https://ocw.mit.edu/pages/privacy-and-terms-of-use/',
    },
    {
      'name': 'OpenLearn',
      'domain': 'open.edu',
      'cat': 'Education',
      'kind': 'file',
      'note': 'Use a downloadable audio or video file. Check the course licence and separately credited material.',
      'url': 'https://www.open.edu/openlearn/',
      'guidance': 'https://www.open.edu/openlearn/about-openlearn/frequently-asked-questions-on-openlearn',
    },
    {
      'name': 'TED',
      'domain': 'ted.com',
      'cat': 'Education',
      'note': 'Public talks with a complete file may work. Follow TED usage terms; YouTube embeds and protected streams are excluded.',
      'guidance': 'https://www.ted.com/about/our-organization/our-policies-terms/ted-talks-usage-policy',
    },
    {
      'name': 'CCC Conference Media',
      'domain': 'media.ccc.de',
      'cat': 'Education',
      'note': 'Recorded talks with downloadable files. Check the recording licence; live streams are unsupported.',
      'guidance': 'https://media.ccc.de/about.html',
    },
    {
      'name': 'Free Music Archive',
      'domain': 'freemusicarchive.org',
      'cat': 'Audio',
      'kind': 'file',
      'note': 'Use a public audio-file link. Each track has its own Creative Commons, public-domain or custom licence.',
      'guidance': 'https://freemusicarchive.org/terms_of_use',
    },
    {
      'name': 'Jamendo Music',
      'domain': 'jamendo.com',
      'cat': 'Audio',
      'kind': 'file',
      'note': 'Check the individual track download terms and use a public audio-file link. Paid or private downloads are excluded.',
      'guidance': 'https://www.jamendo.com/legal/creative-commons',
    },
    {
      'name': 'Musopen',
      'domain': 'musopen.org',
      'cat': 'Audio',
      'kind': 'file',
      'note': 'Use an authorised public audio-file link. Verify the recording rights in your country; login-only files are unsupported.',
      'guidance': 'https://musopen.org/faq/',
    },
    {
      'name': 'Wistia',
      'domain': 'wistia.com',
      'cat': 'Video',
      'note': 'Public media where the owner enables downloading and grants permission. Private or restricted share links are unsupported.',
      'guidance': 'https://support.wistia.com/en/articles/8234473-share-your-wistia-videos',
    },
    {
      'name': 'TikTok',
      'domain': 'tiktok.com',
      'cat': 'Social',
      'note': 'Public video posts; availability varies by post and region.',
    },
    {
      'name': 'Instagram',
      'domain': 'instagram.com',
      'cat': 'Social',
      'note': 'Public reels and posts with an accessible media file.',
    },
    {
      'name': 'Facebook',
      'domain': 'facebook.com',
      'cat': 'Social',
      'note': 'Public video posts; private posts are unavailable.',
    },
    {
      'name': 'Threads',
      'domain': 'threads.net',
      'cat': 'Social',
      'note': 'Public posts containing downloadable media.',
    },
    {
      'name': 'X / Twitter',
      'domain': 'x.com',
      'cat': 'Social',
      'note': 'Public media posts; some links may require login.',
    },
    {
      'name': 'Reddit',
      'domain': 'reddit.com',
      'cat': 'Social',
      'note': 'Public video posts with a complete file format.',
    },
    {
      'name': 'Pinterest',
      'domain': 'pinterest.com',
      'cat': 'Social',
      'note': 'Public video pins with an accessible file.',
    },
    {
      'name': 'Tumblr',
      'domain': 'tumblr.com',
      'cat': 'Social',
      'note': 'Public media posts with a supported file.',
    },
    {
      'name': 'Bluesky',
      'domain': 'bsky.app',
      'cat': 'Social',
      'note': 'Public video posts with a complete file.',
    },
    {
      'name': 'Vimeo',
      'domain': 'vimeo.com',
      'cat': 'Video',
      'note': 'Videos where the owner permits downloading.',
    },
    {
      'name': 'Dailymotion',
      'domain': 'dailymotion.com',
      'cat': 'Video',
      'note': 'Public videos with a complete file.',
    },
    {
      'name': 'Streamable',
      'domain': 'streamable.com',
      'cat': 'Video',
      'note': 'Public clips with an accessible file.',
    },
    {
      'name': 'Rumble',
      'domain': 'rumble.com',
      'cat': 'Video',
      'note': 'Public videos with a supported file.',
    },
    {
      'name': 'Odysee',
      'domain': 'odysee.com',
      'cat': 'Video',
      'note': 'Public videos with permitted downloads.',
    },
    {
      'name': 'Imgur',
      'domain': 'imgur.com',
      'cat': 'Media',
      'note': 'Public posts containing downloadable video.',
    },
    {
      'name': 'Flickr',
      'domain': 'flickr.com',
      'cat': 'Media',
      'note': 'Media whose owner and licence allow downloading.',
    },
    {
      'name': 'GIPHY',
      'domain': 'giphy.com',
      'cat': 'Media',
      'note': 'Public clips with a supported file format.',
    },
    {
      'name': 'SoundCloud',
      'domain': 'soundcloud.com',
      'cat': 'Audio',
      'note': 'Tracks where the artist permits downloading.',
    },
    {
      'name': 'Mixcloud',
      'domain': 'mixcloud.com',
      'cat': 'Audio',
      'note': 'Public audio where download rights allow it.',
    },
    {
      'name': 'Bandcamp',
      'domain': 'bandcamp.com',
      'cat': 'Audio',
      'note': 'Tracks with an artist-authorised download.',
    },
    {
      'name': 'Blender Open Movies',
      'kind': 'file',
      'domain': 'download.blender.org',
      'cat': 'Video',
      'note':
          'Open movie downloads. Check the project licence and attribution.',
      'url':
          'https://download.blender.org/durian/trailer/sintel_trailer-480p.mp4',
    },
    {
      'name': 'Wikimedia Commons files',
      'kind': 'file',
      'domain': 'upload.wikimedia.org',
      'cat': 'Media',
      'note': 'Use the original media file URL. Read its Commons licence page first.',
      'url': 'https://commons.wikimedia.org',
    },
    {
      'name': 'Internet Archive files',
      'kind': 'file',
      'domain': 'archive.org',
      'cat': 'Media',
      'note': 'Only owned, public-domain or appropriately licensed items. Use the file download URL.',
      'url': 'https://archive.org',
    },
  ];

  static int get totalSitesCount => allSites.length;

  static String linkLabel(Map<String, String> site) =>
      site['kind'] == 'file' ? 'Use a media-file link' : 'Public page links';

  static List<Map<String, String>> search(String query, String category) {
    final needle = query.trim().toLowerCase();
    return allSites
        .where(
          (site) =>
              (category == 'All' || site['cat'] == category) &&
              (needle.isEmpty ||
                  [site['name'], site['domain'], site['cat']].any(
                    (value) => value?.toLowerCase().contains(needle) ?? false,
                  )),
        )
        .toList();
  }
}
