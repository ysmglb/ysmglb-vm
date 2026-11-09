package com.a23.vmm

import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import java.io.File
import java.io.RandomAccessFile

/**
 * guest 镜像管理: 存放目录 / 完整性检查 / SAF 导入 (按文件名自动归类)
 */
object ImageManager {
    val REQUIRED = listOf("kernel", "ramdisk.img", "system.img", "vendor.img")

    fun imagesDir(ctx: Context): File =
        File(ctx.getExternalFilesDir(null) ?: ctx.filesDir, "images")

    fun ensureDir(ctx: Context): File = imagesDir(ctx).apply { mkdirs() }

    fun vmConfig(ctx: Context): VmConfig =
        VmConfig(dataDir = imagesDir(ctx).parentFile ?: File(ctx.filesDir, "vmm"))

    data class ImageStatus(val name: String, val exists: Boolean, val sizeMb: Long)

    fun status(ctx: Context): List<ImageStatus> {
        val dir = ensureDir(ctx)
        return REQUIRED.map { n ->
            val f = File(dir, n)
            ImageStatus(n, f.exists() && f.length() > 0, f.length() / (1024 * 1024))
        }
    }

    fun allPresent(ctx: Context): Boolean = status(ctx).all { it.exists }

    /** SAF 导入: 文件名含 system/vendor/ramdisk/kernel/Image 关键词即自动归类 */
    fun import(ctx: Context, uris: List<Uri>): List<String> {
        val logs = mutableListOf<String>()
        val dir = ensureDir(ctx)
        for (uri in uris) {
            val display = displayName(ctx, uri) ?: uri.lastPathSegment ?: continue
            val target = when {
                display.contains("system", true) -> "system.img"
                display.contains("vendor", true) -> "vendor.img"
                display.contains("ramdisk", true) -> "ramdisk.img"
                display.contains("kernel", true) || display == "Image" || display.endsWith("Image", true) -> "kernel"
                display.equals("data.img", true) -> "data.img"
                else -> null
            }
            if (target == null) {
                logs.add("跳过无法识别的文件: $display")
                continue
            }
            try {
                ctx.contentResolver.openInputStream(uri)?.use { input ->
                    File(dir, target).outputStream().use { input.copyTo(it) }
                }
                logs.add("已导入 $display → images/$target")
            } catch (e: Exception) {
                logs.add("导入失败 $display: ${e.message}")
            }
        }
        return logs
    }

    private fun displayName(ctx: Context, uri: Uri): String? =
        ctx.contentResolver.query(uri, null, null, null, null)?.use { c ->
            val idx = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (idx >= 0 && c.moveToFirst()) c.getString(idx) else null
        }
}
