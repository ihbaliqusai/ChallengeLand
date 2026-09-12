const fs = require('fs');

// 1. Load map
const nameMap = JSON.parse(fs.readFileSync('./tools/guess_name/map_foreign_names.json', 'utf8'));
// Add the 2 missing
nameMap['بول إيرليش'] = 'Paul Ehrlich';
nameMap['جون آدمز'] = 'John Adams';

// 2. Load questions
const allQuestions = JSON.parse(fs.readFileSync('./assets/questions.json', 'utf8'));
const guessNameQuestions = allQuestions.filter(q => q.Category === 'خمن الاسم');
console.log('Original "خمن الاسم" count:', guessNameQuestions.length);

const foreignRanges = [
  [0, 18], [21, 36], [80, 85], [87, 88], [96, 99],
  [104, 119], [120, 136], [137, 159], [160, 167],
  [188, 199], [231, 239], [241, 245], [247, 274],
  [280, 319], [320, 360], [386, 399]
];
const foreignIndices = new Set();
foreignRanges.forEach(([s, e]) => {
  for (let i = s; i <= e; i++) foreignIndices.add(i);
});

console.log('Foreign questions count:', foreignIndices.size);
console.log('Arabic questions count:', 400 - foreignIndices.size);

// Specific replacements for Arab distractors in foreign questions
const specialCases = {
  165: { // Euclid
    R: "Euclid",
    W1: "Pythagoras",
    W2: "Archimedes",
    W3: "Thales of Miletus"
  },
  166: { // Hippocrates
    R: "Hippocrates",
    W1: "Galen",
    W2: "Herophilus",
    W3: "Dioscorides"
  },
  167: { // Galen
    R: "Galen",
    W1: "Hippocrates",
    W2: "Herophilus",
    W3: "Dioscorides"
  },
  241: { // Icarus
    R: "Icarus",
    W1: "Phaethon",
    W2: "Daedalus",
    W3: "Bellerophon"
  },
  248: { // William Tell
    R: "William Tell",
    W1: "Robin Hood",
    W2: "Lancelot",
    W3: "King Arthur"
  },
  269: { // Narcissus
    Q: "خمن الشخصية الشهيرة: 🪞 + 🌊 + 👦",
    R: "Narcissus",
    W1: "Adonis",
    W2: "Apollo",
    W3: "Hyacinthus"
  },
  274: { // King Midas
    R: "King Midas",
    W1: "Croesus",
    W2: "King Minos",
    W3: "King Priam"
  }
};

const arabicCharRegex = /[\u0600-\u06FF]/;
const parenthesisRegex = /[()（）]/;

let errors = 0;
const processedGuessName = guessNameQuestions.map((q, index) => {
  const newQ = { ...q };

  if (foreignIndices.has(index)) {
    if (specialCases[index]) {
      if (specialCases[index].Q) newQ.Q = specialCases[index].Q;
      newQ.R = specialCases[index].R;
      newQ.W1 = specialCases[index].W1;
      newQ.W2 = specialCases[index].W2;
      newQ.W3 = specialCases[index].W3;
    } else {
      ['R', 'W1', 'W2', 'W3'].forEach(key => {
        const ar = q[key];
        const en = nameMap[ar];
        if (!en) {
          console.error(`[ERROR] Question ${index} (${key}): No English mapping for "${ar}"`);
          errors++;
        } else {
          newQ[key] = en;
        }
      });
    }

    // Validation for foreign questions
    ['R', 'W1', 'W2', 'W3'].forEach(key => {
      if (arabicCharRegex.test(newQ[key])) {
        console.error(`[ERROR] Question ${index} (${key}): Arabic characters found in foreign choice: "${newQ[key]}"`);
        errors++;
      }
      if (parenthesisRegex.test(newQ[key])) {
        console.error(`[ERROR] Question ${index} (${key}): Parentheses found in choice: "${newQ[key]}"`);
        errors++;
      }
    });

    // Check distinct choices
    const choicesSet = new Set([newQ.R, newQ.W1, newQ.W2, newQ.W3]);
    if (choicesSet.size !== 4) {
      console.error(`[ERROR] Question ${index}: Duplicate choices found!`, [newQ.R, newQ.W1, newQ.W2, newQ.W3]);
      errors++;
    }
  } else {
    // Arabic question validation
    ['R', 'W1', 'W2', 'W3'].forEach(key => {
      if (parenthesisRegex.test(newQ[key])) {
        console.error(`[ERROR] Question ${index} (${key}): Parentheses found in Arabic choice: "${newQ[key]}"`);
        errors++;
      }
    });
    const choicesSet = new Set([newQ.R, newQ.W1, newQ.W2, newQ.W3]);
    if (choicesSet.size !== 4) {
      console.error(`[ERROR] Question ${index}: Duplicate choices in Arabic question!`, [newQ.R, newQ.W1, newQ.W2, newQ.W3]);
      errors++;
    }
  }

  return newQ;
});

console.log(`Validation complete. Total errors: ${errors}`);

if (errors === 0) {
  // Save processed questions
  fs.writeFileSync('./tools/guess_name/processed_guess_name.json', JSON.stringify(processedGuessName, null, 2));
  console.log('Successfully written ./tools/guess_name/processed_guess_name.json');
} else {
  console.error('Failed due to errors.');
  process.exit(1);
}
