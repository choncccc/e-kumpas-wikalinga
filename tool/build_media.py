"""Matches the raw sign recordings to lessons and compresses them for the app.

Reads   assets/E-Kumpas Wikalinga Videos/...   (raw .mov/.jpg, not bundled,
                                                 not committed)
Writes  assets/signs/<category>/<slug>.mp4|.jpg (bundled; every .mp4 also
                                                 gets a small .jpg poster
                                                 frame with the same name)
and a "media" path on each matched sign in assets/content/lessons.json.

Run from the project root, after tool/extract_content.py:
    pip install imageio-ffmpeg      (once; ships its own ffmpeg)
    python -I tool/build_media.py   [--check]  (--check: match only, no encode)

Already-built outputs are skipped, so re-running is cheap. After changing a
clip's entry in tool/media_fixes.py, delete its output so it is rebuilt. Files are matched
by name: the English (or Tagalog) half of "Arm_ Braso.mov" against the term
and its Tagalog. MANUAL covers names that don't match that way. Anything left
over on either side is listed at the end.
"""
import json
import os
import re
import subprocess
import sys
import unicodedata

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from media_fixes import FIXES  # noqa: E402

SRC = 'assets/E-Kumpas Wikalinga Videos/E-Kumpas Wikalinga Videos'
OUT = 'assets/signs'
LESSONS = 'assets/content/lessons.json'

# Category id -> folder of raw recordings.
FOLDERS = {
    'foundation': 'Basic Sign Language (Foundation)',
    'basic': 'Convo',
    'triage': 'Med & Triage',
    'medical_family': 'Medical and Family Hx',
    'nutrition': 'Nutritional and Lifestyle Hx',
    'procedures': 'Procedures & Health Adv',
}

