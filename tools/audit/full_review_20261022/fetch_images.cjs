"use strict";
const fs = require("node:fs"), path = require("node:path"), crypto = require("node:crypto");
const bank = require("./backup/assets__questions.json"), records = [];
fs.mkdirSync(path.join(__dirname, "images"), { recursive: true });
(async () => {
  const images = bank.flatMap((q, index) => q.Img ? [{ index, ...q }] : []);
  for (let offset = 0; offset < images.length; offset += 4) {
    await Promise.all(images.slice(offset, offset + 4).map(async q => {
      try {
        const response = await fetch(q.Img, { signal: AbortSignal.timeout(30000) });
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        if (!response.headers.get("content-type")?.startsWith("image/")) throw new Error("Not an image response");
        const bytes = Buffer.from(await response.arrayBuffer()), saved = `images/${q.index}.jpg`;
        fs.writeFileSync(path.join(__dirname, saved), bytes);
        records.push({ index: q.index, url: q.Img, snapshot: saved, sha256: crypto.createHash("sha256").update(bytes).digest("hex"), bytes: bytes.length, fetchedAt: new Date().toISOString(), status: "downloaded" });
      } catch (error) { records.push({ index: q.index, url: q.Img, status: "unavailable", reason: error.message }); }
    }));
  }
  records.sort((a, b) => a.index - b.index);
  fs.writeFileSync(path.join(__dirname, "media_downloads.json"), JSON.stringify(records, null, 2) + "\n");
  console.log(JSON.stringify(records.map(({ index, status, reason }) => ({ index, status, reason }))));
})();
