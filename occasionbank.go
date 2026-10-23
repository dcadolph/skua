package skua

// partyPacks holds every occasion's bank. Placeholders in braces are filled
// from the forecast, the same as the everyday voice. Every pack must cover
// every mood, phase, and heat; the tests hold it to that.
var partyPacks = map[Occasion]partyPack{
	OccasionBachelorette: bachelorettePack,
	OccasionBachelor:     bachelorPack,
}

// bachelorettePack is the bride squad's weekend voice.
var bachelorettePack = partyPack{
	lines: map[partyMood]map[Heat][]string{
		moodSunny: {
			HeatDirty: {
				"{temp} and sunny. The sky is showing more skin than the bride will tonight. Probably.",
				"Not a cloud in sight, so nothing is covering anything up today. Sunscreen on the bits you plan to show off.",
				"Gorgeous out, {high} at the top. Perfect weather for mimosas and terrible eye contact with the bartender.",
			},
			HeatKinky: {
				"Sun's out and it wants you tied to a lounge chair. The safe word is sunscreen.",
				"{temp} and clear. The sun is going to spank anyone who skipped SPF. Hard.",
				"Blue sky, {high} later. Somebody pack the handcuffs and the aloe, in that order.",
			},
			HeatRaunchy: {
				"{temp} and sunny as hell. Tits out to the sun, but rub some fucking SPF 50 on them first.",
				"Clear skies, {high} by afternoon. Day drinking weather. Pace yourselves, it's a marathon, not a keg stand.",
				"The sun is out and so are the bridesmaids' standards. Water between shots.",
			},
			HeatSlut: {
				"{temp}, cloudless, and the sun is going to fuck everyone raw today. Wrap it up in SPF.",
				"The sky is naked and so should you be. Spiritually. Legally, wear a bikini. Sunscreen everywhere it touches.",
				"Perfect day to get railed by the sun and then by bottomless mimosas. Water in between, you magnificent sluts.",
			},
		},
		moodHot: {
			HeatDirty: {
				"{feels} out there. Hotter than the bride's search history.",
				"It's {temp}. Everyone is going to be sweaty and nobody even had to try.",
				"Heat's on, {high} later. Ice in the drinks, ice down the top, whatever works.",
			},
			HeatKinky: {
				"{feels} and the sun is into breath play today. Shade, water, no heroics.",
				"Hot as a dungeon out there, {high} by afternoon. Wear leather at your own risk.",
				"It's {temp}. The wet T-shirt contest is now a public health measure.",
			},
			HeatRaunchy: {
				"{feels} and sticky as fuck. Chafing is real, ladies. Powder the thighs.",
				"So hot the stripper is going to show up already naked. {high} later. Drink water like it's tequila.",
				"{temp} and climbing. Sweat through the sundress, hydrate through the hangover.",
			},
			HeatSlut: {
				"{feels}. Hotter than the bride's last bad decision and twice as sweaty. One water per shot or you're out.",
				"It's {temp} and everyone's thighs are slapping together like applause. Body glide, bitches.",
				"Satan called and wants his weather back. {high} today. Strip down, drink up, water in between.",
			},
		},
		moodNight: {
			HeatDirty: {
				"Clear night, {temp}. Stars out, bride out, everybody behave. Ish.",
				"{temp} and starry. Lovely night for a walk of shame, later.",
				"Clear and {temp}. Bring a jacket you won't mind leaving at the club.",
			},
			HeatKinky: {
				"{temp} under the stars. Somebody is getting blindfolded tonight and it isn't the moon.",
				"Clear sky, {temp}. Nipples will be on high alert. Bring a layer.",
				"Starry, {temp}. The moon is watching. Give it a show.",
			},
			HeatRaunchy: {
				"{temp} and clear as hell. Cold enough to cut glass with your nipples. Jacket.",
				"Clear night, {temp}. Perfect for bad tattoos, worse decisions, and one Uber home.",
				"Stars out, legs out, bad ideas out. {temp}, so pack a layer, you animals.",
			},
			HeatSlut: {
				"{temp} and clear. Somebody is making out with a stranger by 1 AM and it's going to be beautiful.",
				"Starry night, {temp}. The moon's out, the girls are out, and the bride's bar tab is wide open. Water before bed.",
				"Clear, {temp}, and the night is wide open. So are everyone's legs on that dance floor. Jacket in the bag.",
			},
		},
		moodGloomy: {
			HeatDirty: {
				"Gray and {temp}. The sky is hungover too, so you're in good company.",
				"Overcast. The sky is being modest today. Someone has to be.",
				"{cond} at {temp}. Moody lighting, very flattering for a hangover.",
			},
			HeatKinky: {
				"{cond}. The sky put on a blindfold. Kinky.",
				"Gray and {temp}. Perfect day to stay in bed, and not for sleeping.",
				"Fog's in thick. You can't see five feet, which is great news for whatever happens tonight.",
			},
			HeatRaunchy: {
				"Gray as fuck, {temp}. The sky looks like the bride's mascara at 3 AM. Sunglasses anyway.",
				"{cond}. Hangover weather. Greasy food, cold brew, and an Advil chaser.",
				"Fog thick enough that nobody can see the walk of shame. You're welcome.",
			},
			HeatSlut: {
				"{cond}. Even the sky is doing the walk of shame. It'll burn off by noon, just like you.",
				"Gray, damp, {temp}. The sky is as foggy as last night. Electrolytes, sluts.",
				"Fog city. Perfect cover for whoever is sneaking out of whose room. Don't trip on the way.",
			},
		},
		moodWet: {
			HeatDirty: {
				"Rain today, {rain} chance. Getting wet was always on the itinerary.",
				"{cond}. Wet and wild, minus the wild. Umbrella.",
				"Rain on the bride's weekend is good luck. Allegedly. Bring an umbrella anyway.",
			},
			HeatKinky: {
				"{cond}. Wet and dripping, and you didn't even have to ask. Umbrella.",
				"Rain coming, {rain} odds. The wet T-shirt contest is now weather-sanctioned.",
				"It's wet out there. Take it inside and get creative.",
			},
			HeatRaunchy: {
				"It's pissing rain. The sky broke the seal before you did.",
				"Wet as hell out there, {rain} chance. Ruin your hair or bring a fucking umbrella.",
				"{cond}. Indoor party now. Body shots, bad karaoke, worse dancing.",
			},
			HeatSlut: {
				"The sky is squirting all over the place. {rain} odds. Umbrella, or own it.",
				"Rain. The clouds are getting off on ruining your blowout. Hood up, drink up.",
				"It's soaking wet and so is every dress in this group. Umbrellas and an indoor plan, you filthy animals.",
			},
		},
		moodCold: {
			HeatDirty: {
				"{temp}. Cold enough that everyone's headlights are on.",
				"Chilly, {temp}. Cuddle up with whoever is closest. Bridesmaids count.",
				"{temp}. Wear the jacket. Nobody is impressed by goosebumps.",
			},
			HeatKinky: {
				"{temp}. Nipples like diamond cutters. Layer up or lean in.",
				"Cold, {temp}. Body heat is free. Share it.",
				"{temp} out. Something is going to be stiff tonight and it's your toes. Socks.",
			},
			HeatRaunchy: {
				"{temp}. Cold as the bride's ex's heart. Jacket, you idiots.",
				"It's {temp}. Shrinkage weather for the boys, nipple weather for you. Layers.",
				"{temp} and biting. Hot toddies count as hydration. They do not.",
			},
			HeatSlut: {
				"{temp}. Too cold for slut season, which is a crime. Jacket over the outfit, peel it off inside.",
				"Freezing, {temp}. Climb on whoever is warmest. For survival.",
				"{temp}. Your tits could cut glass. Coat on until the club.",
			},
		},
		moodWind: {
			HeatDirty: {
				"Windy, gusts to {gust}. Marilyn moment incoming. Shorts under the sundress.",
				"Blowing {wind} out there. Hold on to your veils.",
				"Breezy, gusts to {gust}. Your hair has a mind of its own today.",
			},
			HeatKinky: {
				"Gusts to {gust}. The wind is going up skirts uninvited. Rude.",
				"{wind} winds. Something is getting blown today and it's your hat.",
				"Windy as hell. Tie everything down. Yes, everything.",
			},
			HeatRaunchy: {
				"Wind ripping at {gust}. Flash the whole street or wear a fucking romper.",
				"{wind} and gusty. Everything is getting blown today. Hair, hats, the budget.",
				"Gusts to {gust}. Your veil is going to end up in Nevada. Bobby pins.",
			},
			HeatSlut: {
				"Wind blowing {gust} like it's getting paid. Pin the veil, skip the skirt.",
				"Gusty as fuck. Nothing under that dress? The whole beach will know. Choose wisely.",
				"Wind's blowing at {gust}. It is not the only thing getting blown this weekend. Pin the veil.",
			},
		},
	},
	openers: map[partyPhase]map[Heat][]string{
		phaseMorning: {
			HeatDirty:   {"Morning, bride squad.", "Rise and shine, or at least rise."},
			HeatKinky:   {"Morning. Untie whoever needs untying.", "Wake up. Somebody is still wearing last night's handcuffs."},
			HeatRaunchy: {"Morning, you hungover disasters.", "Rise and regret, ladies."},
			HeatSlut:    {"Morning, sluts. Count heads and count bras.", "Wake up, walk-of-shame crew. Coffee is a food group."},
		},
		phaseAfternoon: {
			HeatDirty:   {"Afternoon. Day drinking is a sport and you're in season.", "Afternoon. Pool, sunglasses, and something pink in a glass."},
			HeatKinky:   {"Afternoon. Prime time for poolside trouble.", "Afternoon. Somebody rub lotion on the bride. Slowly."},
			HeatRaunchy: {"Afternoon. If you're not two drinks deep, what the fuck are you doing.", "Afternoon. Edibles now or edibles never."},
			HeatSlut:    {"Afternoon. The edibles are kicking in soon. Plan accordingly.", "Afternoon. Bikinis on, inhibitions off, phones on airplane mode."},
		},
		phaseEvening: {
			HeatDirty:   {"Evening. Time to get dolled up and get in trouble.", "Evening. Lipstick on, bride in front."},
			HeatKinky:   {"Evening. Pregame, then play.", "Evening. Heels on, cuffs in the clutch."},
			HeatRaunchy: {"Evening. Glitter on, standards off.", "Evening. Shots, outfits, and a group photo before anyone falls down."},
			HeatSlut:    {"Evening. Penis straws locked and loaded.", "Evening. Somebody tell the stripper the address. Somebody else tell him again."},
		},
		phaseLate: {
			HeatDirty:   {"Late night. Nothing good happens after midnight, so go find out.", "Late. One more round, then bed. You won't."},
			HeatKinky:   {"Late. The safe word is Uber.", "Late. Whatever happens next, the moon saw it."},
			HeatRaunchy: {"It's late as fuck. Pizza, water, bed, in that order.", "Late. Heels off, tacos on."},
			HeatSlut:    {"Late night. Whatever happens in California dies in the group chat.", "Late. If you're reading this, drink a water and find your bridesmaid."},
		},
	},
	advice: map[partyMood]map[Heat]string{
		moodSunny: {
			HeatDirty:   "Sunscreen, sunglasses, and a water for every mimosa.",
			HeatKinky:   "SPF everywhere, and we mean everywhere.",
			HeatRaunchy: "Reapply sunscreen every two drinks, you lobsters in waiting.",
			HeatSlut:    "Sunscreen on every inch you plan to show off, so all of it.",
		},
		moodHot: {
			HeatDirty:   "Water between every drink and shade when you can.",
			HeatKinky:   "Water, shade, and save the leather for after dark.",
			HeatRaunchy: "One water per shot, or somebody is puking in the Uber.",
			HeatSlut:    "Water every round. Heatstroke is not hot.",
		},
		moodNight: {
			HeatDirty:   "Bring a jacket and charge your phone.",
			HeatKinky:   "Layer up and share your location with the group.",
			HeatRaunchy: "Jacket, charged phone, and nobody leaves alone.",
			HeatSlut:    "Buddy system, jacket, and a water before you pass out.",
		},
		moodGloomy: {
			HeatDirty:   "Coffee, carbs, and sunglasses.",
			HeatKinky:   "Breakfast in bed, then a light layer for later.",
			HeatRaunchy: "Electrolytes, eggs, and Advil. Then you may speak.",
			HeatSlut:    "Pedialyte, hash browns, and a nap before round two.",
		},
		moodWet: {
			HeatDirty:   "Umbrella, and have an indoor backup plan.",
			HeatKinky:   "Umbrella, and a cozy indoor plan.",
			HeatRaunchy: "Umbrella, roof, and a bar that does body shots.",
			HeatSlut:    "Umbrella or a waterproof attitude. Indoor plan either way.",
		},
		moodCold: {
			HeatDirty:   "Jacket now, take it off later.",
			HeatKinky:   "Layers you can peel off one at a time.",
			HeatRaunchy: "Coat over the outfit. Nobody is cute with hypothermia.",
			HeatSlut:    "Coat over the outfit until the club, then go nuts.",
		},
		moodWind: {
			HeatDirty:   "Bobby pins for the veil and shorts under the dress.",
			HeatKinky:   "Pin the veil and secure the skirt.",
			HeatRaunchy: "Pin the veil and hold on to your drink.",
			HeatSlut:    "Pin the veil and wear underwear. Seriously.",
		},
	},
}