# (category id, term) -> file under that category's folder, for names the
# automatic match misses or gets ambiguous.
MANUAL = {
    ('triage', 'Heart'): 'heart.MOV',
    ('triage', 'How many days?'): 'how many days_.MOV',
    ('triage', 'Stomach Ache / Abdominal discomfort'): 'Chief Complains/Stomach ache_abdominal discomfort_.mov',
    ('triage', 'Mouth'): 'Body Parts/Mouth_ Bunganga.mov',
    ('triage', 'Severe Swelling of Feet or Ankles'): 'Red-Flag Symptoms (Hypertension)/severe swelling of feet.MOV',
    ('triage', 'Do you know the warning signs that need immediate medical attention?'):
        'Red-Flag Symptoms (Hypertension)/Do you know the warning signs that needs immediate medical attention.mov',
    ('triage', 'Normal BP: Below 120/80'): 'Blood Pressure Values/Normal BP 120_80 below.MOV',
    ('triage', 'Elevated BP: 120–129 / Below 80'): 'Blood Pressure Values/Elevated BP 120-129_80 below.MOV',
    ('triage', 'Stage 1 High BP: 130–139 / 80–89'): 'Blood Pressure Values/Stage 1 High BP 130–139 _ 80–89.MOV',
    ('triage', 'Stage 2 High BP: 140/90 or higher'): 'Blood Pressure Values/Stage 2 High BP_ 140_90 or higher.MOV',
    ('triage', 'Emergency BP: Above 180/120'): 'Blood Pressure Values/Emergency BP_ Above 180_120 .MOV',
    ('foundation', 'Now/Today'): 'Time/Now_Today.MOV',
    ('foundation', 'Daily/Everyday'): 'Time/Everyday_ Araw-araw.mov',
    ('foundation', 'Number 1,000,000 (Million)'): 'Numbers/1 Million_ Isang Milyon.mov',
    ('basic', 'My name'): 'Common Greetings & Introduction/My Name _ Ang pangalan ko_.mov',
    ('basic', 'Please repeat'): 'Simple Responses/Please, Again (Repeat) _ Pakiusap, Paki-ulit.mov',
    ('basic', 'Please wait'): 'Simple Responses/Please, Wait _ Sandali lang po.mov',
    ('basic', 'How old are you?'): 'Questions/What Is Your Age_  _ Ilang taon ka na_.mov',
    ('basic', 'What is your occupation?'): 'Questions/What Is Your Work_ _ Anong trabaho mo__.mov',
    ('basic', 'What is your name?'): 'Questions/What Is Your Name_ _ Anong pangalan mo__.mov',
    ('basic', "I'm fine"): 'Courtesis/Im Fine _ Ayos lang ako.mov',
    ('medical_family', 'Heart Attack'): 'Hypertension-Related Conditions/Heart attack _ ATAKE SA PUSO.mov',
    ('medical_family', 'Kidney Disease'): 'Hypertension-Related Conditions/Kidney Disease _ SAKIT SA KIDNEY _ SAKIT SA BATO.mov',
    ('medical_family', 'Do you have any allergies?'): 'Allergies/Do you have any allergy_ May alerdyi ka ba_.mov',
    ('medical_family', 'What are you allergic to?'): 'Allergies/allergy what (di pa sure)_ anong alerdyi.mov',
    ('medical_family', 'Drug / Medicine Allergy'): 'Allergies/Medicine Allergy _ ALERDYI SA GAMOT.mov',
    ('medical_family', 'Children'): 'Family Relationship/CHILDREN _ Mga bata _ MGA ANAK.mov',
    ('medical_family', '"Does anyone in your family have high blood pressure?"'):
        'Family Relationship/DOES ANYONE IN YOUR FAMILY HAVE HIGH BLOOD PRESSURE_ _ Meron bang may mataas na alta-presyon sa pamilya niyo__.mov',
    ('medical_family', 'Blurred vision'): 'General Health History/BLURRY VISION _ MALABONG PANINGIN.mov',
    ('medical_family', 'Do you have other illnesses?'): 'General Health History/do you have other illness_.MOV',
    ('medical_family', 'Are you taking medicine for hypertension?'): 'Medications/are you taking your medicine for hpt_.MOV',
    ('medical_family', 'Diabetes / High Sugar'): 'Hypertension-Related Conditions/Diabetes _ DIYABETIS.mov',
    ('medical_family', 'High Blood Pressure / Hypertension'):
        'Hypertension-Related Conditions/High blood pressure _ MATAAS NA BLOOD PRESSURE _ MATAAS NA PRESYON SA DUGO.mov',
    ('nutrition', 'Eat / Meals'): 'Dietary Habits/Kumain _ eat.mov',
    ('nutrition', 'Avoid salty and processed foods.'):
        'Dietary Habits/Iwasan ang maalat at naprosesong mga pagkain _ avoid salty and processed food .MOV',
    ('nutrition', 'Eat more vegetables and fruits.'):
        'Dietary Habits/Kumain ng mas maraming gulat at prutas _ eat more vege and fruit.MOV',
    ('nutrition', 'Do you regularly or always drink coffee?'):
        'Dietary Habits/Regular ka bang umiinom ng kape _ do u regularly drink coffee_.mov',
    ('nutrition', 'How many glasses of water do you drink every day?'):
        'Fluid & Intake Output/Ilang baso ng tubig ang iniinom mo araw-araw_ _ how many glasses of water do u drink everyday.MOV',
    ('nutrition', 'How many times do you urinate in a day?'):
        'Fluid & Intake Output/Ilang beses ka umiihi araw-araw_ _ how many times do u urinate everyday.MOV',
    ('nutrition', 'Smoking / Vaping'): 'Vices & Risk Screening/paninigarilyo _ smoking.mov',
    ('nutrition', 'Alcohol Drinking'): 'Vices & Risk Screening/pag-inom ng alak _ alcohol drnking.mov',
    ('nutrition', 'Illegal Drugs / Substance Use'):
        'Vices & Risk Screening/illegal drugs_ substance use_ ILEGAL NA DROGA_ PAGGAMIT NG ILEGAL NA DROGA.mov',
    ('procedures', 'Support arm on table at heart level'): 'Pre-Measurment Instructions/REST ARM ON THE TABLE _ IPATONG ANG BRASO SA MESA.mov',
    ('procedures', 'Take Pulse / Check Heart Rate'):
        'Medical Procedures/CHECK HEART RATE _ SURIIN ANG BILIS NG TIBOK NG PUSO.mov',
    ('procedures', 'Get Enough Sleep (7–8 Hours)'):
        'Hypertension Prevention & Nursing Advice/Get enough sleep (7-8 hours) _ MATULOG NG SAPAT, 7-8 ORAS.mov',
    ('procedures', 'Get enough sleep.'): 'Hypertension Prevention & Nursing Advice/Get enough sleep.mov',
    ('procedures', 'Regular Medical Checkup'): 'Hypertension Prevention & Nursing Advice/regular check up.MOV',
    ('procedures', 'Limit coffee and other drinks with caffeine.'):
        'Hypertension Prevention & Nursing Advice/Limit coffee and other drinks with caffeine_.mov',
    ('procedures', 'Weight Control / Healthy Weight'):
        'Hypertension Prevention & Nursing Advice/Weight control_Healthy weight _ KONTROLIN ANG TIMBANG _ TAMANG TIMBANG.mov',
    ('procedures', 'Manage Stress & Rest'):
        'Hypertension Prevention & Nursing Advice/Manage Stress and Rest _ PAMAMAHALA SA STRESS AT PAHINGA.mov',
    ('procedures', 'Control Cholesterol & Sugar'):
        'Hypertension Prevention & Nursing Advice/Control Cholesterol and Sugar _ KONTROLIN ANG KOLESTEROL AT ANG ASUKAL SA DUGO.mov',
    ('procedures', 'Take your medicine on time.'):
        'Hypertension Prevention & Nursing Advice/Take your medication on time _ INUMIN ANG GAMOT SA TAMANG ORAS.mov',
    ('procedures', 'Drink plenty of water every day.'):
        'Hypertension Prevention & Nursing Advice/drink plenty of water everyday _ LAGING UMINOM NG MARAMING TUBIG.mov',
    ('triage', 'Blurry or Sudden Vision Loss'):
        'Red-Flag Symptoms (Hypertension)/Blurry, Sudden Vision Loss_ malabo o biglaang pagkawala ng paningin.mov',
    ('medical_family', 'Painkiller / Pain Medicine'): 'Medications/Pain killer_ Pampawala ng sakit.mov',
    ('nutrition', 'Water'): 'Dietary Habits/Tubig_water.mov',
    ('nutrition', 'Salty Food'): 'Dietary Habits/Pagkaing maalat_salty food.mov',
    ('nutrition', 'Oily / Fatty Food'): 'Dietary Habits/Pagkaing mamantika _ oily food.MOV',
    ('nutrition', 'Sweet Food'): 'Dietary Habits/Pagkaing matamis_ Sweet Foods.mov',
    ('nutrition', 'Vegetables'): 'Dietary Habits/gulay _ vegetable.MOV',
    ('nutrition', 'Fruits'): 'Dietary Habits/prutas_fruits.MOV',
    ('procedures', 'Eat more fruits and vegetables.'):
        'Hypertension Prevention & Nursing Advice/eat more vegetables and fruit _ KUMAIN NG MARAMING GULAY AT PRUTAS.mov',
    ('procedures', 'Keep feet flat on the floor'):
        'Pre-Measurment Instructions/KEEP FEET FLAT ON FLOOR _ PANATILIHING PATAG ANG MGA PAA SA SAHIG.mov',
    ('procedures', 'No coffee / caffeine (30 mins before)'):
        'Pre-Measurment Instructions/No coffee 30 min before _ BAWAL MAGKAPE BAGO ANG 30 MINUTO.mov',
    ('procedures', 'No heavy exercise (30 mins before)'):
        'Pre-Measurment Instructions/No heavy exercise 30 minutes before _ IWASAN ANG MGA MABIBIGAT NA EHERSISYO BAGO ANG 30 MINUTO.mov',
    ('procedures', 'No smoking (30 mins before)'):
        'Pre-Measurment Instructions/No smoking 30 min before _ BAWAL ANG MANIGARILYO BAGO ANG 30 MINUTO.mov',
    ('procedures', 'Rest for 5 minutes'): 'Pre-Measurment Instructions/Rest for 5 min _ MAGPAHINGA NG 5 MINUTO.mov',
}

