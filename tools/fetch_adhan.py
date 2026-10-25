#!/usr/bin/env python3
"""يجلب تسجيلات أذان مرخَّصة بحرية من واجهة Internet Archive ويضيفها للتطبيق.

- يقبل فقط ما ترخيصه في بيانات الملف: CC0 أو Public Domain Mark أو CC BY أو CC BY-SA
  (لا NC ولا ND، فالتعديل بالقص والتطبيع مطلوب والتطبيق قد يُوزَّع تجاريًا).
- يحوّل كل تسجيل إلى نسخة قصيرة (أول ~25 ثانية) mp3 أحادي 64 كيلوبت مع تطبيع الصوت.
- يكتب assets/adhan/ وandroid/app/src/main/res/raw/ وlib/adhan_extra.g.dart وتقرير tools/adhan_report.md.
يحتاج ffmpeg وإنترنت. الاستخدام: python3 tools/fetch_adhan.py [العدد=30]
"""
import json, os, re, subprocess, sys, tempfile, urllib.parse, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET = int(sys.argv[1]) if len(sys.argv) > 1 else 30
FIRST_ID = 11  # v1..v4 مستعملة
SHORT_SECONDS = 25
PER_ITEM = 4

OK_LICENSE = re.compile(r'creativecommons\.org/(publicdomain/(zero|mark)/|licenses/by(-sa)?/)', re.I)
BAD_TITLE = re.compile(r'quran|قرآن|قران|dua|دعاء|tarawih|تراويح|khutba|خطبة|lecture|nasheed|نشيد|iqama|إقامة|ringtone|remix|music', re.I)
# لا نقبل وسم الترخيص وحده: أذان مشاهير القرّاء والمؤذنين محمي حتى لو وسمه الرافع «ملكية عامة».
BLOCKED = re.compile(r'ear of the rat|desnia|mish|afasy|alafasy|misyari|rasyid|سريحي|surehi|sarihi|firebladetw|alqurantranslation|'
                     r'commentary|نور على الدرب|faedahislam|herbst|hussary|الحصري|minshawi|المنشاوي|basit|عبد الباسط|refaat|'
                     r'qatami|القطامي|ghamdi|الغامدي|sudais|السديس|shuraim|الشريم|nasser|toubar|طوبار', re.I)
IS_ADHAN = re.compile(r'adhan|azan|azaan|adzan|athan|adan|أذان|اذان', re.I)
AUDIO_FORMATS = {'vbr mp3', 'mp3', '128kbps mp3', '64kbps mp3', '192kbps mp3', '256kbps mp3', '320kbps mp3',
                 'ogg vorbis', 'flac', 'wave', '24bit flac', 'opus', 'mpeg audio', 'm4a', 'aac'}


def get(url, binary=False):
    req = urllib.request.Request(url, headers={'User-Agent': 'KansafraMosqueApp-adhan-fetch/1.0'})
    with urllib.request.urlopen(req, timeout=120) as r:
        data = r.read()
    return data if binary else json.loads(data)


def search():
    q = '(adhan OR azan OR athan OR adzan OR azaan OR أذان) AND mediatype:audio'
    out, page = [], 1
    while page <= 4:
        qs = urllib.parse.urlencode(
            [('q', q), ('fl[]', 'identifier'), ('fl[]', 'title'), ('fl[]', 'creator'), ('fl[]', 'licenseurl'),
             ('rows', 200), ('page', page), ('output', 'json')])
        docs = get('https://archive.org/advancedsearch.php?' + qs)['response']['docs']
        if not docs:
            break
        out += docs
        page += 1
    print(f'found {len(out)} candidate items')
    return out


def lic_short(url):
    m = re.search(r'creativecommons\.org/(publicdomain/(zero|mark)|licenses/(by(?:-sa)?))/([\d.]+)', url)
    if not m:
        return 'CC'
    if m.group(2) == 'zero':
        return 'CC0'
    if m.group(2) == 'mark':
        return 'Public Domain'
    return 'CC ' + m.group(3).upper() + ' ' + m.group(4)


def dart(s):
    return s.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$').replace('\n', ' ')


def clean_name(s):
    s = re.sub(r'\.(mp3|ogg|flac|wav|m4a|opus)$', '', s, flags=re.I)
    s = re.sub(r'[_]+', ' ', s)
    s = re.sub(r'\s+', ' ', s).strip(' -')
    return s[:42]


