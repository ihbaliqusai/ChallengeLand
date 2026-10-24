"use strict";
const fs = require("node:fs"), path = require("node:path");
const { decisions } = require("./decisions.cjs");
const urls = [...new Set(decisions.flatMap(d => d.sources).filter(s => s.startsWith("https://")))];
const results = [], queue = [...urls];
async function worker() {
  while (queue.length) {
    const url = queue.shift();
    try {
      const response = await fetch(url, { signal: AbortSignal.timeout(10000), headers: { "User-Agent": "Mozilla/5.0" } });
      const body = await response.text();
      const title = /<title[^>]*>([\s\S]*?)<\/title>/i.exec(body)?.[1].replace(/\s+/g, " ").trim();
      results.push({ url, finalUrl: response.url, status: response.status, title });
    } catch (error) { results.push({ url, error: String(error) }); }
  }
}
(async () => {
  await Promise.all(Array.from({ length: 8 }, worker));
  results.sort((a, b) => a.url.localeCompare(b.url));
  fs.writeFileSync(path.join(__dirname, "source_availability.json"), JSON.stringify(results, null, 2));
  console.log("Sources:", results.length, "HTTP 200:", results.filter(r => r.status === 200).length);
  for (const r of results.filter(r => r.status !== 200)) console.log(r.status || r.error, r.url);
})();
