// Audit utility for "خمن الأغنية" questions
function normalizeArabic(text) {
  if (!text) return '';
  return text
    .replace(/[\u064B-\u065F\u0670]/g, '') // Remove tashkeel
    .replace(/[إأآا]/g, 'ا')
    .replace(/ة/g, 'ه')
    .replace(/ى/g, 'ي')
    .replace(/[^\u0621-\u064A\s]/g, ' ')
    .trim();
}

function stripPrefixes(word) {
  let w = word;
  if (w.startsWith('ال') && w.length > 3) w = w.slice(2);
  if ((w.startsWith('و') || w.startsWith('ف') || w.startsWith('ب') || w.startsWith('ل') || w.startsWith('ك')) && w.length > 3) {
    w = w.slice(1);
  }
  if (w.startsWith('ال') && w.length > 3) w = w.slice(2);
  return w;
}

function extractTitleWords(r) {
  const title = r.split(' - ')[0].trim();
  const normalized = normalizeArabic(title);
  const stopWords = new Set(['في', 'من', 'على', 'عن', 'هو', 'هي', 'ما', 'لا', 'يا', 'لي', 'له', 'لها', 'ان', 'او', 'قد', 'لو']);
  return normalized.split(/\s+/).filter(w => w.length >= 2 && !stopWords.has(w));
}

function auditQuestion(item, index = 0) {
  const errors = [];
  const warnings = [];

  // 1. Required fields
  if (!item.Q || !item.R || !item.W1 || !item.W2 || !item.W3) {
    errors.push(`Missing fields`);
    return { errors, warnings };
  }

  // 2. Parentheses
  const allText = `${item.Q} ${item.R} ${item.W1} ${item.W2} ${item.W3}`;
  if (allText.includes('(') || allText.includes(')')) {
    errors.push(`Contains parentheses ()`);
  }

  // 3. Distinct options
  const options = [item.R, item.W1, item.W2, item.W3];
  const uniqueOptions = new Set(options);
  if (uniqueOptions.size !== 4) {
    errors.push(`Duplicate options: ${options.join(' | ')}`);
  }

  // 4. Format "Song - Artist"
  options.forEach((opt, oi) => {
    if (!opt.includes(' - ')) {
      errors.push(`Option ${oi} missing ' - ': ${opt}`);
    }
  });

  // 5. Title leakage into Q
  const titleWords = extractTitleWords(item.R);
  let quoteContent = item.Q;
  const match = item.Q.match(/"([^"]+)"/);
  if (match) {
    quoteContent = match[1];
  }
  const normalizedQ = normalizeArabic(quoteContent);
  const qWords = normalizedQ.split(/\s+/).filter(Boolean);

  titleWords.forEach(tw => {
    const twBase = stripPrefixes(tw);
    
    qWords.forEach(qw => {
      const qwBase = stripPrefixes(qw);
      // Direct exact match
      if (tw === qw) {
        errors.push(`LEAK: Exact title word '${tw}' found in Q (Song: ${item.R})`);
      } else if (twBase.length >= 3 && qwBase === twBase) {
        errors.push(`LEAK: Stemmed title word '${tw}' ('${twBase}') matched Q word '${qw}' (Song: ${item.R})`);
      } else if (twBase.length >= 4 && qwBase.length >= 4) {
        if (qwBase.startsWith(twBase) || twBase.startsWith(qwBase)) {
          warnings.push(`POSSIBLE LEAK: Title word '${tw}' stem '${twBase}' very close to '${qw}' stem '${qwBase}' (Song: ${item.R})`);
        }
      }
    });
  });

  return { errors, warnings };
}

function auditBatch(batch, batchName = 'Batch') {
  console.log(`\n=== Auditing ${batchName} (${batch.length} items) ===`);
  let errorCount = 0;
  let warnCount = 0;

  batch.forEach((item, idx) => {
    const { errors, warnings } = auditQuestion(item, idx);
    if (errors.length > 0) {
      errorCount += errors.length;
      console.log(`[Item #${idx + 1}] ERROR: ${item.R}`);
      errors.forEach(e => console.log(`   - ${e}`));
      console.log(`   Q: ${item.Q}`);
    }
    if (warnings.length > 0) {
      warnCount += warnings.length;
      console.log(`[Item #${idx + 1}] WARNING: ${item.R}`);
      warnings.forEach(w => console.log(`   ~ ${w}`));
    }
  });

  console.log(`Result: ${errorCount} errors, ${warnCount} warnings.`);
  return { errorCount, warnCount };
}

module.exports = {
  normalizeArabic,
  extractTitleWords,
  stripPrefixes,
  auditQuestion,
  auditBatch
};