// bachelorPack is the groom's crew's weekend voice.
var bachelorPack = partyPack{
	lines: map[partyMood]map[Heat][]string{
		moodSunny: {
			HeatDirty: {
				"{temp} and sunny. Perfect for golf you're too drunk to play.",
				"Clear skies, {high} later. Sunscreen on the bald spots, boys.",
				"Beautiful out. The groom's last sunny day as a free man. Make it count.",
			},
			HeatKinky: {
				"Sun's out, shirts off, regrets later. SPF.",
				"Clear, {high} by afternoon. The sun wants to see the dad bods. Give it the gift.",
				"{temp} and blue sky. Somebody oil up the groom. Somebody else take pictures.",
			},
			HeatRaunchy: {
				"{temp} and blue sky. Crack a beer, crack another, apply fucking sunscreen.",
				"Gorgeous out. Day drinking is mandatory and so is SPF, you pale bastards.",
				"Clear skies. The groom is going to be lobster red by noon and drunk by one.",
			},
			HeatSlut: {
				"{temp}, sunny, and the groom is about to get railed by bottomless margaritas. Water.",
				"The sky's naked, the boys are shirtless, and everyone will be burnt by 3. SPF, animals.",
				"Clear as hell, {high} later. Somebody's nipples are getting sunburnt today and it's the best man's.",
			},
		},
		moodHot: {
			HeatDirty: {
				"{feels}. Swamp ass weather. Choose breathable shorts.",
				"It's {temp}. Beer gets warm fast, so drink faster. Water too.",
				"Hot one, {high} later. Every one of you will smell like a locker room by noon.",
			},
			HeatKinky: {
				"{feels}. Hot enough to make a grown man moan. Shade.",
				"Sweaty, {high} later. Somebody bring a kiddie pool and nobody ask questions.",
				"{temp} and steamy. Shirts are optional and also a mistake.",
			},
			HeatRaunchy: {
				"{feels} and humid as balls. Literally. Gold Bond.",
				"{temp}. Your nut sack is going to stick to your leg. Powder up and hydrate.",
				"Hot as fuck, {high}. Beer is not water, no matter what the groom says.",
			},
			HeatSlut: {
				"{feels}. Hotter than the dancer the best man swears he didn't book. Water.",
				"It's {temp}. Balls sweating, beers sweating, groom sweating. Hydrate, degenerates.",
				"{high} today. Swamp crotch season. Gold Bond, cold beer, a gallon of water.",
			},
		},
		moodNight: {
			HeatDirty: {
				"Clear night, {temp}. Good for cigars and bad ideas.",
				"{temp} and starry. Somebody is sleeping in the bathtub tonight.",
				"Clear and {temp}. The groom's last wild night, and the stars are watching.",
			},
			HeatKinky: {
				"{temp} and clear. Strip club weather. Bring ones.",
				"Starry, {temp}. Whatever the groom does tonight, the moon is the only witness.",
				"Clear, {temp}. Someone is getting a lap dance and it's going to be awkward for everyone.",
			},
			HeatRaunchy: {
				"{temp} under the stars. Whiskey, cigars, and one dumbass jumping in the pool.",
				"Clear night, {temp}. Bring a hoodie. You are not as warm as the tequila says.",
				"Stars out, wallets out, dignity gone. {temp}, so grab a layer.",
			},
			HeatSlut: {
				"{temp} and clear. Make it rain singles, but not on the groom's face. Jacket.",
				"Starry as hell, {temp}. What happens tonight stays in the group chat, and the group chat is undefeated.",
				"Clear night, {temp}. Somebody is waking up in a stranger's hammock. Probably the groom.",
			},
		},
		moodGloomy: {
			HeatDirty: {
				"{cond}. The sky is hungover. Same.",
				"Gray and {temp}. Breakfast burritos and silence.",
				"Overcast, {temp}. Nobody needs to see the sun after last night.",
			},
			HeatKinky: {
				"Foggy. Can't see shit, which helps.",
				"Overcast and {temp}. Poker day, and pretending you don't feel like death.",
				"{cond}. Perfect day to lie on the couch and moan. You earned it.",
			},
			HeatRaunchy: {
				"Gray as fuck. Hair of the dog weather.",
				"{cond}. Bloody Marys and Gatorade, then decide if you're alive.",
				"{temp} and gloomy. The sky looks how the groom smells.",
			},
			HeatSlut: {
				"Fog thicker than the groom's skull after last night. Electrolytes.",
				"{cond}. The sky looks like somebody shotgunned a beer through a cloud. Same, buddy.",
				"Gray, damp, {temp}. Nobody's dick works and nobody's head works. Pedialyte.",
			},
		},
		moodWet: {
			HeatDirty: {
				"Rain, {rain} chance. The bar crawl has a roof.",
				"{cond}. Getting wet was not on the itinerary, boys.",
				"Rain today. Golf is canceled. Drinking is not.",
			},
			HeatKinky: {
				"Wet out there. Nobody is sliding into the pool today. Slide into a booth.",
				"{cond}. Steakhouse, cards, and a backup plan.",
				"Rain, {rain} odds. Wet T-shirt contest, but it's twelve hairy guys. Hard pass.",
			},
			HeatRaunchy: {
				"It's pissing rain. Find a bar with a roof and a TV.",
				"{cond}. Everyone's jeans are getting soaked and it isn't from the beer pong.",
				"Wet as hell, {rain} chance. Umbrella, you absolute goblins.",
			},
			HeatSlut: {
				"Rain coming down like the groom's bar tab. Umbrella or a roof.",
				"It's dripping out there. The only thing wetter is whatever the best man spilled. Indoors.",
				"Soaked. Strip club has a roof. Just saying.",
			},
		},
		moodCold: {
			HeatDirty: {
				"{temp}. Shrinkage advisory in effect.",
				"Chilly, {temp}. Hoodies on.",
				"{temp}. Cold enough to see your breath and smell your regret.",
			},
			HeatKinky: {
				"{temp}. Cold enough to make everything smaller. Layers.",
				"{temp}. Huddle up for warmth. It's a bachelor party, nobody's judging.",
				"Cold, {temp}. Hot tub. Now. Everybody.",
			},
			HeatRaunchy: {
				"{temp}. Your dick is hiding. Jacket.",
				"Cold as hell, {temp}. Whiskey warms you for ten minutes. A jacket lasts all night.",
				"{temp} and biting. Nipples out, but ironically.",
			},
			HeatSlut: {
				"{temp}. Grapes, not plums, out there tonight. Coat.",
				"Freezing. Everybody is packing peanuts tonight. Jacket.",
				"{temp}. Cold enough to freeze the groom's last shred of dignity. Coat on.",
			},
		},
		moodWind: {
			HeatDirty: {
				"Windy, gusts to {gust}. Hold on to your hats and your dignity.",
				"{wind} winds. Golf is canceled. The bar is not.",
				"Breezy, gusts to {gust}. Cigars will not stay lit. Give up.",
			},
			HeatKinky: {
				"Gusts to {gust}. Something is getting blown this weekend and it's the groom's budget.",
				"{wind} and gusty. Hats off, or the wind takes them.",
				"Windy as hell. Anyone in a kilt, reconsider.",
			},
			HeatRaunchy: {
				"Wind ripping at {gust}. Keep your beer covered, assholes.",
				"Gusty as fuck. Anyone with a combover, tonight's the night you lose it.",
				"{wind} winds. Do not piss into it. Learn from history.",
			},
			HeatSlut: {
				"Wind blowing {gust}, which is more action than the groom gets this weekend. Hold your hats.",
				"Gusts to {gust}. Piss into it and you'll learn something. Don't.",
				"Gusty as fuck. The wind is the only thing getting blown tonight, boys. Behave.",
			},
		},
	},
	openers: map[partyPhase]map[Heat][]string{
		phaseMorning: {
			HeatDirty:   {"Morning, gentlemen. Loose term.", "Rise and grind. Mostly the grinding of teeth."},
			HeatKinky:   {"Morning. Find your wallet, your shoes, and the groom.", "Wake up. Somebody is duct-taped to a lawn chair."},
			HeatRaunchy: {"Morning, you degenerates.", "Rise and regret, boys."},
			HeatSlut:    {"Morning. Count the groomsmen. Count the eyebrows.", "Wake up, fuckers. The Bloody Marys aren't drinking themselves."},
		},
		phaseAfternoon: {
			HeatDirty:   {"Afternoon. Day beers are legally required.", "Afternoon. Cornhole, coolers, and questionable shorts."},
			HeatKinky:   {"Afternoon. Pool, cornhole, and questionable sunscreen coverage.", "Afternoon. Somebody is getting thrown in the pool. It's the groom."},
			HeatRaunchy: {"Afternoon. If you're not three beers deep, the groom is ashamed of you.", "Afternoon. Day drinking. It's a lifestyle."},
			HeatSlut:    {"Afternoon. Edibles in, golf carts out. Nobody drives.", "Afternoon. Shotgun, shotgun, nap, repeat."},
		},
		phaseEvening: {
			HeatDirty:   {"Evening. Steaks and bad decisions.", "Evening. Shirt with buttons. The groom said so."},
			HeatKinky:   {"Evening. Shower, cologne, ones.", "Evening. Somebody iron the groom."},
			HeatRaunchy: {"Evening. Pregame like you're 22, recover like you're 40.", "Evening. Steak, whiskey, and a plan nobody follows."},
			HeatSlut:    {"Evening. Bring cash, leave your dignity.", "Evening. The groom's last night. Ruin him."},
		},
		phaseLate: {
			HeatDirty:   {"Late. Nothing good happens after 2 AM. Prove it.", "Late. One more, then bed. Liar."},
			HeatKinky:   {"Late. The groom's curfew is a myth.", "Late. Whoever falls asleep first gets drawn on."},
			HeatRaunchy: {"Late as fuck. Tacos, water, couch.", "Late. Drunk tacos are a human right."},
			HeatSlut:    {"Late night. What happens here dies in the group chat.", "Late. If you can read this, drink a water and find the groom."},
		},
	},
	advice: map[partyMood]map[Heat]string{
		moodSunny: {
			HeatDirty:   "Sunscreen, sunglasses, and a water every few beers.",
			HeatKinky:   "SPF on the dad bods, all of them.",
			HeatRaunchy: "Sunscreen every two beers, you pink bastards.",
			HeatSlut:    "SPF on everything, including the bald spots and the bad decisions.",
		},
		moodHot: {
			HeatDirty:   "Water between beers and shade when you can.",
			HeatKinky:   "Shade, water, and breathable shorts.",
			HeatRaunchy: "Water every round, or somebody is puking in the Uber.",
			HeatSlut:    "Gold Bond and a gallon of water. Heatstroke kills the vibe.",
		},
		moodNight: {
			HeatDirty:   "Hoodie and a charged phone.",
			HeatKinky:   "Layer up and share locations with the crew.",
			HeatRaunchy: "Hoodie, charged phone, and nobody drives.",
			HeatSlut:    "Buddy system, nobody drives, water before bed.",
		},
		moodGloomy: {
			HeatDirty:   "Coffee, carbs, and a quiet hour.",
			HeatKinky:   "Couch, coffee, and a light layer for later.",
			HeatRaunchy: "Gatorade, greasy eggs, and Advil.",
			HeatSlut:    "Pedialyte, breakfast burritos, and a nap before round two.",
		},
		moodWet: {
			HeatDirty:   "Umbrella, and have an indoor backup plan.",
			HeatKinky:   "Umbrella and a bar with a roof.",
			HeatRaunchy: "Umbrella, roof, and a TV with the game on.",
			HeatSlut:    "Umbrella or a roof. Indoor plan either way.",
		},
		moodCold: {
			HeatDirty:   "Jacket now, brag later.",
			HeatKinky:   "Layers, and the hot tub if there is one.",
			HeatRaunchy: "Real jacket. Whiskey is not insulation.",
			HeatSlut:    "Coat on until the club, then go nuts.",
		},
		moodWind: {
			HeatDirty:   "Hold on to your hat and your cards.",
			HeatKinky:   "Hats off and drinks covered.",
			HeatRaunchy: "Cover your drink and turn your back to the wind.",
			HeatSlut:    "Cover your drink and never piss into the wind.",
		},
	},
}
