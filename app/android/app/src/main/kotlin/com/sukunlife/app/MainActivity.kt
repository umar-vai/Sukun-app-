package com.sukunlife.app

import android.Manifest
import android.app.DownloadManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.security.MessageDigest
import java.util.Locale

/**
 * One explicit user action queues the approved signed APK through Android's
 * DownloadManager. On completion, its size, SHA-256, package identity and
 * monotonically increasing version are verified BEFORE opening the system
 * installer. This app does not silently install anything.
 */
class MainActivity : FlutterActivity() {
    private val updateChannel = "sukunlife/app_updates"
    private val apkMime = "application/vnd.android.package-archive"
    private val prefs by lazy {
        getSharedPreferences("sukun_android_updates", Context.MODE_PRIVATE)
    }
    private val downloads by lazy {
        getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, updateChannel)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "installedVersionCode" ->
                            result.success(installedCode().toInt())
                        "enqueueVerifiedApk" -> result.success(enqueue(call))
                        "downloadStatus" -> getStatus(call, result)
                        "openInstaller" -> openInstaller(call, result)
                        else -> result.notImplemented()
                    }
                } catch (_: Exception) {
                    result.error("UPDATE_UNAVAILABLE", "Unable to prepare the verified APK.", null)
                }
            }
    }

    @Suppress("DEPRECATION")
    private fun installedCode(): Long {
        val info = packageManager.getPackageInfo(packageName, 0)
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            info.versionCode.toLong()
        }
    }

    private fun allowedUrl(value: String): Boolean {
        val uri = Uri.parse(value)
        if (uri.scheme != "https" || uri.userInfo != null ||
            uri.port != -1 || uri.fragment != null || uri.query != null ||
            !uri.path.orEmpty().lowercase(Locale.US).endsWith(".apk")) return false

        val path = uri.pathSegments
        return when (uri.host) {
            "github.com" -> path.size == 6 &&
                path[0] == "umar-vai" && path[1] == "Sukun-app-" &&
                path[2] == "releases" && path[3] == "download" &&
                path[4].isNotEmpty() && path[5].isNotEmpty()
            "downloads.sukunlife.com" -> path.size >= 2 &&
                path[0] == "android" && path.none { it == ".." }
            else -> false
        }
    }

    private fun enqueue(call: MethodCall): Long {
        val url = call.argument<String>("url") ?: error("Missing URL")
        val sha = call.argument<String>("sha256")?.lowercase(Locale.US)
            ?: error("Missing digest")
        val version = call.argument<Int>("versionCode") ?: error("Missing version")
        val expectedSize = call.argument<Number>("sizeBytes")?.toLong() ?: 0L
        require(allowedUrl(url) &&
            sha.matches(Regex("[a-f0-9]{64}")) &&
            version.toLong() > installedCode() &&
            expectedSize in (1024 * 1024)..(512L * 1024 * 1024))

        val filename = "sukun-life-${version}-${sha.take(12)}.apk"
        val directory = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
            ?: error("Download folder unavailable")
        val apk = File(directory, filename)
        if (apk.exists() && !apk.delete()) error("Cannot replace prior download")

        val request = DownloadManager.Request(Uri.parse(url))
            .setTitle("Sukun Life · ${version}")
            .setDescription("অফিসিয়াল অ্যাপ আপডেট ডাউনলোড হচ্ছে")
            .setMimeType(apkMime)
            .setNotificationVisibility(
                DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED
            )
            .setDestinationInExternalFilesDir(
                this, Environment.DIRECTORY_DOWNLOADS, filename
            )
        val downloadId = downloads.enqueue(request)
        prefs.edit()
            .putLong("download_id", downloadId)
            .putString("file_name", filename)
            .putString("sha256", sha)
            .putLong("expected_bytes", expectedSize)
            .putInt("version_code", version)
            .apply()
        return downloadId
    }

    private fun savedFile(id: Long): File {
        require(id > 0 && prefs.getLong("download_id", -1L) == id)
        val name = prefs.getString("file_name", null)
            ?: error("No active release download")
        require(Regex("sukun-life-[0-9]+-[0-9a-f]{12}\\.apk").matches(name))
        val directory = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
            ?: error("No download directory")
        val file = File(directory, name)
        require(file.canonicalFile.parentFile == directory.canonicalFile)
        return file
    }

    private fun downloadState(id: Long): Map<String, Any> {
        downloads.query(DownloadManager.Query().setFilterById(id))?.use { cursor ->
            if (!cursor.moveToFirst()) return mapOf("state" to "failed")
            val state = cursor.getInt(
                cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS)
            )
            val received = cursor.getLong(cursor.getColumnIndexOrThrow(
                DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR
            ))
            val total = cursor.getLong(cursor.getColumnIndexOrThrow(
                DownloadManager.COLUMN_TOTAL_SIZE_BYTES
            ))
            val phase = when (state) {
                DownloadManager.STATUS_SUCCESSFUL -> "downloaded"
                DownloadManager.STATUS_FAILED -> "failed"
                DownloadManager.STATUS_PENDING -> "pending"
                DownloadManager.STATUS_PAUSED -> "paused"
                else -> "downloading"
            }
            return mapOf("state" to phase, "received" to received, "total" to total)
        }
        return mapOf("state" to "failed")
    }

    private fun verifiedFile(id: Long): File? {
        if (downloadState(id)["state"] != "downloaded") return null
        val file = savedFile(id)
        val size = prefs.getLong("expected_bytes", 0L)
        if (!file.isFile || file.length() != size) return null
        val expectedSha = prefs.getString("sha256", null) ?: return null
        val digest = MessageDigest.getInstance("SHA-256")
        FileInputStream(file).use { input ->
            val buffer = ByteArray(65536)
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                digest.update(buffer, 0, read)
            }
        }
        val alphabet = "0123456789abcdef"
        val actual = buildString {
            digest.digest().forEach { item ->
                val byte = item.toInt() and 255
                append(alphabet[byte ushr 4])
                append(alphabet[byte and 15])
            }
        }
        if (actual != expectedSha) return null
        @Suppress("DEPRECATION")
        val archive = packageManager.getPackageArchiveInfo(file.absolutePath, 0)
            ?: return null
        val version = prefs.getInt("version_code", -1)
        @Suppress("DEPRECATION")
        val archiveVersion = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            archive.longVersionCode
        } else {
            archive.versionCode.toLong()
        }
        if (archive.packageName != packageName ||
            archiveVersion != version.toLong() ||
            archiveVersion <= installedCode()) return null
        return file
    }

    private fun getStatus(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<Number>("id")?.toLong() ?: -1L
        savedFile(id)
        val status = downloadState(id)
        if (status["state"] != "downloaded") {
            result.success(status)
            return
        }
        Thread {
            val valid = runCatching { verifiedFile(id) != null }.getOrDefault(false)
            runOnUiThread {
                result.success(mapOf(
                    "state" to if (valid) "ready" else "integrity_failed",
                    "received" to (status["received"] ?: 0L),
                    "total" to (status["total"] ?: -1L)
                ))
            }
        }.start()
    }

    private fun openInstaller(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<Number>("id")?.toLong() ?: -1L
        savedFile(id)
        Thread {
            val verified = runCatching { verifiedFile(id) }.getOrNull()
            runOnUiThread {
                if (verified == null) {
                    result.error("INVALID_APK", "APK verification failed.", null)
                    return@runOnUiThread
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                    !packageManager.canRequestPackageInstalls()) {
                    startActivity(Intent(
                        Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                        Uri.parse("package:$packageName")
                    ))
                    result.success("permission_required")
                    return@runOnUiThread
                }
                try {
                    val uri = FileProvider.getUriForFile(
                        this,
                        "$packageName.apkprovider",
                        verified
                    )
                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, apkMime)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    startActivity(intent)
                    result.success("installer_opened")
                } catch (_: Exception) {
                    result.error("INSTALLER_UNAVAILABLE",
                        "Android installer is unavailable.", null)
                }
            }
        }.start()
    }
}
