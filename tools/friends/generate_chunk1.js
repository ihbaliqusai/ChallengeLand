const chunk1 = [
  // 0 - 9
  {
    R: "6 characters",
    W1: "4 characters",
    W2: "5 characters",
    W3: "8 characters"
  },
  {
    R: "Central Perk",
    W1: "Central Park Cafe",
    W2: "Brooklyn Beans",
    W3: "Manhattan Coffee"
  },
  {
    R: "New York",
    W1: "Chicago",
    W2: "Los Angeles",
    W3: "Boston"
  },
  {
    R: "Paleontologist",
    W1: "General Surgeon",
    W2: "Architect",
    W3: "History Professor"
  },
  {
    R: "Chef",
    W1: "Fashion Designer",
    W2: "Bank Manager",
    W3: "School Teacher"
  },
  {
    R: "Waitress",
    W1: "Fashion Assistant",
    W2: "Receptionist",
    W3: "Runway Model"
  },
  {
    R: "Actor",
    W1: "Film Director",
    W2: "Novelist",
    W3: "Musician"
  },
  {
    R: "Acoustic Guitar",
    W1: "Piano",
    W2: "Violin",
    W3: "Saxophone"
  },
  {
    R: "Smelly Cat",
    W1: "Grandma's Shoe",
    W2: "The Christmas Tree",
    W3: "Snowstorm"
  },
  {
    R: "Ross and Monica",
    W1: "Chandler and Joey",
    W2: "Rachel and Phoebe",
    W3: "Ross and Rachel"
  },

  // 10 - 19
  {
    R: "Chandler and Joey",
    W1: "Ross and Chandler",
    W2: "Joey and Ross",
    W3: "Mike and Chandler"
  },
  {
    R: "Orange",
    W1: "Red",
    W2: "Green",
    W3: "Brown"
  },
  {
    R: "Purple",
    W1: "Sky Blue",
    W2: "Bright Yellow",
    W3: "Olive Green"
  },
  {
    R: "Yellow Picture Frame",
    W1: "Round Mirror",
    W2: "Brass Bell",
    W3: "Wooden Plaque"
  },
  {
    R: "Gunther",
    W1: "Mr. Treeger",
    W2: "Paolo",
    W3: "David"
  },
  {
    R: "How You Doin",
    W1: "Whats Up Man",
    W2: "Hey Beautiful",
    W3: "Good To See You"
  },
  {
    R: "Janice",
    W1: "Carol",
    W2: "Emily",
    W3: "Susan"
  },
  {
    R: "Oh My God",
    W1: "No Way",
    W2: "Here We Go",
    W3: "Look At You"
  },
  {
    R: "Monkey",
    W1: "Dog",
    W2: "Cat",
    W3: "Parrot"
  },
  {
    R: "Marcel",
    W1: "George",
    W2: "Charlie",
    W3: "Rocky"
  },

  // 20 - 29
  {
    R: "Chick and Duck",
    W1: "Parrot and Pigeon",
    W2: "Rooster and Falcon",
    W3: "Peacock and Seagull"
  },
  {
    R: "Carol",
    W1: "Emily",
    W2: "Susan",
    W3: "Mona"
  },
  {
    R: "Ben",
    W1: "Jack",
    W2: "Sam",
    W3: "Tom"
  },
  {
    R: "Chandler Bing",
    W1: "Richard Burke",
    W2: "Pete Becker",
    W3: "Joey Tribbiani"
  },
  {
    R: "Ross and Rachel",
    W1: "Monica and Chandler",
    W2: "Phoebe and Joey",
    W3: "Ross and Phoebe"
  },
  {
    R: "Emma",
    W1: "Ella",
    W2: "Amy",
    W3: "Isabella"
  },
  {
    R: "Obsession with cleanliness and order",
    W1: "Extreme laziness",
    W2: "Constant forgetfulness",
    W3: "Reckless adventure"
  },
  {
    R: "Joey doesn't share food",
    W1: "Strict vegetarian",
    W2: "Only eats sweets",
    W3: "Hates pizza"
  },
  {
    R: "Pizza and Meatball Sub",
    W1: "Vegetable Pasta",
    W2: "Vegetarian Lasagna",
    W3: "Caesar Salad"
  },
  {
    R: "Ross and Chandler",
    W1: "Joey and Chandler",
    W2: "Ross and Joey",
    W3: "Mike and Ross"
  },

  // 30 - 39
  {
    R: "White Wedding Dress",
    W1: "Graduation Gown",
    W2: "Sportswear",
    W3: "Red Evening Gown"
  },
  {
    R: "Barry",
    W1: "Paolo",
    W2: "Mark",
    W3: "Tag"
  },
  {
    R: "Ill Be There for You",
    W1: "Stand by Me",
    W2: "With a Little Help",
    W3: "Time of Your Life"
  },
  {
    R: "The Rembrandts",
    W1: "The Beatles",
    W2: "U2",
    W3: "Green Day"
  },
  {
    R: "10 Seasons",
    W1: "8 Seasons",
    W2: "12 Seasons",
    W3: "9 Seasons"
  },
  {
    R: "We Were On A Break",
    W1: "It Was A Mistake",
    W2: "I Loved You",
    W3: "I Forgot Everything"
  },
  {
    R: "Pivot",
    W1: "Push",
    W2: "Turn",
    W3: "Lift"
  },
  {
    R: "Paris",
    W1: "London",
    W2: "Rome",
    W3: "Madrid"
  },
  {
    R: "Paolo",
    W1: "Mario",
    W2: "Vito",
    W3: "Marco"
  },
  {
    R: "Vintage Cameo Brooch",
    W1: "Pearl Necklace",
    W2: "Classic Watch",
    W3: "Gold Ring"
  },

  // 40 - 49
  {
    R: "China",
    W1: "Japan",
    W2: "Egypt",
    W3: "Mexico"
  },
  {
    R: "Pros and cons list of Rachel and Julie",
    W1: "List of top movies",
    W2: "Party guest list",
    W3: "Flight ticket prices list"
  },
  {
    R: "Central Perk",
    W1: "Museum of Natural History",
    W2: "Monica's Apartment",
    W3: "JFK Airport"
  },
  {
    R: "The Planetarium",
    W1: "Las Vegas Hotel",
    W2: "Montauk Beach",
    W3: "Central Park"
  },
  {
    R: "He didn't want more children",
    W1: "He traveled too much",
    W2: "Her parents disapproved",
    W3: "Different daily hobbies"
  },
  {
    R: "Melting plastic with fire",
    W1: "Collecting vintage stamps",
    W2: "Breeding reptiles",
    W3: "Night fishing"
  },
  {
    R: "18 pages front and back",
    W1: "5 printed pages",
    W2: "10 handwritten pages",
    W3: "2 short pages"
  },
  {
    R: "He fell asleep while reading it",
    W1: "He lost it in the ocean",
    W2: "He tore it up in anger",
    W3: "He gave it to Chandler"
  },
  {
    R: "Touch football game",
    W1: "Basketball in the park",
    W2: "Sprint race",
    W3: "Bowling tournament"
  },
  {
    R: "A troll doll nailed to a 2x4",
    W1: "A broken silver trophy",
    W2: "An antique bronze clock",
    W3: "An engraved gold medal"
  },

  // 50 - 59
  {
    R: "Dr. Drake Ramoray",
    W1: "Dr. Richard Burke",
    W2: "Dr. Robert Green",
    W3: "Dr. Thomas Miller"
  },
  {
    R: "Days of Our Lives",
    W1: "General Hospital",
    W2: "Passions",
    W3: "All My Children"
  },
  {
    R: "He fell down an elevator shaft",
    W1: "He died in a car crash",
    W2: "He moved to another hospital",
    W3: "He got lost in the desert"
  },
  {
    R: "Chandler peed on her leg to ease the pain",
    W1: "She went to the nearest emergency room",
    W2: "She put ice packs on the sting",
    W3: "She rubbed warm sand on the sting"
  },
  {
    R: "A rooster and a duck",
    W1: "A big police dog",
    W2: "A rare water turtle",
    W3: "A colorful desert snake"
  },
  {
    R: "Trivia quiz game against Chandler and Joey",
    W1: "Cooking and dessert baking competition",
    W2: "New Year's Eve poker game",
    W3: "Speed dancing contest in the park"
  },
  {
    R: "What is Chandler Bing's real job?",
    W1: "What is Chandler Bing's middle name?",
    W2: "What is Chandler Bing's monthly salary?",
    W3: "What was Chandler's first elementary school?"
  },
  {
    R: "Transponster",
    W1: "Financial Accountant",
    W2: "Marketing Director",
    W3: "Systems Programmer"
  },
  {
    R: "They kissed each other for one minute",
    W1: "They paid a large sum of cash",
    W2: "They won a rematch trivia game",
    W3: "They threatened to evict the pets"
  },
  {
    R: "Said Rachel's name at the altar",
    W1: "Forgot the wedding rings at the hotel",
    W2: "Arrived two hours late to the ceremony",
    W3: "Knocked over the wedding cake"
  },

  // 60 - 69
  {
    R: "In London at Ross's wedding",
    W1: "In Montauk at the beach house",
    W2: "In Joey's apartment during a party",
    W3: "In Central Perk after hours"
  },
  {
    R: "My Eyes My Eyes",
    W1: "Oh My God",
    W2: "Look At Them",
    W3: "They Are In Love"
  },
  {
    R: "Saw them kissing through his apartment window",
    W1: "Joey told him the truth at Central Perk",
    W2: "Found a love letter in the living room",
    W3: "Overheard them talking on the phone"
  },
  {
    R: "He shot a singing bird outside the bedroom window",
    W1: "She found out he was married with kids",
    W2: "He refused to listen to her music",
    W3: "He tried to arrest Joey at the cafe"
  },
  {
    R: "A beard and mustache in permanent marker",
    W1: "Black sunglasses with a marker",
    W2: "A full Batman face mask",
    W3: "Random numbers and symbols on his forehead"
  },
  {
    R: "Getting married at a Las Vegas wedding chapel",
    W1: "Gambling all their savings on roulette",
    W2: "Buying a beach house together",
    W3: "Attending a private rock concert"
  },
  {
    R: "Regular clothes with ink doodles on their faces",
    W1: "Tuxedo and white wedding gown",
    W2: "Cowboy and showgirl costumes",
    W3: "Hotel bathrobes and slippers"
  },
  {
    R: "English trifle with beef and peas",
    W1: "Burnt apple pie with spicy cheese",
    W2: "Chocolate cake stuffed with fish",
    W3: "Banana pudding mixed with tomato sauce"
  },
  {
    R: "Tight black leather",
    W1: "Stretch skinny denim",
    W2: "Smooth natural silk",
    W3: "Heavy wool fabric"
  },
  {
    R: "Body lotion and baby powder",
    W1: "Liquid soap and boiling water",
    W2: "Olive oil and shampoo",
    W3: "Toothpaste and club soda"
  },

  // 70 - 79
  {
    R: "Teeth glowed intensely under black light",
    W1: "Severe gum inflammation and swelling",
    W2: "Chipped his front teeth enamel",
    W3: "Teeth turned bright yellow"
  },
  {
    R: "Unagi and a state of total awareness",
    W1: "Tiger fighting karate style",
    W2: "Fast momentum judo",
    W3: "Inner balance taekwondo"
  },
  {
    R: "Freshwater eel in sushi",
    W1: "Ancient African dance rhythm",
    W2: "Total relaxation in Japanese",
    W3: "A remote island in the Pacific"
  },
  {
    R: "Porsche sports car",
    W1: "Red Ferrari coupe",
    W2: "Classic Mercedes sedan",
    W3: "BMW convertible"
  },
  {
    R: "Wore full Porsche gear and covered cardboard boxes",
    W1: "Bought a used car of the same color",
    W2: "Rented another sports car for the day",
    W3: "Searched the street for another set of keys"
  },
  {
    R: "An ancient erotic cassette tape of Richard",
    W1: "A secret stash of cash in the ceiling",
    W2: "A hidden diary of his college years",
    W3: "An old marriage certificate with Janice"
  },
  {
    R: "Unpaid intern alongside young college kids",
    W1: "Campaign creative executive director",
    W2: "International marketing consultant",
    W3: "Senior commercial copywriter"
  },
  {
    R: "Performed their goofy high school Routine dance",
    W1: "Won the studio best couple award",
    W2: "Fell off the main dancing platform",
    W3: "Met a Hollywood celebrity backstage"
  },
  {
    R: "Bruce Willis as Paul",
    W1: "Brad Pitt as Will",
    W2: "George Clooney as Dr. Michael",
    W3: "Tom Selleck as Richard"
  },
  {
    R: "Singing to himself that he is a neat guy and love machine",
    W1: "Practicing fierce shadow boxing moves",
    W2: "Crying over his late wife's portrait",
    W3: "Trying on an extravagant fake wig"
  },

  // 80 - 89
  {
    R: "Vintage diamond ring from an antique shop",
    W1: "Gold ring set with a large ruby",
    W2: "Simple plain platinum wedding band",
    W3: "Heirloom silver filigree ring"
  },
  {
    R: "Monica got down on one knee and proposed to him",
    W1: "Cooked a lavish gourmet dinner alone",
    W2: "Surprised him with all their friends",
    W3: "Handed him two round-trip tickets to Paris"
  },
  {
    R: "His handsome looks and attractive charm",
    W1: "He was related to a top company executive",
    W2: "He was completely fluent in French",
    W3: "He had a master's degree from Harvard"
  },
  {
    R: "30 years old",
    W1: "25 years old",
    W2: "35 years old",
    W3: "28 years old"
  },
  {
    R: "Red sports convertible wedged between cars",
    W1: "High-speed touring motorcycle",
    W2: "Luxury Caribbean sailing cruise",
    W3: "Rare vintage gold wristwatch"
  },
  {
    R: "Blood-stained World War I soldier uniform",
    W1: "Official NYPD police dress uniform",
    W2: "Crisp white naval captain uniform",
    W3: "Medieval armor knight costume"
  },
  {
    R: "Red sweater left behind in Monica's apartment",
    W1: "Recorded voicemail on the telephone",
    W2: "Secret photo taken together in Central Perk",
    W3: "Direct confession from Joey to Chandler"
  },
  {
    R: "Backpacking across Western Europe near Mount Tibidabo",
    W1: "Rescuing a lost child in the Amazon rainforest",
    W2: "Astronaut training mission to Mars",
    W3: "Deep sea diving with sharks in Australia"
  },
  {
    R: "Giant pink velvet bunny costume",
    W1: "Sparkling silver astronaut suit",
    W2: "Classic Santa Claus velvet suit",
    W3: "Roman gladiator soldier armor"
  },
  {
    R: "Spudnik as a potato satellite",
    W1: "Giant roaring T-Rex dinosaur",
    W2: "Ancient Egyptian pharaoh mummy",
    W3: "Prehistoric stone-age caveman"
  },

  // 90 - 99
  {
    R: "Bright blue lipstick for men",
    W1: "Face moisturizer with gold flakes",
    W2: "Clear shiny men's nail polish",
    W3: "Ocean breeze scented body cologne"
  },
  {
    R: "In 1994",
    W1: "In 1990",
    W2: "In 1998",
    W3: "In 2000"
  },
  {
    R: "The Duck and The Chick",
    W1: "Parrot and Pigeon",
    W2: "Goose and Seagull",
    W3: "Falcon and Eagle"
  },
  {
    R: "In an enclosed ATM vestibule",
    W1: "In a commercial bank elevator",
    W2: "In a stalled subway train car",
    W3: "In a street public phone booth"
  },
  {
    R: "Baby Ben in his stroller",
    W1: "Phoebe's puppy Clunkers",
    W2: "Joey's theater audition wardrobe",
    W3: "Chandler's expensive leather jacket"
  },
  {
    R: "Theater and television acting",
    W1: "Opera singing and choir",
    W2: "Contemporary abstract painting",
    W3: "Classical piano performance"
  },
  {
    R: "Masseuse and massage therapist",
    W1: "In-home private nurse",
    W2: "Cosmetology and makeup artist",
    W3: "Nutrition and wellness specialist"
  },
  {
    R: "Smelly Cat",
    W1: "Crazy Dog",
    W2: "Little Black Curly Hair",
    W3: "Two of Them Kissed"
  },
  {
    R: "Cheesecake from Mama's Little Bakery in Chicago",
    W1: "Caramel chocolate fudge cake",
    W2: "Cinnamon spiced apple pie",
    W3: "French strawberry cream tart"
  },
  {
    R: "Barbados",
    W1: "Hawaii",
    W2: "Jamaica",
    W3: "Bali"
  }
];

module.exports = chunk1;
