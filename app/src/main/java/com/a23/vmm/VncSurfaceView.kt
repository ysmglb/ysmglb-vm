package com.a23.vmm

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Bitmap
import android.graphics.Rect
import android.view.MotionEvent
import android.view.SurfaceHolder
import android.view.SurfaceView

/**
 * VNC 画面视图: SurfaceView 渲染 + 触摸坐标缩放注入。
 * 与 QEMU guest 分辨率无关, 自动等比居中缩放。
 */
class VncSurfaceView(context: Context) : SurfaceView(context), SurfaceHolder.Callback, VncClient.Listener {

    private val client = VncClient(this)
    private val paint = Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG)
    private val dst = Rect()

    @Volatile private var connected = false
    var statusListener: ((String) -> Unit)? = null

    init {
        holder.addCallback(this)
    }

    fun connect(host: String, port: Int) {
        statusListener?.invoke("连接 VNC $host:$port …")
        client.connect(host, port)
    }

    fun disconnect() = client.close()

    override fun surfaceCreated(holder: SurfaceHolder) = Unit

    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
        layoutDst(width, height)
    }

    override fun surfaceDestroyed(holder: SurfaceHolder) {
        connected = false
        disconnect()
    }

    private fun layoutDst(w: Int, h: Int) {
        if (client.fbWidth <= 0 || w <= 0 || h <= 0) return
        val scale = minOf(w.toFloat() / client.fbWidth, h.toFloat() / client.fbHeight)
        val dw = (client.fbWidth * scale).toInt().coerceAtLeast(1)
        val dh = (client.fbHeight * scale).toInt().coerceAtLeast(1)
        dst.set((w - dw) / 2, (h - dh) / 2, (w - dw) / 2 + dw, (h - dh) / 2 + dh)
    }

    override fun onConnected(name: String, width: Int, height: Int) {
        connected = true
        statusListener?.invoke("已连接: $name (${width}x${height})")
        post { layoutDst(this@VncSurfaceView.width, this@VncSurfaceView.height) }
    }

    override fun onFrame(bitmap: Bitmap) {
        post {
            if (!connected) return@post
            val surface = holder.surface ?: return@post
            if (!surface.isValid) return@post
            try {
                val c = holder.lockCanvas() ?: return@post
                try {
                    synchronized(client.lock) {
                        c.drawColor(Color.BLACK)
                        c.drawBitmap(bitmap, null, dst, paint)
                    }
                } finally {
                    holder.unlockCanvasAndPost(c)
                }
            } catch (_: Exception) {
                // surface 销毁竞态, 忽略
            }
        }
    }

    override fun onError(message: String) {
        statusListener?.invoke("VNC 错误: $message")
    }

    override fun onClosed() {
        statusListener?.invoke("VNC 已断开")
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (!connected || client.fbWidth == 0 || dst.isEmpty) return true
        val fx = ((event.x - dst.left) * client.fbWidth / dst.width()).toInt()
            .coerceIn(0, client.fbWidth - 1)
        val fy = ((event.y - dst.top) * client.fbHeight / dst.height()).toInt()
            .coerceIn(0, client.fbHeight - 1)
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN,
            MotionEvent.ACTION_POINTER_DOWN -> client.pointerEvent(fx, fy, true)
            MotionEvent.ACTION_MOVE -> client.pointerEvent(fx, fy, true)
            MotionEvent.ACTION_UP,
            MotionEvent.ACTION_POINTER_UP,
            MotionEvent.ACTION_CANCEL -> client.pointerEvent(fx, fy, false)
        }
        return true
    }
}
