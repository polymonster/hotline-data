"""
pack_pbr_textures.py

Walks a source textures directory and, for each subdirectory containing a
*_roughness.png, produces a *_roughness_metallic.png in the matching path
under the output (temp) directory:

    R channel = roughness (grayscale)
    G channel = metallic  (grayscale, 0 if no *_metallic.png is present)
    B channel = 0
    A channel = 255

Files are skipped if the output is already newer than both inputs.

Usage:
    py -3 pack_pbr_textures.py <src_textures_dir> <temp_textures_dir>
"""

import os
import sys
from PIL import Image


def pack_directory(root, src_base, temp_base):
    files = os.listdir(root)

    roughness_file = next(
        (os.path.join(root, f) for f in files if f.endswith("_roughness.png")), None
    )
    if roughness_file is None:
        return

    metallic_file = next(
        (os.path.join(root, f) for f in files if f.endswith("_metallic.png")), None
    )

    # Build output path, mirroring directory structure under temp_base
    rel = os.path.relpath(roughness_file, src_base)
    output_name = os.path.basename(rel).replace("_roughness.png", "_roughness_metallic.png")
    output_path = os.path.join(temp_base, os.path.dirname(rel), output_name)

    # Skip if output is up-to-date
    if os.path.exists(output_path):
        output_mtime = os.path.getmtime(output_path)
        newest_input = os.path.getmtime(roughness_file)
        if metallic_file:
            newest_input = max(newest_input, os.path.getmtime(metallic_file))
        if output_mtime >= newest_input:
            return

    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    roughness_img = Image.open(roughness_file).convert("L")
    w, h = roughness_img.size

    if metallic_file:
        metallic_img = Image.open(metallic_file).convert("L")
        if metallic_img.size != (w, h):
            metallic_img = metallic_img.resize((w, h), Image.LANCZOS)
        print(f"  pack: {os.path.relpath(roughness_file, src_base)}")
        print(f"      + {os.path.relpath(metallic_file, src_base)}")
    else:
        metallic_img = Image.new("L", (w, h), 0)
        print(f"  pack: {os.path.relpath(roughness_file, src_base)} (no metallic)")

    packed = Image.merge("RGBA", [
        roughness_img,
        metallic_img,
        Image.new("L", (w, h), 0),
        Image.new("L", (w, h), 255),
    ])
    packed.save(output_path)
    print(f"    -> {os.path.relpath(output_path, temp_base)}")


def main(src_base, temp_base):
    print(f"pack_pbr_textures: {src_base} -> {temp_base}")
    for root, dirs, _ in os.walk(src_base):
        dirs.sort()
        pack_directory(root, src_base, temp_base)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(f"usage: {sys.argv[0]} <src_textures_dir> <temp_textures_dir>")
        sys.exit(1)
    main(sys.argv[1], sys.argv[2])
