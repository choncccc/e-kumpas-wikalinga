"""Builds the Android launcher icons from assets/Icon/icon.jpg.

Run from the project root:  python -I tool/build_icon.py
(needs `pip install imageio-ffmpeg`, as tool/build_media.py does)

The source is a navy rounded square on a white margin. Launchers crop icons
to their own shape (circle, squircle...), so instead of using it as is:
  * everything outside the artwork is painted navy, dropping the margin and
    the rounded corners;
  * the adaptive icon (Android 8+) is a navy background plus that artwork
    scaled into the 66 dp safe zone of the 108 dp canvas, so no launcher
    mask cuts into it;
  * older Android gets a full-bleed navy square with rounded corners.
"""
import math
import os
import subprocess

import imageio_ffmpeg

SRC = 'assets/Icon/icon.jpg'
RES = 'android/app/src/main/res'
NAVY = (0x00, 0x18, 0x40)

# Measured on the source (1254 px): centre of the navy square, how far the
# artwork reaches from it, and where to start painting navy (between the
# artwork and the navy square's edge, ~575 px).
CENTRE = (625.5, 629.0)
ART_RADIUS = 535
CLEAR_FROM = 548

DENSITIES = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
MASTER = 1024

FF = imageio_ffmpeg.get_ffmpeg_exe()


def run(args, data=None):
    return subprocess.run([FF, '-v', 'error', '-y', *args], input=data,
                          stdout=subprocess.PIPE, check=True).stdout


def cleaned():
    """Source as RGB bytes with everything beyond the artwork painted navy."""
    raw = bytearray(run(['-i', SRC, '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-']))
    w = int(math.isqrt(len(raw) // 3))
    cx, cy = CENTRE
    limit = CLEAR_FROM * CLEAR_FROM
    navy = bytes(NAVY)
    for y in range(w):
        dy = (y - cy) ** 2
        row = y * w * 3
        for x in range(w):
            if (x - cx) ** 2 + dy > limit:
                i = row + x * 3
                raw[i:i + 3] = navy
    return w, bytes(raw)


def master(w, rgb, art_radius_px, out, rounded=False):
    """A MASTER-sized square with the artwork centred at the given radius."""
    scale = art_radius_px / ART_RADIUS
    side = round(w * scale) // 2 * 2
    # Crop around the artwork's centre so it lands in the middle.
    cx, cy = CENTRE
    crop = min(w, MASTER / scale)
    x0 = max(0, round(cx - crop / 2))
    y0 = max(0, round(cy - crop / 2))
    color = '0x%02X%02X%02X' % NAVY
    vf = (f'crop={round(min(crop, w - x0))}:{round(min(crop, w - y0))}:{x0}:{y0},'
          f'scale=iw*{scale}:-1:flags=lanczos,'
          f'pad={MASTER}:{MASTER}:(ow-iw)/2:(oh-ih)/2:color={color}')
    if rounded:
        r = MASTER * 0.18
        # Alpha 0 outside a rounded square.
        vf += (',format=rgba,geq=r=\'r(X,Y)\':g=\'g(X,Y)\':b=\'b(X,Y)\':'
               f"a='if(gt(pow(max(0,abs(X-{MASTER}/2)-({MASTER}/2-{r})),2)"
               f"+pow(max(0,abs(Y-{MASTER}/2)-({MASTER}/2-{r})),2),{r}*{r}),0,255)'")
    run(['-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{w}x{w}', '-i', '-',
         '-vf', vf, '-frames:v', '1', out], rgb)


def scaled(src, px, out):
    run(['-i', src, '-vf', f'scale={px}:{px}:flags=lanczos', out])


def main():
    w, rgb = cleaned()
    tmp = os.path.join('build', 'icon')
    os.makedirs(tmp, exist_ok=True)
    fg = os.path.join(tmp, 'foreground.png')
    legacy = os.path.join(tmp, 'legacy.png')
    # Safe zone is a 66 dp circle on a 108 dp canvas; keep the art at 31 dp
    # radius for a little breathing room.
    master(w, rgb, MASTER * 31 / 108, fg)
    master(w, rgb, MASTER * 0.40, legacy, rounded=True)

    for name, k in DENSITIES.items():
        d = os.path.join(RES, f'mipmap-{name}')
        os.makedirs(d, exist_ok=True)
        scaled(fg, round(108 * k), os.path.join(d, 'ic_launcher_foreground.png'))
        scaled(legacy, round(48 * k), os.path.join(d, 'ic_launcher.png'))

    os.makedirs(os.path.join(RES, 'mipmap-anydpi-v26'), exist_ok=True)
    with open(os.path.join(RES, 'mipmap-anydpi-v26', 'ic_launcher.xml'), 'w') as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n'
                '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
                '    <background android:drawable="@color/ic_launcher_background"/>\n'
                '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
                '</adaptive-icon>\n')
    with open(os.path.join(RES, 'values', 'ic_launcher_colors.xml'), 'w') as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
                '    <color name="ic_launcher_background">#%02X%02X%02X</color>\n'
                '</resources>\n' % NAVY)
    print('Launcher icons written to', RES)


main()
