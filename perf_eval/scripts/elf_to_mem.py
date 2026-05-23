#!/usr/bin/env python3
import argparse
import subprocess
from pathlib import Path


ITCM_BASE = 0x80000000
ITCM_WORDS = 1 << 12
DTCM_BASE = 0x80100000
DTCM_WORDS = 1 << 16


def parse_ihex(path: Path) -> dict[int, int]:
    data: dict[int, int] = {}
    upper = 0
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line:
            continue
        if not line.startswith(":"):
            raise ValueError(f"bad ihex line: {line}")
        count = int(line[1:3], 16)
        addr = int(line[3:7], 16)
        rectype = int(line[7:9], 16)
        payload = bytes.fromhex(line[9 : 9 + count * 2])
        if rectype == 0x00:
            base = upper + addr
            for idx, byte in enumerate(payload):
                data[base + idx] = byte
        elif rectype == 0x01:
            break
        elif rectype == 0x04:
            upper = int.from_bytes(payload, "big") << 16
        elif rectype == 0x02:
            upper = int.from_bytes(payload, "big") << 4
    return data


def write_mem(path: Path, image: dict[int, int], base: int, words: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w") as out:
        for word in range(words):
            addr = base + word * 4
            value = 0
            for lane in range(4):
                value |= image.get(addr + lane, 0) << (lane * 8)
            out.write(f"{value:08x}\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--elf", required=True)
    parser.add_argument("--objcopy", required=True)
    parser.add_argument("--itcm", required=True)
    parser.add_argument("--dtcm", required=True)
    parser.add_argument("--ihex", required=True)
    args = parser.parse_args()

    subprocess.run([args.objcopy, "-O", "ihex", args.elf, args.ihex], check=True)
    image = parse_ihex(Path(args.ihex))

    max_itcm = ITCM_BASE + ITCM_WORDS * 4
    max_dtcm = DTCM_BASE + DTCM_WORDS * 4
    bad = [
        addr
        for addr in image
        if not (ITCM_BASE <= addr < max_itcm or DTCM_BASE <= addr < max_dtcm)
    ]
    if bad:
        sample = ", ".join(f"0x{x:08x}" for x in sorted(bad)[:8])
        raise SystemExit(f"addresses outside ITCM/DTCM: {sample}")

    write_mem(Path(args.itcm), image, ITCM_BASE, ITCM_WORDS)
    write_mem(Path(args.dtcm), image, DTCM_BASE, DTCM_WORDS)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
