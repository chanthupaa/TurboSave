package com.turbosave.videodownloader

import android.app.Activity
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.SeekBar
import android.widget.TextView
import android.widget.Toast
import android.widget.VideoView
import kotlin.math.max

internal fun isPlayableMime(mime: String): Boolean =
    mime.startsWith("video/") || mime.startsWith("audio/")

internal fun isViewableMime(mime: String): Boolean =
    isPlayableMime(mime) || mime in setOf("image/jpeg", "image/png", "image/webp")

internal data class GalleryItem(val id: Long, val uri: String, val mime: String)

internal fun validateGalleryItems(raw: List<*>): List<GalleryItem> {
    require(raw.isNotEmpty() && raw.size <= 20) { "Choose between 1 and 20 slideshow images." }
    return raw.map { value ->
        require(value is Map<*, *>) { "The slideshow item is invalid." }
        val id = (value["id"] as? Number)?.toLong() ?: error("Missing download ID")
        val uri = value["uri"] as? String ?: error("Missing saved image URI")
        val mime = value["mimeType"] as? String ?: error("Missing image type")
        require(uri.startsWith("content://")) { "Only files saved by TurboSave can be opened." }
        require(mime in setOf("image/jpeg", "image/png", "image/webp")) { "This slideshow item is not an image." }
        GalleryItem(id, uri, mime)
    }
}

class PlayerActivity : Activity() {
    private lateinit var root: FrameLayout
    private lateinit var player: VideoView
    private lateinit var playPause: ImageButton
    private lateinit var seek: SeekBar
    private lateinit var time: TextView
    private var playbackControls: View? = null
    private var close: View? = null
    private var prepared = false
    private var resumePosition = 0
    private var resumePlaying = true

    private var galleryUris = arrayListOf<Uri>()
    private var galleryIndex = 0
    private var galleryGeneration = 0
    private var galleryBitmap: Bitmap? = null
    private var galleryControls: View? = null
    private lateinit var galleryImage: ImageView
    private lateinit var galleryCounter: TextView
    private lateinit var previous: ImageButton
    private lateinit var next: ImageButton

    private val progressHandler = Handler(Looper.getMainLooper())
    private val updateProgress = object : Runnable {
        override fun run() {
            if (prepared && ::seek.isInitialized) {
                seek.progress = runCatching { player.currentPosition }.getOrDefault(0).coerceAtLeast(0)
                updateTime()
                progressHandler.postDelayed(this, 500)
            }
        }
    }
    private val hideControls = Runnable {
        if (prepared && player.isPlaying && intent.type?.startsWith("video/") == true) {
            playbackControls?.visibility = View.GONE
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.statusBarColor = Color.BLACK
        window.navigationBarColor = Color.BLACK
        root = FrameLayout(this).apply { setBackgroundColor(Color.BLACK) }
        setContentView(root)
        showFullscreen()

        @Suppress("DEPRECATION")
        val suppliedGallery = intent.getParcelableArrayListExtra<Uri>("galleryUris")
        if (!suppliedGallery.isNullOrEmpty()) {
            galleryUris = suppliedGallery.take(20).toCollection(arrayListOf())
            galleryIndex = savedInstanceState?.getInt("galleryIndex")?.coerceIn(0, galleryUris.lastIndex) ?: 0
            buildGallery()
            return
        }

        val uri = intent?.data
        val mime = intent?.type.orEmpty()
        if (uri?.scheme != "content" || !isViewableMime(mime)) {
            fail("This saved media cannot be opened.")
            return
        }
        if (mime.startsWith("image/")) {
            galleryUris.add(uri)
            buildGallery()
            return
        }
        resumePosition = savedInstanceState?.getInt("position") ?: 0
        resumePlaying = savedInstanceState?.getBoolean("playing") ?: true
        buildPlayer(uri, mime)
    }

    private fun buildPlayer(uri: Uri, mime: String) {
        player = VideoView(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
                Gravity.CENTER,
            )
            setOnClickListener { togglePlaybackControls() }
        }
        root.addView(player)
        if (mime.startsWith("audio/")) root.addView(audioArtwork(uri))
        playbackControls = playbackControls().also(root::addView)
        close = closeButton().also(root::addView)

        player.setVideoURI(uri)
        player.setOnPreparedListener { media ->
            prepared = true
            seek.max = media.duration.coerceAtLeast(1)
            if (resumePosition > 0) player.seekTo(resumePosition.coerceAtMost(seek.max))
            if (resumePlaying) player.start()
            updatePlayPause()
            updateTime()
            progressHandler.post(updateProgress)
            scheduleControlsHide()
        }
        player.setOnCompletionListener {
            progressHandler.removeCallbacks(hideControls)
            playbackControls?.visibility = View.VISIBLE
            updatePlayPause()
            updateTime()
        }
        player.setOnErrorListener { _, _, _ ->
            fail("TurboSave could not play this file.")
            true
        }
        player.requestFocus()
    }

