// Replaces only supplied idle clips. Reaction videos and artwork stay unchanged.
// Usage: node tools/characters/update_idle_videos.cjs <source-directory>
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {execFileSync, spawnSync} = require('node:child_process');

const root = path.resolve(__dirname, '../..');
const sourceDirectory = process.argv[2];
if (!sourceDirectory || !fs.statSync(sourceDirectory).isDirectory()) {
  throw new Error('Pass the directory containing video_main<number>.mp4 files.');
}
const ffmpeg = process.env.FFMPEG || 'C:/Program Files (x86)/CoolerMaster/MasterPlus/ffmpeg.exe';
const pack = JSON.parse(fs.readFileSync(path.join(__dirname, 'pack.json'), 'utf8'));
const raw = path.join(root, 'android/app/src/main/res/raw');
const staging = path.join(root, 'build/character-idle-update');
const backups = path.join(staging, 'previous');
fs.mkdirSync(backups, {recursive: true});
const hash = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const previous = Object.fromEntries(fs.readdirSync(raw).filter(name => name.endsWith('.mp4'))
  .map(name => [name, hash(path.join(raw, name))]));
const jobs = pack.filter(character => fs.existsSync(path.join(sourceDirectory, `video_main${character.source}.mp4`)));
if (!jobs.length) throw new Error('No supplied clips match the character catalog.');
for (const name of fs.readdirSync(sourceDirectory).filter(name => /^video_main\d+\.mp4$/i.test(name))) {
  if (!pack.some(character => name === `video_main${character.source}.mp4`)) {
    throw new Error('Unmapped source clip: ' + name);
  }
}
const report = {settings: {codec: 'h264', profile: 'Main', width: 540, height: 960,
  crf: 25, preset: 'slow', pixelFormat: 'yuv420p', audio: false}, clips: [],
  unchangedCharacters: pack.filter(character => !jobs.includes(character)).map(character => character.id)};

function inspect(file) {
  const info = spawnSync(ffmpeg, ['-hide_banner', '-i', file], {encoding: 'utf8'}).stderr;
  const video = info.split('\n').find(line => /Stream.*Video:/.test(line));
  if (!video) throw new Error('No video stream: ' + file);
  return {video: video.trim(), duration: info.match(/Duration:\s*([\d:.]+)/)?.[1],
    audio: /Stream.*Audio:/.test(info)};
}

for (const character of jobs) {
  const source = path.join(sourceDirectory, `video_main${character.source}.mp4`);
  const name = `video_${character.id}.mp4`;
  const staged = path.join(staging, name);
  const target = path.join(raw, name);
  const sourceInfo = inspect(source);
  if (!/720x1280/.test(sourceInfo.video) || !/24 fps/.test(sourceInfo.video)) {
    throw new Error('Inspect unexpected source dimensions/frame rate before importing: ' + source);
  }
  execFileSync(ffmpeg, ['-v', 'error', '-y', '-i', source, '-map', '0:v:0', '-an',
    '-vf', 'scale=540:960:flags=lanczos,setsar=1', '-c:v', 'libx264', '-preset', 'slow',
    '-crf', '25', '-pix_fmt', 'yuv420p', '-profile:v', 'main', '-level:v', '3.1',
    '-movflags', '+faststart', '-map_metadata', '-1', staged], {stdio: 'pipe'});
  // Full decode both clips: catches truncation and verifies that no frames are lost.
  const frames = file => {
    const result = spawnSync(ffmpeg, ['-v', 'error', '-i', file, '-map', '0:v:0', '-an',
      '-progress', 'pipe:1', '-f', 'null', '-'], {encoding: 'utf8'});
    if (result.status !== 0 || result.stderr.trim()) throw new Error('Decode failed: ' + file + '\n' + result.stderr);
    const counts = [...result.stdout.matchAll(/^frame=(\d+)/gm)];
    if (!counts.length) throw new Error('No decoded frames: ' + file);
    return Number(counts[counts.length - 1][1]);
  };
  const sourceFrames = frames(source), outputFrames = frames(staged);
  if (sourceFrames !== outputFrames) throw new Error('Frame count changed: ' + name);
  const outputInfo = inspect(staged);
  if (outputInfo.audio || !/540x960/.test(outputInfo.video) || !/24 fps/.test(outputInfo.video)) {
    throw new Error('Unexpected encoded format: ' + name);
  }
  const sourceBytes = fs.statSync(source).size, outputBytes = fs.statSync(staged).size;
  if (outputBytes >= sourceBytes || outputBytes > 2 * 1024 * 1024) throw new Error('Compression target missed: ' + name);
  report.clips.push({character: character.id, nameAr: character.name, source: path.basename(source),
    output: `android/app/src/main/res/raw/${name}`, sourceBytes, outputBytes,
    previousBytes: fs.statSync(target).size, sourceSha256: hash(source),
    previousSha256: previous[name], outputSha256: hash(staged), sourceFrames, outputFrames,
    sourceInfo, outputInfo});
  console.log(`${character.id}: ${(sourceBytes / 1048576).toFixed(2)} -> ${(outputBytes / 1048576).toFixed(2)} MiB; ${outputFrames} frames verified.`);
}
// Accept the replacements only after every supplied clip passes validation.
for (const clip of report.clips) {
  const name = path.basename(clip.output), target = path.join(raw, name), backup = path.join(backups, name);
  if (!fs.existsSync(backup)) fs.copyFileSync(target, backup);
  fs.copyFileSync(path.join(staging, name), target);
  if (hash(target) !== clip.outputSha256) throw new Error('Copy verification failed: ' + name);
  if (hash(path.join(sourceDirectory, clip.source)) !== clip.sourceSha256) throw new Error('Source changed during import: ' + clip.source);
}
for (const [name, checksum] of Object.entries(previous)) {
  if (!report.clips.some(clip => path.basename(clip.output) === name) && hash(path.join(raw, name)) !== checksum) {
    throw new Error('An unrelated video changed: ' + name);
  }
}
report.sourceBytes = report.clips.reduce((sum, clip) => sum + clip.sourceBytes, 0);
report.outputBytes = report.clips.reduce((sum, clip) => sum + clip.outputBytes, 0);
report.savedPercent = 100 * (1 - report.outputBytes / report.sourceBytes);
fs.writeFileSync(path.join(root, 'docs/character_idle_compression.json'), JSON.stringify(report, null, 2) + '\n');
const catalogReportPath = path.join(root, 'docs/character_pack_compression.json');
if (fs.existsSync(catalogReportPath)) {
  const catalogReport = JSON.parse(fs.readFileSync(catalogReportPath, 'utf8').replace(/^\uFEFF/, ''));
  for (const clip of report.clips) {
    const entry = catalogReport.find(item => item.output === clip.output);
    if (!entry) throw new Error('Missing existing catalog report entry: ' + clip.output);
    Object.assign(entry, {source: clip.source, sourceBytes: clip.sourceBytes,
      outputBytes: clip.outputBytes, sourceSha256: clip.sourceSha256.toUpperCase()});
  }
  fs.writeFileSync(catalogReportPath, JSON.stringify(catalogReport, null, 2) + '\n');
}
console.log(`Updated ${report.clips.length} idle clips: ${(report.sourceBytes / 1048576).toFixed(2)} -> ${(report.outputBytes / 1048576).toFixed(2)} MiB (${report.savedPercent.toFixed(2)}% smaller).`);
console.log('Retained existing clips for: ' + report.unchangedCharacters.join(', '));
