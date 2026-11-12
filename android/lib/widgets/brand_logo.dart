// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Offline vector identities and category fallbacks used for source identification.
/// This artwork does not establish affiliation or download rights.
class BrandLogo extends StatelessWidget {
  final String name;
  final String? domain;
  final String? category;
  final double size;
  final double? borderRadius;
  final bool showShadow;

  const BrandLogo({
    super.key,
    required this.name,
    this.domain,
    this.category,
    this.size = 38.0,
    this.borderRadius,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? (size * 0.26);
    final key = _normalizeKey(name, domain);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: _getBrandShadowColor(key),
                  blurRadius: size * 0.22,
                  spreadRadius: 0,
                  offset: Offset(0, size * 0.08),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: _buildLogoWidget(key, size),
      ),
    );
  }

  static String _normalizeKey(String name, String? domain) {
    final lowerName = name.toLowerCase().trim();
    final lowerDomain = (domain ?? '').toLowerCase().trim();

    // 1. Social & Short-form
    if (lowerName.contains('tiktok') || lowerDomain.contains('tiktok'))
      return 'tiktok';
    if (lowerName.contains('instagram') || lowerDomain.contains('instagram'))
      return 'instagram';
    if (lowerName.contains('facebook') ||
        lowerDomain.contains('facebook') ||
        lowerDomain.contains('fb.gg'))
      return 'facebook';
    if (lowerName.contains('twitter') ||
        lowerName.contains('x /') ||
        lowerDomain == 'x.com' ||
        lowerDomain.contains('twitter'))
      return 'x';
    if (lowerName.contains('threads') || lowerDomain.contains('threads'))
      return 'threads';
    if (lowerName.contains('pinterest') || lowerDomain.contains('pinterest'))
      return 'pinterest';
    if (lowerName.contains('snapchat') || lowerDomain.contains('snapchat'))
      return 'snapchat';
    if (lowerName.contains('reddit') || lowerDomain.contains('reddit'))
      return 'reddit';
    if (lowerName.contains('bluesky') || lowerDomain.contains('bsky'))
      return 'bluesky';
    if (lowerName.contains('mastodon') || lowerDomain.contains('mastodon'))
      return 'mastodon';
    if (lowerName.contains('likee') || lowerDomain.contains('likee'))
      return 'likee';
    if (lowerName.contains('kwai') || lowerDomain.contains('kwai'))
      return 'kwai';
    if (lowerName.contains('douyin') || lowerDomain.contains('douyin'))
      return 'douyin';
    if (lowerName.contains('weibo') || lowerDomain.contains('weibo'))
      return 'weibo';
    if (lowerName.contains('xiaohongshu') ||
        lowerDomain.contains('xiaohongshu'))
      return 'xiaohongshu';
    if (lowerName.contains('9gag') || lowerDomain.contains('9gag'))
      return '9gag';
    if (lowerName.contains('imgur') || lowerDomain.contains('imgur'))
      return 'imgur';
    if (lowerName.contains('tumblr') || lowerDomain.contains('tumblr'))
      return 'tumblr';
    if (lowerName.contains('discord') || lowerDomain.contains('discord'))
      return 'discord';
    if (lowerName.contains('telegram') ||
        lowerDomain == 't.me' ||
        lowerDomain.contains('telegram'))
      return 'telegram';
    if (lowerName.contains('linkedin') || lowerDomain.contains('linkedin'))
      return 'linkedin';
    if (lowerName.contains('medium') || lowerDomain.contains('medium'))
      return 'medium';
    if (lowerName.contains('substack') || lowerDomain.contains('substack'))
      return 'substack';
    if (lowerName.contains('quora') || lowerDomain.contains('quora'))
      return 'quora';
    if (lowerName.contains('vkontakte') || lowerDomain.contains('vk.com'))
      return 'vk';
    if (lowerName.contains('odnoklassniki') || lowerDomain.contains('ok.ru'))
      return 'ok';
    if (lowerName.contains('lemon8') || lowerDomain.contains('lemon8'))
      return 'lemon8';
    if (lowerName.contains('bereal') || lowerDomain.contains('bereal'))
      return 'bereal';
    if (lowerName.contains('triller') || lowerDomain.contains('triller'))
      return 'triller';
    if (lowerName.contains('flickr') || lowerDomain.contains('flickr'))
      return 'flickr';
    if (lowerName.contains('deviantart') || lowerDomain.contains('deviantart'))
      return 'deviantart';
    if (lowerName.contains('behance') || lowerDomain.contains('behance'))
      return 'behance';
    if (lowerName.contains('dribbble') || lowerDomain.contains('dribbble'))
      return 'dribbble';
    if (lowerName.contains('unsplash') || lowerDomain.contains('unsplash'))
      return 'unsplash';
    if (lowerName.contains('pexels') || lowerDomain.contains('pexels'))
      return 'pexels';
    if (lowerName.contains('giphy') || lowerDomain.contains('giphy'))
      return 'giphy';

    // 2. Gaming & Esports
    if (lowerName.contains('kick') || lowerDomain.contains('kick.com'))
      return 'kick';
    if (lowerName.contains('trovo') || lowerDomain.contains('trovo'))
      return 'trovo';
    if (lowerName.contains('steam') || lowerDomain.contains('steam'))
      return 'steam';
    if (lowerName.contains('gamespot') || lowerDomain.contains('gamespot'))
      return 'gamespot';
    if (lowerName.contains('ign') || lowerDomain.contains('ign.com'))
      return 'ign';
    if (lowerName.contains('giant bomb') || lowerDomain.contains('giantbomb'))
      return 'giantbomb';
    if (lowerName.contains('medal') || lowerDomain.contains('medal'))
      return 'medal';
    if (lowerName.contains('allstar') || lowerDomain.contains('allstar'))
      return 'allstar';
    if (lowerName.contains('newgrounds') || lowerDomain.contains('newgrounds'))
      return 'newgrounds';
    if (lowerName.contains('roblox') || lowerDomain.contains('roblox'))
      return 'roblox';
    if (lowerName.contains('playstation') ||
        lowerDomain.contains('playstation'))
      return 'playstation';
    if (lowerName.contains('xbox') || lowerDomain.contains('xbox'))
      return 'xbox';
    if (lowerName.contains('nintendo') || lowerDomain.contains('nintendo'))
      return 'nintendo';
    if (lowerName.contains('itch.io') || lowerDomain.contains('itch.io'))
      return 'itchio';

    // 3. Video Platforms
    if (lowerName.contains('twitch') || lowerDomain.contains('twitch'))
      return 'twitch';
    if (lowerName.contains('vimeo') || lowerDomain.contains('vimeo'))
      return 'vimeo';
    if (lowerName.contains('dailymotion') ||
        lowerDomain.contains('dailymotion'))
      return 'dailymotion';
    if (lowerName.contains('rumble') || lowerDomain.contains('rumble'))
      return 'rumble';
    if (lowerName.contains('bilibili') || lowerDomain.contains('bilibili'))
      return 'bilibili';
    if (lowerName.contains('peertube') || lowerDomain.contains('peertube'))
      return 'peertube';
    if (lowerName.contains('odysee') ||
        lowerName.contains('lbry') ||
        lowerDomain.contains('odysee'))
      return 'odysee';
    if (lowerName.contains('archive') || lowerDomain.contains('archive.org'))
      return 'archive';
    if (lowerName.contains('streamable') || lowerDomain.contains('streamable'))
      return 'streamable';
    if (lowerName.contains('bitchute') || lowerDomain.contains('bitchute'))
      return 'bitchute';
    if (lowerName.contains('dtube') || lowerDomain.contains('d.tube'))
      return 'dtube';
    if (lowerName.contains('niconico') || lowerDomain.contains('nicovideo'))
      return 'niconico';
    if (lowerName.contains('rutube') || lowerDomain.contains('rutube'))
      return 'rutube';
    if (lowerName.contains('loom') || lowerDomain.contains('loom'))
      return 'loom';
    if (lowerName.contains('wistia') || lowerDomain.contains('wistia'))
      return 'wistia';
    if (lowerName.contains('vidyard') || lowerDomain.contains('vidyard'))
      return 'vidyard';
    if (lowerName.contains('daily wire') || lowerDomain.contains('dailywire'))
      return 'dailywire';
    if (lowerName.contains('nebula') || lowerDomain.contains('nebula'))
      return 'nebula';
    if (lowerName.contains('curiositystream') ||
        lowerDomain.contains('curiositystream'))
      return 'curiositystream';

    // 4. Audio & Music
    if (lowerName.contains('soundcloud') || lowerDomain.contains('soundcloud'))
      return 'soundcloud';
    if (lowerName.contains('bandcamp') || lowerDomain.contains('bandcamp'))
      return 'bandcamp';
    if (lowerName.contains('mixcloud') || lowerDomain.contains('mixcloud'))
      return 'mixcloud';
    if (lowerName.contains('audiomack') || lowerDomain.contains('audiomack'))
      return 'audiomack';
    if (lowerName.contains('apple podcast') ||
        lowerDomain.contains('podcasts.apple'))
      return 'applepodcasts';
    if (lowerName.contains('spotify') || lowerDomain.contains('spotify'))
      return 'spotify';
    if (lowerName.contains('iheart') || lowerDomain.contains('iheart'))
      return 'iheart';
    if (lowerName.contains('tunein') || lowerDomain.contains('tunein'))
      return 'tunein';
    if (lowerName.contains('jamendo') || lowerDomain.contains('jamendo'))
      return 'jamendo';
    if (lowerName.contains('free music archive') ||
        lowerDomain.contains('freemusicarchive'))
      return 'fma';
    if (lowerName.contains('freesound') || lowerDomain.contains('freesound'))
      return 'freesound';
    if (lowerName.contains('spreaker') || lowerDomain.contains('spreaker'))
      return 'spreaker';
    if (lowerName.contains('podbean') || lowerDomain.contains('podbean'))
      return 'podbean';
    if (lowerName.contains('castbox') || lowerDomain.contains('castbox'))
      return 'castbox';
    if (lowerName.contains('pocket casts') ||
        lowerDomain.contains('pocketcasts'))
      return 'pocketcasts';

    // 5. News & Broadcast
    if (lowerName.contains('bbc') || lowerDomain.contains('bbc.')) return 'bbc';
    if (lowerName.contains('cnn') || lowerDomain.contains('cnn.')) return 'cnn';
    if (lowerName.contains('bloomberg') || lowerDomain.contains('bloomberg'))
      return 'bloomberg';
    if (lowerName.contains('reuters') || lowerDomain.contains('reuters'))
      return 'reuters';
    if (lowerName.contains('associated press') ||
        lowerName.contains('ap news') ||
        lowerDomain.contains('apnews'))
      return 'ap';
    if (lowerName.contains('al jazeera') || lowerDomain.contains('aljazeera'))
      return 'aljazeera';
    if (lowerName.contains('abc news') || lowerDomain.contains('abcnews'))
      return 'abc';
    if (lowerName.contains('cbs news') || lowerDomain.contains('cbsnews'))
      return 'cbs';
    if (lowerName.contains('fox news') || lowerDomain.contains('foxnews'))
      return 'fox';
    if (lowerName.contains('guardian') || lowerDomain.contains('theguardian'))
      return 'guardian';
    if (lowerName.contains('new york times') || lowerDomain.contains('nytimes'))
      return 'nytimes';
    if (lowerName.contains('wall street journal') ||
        lowerName.contains('wsj') ||
        lowerDomain.contains('wsj'))
      return 'wsj';
    if (lowerName.contains('washington post') ||
        lowerDomain.contains('washingtonpost'))
      return 'wapo';
    if (lowerName.contains('forbes') || lowerDomain.contains('forbes'))
      return 'forbes';
    if (lowerName.contains('npr') || lowerDomain.contains('npr.org'))
      return 'npr';
    if (lowerName.contains('pbs') || lowerDomain.contains('pbs.org'))
      return 'pbs';
    if (lowerName.contains('time') || lowerDomain.contains('time.com'))
      return 'time';
    if (lowerName.contains('euronews') || lowerDomain.contains('euronews'))
      return 'euronews';
    if (lowerName.contains('deutsche welle') ||
        lowerName.contains('dw') ||
        lowerDomain.contains('dw.com'))
      return 'dw';
    if (lowerName.contains('cbc') || lowerDomain.contains('cbc.ca'))
      return 'cbc';

    // 6. Education & Learning
    if (lowerName.contains('ted') || lowerDomain.contains('ted.')) return 'ted';
    if (lowerName.contains('khan') || lowerDomain.contains('khanacademy'))
      return 'khanacademy';
    if (lowerName.contains('mit') || lowerDomain.contains('ocw.mit'))
      return 'mit';
    if (lowerName.contains('microsoft') ||
        lowerDomain.contains('learn.microsoft'))
      return 'microsoft';
    if (lowerName.contains('pyvideo') || lowerDomain.contains('pyvideo'))
      return 'pyvideo';
    if (lowerName.contains('coursera') || lowerDomain.contains('coursera'))
      return 'coursera';
    if (lowerName.contains('edx') || lowerDomain.contains('edx.org'))
      return 'edx';
    if (lowerName.contains('udemy') || lowerDomain.contains('udemy'))
      return 'udemy';
    if (lowerName.contains('duolingo') || lowerDomain.contains('duolingo'))
      return 'duolingo';
    if (lowerName.contains('codecademy') || lowerDomain.contains('codecademy'))
      return 'codecademy';
    if (lowerName.contains('freecodecamp') ||
        lowerDomain.contains('freecodecamp'))
      return 'freecodecamp';
    if (lowerName.contains('harvard') || lowerDomain.contains('harvard.edu'))
      return 'harvard';
    if (lowerName.contains('stanford') || lowerDomain.contains('stanford.edu'))
      return 'stanford';
    if (lowerName.contains('nasa') || lowerDomain.contains('nasa.gov'))
      return 'nasa';
    if (lowerName.contains('c-span') || lowerDomain.contains('c-span.org'))
      return 'cspan';

    // 7. Direct
    if (lowerName.contains('direct')) return 'direct';

    return 'dynamic_badge';
  }

  static Color _getBrandShadowColor(String key) {
    switch (key) {
      case 'tiktok':
        return const Color(0x6600F2FE);
      case 'instagram':
        return const Color(0x66E1306C);
      case 'facebook':
        return const Color(0x661877F2);
      case 'x':
      case 'threads':
        return const Color(0x4D000000);
      case 'pinterest':
        return const Color(0x66E60023);
      case 'snapchat':
        return const Color(0x59FFFC00);
      case 'reddit':
        return const Color(0x66FF4500);
      case 'kick':
        return const Color(0x6653FC18);
      case 'trovo':
        return const Color(0x6600F59B);
      case 'steam':
        return const Color(0x59171A21);
      case 'gamespot':
      case 'ign':
        return const Color(0x66E01A22);
      case 'twitch':
        return const Color(0x669146FF);
      case 'vimeo':
        return const Color(0x661AB7EA);
      case 'soundcloud':
        return const Color(0x66FF5500);
      case 'dailymotion':
        return const Color(0x59002A54);
      case 'rumble':
        return const Color(0x6685C744);
      case 'bilibili':
        return const Color(0x6600A1D6);
      case 'spotify':
        return const Color(0x661DB954);
      case 'discord':
        return const Color(0x665865F2);
      case 'telegram':
        return const Color(0x6624A1DE);
      case 'direct':
        return const Color(0x6600F2FE);
      default:
        return const Color(0x3300B4D8);
    }
  }

  Widget _buildLogoWidget(String key, double s) {
    switch (key) {
      case 'tiktok':
        return _buildTikTok(s);
      case 'instagram':
        return _buildInstagram(s);
      case 'facebook':
        return _buildFacebook(s);
      case 'x':
        return _buildX(s);
      case 'threads':
        return _buildThreads(s);
      case 'pinterest':
        return _buildPinterest(s);
      case 'snapchat':
        return _buildSnapchat(s);
      case 'reddit':
        return _buildReddit(s);
      case 'bluesky':
        return _buildBluesky(s);
      case 'mastodon':
        return _buildMastodon(s);
      case 'likee':
        return _buildLikee(s);
      case 'kwai':
        return _buildKwai(s);
      case 'douyin':
        return _buildDouyin(s);
      case 'weibo':
        return _buildWeibo(s);
      case 'xiaohongshu':
        return _buildXiaoHongShu(s);
      case '9gag':
        return _build9GAG(s);
      case 'imgur':
        return _buildImgur(s);
      case 'tumblr':
        return _buildTumblr(s);
      case 'discord':
        return _buildDiscord(s);
      case 'telegram':
        return _buildTelegram(s);
      case 'linkedin':
        return _buildLinkedIn(s);
      case 'medium':
        return _buildMedium(s);
      case 'substack':
        return _buildSubstack(s);
      case 'quora':
        return _buildQuora(s);
      case 'vk':
        return _buildVK(s);
      case 'ok':
        return _buildOK(s);
      case 'lemon8':
        return _buildLemon8(s);
      case 'bereal':
        return _buildBeReal(s);
      case 'triller':
        return _buildTriller(s);
      case 'flickr':
        return _buildFlickr(s);
      case 'deviantart':
        return _buildDeviantArt(s);
      case 'behance':
        return _buildBehance(s);
      case 'dribbble':
        return _buildDribbble(s);
      case 'unsplash':
        return _buildUnsplash(s);
      case 'pexels':
        return _buildPexels(s);
      case 'giphy':
        return _buildGIPHY(s);

      case 'kick':
        return _buildKick(s);
      case 'trovo':
        return _buildTrovo(s);
      case 'steam':
        return _buildSteam(s);
      case 'gamespot':
        return _buildGameSpot(s);
      case 'ign':
        return _buildIGN(s);
      case 'giantbomb':
        return _buildGiantBomb(s);
      case 'medal':
        return _buildMedal(s);
      case 'allstar':
        return _buildAllstar(s);
      case 'newgrounds':
        return _buildNewgrounds(s);
      case 'roblox':
        return _buildRoblox(s);
      case 'playstation':
        return _buildPlayStation(s);
      case 'xbox':
        return _buildXbox(s);
      case 'nintendo':
        return _buildNintendo(s);
      case 'itchio':
        return _buildItchIo(s);

      case 'twitch':
        return _buildTwitch(s);
      case 'vimeo':
        return _buildVimeo(s);
      case 'dailymotion':
        return _buildDailymotion(s);
      case 'rumble':
        return _buildRumble(s);
      case 'bilibili':
        return _buildBilibili(s);
      case 'peertube':
        return _buildPeerTube(s);
      case 'odysee':
        return _buildOdysee(s);
      case 'archive':
        return _buildArchive(s);
      case 'streamable':
        return _buildStreamable(s);
      case 'bitchute':
        return _buildBitChute(s);
      case 'dtube':
        return _buildDTube(s);
      case 'niconico':
        return _buildNiconico(s);
      case 'rutube':
        return _buildRutube(s);
      case 'loom':
        return _buildLoom(s);
      case 'wistia':
        return _buildWistia(s);
      case 'vidyard':
        return _buildVidyard(s);
      case 'dailywire':
        return _buildDailyWire(s);
      case 'nebula':
        return _buildNebula(s);
      case 'curiositystream':
        return _buildCuriosityStream(s);

      case 'soundcloud':
        return _buildSoundCloud(s);
      case 'bandcamp':
        return _buildBandcamp(s);
      case 'mixcloud':
        return _buildMixcloud(s);
      case 'audiomack':
        return _buildAudiomack(s);
      case 'applepodcasts':
        return _buildApplePodcasts(s);
      case 'spotify':
        return _buildSpotify(s);
      case 'iheart':
        return _buildIHeart(s);
      case 'tunein':
        return _buildTuneIn(s);
      case 'jamendo':
        return _buildJamendo(s);
      case 'fma':
        return _buildFMA(s);
      case 'freesound':
        return _buildFreesound(s);
      case 'spreaker':
        return _buildSpreaker(s);
      case 'podbean':
        return _buildPodbean(s);
      case 'castbox':
        return _buildCastbox(s);
      case 'pocketcasts':
        return _buildPocketCasts(s);

      case 'bbc':
        return _buildBBC(s);
      case 'cnn':
        return _buildCNN(s);
      case 'bloomberg':
        return _buildBloomberg(s);
      case 'reuters':
        return _buildReuters(s);
      case 'ap':
        return _buildAP(s);
      case 'aljazeera':
        return _buildAlJazeera(s);
      case 'abc':
        return _buildABC(s);
      case 'cbs':
        return _buildCBS(s);
      case 'fox':
        return _buildFOX(s);
      case 'guardian':
        return _buildGuardian(s);
      case 'nytimes':
        return _buildNYT(s);
      case 'wsj':
        return _buildWSJ(s);
      case 'wapo':
        return _buildWAPO(s);
      case 'forbes':
        return _buildForbes(s);
      case 'npr':
        return _buildNPR(s);
      case 'pbs':
        return _buildPBS(s);
      case 'time':
        return _buildTime(s);
      case 'euronews':
        return _buildEuronews(s);
      case 'dw':
        return _buildDW(s);
      case 'cbc':
        return _buildCBC(s);

      case 'ted':
        return _buildTED(s);
      case 'khanacademy':
        return _buildKhanAcademy(s);
      case 'mit':
        return _buildMIT(s);
      case 'microsoft':
        return _buildMicrosoft(s);
      case 'pyvideo':
        return _buildPyVideo(s);
      case 'coursera':
        return _buildCoursera(s);
      case 'edx':
        return _buildEdX(s);
      case 'udemy':
        return _buildUdemy(s);
      case 'duolingo':
        return _buildDuolingo(s);
      case 'codecademy':
        return _buildCodecademy(s);
      case 'freecodecamp':
        return _buildFreeCodeCamp(s);
      case 'harvard':
        return _buildHarvard(s);
      case 'stanford':
        return _buildStanford(s);
      case 'nasa':
        return _buildNASA(s);
      case 'cspan':
        return _buildCSPAN(s);

      case 'direct':
        return _buildDirect(s);
      default:
        return _buildDynamicBrandBadge(s);
    }
  }

  // ==========================================
  // DYNAMIC CATEGORY-AWARE LUXURY BRAND ENGINE
  // ==========================================
  Widget _buildDynamicBrandBadge(double s) {
    final cat = (category ?? '').toLowerCase();
    final dom = (domain ?? name).toLowerCase();

    // Deterministic 16 premium luxury palettes
    final palettes = [
      [const Color(0xFF00B4D8), const Color(0xFF0077B6)], // Cyan Blue
      [const Color(0xFF7928CA), const Color(0xFFFF0080)], // Neon Violet
      [const Color(0xFF059669), const Color(0xFF10B981)], // Emerald
      [const Color(0xFFE11D48), const Color(0xFFBE123C)], // Crimson
      [const Color(0xFFF59E0B), const Color(0xFFD97706)], // Amber Gold
      [const Color(0xFF6366F1), const Color(0xFF4F46E5)], // Indigo
      [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)], // Purple
      [const Color(0xFF06B6D4), const Color(0xFF0891B2)], // Cyan
      [const Color(0xFF14B8A6), const Color(0xFF0D9488)], // Teal
      [const Color(0xFFEC4899), const Color(0xFFDB2777)], // Pink
      [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)], // Royal Blue
      [const Color(0xFFF97316), const Color(0xFFEA580C)], // Orange
      [const Color(0xFF84CC16), const Color(0xFF65A30D)], // Lime
      [const Color(0xFF64748B), const Color(0xFF334155)], // Slate
      [const Color(0xFF0284C7), const Color(0xFF0369A1)], // Sky
      [const Color(0xFF9333EA), const Color(0xFF7E22CE)], // Violet
    ];

    int hash = 0;
    for (int i = 0; i < dom.length; i++) {
      hash = (hash * 31 + dom.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    final palette = palettes[hash % palettes.length];

    IconData catIcon;
    if (cat.contains('gaming') ||
        dom.contains('game') ||
        dom.contains('play') ||
        dom.contains('esport')) {
      catIcon = Icons.sports_esports_rounded;
    } else if (cat.contains('audio') ||
        dom.contains('music') ||
        dom.contains('sound') ||
        dom.contains('fm') ||
        dom.contains('podcast')) {
      catIcon = Icons.graphic_eq_rounded;
    } else if (cat.contains('news') ||
        dom.contains('news') ||
        dom.contains('press') ||
        dom.contains('times') ||
        dom.contains('post')) {
      catIcon = Icons.newspaper_rounded;
    } else if (cat.contains('education') ||
        dom.contains('edu') ||
        dom.contains('learn') ||
        dom.contains('univ') ||
        dom.contains('academy')) {
      catIcon = Icons.school_rounded;
    } else if (cat.contains('social') ||
        dom.contains('chat') ||
        dom.contains('community') ||
        dom.contains('forum')) {
      catIcon = Icons.hub_rounded;
    } else if (cat.contains('direct')) {
      catIcon = Icons.bolt_rounded;
    } else {
      catIcon = Icons.smart_display_rounded;
    }

    final letter = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '•';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: palette,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background category watermark
          Positioned(
            right: -s * 0.12,
            bottom: -s * 0.12,
            child: Icon(
              catIcon,
              size: s * 0.70,
              color: Colors.white.withValues(alpha: 0.22),
            ),
          ),
          // Clean central brand monogram with glass ring
          Container(
            width: s * 0.60,
            height: s * 0.60,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.30),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.38),
                width: 1.0,
              ),
            ),
            child: Center(
              child: Text(
                letter,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: s * 0.34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SPECIFIC BRAND VECTOR BUILDERS
  // ==========================================

  // 1. TIKTOK
  Widget _buildTikTok(double s) {
    return Container(
      color: const Color(0xFF000000),
      child: Center(
        child: CustomPaint(
          size: Size(s * 0.65, s * 0.65),
          painter: _TikTokPainter(),
        ),
      ),
    );
  }

  // 2. INSTAGRAM
  Widget _buildInstagram(double s) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.8, 1.0),
          radius: 1.4,
          colors: [
            Color(0xFFFFDC80),
            Color(0xFFF77737),
            Color(0xFFFD1D1D),
            Color(0xFFE1306C),
            Color(0xFFC13584),
            Color(0xFF833AB4),
            Color(0xFF4C5FD7),
          ],
          stops: [0.0, 0.15, 0.35, 0.55, 0.70, 0.85, 1.0],
        ),
      ),
      child: Center(
        child: CustomPaint(
          size: Size(s * 0.62, s * 0.62),
          painter: _InstagramPainter(),
        ),
      ),
    );
  }

  // 3. FACEBOOK
  Widget _buildFacebook(double s) {
    return Container(
      color: const Color(0xFF1877F2),
      child: Center(
        child: CustomPaint(
          size: Size(s * 0.60, s * 0.60),
          painter: _FacebookPainter(),
        ),
      ),
    );
  }

  // 4. X / TWITTER
  Widget _buildX(double s) {
    return Container(
      color: const Color(0xFF000000),
      child: Center(
        child: CustomPaint(
          size: Size(s * 0.58, s * 0.58),
          painter: _XPainter(),
        ),
      ),
    );
  }

  // 5. THREADS
  Widget _buildThreads(double s) {
    return Container(
      color: const Color(0xFF101010),
      child: Center(
        child: Text(
          '@',
          style: TextStyle(
            color: Colors.white,
            fontSize: s * 0.66,
            fontWeight: FontWeight.w900,
            height: 1.0,
          ),
        ),
      ),
    );
  }

  // 6. PINTEREST
  Widget _buildPinterest(double s) {
    return Container(
      color: const Color(0xFFE60023),
      child: Center(
        child: Text(
          'P',
          style: TextStyle(
            color: Colors.white,
            fontSize: s * 0.68,
            fontWeight: FontWeight.w900,
            fontFamily: 'serif',
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  // 7. SNAPCHAT
  Widget _buildSnapchat(double s) {
    return Container(
      color: const Color(0xFFFFFC00),
      child: Center(
        child: Icon(
          Icons.sentiment_satisfied_alt_rounded,
          color: Colors.black,
          size: s * 0.62,
        ),
      ),
    );
  }

  // 8. REDDIT
  Widget _buildReddit(double s) {
    return Container(
      color: const Color(0xFFFF4500),
      child: Center(
        child: FaIcon(
          FontAwesomeIcons.redditAlien,
          color: Colors.white,
          size: s * 0.58,
        ),
      ),
    );
  }

  // 9. BLUESKY
  Widget _buildBluesky(double s) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0085FF), Color(0xFF00C6FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.flutter_dash_rounded,
          color: Colors.white,
          size: s * 0.62,
        ),
      ),
    );
  }

  // 10. MASTODON
  Widget _buildMastodon(double s) {
    return Container(
      color: const Color(0xFF6364FF),
      child: Center(
        child: FaIcon(
          FontAwesomeIcons.mastodon,
          color: Colors.white,
          size: s * 0.54,
        ),
      ),
    );
  }

  // 11. LIKEE
  Widget _buildLikee(double s) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF2A6D), Color(0xFFFF9472)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.favorite_rounded,
          color: Colors.white,
          size: s * 0.62,
        ),
      ),
    );
  }

  // 12. KWAI
  Widget _buildKwai(double s) {
    return Container(
      color: const Color(0xFFFF4800),
      child: Center(
        child: Icon(
          Icons.videocam_rounded,
          color: Colors.white,
          size: s * 0.60,
        ),
      ),
    );
  }

  // 13. DOUYIN
  Widget _buildDouyin(double s) {
    return Container(
      color: const Color(0xFF161823),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          color: const Color(0xFF00F2FE),
          size: s * 0.62,
        ),
      ),
    );
  }

  // 14. WEIBO
  Widget _buildWeibo(double s) {
    return Container(
      color: const Color(0xFFE6162D),
      child: Center(
        child: FaIcon(
          FontAwesomeIcons.weibo,
          color: Colors.white,
          size: s * 0.54,
        ),
      ),
    );
  }

  // 15. XIAOHONGSHU
  Widget _buildXiaoHongShu(double s) {
    return Container(
      color: const Color(0xFFFF2442),
      child: Center(
        child: Text(
          'RED',
          style: TextStyle(
            color: Colors.white,
            fontSize: s * 0.32,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  // 16. 9GAG
  Widget _build9GAG(double s) {
    return Container(
      color: const Color(0xFF000000),
      child: Center(
        child: Text(
          '9G',
          style: TextStyle(
            color: Colors.white,
            fontSize: s * 0.45,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  // 17. IMGUR
  Widget _buildImgur(double s) {
    return Container(
      color: const Color(0xFF1BB76E),
      child: Center(
        child: Text(
          'i',
          style: TextStyle(
            color: Colors.white,
            fontSize: s * 0.68,
            fontWeight: FontWeight.w900,
            fontFamily: 'serif',
          ),
        ),
      ),
    );
  }

  // 18. TUMBLR
  Widget _buildTumblr(double s) {
    return Container(
      color: const Color(0xFF36465D),
      child: Center(
        child: FaIcon(
          FontAwesomeIcons.tumblr,
          color: Colors.white,
          size: s * 0.54,
        ),
      ),
    );
  }

  // 19. DISCORD
  Widget _buildDiscord(double s) {
    return Container(
      color: const Color(0xFF5865F2),
      child: Center(
        child: FaIcon(
          FontAwesomeIcons.discord,
          color: Colors.white,
          size: s * 0.56,
        ),
      ),
    );
  }

  // 20. TELEGRAM
  Widget _buildTelegram(double s) {
    return Container(
      color: const Color(0xFF24A1DE),
      child: Center(
        child: FaIcon(
          FontAwesomeIcons.telegram,
          color: Colors.white,
          size: s * 0.56,
        ),
      ),
    );
  }

  // 21. LINKEDIN
  Widget _buildLinkedIn(double s) {
    return Container(
      color: const Color(0xFF0A66C2),
      child: Center(
        child: FaIcon(
          FontAwesomeIcons.linkedinIn,
          color: Colors.white,
          size: s * 0.54,
        ),
      ),
    );
  }

  // 22. MEDIUM
  Widget _buildMedium(double s) {
    return Container(
      color: const Color(0xFF000000),
      child: Center(
        child: FaIcon(
          FontAwesomeIcons.medium,
          color: Colors.white,
          size: s * 0.54,
        ),
      ),
    );
  }

  // 23. SUBSTACK
  Widget _buildSubstack(double s) {
    return Container(
      color: const Color(0xFFFF6719),
      child: Center(
        child: Icon(
          Icons.bookmark_rounded,
          color: Colors.white,
          size: s * 0.60,
        ),
      ),
    );
  }

  // 24. QUORA
  Widget _buildQuora(double s) {
    return Container(
      color: const Color(0xFFB92B27),
      child: Center(
        child: FaIcon(
          FontAwesomeIcons.quora,
          color: Colors.white,
          size: s * 0.54,
        ),
      ),
    );
  }

  // 25. VK
  Widget _buildVK(double s) {
    return Container(
      color: const Color(0xFF0077FF),
      child: Center(
        child: FaIcon(FontAwesomeIcons.vk, color: Colors.white, size: s * 0.54),
      ),
    );
  }

  // 26. OK
  Widget _buildOK(double s) {
    return Container(
      color: const Color(0xFFEE8208),
      child: Center(
        child: FaIcon(
          FontAwesomeIcons.odnoklassniki,
          color: Colors.white,
          size: s * 0.54,
        ),
      ),
    );
  }

  // 27. LEMON8
  Widget _buildLemon8(double s) {
    return Container(
      color: const Color(0xFFFFE600),
      child: Center(
        child: Text(
          'L8',
          style: TextStyle(
            color: Colors.black,
            fontSize: s * 0.42,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  // 28. BEREAL
  Widget _buildBeReal(double s) {
    return Container(
      color: const Color(0xFF000000),
      child: Center(
        child: Text(
          'BeReal.',
          style: TextStyle(
            color: Colors.white,
            fontSize: s * 0.22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  // 29. TRILLER
  Widget _buildTriller(double s) {
    return Container(
      color: const Color(0xFFFF007A),
      child: Center(
        child: Text(
          'TR',
          style: TextStyle(
            color: Colors.white,
            fontSize: s * 0.44,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  // 30. FLICKR
  Widget _buildFlickr(double s) {
    return Container(
      color: const Color(0xFFF3F5F8),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: s * 0.22,
              height: s * 0.22,
              decoration: const BoxDecoration(
                color: Color(0xFF0063DC),
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: s * 0.08),
            Container(
              width: s * 0.22,
              height: s * 0.22,
              decoration: const BoxDecoration(
                color: Color(0xFFFF0084),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 31. DEVIANTART
  Widget _buildDeviantArt(double s) {
    return Container(
      color: const Color(0xFF05CC47),
      child: Center(
        child: FaIcon(
          FontAwesomeIcons.deviantart,
          color: Colors.white,
          size: s * 0.54,
        ),
      ),
    );
  }

  // 32. BEHANCE
  Widget _buildBehance(double s) {
    return Container(
      color: const Color(0xFF1769FF),
      child: Center(
        child: FaIcon(
          FontAwesomeIcons.behance,
          color: Colors.white,
          size: s * 0.54,
        ),
      ),
    );
  }

  // 33. DRIBBBLE
  Widget _buildDribbble(double s) {
    return Container(
      color: const Color(0xFFEA4C89),
      child: Center(
        child: FaIcon(
          FontAwesomeIcons.dribbble,
          color: Colors.white,
          size: s * 0.54,
        ),
      ),
    );
  }

  // 34. UNSPLASH
  Widget _buildUnsplash(double s) {
    return Container(
      color: const Color(0xFF000000),
      child: Center(
        child: FaIcon(
          FontAwesomeIcons.unsplash,
          color: Colors.white,
          size: s * 0.54,
        ),
      ),
    );
  }

  // 35. PEXELS
  Widget _buildPexels(double s) {
    return Container(
      color: const Color(0xFF05A081),
      child: Center(
        child: Text(
          'P',
          style: TextStyle(
            color: Colors.white,
            fontSize: s * 0.60,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  // 36. GIPHY
  Widget _buildGIPHY(double s) {
    return Container(
      color: const Color(0xFF121212),
      child: Center(
        child: Text(
          'GIPHY',
          style: TextStyle(
            color: const Color(0xFF00FF99),
            fontSize: s * 0.22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  // 37. KICK (Official Neon Green + Bold K)
  Widget _buildKick(double s) {
    return Container(
      color: const Color(0xFF53FC18), // Official Kick neon green
      child: Center(
        child: Text(
          'K',
          style: TextStyle(
            color: Colors.black,
            fontSize: s * 0.68,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  // 38. TROVO (Official Obsidian + Cyan/Green Logo)
  Widget _buildTrovo(double s) {
    return Container(
      color: const Color(0xFF121926),
      child: Center(
        child: Icon(
          Icons.sports_esports_rounded,
          color: const Color(0xFF00F59B), // Trovo neon green
          size: s * 0.62,
        ),
      ),
    );
  }

  // 39. STEAM (Official Valve Crank/Piston Vector)
  Widget _buildSteam(double s) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF171A21), Color(0xFF1B2838)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: FaIcon(
          FontAwesomeIcons.steam,
          color: Colors.white,
          size: s * 0.60,
        ),
      ),
    );
  }

  // 40. GAMESPOT (Official Red + Radar GS)
  Widget _buildGameSpot(double s) {
    return Container(
      color: const Color(0xFFE01A22), // GameSpot red
      child: Center(
        child: Text(
          'GS',
          style: TextStyle(
            color: Colors.white,
            fontSize: s * 0.44,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.0,
          ),
        ),
      ),
    );
  }

  // 41. IGN (Official Crimson + IGN Emblem)
  Widget _buildIGN(double s) {
    return Container(
      color: const Color(0xFFBF1313), // IGN crimson
      child: Center(
        child: Text(
          'IGN',
          style: TextStyle(
            color: Colors.white,
            fontSize: s * 0.38,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  // 42. GIANT BOMB
  Widget _buildGiantBomb(double s) {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: Center(
        child: Icon(
          Icons.brightness_low_rounded,
          color: const Color(0xFFFF5500),
          size: s * 0.62,
        ),
      ),
    );
  }

  // 43. MEDAL.TV
  Widget _buildMedal(double s) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF8A00), Color(0xFFE52E71)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.military_tech_rounded,
          color: Colors.white,
          size: s * 0.62,
        ),
      ),
    );
  }

  // 44. ALLSTAR
  Widget _buildAllstar(double s) {
    return Container(
      color: const Color(0xFF5865F2),
      child: Center(
        child: Icon(
          Icons.star_rounded,
          color: const Color(0xFFFFDF00),
          size: s * 0.65,
        ),
      ),
    );
  }

  // 45. NEWGROUNDS
  Widget _buildNewgrounds(double s) {
    return Container(
      color: const Color(0xFFFF9900), // Newgrounds orange
      child: Center(
        child: Icon(Icons.shield_rounded, color: Colors.white, size: s * 0.62),
      ),
    );
  }

  // 46. ROBLOX
  Widget _buildRoblox(double s) {
    return Container(
      color: const Color(0xFF191B1D),
      child: Center(
        child: Transform.rotate(
          angle: 0.18,
          child: Container(
            width: s * 0.44,
            height: s * 0.44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(s * 0.08),
            ),
            child: Center(
              child: Container(
                width: s * 0.16,
                height: s * 0.16,
                decoration: BoxDecoration(
                  color: const Color(0xFF191B1D),
                  borderRadius: BorderRadius.circular(s * 0.04),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 47. PLAYSTATION
  Widget _buildPlayStation(double s) {
    return Container(
      color: const Color(0xFF003791),
      child: Center(
        child: FaIcon(
          FontAwesomeIcons.playstation,
          color: Colors.white,
          size: s * 0.54,
        ),
      ),
    );
  }

  // 48. XBOX
  Widget _buildXbox(double s) {
    return Container(
      color: const Color(0xFF107C10),
      child: Center(
        child: FaIcon(
          FontAwesomeIcons.xbox,
          color: Colors.white,
          size: s * 0.58,
        ),
      ),
    );
  }

  // 49. NINTENDO
  Widget _buildNintendo(double s) {
    return Container(
      color: const Color(0xFFE60012),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: s * 0.08,
            vertical: s * 0.04,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(s * 0.2),
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: Text(
            'N',
            style: TextStyle(
              color: Colors.white,
              fontSize: s * 0.38,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  // 50. ITCH.IO
  Widget _buildItchIo(double s) {
    return Container(
      color: const Color(0xFFFA5C5C),
      child: Center(
        child: FaIcon(
          FontAwesomeIcons.itchIo,
          color: Colors.white,
          size: s * 0.54,
        ),
      ),
    );
  }

  // 51. TWITCH
  Widget _buildTwitch(double s) {
    return Container(
      color: const Color(0xFF9146FF),
      child: Center(
        child: FaIcon(
          FontAwesomeIcons.twitch,
          color: Colors.white,
          size: s * 0.56,
        ),
      ),
    );
  }

  // 52. VIMEO
  Widget _buildVimeo(double s) {
    return Container(
      color: const Color(0xFF1AB7EA),
      child: Center(
        child: FaIcon(
          FontAwesomeIcons.vimeoV,
          color: Colors.white,
          size: s * 0.54,
        ),
      ),
    );
  }

  // 53. DAILYMOTION
  Widget _buildDailymotion(double s) {
    return Container(
      color: const Color(0xFF002A54),
      child: Center(
        child: Text(
          'd',
          style: TextStyle(
            color: Colors.white,
            fontSize: s * 0.68,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  // 54. RUMBLE
  Widget _buildRumble(double s) {
    return Container(
      color: const Color(0xFF85C744),
      child: Center(
        child: Icon(
          Icons.play_arrow_rounded,
          color: Colors.white,
          size: s * 0.68,
        ),
      ),
    );
  }

  // 55. BILIBILI
  Widget _buildBilibili(double s) {
    return Container(
      color: const Color(0xFF00A1D6),
      child: Center(
        child: Icon(Icons.tv_rounded, color: Colors.white, size: s * 0.62),
      ),
    );
  }

  // 56. PEERTUBE
  Widget _buildPeerTube(double s) {
    return Container(
      color: const Color(0xFFF1680D),
      child: Center(
        child: Icon(
          Icons.play_circle_filled_rounded,
          color: Colors.white,
          size: s * 0.62,
        ),
      ),
    );
  }

  // 57. ODYSEE
  Widget _buildOdysee(double s) {
    return Container(
      color: const Color(0xFFEF1962),
      child: Center(
        child: Icon(Icons.explore_rounded, color: Colors.white, size: s * 0.62),
      ),
    );
  }

  // 58. INTERNET ARCHIVE
  Widget _buildArchive(double s) {
    return Container(
      color: const Color(0xFF1C1C1C),
      child: Center(
        child: Icon(
          Icons.account_balance_rounded,
          color: Colors.white,
          size: s * 0.58,
        ),
      ),
    );
  }

  // 59. STREAMABLE
  Widget _buildStreamable(double s) {
    return Container(
      color: const Color(0xFF0E76A8),
      child: Center(
        child: Icon(Icons.link_rounded, color: Colors.white, size: s * 0.60),
      ),
    );
  }

  // 60. BITCHUTE
  Widget _buildBitChute(double s) {
    return Container(
      color: const Color(0xFFFF5722),
      child: Center(
        child: Icon(
          Icons.play_circle_filled_rounded,
          color: Colors.white,
          size: s * 0.62,
        ),
      ),
    );
  }

  // 61. DTUBE
  Widget _buildDTube(double s) {
    return Container(
      color: const Color(0xFFE91E63),
      child: Center(
        child: Icon(
          Icons.play_arrow_rounded,
          color: Colors.white,
          size: s * 0.65,
        ),
      ),
    );
  }

  // 62. NICONICO
  Widget _buildNiconico(double s) {
    return Container(
      color: const Color(0xFF252525),
      child: Center(
        child: Icon(Icons.tv_rounded, color: Colors.white, size: s * 0.62),
      ),
    );
  }

  // 63. RUTUBE
  Widget _buildRutube(double s) {
    return Container(
      color: const Color(0xFF000000),
      child: Center(
        child: Text(
          'RU',
          style: TextStyle(
            color: const Color(0xFFE5261E),
            fontSize: s * 0.42,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  // 64. LOOM
  Widget _buildLoom(double s) {
    return Container(
      color: const Color(0xFF625DF5),
      child: Center(
        child: Icon(Icons.flare_rounded, color: Colors.white, size: s * 0.62),
      ),
    );
  }

  // 65. WISTIA
  Widget _buildWistia(double s) {
    return Container(
      color: const Color(0xFF54BBFF),
      child: Center(
        child: Icon(Icons.flag_rounded, color: Colors.white, size: s * 0.62),
      ),
    );
  }

  // 66. VIDYARD
  Widget _buildVidyard(double s) {
    return Container(
      color: const Color(0xFF00B159),
      child: Center(
        child: Icon(
          Icons.videocam_rounded,
          color: Colors.white,
          size: s * 0.62,
        ),
      ),
    );
  }

  // 67. DAILY WIRE
  Widget _buildDailyWire(double s) {
    return Container(
      color: const Color(0xFF000000),
      child: Center(
        child: Text(
          'DW',
          style: TextStyle(
            color: const Color(0xFFE50914),
            fontSize: s * 0.44,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  // 68. NEBULA
  Widget _buildNebula(double s) {
    return Container(
      color: const Color(0xFF1E1435),
      child: Center(
        child: Icon(
          Icons.auto_awesome_rounded,
          color: const Color(0xFF9D65C9),
          size: s * 0.62,
        ),
      ),
    );
  }

  // 69. CURIOSITYSTREAM
  Widget _buildCuriosityStream(double s) {
    return Container(
      color: const Color(0xFFFFB300),
      child: Center(
        child: Text(
          'Q',
          style: TextStyle(
            color: Colors.black,
            fontSize: s * 0.62,
            fontWeight: FontWeight.w900,
            fontFamily: 'serif',
          ),
        ),
      ),
    );
  }

  // 70. SOUNDCLOUD
  Widget _buildSoundCloud(double s) {
    return Container(
      color: const Color(0xFFFF5500),
      child: Center(
        child: FaIcon(
          FontAwesomeIcons.soundcloud,
          color: Colors.white,
          size: s * 0.58,
        ),
      ),
    );
  }

  // 71. BANDCAMP
  Widget _buildBandcamp(double s) {
    return Container(
      color: const Color(0xFF1DA0C3),
      child: Center(
        child: FaIcon(
          FontAwesomeIcons.bandcamp,
          color: Colors.white,
          size: s * 0.54,
        ),
      ),
    );
  }

  // 72. MIXCLOUD
  Widget _buildMixcloud(double s) {
    return Container(
      color: const Color(0xFF5000FF),
      child: Center(
        child: FaIcon(
          FontAwesomeIcons.mixcloud,
          color: Colors.white,
          size: s * 0.54,
        ),
      ),
    );
  }

  // 73. AUDIOMACK
  Widget _buildAudiomack(double s) {
    return Container(
      color: const Color(0xFFFF9900),
      child: Center(
        child: Icon(
          Icons.graphic_eq_rounded,
          color: Colors.black,
          size: s * 0.62,
        ),
      ),
    );
  }

  // 74. APPLE PODCASTS
  Widget _buildApplePodcasts(double s) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFB134EB), Color(0xFF6B26CE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.podcasts_rounded,
          color: Colors.white,
          size: s * 0.62,
        ),
      ),
    );
  }

  // 75. SPOTIFY
  Widget _buildSpotify(double s) {
    return Container(
      color: const Color(0xFF1DB954),
      child: Center(
        child: FaIcon(
          FontAwesomeIcons.spotify,
          color: Colors.black,
          size: s * 0.58,
        ),
      ),
    );
  }

  // 76. IHEARTRADIO
  Widget _buildIHeart(double s) {
    return Container(
      color: const Color(0xFFC6002B),
      child: Center(
        child: Icon(
          Icons.favorite_rounded,
          color: Colors.white,
          size: s * 0.60,
        ),
      ),
    );
  }

  // 77. TUNEIN
  Widget _buildTuneIn(double s) {
    return Container(
      color: const Color(0xFF1C2029),
      child: Center(
        child: Text(
          'T',
          style: TextStyle(
            color: const Color(0xFF00D4FF),
            fontSize: s * 0.60,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  // 78. JAMENDO
  Widget _buildJamendo(double s) {
    return Container(
      color: const Color(0xFFE84281),
      child: Center(
        child: Icon(
          Icons.play_circle_filled_rounded,
          color: Colors.white,
          size: s * 0.60,
        ),
      ),
    );
  }

  // 79. FREE MUSIC ARCHIVE
  Widget _buildFMA(double s) {
    return Container(
      color: const Color(0xFF007BFF),
      child: Center(
        child: Text(
          'FMA',
          style: TextStyle(
            color: Colors.white,
            fontSize: s * 0.32,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  // 80. FREESOUND
  Widget _buildFreesound(double s) {
    return Container(
      color: const Color(0xFF000000),
      child: Center(
        child: Icon(
          Icons.graphic_eq_rounded,
          color: const Color(0xFFFFCC00),
          size: s * 0.60,
        ),
      ),
    );
  }

  // 81. SPREAKER
  Widget _buildSpreaker(double s) {
    return Container(
      color: const Color(0xFFFFBE00),
      child: Center(
        child: Icon(Icons.star_rounded, color: Colors.black, size: s * 0.62),
      ),
    );
  }

  // 82. PODBEAN
  Widget _buildPodbean(double s) {
    return Container(
      color: const Color(0xFF7CB342),
      child: Center(
        child: Icon(
          Icons.podcasts_rounded,
          color: Colors.white,
          size: s * 0.60,
        ),
      ),
    );
  }

  // 83. CASTBOX
  Widget _buildCastbox(double s) {
    return Container(
      color: const Color(0xFFF57C00),
      child: Center(
        child: Icon(
          Icons.speaker_group_rounded,
          color: Colors.white,
          size: s * 0.58,
        ),
      ),
    );
  }

  // 84. POCKET CASTS
  Widget _buildPocketCasts(double s) {
    return Container(
      color: const Color(0xFFF43E37),
      child: Center(
        child: Icon(
          Icons.radio_button_checked_rounded,
          color: Colors.white,
          size: s * 0.62,
        ),
      ),
    );
  }

  // 85. BBC
  Widget _buildBBC(double s) {
    return Container(
      color: const Color(0xFFBB1919),
      padding: EdgeInsets.symmetric(horizontal: s * 0.12),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: ['B', 'B', 'C'].map((letter) {
            return Container(
              margin: EdgeInsets.symmetric(horizontal: s * 0.02),
              width: s * 0.22,
              height: s * 0.22,
              color: Colors.white,
              child: Center(
                child: Text(
                  letter,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: s * 0.16,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // 86. CNN
  Widget _buildCNN(double s) {
    return Container(
      color: const Color(0xFFCC0000),
      child: Center(
        child: Text(
          'CNN',
          style: TextStyle(
            color: Colors.white,
            fontSize: s * 0.36,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }

  // 87. BLOOMBERG
  Widget _buildBloomberg(double s) {
    return Container(
      color: const Color(0xFF000000),
      child: Center(
        child: Text(
          'B',
          style: TextStyle(
            color: Colors.white,
            fontSize: s * 0.62,
            fontWeight: FontWeight.w900,
            fontFamily: 'serif',
          ),
        ),
      ),
    );
  }

  // 88. REUTERS
  Widget _buildReuters(double s) {
    return Container(
      color: const Color(0xFFFF8000),
      child: Center(
        child: Icon(
          Icons.donut_large_rounded,
          color: Colors.white,
          size: s * 0.62,
        ),
      ),
    );
  }

  // 89. AP
  Widget _buildAP(double s) {
    return Container(
      color: const Color(0xFF000000),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'AP',
              style: TextStyle(
                color: Colors.white,
                fontSize: s * 0.38,
                fontWeight: FontWeight.w900,
              ),
            ),
            Container(
              width: s * 0.44,
              height: 2,
              color: const Color(0xFFEE3224),
            ),
          ],
        ),
      ),
    );
  }

  // 90. AL JAZEERA
  Widget _buildAlJazeera(double s) {
    return Container(
      color: const Color(0xFFC78F1E),
      child: Center(
        child: Icon(
          Icons.local_fire_department_rounded,
          color: Colors.white,
          size: s * 0.62,
        ),
      ),
    );
  }

  // 91. ABC NEWS
  Widget _buildABC(double s) {
    return Container(
      color: const Color(0xFF000000),
      child: Center(
        child: Text(
          'abc',
          style: TextStyle(
            color: Colors.white,
            fontSize: s * 0.38,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  // 92. CBS NEWS
  Widget _buildCBS(double s) {
    return Container(
      color: const Color(0xFF002244),
      child: Center(
        child: Icon(
          Icons.remove_red_eye_rounded,
          color: Colors.white,
          size: s * 0.62,
        ),
      ),
    );
  }

  // 93. FOX NEWS
  Widget _buildFOX(double s) {
    return Container(
      color: const Color(0xFF003366),
      child: Center(
        child: Text(
          'FOX',
          style: TextStyle(
            color: Colors.white,
            fontSize: s * 0.34,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  // 94. THE GUARDIAN
  Widget _buildGuardian(double s) {
    return Container(
      color: const Color(0xFF052962),
      child: Center(
        child: Text(
          'G',
          style: TextStyle(
            color: const Color(0xFFFFE500),
            fontSize: s * 0.62,
            fontWeight: FontWeight.w900,
            fontFamily: 'serif',
          ),
        ),
      ),
    );
  }

  // 95. NYT
  Widget _buildNYT(double s) {
    return Container(
      color: const Color(0xFF121212),
      child: Center(
        child: Text(
          'T',
          style: TextStyle(
            color: Colors.white,
            fontSize: s * 0.65,
            fontWeight: FontWeight.w900,
            fontFamily: 'serif',
          ),
        ),
      ),
    );
  }

  // 96. WSJ
  Widget _buildWSJ(double s) {
    return Container(
      color: const Color(0xFF000000),
      child: Center(
        child: Text(
          'WSJ',
          style: TextStyle(
            color: Colors.white,
            fontSize: s * 0.32,
            fontWeight: FontWeight.w900,
            fontFamily: 'serif',
          ),
        ),
      ),
    );
  }

  // 97. WASHINGTON POST
  Widget _buildWAPO(double s) {
    return Container(
      color: const Color(0xFF231F20),
      child: Center(
        child: Text(
          'WP',
          style: TextStyle(
            color: Colors.white,
            fontSize: s * 0.40,
            fontWeight: FontWeight.w900,
            fontFamily: 'serif',
          ),
        ),
      ),
    );
  }

  // 98. FORBES
  Widget _buildForbes(double s) {
    return Container(
      color: const Color(0xFF111111),
      child: Center(
        child: Text(
          'F',
          style: TextStyle(
            color: Colors.white,
            fontSize: s * 0.65,
            fontWeight: FontWeight.w900,
            fontFamily: 'serif',
          ),
        ),
      ),
    );
  }

  // 99. NPR
  Widget _buildNPR(double s) {
    return Container(
      color: const Color(0xFF000000),
      child: Center(
        child: Text(
          'npr',
          style: TextStyle(
            color: Colors.white,
            fontSize: s * 0.36,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  // 100. PBS
  Widget _buildPBS(double s) {
    return Container(
      color: const Color(0xFF004990),
      child: Center(
        child: Text(
          'PBS',
          style: TextStyle(
            color: Colors.white,
            fontSize: s * 0.34,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  // 101. TIME
  Widget _buildTime(double s) {
    return Container(
      color: const Color(0xFFE90000),
      child: Center(
        child: Text(
          'TIME',
          style: TextStyle(
            color: Colors.white,
            fontSize: s * 0.30,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  // 102. EURONEWS
  Widget _buildEuronews(double s) {
    return Container(
      color: const Color(0xFF003399),
      child: Center(
        child: Text(
          'euro',
          style: TextStyle(
            color: Colors.white,
            fontSize: s * 0.32,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  // 103. DEUTSCHE WELLE
  Widget _buildDW(double s) {
    return Container(
      color: const Color(0xFF0064B4),
      child: Center(
        child: Text(
          'DW',
          style: TextStyle(
            color: Colors.white,
            fontSize: s * 0.40,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  // 104. CBC
  Widget _buildCBC(double s) {
    return Container(
      color: const Color(0xFFD60000),
      child: Center(
        child: Icon(
          Icons.circle_notifications_rounded,
          color: Colors.white,
          size: s * 0.62,
        ),
      ),
    );
  }

  // 105. TED
  Widget _buildTED(double s) {
    return Container(
      color: const Color(0xFFE62B1E),
      child: Center(
        child: Text(
          'TED',
          style: TextStyle(
            color: Colors.white,
            fontSize: s * 0.38,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  // 106. KHAN ACADEMY
  Widget _buildKhanAcademy(double s) {
    return Container(
      color: const Color(0xFF14BF96),
      child: Center(
        child: Icon(Icons.eco_rounded, color: Colors.white, size: s * 0.60),
      ),
    );
  }

  // 107. MIT OCW
  Widget _buildMIT(double s) {
    return Container(
      color: const Color(0xFFA31F34),
      child: Center(
        child: Text(
          'MIT',
          style: TextStyle(
            color: Colors.white,
            fontSize: s * 0.38,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  // 108. MICROSOFT LEARN
  Widget _buildMicrosoft(double s) {
    return Container(
      color: const Color(0xFF000000),
      padding: EdgeInsets.all(s * 0.22),
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: s * 0.05,
        crossAxisSpacing: s * 0.05,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          ColoredBox(color: Color(0xFFF25022)),
          ColoredBox(color: Color(0xFF7FBA00)),
          ColoredBox(color: Color(0xFF00A4EF)),
          ColoredBox(color: Color(0xFFFFB900)),
        ],
      ),
    );
  }

  // 109. PYVIDEO
  Widget _buildPyVideo(double s) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3776AB), Color(0xFFFFD43B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.play_circle_filled_rounded,
          color: Colors.white,
          size: s * 0.62,
        ),
      ),
    );
  }

  // 110. COURSERA
  Widget _buildCoursera(double s) {
    return Container(
      color: const Color(0xFF0056D2),
      child: Center(
        child: Text(
          'C',
          style: TextStyle(
            color: Colors.white,
            fontSize: s * 0.62,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  // 111. EDX
  Widget _buildEdX(double s) {
    return Container(
      color: const Color(0xFFB72626),
      child: Center(
        child: Text(
          'edX',
          style: TextStyle(
            color: Colors.white,
            fontSize: s * 0.38,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  // 112. UDEMY
  Widget _buildUdemy(double s) {
    return Container(
      color: const Color(0xFFA435F0),
      child: Center(
        child: Icon(
          Icons.navigation_rounded,
          color: Colors.white,
          size: s * 0.58,
        ),
      ),
    );
  }

  // 113. DUOLINGO
  Widget _buildDuolingo(double s) {
    return Container(
      color: const Color(0xFF58CC02),
      child: Center(
        child: Icon(
          Icons.sentiment_very_satisfied_rounded,
          color: Colors.white,
          size: s * 0.65,
        ),
      ),
    );
  }

  // 114. CODECADEMY
  Widget _buildCodecademy(double s) {
    return Container(
      color: const Color(0xFF1F2430),
      child: Center(
        child: Text(
          '>_',
          style: TextStyle(
            color: const Color(0xFF388E3C),
            fontSize: s * 0.44,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  // 115. FREECODECAMP
  Widget _buildFreeCodeCamp(double s) {
    return Container(
      color: const Color(0xFF0A0A23),
      child: Center(
        child: Icon(
          Icons.local_fire_department_rounded,
          color: const Color(0xFFFF9C00),
          size: s * 0.65,
        ),
      ),
    );
  }

  // 116. HARVARD
  Widget _buildHarvard(double s) {
    return Container(
      color: const Color(0xFFA51C30),
      child: Center(
        child: Text(
          'H',
          style: TextStyle(
            color: Colors.white,
            fontSize: s * 0.60,
            fontWeight: FontWeight.w900,
            fontFamily: 'serif',
          ),
        ),
      ),
    );
  }

  // 117. STANFORD
  Widget _buildStanford(double s) {
    return Container(
      color: const Color(0xFF8C1515),
      child: Center(
        child: Text(
          'S',
          style: TextStyle(
            color: Colors.white,
            fontSize: s * 0.60,
            fontWeight: FontWeight.w900,
            fontFamily: 'serif',
          ),
        ),
      ),
    );
  }

  // 118. NASA
  Widget _buildNASA(double s) {
    return Container(
      color: const Color(0xFF0B3D91),
      child: Center(
        child: Text(
          'NASA',
          style: TextStyle(
            color: Colors.white,
            fontSize: s * 0.28,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  // 119. C-SPAN
  Widget _buildCSPAN(double s) {
    return Container(
      color: const Color(0xFF0D3B66),
      child: Center(
        child: Text(
          'C-SPAN',
          style: TextStyle(
            color: Colors.white,
            fontSize: s * 0.24,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  // 120. DIRECT STREAMS
  Widget _buildDirect(double s) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF00F2FE), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(Icons.bolt_rounded, color: Colors.white, size: s * 0.62),
      ),
    );
  }
}

// ==========================================
// CUSTOM PAINTER: TIKTOK CHROMATIC 3D GLYPH
// ==========================================
class _TikTokPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    Path createNotePath() {
      final p = Path();
      p.moveTo(w * 0.56, h * 0.15);
      p.cubicTo(w * 0.62, h * 0.15, w * 0.72, h * 0.22, w * 0.78, h * 0.32);
      p.cubicTo(w * 0.84, h * 0.40, w * 0.88, h * 0.46, w * 0.94, h * 0.48);
      p.lineTo(w * 0.94, h * 0.32);
      p.cubicTo(w * 0.82, h * 0.30, w * 0.72, h * 0.20, w * 0.68, h * 0.10);
      p.lineTo(w * 0.56, h * 0.10);
      p.close();

      final stem = Path();
      stem.moveTo(w * 0.56, h * 0.10);
      stem.lineTo(w * 0.68, h * 0.10);
      stem.lineTo(w * 0.68, h * 0.64);
      stem.cubicTo(w * 0.68, h * 0.76, w * 0.54, h * 0.86, w * 0.38, h * 0.86);
      stem.cubicTo(w * 0.22, h * 0.86, w * 0.10, h * 0.75, w * 0.10, h * 0.61);
      stem.cubicTo(w * 0.10, h * 0.48, w * 0.22, h * 0.38, w * 0.38, h * 0.38);
      stem.cubicTo(w * 0.45, h * 0.38, w * 0.51, h * 0.41, w * 0.56, h * 0.46);
      stem.close();

      return Path.combine(PathOperation.union, p, stem);
    }

    final note = createNotePath();

    final cyanPaint = Paint()
      ..color = const Color(0xFF00F2FE)
      ..style = PaintingStyle.fill;
    canvas.save();
    canvas.translate(-w * 0.045, -h * 0.035);
    canvas.drawPath(note, cyanPaint);
    canvas.restore();

    final pinkPaint = Paint()
      ..color = const Color(0xFFFE2C55)
      ..style = PaintingStyle.fill;
    canvas.save();
    canvas.translate(w * 0.045, h * 0.035);
    canvas.drawPath(note, pinkPaint);
    canvas.restore();

    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawPath(note, whitePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ==========================================
// CUSTOM PAINTER: INSTAGRAM CAMERA VECTOR
// ==========================================
class _InstagramPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokeW = size.width * 0.095;
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final pad = strokeW * 0.65;
    final rect = Rect.fromLTWH(
      pad,
      pad,
      size.width - pad * 2,
      size.height - pad * 2,
    );
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size.width * 0.28),
    );
    canvas.drawRRect(rrect, strokePaint);

    final center = Offset(size.width * 0.5, size.height * 0.5);
    canvas.drawCircle(center, size.width * 0.22, strokePaint);

    final flashCenter = Offset(size.width * 0.74, size.height * 0.26);
    canvas.drawCircle(flashCenter, size.width * 0.045, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ==========================================
// CUSTOM PAINTER: FACEBOOK OFFSET 'f'
// ==========================================
class _FacebookPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final p = Path();
    p.moveTo(w * 0.62, h * 1.0);
    p.lineTo(w * 0.62, h * 0.60);
    p.lineTo(w * 0.78, h * 0.60);
    p.lineTo(w * 0.81, h * 0.44);
    p.lineTo(w * 0.62, h * 0.44);
    p.lineTo(w * 0.62, h * 0.33);
    p.cubicTo(w * 0.62, h * 0.26, w * 0.65, h * 0.21, w * 0.74, h * 0.21);
    p.lineTo(w * 0.82, h * 0.21);
    p.lineTo(w * 0.82, h * 0.07);
    p.cubicTo(w * 0.77, h * 0.06, w * 0.69, h * 0.05, w * 0.60, h * 0.05);
    p.cubicTo(w * 0.42, h * 0.05, w * 0.30, h * 0.16, w * 0.30, h * 0.36);
    p.lineTo(w * 0.30, h * 0.44);
    p.lineTo(w * 0.15, h * 0.44);
    p.lineTo(w * 0.15, h * 0.60);
    p.lineTo(w * 0.30, h * 0.60);
    p.lineTo(w * 0.30, h * 1.0);
    p.close();

    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ==========================================
// CUSTOM PAINTER: X / TWITTER VECTOR
// ==========================================
class _XPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final p = Path();
    p.moveTo(w * 0.05, h * 0.05);
    p.lineTo(w * 0.38, h * 0.05);
    p.lineTo(w * 0.95, h * 0.95);
    p.lineTo(w * 0.62, h * 0.95);
    p.close();

    final p2 = Path();
    p2.moveTo(w * 0.95, h * 0.05);
    p2.lineTo(w * 0.75, h * 0.05);
    p2.lineTo(w * 0.05, h * 0.95);
    p2.lineTo(w * 0.25, h * 0.95);
    p2.close();

    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawPath(p, paint);
    canvas.drawPath(p2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
