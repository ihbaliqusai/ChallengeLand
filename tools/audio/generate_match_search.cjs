// Original oscillator-only radar loop. No external samples or recordings.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const root = path.resolve(__dirname, '../..');
const rate = 44100;
const duration = 1.6;
const filename = 'match_search.wav';
const generator = 'tools/audio/generate_match_search.cjs';

function generate(directory) {
  const frames = Math.round(rate * duration);
  const samples = new Float64Array(frames);

  function ping(start, frequency, gain) {
    const begin = Math.round(start * rate);
    const length = Math.round(0.54 * rate);
    for (let i = 0; i < length && begin + i < frames; i++) {
      const t = i / rate;
      const attack = Math.sin(Math.min(1, t / 0.012) * Math.PI * 0.5);
      const release = Math.min(1, (length - 1 - i) / (rate * 0.045));
      // Integrate the gently descending frequency so the chirp stays smooth.
      const phase = 2 * Math.PI * (frequency * t + 95 * (1 - Math.exp(-t * 16)) / 16);
      const tone = Math.sin(phase) + 0.12 * Math.sin(phase * 2);
      samples[begin + i] += tone * gain * attack * release * Math.exp(-t * 11);
    }
  }

  // Even spacing continues through the loop boundary; faint echoes add depth.
  for (const [start, frequency] of [[0.05, 760], [0.85, 840]]) {
    ping(start, frequency, 1);
    ping(start + 0.14, frequency, 0.16);
  }

  let peak = 0;
  for (const sample of samples) peak = Math.max(peak, Math.abs(sample));
  const gain = 0.34 / peak;
  const output = Buffer.alloc(44 + frames * 2);
  output.write('RIFF', 0);
  output.writeUInt32LE(output.length - 8, 4);
  output.write('WAVEfmt ', 8);
  output.writeUInt32LE(16, 16);
  output.writeUInt16LE(1, 20); // Uncompressed PCM.
  output.writeUInt16LE(1, 22); // Mono, centered in the game's effect mix.
  output.writeUInt32LE(rate, 24);
  output.writeUInt32LE(rate * 2, 28);
  output.writeUInt16LE(2, 32);
  output.writeUInt16LE(16, 34);
  output.write('data', 36);
  output.writeUInt32LE(frames * 2, 40);

  let sum = 0;
  let decodedPeak = 0;
  for (let i = 0; i < frames; i++) {
    const edge = Math.min(1, i / (rate * 0.012), (frames - 1 - i) / (rate * 0.012));
    const value = Math.round(samples[i] * gain * Math.max(0, edge) * 32767);
    output.writeInt16LE(value, 44 + i * 2);
    const decoded = value / 32768;
    sum += decoded * decoded;
    decodedPeak = Math.max(decodedPeak, Math.abs(decoded));
  }
  if (output.readInt16LE(44) !== 0 || output.readInt16LE(output.length - 2) !== 0) {
    throw new Error('Loop boundary must return to digital silence.');
  }

  fs.mkdirSync(directory, { recursive: true });
  fs.writeFileSync(path.join(directory, filename), output);
  return {
    file: filename,
    role: 'حلقة مسح هادئة أثناء البحث عن منافس',
    durationSeconds: duration,
    sampleRate: rate,
    channels: 1,
    bytes: output.length,
    sha256: crypto.createHash('sha256').update(output).digest('hex'),
    sources: [],
    originalProceduralDesign: true,
    loopPrepared: true,
    generator,
    peakDb: Number((20 * Math.log10(decodedPeak)).toFixed(2)),
    rmsDb: Number((20 * Math.log10(Math.sqrt(sum / frames))).toFixed(2)),
    processing: 'Original sine-based scanning pings and quiet echoes; 44100 Hz mono PCM16 WAV; exact 1.6-second loop; zero-valued edge samples and short edge fades; peak 0.34. No external samples.'
  };
}

if (require.main === module) {
  const stage = path.join(root, 'build/audio-replacement');
  const record = generate(stage);
  if (process.argv.includes('--apply')) {
    const raw = path.join(root, 'android/app/src/main/res/raw');
    const ledgerPath = path.join(raw, 'audio_provenance.json');
    const ledger = JSON.parse(fs.readFileSync(ledgerPath, 'utf8'));
    ledger.files = ledger.files.filter(item => item.file !== filename);
    ledger.files.push(record);
    ledger.updatedAt = '2026-10-28';
    fs.copyFileSync(path.join(stage, filename), path.join(raw, filename));
    fs.writeFileSync(ledgerPath, JSON.stringify(ledger, null, 2) + '\n');
  }
  console.log(JSON.stringify(record, null, 2));
}

module.exports = { generate };
