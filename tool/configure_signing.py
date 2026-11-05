#!/usr/bin/env python3
"""Write private Gradle signing settings from Codemagic's secret environment."""
import os,pathlib
mapping={'storeFile':'CM_KEYSTORE_PATH','storePassword':'CM_KEYSTORE_PASSWORD','keyAlias':'CM_KEY_ALIAS','keyPassword':'CM_KEY_PASSWORD'}
def escape(value):
 return value.replace('\\','\\\\').replace('\n','\\n').replace('\r','\\r').replace('=','\\=').replace(':','\\:').replace(' ','\\ ')
values={k:os.environ[v] for k,v in mapping.items()}
if not pathlib.Path(values['storeFile']).is_file():raise SystemExit('Signing keystore not found')
p=pathlib.Path('android/key.properties')
p.write_text('\n'.join(k+'='+escape(v) for k,v in values.items())+'\n');p.chmod(0o600)
print('Release signing configured. Credentials were not printed.')
