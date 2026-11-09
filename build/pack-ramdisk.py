#!/usr/bin/env python3
"""往 Android ramdisk (legacy LZ4 + newc cpio) 里加/改文件。

Cuttlefish 的 fstab.cutf_cvm 平时由 bootloader 注入设备树, 我们 -kernel 直启没有
bootloader, 只能把它塞进 ramdisk 的 first_stage_ramdisk/ 下, init 的 GetFstabPath()
会按 androidboot.hardware 去找 /first_stage_ramdisk/fstab.<hardware>。

用法: python3 pack-ramdisk.py <in.img> <out.img> <要加入的文件>...
      文件按 basename 放到 ramdisk 根和 first_stage_ramdisk/ 下
"""
import os
import struct
import sys

import lz4.block

LEGACY_MAGIC = 0x184C2102
BLOCK = 8 << 20


def unlz4(data):
    off = 4
    out = []
    while off + 4 <= len(data):
        n = struct.unpack_from("<I", data, off)[0]
        off += 4
        if n == 0:
            break
        out.append(lz4.block.decompress(data[off:off + n], uncompressed_size=BLOCK))
        off += n
    return b"".join(out)


def lz4_legacy(data):
    out = bytearray(struct.pack("<I", LEGACY_MAGIC))
    for i in range(0, len(data), BLOCK):
        blk = data[i:i + BLOCK]
        comp = lz4.block.compress(blk, mode="high_compression", store_size=False)
        out += struct.pack("<I", len(comp)) + comp
    out += struct.pack("<I", 0)
    return bytes(out)


def parse_cpio(raw):
    entries = []
    off = 0
    while off + 110 <= len(raw) and raw[off:off + 6] in (b"070701", b"070702"):
        hdr = raw[off:off + 110]

        def f(i):
            return int(hdr[i:i + 8], 16)

        mode, filesize, namesize = f(14), f(54), f(94)
        name = raw[off + 110:off + 110 + namesize - 1].decode()
        data_off = (off + 110 + namesize + 3) & ~3
        entries.append([name, mode, raw[data_off:data_off + filesize]])
        off = (data_off + filesize + 3) & ~3
    return entries


def write_cpio(entries):
    out = bytearray()
    ino = 1
    for name, mode, data in entries:
        nb = name.encode() + b"\x00"
        hdr = b"070701" + b"".join(
            f"{v:08x}".encode() for v in (
                ino, mode, 0, 0, 1, 0, len(data), 0, 0, 0, 0, len(nb), 0))
        out += hdr + nb
        out += b"\x00" * ((-len(out)) % 4)
        out += data
        out += b"\x00" * ((-len(data)) % 4)
        ino += 1
    nb = b"TRAILER!!!\x00"
    hdr = b"070701" + b"".join(
        f"{v:08x}".encode() for v in (0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, len(nb), 0))
    out += hdr + nb
    out += b"\x00" * ((-len(out)) % 4)
    return bytes(out)


def main():
    src, dst = sys.argv[1], sys.argv[2]
    add = sys.argv[3:]
    raw = unlz4(open(src, "rb").read())
    entries = parse_cpio(raw)
    names = {e[0] for e in entries}

    def put(path, data):
        for e in entries:
            if e[0] == path:
                e[2] = data
                return
        entries.append([path, 0o100644, data])

    for path in add:
        data = open(path, "rb").read()
        base = os.path.basename(path)
        put(base, data)
        if not any(e[0] == "first_stage_ramdisk" for e in entries):
            entries.append(["first_stage_ramdisk", 0o040755, b""])
        put("first_stage_ramdisk/" + base, data)
        print(f"  + {base} ({len(data)}B) 和 first_stage_ramdisk/{base}")

    open(dst, "wb").write(lz4_legacy(write_cpio(entries)))
    print(f"{dst} = {os.path.getsize(dst)}B, 共 {len(entries)} 个条目")


main()
