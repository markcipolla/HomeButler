#!/usr/bin/env python3
"""Patch armv7 Mach-O to set Thumb bit on all internal code pointers.

Modern linkers (ld 27000+) produce armv7 binaries where code pointers
in __DATA lack the Thumb bit (bit 0). iOS 9's old dyld and ObjC runtime
don't infer Thumb from N_ARM_THUMB_DEF, so functions get called in ARM
mode and hit SIGILL/SIGBUS. This sets bit 0 on:
  - LC_MAIN entryoff
  - All pointers in __DATA sections that reference __TEXT,__text
"""
import struct, sys

FAT_MAGIC = 0xCAFEBABE
FAT_MAGIC_64 = 0xCAFEBABF
MH_MAGIC = 0xFEEDFACE
LC_MAIN = 0x80000028
LC_SEGMENT = 0x1
CPU_TYPE_ARM = 12

def patch_macho(f, base):
    f.seek(base)
    magic = struct.unpack('<I', f.read(4))[0]
    if magic != MH_MAGIC:
        return False
    cputype = struct.unpack('<I', f.read(4))[0]
    if cputype != CPU_TYPE_ARM:
        return False
    f.read(4)  # cpusubtype
    f.read(4)  # filetype
    ncmds = struct.unpack('<I', f.read(4))[0]
    f.read(4 + 4)  # sizeofcmds + flags

    text_start = text_end = 0
    data_sections = []  # (file_offset, size)
    lc_main_offset = None
    patched = 0

    pos = f.tell()
    for _ in range(ncmds):
        f.seek(pos)
        cmd, cmdsize = struct.unpack('<II', f.read(8))

        if cmd == LC_MAIN:
            lc_main_offset = pos + 8
            entryoff = struct.unpack('<I', f.read(4))[0]
            if not (entryoff & 1):
                f.seek(pos + 8)
                f.write(struct.pack('<I', entryoff | 1))
                patched += 1

        elif cmd == LC_SEGMENT:
            segname = f.read(16).split(b'\x00')[0].decode()
            vmaddr, vmsize, fileoff, filesize = struct.unpack('<IIII', f.read(16))
            f.read(8)  # maxprot + initprot
            nsects = struct.unpack('<I', f.read(4))[0]
            f.read(4)  # flags

            for _ in range(nsects):
                sectname = f.read(16).split(b'\x00')[0].decode()
                seg = f.read(16).split(b'\x00')[0].decode()
                addr, size, offset = struct.unpack('<III', f.read(12))
                f.read(4 * 5)  # align, reloff, nreloc, flags, reserved1, reserved2
                f.read(4)

                if seg == '__TEXT' and sectname == '__text':
                    text_start = addr
                    text_end = addr + size

                if segname == '__DATA':
                    data_sections.append((offset + base, size))

        pos += cmdsize

    if not text_start or not data_sections:
        return patched > 0

    for sec_offset, sec_size in data_sections:
        for i in range(0, sec_size - 3, 4):
            f.seek(sec_offset + i)
            val = struct.unpack('<I', f.read(4))[0]
            if text_start <= val < text_end and not (val & 1):
                f.seek(sec_offset + i)
                f.write(struct.pack('<I', val | 1))
                patched += 1

    if patched:
        print(f'Patched {patched} code pointers')
    return patched > 0

def main():
    if len(sys.argv) != 2:
        print(f'Usage: {sys.argv[0]} <binary>', file=sys.stderr)
        sys.exit(1)

    path = sys.argv[1]
    with open(path, 'r+b') as f:
        magic = struct.unpack('>I', f.read(4))[0]

        if magic == FAT_MAGIC:
            f.seek(4)
            narch = struct.unpack('>I', f.read(4))[0]
            for _ in range(narch):
                cpu, sub, offset, size, align = struct.unpack('>IIIII', f.read(20))
                if cpu == CPU_TYPE_ARM:
                    here = f.tell()
                    patch_macho(f, offset)
                    f.seek(here)
        elif magic == FAT_MAGIC_64:
            f.seek(4)
            narch = struct.unpack('>I', f.read(4))[0]
            for _ in range(narch):
                cpu, sub = struct.unpack('>II', f.read(8))
                offset, size, align = struct.unpack('>QQQ', f.read(24))
                if cpu == CPU_TYPE_ARM:
                    here = f.tell()
                    patch_macho(f, offset)
                    f.seek(here)
        else:
            f.seek(0)
            patch_macho(f, 0)

if __name__ == '__main__':
    main()
