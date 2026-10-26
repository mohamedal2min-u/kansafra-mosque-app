#!/usr/bin/env python3
"""يجلب «التفسير الميسّر» (مجمع الملك فهد لطباعة المصحف الشريف) ويحفظه في assets/tafsir/muyassar.json
بصيغة [[نص تفسير آيات السورة 1], [السورة 2], ...] ليعمل في التطبيق بدون إنترنت.
المصدر الأول: api.alquran.cloud (edition ar.muyassar)، والاحتياطي: tanzil.net. يتحقق من 114 سورة و6236 آية.
"""
import json, os, sys, urllib.request

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'assets', 'tafsir', 'muyassar.json')


def get(url):
    req = urllib.request.Request(url, headers={'User-Agent': 'KansafraMosqueApp/1.0'})
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read().decode('utf-8')


def from_alquran_cloud():
    j = json.loads(get('https://api.alquran.cloud/v1/quran/ar.muyassar'))
    return [[a['text'].strip() for a in s['ayahs']] for s in j['data']['surahs']]


def from_tanzil():
    txt = get('https://tanzil.net/trans/?transID=ar.muyassar&type=txt-2')
    surahs = [[] for _ in range(114)]
    for line in txt.splitlines():
        parts = line.split('|', 2)
        if len(parts) == 3 and parts[0].isdigit():
            surahs[int(parts[0]) - 1].append(parts[2].strip())
    return surahs


def valid(s):
    return len(s) == 114 and sum(len(x) for x in s) == 6236 and all(t for x in s for t in x)


data = None
for f in (from_alquran_cloud, from_tanzil):
    try:
        d = f()
        if valid(d):
            data = d
            print('OK from', f.__name__)
            break
        print('invalid data from', f.__name__, len(d), sum(len(x) for x in d))
    except Exception as e:
        print('failed', f.__name__, e)
if data is None:
    sys.exit('no valid tafsir source')
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, 'w', encoding='utf-8') as fh:
    json.dump(data, fh, ensure_ascii=False, separators=(',', ':'))
print('wrote', OUT, os.path.getsize(OUT), 'bytes')
