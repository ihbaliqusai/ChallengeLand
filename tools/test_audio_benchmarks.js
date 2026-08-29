const { execSync } = require('child_process');
const fs = require('fs');
const FFMPEG = "C:\\Program Files (x86)\\CoolerMaster\\MasterPlus\\ffmpeg.exe";

const testFile = 'android/app/src/main/res/raw/sneaky_snitch.mp3';
const origSize = fs.statSync(testFile).size / 1024 / 1024;

execSync(`"${FFMPEG}" -y -i "${testFile}" -codec:a libmp3lame -b:a 96k test_96k.mp3 2>nul`);
const size96k = fs.statSync('test_96k.mp3').size / 1024 / 1024;

execSync(`"${FFMPEG}" -y -i "${testFile}" -codec:a libmp3lame -b:a 64k test_64k.mp3 2>nul`);
const size64k = fs.statSync('test_64k.mp3').size / 1024 / 1024;

console.log('Original sneaky_snitch: ' + origSize.toFixed(2) + ' MB');
console.log('96 kbps MP3: ' + size96k.toFixed(2) + ' MB (Saved ' + ((1 - size96k/origSize)*100).toFixed(0) + '%)');
console.log('64 kbps MP3: ' + size64k.toFixed(2) + ' MB (Saved ' + ((1 - size64k/origSize)*100).toFixed(0) + '%)');

fs.unlinkSync('test_96k.mp3');
fs.unlinkSync('test_64k.mp3');
