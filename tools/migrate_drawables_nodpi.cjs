const fs = require('node:fs');
const path = require('node:path');
const {execFileSync} = require('node:child_process');

const root = path.resolve(__dirname, '..');
const drawableDir = path.join(root, 'android/app/src/main/res/drawable');
const nodpiDir = path.join(root, 'android/app/src/main/res/drawable-nodpi');
const unusedDir = path.join(root, 'tools/design_sources/unused_drawables');
const sharedAssetsPath = path.join(__dirname, 'shared_assets.json');

fs.mkdirSync(nodpiDir, {recursive: true});
fs.mkdirSync(unusedDir, {recursive: true});

// 1. Move dead unused files from nodpi to design_sources
const unusedFiles = [
  'bg_versus_split_texture.png',
  'bg_split_left_purple.png',
  'bg_split_right_orange.png',
  'bg_stake_prize_banner.png'
];
for (const file of unusedFiles) {
  const src = path.join(nodpiDir, file);
  if (fs.existsSync(src)) {
    const dest = path.join(unusedDir, file);
    fs.copyFileSync(src, dest);
    fs.unlinkSync(src);
    console.log(`Moved unused file to backup: ${file}`);
  }
}

// 2. Identify heavy drawables to move to drawable-nodpi
const filesToMove = [
  'bg_game2.png',
  'bg_main.png',
  'bg_challenge_cosmic.jpg',
  'board.png',
  'board1.png',
  'podium.png',
  'podiumhost.png',
  'img_empty_swords.png',
  'img_empty_trophy.png'
];

// Add contestant files
for (const file of fs.readdirSync(drawableDir)) {
  if (/^(contestant_|game_contestant_)/i.test(file)) {
    filesToMove.push(file);
  }
}

console.log(`Moving ${filesToMove.length} files to drawable-nodpi...`);
for (const file of filesToMove) {
  const src = path.join(drawableDir, file);
  const dest = path.join(nodpiDir, file);
  if (fs.existsSync(src)) {
    fs.copyFileSync(src, dest);
    fs.unlinkSync(src);
    console.log(`Moved: ${file}`);
  }
}

// 3. Update shared_assets.json mappings
const shared = JSON.parse(fs.readFileSync(sharedAssetsPath, 'utf8'));
let updatedCount = 0;
for (const [key, val] of Object.entries(shared)) {
  if (val.startsWith('android/app/src/main/res/drawable/')) {
    const filename = path.basename(val);
    if (filesToMove.includes(filename)) {
      shared[key] = `android/app/src/main/res/drawable-nodpi/${filename}`;
      updatedCount++;
    }
  }
}
fs.writeFileSync(sharedAssetsPath, JSON.stringify(shared, null, 2) + '\n');
console.log(`Updated ${updatedCount} paths in shared_assets.json`);

// 4. Regenerate code
execFileSync(process.execPath, [path.join(__dirname, 'prepare_shared_assets.cjs')], {stdio: 'inherit'});
execFileSync(process.execPath, [path.join(__dirname, 'artwork_inventory.cjs')], {stdio: 'inherit'});
console.log('Migration to drawable-nodpi complete.');
