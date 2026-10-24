const fs = require('fs');
const path = require('path');

const orig = JSON.parse(fs.readFileSync(path.resolve(__dirname, 'original_friends.json'), 'utf8'));
const current = JSON.parse(fs.readFileSync(path.resolve(__dirname, '../../assets/questions.json'), 'utf8')).filter(q => q.Category === 'مسلسل Friends');

const dupes = new Set([92, 95, 97, 122, 189, 289, 368]);

// Map of indices in original_friends.json that should have English choices
// These are iconic quotes, songs, show terms, character alter-egos, titles, proper nouns
const englishOverride = {
  1: {
    R: "Central Perk",
    W1: "Central Park Cafe",
    W2: "Brooklyn Beans",
    W3: "Manhattan Coffee"
  },
  8: {
    R: "Smelly Cat",
    W1: "Crazy Dog",
    W2: "Little Black Curly Hair",
    W3: "Two of Them Kissed"
  },
  15: {
    R: "How You Doin",
    W1: "Whats Up Man",
    W2: "Hey Beautiful",
    W3: "Good To See You"
  },
  17: {
    R: "Oh My God",
    W1: "No Way",
    W2: "Here We Go",
    W3: "Look At You"
  },
  27: {
    R: "Joey doesn't share food",
    W1: "Joey eats only vegetables",
    W2: "Joey cooks all his meals",
    W3: "Joey eats only fast food"
  },
  32: {
    R: "Ill Be There for You",
    W1: "Stand by Me",
    W2: "With a Little Help",
    W3: "Time of Your Life"
  },
  33: {
    R: "The Rembrandts",
    W1: "The Beatles",
    W2: "U2",
    W3: "Oasis"
  },
  35: {
    R: "We Were On A Break",
    W1: "It Was A Mistake",
    W2: "I Loved You",
    W3: "I Forgot Everything"
  },
  36: {
    R: "Pivot",
    W1: "Push",
    W2: "Turn",
    W3: "Lift"
  },
  57: {
    R: "Transponster",
    W1: "Accountant",
    W2: "Data Analyst",
    W3: "Statistical Adjuster"
  },
  61: {
    R: "My Eyes My Eyes",
    W1: "No No No",
    W2: "What Is That",
    W3: "Please Stop"
  },
  68: {
    R: "Mac and C.H.E.E.S.E.",
    W1: "Cops and Robbers",
    W2: "New York Detectives",
    W3: "The Robot Agency"
  },
  72: {
    R: "Unagi",
    W1: "Karate",
    W2: "Judo",
    W3: "Sushi"
  },
  102: {
    R: "Miss Chanandler Bong",
    W1: "Mrs. Monica Bing",
    W2: "Miss Chandy Bing",
    W3: "Mrs. Joey Bing"
  },
  103: {
    R: "Pottery Barn",
    W1: "IKEA",
    W2: "Bloomingdale's",
    W3: "Crate and Barrel"
  },
  104: {
    R: "Princess Consuela Banana Hammock",
    W1: "Queen Phoebe",
    W2: "Lady Regina Phalange",
    W3: "Countess Buffay"
  },
  106: {
    R: "The Moist Maker",
    W1: "The Crunch Bite",
    W2: "The Geller Burger",
    W3: "Super Turkey Sandwich"
  },
  109: {
    R: "Crap Bag",
    W1: "Bean Can",
    W2: "Dirty Sock",
    W3: "Trash Can"
  },
  115: {
    R: "The Shining",
    W1: "Carrie",
    W2: "Misery",
    W3: "Pet Sematary"
  },
  116: {
    R: "Little Women",
    W1: "Pride and Prejudice",
    W2: "Jane Eyre",
    W3: "Wuthering Heights"
  },
  142: {
    R: "Crap Bag",
    W1: "Trash Can",
    W2: "Dirty Sock",
    W3: "Bean Can"
  },
  157: {
    R: "I Got Off The Plane",
    W1: "I Love You Ross",
    W2: "We Are On A Break",
    W3: "I Am Staying in New York"
  },
  211: {
    R: "I Got Off The Plane",
    W1: "I Love You Ross",
    W2: "We Are On A Break",
    W3: "I Am Staying in New York"
  },
  239: {
    R: "Regina Phalange",
    W1: "Princess Consuela",
    W2: "Gladys",
    W3: "Glynnis"
  },
  240: {
    R: "Ken Adams",
    W1: "Holden McGroin",
    W2: "Joseph Stalin",
    W3: "Flame Boy"
  },
  243: {
    R: "Je m'appelle Claude",
    W1: "Bonjour mon ami",
    W2: "Merci beaucoup",
    W3: "Au revoir monsieur"
  },
  244: {
    R: "Apothecary Table",
    W1: "Dining Table",
    W2: "Coffee Table",
    W3: "Bookshelf"
  },
  248: {
    R: "Gladys",
    W1: "Glynnis",
    W2: "Bella",
    W3: "Rosita"
  },
  264: {
    R: "Gladys and Glynnis",
    W1: "Bella and Stella",
    W2: "Rosita and Maria",
    W3: "Emma and Ella"
  },
  269: {
    R: "Ichiban",
    W1: "Tokyo Shine",
    W2: "Samurai Blue",
    W3: "Nippon Style"
  },
  270: {
    R: "Ichiban! Lipstick for men",
    W1: "Tokyo power for modern men",
    W2: "Samurai shine for your smile",
    W3: "Nippon beauty for brave men"
  },
  277: {
    R: "Science Boy",
    W1: "Dinosaur Boy",
    W2: "Space Boy",
    W3: "Nature Boy"
  },
  280: {
    R: "Soapy Award",
    W1: "Golden Globe Award",
    W2: "Daytime Emmy Award",
    W3: "People's Choice Award"
  },
  294: {
    R: "Vogue",
    W1: "Cosmopolitan",
    W2: "Elle",
    W3: "Marie Claire"
  },
  297: {
    R: "Je m'appelle Claude",
    W1: "Bonjour mon ami",
    W2: "Merci beaucoup",
    W3: "Au revoir monsieur"
  },
  300: {
    R: "Baby Got Back",
    W1: "Smelly Cat",
    W2: "The Lion Sleeps Tonight",
    W3: "Twinkle Twinkle Little Star"
  },
  322: {
    R: "15 Yemen Road, Yemen",
    W1: "Old Embassy District, Sana'a",
    W2: "Airport Express Highway 22",
    W3: "Central Tahrir Square, Sana'a"
  },
  323: {
    R: "18 pages front and back!",
    W1: "A whole book of rules!",
    W2: "A dramatic novel!",
    W3: "Dozens of complaints!"
  },
  327: {
    R: "Freud! The Musical",
    W1: "Les Miserables",
    W2: "Othello The Musical",
    W3: "A Midsummer Night's Dream"
  },
  342: {
    R: "It's All Relative",
    W1: "Ancient Romances",
    W2: "Theatrical Arts",
    W3: "Adolescent Secrets"
  },
  348: {
    R: "Aortic Pump",
    W1: "Ventricular Chamber",
    W2: "Cardio Magnifico",
    W3: "Blood Circulator"
  },
  351: {
    R: "Old Yeller",
    W1: "Bambi",
    W2: "E.T.",
    W3: "The Wizard of Oz"
  },
  353: {
    R: "The Moist Maker",
    W1: "The Crunch Bite",
    W2: "The Geller Burger",
    W3: "Super Turkey Sandwich"
  },
  356: {
    R: "Way! No Way!",
    W1: "The College Rockers",
    W2: "The Retro Synth Boys",
    W3: "Blackout New York"
  },
  361: {
    R: "Frankie Say Relax",
    W1: "New York Yankees",
    W2: "Rolling Stones",
    W3: "Nerd For Life"
  },
  383: {
    R: "Aux Buttes Chaumont",
    W1: "Le Chat Noir",
    W2: "Moulin Rouge",
    W3: "Cacao Paysan"
  },
  386: {
    R: "The One With",
    W1: "Episode Of",
    W2: "Story With",
    W3: "Chapter In"
  },
  388: {
    R: "Rosita",
    W1: "Bella",
    W2: "Mia",
    W3: "Stella"
  },
  389: {
    R: "Where",
    W1: "Why",
    W2: "When",
    W3: "Here"
  },
  397: {
    R: "Dr. Drake Ramoray",
    W1: "Dr. Stryker Cooper",
    W2: "Dr. Lance Baker",
    W3: "Dr. Philip Ross"
  },
  403: {
    R: "Baby Kangaroo Tribbiani",
    W1: "Magnifico Joey Primo",
    W2: "Joey Joey Kangaroo",
    W3: "Little Joe Kangaroo"
  },
  404: {
    R: "Mrs. Whiskerson",
    W1: "Bella",
    W2: "Kitty",
    W3: "Miss Fifi"
  },
  405: {
    R: "Pat the Dog",
    W1: "Barney",
    W2: "Spike",
    W3: "Bruno"
  },
  406: {
    R: "Hugsy",
    W1: "Bingo",
    W2: "Willy",
    W3: "Sparky"
  },
  407: {
    R: "The Velveteen Rabbit",
    W1: "The Secret Garden",
    W2: "Alice in Wonderland",
    W3: "Peter Pan"
  }
};

