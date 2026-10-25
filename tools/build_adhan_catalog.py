#!/usr/bin/env python3
"""يبني كتالوج الأذان الأونلاين من مجلد تسجيلات كاملة.

الاستخدام: python3 tools/build_adhan_catalog.py <مجلد التسجيلات> [مجلد-خرج=docs/adhan]
- يستبعد الرديء (معدل بت < 64 كيلوبت، أو معدل عيّنة < 32 كيلوهرتز، أو مدة خارج 45–480 ثانية).
- يحوّل كل تسجيل إلى مقطع أول 30 ثانية: mp3 أحادي 64 كيلوبت، مع قصّ الصمت الأول وتطبيع الصوت.
- يكتب catalog.json (يُقرأ من التطبيق) بجانب المقاطع.
يحتاج ffmpeg وffprobe.
"""
import concurrent.futures as cf, glob, json, os, re, subprocess, sys

SRC = sys.argv[1]
OUT = sys.argv[2] if len(sys.argv) > 2 else 'docs/adhan'
SECONDS = 30
os.makedirs(OUT, exist_ok=True)


def probe(f):
    r = subprocess.run(['ffprobe', '-v', 'error', '-select_streams', 'a:0', '-show_entries',
                        'stream=bit_rate,sample_rate:format=duration,bit_rate', '-of', 'json', f],
                       capture_output=True, text=True)
    try:
        j = json.loads(r.stdout)
        s, fm = j['streams'][0], j['format']
        return float(fm['duration']), int(s.get('bit_rate') or fm.get('bit_rate') or 0) // 1000, int(s['sample_rate'])
    except Exception:
        return None


def display(stem):
    m = re.search(r'\(([^)]*[؀-ۿ][^)]*)\)', stem)
    if m:
        return m.group(1).replace('_', ' ').strip()
    ar = re.sub(r'[A-Za-z0-9_\-]+', ' ', stem).strip()
    return ar or stem.replace('_', ' ').strip()


def convert(args):
    idx, f = args
    out = os.path.join(OUT, 'a%03d.mp3' % idx)
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', f, '-t', str(SECONDS + 20), '-vn', '-ac', '1', '-ar', '44100',
                    '-af', 'silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.2,'
                           'loudnorm=I=-16:TP=-1.5:LRA=11,'
                           f'atrim=0:{SECONDS},afade=t=out:st={SECONDS - 1.5}:d=1.5',
                    '-c:a', 'libmp3lame', '-b:a', '64k', out], check=True)
    return out


files = []
for f in sorted(glob.glob(os.path.join(SRC, '*.mp3'))):
    p = probe(f)
    if p and p[1] >= 64 and p[2] >= 32000 and 45 <= p[0] <= 480:
        files.append((f, p))
print(len(files), 'files pass the quality filter')

with cf.ThreadPoolExecutor(4) as ex:
    list(ex.map(convert, [(i + 1, f) for i, (f, _) in enumerate(files)]))

cat = []
for i, (f, p) in enumerate(files):
    stem = os.path.splitext(os.path.basename(f))[0]
    out = os.path.join(OUT, 'a%03d.mp3' % (i + 1))
    cat.append({
        'id': 'a%03d' % (i + 1),
        'name': display(stem),
        'file': 'a%03d.mp3' % (i + 1),
        'fajr': bool(re.search(r'fajr|فجر|الفجر', stem, re.I)),
        'bytes': os.path.getsize(out),
    })
# أسماء مكررة لنفس المؤذن (تسجيلات متعددة): نضيف رقمًا ليتميّز كل واحد.
seen = {}
for v in cat:
    seen[v['name']] = seen.get(v['name'], 0) + 1
count = {}
for v in cat:
    if seen[v['name']] > 1:
        count[v['name']] = count.get(v['name'], 0) + 1
        v['name'] = '%s (%d)' % (v['name'], count[v['name']])
with open(os.path.join(OUT, 'catalog.json'), 'w', encoding='utf-8') as fh:
    json.dump({'version': 1, 'seconds': SECONDS, 'voices': cat}, fh, ensure_ascii=False, indent=1)
print('done', len(cat))
