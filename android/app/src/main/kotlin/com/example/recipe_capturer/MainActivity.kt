package com.example.recipe_capturer

import android.content.Intent
import android.net.Uri
import android.webkit.MimeTypeMap
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
  private data class SharePayload(
    val imagePaths: List<String> = emptyList(),
    val sharedText: String? = null,
  ) {
    fun hasContent(): Boolean = imagePaths.isNotEmpty() || !sharedText.isNullOrBlank()

    fun toMap(): Map<String, Any?> {
      return mapOf(
        "imagePaths" to imagePaths,
        "sharedText" to sharedText,
      )
    }
  }

  private var pendingShareIntent: Intent? = null
  private var eventSink: EventChannel.EventSink? = null

  override fun onCreate(savedInstanceState: android.os.Bundle?) {
    super.onCreate(savedInstanceState)
    pendingShareIntent = intent
  }

  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    setIntent(intent)

    val sink = eventSink
    if (sink != null) {
      processShareIntentAsync(intent) { payload ->
        if (!payload.hasContent()) return@processShareIntentAsync
        runOnUiThread {
          sink.success(payload.toMap())
        }
      }
    } else {
      pendingShareIntent = intent
    }
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(
      flutterEngine.dartExecutor.binaryMessenger,
      "recipe_capturer/share_intent_method",
    ).setMethodCallHandler { call, result ->
      when (call.method) {
        "consumeInitialSharePayload" -> {
          val initialIntent = pendingShareIntent
          pendingShareIntent = null

          if (initialIntent == null) {
            result.success(SharePayload().toMap())
            return@setMethodCallHandler
          }

          processShareIntentAsync(initialIntent) { payload ->
            runOnUiThread {
              result.success(payload.toMap())
            }
          }
        }

        "consumeInitialSharedImages" -> {
          // Backward-compatible fallback for older Dart side callers.
          val initialIntent = pendingShareIntent
          pendingShareIntent = null

          if (initialIntent == null) {
            result.success(emptyList<String>())
            return@setMethodCallHandler
          }

          processShareIntentAsync(initialIntent) { payload ->
            runOnUiThread {
              result.success(payload.imagePaths)
            }
          }
        }

        else -> result.notImplemented()
      }
    }

    EventChannel(
      flutterEngine.dartExecutor.binaryMessenger,
      "recipe_capturer/share_intent_events",
    ).setStreamHandler(
      object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
          eventSink = events
        }

        override fun onCancel(arguments: Any?) {
          eventSink = null
        }
      },
    )
  }

  private fun processShareIntentAsync(intent: Intent?, onDone: (SharePayload) -> Unit) {
    Thread {
      val payload = extractSharePayload(intent)
      onDone(payload)
    }.start()
  }

  private fun extractSharePayload(intent: Intent?): SharePayload {
    if (intent == null) return SharePayload()

    val uris = mutableListOf<Uri>()
    when (intent.action) {
      Intent.ACTION_SEND -> {
        val uri = readSingleUri(intent)
        if (uri != null) uris.add(uri)
      }

      Intent.ACTION_SEND_MULTIPLE -> {
        uris.addAll(readMultipleUris(intent))
      }

      else -> return SharePayload()
    }

    val copied = mutableListOf<String>()
    for (uri in uris) {
      val copiedPath = copyUriToCache(uri)
      if (copiedPath != null) copied.add(copiedPath)
    }

    val sharedText = readSharedText(intent)
    return SharePayload(imagePaths = copied, sharedText = sharedText)
  }

  @Suppress("DEPRECATION")
  private fun readSingleUri(intent: Intent): Uri? {
    return intent.getParcelableExtra(Intent.EXTRA_STREAM)
  }

  @Suppress("DEPRECATION")
  private fun readMultipleUris(intent: Intent): List<Uri> {
    val result = mutableListOf<Uri>()

    val extraUris = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
    if (extraUris != null) {
      result.addAll(extraUris)
    }

    val clipData = intent.clipData
    if (clipData != null) {
      for (i in 0 until clipData.itemCount) {
        val uri = clipData.getItemAt(i).uri
        if (uri != null) result.add(uri)
      }
    }

    return result.distinct()
  }

  private fun readSharedText(intent: Intent): String? {
    val raw = intent.getStringExtra(Intent.EXTRA_TEXT) ?: intent.getStringExtra(Intent.EXTRA_SUBJECT)
    val normalized = raw?.trim()
    if (normalized.isNullOrEmpty()) return null
    return normalized
  }

  private fun copyUriToCache(uri: Uri): String? {
    return try {
      val input = contentResolver.openInputStream(uri) ?: return null

      val extension = extensionForUri(uri)
      val sharedDir = File(cacheDir, "shared_images")
      if (!sharedDir.exists()) {
        sharedDir.mkdirs()
      }

      val outFile = File(
        sharedDir,
        "share_${System.currentTimeMillis()}_${System.nanoTime()}.$extension",
      )

      input.use { inStream ->
        outFile.outputStream().use { outStream ->
          inStream.copyTo(outStream)
        }
      }

      outFile.absolutePath
    } catch (_: Exception) {
      null
    }
  }

  private fun extensionForUri(uri: Uri): String {
    val mimeType = contentResolver.getType(uri) ?: return "jpg"
    val fromMime = MimeTypeMap.getSingleton().getExtensionFromMimeType(mimeType)
    return fromMime ?: "jpg"
  }
}
