"""Read-only structure validation for the two Dragon Q8B GPT layouts."""
import argparse
import struct
import uuid
import zlib
from pathlib import Path


def require(condition, message="invalid Dragon Q8B image structure"):
    # Never depend on assertions: Python -O/PYTHONOPTIMIZE must not bypass validation.
    if not condition:
        raise ValueError(message)


def validate(path, sector):
    size = path.stat().st_size
    require(size % sector == 0)
    with path.open("rb") as image:
        def read(offset, count):
            image.seek(offset)
            data = image.read(count)
            require(len(data) == count, "truncated image")
            return data

        mbr = read(0, 512)
        require(mbr[510:512] == b"\x55\xaa")
        require(mbr[450] == 0xEE)  # protective MBR

        def header(lba):
            data = read(lba * sector, sector)
            require(data[:8] == b"EFI PART")
            length, crc = struct.unpack_from("<II", data, 12)
            require(length == 92)
            clean = bytearray(data[:length])
            clean[16:20] = b"\x00" * 4
            require(zlib.crc32(clean) == crc)
            current, alternate, first, last = struct.unpack_from("<QQQQ", data, 24)
            require(current == lba)
            table, count, entry_size, table_crc = struct.unpack_from("<QIII", data, 72)
            require(entry_size == 128)
            entries = read(table * sector, count * entry_size)
            require(zlib.crc32(entries) == table_crc)
            return alternate, first, last, entries, data[56:72]

        backup, first, last, entries, disk_id = header(1)
        require(backup == size // sector - 1)
        alternate, bfirst, blast, bentries, bid = header(backup)
        require((alternate, bfirst, blast, bentries, bid) == (1, first, last, entries, disk_id))
        require(uuid.UUID(bytes_le=disk_id) == uuid.UUID("81ad85de-22d0-4e73-8ebb-0512b0000001"))
        partitions = []
        for index in range(2):
            entry = entries[index * 128:(index + 1) * 128]
            start, end = struct.unpack_from("<QQ", entry, 32)
            require(first <= start <= end <= last)
            require(start * sector % 1048576 == 0)
            partitions.append((uuid.UUID(bytes_le=entry[:16]), start, end))
        require(entries[256:] == b"\x00" * (len(entries) - 256))
        esp, root = partitions
        require(esp[0] == uuid.UUID("c12a7328-f81f-11d2-ba4b-00a0c93ec93b"))
        require(root[0] == uuid.UUID("0fc63daf-8483-4772-8e79-3d69d8477de4"))
        require(esp[1] * sector == 1048576)
        require((esp[2] - esp[1] + 1) * sector == 536870912)
        require(root[1] == esp[2] + 1)
        bpb = read(esp[1] * sector, sector)
        require(struct.unpack_from("<H", bpb, 11)[0] == sector)
        require(bpb[510:512] == b"\x55\xaa")
        require(bpb[71:82] == b"BOOT_Q8B   ")
        sb = read(root[1] * sector + 1024, 1024)
        require(sb[56:58] == b"\x53\xef")
        require(sb[120:136].rstrip(b"\x00") == b"NIXOS_Q8B")
        blocks = struct.unpack_from("<I", sb, 4)[0]
        if struct.unpack_from("<I", sb, 96)[0] & 0x80:  # ext4 64bit feature
            blocks |= struct.unpack_from("<I", sb, 336)[0] << 32
        block_size = 1024 << struct.unpack_from("<I", sb, 24)[0]
        require(block_size == 4096)
        require(struct.unpack_from("<I", sb, 352)[0] & 3 == 1,
                "expected fixed signed directory-hash semantics")
        require(0 < blocks * block_size <= (root[2] - root[1] + 1) * sector,
                "ext4 filesystem exceeds root partition")
    print(f"{path.name}: GPT/backup CRCs, partitions, FAT BPB and ext4 verified ({sector}-byte sectors)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("image", type=Path)
    parser.add_argument("sector", type=int, choices=[512, 4096])
    args = parser.parse_args()
    validate(args.image, args.sector)
