#!/bin/bash
# Deploy HomeButler to jailbroken iPad over SSH
# Builds with Theos, copies to /Applications/ (permanent, never expires)
# Usage: ./deploy.sh

set -e

IPAD_IP="${IPAD_IP:-192.168.4.113}"
IPAD_PASS="${IPAD_PASS:-alpine}"
SSH_OPTS="-o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa -o StrictHostKeyChecking=no"
SSH="sshpass -p $IPAD_PASS ssh $SSH_OPTS root@$IPAD_IP"
SCP="sshpass -p $IPAD_PASS scp $SSH_OPTS"

echo "==> Building with Theos..."
make clean
make

APP_PATH=".theos/obj/debug/HomeButler.app"

echo "==> Copying resources..."
cp -r Resources/* "$APP_PATH/" 2>/dev/null || true

# Xcode 27's linker drops the ARM Thumb bit on all armv7 function pointers.
# iOS 9's objc_msgSend uses the bit to pick Thumb vs ARM mode, so every ObjC
# method call crashes with SIGILL/SIGBUS without this patch.
echo "==> Patching armv7 Thumb bits..."
python3 << 'PATCH_EOF'
import struct, sys

path = sys.argv[1] if len(sys.argv) > 1 else ".theos/obj/debug/HomeButler.app/HomeButler"
with open(path, "rb") as f:
    data = bytearray(f.read())

magic = struct.unpack("<I", data[0:4])[0]
if magic == 0xcafebabe:
    print("  Fat binary not supported by this patcher; build armv7-only"); sys.exit(1)
if magic != 0xfeedface:
    print("  Not a 32-bit Mach-O"); sys.exit(1)

ncmds = struct.unpack("<I", data[16:20])[0]
off = 28
segments = []
rebase_off = rebase_size = 0
text_start = text_end = 0
patched_entry = False

for _ in range(ncmds):
    cmd = struct.unpack("<I", data[off:off+4])[0]
    csz = struct.unpack("<I", data[off+4:off+8])[0]
    if cmd == 1:  # LC_SEGMENT
        seg = data[off+8:off+24].split(b"\x00")[0].decode()
        va  = struct.unpack("<I", data[off+24:off+28])[0]
        vs  = struct.unpack("<I", data[off+28:off+32])[0]
        fo  = struct.unpack("<I", data[off+32:off+36])[0]
        segments.append((seg, va, vs, fo))
        ns = struct.unpack("<I", data[off+48:off+52])[0]
        so = off + 56
        for _ in range(ns):
            sn = data[so:so+16].split(b"\x00")[0].decode()
            sa = struct.unpack("<I", data[so+32:so+36])[0]
            ss = struct.unpack("<I", data[so+36:so+40])[0]
            if sn == "__text":
                text_start, text_end = sa, sa + ss
            so += 68
    elif cmd == 0x80000022:  # LC_DYLD_INFO_ONLY
        rebase_off = struct.unpack("<I", data[off+8:off+12])[0]
        rebase_size = struct.unpack("<I", data[off+12:off+16])[0]
    elif cmd == 0x80000028:  # LC_MAIN
        eo = struct.unpack("<Q", data[off+8:off+16])[0]
        if not eo & 1:
            struct.pack_into("<Q", data, off+8, eo | 1)
            patched_entry = True
    off += csz

# Decode rebase opcodes
def uleb(data, p):
    r = 0; s = 0
    while True:
        b = data[p]; r |= (b & 0x7f) << s; p += 1
        if not (b & 0x80): return r, p
        s += 7

p = rebase_off; end = rebase_off + rebase_size
si = so = 0; locs = []
while p < end:
    b = data[p]; p += 1; op = b & 0xF0; im = b & 0x0F
    if   op == 0x00: break
    elif op == 0x10: pass
    elif op == 0x20: si = im; so, p = uleb(data, p)
    elif op == 0x30: a, p = uleb(data, p); so += a
    elif op == 0x40: so += im * 4
    elif op == 0x50:
        for _ in range(im): locs.append((si, so)); so += 4
    elif op == 0x60:
        t, p = uleb(data, p)
        for _ in range(t): locs.append((si, so)); so += 4
    elif op == 0x70:
        locs.append((si, so)); a, p = uleb(data, p); so += 4 + a
    elif op == 0x80:
        t, p = uleb(data, p); sk, p = uleb(data, p)
        for _ in range(t): locs.append((si, so)); so += 4 + sk

n = 0
for sidx, soff in locs:
    if sidx < len(segments):
        _, _, _, sfoff = segments[sidx]
        foff = sfoff + soff
        if foff + 4 <= len(data):
            val = struct.unpack("<I", data[foff:foff+4])[0]
            if text_start <= val < text_end and not (val & 1):
                struct.pack_into("<I", data, foff, val | 1)
                n += 1

with open(path, "wb") as f:
    f.write(data)
print("  Patched %d function pointers + entry point" % n if patched_entry else "  Patched %d function pointers" % n)
PATCH_EOF

echo "==> Signing with ldid..."
ldid -Sentitlements.plist "$APP_PATH/HomeButler"

echo "==> Stopping HomeButler on device..."
$SSH "killall HomeButler 2>/dev/null || true"

echo "==> Deploying to /Applications/..."
$SSH "rm -rf /Applications/HomeButler.app; mkdir -p /Applications/HomeButler.app"
$SCP -r "$APP_PATH"/* root@$IPAD_IP:/Applications/HomeButler.app/

echo "==> Setting permissions and refreshing..."
$SSH "chmod -R 755 /Applications/HomeButler.app && chown -R root:wheel /Applications/HomeButler.app && uicache -p /Applications/HomeButler.app"

echo "==> Launching HomeButler..."
$SSH "uiopen /Applications/HomeButler.app"

echo ""
echo "Done! HomeButler deployed to /Applications/ — permanent install."
