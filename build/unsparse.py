#!/usr/bin/env python3
"""把 Android sparse 镜像转成 raw。

QEMU 只认 raw, 而 ci.android.com 产出的 super.img 是 sparse (magic 0xED26FF3A)。
转换后 raw 是 8.6G, 但稀疏文件实际只占 ~1.7G (Windows 上会先打 sparse 标记)。

用法: python3 unsparse.py <sparse.img> <raw.img>
"""
import os
import struct
import sys

RAW, FILL, DONT_CARE, CRC32 = 0xCAC1, 0xCAC2, 0xCAC3, 0xCAC4
BUF = 8 << 20


def mark_sparse(path):
    """Windows/NTFS: 标记稀疏, 未写入区间不占物理空间。其他平台为空操作。"""
    if sys.platform != "win32":
        return
    import ctypes

    k = ctypes.windll.kernel32
    h = k.CreateFileW(path, 0xC0000000, 0, None, 3, 0x80, None)
    done = ctypes.c_ulong(0)
    k.DeviceIoControl(h, 0x900C4, None, 0, None, 0, ctypes.byref(done), None)  # FSCTL_SET_SPARSE
    k.CloseHandle(h)


def main():
    src, dst = sys.argv[1], sys.argv[2]
    if os.path.exists(dst):
        os.remove(dst)
    open(dst, "wb").close()
    mark_sparse(dst)

    f = open(src, "rb")
    magic, major, minor, fh, ch, blk, total_blks, total_chunks, _ = struct.unpack("<IHHHHIIII", f.read(28))
    if magic != 0xED26FF3A:
        sys.exit("不是 Android sparse 镜像 (magic 不匹配)")
    f.seek(fh)
    out = open(dst, "r+b")
    pos = 0
    for i in range(total_chunks):
        ctype, _, chunk_blocks, _ = struct.unpack("<HHII", f.read(ch))
        n = chunk_blocks * blk
        if ctype == RAW:
            left = n
            while left > 0:
                buf = f.read(min(left, BUF))
                if not buf:
                    sys.exit("sparse 数据提前结束")
                out.seek(pos)
                out.write(buf)
                pos += len(buf)
                left -= len(buf)
        elif ctype == FILL:
            pattern = f.read(4) * (BUF // 4)
            out.seek(pos)
            left = n
            while left > 0:
                k = min(left, BUF)
                out.write(pattern[:k])
                pos += k
                left -= k
        elif ctype == DONT_CARE:
            pos += n          # 留空洞, 不写
        elif ctype == CRC32:
            f.read(4)
        else:
            sys.exit(f"未知 chunk 类型 {ctype:#x} (第 {i} 个)")
    out.truncate(pos)
    out.close()
    f.close()
    print(f"raw={pos} bytes ({pos / 1e9:.2f} GB)")


main()
