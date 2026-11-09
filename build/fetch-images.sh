#!/usr/bin/env bash
# =====================================================================
# fetch-images.sh — 下载 AOSP Cuttlefish arm64 guest 镜像
#
# 数据来源: ci.android.com (Apache 2.0, 可合法打包分发)
#
# 用法:
#   ./fetch-images.sh                          # 自动解析 aosp-main 最新构建
#   ./fetch-images.sh --build 12345678         # 指定 Build ID
#   ./fetch-images.sh --list                   # 只列出该构建的 artifact
#   ./fetch-images.sh --build 12345678 --push  # 下载后 adb push 到手机
#
# 常用参数:
#   --branch <名>   默认 aosp-main
#   --target <名>   默认 aosp_cf_arm64_phone-trunk_staging-userdebug
#   --out    <目录> 默认 <工程根>/images-download
#
# 产物: kernel / ramdisk.img / system.img / vendor.img
#       (与 app/src/main/java/com/a23/vmm/VmConfig.kt 的启动参数一一对应)
# =====================================================================
set -euo pipefail

BRANCH="aosp-android-latest-release"
TARGET="aosp_cf_arm64_only_phone-userdebug"
BUILD_ID=""
PUSH=0
LIST_ONLY=0

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/images-download"
WORK="$OUT/.work"
# 新版 Cuttlefish 构建把系统镜像打成 img-<build>.zip, kernel/ramdisk 在 boot.zip 里
WANTED=(kernel ramdisk.img system.img vendor.img product.img)
PKG_NAME="com.a23.vmm"

log()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --build)  BUILD_ID="${2:?--build 需要 Build ID}"; shift 2 ;;
    --branch) BRANCH="${2:?}"; shift 2 ;;
    --target) TARGET="${2:?}"; shift 2 ;;
    --out)    OUT="${2:?}"; shift 2 ;;
    --push)   PUSH=1; shift ;;
    --list)   LIST_ONLY=1; shift ;;
    -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
    *) die "未知参数: $1 (试试 --help)" ;;
  esac
done

mkdir -p "$OUT" "$WORK"
PAGE_URL="https://ci.android.com/builds/submitted"

# ---------------------------------------------------------------------
# 1. 解析最新 Build ID
#    ci.android.com 的 branch status.json 是唯一的公开入口,
#    结构可能变动, 因此用 python 做宽松的递归搜索; 失败则提示手动指定。
# ---------------------------------------------------------------------
resolve_latest() {
  command -v python3 >/dev/null || die "需要 python3 解析构建列表, 或直接用 --build <ID>"
  local json
  json=$(curl -fsSL --retry 3 "https://ci.android.com/builds/branches/${BRANCH}/status.json") \
    || die "无法获取 ${BRANCH} 构建列表, 请到 https://ci.android.com 手动复制 Build ID"

  printf '%s' "$json" | python3 -c '
import json, sys
want = sys.argv[1]
data = json.load(sys.stdin)
for t in data.get("targets") or []:
    if t.get("name") == want:
        print(t.get("last_known_good_build") or "")
        break
' "$TARGET"
}

if [ -z "$BUILD_ID" ]; then
  log "解析 ${BRANCH} / ${TARGET} 最新构建…"
  BUILD_ID=$(resolve_latest)
  [ -n "$BUILD_ID" ] || die "自动解析失败, 请用 --build <BuildID>"
fi
log "构建: $TARGET @ $BUILD_ID"
BASE="https://ci.android.com/builds/submitted/${BUILD_ID}/${TARGET}/latest/raw"

# ---------------------------------------------------------------------
# 2. artifact 名称
#    新版详情页是纯 JS 渲染的 SPA, 拿不到文件列表, 但命名规则固定:
#      <target 去掉 -userdebug>-img-<build>.zip  ← system/vendor/product 等
#      boot.zip                                  ← boot.img (kernel+ramdisk)
# ---------------------------------------------------------------------
IMG_ZIP="${TARGET%-userdebug}-img-${BUILD_ID}.zip"
BOOT_ZIP="boot.zip"

if [ "$LIST_ONLY" = 1 ]; then
  log "该构建的镜像包:"
  echo "  $IMG_ZIP"
  echo "  $BOOT_ZIP"
  echo "  下载前缀: $BASE/"
  exit 0
fi

