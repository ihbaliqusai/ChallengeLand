// Resize oversized shipped UI assets. Design originals are retained outside APKs.
const fs = require('node:fs');
const path = require('node:path');
const {execFileSync} = require('node:child_process');
const {root, dimensions, shippedAssets} = require('./artwork_inventory.cjs');
const encoder = process.env.FFMPEG || 'C:/Program Files (x86)/CoolerMaster/MasterPlus/ffmpeg.exe';
const report = [];
for (const asset of shippedAssets()) {
  if (!/\.(webp|png)$/i.test(asset)) continue;
  let cap;
  if (/^assets\/store\//.test(asset)) {
    cap = /membership|champions_club_preview|navigation/.test(asset) ? 1600 :
      /offer_/.test(asset) ? 1200 : 768;
  } else if (/^assets\/home\//.test(asset)) {
    cap = /keys|tickets/.test(asset) ? 512 : 768;
  } else if (/^assets\/ui\/(home_menu|game_modes|weekly_reward)/.test(asset)) cap = 1600;
  else if (asset === 'assets/ui/play_stake_dialog.png') cap = 1024;
  else continue;
  const target = path.join(root, asset);
  const beforeSize = dimensions(target);
  if (Math.max(...beforeSize) <= cap) continue;
  const backup = path.join(root, 'tools/design_sources/lightness', asset);
  fs.mkdirSync(path.dirname(backup), {recursive: true});
  if (!fs.existsSync(backup)) fs.copyFileSync(target, backup);
  // Use the original lossless PNG when it is available, rather than recompressing.
  const png = target.replace(/\.webp$/, '.png');
  const source = asset.endsWith('.webp') && fs.existsSync(png) ? png : backup;
  const original = dimensions(source);
  const ratio = Math.min(1, cap / Math.max(...original));
  const width = Math.round(original[0] * ratio), height = Math.round(original[1] * ratio);
  const output = target.replace(/(\.[^.]+)$/, '.resized$1');
  const args = ['-v', 'error', '-y', '-i', source, '-vf', `scale=${width}:${height}:flags=lanczos`, '-frames:v', '1', '-threads', '1'];
  args.push(...(asset.endsWith('.webp') ? ['-c:v', 'libwebp', '-lossless', '1', '-compression_level', '6'] : ['-c:v', 'png', '-compression_level', '9']));
  execFileSync(encoder, [...args, output], {stdio: 'pipe'});
  const entry = {asset, before: beforeSize, after: dimensions(output), beforeBytes: fs.statSync(target).size, afterBytes: fs.statSync(output).size};
  // Windows image previews can retain a handle without FILE_SHARE_DELETE.
  fs.copyFileSync(output, target);
  fs.unlinkSync(output);
  report.push(entry);
  console.log(`${asset}: ${beforeSize.join('x')} -> ${entry.after.join('x')}`);
}
fs.mkdirSync(path.join(root, 'build/lightness-audit'), {recursive: true});
fs.writeFileSync(path.join(root, 'build/lightness-audit/image-optimization.json'), JSON.stringify(report, null, 2));
console.log(`Resized ${report.length} assets; saved ${(report.reduce((sum, item) => sum + item.beforeBytes - item.afterBytes, 0) / 1048576).toFixed(2)} MiB.`);
