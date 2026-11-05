"""Generate the DG Command Center multi-resolution Windows icon using stdlib."""

import math
import struct
import sys
from pathlib import Path


SIZES = (16, 24, 32, 48, 64, 128, 256)
SCALE = 4


def segment_distance(x, y, x1, y1, x2, y2):
    dx, dy = x2 - x1, y2 - y1
    length_squared = dx * dx + dy * dy
    if not length_squared:
        return math.hypot(x - x1, y - y1)
    position = max(0.0, min(1.0, ((x - x1) * dx + (y - y1) * dy) / length_squared))
    return math.hypot(x - x1 - position * dx, y - y1 - position * dy)


def render(size):
    high_size = size * SCALE
    high_pixels = bytearray(high_size * high_size * 4)
    for py in range(high_size):
        y = (py + 0.5) / high_size
        for px in range(high_size):
            x = (px + 0.5) / high_size
            inset = 0.055
            radius = 0.23
            qx = abs(x - 0.5) - (0.5 - inset - radius)
            qy = abs(y - 0.5) - (0.5 - inset - radius)
            shape_distance = min(max(qx, qy), 0.0) + math.hypot(max(qx, 0), max(qy, 0)) - radius
            if shape_distance > 0:
                continue

            mix = max(0.0, min(1.0, (x * 0.48 + (1 - y) * 0.52)))
            color = [round(a + (b - a) * mix) for a, b in zip((7, 27, 48), (0, 144, 184))]
            border_distance = min(x - inset, 1 - inset - x, y - inset, 1 - inset - y)
            if border_distance < 0.012:
                color = [min(255, int(channel * 0.68 + edge * 0.32)) for channel, edge in zip(color, (116, 239, 255))]

            glyph_width = 0.037
            chevron = min(
                segment_distance(x, y, 0.29, 0.31, 0.52, 0.50),
                segment_distance(x, y, 0.52, 0.50, 0.29, 0.69),
            )
            underline = segment_distance(x, y, 0.49, 0.69, 0.73, 0.69)
            if min(chevron, underline) < glyph_width + 0.014:
                color = [0, 18, 35]
            if chevron < glyph_width:
                color = [244, 252, 255]
            if underline < glyph_width:
                color = [119, 239, 255]

            offset = (py * high_size + px) * 4
            high_pixels[offset:offset + 4] = bytes((*color, 255))

    pixels = bytearray(size * size * 4)
    for y in range(size):
        for x in range(size):
            totals = [0, 0, 0, 0]
            for sy in range(SCALE):
                for sx in range(SCALE):
                    offset = (((y * SCALE + sy) * high_size) + x * SCALE + sx) * 4
                    for channel in range(4):
                        totals[channel] += high_pixels[offset + channel]
            offset = (y * size + x) * 4
            pixels[offset:offset + 4] = bytes((value + SCALE * SCALE // 2) // (SCALE * SCALE) for value in totals)
    return pixels


def dib_frame(size):
    pixels = render(size)
    xor = bytearray()
    mask = bytearray()
    mask_stride = ((size + 31) // 32) * 4
    for y in range(size - 1, -1, -1):
        row_has_transparency = bytearray(mask_stride)
        for x in range(size):
            offset = (y * size + x) * 4
            red, green, blue, alpha = pixels[offset:offset + 4]
            xor.extend((blue, green, red, alpha))
            if alpha == 0:
                row_has_transparency[x // 8] |= 1 << (7 - x % 8)
        mask.extend(row_has_transparency)
    header = struct.pack("<IiiHHIIiiII", 40, size, size * 2, 1, 32, 0, len(xor), 0, 0, 0, 0)
    return header + xor + mask


def write_icon(path):
    frames = [(size, dib_frame(size)) for size in SIZES]
    directory_size = 6 + len(frames) * 16
    offset = directory_size
    entries = []
    for size, data in frames:
        dimension = 0 if size == 256 else size
        entries.append(struct.pack("<BBBBHHII", dimension, dimension, 0, 0, 1, 32, len(data), offset))
        offset += len(data)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(struct.pack("<HHH", 0, 1, len(frames)) + b"".join(entries) + b"".join(data for _, data in frames))
    print(f"Wrote {len(frames)} icon sizes to {path}")


if __name__ == "__main__":
    destination = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[1] / "assets" / "DG-Command-Center.ico"
    write_icon(destination)
