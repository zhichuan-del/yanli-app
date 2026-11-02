package org.yanli.yanli_app

import android.Manifest
import android.app.Activity
import android.net.Uri
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction
import java.nio.charset.StandardCharsets
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val permissionRequestCode = 28110
    private val exportRequestCode = 28111
    private val importRequestCode = 28112
    private val maxDocumentBytes = 20 * 1024 * 1024
    private val fileExecutor = Executors.newSingleThreadExecutor()
    private var pendingFileResult: MethodChannel.Result? = null
    private var exportContent: ByteArray? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pending: MethodChannel.Result? = null
    private var recognizer: SpeechRecognizer? = null
    private var timeout: Runnable? = null
    private var session = 0
    private var permissionRequestPending = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        configureFiles(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "org.yanli/voice")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> startRecognition(result)
                    "stop" -> {
                        if (recognizer != null) {
                            try {
                                recognizer?.stopListening()
                                scheduleTimeout(15_000)
                                result.success(null)
                            } catch (_: Exception) {
                                finishError("recognition_failed", "停止语音识别失败，请使用键盘输入。")
                                result.success(null)
                            }
                        } else {
                            result.success(null)
                        }
                    }
                    "cancel" -> {
                        finishError("cancelled", "已取消语音输入。")
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun configureFiles(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "org.yanli/files")
            .setMethodCallHandler { call, result ->
                if (call.method != "export" && call.method != "import") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (pendingFileResult != null) {
                    result.error("busy", "请先完成当前文件操作。", null)
                    return@setMethodCallHandler
                }
                val intent: Intent
                val requestCode: Int
                if (call.method == "export") {
                    val filename = call.argument<String>("filename")
                    val mime = call.argument<String>("mime")
                    val content = call.argument<String>("content")
                    if (filename.isNullOrBlank() || mime.isNullOrBlank() || content == null) {
                        result.error("invalid_args", "文件名称、类型或内容无效。", null)
                        return@setMethodCallHandler
                    }
                    val bytes = content.toByteArray(StandardCharsets.UTF_8)
                    if (bytes.size > maxDocumentBytes) {
                        result.error("too_large", "文件内容超过 20 MB，无法导出。", null)
                        return@setMethodCallHandler
                    }
                    exportContent = bytes
                    intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = mime
                        putExtra(Intent.EXTRA_TITLE, filename)
                    }
                    requestCode = exportRequestCode
                } else {
                    intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "*/*"
                        putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/json", "text/plain", "application/octet-stream"))
                    }
                    requestCode = importRequestCode
                }
                pendingFileResult = result
                try {
                    @Suppress("DEPRECATION")
                    startActivityForResult(intent, requestCode)
                } catch (_: Exception) {
                    completeFileError(result, "picker_unavailable", "无法打开系统文件选择器。")
                }
            }
    }

    @Deprecated("Android activity result compatibility for the system document picker")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != exportRequestCode && requestCode != importRequestCode) return
        val result = pendingFileResult ?: return
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            completeFileSuccess(result, null)
            return
        }
        val bytes = exportContent
        fileExecutor.execute {
            try {
                if (requestCode == exportRequestCode) {
                    if (bytes == null) throw IllegalStateException("Missing export content")
                    writeDocument(uri, bytes)
                    mainHandler.post { completeFileSuccess(result, true) }
                } else {
                    val text = readDocument(uri)
                    mainHandler.post { completeFileSuccess(result, text) }
                }
            } catch (_: DocumentTooLargeException) {
                mainHandler.post { completeFileError(result, "too_large", "文件超过 20 MB，请选择较小的备份文件。") }
            } catch (_: Exception) {
                mainHandler.post { completeFileError(result, "io_error", "文件读取或写入失败，请检查文件后重试。") }
            }
        }
    }

    private class DocumentTooLargeException : Exception()

    private fun readDocument(uri: Uri): String {
        val bytes = ByteArrayOutputStream()
        val stream = contentResolver.openInputStream(uri) ?: throw IllegalStateException("Cannot open document")
        stream.use { input ->
            val buffer = ByteArray(8192)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                if (bytes.size() + count > maxDocumentBytes) throw DocumentTooLargeException()
                bytes.write(buffer, 0, count)
            }
        }
        return StandardCharsets.UTF_8.newDecoder()
            .onMalformedInput(CodingErrorAction.REPORT)
            .onUnmappableCharacter(CodingErrorAction.REPORT)
            .decode(ByteBuffer.wrap(bytes.toByteArray())).toString()
    }

    private fun writeDocument(uri: Uri, bytes: ByteArray) {
        val stream = contentResolver.openOutputStream(uri, "wt") ?: throw IllegalStateException("Cannot open document")
        stream.use { it.write(bytes) }
    }

    private fun completeFileSuccess(result: MethodChannel.Result, value: Any?) {
        if (pendingFileResult !== result) return
        pendingFileResult = null
        exportContent = null
        result.success(value)
    }

    private fun completeFileError(result: MethodChannel.Result, code: String, message: String) {
        if (pendingFileResult !== result) return
        pendingFileResult = null
        exportContent = null
        result.error(code, message, null)
    }

    private fun startRecognition(result: MethodChannel.Result) {
        if (pending != null || permissionRequestPending) {
            result.error("busy", "语音输入正在进行，请先结束当前输入。", null)
            return
        }
        // The on-device recognizer is available starting with Android 12. Never
        // fall back to createSpeechRecognizer, which may transmit audio online.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            !SpeechRecognizer.isOnDeviceRecognitionAvailable(this)
        ) {
            result.error("unavailable", "此设备暂不支持离线语音识别，请使用键盘输入。", null)
            return
        }
        pending = result
        session++
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            permissionRequestPending = true
            requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), permissionRequestCode)
        } else {
            beginListening()
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != permissionRequestCode) return
        permissionRequestPending = false
        if (pending == null) return
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            beginListening()
        } else {
            finishError("permission_denied", "未获得麦克风权限，请授权后重试或使用键盘输入。")
        }
    }

    private fun beginListening() {
        if (pending == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        val currentSession = session
        try {
            val current = SpeechRecognizer.createOnDeviceSpeechRecognizer(this)
            recognizer = current
            current.setRecognitionListener(object : RecognitionListener {
                private fun active() = currentSession == session && pending != null
                override fun onReadyForSpeech(params: Bundle?) {}
                override fun onBeginningOfSpeech() {}
                override fun onRmsChanged(rmsdB: Float) {}
                override fun onBufferReceived(buffer: ByteArray?) {}
                override fun onEndOfSpeech() {}
                override fun onPartialResults(partialResults: Bundle?) {}
                override fun onEvent(eventType: Int, params: Bundle?) {}
                override fun onError(error: Int) {
                    if (!active()) return
                    val message = when (error) {
                        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "没有麦克风权限，请检查系统设置或使用键盘输入。"
                        SpeechRecognizer.ERROR_NO_MATCH, SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "没有识别到语音，请重试或使用键盘输入。"
                        SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED, SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE -> "设备上的离线中文语音包不可用，请使用键盘输入。"
                        else -> "离线语音识别失败，请检查设备的离线语音功能或使用键盘输入。"
                    }
                    finishError("recognition_failed", message)
                }
                override fun onResults(results: Bundle?) {
                    if (!active()) return
                    val text = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()?.trim()
                    if (text.isNullOrEmpty()) {
                        finishError("no_match", "没有识别到语音，请重试或使用键盘输入。")
                    } else {
                        finishSuccess(text)
                    }
                }
            })
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.SIMPLIFIED_CHINESE.toLanguageTag())
                putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
            }
            current.startListening(intent)
            scheduleTimeout(60_000)
        } catch (_: Exception) {
            finishError("unavailable", "设备端离线语音识别不可用，请使用键盘输入。")
        }
    }

    private fun scheduleTimeout(milliseconds: Long) {
        timeout?.let { mainHandler.removeCallbacks(it) }
        timeout = Runnable { finishError("timeout", "语音识别超时，请重试或使用键盘输入。") }
        mainHandler.postDelayed(timeout!!, milliseconds)
    }

    private fun releaseRecognizer() {
        session++
        timeout?.let { mainHandler.removeCallbacks(it) }
        timeout = null
        recognizer?.let {
            try { it.cancel() } catch (_: Exception) {}
            it.destroy()
        }
        recognizer = null
    }

    private fun finishSuccess(text: String) {
        val result = pending ?: return
        pending = null
        releaseRecognizer()
        result.success(text)
    }

    private fun finishError(code: String, message: String) {
        val result = pending ?: return
        pending = null
        releaseRecognizer()
        result.error(code, message, null)
    }

    override fun onStop() {
        // Do not keep listening when the app is backgrounded.
        if (recognizer != null) finishError("interrupted", "语音输入已中断，请重试或使用键盘输入。")
        super.onStop()
    }

    override fun onDestroy() {
        pendingFileResult?.let { completeFileError(it, "interrupted", "文件操作被中断，请重试。") }
        fileExecutor.shutdown()
        finishError("interrupted", "语音输入已中断，请重试或使用键盘输入。")
        super.onDestroy()
    }
}
