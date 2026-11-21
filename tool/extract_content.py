"""Turns prototype/contents/App-Content.pdf into assets/content/lessons.json.

Tagalog translations (and the few lesson changes that came with them) come
from tool/tagalog.json, a hand transcription of
prototype/contents/FSL-APP-Content_WithTagalog.pdf.

Run from the project root:  python -I tool/extract_content.py
then:                       python -I tool/build_media.py
(this script drops the media links, build_media.py puts them back).
Re-run whenever the content changes, then bump
SqliteLessonRepository.contentVersion so installed apps reseed.
"""
import json
import re
import sys

import fitz  # PyMuPDF

SRC = 'prototype/contents/App-Content.pdf'
OUT = 'assets/content/lessons.json'
TAGALOG = 'tool/tagalog.json'

# Must match LearningContent ids/titles in lib/data/learning_content.dart.
CATEGORY_IDS = ['foundation', 'basic', 'triage', 'medical_family', 'nutrition', 'procedures']


def clean(s):
    s = re.sub(r'\s+', ' ', s).strip()
    s = s.replace('’', "'").replace(' :', ':')
    return s.rstrip(':').strip()


def main():
    text = '\n'.join(p.get_text() for p in fitz.open(SRC))
    body = text[text.index('LEARNING CONTENT'):text.index('\nGAME')]
    lines = [l.strip() for l in body.splitlines()]

    tips = []
    categories = []
    field = None  # (dict, key) currently receiving text

    def append(s):
        obj, key = field
        cur = obj.get(key, '')
        # A line ending in '-' is a word broken across lines (TOO-|MUCH).
        joiner = '' if cur.endswith('-') else ' '
        obj[key] = (cur + joiner + s) if cur else s

    for line in lines[1:]:
        if not line:
            continue
        m = re.match(r'^(\d)\.\s+(.*)$', line)
        if m and len(categories) < 6:
            cat = {'id': CATEGORY_IDS[len(categories)], 'title': '', 'topics': []}
            categories.append(cat)
            field = (cat, 'title')
            append(m.group(2))
            continue
        if line.startswith('●'):
            topic = {'title': '', 'signs': []}
            categories[-1]['topics'].append(topic)
            field = (topic, 'title')
            append(line[1:].strip())
            continue
        if line.startswith('○') or line == '-':
            rest = line[1:].strip()
            signs = categories[-1]['topics'][-1]['signs']
            if line == '-' or re.match(r'^(Sign\s*Order|Facial\s*Expression)', rest):
                note = {}
                signs[-1].setdefault('notes', []).append(note)
                field = (note, 'text')
            else:
                sign = {'term': ''}
                signs.append(sign)
                field = (sign, 'term')
            if rest:
                append(rest)
            continue
        if line == '-':
            continue
        append(line)

    # Tidy text and split notes into sign order / facial expression.
    for cat in categories:
        cat['title'] = clean(cat['title'])
        for topic in cat['topics']:
            topic['title'] = clean(topic['title'])
            # Some notes sit under their own bullet ("○" then "Sign Order: ..."
            # on the next line). Fold those back into the sign above them.
            merged = []
            for sign in topic['signs']:
                term = clean(sign['term'])
                if merged and re.match(r'^(Sign\s*Order|Facial\s*Expression):', term, re.I):
                    merged[-1].setdefault('notes', []).append({'text': term})
                    merged[-1]['notes'].extend(sign.get('notes', []))
                else:
                    merged.append(sign)
            topic['signs'] = merged
            for sign in topic['signs']:
                sign['term'] = clean(sign['term'])
                for note in sign.pop('notes', []):
                    t = clean(note.get('text', ''))
                    m = re.match(r'^Sign\s*Order:\s*(.*)$', t, re.I)
                    if m:
                        sign['sign_order'] = m.group(1).rstrip('.').strip()
                        continue
                    m = re.match(r'^Facial\s*Expression:\s*(.*)$', t, re.I)
                    if m:
                        sign['facial_expression'] = re.sub(r'\s*:\s*', ': ', m.group(1)).strip().rstrip('.')
                        continue
                    if t:
                        raise SystemExit(f'Unrecognised note under {sign["term"]!r}: {t!r}')
            # Drop stray empty entries from PDF line noise.
            topic['signs'] = [s for s in topic['signs'] if s['term']]

    apply_tagalog(categories)

    with open(OUT, 'w', encoding='utf-8') as f:
        json.dump({'source': SRC, 'categories': categories}, f, ensure_ascii=False, indent=1)

    sys.stdout.reconfigure(encoding='utf-8')
    for cat in categories:
        n = sum(len(t['signs']) for t in cat['topics'])
        tl = sum(1 for t in cat['topics'] for s in t['signs'] if 'tagalog' in s)
        print(f"{cat['id']:15} {cat['title']!r}: {len(cat['topics'])} topics, {n} signs, {tl} with Tagalog")
        for t in cat['topics']:
            print(f"    {t['title']!r} ({len(t['signs'])})")


def apply_tagalog(categories):
    """Applies tool/tagalog.json. Every key in it must match a lesson, so a
    typo or a renamed term fails loudly instead of silently dropping a
    translation."""
    with open(TAGALOG, encoding='utf-8') as f:
        data = json.load(f)
    by_id = {c['id']: c for c in categories}

    def topic_of(cat_id, title):
        for t in by_id[cat_id]['topics']:
            if t['title'] == title:
                return t
        raise SystemExit(f'tagalog.json: no topic {cat_id}/{title!r}')

    for cat_id, topics in data['edits'].items():
        for title, edits in topics.items():
            signs = topic_of(cat_id, title)['signs']
            for op, anchor, terms in edits:
                i = next((i for i, s in enumerate(signs) if s['term'] == anchor), None)
                if i is None:
                    raise SystemExit(f'tagalog.json: no sign {anchor!r} in {cat_id}/{title!r}')
                new = [{'term': t} for t in terms]
                if op == 'after':
                    signs[i + 1:i + 1] = new
                elif op == 'before':
                    signs[i:i] = new
                elif op == 'replace':
                    signs[i:i + 1] = new
                else:
                    raise SystemExit(f'tagalog.json: unknown edit {op!r}')

    for cat_id, titles in data['topics'].items():
        for title, tl in titles.items():
            topic_of(cat_id, title)['tagalog'] = tl

    for cat_id, terms in data['terms'].items():
        signs = {s['term']: s for t in by_id[cat_id]['topics'] for s in t['signs']}
        for term, tl in terms.items():
            if term not in signs:
                raise SystemExit(f'tagalog.json: no sign {term!r} in {cat_id}')
            signs[term]['tagalog'] = tl


main()
