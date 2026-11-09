#!/bin/bash
# =====================================================================
# 交叉编译 QEMU 的依赖库 (静态库) → build/_prefix
# 在 Linux 或 WSL 中执行。前置要求:
#   - Android NDK r26+  (环境变量 NDK, 默认 /opt/android-ndk-r26d)
#   - meson >= 1.2, ninja, pkg-config, git, curl
#   - python3
# 产物: build/_prefix/lib/*.a + pkgconfig
# =====================================================================
set -euo pipefail

# API 26 的 bionic 缺少 iconv_open(), glib 编译会失败 (Dependency "iconv" not found)
# 从 API 28 起 bionic 才完整提供 iconv; 28 对应 Android 9, 普及率足够
API=28
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
WORK="$BUILD/_work"
PREFIX="$BUILD/_prefix"
NDK=${NDK:-/opt/android-ndk-r26d}
TC="$NDK/toolchains/llvm/prebuilt/linux-x86_64"

export PATH="$TC/bin:$PATH"
export CC=aarch64-linux-android$API-clang
export CXX=aarch64-linux-android$API-clang++
# 不要设 PKG_CONFIG_SYSROOT_DIR: 我们的依赖库 install prefix 是构建机上的绝对路径,
# pkg-config 再叠一层 sysroot 前缀会变成 "...sysroot/home/runner/.../_prefix/include"
export PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig"

mkdir -p "$WORK" "$PREFIX"
cd "$WORK"

# ---- 0. 给 NDK 自带但无 pkg-config 文件的库补 .pc ----
# iconv: Android 的 iconv 在 libc 中, 但某些构建环境下需要 pkg-config 声明
mkdir -p "$PREFIX/lib/pkgconfig"
if [ ! -f "$PREFIX/lib/pkgconfig/iconv.pc" ]; then
  echo "== 生成 iconv.pc (API=$API) =="
  cat > "$PREFIX/lib/pkgconfig/iconv.pc" <<'EOF'
Name: iconv
Description: Android bionic iconv (in libc since API 28)
Version: 1
Libs:
Cflags:
EOF
fi

# ---- 0. libffi (glib 的 GObject 闭包依赖, autotools 项目) ----
if [ ! -f "$PREFIX/lib/pkgconfig/libffi.pc" ]; then
  echo "== libffi 3.4.6 =="
  curl -fL "https://github.com/libffi/libffi/releases/download/v3.4.6/libffi-3.4.6.tar.gz" | tar xz
  cd libffi-3.4.6
  ./configure --host=aarch64-linux-android$API --prefix="$PREFIX" \
      --disable-shared --enable-static
  make -j"$(nproc)" install
  cd ..
else
  echo "== libffi 已安装, 跳过 =="
fi

meson_dep() {  # meson_dep <name> <git-url> <tag> [extra meson flags...]
  local name=$1 url=$2 tag=$3; shift 3
  if [ -f "$PREFIX/lib/pkgconfig/$name.pc" ] || [ -f "$PREFIX/lib/pkgconfig/${name%-2.0}.pc" ]; then
    echo "== $name 已安装, 跳过 =="; return
  fi
  rm -rf "src-$name"
  git clone --depth 1 --branch "$tag" "$url" "src-$name"
  meson setup "build-$name" "src-$name" \
      --cross-file="$BUILD/cross/android-arm64.ini" \
      --prefix="$PREFIX" --default-library=static --buildtype=release \
      "$@"
  ninja -C "build-$name" install
}

# ---- 1. glib (QEMU 硬依赖) ----
# 注意: glib 对 android 交叉编译若报探测错误, 参考 Termux 的补丁集:
#   https://github.com/termux/termux-packages/tree/master/packages/glib
meson_dep glib-2.0 https://github.com/GNOME/glib.git 2.80.4 \
    -Dtests=false -Dlibmount=disabled -Dselinux=disabled -Dxattr=false \
    -Dglib_debug=disabled -Dglib_assert=false -Dman=false -Ddtrace=false \
    -Dsystemtap=false -Dsysprof=disabled -Dintrospection=disabled

# ---- 2. pixman ----
# 0.44.2 用 meson.options (非 meson_options.txt), tests/demos/libpng/gtk 都是 feature 类型
# 没有 libjpeg 选项, 之前的 -Dlibjpeg=disabled 直接让 meson setup 报错
meson_dep pixman-1 https://gitlab.freedesktop.org/pixman/pixman.git pixman-0.44.2 \
    -Dtests=disabled -Ddemos=disabled -Dlibpng=disabled -Dgtk=disabled

# ---- 3. libslirp (用户态网络 NAT, 无需 root) ----
meson_dep slirp https://gitlab.freedesktop.org/slirp/libslirp.git v4.8.0

# ---- 4. libdrm (virgl 依赖) ----
meson_dep libdrm https://gitlab.freedesktop.org/mesa/drm.git libdrm-2.4.123 \
    -Dtests=false -Damdgpu=disabled -Dnouveau=disabled -Dvmwgfx=disabled \
    -Dradeon=disabled -Dintel=disabled -Dfreedreno=disabled -Detnaviv=disabled

# ---- 5. libepoxy (virgl 依赖: guest GL 调用转发需要 EGL/GLES) ----
# 1.5.10 是老版本: tests/x11 仍是 boolean, egl/glx 是 combo(yes/no/auto)
meson_dep epoxy https://github.com/anholt/libepoxy.git 1.5.10 \
    -Degl=yes -Dglx=no -Dx11=false -Dtests=false

# ---- 6. virglrenderer (virtio-gpu-gl 的宿主侧渲染) ----
# 若上游 tag 的 meson 选项名有出入, 查看其 meson_options.txt;
# 备选方案: 直接用 AOSP 带过适配的仓库
#   https://android.googlesource.com/platform/external/virglrenderer
# 1.0.1 没有 gbm 选项, gbm 依赖由 minigbm_allocation 触发
meson_dep virglrenderer https://gitlab.freedesktop.org/virgl/virglrenderer.git virglrenderer-1.0.1 \
    -Dtests=false -Dminigbm_allocation=false -Dvenus=false -Dplatforms=egl

echo
echo "依赖库安装完成 → $PREFIX"
ls "$PREFIX/lib"
