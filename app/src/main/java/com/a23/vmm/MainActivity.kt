package com.a23.vmm

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.widget.Button
import android.widget.TextView
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat

class MainActivity : AppCompatActivity() {

    private lateinit var status: TextView

    private val pickImages =
        registerForActivityResult(ActivityResultContracts.OpenMultipleDocuments()) { uris ->
            if (uris.isNotEmpty()) {
                refresh("导入结果:\n" + ImageManager.import(this, uris).joinToString("\n"))
            }
        }

    private val requestNotif =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { refresh(null) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        status = findViewById(R.id.status_text)

        findViewById<Button>(R.id.btn_import).setOnClickListener {
            pickImages.launch(arrayOf("*/*"))
        }
        findViewById<Button>(R.id.btn_start).setOnClickListener {
            if (!ImageManager.allPresent(this)) {
                refresh("缺少镜像文件, 请先点击「导入镜像」\n需要: ${ImageManager.REQUIRED.joinToString()}")
                return@setOnClickListener
            }
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED
            ) {
                requestNotif.launch(Manifest.permission.POST_NOTIFICATIONS)
            }
            ContextCompat.startForegroundService(this, Intent(this, VmService::class.java))
            startActivity(Intent(this, VmActivity::class.java))
        }
        findViewById<Button>(R.id.btn_stop).setOnClickListener {
            VmEngine.currentConfig()?.let { VmEngine.sendMonitorCommand(it, "quit") }
            VmEngine.stop()
            refresh("已请求停止虚拟机")
        }

        refresh(null)
    }

    override fun onResume() {
        super.onResume()
        refresh(null)
    }

    private fun refresh(prefix: String?) {
        val lines = ImageManager.status(this).joinToString("\n") { s ->
            String.format(
                "%-12s %s %8d MB",
                s.name,
                if (s.exists) "OK  " else "缺失",
                s.sizeMb,
            )
        }
        val vmState = when {
            VmEngine.isRunning() -> "运行中"
            else -> "未运行"
        }
        status.text = (prefix?.plus("\n\n") ?: "") +
            "虚拟机: $vmState\n" +
            "镜像目录: ${ImageManager.imagesDir(this).path}\n\n" +
            lines + "\n\n" +
            "启动前请确认 jniLibs/arm64-v8a/libqemu.so 已就位\n" +
            "(build/build-qemu.sh 产物)"
    }
}