# Recordings that are deliberately not used (duplicates and retakes).
UNUSED = {
    'Medical and Family Hx/Heart Attack _ ATAKE SA PUSO.mov',
    'Medical and Family Hx/Hypertension-Related Conditions/Kidney Disease_.mov',
    'Medical and Family Hx/Allergies/do you have any allergy_ may alredyi ka ba_.mov',
}

IMAGE_EXT = {'.jpg', '.jpeg', '.png'}


def norm(s):
    s = unicodedata.normalize('NFKD', s).encode('ascii', 'ignore').decode()
    s = s.lower().replace('&', ' and ')
    return re.sub(r'[^a-z0-9]+', ' ', s).strip()


def term_keys(sign):
    """Ways a file might name this sign: English first, then Tagalog (which
    has more clashes, e.g. Time and Hour are both "Oras")."""
    term = sign['term']
    english = {norm(term)}
    m = re.match(r'^(Letter|Number) (.+)$', term)
    if m:
        english.add(norm(m.group(2)))
    for part in re.split(r'\s*/\s*', term):
        english.add(norm(part))
    tagalog = {norm(p) for p in re.split(r'\s*/\s*', sign.get('tagalog', ''))}
    return [english - {''}, tagalog - {''}]


def file_keys(name):
    stem = os.path.splitext(name)[0] if '.' in name[-5:] else name
    keys = {norm(stem)}
    for part in re.split(r'_\s|\s_|_$', stem):
        if part.strip():
            keys.add(norm(part))
    keys.discard('')
    return keys


