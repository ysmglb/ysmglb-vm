package com.a23.vmm

import android.graphics.Bitmap
import android.graphics.Canvas
import android.util.Log
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.DataInputStream
import java.io.DataOutputStream
import java.net.Socket
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.concurrent.thread

/**
 * 极简 RFB 3.8 VNC 客户端, 专为 QEMU 内置 VNC (127.0.0.1) 定制:
 *   安全类型 None + RGB565 little-endian + Raw 编码。
 * 无第三方依赖, 一个类完成握手/帧更新/输入注入。
 *
 * TODO(v2): Tight/Hextile 编码提升帧率, VNC DH 认证, 剪贴板同步。
 */
class VncClient(private val listener: Listener) {

    interface Listener {
        fun onConnected(name: String, width: Int, height: Int)
        fun onFrame(bitmap: Bitmap)
        fun onError(message: String)
        fun onClosed()
    }

    val lock = Any()

    @Volatile var fbWidth: Int = 0
        private set
    @Volatile var fbHeight: Int = 0
        private set

    @Volatile private var running = false
    private var socket: Socket? = null
    @Volatile private var dout: DataOutputStream? = null
    private var bitmap: Bitmap? = null

    fun connect(host: String, port: Int) {
        running = true
        thread(name = "vnc-client") { run(host, port) }
    }

    fun close() {
        running = false
        try { socket?.close() } catch (_: Exception) {}
    }

    private fun run(host: String, port: Int) {
        try {
            val s = Socket(host, port).also { socket = it; it.tcpNoDelay = true }
            val inp = DataInputStream(BufferedInputStream(s.getInputStream(), 1 shl 16))
            val out = DataOutputStream(BufferedOutputStream(s.getOutputStream()))
            dout = out

            // ---- 1. 版本握手 ----
            val serverVer = ByteArray(12)
            inp.readFully(serverVer)
            out.write("RFB 003.008\n".toByteArray())
            out.flush()

            // ---- 2. 安全类型 (骨架版只支持 None) ----
            val n = inp.readUnsignedByte()
            check(n > 0) { readSecurityError(inp) }
            val types = ByteArray(n)
            inp.readFully(types)
            check(types.contains(1.toByte())) {
                "QEMU VNC 启用了认证, 骨架版未实现 DH (不要对 -vnc 设置密码)"
            }
            out.writeByte(1)
            out.flush()
            val result = inp.readInt()
            check(result == 0) { "安全协商被拒绝 result=$result" }

            // ---- 3. ClientInit: 共享模式 ----
            out.writeByte(1)
            out.flush()

            // ---- 4. ServerInit ----
            fbWidth = inp.readUnsignedShort()
            fbHeight = inp.readUnsignedShort()
            inp.readFully(ByteArray(16)) // 服务器默认像素格式, 随后用 SetPixelFormat 覆盖
            val nameLen = inp.readInt()
            val name = ByteArray(nameLen)
            inp.readFully(name)
            listener.onConnected(String(name, Charsets.ISO_8859_1), fbWidth, fbHeight)

            // ---- 5. SetPixelFormat: RGB565 LE ----
            out.writeByte(0)
            out.write(ByteArray(3)) // padding
            out.writeByte(16)  // bitsPerPixel
            out.writeByte(16)  // depth
            out.writeByte(0)   // bigEndian = false
            out.writeByte(1)   // trueColor
            out.writeShort(31) // redMax
            out.writeShort(63) // greenMax
            out.writeShort(31) // blueMax
            out.write(ByteArray(3)) // padding
            out.writeByte(11)  // redShift
            out.writeByte(5)   // greenShift
            out.writeByte(0)   // blueShift
            out.flush()

            // ---- 6. SetEncodings: 仅 Raw ----
            out.writeByte(2)
            out.write(ByteArray(1)) // padding
            out.writeShort(1)       // 编码个数
            out.writeInt(0)         // 0 = Raw
            out.flush()

            requestUpdate(incremental = false)

            var buf = ByteBuffer.allocateDirect(fbWidth * fbHeight * 2)
                .order(ByteOrder.LITTLE_ENDIAN)
            while (running) {
                when (inp.readUnsignedByte()) {
                    0 -> { // FramebufferUpdate
                        inp.readUnsignedByte() // padding
                        val rects = inp.readUnsignedShort()
                        repeat(rects) {
                            val x = inp.readUnsignedShort()
                            val y = inp.readUnsignedShort()
                            val w = inp.readUnsignedShort()
                            val h = inp.readUnsignedShort()
                            val encoding = inp.readInt()
                            check(encoding == 0) { "收到未请求的编码 $encoding" }
                            val need = w * h * 2
                            if (buf.capacity() < need) {
                                buf = ByteBuffer.allocateDirect(need).order(ByteOrder.LITTLE_ENDIAN)
                            }
                            val arr = ByteArray(need)
                            inp.readFully(arr)
                            val patch = Bitmap.createBitmap(w, h, Bitmap.Config.RGB_565)
                            buf.clear()
                            buf.put(arr)
                            buf.position(0)
                            patch.copyPixelsFromBuffer(buf)
                            synchronized(lock) {
                                val master = bitmap
                                    ?: Bitmap.createBitmap(fbWidth, fbHeight, Bitmap.Config.RGB_565)
                                        .also { bitmap = it }
                                Canvas(master).drawBitmap(patch, x.toFloat(), y.toFloat(), null)
                            }
                            patch.recycle()
                            listener.onFrame(bitmap!!)
                        }
                        requestUpdate(incremental = true)
                    }
                    1 -> { // SetColourMapEntries (仅 trueColor 下不会出现, 保险跳过)
                        inp.readUnsignedByte()
                        inp.readUnsignedShort()
                        val count = inp.readUnsignedShort()
                        inp.readFully(ByteArray(count * 6))
                    }
                    2 -> Unit // Bell
                    3 -> { // ServerCutText
                        val len = inp.readInt()
                        inp.readFully(ByteArray(len))
                    }
                    else -> throw IllegalStateException("未知 RFB 消息类型")
                }
            }
        } catch (e: Exception) {
            if (running) {
                Log.e(TAG_VNC, "VNC 会话异常", e)
                listener.onError(e.message ?: e.toString())
            }
        } finally {
            close()
            listener.onClosed()
        }
    }

