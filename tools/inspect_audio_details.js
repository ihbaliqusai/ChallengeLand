const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const FFMPEG = "C:\\Program Files (x86)\\CoolerMaster\\MasterPlus\\ffmpeg.exe";
const RAW_DIR = path.resolve(__dirname, '../android/app/src/main/res/raw');

const files = fs.readdirSync(RAW_DIR).filter(f => f.endsWith('.mp3'));

console.log("=== Audio Files Bitrates & Durations ===");
let totalBytes = 0;

for (const file of files) {
    const filePath = path.join(RAW_DIR, file);
    const stat = fs.statSync(filePath);
    totalBytes += stat.size;
    
    let info = "";
    try {
        execSync(`"${FFMPEG}" -i "${filePath}" -hide_banner`, { stdio: 'pipe' });
    } catch (e) {
        info = e.stderr ? e.stderr.toString() : "";
    }

    const durationMatch = info.match(/Duration:\s*([0-9:.]+),\s*start:\s*[0-9.]+,\s*bitrate:\s*([0-9]+)\s*kb\/s/);
    const audioMatch = info.match(/Audio:\s*(.+)/);

    const dur = durationMatch ? durationMatch[1] : "?";
    const bitrate = durationMatch ? durationMatch[2] + " kb/s" : "?";
    const format = audioMatch ? audioMatch[1].split(',').slice(0, 3).join(', ') : "?";

    console.log(`${file.padEnd(28)} | ${(stat.size / 1024 / 1024).toFixed(2).padStart(5)} MB | ${dur.padStart(11)} | ${bitrate.padStart(10)} | ${format}`);
}

console.log(`\nTotal MP3 Files: ${files.length}, Total Size: ${(totalBytes / 1024 / 1024).toFixed(2)} MB`);