def slug(s):
    s = unicodedata.normalize('NFKD', s).encode('ascii', 'ignore').decode().lower()
    return re.sub(r'[^a-z0-9]+', '_', s).strip('_')[:60]


def is_image(path):
    return os.path.splitext(path)[1].lower() in IMAGE_EXT


def encode(ffmpeg, src, dst, fix=None):
    """Compresses one recording. [fix] (from media_fixes.FIXES) trims the
    clip or crops clutter off its sides."""
    fix = fix or {}
    tmp = dst + '.part'
    crop = ''
    if 'crop' in fix:
        left, right, top, bottom = (*fix['crop'], 0, 0)[:4]
        crop = (f'crop=iw*{1 - left - right:.4f}:ih*{1 - top - bottom:.4f}:'
                f'iw*{left:.4f}:ih*{top:.4f},')
    start = fix.get('start', 0)
    seek = ['-ss', str(start)] if start else []
    trim = ['-t', f"{fix['end'] - start:.3f}"] if 'end' in fix else []
    if dst.endswith('.jpg'):
        args = ['-vf', f'{crop}scale=720:-2', '-frames:v', '1', '-q:v', '4', '-f', 'mjpeg']
    else:
        # Muted, 640 px wide H.264 that every Android/iOS decoder plays.
        args = ['-map', '0:v:0', '-an', *trim, '-vf', f'{crop}scale=640:-2,fps=30',
                '-c:v', 'libx264', '-profile:v', 'main', '-pix_fmt', 'yuv420p',
                '-crf', '28', '-preset', 'slow', '-movflags', '+faststart',
                '-f', 'mp4']
    subprocess.run([ffmpeg, '-v', 'error', '-y', *seek, '-i', src, *args, tmp], check=True)
    os.replace(tmp, dst)


def poster(ffmpeg, video, dst):
    """A representative frame (ffmpeg's thumbnail filter picks the least
    blurry of the first 90), small enough for game cards and thumbnails."""
    tmp = dst + '.part'
    subprocess.run([ffmpeg, '-v', 'error', '-y', '-i', video,
                    '-vf', 'thumbnail=90,scale=320:-2', '-frames:v', '1',
                    '-q:v', '5', '-f', 'mjpeg', tmp], check=True)
    os.replace(tmp, dst)


