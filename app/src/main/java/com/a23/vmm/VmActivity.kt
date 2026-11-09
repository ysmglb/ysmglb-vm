package com.a23.vmm

import android.os.Bundle
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat

class VmActivity : AppCompatActivity() {

    private var vnc: VncSurfaceView? = null
    private lateinit var hint: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_vm)
        hint = findViewById(R.id.hint)
        immersive()
        window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun onResume() {
        super.onResume()
        // 兜底: 服务没拉起来时直接启动引擎 (镜像缺失时 VmEngine 会给出日志)
        if (!VmEngine.isRunning()) {
            VmEngine.start(this, ImageManager.vmConfig(this))
        }
        attachVnc()
    }

    override fun onPause() {
        vnc?.let {
            it.disconnect()
            (findViewById<FrameLayout>(R.id.container)).removeView(it)
        }
        vnc = null
        super.onPause()
    }

    override fun onBackPressed() {
        // 不直接退出画面: 回到主界面, VM 保留在后台 Service
        moveTaskToBack(true)
    }

    private fun attachVnc() {
        if (vnc != null) return
        val view = VncSurfaceView(this)
        view.layoutParams = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
        )
        view.statusListener = { msg -> runOnUiThread { hint.text = msg } }
        (findViewById<FrameLayout>(R.id.container)).addView(view)
        vnc = view
        view.connect("127.0.0.1", VmEngine.currentConfig()?.vncPort ?: 5900)
    }

    private fun immersive() {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        val controller = WindowInsetsControllerCompat(window, findViewById(android.R.id.content))
        controller.hide(WindowInsetsCompat.Type.systemBars())
        controller.systemBarsBehavior =
            WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
    }
}
