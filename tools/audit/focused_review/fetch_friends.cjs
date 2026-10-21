"use strict";
const fs = require("node:fs"), path = require("node:path");
const base = "https://www.friends-tv.org/";
const episodes = [106,107,117,201,212,214,216,220,221,302,311,403,404,416,423,508,509,514,515,516,521,604,605,606,608,611,612,619,623,624,701,703,707,708,709,711,714,802,807,810,811,823,907,915,1003,1005,1007,1008,1009,1014,1017];
(async () => {
  const response = await fetch(base + "transcripts.html");
  const html = await response.text();
  const links = [...html.matchAll(/href=["']([^"']+)["']/gi)].map(m => m[1].replaceAll("\\", "/"));
  const manifest = [];
  for (let i = 0; i < episodes.length; i += 5) await Promise.all(episodes.slice(i, i + 5).map(async episode => {
    const link = links.find(link => new RegExp("(?:^|/)" + episode + "(?:extended)?\\.").test(link));
    if (!link) { manifest.push({ episode, error: "not_in_index" }); return; }
    const url = new URL(link, base).href;
    const file = path.join(__dirname, `friends_${episode}.txt`);
    if (!fs.existsSync(file)) {
      const response = await fetch(url, { signal: AbortSignal.timeout(20000) });
      if (!response.ok) throw new Error(`${response.status}: ${url}`);
      const text = (await response.text()).replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, "").replace(/<[^>]+>/g, " ").replace(/&nbsp;/g, " ").replace(/&quot;/g, '"').replace(/&amp;/g, "&").replace(/[ \t]+/g, " ");
      fs.writeFileSync(file, text);
    }
    manifest.push({ episode, url });
  }));
  manifest.sort((a, b) => a.episode - b.episode);
  fs.writeFileSync(path.join(__dirname, "friends_sources.json"), JSON.stringify(manifest, null, 2));
  console.log(manifest);
})();