# ---------------------------------------------------------------------
# 3. 下载 (带断点续传 + 重试 + 有效性检查)
#    ci.android.com 会 307 跳到 storage.googleapis.com, 该域名在部分网络不可达;
#    storage-download.googleapis.com 是官方等价端点, 签名不覆盖 host, 换域名仍有效。
# ---------------------------------------------------------------------
real_url() {
  local name="$1" loc
  loc=$(curl -s -o /dev/null -D - -r 0-0 "$BASE/$name" | tr -d '\r' | sed -n 's/^[Ll]ocation: *//p')
  if [ -n "$loc" ]; then
    printf '%s' "${loc/storage.googleapis.com/storage-download.googleapis.com}"
  else
    printf '%s' "$BASE/$name"
  fi
}

fetch() {
  local name="$1" dest="$OUT/$1" url
  if [ -s "$dest" ]; then
    log "$name 已存在 ($(du -h "$dest" | cut -f1)), 跳过"
    return 0
  fi
  url=$(real_url "$name")
  log "下载 $name"
  if curl -fL --retry 5 --retry-delay 3 -C - --progress-bar "$url" -o "$dest.part"; then
    mv -f "$dest.part" "$dest"
  else
    rm -f "$dest.part"; return 1
  fi
  [ -s "$dest" ] || { rm -f "$dest"; return 1; }
  if head -c 16 "$dest" | grep -qi '<!DOCTYPE'; then
    warn "$name 返回的是 HTML 错误页"; rm -f "$dest"; return 1
  fi
  return 0
}

fetch "$IMG_ZIP" || die "系统镜像包 ${IMG_ZIP} 下载失败"
fetch "$BOOT_ZIP" || die "boot.zip 下载失败"

# ---------------------------------------------------------------------
# 4. 解包
# ---------------------------------------------------------------------
log "解包 $IMG_ZIP"
unzip -o -q "$OUT/$IMG_ZIP" -d "$OUT" || die "解包 ${IMG_ZIP} 失败"

log "解包 $BOOT_ZIP"
unzip -o -q "$OUT/$BOOT_ZIP" -d "$WORK" || die "解包 boot.zip 失败"
[ -s "$OUT/boot.img" ] || { [ -s "$WORK/boot.img" ] && mv -f "$WORK/boot.img" "$OUT/boot.img"; }

# QEMU 用 -kernel/-initrd 直接引导, 需要把 boot.img 拆成 kernel + ramdisk
if [ ! -s "$OUT/kernel" ] && [ -s "$OUT/boot.img" ]; then
  log "拆解 boot.img"
  python3 "$(dirname "$0")/extract-boot.py" "$OUT/boot.img" "$WORK/boot" \
    && { mv -f "$WORK/boot/kernel" "$OUT/kernel"; mv -f "$WORK/boot/ramdisk" "$OUT/ramdisk.img"; \
         log "得到 kernel / ramdisk.img"; } \
    || warn "boot.img 拆解失败, 见上方错误"
fi

# ---------------------------------------------------------------------
# 5. 结果汇总
# ---------------------------------------------------------------------
echo
log "结果目录: $OUT"
MISSING=0
for f in "${WANTED[@]}"; do
  if [ -s "$OUT/$f" ]; then
    printf '  %-12s %8s\n' "$f" "$(du -h "$OUT/$f" | cut -f1)"
  else
    printf '  %-12s %8s\n' "$f" "缺失"; MISSING=$((MISSING+1))
  fi
done
echo
[ "$MISSING" -eq 0 ] || die "$MISSING 个必需文件缺失, 见上方提示"

# ---------------------------------------------------------------------
# 6. 可选: 推送到手机
# ---------------------------------------------------------------------
if [ "$PUSH" = 1 ]; then
  command -v adb >/dev/null || die "未找到 adb"
  adb get-state >/dev/null 2>&1 || die "没有已连接且调试授权的设备"
  DEST="/storage/emulated/0/Android/data/${PKG_NAME}/files/images"
  log "推送 → $DEST"
  adb shell mkdir -p "$DEST"
  for f in "${WANTED[@]}"; do adb push "$OUT/$f" "$DEST/" ; done
  adb shell ls -lh "$DEST"
else
  echo "手动推送命令:"
  echo "  adb shell mkdir -p /storage/emulated/0/Android/data/${PKG_NAME}/files/images"
  echo "  adb push $OUT/{kernel,ramdisk.img,system.img,vendor.img} \\"
  echo "      /storage/emulated/0/Android/data/${PKG_NAME}/files/images/"
fi
