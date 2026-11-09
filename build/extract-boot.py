#!/usr/bin/env python3
"""从 Android boot.img 拆出 kernel + ramdisk。

AOSP 的 unpack_bootimg 不在 PyPI 上, 而 boot.img 的头部格式很简单,
这里自己解析即可 (支持 header v0-v4)。

用法: python3 extract-boot.py <boot.img> <输出目录>
"""
import os
import struct
import sys


def main():
    src, outdir = sys.argv[1], sys.argv[2]
    with open(src, "rb") as f:
        data = f.read()
    if data[:8] != b"ANDROID!":
        sys.exit("不是 Android boot.img (magic 不匹配)")

    kernel_size, ramdisk_size = struct.unpack_from("<II", data, 8)
    page_size = struct.unpack_from("<I", data, 36)[0] or 4096
    header_version = struct.unpack_from("<I", data, 40)[0]

    if header_version >= 3:
        # v3/v4: 头部固定 4096 字节, 数据紧接其后按 4096 对齐
        kernel_off = 4096
        ramdisk_off = kernel_off + ((kernel_size + 4095) // 4096) * 4096
    else:
        kernel_off = page_size
        ramdisk_off = kernel_off + ((kernel_size + page_size - 1) // page_size) * page_size

    os.makedirs(outdir, exist_ok=True)
    with open(os.path.join(outdir, "kernel"), "wb") as f:
        f.write(data[kernel_off:kernel_off + kernel_size])
    with open(os.path.join(outdir, "ramdisk"), "wb") as f:
        f.write(data[ramdisk_off:ramdisk_off + ramdisk_size])

    print(f"kernel={kernel_size} ramdisk={ramdisk_size} header_version={header_version}")


main()
