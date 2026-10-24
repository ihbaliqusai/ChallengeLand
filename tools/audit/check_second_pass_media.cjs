"use strict";
// Availability only: neither an HTTP 200 nor image bytes verify the answer.
const fs = require("node:fs"), path = require("node:path");
const root = path.resolve(__dirname, "../..");
const questions = require("../../assets/questions.json");
const images = questions.map((q, index) => ({ ...q, index })).filter(q => q.Img);
async function check(q) {
  const result = { index: q.index, url: q.Img, category: q.Category, visualAnswerVerified: false };
  try {
    const response = await fetch(q.Img, { signal: AbortSignal.timeout(20000) });
    const bytes = (await response.arrayBuffer()).byteLength;
    Object.assign(result, { status: response.status, contentType: response.headers.get("content-type"), bytes });
    result.available = response.ok && result.contentType?.startsWith("image/") && bytes > 100;
  } catch (error) { Object.assign(result, { available: false, error: String(error) }); }
  return result;
}
(async () => {
  const results = [];
  for (let i = 0; i < images.length; i += 4) results.push(...await Promise.all(images.slice(i, i + 4).map(check)));
  fs.writeFileSync(path.join(__dirname, "second_pass_media.json"), JSON.stringify(results, null, 2) + "\n");
  console.log(`Remote images available: ${results.filter(r => r.available).length}/${results.length}; visual answer verification remains pending.`);
})();
