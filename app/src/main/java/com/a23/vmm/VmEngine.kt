package com.a23.vmm

import android.content.Context
import android.util.Log
import java.io.File
import java.net.InetSocketAddress
import java.net.Socket
import java.util.concurrent.TimeUnit
import kotlin.concurrent.thread

/**
 * QEMU 进程管理器。
 *
 * 架构说明: QEMU 不以 JNI 方式内嵌, 而是作为独立可执行文件打包在
 * jniLibs/arm64-v8a/libqemu.so (可执行文件伪装成 so, useLegacyPackaging 解压后
 * 保留执行位), 由 ProcessBuilder 直接 exec —— 与 Limbo 一脉相承的做法,
 * 信号/崩溃隔离/日志捕获都更干净。
 */
object VmEngine {
    private const val TAG = "VMM"

    @Volatile private var process: Process? = null
    @Volatile private var config: VmConfig? = null

    fun isRunning(): Boolean = process?.isAlive == true

    fun currentConfig(): VmConfig? = config

    fun qemuBinary(context: Context): File =
        File(context.applicationInfo.nativeLibraryDir, "libqemu.so")

    @Synchronized
    fun start(context: Context, cfg: VmConfig, onLog: (String) -> Unit = {}): Boolean {
        if (isRunning()) {
            Log.w(TAG, "VM 已在运行, 忽略重复启动")
            return true
        }
        val bin = qemuBinary(context)
        if (!bin.exists()) {
            val msg = "缺少 $bin —— 请在 WSL/Linux 执行 build/build-qemu.sh 生成后放入 jniLibs/arm64-v8a/"
            Log.e(TAG, msg)
            onLog("ERROR: $msg")
            return false
        }
        val args = cfg.buildArgs()
        val pb = ProcessBuilder(listOf(bin.absolutePath) + args)
        pb.environment()["TMPDIR"] = context.cacheDir.absolutePath
        pb.environment()["HOME"] = cfg.dataDir.absolutePath
        pb.redirectErrorStream(true)
        return try {
            val p = pb.start()
            process = p
            config = cfg
            thread(name = "qemu-log", isDaemon = true) {
                p.inputStream.bufferedReader().forEachLine { line ->
                    Log.i("QEMU", line)
                    onLog(line)
                }
            }
            Log.i(TAG, "QEMU 已启动")
            onLog("QEMU 已启动")
            true
        } catch (e: Exception) {
            Log.e(TAG, "QEMU 启动失败", e)
            onLog("ERROR: 启动失败 ${e.message}")
            false
        }
    }

    @Synchronized
    fun stop() {
        process?.let { p ->
            p.destroy()
            try { p.waitFor(3, TimeUnit.SECONDS) } catch (_: InterruptedException) {}
            if (p.isAlive) p.destroyForcibly()
        }
        process = null
        config = null
    }

    /**
     * 通过 QEMU monitor (telnet) 发送命令, 如 quit / system_powerdown / info status
     */
    fun sendMonitorCommand(cfg: VmConfig, cmd: String): Boolean = try {
        Socket().use { s ->
            s.connect(InetSocketAddress("127.0.0.1", cfg.monitorPort), 2000)
            s.soTimeout = 3000
            val out = s.getOutputStream()
            out.write((cmd + "\n").toByteArray())
            out.flush()
            // 消费欢迎横幅与回显, 超时即认为已送达
            try { s.getInputStream().read(ByteArray(4096)) } catch (_: Exception) {}
        }
        true
    } catch (e: Exception) {
        Log.e(TAG, "monitor 命令失败: $cmd", e)
        false
    }
}
