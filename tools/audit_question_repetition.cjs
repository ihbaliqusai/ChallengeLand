const fs = require('node:fs');
const path = require('node:path');
const { questionKey } = require('../functions/src/question_identity');
const bank = require('../assets/questions.json');
const groups = new Map();
for (const [index, question] of bank.entries()) {
  const key = questionKey(question);
  if (!groups.has(key)) groups.set(key, []);
  groups.get(key).push(index);
}
const duplicates = [...groups].filter(([, indices]) => indices.length > 1).map(([key, indices]) => ({
  key, records: indices.map(index => ({ index, category: bank[index].Category, text: bank[index].Q, answer: bank[index].R })),
}));
const categories = {};
for (const q of bank) {
  const c = categories[q.Category] ||= { total: 0, unique: new Set(), levels: {} };
  c.total++; c.unique.add(questionKey(q)); c.levels[q.Level] = (c.levels[q.Level] || 0) + 1;
}
const report = { total: bank.length, unique: groups.size, duplicateGroups: duplicates.length,
  duplicateRows: bank.length - groups.size, duplicates,
  categories: Object.fromEntries(Object.entries(categories).map(([name, c]) => [name, { ...c, unique: c.unique.size }])) };
const output = path.resolve(__dirname, '../docs/question_repetition_audit.json');
fs.writeFileSync(output, JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify({ total: report.total, unique: report.unique, duplicateGroups: report.duplicateGroups,
  duplicateRows: report.duplicateRows, examples: duplicates.slice(0, 5).map(g => ({ ...g, records: g.records.slice(0, 3) })), report: output }, null, 2));
