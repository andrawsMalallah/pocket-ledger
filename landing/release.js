(async () => {
 const status=document.getElementById('release-status'),button=document.getElementById('apk-download');
 try {
  const response=await fetch('release.json',{cache:'no-store'});
  if(!response.ok)throw Error('No release');
  const release=await response.json();
  if(!release.available){status.textContent='The first Android release is being prepared.';return;}
  const url=new URL(release.url,location.href);
  if(url.origin!==location.origin||!url.pathname.endsWith('.apk')||!/^\d+\.\d+\.\d+$/.test(release.version)||! /^[a-f0-9]{64}$/.test(release.sha256))throw Error('Invalid release');
  const check=await fetch(url,{method:'HEAD',cache:'no-store'});
  if(!check.ok)throw Error('Missing APK');
  status.textContent='Ready for your phone.';
  document.getElementById('release-detail').textContent=`Version ${release.version} · ${(release.bytes/1048576).toFixed(1)} MB`;
  button.href=url.href;button.hidden=false;
  document.getElementById('checksum').textContent=release.sha256;
  document.getElementById('checksum-panel').hidden=false;
 }catch(_){status.textContent='The download is not available yet. Please check again later.';button.hidden=true;}
})();
