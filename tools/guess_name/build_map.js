const fs = require('fs');

const choices = JSON.parse(fs.readFileSync('./tools/guess_name/foreign_choices_all.json', 'utf8'));

// Initial base map of known characters, scientists, philosophers, figures
const map = {
  // Pop culture / superheroes
  "سبايدرمان": "Spider-Man",
  "باتمان": "Batman",
  "سوبرمان": "Superman",
  "فلاش": "The Flash",
  "آيرون مان": "Iron Man",
  "ثور": "Thor",
  "هالك": "Hulk",
  "جيمس بوند": "James Bond",
  "هاري بوتر": "Harry Potter",
  "لوفي": "Monkey D. Luffy",
  "زورو": "Roronoa Zoro",
  "ناروتو": "Naruto Uzumaki",
  "بيكاتشو": "Pikachu",
  "سبونج بوب": "SpongeBob SquarePants",
  "بسيط نجم": "Patrick Star",
  "شفيق": "Squidward Tentacles",
  "مستر سلطع": "Mr. Krabs",
  "توم وجيري": "Tom and Jerry",
  "تيمون وبومبا": "Timon and Pumbaa",
  "روبن هود": "Robin Hood",
  "بيتر بان": "Peter Pan",
  "بينوكيو": "Pinocchio",
  "طرزان": "Tarzan",
  "ماوكلي": "Mowgli",
  "ماكوين": "Lightning McQueen",
  "إلسا": "Elsa",
  "رابونزل": "Rapunzel",
  "سنو وايت": "Snow White",
  "سندريلا": "Cinderella",
  "الجميلة والوحش": "Beauty and the Beast",
  "أرييل": "Ariel",
  "سونيك": "Sonic the Hedgehog",
  "ماريو": "Mario",
  "يوشي": "Yoshi",
  "دونكي كونغ": "Donkey Kong"
};

console.log('Choices count:', choices.length);
