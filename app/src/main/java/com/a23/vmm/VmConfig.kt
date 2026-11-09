package com.a23.vmm

import java.io.File
import java.io.RandomAccessFile

/**
 * QEMU 启动参数。
 *
 * 镜像来源: AOSP Cuttlefish arm64 (Apache 2.0, 可合法分发)
 *   kernel / ramdisk.img / system.img / vendor.img 放在 <dataDir>/images/
 *   data.img 首次启动时自动创建为稀疏文件, 由 guest 端 vold 格式化
 */
data class VmConfig(
    val dataDir: File,
    val ramMb: Int = 3072,
    val cpus: Int = 4,
    /** true = virtio-gpu-gl-pci (virgl GL 加速, 需 QEMU 编译时 --enable-virglrenderer); false = 无加速回退 */
    val glAccelerated: Boolean = false,
    /** VNC 显示号, 0 → 端口 5900 */
    val vncDisplay: Int = 0,
    val monitorPort: Int = 4444,
) {
    val imagesDir: File get() = File(dataDir, "images")
    val dataImg: File get() = File(imagesDir, "data.img")
    val vncPort: Int get() = 5900 + vncDisplay

    fun buildArgs(): List<String> {
        val img = imagesDir
        // data.img: 4GB 稀疏文件, 物理占用≈0
        if (!dataImg.exists()) {
            RandomAccessFile(dataImg, "rw").use { it.setLength(4L * 1024 * 1024 * 1024) }
        }
        val gpuDevice = if (glAccelerated) "virtio-gpu-gl-pci" else "virtio-gpu-device"
        // TODO(启动参数调优): Cuttlefish 对 androidboot.* 要求随版本变化,
        //  首次跑通后再按 /proc/cmdline 与内核日志逐步修正, 必要时补 data分区 fstab
        return listOf(
            "-M", "virt,gic-version=3",
            "-cpu", "cortex-a76",
            "-smp", cpus.toString(),
            "-m", ramMb.toString(),
            "-kernel", File(img, "kernel").absolutePath,
            "-initrd", File(img, "ramdisk.img").absolutePath,
            "-append",
            "console=ttyAMA0 earlycon=pl011,0x9000000 " +
                "androidboot.hardware=cutf_cvm " +
                "androidboot.selinux=permissive " +
                "androidboot.serialno=vmm0001",
            "-drive", "if=none,id=sys,file=${File(img, "system.img").absolutePath},format=raw,readonly=on",
            "-device", "virtio-blk-device,drive=sys",
            "-drive", "if=none,id=vdr,file=${File(img, "vendor.img").absolutePath},format=raw,readonly=on",
            "-device", "virtio-blk-device,drive=vdr",
            "-drive", "if=none,id=data,file=${dataImg.absolutePath},format=raw",
            "-device", "virtio-blk-device,drive=data",
            "-device", gpuDevice,
            "-device", "virtio-rng-pci",
            "-netdev", "user,id=n0",
            "-device", "virtio-net-device,netdev=n0",
            "-vnc", "127.0.0.1:$vncDisplay",
            "-monitor", "telnet:127.0.0.1:$monitorPort,server,nowait",
            "-no-reboot",
        )
    }
}
