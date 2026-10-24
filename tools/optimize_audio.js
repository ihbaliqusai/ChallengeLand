const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const FFMPEG = "C:\\Program Files (x86)\\CoolerMaster\\MasterPlus\\ffmpeg.exe";
const RAW_DIR = path.resolve(__dirname, '../android/app/src/main/res/raw');
const BACKUP_ROOT = path.resolve(__dirname, 'backup_audio');
const BACKUP_UNUSED = path.join(BACKUP_ROOT, 'unused');
const BACKUP_ORIGINALS = path.join(BACKUP_ROOT, 'originals');

// Ensure backup directories exist
fs.mkdirSync(BACKUP_UNUSED, { recursive: true });
fs.mkdirSync(BACKUP_ORIGINALS, { recursive: true });

// 1. Unused audio files list
const UNUSED_FILES = [
    'drum.mp3',
    'drum_roll.mp3',
    'fastest_finger.mp3',
    'final_answer.mp3'
];

console.log("==========================================================");
console.log(" 1. Moving Unused Audio Files to Backup...");
console.log("==========================================================");

let unusedSavedBytes = 0;
for (const file of UNUSED_FILES) {
    const srcPath = path.join(RAW_DIR, file);
    const destPath = path.join(BACKUP_UNUSED, file);
    if (fs.existsSync(srcPath)) {
        const size = fs.statSync(srcPath).size;
        unusedSavedBytes += size;
        fs.copyFileSync(srcPath, destPath);
        fs.unlinkSync(srcPath);
        console.log(` [REMOVED] ${file.padEnd(25)} : ${(size / 1024 / 1024).toFixed(2).padStart(5)} MB (Backed up safely)`);
    } else if (fs.existsSync(destPath)) {
        const size = fs.statSync(destPath).size;
        unusedSavedBytes += size;
        console.log(` [ALREADY REMOVED] ${file.padEnd(17)} : ${(size / 1024 / 1024).toFixed(2).padStart(5)} MB`);
    }
}
console.log(`Total unused audio freed: ${(unusedSavedBytes / 1024 / 1024).toFixed(2)} MB\n`);

console.log("==========================================================");
console.log(" 2. Compressing Active Audio Files (96 kbps Joint-Stereo)...");
console.log("==========================================================");

const remainingFiles = fs.readdirSync(RAW_DIR).filter(f => f.endsWith('.mp3'));

let origTotalBytes = 0;
let newTotalBytes = 0;

for (const file of remainingFiles) {
    const srcPath = path.join(RAW_DIR, file);
    const backupPath = path.join(BACKUP_ORIGINALS, file);
    const tempPath = path.join(RAW_DIR, file + '.opt.mp3');

    // Make sure we have the true original in backup
    if (!fs.existsSync(backupPath)) {
        fs.copyFileSync(srcPath, backupPath);
    }

    const inputForCompression = fs.existsSync(backupPath) ? backupPath : srcPath;
    const origSize = fs.statSync(inputForCompression).size;
    origTotalBytes += origSize;

    // Compress with FFmpeg: -vn -map 0:a:0 -codec:a libmp3lame -b:a 96k -map_metadata -1
    try {
        execSync(`"${FFMPEG}" -y -i "${inputForCompression}" -vn -map 0:a:0 -codec:a libmp3lame -b:a 96k -map_metadata -1 "${tempPath}" 2>nul`);
        
        if (fs.existsSync(tempPath)) {
            const newSize = fs.statSync(tempPath).size;
            // Only replace if new size is smaller
            if (newSize < origSize) {
                fs.copyFileSync(tempPath, srcPath);
                newTotalBytes += newSize;
                const savedPct = ((1 - newSize / origSize) * 100).toFixed(0);
                console.log(` [OK]   ${file.padEnd(28)} : ${(origSize / 1024 / 1024).toFixed(2).padStart(5)} MB -> ${(newSize / 1024 / 1024).toFixed(2).padStart(5)} MB (Saved ${savedPct}%)`);
            } else {
                newTotalBytes += origSize;
                console.log(` [KEEP] ${file.padEnd(28)} : ${(origSize / 1024 / 1024).toFixed(2).padStart(5)} MB (Already optimal)`);
            }
            fs.unlinkSync(tempPath);
        }
    } catch (e) {
        console.error(` [ERROR] Failed to compress ${file}: ${e.message}`);
        newTotalBytes += origSize;
        if (fs.existsSync(tempPath)) fs.unlinkSync(tempPath);
    }
}

if (fs.existsSync(path.join(__dirname, '../test_out.mp3'))) {
    fs.unlinkSync(path.join(__dirname, '../test_out.mp3'));
}

console.log("\n==========================================================");
const origMB = origTotalBytes / 1024 / 1024;
const newMB = newTotalBytes / 1024 / 1024;
const savedMB = origMB - newMB;
const totalOverallSavedMB = (unusedSavedBytes + savedMB);

console.log(` Total Active Audio (Before) : ${origMB.toFixed(2)} MB`);
console.log(` Total Active Audio (After)  : ${newMB.toFixed(2)} MB`);
console.log(` Compression Savings         : ${savedMB.toFixed(2)} MB`);
console.log(` Unused Files Deleted        : ${(unusedSavedBytes / 1024 / 1024).toFixed(2)} MB`);
console.log(` 🌟 TOTAL AUDIO SPACE SAVED  : ${totalOverallSavedMB.toFixed(2)} MB`);
console.log(` Backups safely stored at    : ${BACKUP_ROOT}`);
console.log("==========================================================");
