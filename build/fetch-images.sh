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

BRANCH="aosp-main"
TARGET="aosp_cf_arm64_phone-trunk_staging-userdebug"
BUILD_ID=""
PUSH=0
LIST_ONLY=0

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/images-download"
WORK="$OUT/.work"
WANTED=(kernel ramdisk.img system.img vendor.img)
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
target = sys.argv[1]
data = json.load(sys.stdin)
hits = []
def walk(node):
    if isinstance(node, dict):
        t = str(node.get("target", ""))
        b = node.get("buildId") or node.get("build_id")
        if b and target in t:
            hits.append((t, str(b)))
        for v in node.values():
            walk(v)
    elif isinstance(node, list):
        for v in node:
            walk(v)
walk(data)
seen, out = set(), []
for t, b in hits:
    if b not in seen:
        seen.add(b); out.append(b)
print("\n".join(out[:1]))
' "$TARGET"
}

if [ -z "$BUILD_ID" ]; then
  log "解析 ${BRANCH} / ${TARGET} 最新构建…"
  BUILD_ID=$(resolve_latest)
  [ -n "$BUILD_ID" ] || die "自动解析失败, 请用 --build <BuildID>"
fi
log "构建: $TARGET @ $BUILD_ID"
BASE="${PAGE_URL}/${BUILD_ID}/linux/android/${TARGET}"

# ---------------------------------------------------------------------
# 2. 列出 artifact
# ---------------------------------------------------------------------
list_artifacts() {
  curl -fsSL --retry 3 "${BASE}/" 2>/dev/null \
    | grep -oE '/raw/[A-Za-z0-9._+%-]+' \
    | sed 's#^/raw/##' | sort -u
}

if [ "$LIST_ONLY" = 1 ]; then
  log "artifact 列表:"
  list_artifacts || die "无法读取构建详情页, 请用浏览器打开 $BASE"
  exit 0
fi

# ---------------------------------------------------------------------
# 3. 下载单个文件 (带断点续传 + 重试 + 有效性检查)
# ---------------------------------------------------------------------
download() {
  local name="$1" dest="$OUT/$1" url
  if [ -s "$dest" ]; then
    log "$name 已存在 ($(du -h "$dest" | cut -f1)), 跳过"
    return 0
  fi
  url="${BASE}/raw/${name}"
  log "下载 $name ← ${url}"
  if curl -fL --retry 3 --retry-delay 2 -C - --progress-bar "$url" -o "$dest.part"; then
    mv -f "$dest.part" "$dest"
  else
    rm -f "$dest.part"; return 1
  fi
  # 空文件/HTML 错误页视为失败
  [ -s "$dest" ] || { rm -f "$dest"; return 1; }
  if head -c 16 "$dest" | grep -qi '<!DOCTYPE'; then
    warn "$name 返回的是 HTML 错误页"; rm -f "$dest"; return 1
  fi
  return 0
}

FAILED=()
for f in "${WANTED[@]}"; do
  download "$f" || FAILED+=("$f")
done

# ---------------------------------------------------------------------
# 4. 回退: 新版构建把磁盘镜像打成一个 zip, 从里面抽取
# ---------------------------------------------------------------------
if [ ${#FAILED[@]} -gt 0 ]; then
  warn "以下文件直链不可用: ${FAILED[*]}"
  ZIP_NAME=$(list_artifacts | grep -E 'img.*\.zip$' | head -n 1 || true)
  if [ -n "$ZIP_NAME" ]; then
    log "回退方案: 下载并解包 ${ZIP_NAME}"
    ZFILE="$WORK/$ZIP_NAME"
    curl -fL --retry 3 -C - --progress-bar "${BASE}/raw/${ZIP_NAME}" -o "$ZFILE" || die "zip 下载失败"
    ( cd "$WORK" && unzip -o -q "$ZFILE" )
    for f in system.img vendor.img ramdisk.img; do
      if [ -f "$WORK/$f" ] && [ ! -s "$OUT/$f" ]; then
        mv -f "$WORK/$f" "$OUT/$f"; log "从 zip 提取 $f"
      fi
    done
    # 新版 Cuttlefish 常只有 boot.img (kernel+ramdisk 合并)
    if [ ! -s "$OUT/kernel" ]; then
      if [ -s "$WORK/kernel" ]; then
        mv -f "$WORK/kernel" "$OUT/kernel"; log "从 zip 提取 kernel"
      elif [ -s "$WORK/boot.img" ]; then
        warn "只找到 boot.img, 需要拆包拿 arm64 Image:"
        warn "  pip install unpack_bootimg && unpack_bootimg --boot_img $WORK/boot.img --out $WORK/boot"
        warn "  再把 \$WORK/boot/kernel 改名为 $OUT/kernel"
      fi
    fi
    if [ ! -s "$OUT/ramdisk.img" ] && [ -s "$WORK/boot.img" ]; then
      warn "ramdisk.img 需从 boot.img 拆出 (同上 unpack_bootimg, 取 ramdisk 段)"
    fi
  else
    warn "未找到 img zip, 请用 --list 核对 artifact 名称"
  fi
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
