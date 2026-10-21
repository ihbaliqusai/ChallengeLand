const fs = require('fs');
const path = require('path');
const list = JSON.parse(fs.readFileSync(path.join(__dirname, 'option_dependent.json'), 'utf8'));
list.slice(20).forEach(x => {
  console.log(`[${x.idx}] (${x.cat}, lvl ${x.lvl}) Q: ${x.q}\nR: ${x.r} | choices: ${x.choices.join(', ')}\n`);
});