def match(lessons):
    """Pairs every lesson sign with its recording. Sets sign['media'] and
    returns (plan, missing, leftover), plan being (sign, src_rel, dst) with
    src_rel relative to SRC."""
    plan = []  # (sign, src_rel, dst)
    used = set()
    missing = []
    for cat in lessons['categories']:
        root = os.path.join(SRC, FOLDERS[cat['id']])
        files = sorted(
            os.path.relpath(os.path.join(d, n), root).replace('\\', '/')
            for d, _, names in os.walk(root) for n in names
        )
        files = [f for f in files if f'{FOLDERS[cat["id"]]}/{f}' not in UNUSED]
        index = {}
        for f in files:
            for k in file_keys(os.path.basename(f)):
                index.setdefault(k, []).append(f)

        for topic in cat['topics']:
            for sign in topic['signs']:
                sign.pop('media', None)
                manual = MANUAL.get((cat['id'], sign['term']))
                if manual:
                    if manual not in files:
                        raise SystemExit(f'MANUAL file not found: {cat["id"]}/{manual}')
                    hits = [manual]
                else:
                    hits = []
                    for keys in term_keys(sign):
                        hits = sorted({f for k in keys for f in index.get(k, [])})
                        if hits:
                            break
                if len(hits) > 1:
                    raise SystemExit(
                        f'Ambiguous match for {cat["id"]}/{sign["term"]!r}: {hits}. Add it to MANUAL.'
                    )
                if not hits:
                    missing.append(f'{cat["id"]}/{topic["title"]}/{sign["term"]}')
                    continue
                src_rel = hits[0]
                if src_rel in used:
                    raise SystemExit(f'{src_rel} matched twice; add a MANUAL entry.')
                used.add(src_rel)
                ext = '.jpg' if is_image(src_rel) else '.mp4'
                dst = f'{OUT}/{cat["id"]}/{slug(topic["title"])}__{slug(sign["term"])}{ext}'
                sign['media'] = dst
                plan.append((sign, f'{FOLDERS[cat["id"]]}/{src_rel}', dst))

    leftover = []
    for cat_id, folder in FOLDERS.items():
        root = os.path.join(SRC, folder)
        for d, _, names in os.walk(root):
            for n in names:
                rel = os.path.relpath(os.path.join(d, n), root).replace('\\', '/')
                if rel not in used and f'{folder}/{rel}' not in UNUSED:
                    leftover.append(f'{folder}/{rel}')
    return plan, missing, leftover


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    check_only = '--check' in sys.argv
    with open(LESSONS, encoding='utf-8') as f:
        lessons = json.load(f)
    plan, missing, leftover = match(lessons)

    print(f'{len(plan)} signs matched, {len(missing)} without media, '
          f'{len(leftover)} recordings unused')
    for m in missing:
        print('  no media:', m)
    for l in leftover:
        print('  unused:  ', l)
    if check_only:
        return

    import imageio_ffmpeg
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    wanted = {dst for _, _, dst in plan}
    posters = {dst[:-4] + '.jpg' for dst in wanted if dst.endswith('.mp4')}
    assert not posters & wanted, 'poster name clashes with a sign still'
    wanted |= posters
    for i, (_, src, dst) in enumerate(plan, 1):
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        if not os.path.exists(dst):
            print(f'[{i}/{len(plan)}] {dst}', flush=True)
            encode(ffmpeg, os.path.join(SRC, src), dst, FIXES.get(src))
        jpg = dst[:-4] + '.jpg'
        if dst.endswith('.mp4') and not os.path.exists(jpg):
            poster(ffmpeg, dst, jpg)
    # Drop outputs for signs that no longer have media.
    for d, _, names in os.walk(OUT):
        for n in names:
            p = f'{d}/{n}'.replace('\\', '/')
            if p not in wanted:
                os.remove(p)

    with open(LESSONS, 'w', encoding='utf-8') as f:
        json.dump(lessons, f, ensure_ascii=False, indent=1)
    total = sum(os.path.getsize(dst) for dst in wanted)
    print(f'Wrote {len(wanted)} files, {total / 1e6:.1f} MB, and updated {LESSONS}')


if __name__ == '__main__':
    main()
