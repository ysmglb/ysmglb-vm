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

# 与 build-deps.sh 保持一致: API 28 起 bionic 才完整提供 iconv
API=28
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
WORK="$BUILD/_work"
PREFIX="$BUILD/_prefix"
NDK=${NDK:-/opt/android-ndk-r26d}
TC="$NDK/toolchains/llvm/prebuilt/linux-x86_64"

export PATH="$TC/bin:$PATH"
# 不要设 PKG_CONFIG_SYSROOT_DIR (同 build-deps.sh 的原因)
export PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig"
# configure 会推导 pkg_config=${PKG_CONFIG-${cross_prefix}pkg-config},
# 不显式指定就会去找 aarch64-linux-android26-pkg-config (不存在)
export PKG_CONFIG=pkg-config

# configure 会用 ${CC-${cross_prefix}gcc} 推导交叉编译器, NDK 没有 *-gcc,
# 因此必须显式导出全部工具链, 否则报 "C compiler cannot create executables"
export CC="$TC/bin/aarch64-linux-android$API-clang"
export CXX="$TC/bin/aarch64-linux-android$API-clang++"
export AR="$TC/bin/llvm-ar"
export NM="$TC/bin/llvm-nm"
export STRIP="$TC/bin/llvm-strip"
export OBJCOPY="$TC/bin/llvm-objcopy"
export RANLIB="$TC/bin/llvm-ranlib"

QEMU_VER=${QEMU_VER:-9.1.0}

# ---- 0. zlib.pc (NDK 自带 zlib.h/libz.so, 但不提供 pkg-config 文件) ----
# QEMU 的 zlib 依赖是 required: true, 缺 .pc 会直接 configure 失败
if [ ! -f "$PREFIX/lib/pkgconfig/zlib.pc" ]; then
  cat > "$PREFIX/lib/pkgconfig/zlib.pc" <<'EOF'
Name: zlib
Description: Android NDK zlib
Version: 1.3.1
Libs: -lz
Cflags:
EOF
fi

# ---- 1. 源码 (发布 tarball 已内嵌 dtc/meson 等 submodule) ----
mkdir -p "$WORK"
cd "$WORK"
if [ ! -d "qemu-$QEMU_VER" ]; then
  echo "== 下载 QEMU $QEMU_VER 源码 =="
  curl -fL "https://download.qemu.org/qemu-$QEMU_VER.tar.xz" | tar xJ
fi
cd "qemu-$QEMU_VER"

# 清掉上一次失败留下的 meson 构建目录 (缓存的 _work 会带过来)
rm -rf build

# ---- 2. configure ----
# 关闭所有可选依赖, 只保留: vnc 显示 / slirp 网络 / virglrenderer GPU
# 注意: QEMU 9.x 已移除 --disable-tests / --disable-libxml2 / --disable-containers
#       / --audio-drv-list 等旧选项, 传了会直接 "unknown option" 退出
# virglrenderer 需要 gbm (Android NDK 没有), 编出来才启用 OpenGL
GL_FLAGS=()
if [ -f "$PREFIX/lib/pkgconfig/virglrenderer.pc" ]; then
  GL_FLAGS=(--enable-virglrenderer --enable-opengl)
  echo "== 启用 virtio-gpu-gl (virglrenderer) =="
else
  echo "== 未找到 virglrenderer.pc, 本次不带 OpenGL 加速 =="
fi

./configure \
  --target-list=aarch64-softmmu \
  --cross-prefix="aarch64-linux-android$API-" \
  --host-cc=clang \
  --enable-pie \
  --enable-vnc \
  --enable-slirp \
  "${GL_FLAGS[@]}" \
  --disable-sdl --disable-gtk --disable-curses \
  --disable-docs --disable-tools --disable-guest-agent \
  --disable-zstd --disable-lzo --disable-snappy --disable-bzip2 --disable-lzfse \
  --disable-gnutls --disable-nettle --disable-gcrypt \
  --disable-seccomp --disable-numa --disable-libusb --disable-libiscsi \
  --disable-libnfs --disable-libssh --disable-rbd --disable-glusterfs \
  --disable-attr \
  --extra-cflags="-I$PREFIX/include" \
  --extra-ldflags="-L$PREFIX/lib -llog" \
  || { echo "== configure 失败, meson 日志末尾 =="; tail -n 80 build/meson-logs/meson-log.txt 2>/dev/null; exit 1; }

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
