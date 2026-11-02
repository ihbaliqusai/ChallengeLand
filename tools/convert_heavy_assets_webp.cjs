const fs = require('node:fs');
const path = require('node:path');
const {execFileSync} = require('node:child_process');

const root = path.resolve(__dirname, '..');
const encoder = 'C:/Program Files (x86)/CoolerMaster/MasterPlus/ffmpeg.exe';

const tasks = [
  {src: 'assets/home/lobby_background.png', dest: 'assets/home/lobby_background.webp', maxDim: 1920, quality: 86},
  {src: 'assets/ui/splash_background.png', dest: 'assets/ui/splash_background.webp', maxDim: 1920, quality: 86},
  {src: 'assets/social/invite_friends_hero.png', dest: 'assets/social/invite_friends_hero.webp', maxDim: 1600, quality: 88},
  {src: 'assets/images/campaign/ui/victory_background.jpg', dest: 'assets/images/campaign/ui/victory_background.webp', maxDim: 1920, quality: 86},
  {src: 'assets/images/campaign/ui/victory_panel.png', dest: 'assets/images/campaign/ui/victory_panel.webp', maxDim: 1600, quality: 88},
  {src: 'assets/social/friends_challenges.jfif', dest: 'assets/social/friends_challenges.webp', maxDim: 1920, quality: 86},
  {src: 'assets/ui/play_stake_dialog.png', dest: 'assets/ui/play_stake_dialog.webp', maxDim: 1024, quality: 90},
  {src: 'assets/ui/splash_presenter.png', dest: 'assets/ui/splash_presenter.webp', maxDim: 1400, quality: 90},
  {src: 'assets/ui/splash_logo.png', dest: 'assets/ui/splash_logo.webp', maxDim: 1200, quality: 90},
  {src: 'assets/ui/million_challenge_logo.png', dest: 'assets/ui/million_challenge_logo.webp', maxDim: 512, quality: 90}
];

let totalOriginalBytes = 0;
let totalWebpBytes = 0;

for (const t of tasks) {
  const fullSrc = path.join(root, t.src);
  const fullDest = path.join(root, t.dest);
  if (!fs.existsSync(fullSrc)) {
    console.warn(`Source missing: ${t.src}`);
    continue;
  }
  const originalSize = fs.statSync(fullSrc).size;
  totalOriginalBytes += originalSize;

  // Backup original
  const backup = path.join(root, 'tools/design_sources/backup_prompt1', t.src);
  fs.mkdirSync(path.dirname(backup), {recursive: true});
  if (!fs.existsSync(backup)) {
    fs.copyFileSync(fullSrc, backup);
  }

  // Convert via ffmpeg
  const args = [
    '-v', 'error', '-y',
    '-i', fullSrc,
    '-vf', `scale='min(${t.maxDim},iw)':-1:flags=lanczos`,
    '-c:v', 'libwebp',
    '-quality', String(t.quality),
    fullDest
  ];
  execFileSync(encoder, args);

  const newSize = fs.statSync(fullDest).size;
  totalWebpBytes += newSize;
  console.log(`Converted ${t.src} (${Math.round(originalSize / 1024)} KB) -> ${t.dest} (${Math.round(newSize / 1024)} KB) [Saved ${Math.round((originalSize - newSize) / 1024)} KB]`);
}

console.log(`\nTOTAL ORIGINAL: ${(totalOriginalBytes / (1024*1024)).toFixed(2)} MB`);
console.log(`TOTAL WEBP: ${(totalWebpBytes / (1024*1024)).toFixed(2)} MB`);
console.log(`TOTAL SAVED: ${((totalOriginalBytes - totalWebpBytes) / (1024*1024)).toFixed(2)} MB (${((1 - totalWebpBytes/totalOriginalBytes)*100).toFixed(1)}% reduction!)`);
