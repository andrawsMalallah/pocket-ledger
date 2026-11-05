#!/usr/bin/env python3
"""Publish an existing APK into the static landing directory; never builds an APK."""
import argparse, hashlib, json, pathlib, re, shutil, zipfile
p=argparse.ArgumentParser()
p.add_argument('apk',type=pathlib.Path)
p.add_argument('--version',required=True)
p.add_argument('--destination',type=pathlib.Path,default=pathlib.Path('landing'))
a=p.parse_args()
if not re.fullmatch(r'\d+\.\d+\.\d+',a.version): p.error('Version must look like 1.0.0')
if not a.apk.is_file() or a.apk.suffix.lower()!='.apk': p.error('Provide an existing APK')
with zipfile.ZipFile(a.apk) as z:
 if 'AndroidManifest.xml' not in z.namelist() or not any(n.startswith('lib/') and n.endswith('/libflutter.so') for n in z.namelist()): p.error('Not a Flutter Android APK')
target=a.destination/'downloads'/f'pocket-ledger-{a.version}.apk'
target.parent.mkdir(parents=True,exist_ok=True)
if a.apk.resolve()!=target.resolve(): shutil.copyfile(a.apk,target)
metadata={'available':True,'version':a.version,'url':f'downloads/{target.name}','bytes':target.stat().st_size,'sha256':hashlib.file_digest(target.open('rb'),'sha256').hexdigest()}
(a.destination/'release.json').write_text(json.dumps(metadata,indent=2)+'\n')
print(f'Release ready: {target} ({metadata["bytes"]} bytes)')
