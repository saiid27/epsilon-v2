package com.epsilon.academy.said

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val filePickerRequestCode = 32042
    private var pendingFilePickerResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "epsilon/secure_window"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "enable" -> {
                    window.setFlags(
                        WindowManager.LayoutParams.FLAG_SECURE,
                        WindowManager.LayoutParams.FLAG_SECURE
                    )
                    result.success(null)
                }
                "disable" -> {
                    window.setFlags(
                        WindowManager.LayoutParams.FLAG_SECURE,
                        WindowManager.LayoutParams.FLAG_SECURE
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "epsilon/file_picker"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickFile" -> {
                    if (pendingFilePickerResult != null) {
                        result.error("busy", "يوجد اختيار ملف قيد التنفيذ.", null)
                        return@setMethodCallHandler
                    }

                    val type = call.argument<String>("type") ?: "image"
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        this.type = if (type == "excel") "*/*" else "image/*"
                        if (type == "excel") {
                            putExtra(
                                Intent.EXTRA_MIME_TYPES,
                                arrayOf(
                                    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                                    "application/vnd.ms-excel",
                                    "application/octet-stream"
                                )
                            )
                        }
                    }

                    pendingFilePickerResult = result
                    startActivityForResult(intent, filePickerRequestCode)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode != filePickerRequestCode) {
            return
        }

        val result = pendingFilePickerResult ?: return
        pendingFilePickerResult = null

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }

        try {
            val uri = data.data!!
            val name = displayName(uri) ?: "picked-file"
            val destination = File(cacheDir, "${System.currentTimeMillis()}-$name")
            contentResolver.openInputStream(uri).use { input ->
                if (input == null) {
                    throw IllegalStateException("Cannot open selected file.")
                }
                destination.outputStream().use { output ->
                    input.copyTo(output)
                }
            }
            result.success(mapOf("path" to destination.absolutePath, "name" to name))
        } catch (error: Exception) {
            result.error("pick_failed", error.localizedMessage, null)
        }
    }

    private fun displayName(uri: Uri): String? {
        return contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (nameIndex >= 0 && cursor.moveToFirst()) {
                cursor.getString(nameIndex)
            } else {
                null
            }
        }
    }
}
