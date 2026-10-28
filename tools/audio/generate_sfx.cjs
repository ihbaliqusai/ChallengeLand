const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const ffmpeg = process.env.CHALLENGELAND_FFMPEG || 'C:/Program Files (x86)/CoolerMaster/MasterPlus/ffmpeg.exe';
const rate = 44100;
const stageDir = path.resolve(__dirname, '../../build/audio-sfx');
const rawDir = path.resolve(__dirname, '../../android/app/src/main/res/raw');

fs.mkdirSync(stageDir, { recursive: true });

function ff(args) {
  const result = spawnSync(ffmpeg, ['-hide_banner', '-loglevel', 'error', ...args], { encoding: 'utf8' });
  if (result.status !== 0) throw new Error(String(result.stderr || result.error));
}

let seed = 428913;
function noise() {
  seed ^= seed << 13;
  seed ^= seed >>> 17;
  seed ^= seed << 5;
  return (seed >>> 0) / 2147483648 - 1;
}

// 1. Button click: a modern, crisp, tactile UI pop/click (60ms)
function generateButtonClick() {
  const duration = 0.06; // 60ms
  const frames = Math.round(duration * rate);
  const out = new Float32Array(frames * 2);

  let prevNoise = 0;
  for (let i = 0; i < frames; i++) {
    const t = i / rate;
    const n = noise();
    const hpNoise = (n - prevNoise * 0.75);
    prevNoise = n;
    const noiseBurst = t < 0.005 ? hpNoise * Math.sin(t / 0.005 * Math.PI) * 0.5 : 0;

    // Pitch sweep: drops from 1600Hz down to 500Hz
    const freq = 500 + 1100 * Math.exp(-t * 80);
    const phase = 2 * Math.PI * freq * t;
    const body = (Math.sin(phase) + 0.25 * Math.sin(phase * 2)) * Math.exp(-t * 65);

    const amp = Math.min(1, t / 0.001) * Math.max(0, 1 - t / duration);
    const sample = (body * 0.8 + noiseBurst) * amp;

    out[i * 2] = sample;
    out[i * 2 + 1] = sample;
  }
  return { out, duration };
}

// 2. Wheel tick: sharp, wooden/plastic mechanical peg click (50ms)
function generateWheelTick() {
  const duration = 0.05; // 50ms
  const frames = Math.round(duration * rate);
  const out = new Float32Array(frames * 2);

  let prevNoise = 0;
  for (let i = 0; i < frames; i++) {
    const t = i / rate;
    const n = noise();
    const hpNoise = (n - prevNoise * 0.85);
    prevNoise = n;
    const click = t < 0.004 ? hpNoise * 0.7 : 0;

    // Dual resonant ring: 2200Hz and 3400Hz with fast damping
    const p1 = 2 * Math.PI * 2200 * t;
    const p2 = 2 * Math.PI * 3400 * t;
    const tone = (Math.sin(p1) * 0.7 + Math.sin(p2) * 0.3) * Math.exp(-t * 110);

    const sample = (tone * 0.75 + click) * Math.min(1, t / 0.0006) * Math.max(0, 1 - t / duration);

    out[i * 2] = sample;
    out[i * 2 + 1] = sample;
  }
  return { out, duration };
}