    private fun readSecurityError(inp: DataInputStream): String {
        val len = inp.readInt()
        val b = ByteArray(len)
        inp.readFully(b)
        return "安全协商失败: " + String(b, Charsets.ISO_8859_1)
    }

    private fun requestUpdate(incremental: Boolean) {
        val out = dout ?: return
        synchronized(lock) {
            out.writeByte(3) // FramebufferUpdateRequest
            out.writeByte(if (incremental) 1 else 0)
            out.writeShort(0)
            out.writeShort(0)
            out.writeShort(fbWidth)
            out.writeShort(fbHeight)
            out.flush()
        }
    }

    /** 触控注入: mask bit0 = 左键 */
    fun pointerEvent(x: Int, y: Int, pressed: Boolean) {
        val out = dout ?: return
        synchronized(lock) {
            out.writeByte(5)
            out.writeByte(if (pressed) 1 else 0)
            out.writeShort(x)
            out.writeShort(y)
            out.flush()
        }
    }

    /** 键盘注入: keysym 编码 (X11 keysymdef), 如 Esc=0xFF1B Home=0xFFBE */
    fun keyEvent(keysym: Int, down: Boolean) {
        val out = dout ?: return
        synchronized(lock) {
            out.writeByte(4)
            out.writeByte(if (down) 1 else 0)
            out.writeShort(0)
            out.writeInt(keysym)
            out.flush()
        }
    }

    companion object {
        private const val TAG_VNC = "VNC"
    }
}
