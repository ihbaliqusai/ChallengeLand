const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const FFMPEG = "C:\\Program Files (x86)\\CoolerMaster\\MasterPlus\\ffmpeg.exe";
const ROOT = path.resolve(__dirname, '..');

// 1. Find all audio files
function getAudioFiles(dir) {
    let results = [];
    const list = fs.readdirSync(dir);
    for (const file of list) {
        if (['build', '.git', 'node_modules', 'backup_videos', 'backup_audio', '.dart_tool'].includes(file)) continue;
        const fullPath = path.join(dir, file);
        const stat = fs.statSync(fullPath);
        if (stat.isDirectory()) {
            results = results.concat(getAudioFiles(fullPath));
        } else {
            const ext = path.extname(file).toLowerCase();
            if (['.mp3', '.wav', '.ogg', '.m4a', '.aac', '.flac'].includes(ext)) {
                results.push({
                    name: file,
                    baseName: path.basename(file, ext),
                    fullPath: fullPath,
                    relPath: path.relative(ROOT, fullPath),
                    size: stat.size,
                    ext: ext
                });
            }
        }
    }
    return results;
}

// 2. Find all source code files
function getCodeFiles(dir) {
    let results = [];
    const list = fs.readdirSync(dir);
    for (const file of list) {
        if (['build', '.git', 'node_modules', 'backup_videos', 'backup_audio', '.dart_tool', 'tools'].includes(file)) continue;
        const fullPath = path.join(dir, file);
        const stat = fs.statSync(fullPath);
        if (stat.isDirectory()) {
            results = results.concat(getCodeFiles(fullPath));
        } else {
            const ext = path.extname(file).toLowerCase();
            if (['.dart', '.java', '.kt', '.xml', '.json', '.gradle', '.js', '.html'].includes(ext)) {
                results.push(fullPath);
            }
        }
    }
    return results;
}

const audioFiles = getAudioFiles(ROOT);
const codeFiles = getCodeFiles(ROOT);

console.log(`Found ${audioFiles.length} audio files and ${codeFiles.length} code files.`);

// Load all code file contents into memory for fast searching
const codeData = codeFiles.map(filePath => ({
    path: path.relative(ROOT, filePath),
    content: fs.readFileSync(filePath, 'utf8')
}));

const usedAudio = [];
const unusedAudio = [];

for (const audio of audioFiles) {
    const baseName = audio.baseName;
    const fullName = audio.name;
    
    const references = [];

    for (const code of codeData) {
        // Check if code contains baseName (for R.raw.<baseName> or "<baseName>") or fullName
        // In Android Java/Kotlin, it's typically R.raw.sound_name
        // In Flutter, it might be 'assets/sound_name.mp3' or 'sound_name.mp3'
        const regex = new RegExp(`\\b${baseName}\\b`, 'i');
        if (regex.test(code.content)) {
            // Find line numbers
            const lines = code.content.split('\n');
            lines.forEach((line, idx) => {
                if (new RegExp(`\\b${baseName}\\b`, 'i').test(line)) {
                    references.push({
                        file: code.path,
                        lineNum: idx + 1,
                        text: line.trim()
                    });
                }
            });
        }
    }

    if (references.length > 0) {
        usedAudio.push({ ...audio, references });
    } else {
        unusedAudio.push(audio);
    }
}

console.log("\n=======================================================");
console.log(`=== UNUSED AUDIO FILES (${unusedAudio.length}) ===`);
console.log("=======================================================");
let unusedTotalSize = 0;
unusedAudio.forEach(a => {
    unusedTotalSize += a.size;
    console.log(`❌ [UNUSED] ${a.name.padEnd(30)} : ${(a.size / 1024 / 1024).toFixed(2).padStart(6)} MB (${a.relPath})`);
});
console.log(`Total Unused Audio Size: ${(unusedTotalSize / 1024 / 1024).toFixed(2)} MB\n`);

console.log("=======================================================");
console.log(`=== USED AUDIO FILES (${usedAudio.length}) ===`);
console.log("=======================================================");
let usedTotalSize = 0;
usedAudio.forEach(a => {
    usedTotalSize += a.size;
    console.log(`✅ [USED]   ${a.name.padEnd(30)} : ${(a.size / 1024 / 1024).toFixed(2).padStart(6)} MB`);
    // Print first 2 references
    a.references.slice(0, 2).forEach(r => {
        console.log(`     ↳ in ${r.file}:${r.lineNum} -> ${r.text.substring(0, 70)}`);
    });
});
console.log(`\nTotal Used Audio Size: ${(usedTotalSize / 1024 / 1024).toFixed(2)} MB`);