def main():
    cands = []
    for d in search():
        lic = d.get('licenseurl') or ''
        if isinstance(lic, list):
            lic = lic[0] if lic else ''
        if not OK_LICENSE.search(lic):
            continue
        if BAD_TITLE.search(str(d.get('title', ''))) or BLOCKED.search(f"{d.get('title', '')} {d.get('creator', '')} {d['identifier']}"):
            continue
        cands.append((d['identifier'], str(d.get('title', '')), d.get('creator'), lic))
    print(f'{len(cands)} items with an acceptable license')

    chosen = []  # (identifier, itemtitle, creator, lic, filename, filetitle, length)
    for ident, title, creator, lic in cands:
        if len(chosen) >= TARGET * 2:
            break
        try:
            meta = get(f'https://archive.org/metadata/{ident}')
        except Exception as e:
            print('skip', ident, e)
            continue
        n = 0
        seen_len = set()
        for f in meta.get('files', []):
            if n >= PER_ITEM:
                break
            if f.get('source') != 'original' or str(f.get('format', '')).lower() not in AUDIO_FORMATS:
                continue
            try:
                length = float(f.get('length', 0))
            except ValueError:
                continue
            name = f['name']
            ftitle = f.get('title') or name
            if BAD_TITLE.search(ftitle) or BAD_TITLE.search(name) or BLOCKED.search(f'{ftitle} {name}'):
                continue
            if not IS_ADHAN.search(f'{ftitle} {name} {title} {ident}'):
                continue
            # نفس التسجيل بصيغ متعددة (mp3/ogg) يأتي بطول متقارب: نأخذ واحدًا.
            if int(length) // 3 in seen_len:
                continue
            seen_len.add(int(length) // 3)
            # أذان كامل ≈ دقيقة إلى 6 دقائق؛ ما عداه غالبًا ليس أذانًا.
            if not 50 <= length <= 400:
                continue
            chosen.append((ident, title, creator, lic, name, ftitle, length))
            n += 1
    print(f'{len(chosen)} files selected before conversion')

    raw_dir = os.path.join(ROOT, 'android/app/src/main/res/raw')
    asset_dir = os.path.join(ROOT, 'assets/adhan')
    done, rows = [], []
    with tempfile.TemporaryDirectory() as tmp:
        for ident, title, creator, lic, name, ftitle, length in chosen:
            if len(done) >= TARGET:
                break
            vid = FIRST_ID + len(done)
            src = os.path.join(tmp, 'src_' + re.sub(r'[^A-Za-z0-9.]', '_', name))
            try:
                url = f'https://archive.org/download/{ident}/' + urllib.parse.quote(name)
                with open(src, 'wb') as fh:
                    fh.write(get(url, binary=True))
                out = os.path.join(tmp, f'adhan_v{vid}_short.mp3')
                subprocess.run(
                    ['ffmpeg', '-v', 'error', '-y', '-i', src, '-t', str(SHORT_SECONDS + 20), '-ac', '1', '-ar', '44100',
                     '-af', 'silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.2,'
                            'loudnorm=I=-16:TP=-1.5:LRA=11,'
                            f'atrim=0:{SHORT_SECONDS},afade=t=out:st={SHORT_SECONDS - 1.5}:d=1.5',
                     '-c:a', 'libmp3lame', '-b:a', '64k', out],
                    check=True)
                if os.path.getsize(out) < 40_000:
                    raise RuntimeError('too small after conversion')
            except Exception as e:
                print('FAILED', ident, name, e)
                continue
            for d in (asset_dir, raw_dir):
                os.makedirs(d, exist_ok=True)
                with open(out, 'rb') as a, open(os.path.join(d, f'adhan_v{vid}_short.mp3'), 'wb') as b:
                    b.write(a.read())
            label = clean_name(ftitle if ftitle != name else title) or clean_name(title) or f'مؤذن {vid}'
            who = (creator[0] if isinstance(creator, list) else creator) or 'Internet Archive'
            credit = f'{who} - {lic_short(lic)} (archive.org/details/{ident})'
            done.append(('voice%d' % vid, 'v%d' % vid, label, credit))
            rows.append((vid, label, who, lic_short(lic), f'https://archive.org/details/{ident}', int(length)))
            print('OK', vid, label, lic_short(lic))

    with open(os.path.join(ROOT, 'lib/adhan_extra.g.dart'), 'w', encoding='utf-8') as f:
        f.write('// مولَّد بواسطة tools/fetch_adhan.py (لا تعدّله يدويًا).\n'
                "// كل عنصر: [المعرّف, الاسم الخام, الاسم المعروض, الترخيص والمصدر, '1' إن دخل الوضع التلقائي].\n"
                'const extraAdhanData = <List<String>>[\n')
        for vid, raw, name, credit in done:
            f.write(f"  ['{vid}', '{raw}', '{dart(name)}', '{dart(credit)}', '1'],\n")
        f.write('];\n')

    with open(os.path.join(ROOT, 'tools/adhan_report.md'), 'w', encoding='utf-8') as f:
        f.write('# تقرير الأذان المضاف آليًا\n\n| # | الاسم | المؤلف | الترخيص | المصدر | مدة الأصل (ث) |\n|---|---|---|---|---|---|\n')
        for r in rows:
            f.write('| v%d | %s | %s | %s | %s | %d |\n' % r)
    with open(os.path.join(asset_dir, 'CREDITS.md'), 'a', encoding='utf-8') as f:
        f.write('\n## مضاف آليًا من Internet Archive (tools/fetch_adhan.py)\n\nالنسخ القصيرة فقط (أول %d ثانية، mp3 أحادي، تطبيع للصوت). التفاصيل في tools/adhan_report.md.\n' % SHORT_SECONDS)
    print(f'DONE: {len(done)} voices')
    if not done:
        sys.exit(1)


if __name__ == '__main__':
    main()
