import json, pathlib, subprocess, tempfile, unittest, zipfile, hashlib
SCRIPT=pathlib.Path(__file__).resolve().parents[1]/'prepare_release.py'
class ReleaseTest(unittest.TestCase):
 def test_rejects_non_apk_and_does_not_enable_download(self):
  with tempfile.TemporaryDirectory() as tmp:
   p=pathlib.Path(tmp);bad=p/'file.txt';bad.write_text('not an apk')
   r=subprocess.run(['python3',str(SCRIPT),str(bad),'--version','1.0.0','--destination',str(p/'web')],capture_output=True)
   self.assertNotEqual(r.returncode,0);self.assertFalse((p/'web/release.json').exists())
 def test_release_manifest_matches_copied_bytes(self):
  with tempfile.TemporaryDirectory() as tmp:
   p=pathlib.Path(tmp);apk=p/'fixture.apk'
   with zipfile.ZipFile(apk,'w') as z:z.writestr('AndroidManifest.xml','test fixture');z.writestr('lib/arm64-v8a/libflutter.so','test fixture')
   subprocess.run(['python3',str(SCRIPT),str(apk),'--version','1.0.0','--destination',str(p/'web')],check=True,capture_output=True)
   data=json.loads((p/'web/release.json').read_text());target=p/'web'/data['url']
   self.assertEqual(data['sha256'],hashlib.sha256(target.read_bytes()).hexdigest());self.assertEqual(data['bytes'],target.stat().st_size);self.assertTrue(data['available'])
   js=(p/'web/release-data.js').read_text()
   self.assertEqual(json.loads(js.removeprefix('window.PENNY_RELEASE = ').removesuffix(';\n')),data)
if __name__=='__main__':unittest.main()