    private fun playbackControls(): View = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        setPadding(dp(12), dp(8), dp(12), dp(10))
        setBackgroundColor(0xCC101010.toInt())
        layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.WRAP_CONTENT,
            Gravity.BOTTOM,
        )
        seek = SeekBar(this@PlayerActivity).apply {
            max = 1
            contentDescription = "Playback position"
            setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(bar: SeekBar?, value: Int, fromUser: Boolean) {
                    if (fromUser) updateTime(value)
                }
                override fun onStartTrackingTouch(bar: SeekBar?) = progressHandler.removeCallbacks(hideControls)
                override fun onStopTrackingTouch(bar: SeekBar?) {
                    player.seekTo(bar?.progress ?: 0)
                    scheduleControlsHide()
                }
            })
        }
        addView(seek, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(44)))
        addView(LinearLayout(this@PlayerActivity).apply {
            gravity = Gravity.CENTER_VERTICAL
            addView(mediaButton(android.R.drawable.ic_media_rew, "Back 10 seconds") {
                seekTo((player.currentPosition - 10_000).coerceAtLeast(0))
            })
            playPause = mediaButton(android.R.drawable.ic_media_play, "Play") {
                if (player.isPlaying) player.pause() else player.start()
                updatePlayPause()
                scheduleControlsHide()
            }
            addView(playPause)
            addView(mediaButton(android.R.drawable.ic_media_ff, "Forward 10 seconds") {
                seekTo((player.currentPosition + 10_000).coerceAtMost(seek.max))
            })
            time = TextView(this@PlayerActivity).apply {
                text = "0:00 / 0:00"
                textSize = 13f
                setTextColor(Color.WHITE)
                gravity = Gravity.CENTER_VERTICAL or Gravity.END
            }
            addView(time, LinearLayout.LayoutParams(0, dp(48), 1f))
        })
    }

    private fun mediaButton(icon: Int, description: String, action: () -> Unit) =
        ImageButton(this).apply {
            setImageResource(icon)
            contentDescription = description
            setColorFilter(Color.WHITE)
            setBackgroundColor(Color.TRANSPARENT)
            setOnClickListener { action() }
            layoutParams = LinearLayout.LayoutParams(dp(52), dp(48))
        }

    private fun seekTo(position: Int) {
        player.seekTo(position)
        seek.progress = position
        updateTime(position)
        scheduleControlsHide()
    }

    private fun togglePlaybackControls() {
        val controls = playbackControls ?: return
        controls.visibility = if (controls.visibility == View.VISIBLE) View.GONE else View.VISIBLE
        if (controls.visibility == View.VISIBLE) scheduleControlsHide()
    }

    private fun scheduleControlsHide() {
        progressHandler.removeCallbacks(hideControls)
        if (prepared && player.isPlaying && intent.type?.startsWith("video/") == true) {
            progressHandler.postDelayed(hideControls, 3_000)
        }
    }

    private fun updatePlayPause() {
        if (!::playPause.isInitialized) return
        val playing = prepared && player.isPlaying
        playPause.setImageResource(if (playing) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play)
        playPause.contentDescription = if (playing) "Pause" else "Play"
    }

    private fun updateTime(position: Int = runCatching { player.currentPosition }.getOrDefault(0).coerceAtLeast(0)) {
        if (!::time.isInitialized || !::seek.isInitialized) return
        time.text = "${formatTime(position)} / ${formatTime(seek.max)}"
    }

    private fun formatTime(milliseconds: Int): String {
        val seconds = milliseconds.coerceAtLeast(0) / 1000
        return "%d:%02d".format(seconds / 60, seconds % 60)
    }

    private fun buildGallery() {
        galleryImage = ImageView(this).apply {
            scaleType = ImageView.ScaleType.FIT_CENTER
            setBackgroundColor(Color.BLACK)
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            )
            setOnClickListener { toggleGalleryControls() }
            var downX = 0f
            setOnTouchListener { _, event ->
                when (event.actionMasked) {
                    MotionEvent.ACTION_DOWN -> downX = event.x
                    MotionEvent.ACTION_UP -> {
                        val delta = event.x - downX
                        if (delta > dp(64)) showGalleryImage(galleryIndex - 1)
                        else if (delta < -dp(64)) showGalleryImage(galleryIndex + 1)
                        else performClick()
                    }
                }
                true
            }
        }
        root.addView(galleryImage)
        galleryControls = galleryControls().also(root::addView)
        close = closeButton().also(root::addView)
        showGalleryImage(galleryIndex)
    }

    private fun galleryControls(): View = LinearLayout(this).apply {
        gravity = Gravity.CENTER
        orientation = LinearLayout.HORIZONTAL
        setPadding(dp(16), dp(8), dp(16), dp(8))
        setBackgroundColor(0xCC101010.toInt())
        layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            dp(64),
            Gravity.BOTTOM,
        )
        previous = mediaButton(android.R.drawable.ic_media_previous, "Previous image") {
            showGalleryImage(galleryIndex - 1)
        }
        addView(previous)
        galleryCounter = TextView(this@PlayerActivity).apply {
            setTextColor(Color.WHITE)
            textSize = 15f
            gravity = Gravity.CENTER
        }
        addView(galleryCounter, LinearLayout.LayoutParams(0, dp(48), 1f))
        next = mediaButton(android.R.drawable.ic_media_next, "Next image") {
            showGalleryImage(galleryIndex + 1)
        }
        addView(next)
    }

    private fun showGalleryImage(index: Int) {
        if (index !in galleryUris.indices) return
        galleryIndex = index
        val generation = ++galleryGeneration
        galleryCounter.text = "${index + 1} / ${galleryUris.size}"
        galleryImage.contentDescription = "Image ${index + 1} of ${galleryUris.size}"
        previous.isEnabled = index > 0
        previous.alpha = if (previous.isEnabled) 1f else .35f
        next.isEnabled = index < galleryUris.lastIndex
        next.alpha = if (next.isEnabled) 1f else .35f
        Thread {
            val bitmap = decodeSampled(galleryUris[index])
            runOnUiThread {
                if (isDestroyed || generation != galleryGeneration) {
                    bitmap?.recycle()
                    return@runOnUiThread
                }
                val old = galleryBitmap
                galleryBitmap = bitmap
                galleryImage.setImageBitmap(bitmap)
                old?.recycle()
                if (bitmap == null) Toast.makeText(this, "This image could not be displayed.", Toast.LENGTH_LONG).show()
            }
        }.start()
    }

    private fun decodeSampled(uri: Uri): Bitmap? = runCatching {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
        val targetWidth = max(resources.displayMetrics.widthPixels, 1)
        val targetHeight = max(resources.displayMetrics.heightPixels, 1)
        var sample = 1
        while (bounds.outWidth / (sample * 2) >= targetWidth && bounds.outHeight / (sample * 2) >= targetHeight) sample *= 2
        val options = BitmapFactory.Options().apply { inSampleSize = sample }
        contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, options) }
    }.getOrNull()

    private fun toggleGalleryControls() {
        val controls = galleryControls ?: return
        val visible = controls.visibility == View.VISIBLE
        controls.visibility = if (visible) View.GONE else View.VISIBLE
        close?.visibility = if (visible) View.GONE else View.VISIBLE
    }

    private fun audioArtwork(uri: Uri): View = LinearLayout(this).apply {
        layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT,
        )
        gravity = Gravity.CENTER
        orientation = LinearLayout.VERTICAL
        isClickable = false
        addView(TextView(this@PlayerActivity).apply {
            text = "AUDIO"
            textSize = 18f
            gravity = Gravity.CENTER
            setTextColor(Color.LTGRAY)
        })
        addView(TextView(this@PlayerActivity).apply {
            text = displayName(uri)
            textSize = 18f
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            setPadding(dp(48), dp(12), dp(48), 0)
        })
    }

    private fun closeButton(): View = ImageButton(this).apply {
        setImageResource(android.R.drawable.ic_menu_close_clear_cancel)
        contentDescription = "Close viewer"
        setColorFilter(Color.WHITE)
        setBackgroundColor(0x66000000)
        setOnClickListener { finish() }
        layoutParams = FrameLayout.LayoutParams(dp(56), dp(56), Gravity.TOP or Gravity.START).apply {
            setMargins(dp(8), dp(8), 0, 0)
        }
    }

    private fun displayName(uri: Uri): String = runCatching {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) cursor.getString(0) else null
        }
    }.getOrNull().orEmpty().ifBlank { "Saved audio" }

    private fun showFullscreen() {
        if (android.os.Build.VERSION.SDK_INT >= 30) {
            window.insetsController?.apply {
                hide(WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars())
                systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility =
                View.SYSTEM_UI_FLAG_FULLSCREEN or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
        }
    }

    private fun fail(message: String) {
        Toast.makeText(this, message, Toast.LENGTH_LONG).show()
        finish()
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        if (galleryUris.isNotEmpty()) outState.putInt("galleryIndex", galleryIndex)
        if (prepared) {
            outState.putInt("position", runCatching { player.currentPosition }.getOrDefault(0))
            outState.putBoolean("playing", player.isPlaying)
        }
    }

    override fun onPause() {
        if (prepared) {
            resumePosition = runCatching { player.currentPosition }.getOrDefault(0)
            resumePlaying = player.isPlaying
            if (player.isPlaying) player.pause()
            updatePlayPause()
        }
        progressHandler.removeCallbacks(updateProgress)
        progressHandler.removeCallbacks(hideControls)
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        if (prepared) {
            if (resumePlaying) player.start()
            progressHandler.post(updateProgress)
            updatePlayPause()
            scheduleControlsHide()
        }
    }

    override fun onDestroy() {
        progressHandler.removeCallbacksAndMessages(null)
        if (::player.isInitialized) player.stopPlayback()
        galleryBitmap?.recycle()
        galleryBitmap = null
        super.onDestroy()
    }
}
