"use strict";
const fs = require("node:fs"), path = require("node:path");
const name = process.argv[2], offset = Number(process.argv[3] || 0), count = Number(process.argv[4] || 70);
const records = fs.readFileSync(path.join(__dirname, name), "utf8").trim().split(/\r?\n/).map(JSON.parse);
for (const q of records.slice(offset, offset + count)) console.log(`${q.index}|L${q.Level}|${q.Q} → ${q.R} | ${q.W1} / ${q.W2} / ${q.W3}${q.Img ? " | IMG=" + q.Img : ""}`);
