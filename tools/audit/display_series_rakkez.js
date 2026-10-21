const fs = require('fs');
const path = require('path');
const grouped = JSON.parse(fs.readFileSync(path.join(__dirname, 'super_long_grouped.json'), 'utf8'));

console.log('=== ARABIC SERIES SUPER LONG QUESTIONS (sample 15) ===');
grouped['مسلسلات عربية'].slice(0, 15).forEach(item => {
  console.log(`[${item.idx}] Q: ${item.Q}\nR: ${item.R}\n`);
});

console.log('\n=== RAKKEZ SHWAY SUPER LONG QUESTIONS (sample 15) ===');
grouped['ركز شوي'].slice(0, 15).forEach(item => {
  console.log(`[${item.idx}] Q: ${item.Q}\nR: ${item.R}\n`);
});
