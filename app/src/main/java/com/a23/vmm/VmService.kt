package com.a23.vmm

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.IBinder
import kotlin.concurrent.thread

/**
 * 前台服务: 拉起并保活 QEMU 子进程。
 * LMK 对前台服务宽容得多, 但仍建议用户关闭本应用的电池优化。
 */
class VmService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createChannel()
        startForeground(NOTIF_ID, buildNotification())
        if (!VmEngine.isRunning()) {
            val cfg = ImageManager.vmConfig(this)
            VmEngine.start(this, cfg)
            // 启动失败 (缺 libqemu.so / 缺镜像) 时自动退出前台态
            thread(isDaemon = true) {
                Thread.sleep(5000)
                if (!VmEngine.isRunning()) stopSelf()
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        VmEngine.stop()
        super.onDestroy()
    }

    private fun createChannel() {
        val ch = NotificationChannel(
            CHANNEL_ID,
            getString(R.string.vm_channel),
            NotificationManager.IMPORTANCE_LOW,
        )
        getSystemService(NotificationManager::class.java).createNotificationChannel(ch)
    }

    private fun buildNotification(): Notification =
        Notification.Builder(this, CHANNEL_ID)
            .setContentTitle(getString(R.string.vm_notification_title))
            .setContentText(getString(R.string.vm_notification_text))
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setOngoing(true)
            .build()

    companion object {
        private const val CHANNEL_ID = "vm"
        private const val NOTIF_ID = 1
    }
}
