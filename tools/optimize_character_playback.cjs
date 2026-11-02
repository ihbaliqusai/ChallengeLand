// Keep every contestant animated. Reduce decoder pixels, never the frame rate.
// Stages and fully decodes every clip before --apply replaces any source file.
// Originals are retained outside packaged resources. Reruns use those originals.
// node tools/optimize_character_playback.cjs [--apply | --verify]
// Optional: --stage <absolute-directory>, CHALLENGELAND_FFMPEG=<executable>
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {spawnSync} = require('node:child_process');

const root = path.resolve(__dirname, '..');
const raw = path.join(root, 'android/app/src/main/res/raw');
const args = process.argv.slice(2);
const stageIndex = args.indexOf('--stage');
const stage = stageIndex < 0 ? path.join(root, 'build/runtime-video-optimization')
  : path.resolve(args[stageIndex + 1]);
if (stage.startsWith(raw + path.sep) || stage === raw) {
  throw new Error('Staging/backups must be outside packaged raw resources.');
}
const ffmpeg = process.env.CHALLENGELAND_FFMPEG
  || 'C:/Program Files (x86)/CoolerMaster/MasterPlus/ffmpeg.exe';
const names = fs.readdirSync(raw).filter(name => /^video_[a-z]+(?:_(?:correct|wrong))?\.mp4$/.test(name)).sort();
if (names.length !== 48) throw new Error(`Expected 16 characters × 3 clips; found ${names.length}.`);
const clips = [...names, 'bkgame.mp4'];
// The later quality pass supplies separate large previews. Do not accidentally
// overwrite its improved game encodes by rerunning this initial reduction pass.
if (args.includes('--apply') && fs.existsSync(path.join(raw, 'character_preview_khaled.mp4'))) {
  throw new Error('Two-tier quality profile is active. Use tools/improve_character_quality.cjs instead.');
}
const hash = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
function run(arguments_) {
  const result = spawnSync(ffmpeg, arguments_, {encoding: 'utf8', maxBuffer: 8 * 1024 * 1024});
  if (result.error || result.status !== 0) throw new Error(result.error?.message || result.stderr);
  return result;
}
function inspect(file) {
  const result = spawnSync(ffmpeg, ['-hide_banner', '-i', file], {encoding: 'utf8'});
  if (result.error) throw result.error;
  const video = result.stderr.split('\n').find(line => /Stream.*Video:/.test(line));
  const dimensions = video?.match(/,\s*(\d+)x(\d+)[\s,]/);
  const fps = video?.match(/([\d.]+) fps/);
  if (!dimensions || !fps) throw new Error('Unrecognized video: ' + file);
  const decoded = run(['-v', 'error', '-i', file, '-map', '0:v:0', '-an',
    '-progress', 'pipe:1', '-f', 'null', '-']);
  if (decoded.stderr.trim()) throw new Error('Decoder errors: ' + decoded.stderr);
  const frames = [...decoded.stdout.matchAll(/^frame=(\d+)/gm)].at(-1)?.[1];
  if (!frames) throw new Error('No decoded frames: ' + file);
  return {width: Number(dimensions[1]), height: Number(dimensions[2]),
    fps: Number(fps[1]), frames: Number(frames), audio: /Stream.*Audio:/.test(result.stderr),
    bytes: fs.statSync(file).size, sha256: hash(file)};
}
if (args.includes('--verify')) {
  for (const name of clips) {
    const info = inspect(path.join(raw, name));
    const expected = name === 'bkgame.mp4' ? [768, 432] : [360, 640];
    if (info.width !== expected[0] || info.height !== expected[1] || info.audio || info.fps !== 24) {
      throw new Error('Playback profile mismatch: ' + name + '\n' + JSON.stringify(info));
    }
  }
  console.log('49 clips decode fully: expected dimensions, 24 fps, no unused audio.');
  process.exit(0);
}
const originals = path.join(stage, 'originals');
const encoded = path.join(stage, 'encoded');
fs.mkdirSync(originals, {recursive: true});
fs.mkdirSync(encoded, {recursive: true});
const report = {profile: {characterWidth: 360, characterHeight: 640, fps: 24,
  backgroundWidth: 768, backgroundHeight: 432, audio: false, crf: 25}, clips: []};
const previousReportPath = path.join(stage, 'report.json');
const previous = fs.existsSync(previousReportPath)
  ? JSON.parse(fs.readFileSync(previousReportPath, 'utf8')) : null;
for (const name of clips) {
  const original = path.join(originals, name);
  const earlier = previous?.clips.find(clip => clip.name === name);
  if (earlier && ![earlier.before.sha256, earlier.after.sha256].includes(hash(path.join(raw, name)))) {
    throw new Error('Source clip changed; use a fresh staging directory for the new artwork: ' + name);
  }
  if (!fs.existsSync(original)) fs.copyFileSync(path.join(raw, name), original);
  const before = inspect(original);
  if (before.fps !== 24) throw new Error('Do not silently change frame rate: ' + name);
  const dimensions = name === 'bkgame.mp4' ? '768:432' : '360:640';
  const output = path.join(encoded, name);
  if (`${before.width}:${before.height}` === dimensions && !before.audio) {
    // A new staging directory may already contain the shipping profile. Do not
    // introduce another generation of lossy encoding simply by rerunning a tool.
    fs.copyFileSync(original, output);
  } else run(['-v', 'error', '-y', '-i', original, '-map', '0:v:0', '-an',
    '-vf', `scale=${dimensions}:flags=lanczos,setsar=1`, '-vsync', '0',
    '-c:v', 'libx264', '-preset', 'slow', '-crf', '25', '-pix_fmt', 'yuv420p',
    '-profile:v', 'main', '-level:v', '3.1', '-movflags', '+faststart', '-map_metadata', '-1', output]);
  const after = inspect(output);
  if (after.frames !== before.frames || after.fps !== before.fps || after.audio) {
    throw new Error('Frame preservation check failed: ' + name);
  }
  report.clips.push({name, before, after});
  console.log(`${report.clips.length}/${clips.length} ${name}: ${before.bytes} -> ${after.bytes} bytes; ${after.frames} frames`);
}
report.beforeBytes = report.clips.reduce((sum, clip) => sum + clip.before.bytes, 0);
report.afterBytes = report.clips.reduce((sum, clip) => sum + clip.after.bytes, 0);
if (report.afterBytes > report.beforeBytes) throw new Error('Combined video size must not increase.');
// Apply only after the entire batch is encoded and validated, not clip by clip.
if (args.includes('--apply')) {
  for (const {name} of report.clips) fs.copyFileSync(path.join(encoded, name), path.join(raw, name));
}
report.applied = args.includes('--apply');
fs.writeFileSync(path.join(stage, 'report.json'), JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify({applied: report.applied, beforeBytes: report.beforeBytes,
  afterBytes: report.afterBytes, savedBytes: report.beforeBytes - report.afterBytes}));
