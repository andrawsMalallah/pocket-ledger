(async () => {
  const status = document.getElementById('release-status');
  const button = document.getElementById('apk-download');
  try {
    // A generated script also lets the extracted site work from file://.
    const release = window.PENNY_RELEASE;
    if (!release || !release.available) {
      status.textContent = 'The first Android release is being prepared.';
      return;
    }
    const url = new URL(release.url, location.href);
    const sameLocation = location.protocol === 'file:'
      ? url.protocol === 'file:' && /^downloads\/[^/]+\.apk$/.test(release.url)
      : url.origin === location.origin;
    if (!sameLocation || !url.pathname.endsWith('.apk') ||
        !/^\d+\.\d+\.\d+$/.test(release.version) ||
        !/^[a-f0-9]{64}$/.test(release.sha256) ||
        !Number.isSafeInteger(release.bytes) || release.bytes <= 0) {
      throw Error('Invalid release');
    }
    // Browsers generally block fetch/HEAD on local files. On a server, verify
    // the APK exists before displaying its download button.
    if (location.protocol !== 'file:') {
      const check = await fetch(url, {method: 'HEAD', cache: 'no-store'});
      if (!check.ok) throw Error('Missing APK');
    }
    status.textContent = 'Ready for your phone.';
    document.getElementById('release-detail').textContent =
      `Version ${release.version} · ${(release.bytes / 1048576).toFixed(1)} MB`;
    button.href = url.href;
    button.hidden = false;
    document.getElementById('checksum').textContent = release.sha256;
    document.getElementById('checksum-panel').hidden = false;
  } catch (_) {
    status.textContent = 'The download is not available yet. Please check again later.';
    button.hidden = true;
  }
})();
