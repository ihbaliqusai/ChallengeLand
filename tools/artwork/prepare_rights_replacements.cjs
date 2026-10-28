const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { execFileSync } = require('node:child_process');

const root = path.resolve(__dirname, '../..');
const sourceDirectory = path.join(__dirname, 'source');
const ffmpeg = process.env.CHALLENGELAND_FFMPEG
  || 'C:/Program Files (x86)/CoolerMaster/MasterPlus/ffmpeg.exe';
const hash = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const entries = [
  { source: 'quiz_gem_generated.png', target: 'assets/ui/million_challenge_logo.png', size: 512 },
  { source: 'noura_owl_generated.png', target: 'android/app/src/main/res/drawable/avatar13.png', size: 256 },
];
for (const entry of entries) {
  const source = path.join(sourceDirectory, entry.source);
  const target = path.join(root, entry.target);
  execFileSync(ffmpeg, ['-hide_banner', '-loglevel', 'error', '-y', '-i', source,
    '-vf', `scale=${entry.size}:${entry.size}:flags=lanczos`,
    '-frames:v', '1', '-compression_level', '9', target], { stdio: 'inherit' });
  const data = fs.readFileSync(target);
  if (data.readUInt32BE(16) !== entry.size || data.readUInt32BE(20) !== entry.size) {
    throw new Error(`Unexpected replacement dimensions: ${entry.target}`);
  }
  console.log(JSON.stringify({ target: entry.target, width: entry.size, height: entry.size,
    bytes: data.length, sha256: hash(target), sourceSha256: hash(source) }));
}
