package com.meld.installer

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.UsedByGodot
import java.io.File

class MeldInstaller(godot: Godot) : GodotPlugin(godot) {

    override fun getPluginName(): String = "MeldInstaller"

    @UsedByGodot
    fun canRequestPackageInstalls(): Boolean {
        val act = activity ?: return false
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            act.packageManager.canRequestPackageInstalls()
    }

    @UsedByGodot
    fun openUnknownSourcesSettings() {
        val act = activity ?: return
        val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
            data = Uri.parse("package:${act.packageName}")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        act.startActivity(intent)
    }

    @UsedByGodot
    fun installApk(absolutePath: String): Boolean {
        val act = activity ?: return false
        val apk = File(absolutePath)
        if (!apk.exists()) return false

        val uri = FileProvider.getUriForFile(
            act,
            "${act.packageName}.meld.installer",
            apk
        )

        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        act.startActivity(intent)
        return true
    }
}