const windowsPattern = /win-x64\.zip$/i;
const macPattern = /macos-universal\.(dmg|zip)$/i;

export function selectPublicReleases(all) {
  const stable = all.filter(r => !r.draft && !r.prerelease && r.published_at && /^v\d+\.\d+\.\d+$/.test(r.tag_name))
    .sort((a, b) => Date.parse(b.published_at) - Date.parse(a.published_at));
  const windows = stable.find(r => r.assets?.some(a => windowsPattern.test(a.name)));
  if (!windows) throw new Error('Missing published Windows x64 release');
  const mac = stable.find(r => r.assets?.some(a => macPattern.test(a.name)));
  return {
    stable, windows, mac,
    windowsAsset: windows.assets.find(a => windowsPattern.test(a.name)),
    macAsset: mac?.assets.find(a => /macos-universal\.dmg$/i.test(a.name)) || mac?.assets.find(a => macPattern.test(a.name))
  };
}