// 3. Wheel win: ascending bright bell chime with rewarding sparkle (1.25s)
function generateWheelWin() {
  const duration = 1.25; // 1.25s
  const frames = Math.round(duration * rate);
  const out = new Float32Array(frames * 2);

  function bellTone(start, noteMidi, gain, pan = 0) {
    const freq = 440 * 2 ** ((noteMidi - 69) / 12);
    const begin = Math.round(start * rate);
    const len = Math.round(0.75 * rate);
    const l = Math.sqrt((1 - pan) / 2);
    const r = Math.sqrt((1 + pan) / 2);

    for (let j = 0; j < len && begin + j < frames; j++) {
      const t = j / rate;
      const attack = Math.min(1, t / 0.004);
      const phase = 2 * Math.PI * freq * t;
      // Bell FM harmonics
      const val = (Math.sin(phase + 1.2 * Math.exp(-t * 8) * Math.sin(phase * 2.76)) + 0.18 * Math.sin(phase * 2))
        * Math.exp(-t * 3.8) * attack * gain;
      out[(begin + j) * 2] += val * l;
      out[(begin + j) * 2 + 1] += val * r;
    }
  }

  // Ascending arpeggio: C5 (72), E5 (76), G5 (79), C6 (84), E6 (88)
  const notes = [
    { start: 0.00, note: 72, gain: 0.30, pan: -0.2 },
    { start: 0.09, note: 76, gain: 0.32, pan: -0.1 },
    { start: 0.18, note: 79, gain: 0.34, pan: 0.1 },
    { start: 0.27, note: 84, gain: 0.38, pan: 0.2 },
    { start: 0.37, note: 88, gain: 0.45, pan: 0.0 }, // Peak note
    { start: 0.37, note: 79, gain: 0.20, pan: -0.3 }, // Harmony
    { start: 0.37, note: 84, gain: 0.22, pan: 0.3 },
  ];

  for (const n of notes) {
    bellTone(n.start, n.note, n.gain, n.pan);
  }

  // Sparkle shimmer
  for (let s = 0.46; s < 1.0; s += 0.075) {
    const sparkleNote = [91, 93, 96, 100][Math.floor(s * 10) % 4];
    bellTone(s, sparkleNote, 0.10, (Math.sin(s * 20) * 0.4));
  }

  return { out, duration };
}

const sfxList = [
  { name: 'sfx_wheel_tick', gen: generateWheelTick, targetRms: -16 },
  { name: 'sfx_wheel_win', gen: generateWheelWin, targetRms: -17 },
];

// Clean up previous .mp3 files if present to prevent resource conflicts
for (const sfx of [{ name: 'sfx_button_click' }, ...sfxList]) {
  const oldMp3 = path.join(rawDir, `${sfx.name}.mp3`);
  if (fs.existsSync(oldMp3)) {
    fs.unlinkSync(oldMp3);
    console.log(`Removed old ${sfx.name}.mp3`);
  }
}

// 1. Button click: authentic Kenney Interface Sounds drop_004 (CC0-1.0)
const clickSource = path.join(__dirname, 'sources/Audio/drop_004.ogg');
const clickWav = path.join(stageDir, 'sfx_button_click.wav');
ff([
  '-y', '-i', clickSource,
  '-c:a', 'pcm_s16le', '-ar', String(rate), '-ac', '2',
  clickWav
]);
const rawClick = path.join(rawDir, 'sfx_button_click.wav');
fs.copyFileSync(clickWav, rawClick);
console.log(`Installed sfx_button_click.wav (${fs.statSync(rawClick).size} bytes) from Kenney drop_004 (CC0)`);

// 2. Synthesized effects for wheel tick and wheel win
for (const sfx of sfxList) {
  const { out } = sfx.gen();
  let sum = 0, peak = 0;
  for (let i = 0; i < out.length; i++) {
    sum += out[i] * out[i];
    peak = Math.max(peak, Math.abs(out[i]));
  }
  if (peak > 0) {
    const rms = Math.sqrt(sum / out.length);
    const targetGain = 10 ** (sfx.targetRms / 20);
    const gain = Math.min(targetGain / rms, 0.92 / peak);
    for (let i = 0; i < out.length; i++) out[i] *= gain;
  }

  const pcmPath = path.join(stageDir, `${sfx.name}.f32`);
  fs.writeFileSync(pcmPath, Buffer.from(out.buffer));
  const wavPath = path.join(stageDir, `${sfx.name}.wav`);

  // Encode as uncompressed 16-bit PCM WAV for SoundPool zero-latency guaranteed playback
  ff([
    '-y', '-f', 'f32le', '-ar', String(rate), '-ac', '2', '-i', pcmPath,
    '-c:a', 'pcm_s16le', '-ar', String(rate), '-ac', '2',
    wavPath
  ]);
  fs.unlinkSync(pcmPath);

  // Copy WAV to rawDir
  const rawPath = path.join(rawDir, `${sfx.name}.wav`);
  fs.copyFileSync(wavPath, rawPath);
  console.log(`Generated and installed ${sfx.name}.wav (${fs.statSync(rawPath).size} bytes)`);
}
