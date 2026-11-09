#!/data/data/com.termux/files/usr/bin/bash
# =====================================================================
# Termux 快速可行性验证 (可选): 不装 APK, 直接在手机上跑同一套 QEMU 命令
# 用途: 先确认 guest 镜像/启动参数能引导成功, 再回头调 APK 里的 VmConfig
#
# 前置: 从 F-Droid 安装 Termux; 下载镜像到 ~/vmm-images (见 fetch-images.sh)
# 验证: 另装一个 VNC 客户端 (如 AVNC) 连 127.0.0.1:5900 观看画面
# =====================================================================
set -e

pkg install -y qemu-system-aarch64 qemu-utils

IMG="$HOME/vmm-images"
for f in kernel ramdisk.img system.img vendor.img; do
  [ -s "$IMG/$f" ] || { echo "缺少 $IMG/$f"; exit 1; }
done

# data.img 4GB 稀疏文件
[ -f "$IMG/data.img" ] || qemu-img create -f raw "$IMG/data.img" 4G

exec qemu-system-aarch64 \
  -M virt,gic-version=3 -cpu cortex-a76 -smp 4 -m 3072 \
  -kernel "$IMG/kernel" \
  -initrd "$IMG/ramdisk.img" \
  -append "console=ttyAMA0 earlycon=pl011,0x9000000 androidboot.hardware=cutf_cvm androidboot.selinux=permissive" \
  -drive if=none,id=sys,file="$IMG/system.img",format=raw,readonly=on \
  -device virtio-blk-device,drive=sys \
  -drive if=none,id=vdr,file="$IMG/vendor.img",format=raw,readonly=on \
  -device virtio-blk-device,drive=vdr \
  -drive if=none,id=data,file="$IMG/data.img",format=raw \
  -device virtio-blk-device,drive=data \
  -device virtio-rng-pci \
  -netdev user,id=n0 -device virtio-net-device,netdev=n0 \
  -vnc 127.0.0.1:0 \
  -monitor telnet:127.0.0.1:4444,server,nowait \
  -no-reboot
