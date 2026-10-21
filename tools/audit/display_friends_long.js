const fs = require('fs');
const path = require('path');
const grouped = JSON.parse(fs.readFileSync(path.join(__dirname, 'super_long_grouped.json'), 'utf8'));

console.log('=== FRIENDS SUPER LONG QUESTIONS (first 25) ===');
grouped['مسلسل Friends'].slice(0, 25).forEach(item => {
  console.log(`[${item.idx}] Q: ${item.Q}\nR: ${item.R}\n`);
});
