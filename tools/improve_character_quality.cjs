// Two playback tiers: eight small in-game decoders, one sharper preview.
// Always start from verified originals, never upscale the shipping 360p clips.
// node tools/improve_character_quality.cjs --originals DIR --baseline-report FILE --stage DIR [--apply]
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {spawnSync} = require('node:child_process');
const root = path.resolve(__dirname, '..');
const raw = path.join(root, 'android/app/src/main/res/raw');
const args = process.argv.slice(2);
function option(name) {
  const index = args.indexOf(name);
  if (index < 0 || !args[index + 1] || args[index + 1].startsWith('--')) {
    throw new Error('Missing ' + name);
  }
  return path.resolve(args[index + 1]);
}
const originals = option('--originals');
const baseline = JSON.parse(fs.readFileSync(option('--baseline-report'), 'utf8'));
const stage = option('--stage');
if (stage === raw || stage.startsWith(raw + path.sep)) throw new Error('Stage outside packaged resources.');
const encoded = path.join(stage, 'encoded');
const rollback = path.join(stage, 'rollback');
fs.mkdirSync(encoded, {recursive: true});
fs.mkdirSync(rollback, {recursive: true});
const reportPath = path.join(stage, 'report.json');
const previous = fs.existsSync(reportPath) ? JSON.parse(fs.readFileSync(reportPath, 'utf8')) : null;
const ffmpeg = process.env.CHALLENGELAND_FFMPEG || 'C:/Program Files (x86)/CoolerMaster/MasterPlus/ffmpeg.exe';
const hash = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
function run(parameters) {
  const result = spawnSync(ffmpeg, parameters, {encoding: 'utf8', maxBuffer: 8 * 1024 * 1024});
  if (result.error || result.status !== 0) throw new Error(result.error?.message || result.stderr);
  return result;
}
function inspect(file) {
  const header = spawnSync(ffmpeg, ['-hide_banner', '-i', file], {encoding: 'utf8'});
  if (header.error) throw header.error;
  const video = header.stderr.split('\n').find(line => /Stream.*Video:/.test(line));
  const dimensions = video?.match(/,\s*(\d+)x(\d+)[\s,]/);
  const fps = video?.match(/([\d.]+) fps/);
  if (!dimensions || !fps) throw new Error('Unknown video: ' + file);
  const decoded = run(['-v', 'error', '-i', file, '-map', '0:v:0', '-an', '-progress', 'pipe:1', '-f', 'null', '-']);
  if (decoded.stderr.trim()) throw new Error(decoded.stderr);
  const frames = Number([...decoded.stdout.matchAll(/^frame=(\d+)/gm)].at(-1)?.[1]);
  if (!frames) throw new Error('Empty video: ' + file);
  return {width: Number(dimensions[1]), height: Number(dimensions[2]), fps: Number(fps[1]), frames,
    audio: /Stream.*Audio:/.test(header.stderr), bytes: fs.statSync(file).size, sha256: hash(file)};
}
const names = baseline.clips.map(clip => clip.name).filter(name => /^video_[a-z]+(?:_(?:correct|wrong))?\.mp4$/.test(name));
if (names.length !== 48 || new Set(names).size !== 48) throw new Error('Expected 48 original character clips.');
const report = {profile: {gameplay: {width: 360, height: 640, crf: 22},
  preview: {width: 540, height: 960, crf: 22, preserveMatchingOriginal: true}, fps: 24, audio: false}, clips: []};
for (const name of names) {
  const original = path.join(originals, name);
  const sourceRecord = baseline.clips.find(clip => clip.name === name);
  if (hash(original) !== sourceRecord.before.sha256) throw new Error('Original changed: ' + name);
  const before = inspect(original);
  if (before.width < 540 || before.height < 960 || before.fps !== 24) throw new Error('High quality source required: ' + name);
  const shipping = path.join(raw, name);
  const allowed = [sourceRecord.before.sha256, sourceRecord.after.sha256,
    previous?.clips.find(clip => clip.name === name)?.after.sha256];
  if (!allowed.includes(hash(shipping))) throw new Error('Shipping source changed: ' + name);
  const targets = [{name, width: 360, height: 640}];
  if (!/_(?:correct|wrong)\.mp4$/.test(name)) {
    targets.push({name: name.replace('video_', 'character_preview_'), width: 540, height: 960});
  }
  for (const target of targets) {
    const output = path.join(encoded, target.name);
    if (before.width === target.width && before.height === target.height && !before.audio) {
      fs.copyFileSync(original, output);
    } else {
      run(['-v', 'error', '-y', '-i', original, '-map', '0:v:0', '-an',
        '-vf', `scale=${target.width}:${target.height}:flags=lanczos,setsar=1`, '-vsync', '0',
        '-c:v', 'libx264', '-preset', 'slow', '-crf', '22', '-pix_fmt', 'yuv420p',
        '-profile:v', 'main', '-level:v', '3.1', '-movflags', '+faststart', '-map_metadata', '-1', output]);
    }
    const after = inspect(output);
    if (after.width !== target.width || after.height !== target.height || after.fps !== before.fps ||
        after.frames !== before.frames || after.audio) throw new Error('Decode verification failed: ' + target.name);
    const current = path.join(raw, target.name);
    if (fs.existsSync(current)) {
      const earlier = previous?.clips.find(clip => clip.name === target.name);
      if (target.name !== name && hash(current) !== earlier?.after.sha256) throw new Error('Preview changed: ' + target.name);
      if (!fs.existsSync(path.join(rollback, target.name))) fs.copyFileSync(current, path.join(rollback, target.name));
    }
    report.clips.push({name: target.name, source: name, tier: target.name === name ? 'gameplay' : 'preview', before, after});
    console.log(`${report.clips.length}/64 ${target.name}: ${after.width}x${after.height}, ${after.frames} frames, ${after.bytes} bytes`);
  }
}
if (report.clips.length !== 64) throw new Error('Expected 48 gameplay clips and 16 previews.');
report.baselineCharacterBytes = baseline.clips.filter(clip => names.includes(clip.name)).reduce((sum, clip) => sum + clip.after.bytes, 0);
report.gameplayBytes = report.clips.filter(clip => clip.tier === 'gameplay').reduce((sum, clip) => sum + clip.after.bytes, 0);
report.previewBytes = report.clips.filter(clip => clip.tier === 'preview').reduce((sum, clip) => sum + clip.after.bytes, 0);
report.applied = args.includes('--apply');
// Validate the whole batch before replacing any packaged file.
if (report.applied) for (const clip of report.clips) fs.copyFileSync(path.join(encoded, clip.name), path.join(raw, clip.name));
fs.writeFileSync(reportPath, JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify({applied: report.applied, gameplayBytes: report.gameplayBytes, previewBytes: report.previewBytes,
  addedBytes: report.gameplayBytes + report.previewBytes - report.baselineCharacterBytes}));
