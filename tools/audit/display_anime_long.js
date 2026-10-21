const fs = require('fs');
const path = require('path');
const grouped = JSON.parse(fs.readFileSync(path.join(__dirname, 'super_long_grouped.json'), 'utf8'));

console.log('=== ANIME SUPER LONG QUESTIONS (46) ===');
grouped['الأنمي'].forEach(item => {
  console.log(`[${item.idx}] Q: ${item.Q}\nR: ${item.R}\n`);
});
