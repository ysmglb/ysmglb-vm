#!/bin/bash
# =====================================================================
# 交叉编译 QEMU 9.1 (aarch64-softmmu, TCG 指令翻译) → libqemu.so
# 在 Linux 或 WSL 中执行 (先跑 build-deps.sh)。
#
# 产物说明:
#   qemu-system-aarch64 是 PIE 可执行文件 (Android 禁止 dlopen 可执行文件),
#   重命名为 libqemu.so 放进 jniLibs/arm64-v8a, APK 开启 useLegacyPackaging
#   解压安装后保留执行位, 由 App 通过 ProcessBuilder exec 启动。
# =====================================================================
set -euo pipefail

API=26
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
WORK="$BUILD/_work"
PREFIX="$BUILD/_prefix"
NDK=${NDK:-/opt/android-ndk-r26d}
TC="$NDK/toolchains/llvm/prebuilt/linux-x86_64"

export PATH="$TC/bin:$PATH"
export PKG_CONFIG_SYSROOT_DIR="$TC/sysroot"
export PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig"

QEMU_VER=${QEMU_VER:-9.1.0}

# ---- 1. 源码 (发布 tarball 已内嵌 dtc/meson 等 submodule) ----
mkdir -p "$WORK"
cd "$WORK"
if [ ! -d "qemu-$QEMU_VER" ]; then
  echo "== 下载 QEMU $QEMU_VER 源码 =="
  curl -fL "https://download.qemu.org/qemu-$QEMU_VER.tar.xz" | tar xJ
fi
cd "qemu-$QEMU_VER"

# ---- 2. configure ----
# 关闭所有可选依赖, 只保留: vnc 显示 / slirp 网络 / virglrenderer GPU
./configure \
  --target-list=aarch64-softmmu \
  --cross-prefix=aarch64-linux-android26- \
  --host-cc=clang \
  --enable-pie \
  --enable-vnc \
  --enable-slirp \
  --enable-virglrenderer \
  --enable-opengl \
  --enable-fdt=internal \
  --disable-sdl --disable-gtk --disable-curses \
  --disable-docs --disable-tests --disable-tools --disable-guest-agent \
  --disable-zstd --disable-lzo --disable-snappy --disable-bzip2 --disable-lzfse \
  --disable-gnutls --disable-nettle --disable-gcrypt \
  --disable-seccomp --disable-numa --disable-libusb --disable-libiscsi \
  --disable-libnfs --disable-libssh --disable-rbd --disable-glusterfs \
  --disable-libxml2 --disable-attr --disable-containers \
  --audio-drv-list= \
  --extra-cflags="-I$PREFIX/include" \
  --extra-ldflags="-L$PREFIX/lib -llog" \
  --host=bionic 2>/dev/null || true
# 注: 若 configure 对 bionic 探测报错, 删掉上面最后一行 --host 并按报错逐项 disable

# ---- 3. 编译 ----
make -j"$(nproc)" qemu-system-aarch64

# ---- 4. 打包进工程 ----
OUT="$ROOT/app/src/main/jniLibs/arm64-v8a"
mkdir -p "$OUT"
cp -f qemu-system-aarch64 "$OUT/libqemu.so"
"$TC/bin/llvm-strip" "$OUT/libqemu.so" 2>/dev/null || true
echo
echo "完成 → $OUT/libqemu.so"
ls -lh "$OUT/libqemu.so"
echo "下一步: 在 Android Studio 里直接 assembleDebug, libqemu.so 会打进 APK"
