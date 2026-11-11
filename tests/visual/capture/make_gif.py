#!/usr/bin/env python3
"""
Utility to assemble captured PNG frames into high-quality animated GIFs (960x540, 10-15 FPS).
Uses Pillow with adaptive color quantization for sharp visual artifacts.
"""

import os
import sys
import glob
from PIL import Image

def build_gif(frames_dir: str, output_path: str, fps: int = 12, target_width: int = 960, target_height: int = 540):
    files = sorted(glob.glob(os.path.join(frames_dir, "*.png")))
    if not files:
        print(f"Error: No PNG frames found in {frames_dir}", file=sys.stderr)
        sys.exit(1)
    
    print(f"Compiling {len(files)} frames from {frames_dir} at {fps} FPS -> {output_path}...")
    
    frames = []
    duration_ms = int(1000.0 / fps)
    
    for idx, f in enumerate(files):
        try:
            im = Image.open(f).convert("RGBA")
            # Create white/clean background for any transparent pixels
            bg = Image.new("RGB", im.size, (245, 240, 230))
            bg.paste(im, mask=im.split()[3])
            
            if target_width > 0 and target_height > 0:
                bg = bg.resize((target_width, target_height), Image.Resampling.BILINEAR)
            
            # Convert to 256-color palette with dithering for smooth gradients
            p_im = bg.convert("P", palette=Image.Palette.ADAPTIVE, colors=256)
            frames.append(p_im)
        except Exception as e:
            print(f"Warning: Failed reading {f}: {e}", file=sys.stderr)
    
    if not frames:
        print("Error: No frames could be processed", file=sys.stderr)
        sys.exit(1)
    
    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    
    # Save as animated GIF
    frames[0].save(
        output_path,
        save_all=True,
        append_images=frames[1:],
        duration=duration_ms,
        loop=0,
        optimize=True
    )
    
    file_size_kb = os.path.getsize(output_path) / 1024.0
    print(f"SUCCESS: Generated GIF {output_path} ({len(frames)} frames, {file_size_kb:.1f} KB)")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: make_gif.py <frames_dir> <output_gif_path> [fps] [width] [height]")
        sys.exit(1)
    
    f_dir = sys.argv[1]
    o_path = sys.argv[2]
    fps_val = int(sys.argv[3]) if len(sys.argv) > 3 else 12
    w_val = int(sys.argv[4]) if len(sys.argv) > 4 else 960
    h_val = int(sys.argv[5]) if len(sys.argv) > 5 else 540
    
    build_gif(f_dir, o_path, fps_val, w_val, h_val)
