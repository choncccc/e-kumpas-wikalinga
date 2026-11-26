"""Compresses the blood pressure procedure walkthrough for the app.

Reads   assets/IMAGES/BP PROCEDURE/1.MOV ... 9.MOV   (raw, not bundled,
                                                     not committed)
Writes  assets/procedure/bp_step_<n>.mp4|.jpg        (bundled; the .jpg is a
                                                     poster frame)
        assets/procedure/bp_cover.jpg                (Home card photo, a
                                                     sharper frame of COVER)

Run from the project root:
    pip install imageio-ffmpeg      (once; ships its own ffmpeg)
    python -I tool/build_procedure.py

Uses the same encoder settings as tool/build_media.py. Already-built outputs
are skipped; delete one to rebuild it (e.g. after changing FIXES below).
"""
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_media import encode, poster  # noqa: E402

SRC = 'assets/IMAGES/BP PROCEDURE'
OUT = 'assets/procedure'
STEPS = 9

# Step whose clip, at COVER_AT seconds, is the Home card's photo.
COVER = 7
COVER_AT = 2.0

# Step number -> trim/crop, same format as media_fixes.FIXES.
FIXES = {}


def main():
    import imageio_ffmpeg
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    os.makedirs(OUT, exist_ok=True)
    for n in range(1, STEPS + 1):
        src = os.path.join(SRC, f'{n}.MOV')
        mp4 = os.path.join(OUT, f'bp_step_{n}.mp4')
        jpg = os.path.join(OUT, f'bp_step_{n}.jpg')
        if not os.path.exists(src):
            sys.exit(f'missing {src}')
        if not os.path.exists(mp4):
            print('encode', mp4)
            encode(ffmpeg, src, mp4, FIXES.get(n))
        if not os.path.exists(jpg):
            poster(ffmpeg, mp4, jpg)
    cover = os.path.join(OUT, 'bp_cover.jpg')
    if not os.path.exists(cover):
        subprocess.run([ffmpeg, '-v', 'error', '-y', '-ss', str(COVER_AT),
                        '-i', os.path.join(SRC, f'{COVER}.MOV'),
                        '-vf', 'scale=720:-2', '-frames:v', '1', '-q:v', '4',
                        '-f', 'mjpeg', cover], check=True)


if __name__ == '__main__':
    main()
