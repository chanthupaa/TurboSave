# TurboSave Player and Slideshow Design

## Goal

Let users review and download TikTok and Instagram image slideshows while making saved video, audio, and image playback clearer and easier to control on low-end Android phones.

## User flow

- A slideshow post opens the existing review sheet with an Images section.
- Every image is selected initially.
- Each tile has its own selection control, plus Select all and Clear all actions.
- Download selected saves each chosen original image as a separate file through Android DownloadManager.
- Images from one post share collection metadata so Library presents them as one album.
- Opening the album launches the in-app viewer and allows swipe, previous, and next navigation.
- Video/audio playback gains clearer play/pause, 10-second seek, time progress, tap-to-show controls, and accessible labels.

## Architecture

The local yt-dlp extractor will classify safe direct image entries separately from complete video/audio formats. Flutter keeps the existing `FormatOption` and download-task pipeline, adding an image flag and collection metadata instead of introducing a new dependency. Android remains responsible for validating, downloading, and opening files; `PlayerActivity` will support image MIME types and gallery URI lists as well as video/audio.

## Constraints

- Public HTTPS sources only; no login, DRM, paywall, or protection bypass.
- Accept only validated image formats and actual image response signatures.
- Maximum 20 selected images per batch so the existing queue limit remains meaningful.
- No ZIP generation, transcoding, or new Flutter package.
- Controls must remain at least 48dp, have screen-reader labels, support dark surfaces, and offer buttons as alternatives to swipe gestures.

## Verification

- Python extractor tests cover slideshow normalization and reject arbitrary playlists.
- Flutter tests cover image parsing, individual/select-all behavior, durable batch queue records, and grouped Library opening.
- Kotlin JVM tests cover image signatures, MIME validation, and gallery request validation.
- Run Flutter analysis, full Flutter tests, Python tests, Kotlin JVM tests, and build the unrestricted APK.
