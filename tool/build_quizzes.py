"""Builds the bundled quizzes from tool/quiz_content.json.

Reads   tool/quiz_content.json        (questions transcribed from
                                       prototype/contents/quizzes.pdf)
        assets/E-Kumpas Wikalinga Videos/E-Kumpas Wikalinga Videos_v2/...
                                      (raw recordings, not committed)
Writes  assets/quizzes/<quiz>__qNN.mp4|.jpg  (clips only the quizzes use)
        assets/content/quizzes.json          (what the app loads)

A quiz clip that is the same recording as a lesson sign reuses the lesson's
compressed file in assets/signs/ instead of bundling it twice, so run
tool/build_media.py first. Trims and crops come from tool/media_fixes.py;
after changing one, delete the clip's output so it is rebuilt.

    python -I tool/build_quizzes.py [--check]   (--check: resolve clips only)
"""
import fnmatch
import hashlib
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_media  # noqa: E402
from media_fixes import FIXES  # noqa: E402

SRC = 'assets/E-Kumpas Wikalinga Videos/E-Kumpas Wikalinga Videos_v2'
CONTENT = 'tool/quiz_content.json'
OUT = 'assets/quizzes'
BUNDLE = 'assets/content/quizzes.json'


def md5(path):
    h = hashlib.md5()
    with open(path, 'rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def resolve(pattern, files):
    hits = [f for f in files if fnmatch.fnmatchcase(f, pattern)]
    if len(hits) != 1:
        raise SystemExit(f'clip {pattern!r} matched {len(hits)} files: {hits}')
    return hits[0]


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    check_only = '--check' in sys.argv
    with open(CONTENT, encoding='utf-8') as f:
        content = json.load(f)

    files = sorted(
        os.path.relpath(os.path.join(d, n), SRC).replace('\\', '/')
        for d, _, names in os.walk(SRC) for n in names
    )

    # Lesson recordings by content, so identical quiz copies reuse them.
    with open(build_media.LESSONS, encoding='utf-8') as f:
        lessons = json.load(f)
    plan, _, _ = build_media.match(lessons)
    lesson_media = {
        md5(os.path.join(build_media.SRC, src)): (src, dst) for _, src, dst in plan
    }

    jobs = []  # (src_rel, dst)
    sets = []
    missing = []
    for s in content['sets']:
        quizzes = []
        for n, quiz in enumerate(s['quizzes'], 1):
            quiz_id = f"{s['id']}_{n}"
            items = []
            for i, item in enumerate(quiz['items'], 1):
                assert len(item['options']) == 4, (quiz_id, i)
                media = None
                if item['clip'] is None:
                    missing.append(f'{s["title"]} {n} #{i}: {item["options"]["ABCD".index(item["answer"])]}')
                else:
                    src = resolve(item['clip'], files)
                    lesson = lesson_media.get(md5(os.path.join(SRC, src)))
                    if lesson and src not in FIXES:
                        media = lesson[1]
                    else:
                        ext = '.jpg' if build_media.is_image(src) else '.mp4'
                        media = f'{OUT}/{quiz_id}__q{i:02d}{ext}'
                        jobs.append((src, media))
                items.append({
                    'options': item['options'],
                    'answer': 'ABCD'.index(item['answer']),
                    'media': media,
                })
            quizzes.append({'id': quiz_id, 'number': n, 'title': quiz['title'], 'items': items})
        sets.append({
            'id': s['id'],
            'title': s['title'],
            'subtitle': s['subtitle'],
            'seconds_per_item': s['seconds_per_item'],
            'quizzes': quizzes,
        })

    total = sum(len(q['items']) for s in sets for q in s['quizzes'])
    print(f'{total} questions, {len(jobs)} quiz-only clips, {len(missing)} without a clip')
    for m in missing:
        print('  no clip:', m)
    if check_only:
        return

    import imageio_ffmpeg
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    os.makedirs(OUT, exist_ok=True)
    for i, (src, dst) in enumerate(jobs, 1):
        if not os.path.exists(dst):
            print(f'[{i}/{len(jobs)}] {dst}  <-  {src}', flush=True)
            build_media.encode(ffmpeg, os.path.join(SRC, src), dst, FIXES.get(src))
    wanted = {dst for _, dst in jobs}
    for n in os.listdir(OUT):
        if f'{OUT}/{n}' not in wanted:
            os.remove(f'{OUT}/{n}')

    with open(BUNDLE, 'w', encoding='utf-8') as f:
        json.dump({'source': content['source'], 'sets': sets}, f, ensure_ascii=False, indent=1)
    size = sum(os.path.getsize(d) for d in wanted)
    print(f'Wrote {len(wanted)} clips, {size / 1e6:.1f} MB, and {BUNDLE}')


if __name__ == '__main__':
    main()
