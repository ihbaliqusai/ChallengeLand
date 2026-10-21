const fs = require('fs');
const path = require('path');
const anomalies = JSON.parse(fs.readFileSync(path.join(__dirname, 'category_anomalies.json'), 'utf8'));

['اختراعات', 'مسلسل Friends'].forEach(cat => {
  console.log(`\n=== Category: ${cat} ===`);
  anomalies.filter(a => a.cat === cat).slice(0, 15).forEach(a => {
    console.log(`[${a.idx}] Q: ${a.q}\nR: ${a.r}\n`);
  });
});