// Helper to clean Arabic text from stray English tags (like "Season 5" or "Nubbin")
function cleanArabicChoice(str) {
  if (!str) return '';
  let cleaned = str;
  // If the choice is mostly Arabic with an English suffix/subword (e.g. "حلمة ثالثة إضافية Nubbin" -> "حلمة ثالثة إضافية")
  cleaned = cleaned.replace(/\s*[a-zA-Z0-9_!'-]+(\s+[a-zA-Z0-9_!'-]+)*\s*$/g, function(match) {
    // Only strip trailing English if there is already Arabic content before it
    return '';
  });
  // Clean multiple spaces and trim
  cleaned = cleaned.replace(/\s+/g, ' ').trim();
  // If stripping emptied it, return original
  return cleaned || str.trim();
}

const refinedFriends = [];

for (let i = 0; i < orig.length; i++) {
  if (dupes.has(i)) continue;

  const q = orig[i];

  if (englishOverride[i]) {
    // Specific iconic English term/quote
    const eng = englishOverride[i];
    refinedFriends.push({
      Level: q.Level || '0',
      Q: q.Q,
      R: eng.R,
      W1: eng.W1,
      W2: eng.W2,
      W3: eng.W3,
      Category: 'مسلسل Friends'
    });
  } else {
    // Pure Arabic question / narrative / story / reason
    // Clean any stray English from Arabic choices
    let r = cleanArabicChoice(q.R);
    let w1 = cleanArabicChoice(q.W1);
    let w2 = cleanArabicChoice(q.W2);
    let w3 = cleanArabicChoice(q.W3);

    refinedFriends.push({
      Level: q.Level || '0',
      Q: q.Q,
      R: r,
      W1: w1,
      W2: w2,
      W3: w3,
      Category: 'مسلسل Friends'
    });
  }
}

console.log('Refined Friends questions total:', refinedFriends.length);

// Check distinct and validity
for (let i = 0; i < refinedFriends.length; i++) {
  const item = refinedFriends[i];
  const choices = [item.R, item.W1, item.W2, item.W3];
  const u = new Set(choices.map(c => c.trim().toLowerCase()));
  if (u.size !== 4) {
    console.error(`Index ${i} choices not distinct:`, choices);
  }
}

fs.writeFileSync(path.resolve(__dirname, 'refined_friends.json'), JSON.stringify(refinedFriends, null, 2), 'utf8');
console.log('Saved tools/friends/refined_friends.json');
