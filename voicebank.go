package skua

import (
	"context"
	"fmt"
	"hash/fnv"
	"math"
	"strings"
)

// TemplateVoicer is a Voicer backed by a built-in bank of written lines. It
// needs no key and no network, so the skua always has a voice. Lines vary by
// weather bucket and maturity level, and the pick is seeded by day and place so
// it changes daily without flickering between requests.
type TemplateVoicer struct{}

// NewTemplateVoicer builds the built-in voice.
func NewTemplateVoicer() *TemplateVoicer {
	return &TemplateVoicer{}
}

// voiceBucket is a coarse weather situation the line bank is keyed by.
type voiceBucket string

// Line bank buckets, ordered from most to least urgent in bucketFor.
const (
	bucketStorm      voiceBucket = "storm"
	bucketSnow       voiceBucket = "snow"
	bucketRain       voiceBucket = "rain"
	bucketDrizzle    voiceBucket = "drizzle"
	bucketFog        voiceBucket = "fog"
	bucketHot        voiceBucket = "hot"
	bucketCold       voiceBucket = "cold"
	bucketWind       voiceBucket = "wind"
	bucketOvercast   voiceBucket = "overcast"
	bucketPartly     voiceBucket = "partly"
	bucketClearDay   voiceBucket = "clearday"
	bucketClearNight voiceBucket = "clearnight"
)

// rainRateMM is the current precipitation rate in millimeters at or above which
// the sky counts as raining whatever the condition string says.
const rainRateMM = 0.1

// bucketFor classifies a forecast into a line bank bucket. Active weather wins,
// then temperature extremes, then wind, then sky cover. A measurable
// precipitation rate counts as rain even when the condition string lags.
func bucketFor(f Forecast) voiceBucket {
	c := strings.ToLower(f.Current.Condition)
	switch {
	case strings.Contains(c, "thunder"):
		return bucketStorm
	case strings.Contains(c, "snow"), strings.Contains(c, "sleet"), strings.Contains(c, "ice"),
		strings.Contains(c, "freezing"):
		return bucketSnow
	case strings.Contains(c, "rain"), strings.Contains(c, "shower"):
		return bucketRain
	case strings.Contains(c, "drizzle"):
		return bucketDrizzle
	case f.Current.PrecipMM >= rainRateMM:
		return bucketRain
	case strings.Contains(c, "fog"), strings.Contains(c, "mist"):
		return bucketFog
	}
	switch {
	case f.Current.ApparentTempC >= 33:
		return bucketHot
	case f.Current.ApparentTempC <= 0:
		return bucketCold
	case f.Current.WindGustKph >= 55, f.Current.WindKph >= 35:
		return bucketWind
	}
	switch {
	case strings.Contains(c, "overcast"):
		return bucketOvercast
	case strings.Contains(c, "partly"), strings.Contains(c, "mainly"), strings.Contains(c, "cloud"):
		return bucketPartly
	}
	if f.Current.IsDay {
		return bucketClearDay
	}
	return bucketClearNight
}

// voiceLines is the line bank: one list per bucket per level. Placeholders in
// braces are filled from the forecast. This bank is the product's soul; it only
// ever grows.
var voiceLines = map[voiceBucket]map[VoiceLevel][]string{
	bucketStorm: {
		LevelDry: {
			"Storm's up, and I've ridden enough to know it won't wait on your plans. Get inside.",
			"Thunder out there. Nothing in the yard is worth standing under that. In you go.",
			"Sky's throwing bolts. You don't argue with lightning. Indoors, all of you.",
		},
		LevelProper: {
			"Thunderstorms in the area. Stay indoors and away from windows.",
			"Lightning nearby. Postpone anything outdoors.",
			"Active storms right now. Keep an eye on the radar.",
		},
		LevelSassy: {
			"The sky is throwing a tantrum. Maybe do not be under it.",
			"Thunder again. The atmosphere clearly needs attention.",
			"Storms overhead. Great day to discover your indoor hobbies.",
		},
		LevelSalty: {
			"The sky is pissed off and throwing bolts. Get your ass inside.",
			"Thunderstorms, because the weather said screw your plans.",
			"It is an absolute shitshow up there. Stay in.",
		},
		LevelFeral: {
			"The sky is having a full-blown screaming climax up there. Do not get between it and the ground.",
			"Thunder, lightning, rain everywhere. The atmosphere is thirsty and loud about it. Stay inside.",
			"The clouds are slamming into each other like it is closing time. Let them finish. Indoors.",
		},
	},
	bucketSnow: {
		LevelDry: {
			"Snow's down and the roads turn mean fast. Leave room and go slow.",
			"Coming down white. Warm the kids before they're out in it, and mind your footing.",
			"Snow today. Pretty from the window, treacherous under a tire.",
		},
		LevelProper: {
			"Snow is falling. Allow extra time and drive gently.",
			"Wintry conditions. Watch for slick surfaces.",
			"Snow today. Layer up before heading out.",
		},
		LevelSassy: {
			"Snow. Everything is prettier and everyone forgets how to drive.",
			"The sky is shedding. Bundle up, buttercup.",
			"Fresh snow, fresh chaos. Boots, not sneakers.",
		},
		LevelSalty: {
			"Snow, and the roads are going to be a damn mess. Slow down.",
			"It is snowing. Wear real boots, not whatever the hell those are.",
			"Cold as hell and white everywhere. Drive like you mean to live.",
		},
		LevelFeral: {
			"The sky is dumping its cold white load all over town. Everything gets slippery when it is like this. Drive slow.",
			"Snow everywhere. The clouds could not hold it any longer. Boots on, dignity optional.",
			"It is a whiteout hookup between sky and ground out there. Let them have it. Big coat.",
		},
	},
	bucketRain: {
		LevelDry: {
			"Rain's set in, {rain} chance it holds. Take the umbrella you always forget.",
			"Wet out there. Steady, not dramatic. The jacket by the door earns its keep today.",
			"It's raining, the soaking kind if you're stubborn. Don't be.",
		},
		LevelProper: {
			"Rain at the moment. Take an umbrella.",
			"Wet conditions. Plan for slower travel.",
			"Steady rain. A jacket will serve you well.",
		},
		LevelSassy: {
			"Rain again, shocking. Bring the umbrella you will forget anyway.",
			"Water is falling from the sky. Revolutionary. Grab a jacket.",
			"It is raining. Your hair had plans. The sky disagrees.",
		},
		LevelSalty: {
			"It is pissing down out there. Take the damn umbrella.",
			"Rain all over the place. Your shoes are about to have a bad time.",
			"Wet as hell today. Quit stalling and grab the jacket.",
		},
		LevelFeral: {
			"The sky has a full bladder and zero shame. Umbrella, unless getting soaked is your thing. No judgment. Some.",
			"It is coming down hard and sloppy out there. The gutters are gagging. Wear the jacket.",
			"The clouds are wringing themselves out all over you. Kinky. Umbrella up.",
		},
	},
	bucketDrizzle: {
		LevelDry: {
			"Barely a drizzle. The sky's half in. A hood settles it.",
			"Just a mist. Not umbrella weather, hood weather.",
			"Light spit from above. Annoying, harmless. Carry on.",
		},
		LevelProper: {
			"Light drizzle. A hood should be enough.",
			"Misting rain around. Roads may be slick.",
			"A little drizzle. Nothing a jacket cannot handle.",
		},
		LevelSassy: {
			"Drizzle. The sky cannot commit either.",
			"A half-hearted rain out there. Match its energy.",
			"Barely raining. Just enough to ruin your glasses.",
		},
		LevelSalty: {
			"Weak-ass drizzle out there. Not enough to cancel a damn thing.",
			"The sky is spitting on you. Rude, but survivable.",
			"Drizzle. Annoying as hell, harmless as ever.",
		},
		LevelFeral: {
			"The sky is doing a lazy little tease and calling it rain. Nobody is impressed. Hood up.",
			"Barely wet out there. The clouds are all talk and no follow-through today.",
			"A pathetic little dribble from above. The sky should be embarrassed. You are fine.",
		},
	},
	bucketFog: {
		LevelDry: {
			"Fog's thick this morning. Can't see far, so don't drive like you can. Lights on.",
			"Air's gone gray and close. Leave early, headlights on, no heroics.",
			"Fogged in. Give the road more room than feels right.",
		},
		LevelProper: {
			"Fog is reducing visibility. Use low beams and extra distance.",
			"A foggy start. Take it slow on the road.",
			"Thick air out there. Allow extra time.",
		},
		LevelSassy: {
			"Fog. The world got soft focus and nobody asked.",
			"Visibility is a rumor this morning. Drive like it.",
			"Pea soup outside. Headlights on, hero moves off.",
		},
		LevelSalty: {
			"Fog thick as hell. You cannot see shit, so drive like it.",
			"The air is basically soup. Low beams, no hero crap.",
			"Cannot see a damn thing out there. Slow down.",
		},
		LevelFeral: {
			"The clouds got drunk and passed out on the ground. Now nobody can see anything. Low beams.",
			"The sky is smothering the street like it wants to be held. Sweet, but you still cannot see. Slow down.",
			"Everything is wrapped in a wet gray blindfold. If that excites you, great. Still drive slow.",
		},
	},
	bucketHot: {
		LevelDry: {
			"Feels like {feels}. Heat like this wears you down slow. Water, shade, and mind the little ones.",
			"{feels} out, and the air's got weight. Do the outside work early or skip it.",
			"It's {feels}. This kind takes it out of you quiet. Keep the kids in the shade.",
		},
		LevelProper: {
			"Dangerous heat, feeling like {feels}. Hydrate and limit time outside.",
			"It feels like {feels} out there. Take the heat seriously.",
			"Extreme heat today. Water, shade, and short exposure.",
		},
		LevelSassy: {
			"Feels like {feels}. The sun is showing off again.",
			"{feels} out there. Your car handle is now a branding iron.",
			"Hot enough to bake cookies on the dashboard. Feels like {feels}. Hydrate.",
		},
		LevelSalty: {
			"It feels like {feels} out there. Hot as hell is an understatement.",
			"Damn near {feels} today. Drink water like it is your job.",
			"The sun is trying to kill you today. {feels}. Act accordingly.",
		},
		LevelFeral: {
			"Feels like {feels}. The sun is pressed up against everything, hot and needy as hell. Hydrate before you become a raisin.",
			"It is {feels} and the air is basically heavy breathing on your neck. Gross. Water, shade, repeat.",
			"The sun woke up horny for destruction and it shows. {feels}. Stay inside where it cannot touch you.",
		},
	},
	bucketCold: {
		LevelDry: {
			"Feels like {feels}. Cold with teeth. Cover what you'd miss.",
			"{feels} out there, the kind that finds every gap. Big coat, no shortcuts.",
			"It's {feels}. Bundle the kids proper and mind the pipes tonight.",
		},
		LevelProper: {
			"Below freezing, feeling like {feels}. Dress in layers.",
			"Bitter cold today. Cover exposed skin.",
			"Feels like {feels}. Keep outdoor time short.",
		},
		LevelSassy: {
			"Feels like {feels}. Your face will file a complaint.",
			"Cold enough to make regrets. Layer up.",
			"{feels} out there. The air bites back today.",
		},
		LevelSalty: {
			"It is cold as hell. Feels like {feels}. Big coat, no debate.",
			"Freeze-your-ass-off weather, {feels}. Layer up.",
			"{feels} out there. Skip the fashion, wear the parka.",
		},
		LevelFeral: {
			"Feels like {feels}. Cold enough to make parts of you file for divorce. Layer up everything.",
			"The air is biting like it likes you. {feels}. Cover every inch you value.",
			"It is {feels} and the wind wants under your clothes. It does not deserve you. Big coat.",
		},
	},
	bucketWind: {
		LevelDry: {
			"Wind's up, gusts near {gust}. Whatever you leave loose belongs to it now.",
			"Gusting to {gust}. Hold your hat and bring the light stuff in.",
			"The wind's handsy today, {gust} gusts. Secure the yard.",
		},
		LevelProper: {
			"Strong wind with gusts near {gust}. Secure loose items.",
			"Blustery conditions today. Mind doors and awnings.",
			"Gusts to {gust}. Hold onto hats and plans.",
		},
		LevelSassy: {
			"Gusts to {gust}. Your hairstyle is temporary.",
			"The wind is auditioning for a disaster movie. Gusts near {gust}.",
			"Breezy is underselling it. {gust} gusts. Chase your own trash can.",
		},
		LevelSalty: {
			"Wind is ripping through at {gust}. Tie your crap down.",
			"Gusts to {gust}. The patio furniture is leaving without you.",
			"Windy as hell, {gust} gusts. Hold onto something.",
		},
		LevelFeral: {
			"The wind is grabbing everything it can get its hands on. Gusts to {gust}. Rude and handsy. Tie your stuff down.",
			"Gusts to {gust}. The air is blowing everything in sight, and it is not subtle about it.",
			"The wind is howling like it just got what it wanted. {gust} gusts. Secure your belongings and your dignity.",
		},
	},
	bucketOvercast: {
		LevelDry: {
			"Gray and quiet, {temp}. No trouble in it. Good day to get things done.",
			"Overcast and calm, {temp}. Sky's minding its business. You can mind yours.",
			"Flat gray, {temp}. Nothing to dodge. Easy day if you let it be.",
		},
		LevelProper: {
			"A gray, quiet sky today. Comfortable for getting things done.",
			"Overcast through the day. No surprises up there.",
			"Cloud cover overhead. Calm and steady conditions.",
		},
		LevelSassy: {
			"The sky picked gray again. Bold choice. {temp} out.",
			"One hundred percent clouds, zero percent effort. {temp}.",
			"Overcast. The sun called in sick, you still cannot.",
		},
		LevelSalty: {
			"Gray as hell out there, {temp}. The sun is not coming, deal with it.",
			"A whole lot of nothing up there. {temp} and gloomy.",
			"The sky is one giant gray shrug today. {temp}.",
		},
		LevelFeral: {
			"The sky threw a blanket over the whole town and refuses to get out of bed. {temp}. Honestly, same.",
			"Gray on gray on gray. The sun is under the covers doing nobody any good. {temp}.",
			"The clouds are spooning the entire sky today. No room for the sun in that bed. {temp}.",
		},
	},
	bucketPartly: {
		LevelDry: {
			"Sun and cloud trading off, {temp}. About as easy as weather gets. Use it.",
			"Partly cloudy, {temp}. A good, unremarkable day. Get the kids outside.",
			"Bit of sun, bit of cloud, {temp}. No complaints, and I always have complaints.",
		},
		LevelProper: {
			"A mix of sun and cloud, around {temp}. A pleasant stretch.",
			"Partly cloudy and mild. Good conditions overall.",
			"Broken cloud today with {temp}. Easy weather.",
		},
		LevelSassy: {
			"Sun and clouds taking turns. {temp}. The sky cannot decide either.",
			"Partly cloudy, fully adequate. {temp}.",
			"A little sun, a little cloud. {temp}. Variety, allegedly.",
		},
		LevelSalty: {
			"Half sun, half clouds, all fine. {temp}. Nothing to bitch about.",
			"{temp} with the sky half-assing both sun and clouds.",
			"Decent damn day. {temp}, some clouds. Go outside.",
		},
		LevelFeral: {
			"The sun keeps slipping in and out of the clouds like it is teasing the whole town. {temp}. Enjoy the show.",
			"Sun, then cloud, then sun again. The sky is playing hard to get at {temp}. Classic.",
			"The clouds keep undressing the sun and covering it back up. {temp}. Scandalous up there.",
		},
	},
	bucketClearDay: {
		LevelDry: {
			"Clear and {temp}. I've seen enough gray weeks to know this one's worth stepping into.",
			"Full sun, {temp}. Don't waste it behind a window. Sunscreen, then out.",
			"Not a cloud, {temp}. Take the family out in it, these are the ones you remember.",
		},
		LevelProper: {
			"Clear skies and {temp}. A fine day to be outside.",
			"Full sun today at {temp}. Sunscreen is wise.",
			"Bright and clear, {temp}. Enjoy it.",
		},
		LevelSassy: {
			"Clear and {temp}. Even the skua cannot find a complaint.",
			"Wall-to-wall sunshine at {temp}. Go touch some grass.",
			"{temp} and cloudless. Your excuses just evaporated.",
		},
		LevelSalty: {
			"Not a damn cloud up there. {temp}. Get outside already.",
			"Clear as hell and {temp}. Wasting this indoors would be a crime.",
			"{temp}, pure sun. Quit reading forecasts and go live.",
		},
		LevelFeral: {
			"Not a single cloud. The sky is completely naked at {temp} and loving the attention. Go stare, it wants you to.",
			"{temp}, full sun, sky stripped bare. Shameless up there today. Get out in it.",
			"The sky took everything off and it is glorious. {temp}. Sunscreen, unless you like it rough.",
		},
	},
	bucketClearNight: {
		LevelDry: {
			"Clear night, {temp}. Stars are out and showing off. Worth a look before bed.",
			"{temp} and calm. Good sky tonight. Step out a minute.",
			"Cloudless, {temp}. The kind of quiet night that's easy to sleep under.",
		},
		LevelProper: {
			"A clear night at {temp}. Good stargazing weather.",
			"Calm and clear this evening, {temp}.",
			"Clear skies overnight with {temp}. Rest easy.",
		},
		LevelSassy: {
			"Clear night, {temp}. The stars showed up. Did you?",
			"{temp} and cloudless out there. The moon is showing off.",
			"A quiet, clear night at {temp}. Suspiciously peaceful.",
		},
		LevelSalty: {
			"Clear as hell tonight, {temp}. Look up for once.",
			"{temp} and a naked sky full of stars. Not bad at all.",
			"Damn nice night. {temp}, stars everywhere.",
		},
		LevelFeral: {
			"The night sky is wearing absolutely nothing but stars at {temp}. Gorgeous and it knows it. Look up.",
			"{temp} and the moon is out there glowing like it just got lucky. Honestly, good for it.",
			"Clear, {temp}, and the stars are winking at everyone. Flirty night up there. Enjoy it.",
		},
	},
}

// voiceAdvice is the per-bucket closing recommendation, toned per level.
var voiceAdvice = map[voiceBucket]map[VoiceLevel]string{
	bucketStorm: {
		LevelDry:    "Stay in until it's through. It always is, eventually.",
		LevelProper: "Stay indoors until the lightning passes.",
		LevelSassy:  "Stay inside and let the sky finish its meltdown.",
		LevelSalty:  "Stay the hell inside until it blows through.",
		LevelFeral:  "Stay inside until the sky is done making a scene.",
	},
	bucketSnow: {
		LevelDry:    "Slow down and leave room. The ditch has enough company.",
		LevelProper: "Drive slowly and leave extra distance.",
		LevelSassy:  "Drive like everyone around you just discovered snow.",
		LevelSalty:  "Drive slow. The ditch does not need company.",
		LevelFeral:  "Drive slow and let the sky finish its business.",
	},
	bucketRain: {
		LevelDry:    "Take the umbrella. You know how this goes without one.",
		LevelProper: "Carry an umbrella through the day.",
		LevelSassy:  "Umbrella. You know how this ends without one.",
		LevelSalty:  "Bring the damn umbrella.",
		LevelFeral:  "Take the umbrella and let the sky drip all it wants.",
	},
	bucketDrizzle: {
		LevelDry:    "A hood covers it. No fuss.",
		LevelProper: "A hood or cap will cover it.",
		LevelSassy:  "A hood will do. This is not real rain.",
		LevelSalty:  "A hood covers it. No drama needed.",
		LevelFeral:  "A hood handles this weak little performance.",
	},
	bucketFog: {
		LevelDry:    "Headlights on and easy until it lifts.",
		LevelProper: "Allow extra travel time until it lifts.",
		LevelSassy:  "Leave early. You cannot rush soup.",
		LevelSalty:  "Leave early and use your damn headlights.",
		LevelFeral:  "Headlights on until the sky lets go of the ground.",
	},
	bucketHot: {
		LevelDry:    "Water all day, shade when you can, and watch the little ones.",
		LevelProper: "Hydrate often and take breaks in shade.",
		LevelSassy:  "Water first, complaints second.",
		LevelSalty:  "Drink water all damn day.",
		LevelFeral:  "Hydrate like your life depends on it, because it does.",
	},
	bucketCold: {
		LevelDry:    "Layer up and cover what's exposed.",
		LevelProper: "Layer up and cover exposed skin.",
		LevelSassy:  "Layers. All of them.",
		LevelSalty:  "Wear the big coat. This is not a debate.",
		LevelFeral:  "Bundle every inch. The cold is grabby today.",
	},
	bucketWind: {
		LevelDry:    "Tie down anything you'd hate to chase.",
		LevelProper: "Secure anything that can blow away.",
		LevelSassy:  "Anything not tied down is leaving. Choose wisely.",
		LevelSalty:  "Tie your stuff down before it ends up in the next county.",
		LevelFeral:  "Strap everything down. The wind takes what it wants today.",
	},
	bucketOvercast: {
		LevelDry:    "Nothing up there to stop you. Get after it.",
		LevelProper: "A steady day with no weather obstacles.",
		LevelSassy:  "No excuses in this forecast. Carry on.",
		LevelSalty:  "Nothing up there to stop you. Get after it.",
		LevelFeral:  "The sky is napping. Do whatever you want down here.",
	},
	bucketPartly: {
		LevelDry:    "Good day for outside. Don't overthink it.",
		LevelProper: "Good conditions for outdoor plans.",
		LevelSassy:  "Perfectly usable weather. Use it.",
		LevelSalty:  "Solid day. Do not waste it indoors.",
		LevelFeral:  "Get outside while the sky is in a good mood.",
	},
	bucketClearDay: {
		LevelDry:    "Sunscreen if you're out a while, then enjoy it.",
		LevelProper: "Sunscreen if you are out for long.",
		LevelSassy:  "Sunscreen, unless lobster is the look.",
		LevelSalty:  "Sunscreen up. The sun does not care about you.",
		LevelFeral:  "Sunscreen, because the sun loves too hard.",
	},
	bucketClearNight: {
		LevelDry:    "Step out and look up before you turn in.",
		LevelProper: "A good evening for a walk.",
		LevelSassy:  "Worth stepping outside before bed.",
		LevelSalty:  "Go look at the stars for a damn minute.",
		LevelFeral:  "Step outside. The night is putting on a show.",
	},
}

// briefingOpeners frames the day per level, filled with real numbers.
var briefingOpeners = map[VoiceLevel][]string{
	LevelDry: {
		"Today runs {low} to {high} with {cond}.",
		"{cond} today, high of {high}, low around {low}.",
	},
	LevelProper: {
		"Today runs from {low} up to {high} with {cond}.",
		"Expect {cond} with a high near {high} and a low around {low}.",
	},
	LevelSassy: {
		"Today: {cond}, topping out at {high} and bottoming at {low}.",
		"The menu is {cond}, high of {high}, low of {low}.",
	},
	LevelSalty: {
		"Today is {cond} with a high of {high} and a low of {low}. That is the deal.",
		"{cond} today, {high} at the top, {low} at the bottom.",
	},
	LevelFeral: {
		"The day swings from {low} to a sweaty {high} with {cond} the whole way.",
		"{cond} today, peaking at {high} and dropping to {low} when the sky cools off.",
	},
}

// briefingRain phrases the rain chance per level when it matters.
var briefingRain = map[VoiceLevel]string{
	LevelDry:    "About a {rain} chance of rain, so plan for it.",
	LevelProper: "Rain chance is {rain}.",
	LevelSassy:  "There is a {rain} chance of rain, so calibrate your optimism.",
	LevelSalty:  "A {rain} shot at rain, so heads up.",
	LevelFeral:  "The sky has a {rain} urge to let loose, so be ready for it.",
}

// forecastContext returns one short factual clause about the shape of the week,
// or an empty string when nothing stands out. It reads daily highs in Celsius
// and precipitation probability, and reports the first matching pattern by
// priority: a heat streak, a week peak or valley, a day-to-day trend, then a
// wet stretch. The imperial flag governs unit conversion for any temperature in
// the returned text, though the current clauses carry none.
func forecastContext(f Forecast, imperial bool) string {
	_ = imperial
	if len(f.Daily) == 0 {
		return ""
	}

	// Heat streak: consecutive days from today at or above 32C.
	streak := 0
	for _, d := range f.Daily {
		if d.HighC >= 32 {
			streak++
			continue
		}
		break
	}
	if streak >= 3 {
		return fmt.Sprintf("That's %d straight in the heat.", streak)
	}

	// Week peak or valley over the first up-to-seven days.
	if len(f.Daily) >= 4 {
		span := f.Daily
		if len(span) > 7 {
			span = span[:7]
		}
		today := span[0].HighC
		isMax, isMin := true, true
		for _, d := range span[1:] {
			if d.HighC >= today {
				isMax = false
			}
			if d.HighC <= today {
				isMin = false
			}
		}
		if isMax {
			return "Today is the hottest of the week."
		}
		if isMin && today <= 5 {
			return "Today is the coldest of the stretch."
		}
	}

	// Trend from today to tomorrow.
	if len(f.Daily) >= 2 {
		delta := f.Daily[1].HighC - f.Daily[0].HighC
		if delta >= 3 {
			return "Warmer tomorrow."
		}
		if delta <= -3 {
			return "Cooler tomorrow."
		}
	}

	// Wet stretch among the next up-to-five days.
	wetSpan := f.Daily
	if len(wetSpan) > 5 {
		wetSpan = wetSpan[:5]
	}
	wet := 0
	for _, d := range wetSpan {
		if d.PrecipProb >= 50 {
			wet++
		}
	}
	if wet >= 3 {
		return fmt.Sprintf("A wet stretch ahead, %d of the next five.", wet)
	}

	return ""
}

// eventLine returns a short read on the weather at the user's next calendar
// event, or an empty string when there is no event or no hourly point falls
// close enough to its start. The read leads with the hazard, then temperature
// extremes, then a plain condition, so the listener hears what matters first.
func eventLine(f Forecast, opts VoiceOpts) string {
	if opts.EventTitle == "" || opts.EventEpoch == 0 {
		return ""
	}

	deg := func(c float64) string {
		if opts.Imperial {
			return fmt.Sprintf("%d°", int(math.Round(c*1.8+32)))
		}
		return fmt.Sprintf("%d°", int(math.Round(c)))
	}

	var (
		hour    HourlyPoint
		found   bool
		bestGap int64
	)
	for _, h := range f.Hourly {
		gap := h.Time.Unix() - opts.EventEpoch
		if gap < 0 {
			gap = -gap
		}
		if !found || gap < bestGap {
			hour, bestGap, found = h, gap, true
		}
	}
	if !found || bestGap > 5400 {
		return ""
	}

	temp := deg(hour.ApparentTempC)
	cond := strings.ToLower(hour.Condition)
	var read string
	switch {
	case strings.Contains(cond, "thunder"), strings.Contains(cond, "storm"):
		read = "storms likely, plan cover"
	case strings.Contains(cond, "rain"), strings.Contains(cond, "shower"),
		strings.Contains(cond, "drizzle"):
		read = "wet, bring cover"
	case strings.Contains(cond, "snow"), strings.Contains(cond, "sleet"),
		strings.Contains(cond, "ice"):
		read = "wintry, bundle up"
	case hour.ApparentTempC >= 33:
		read = fmt.Sprintf("hot, %s, water for it", temp)
	case hour.ApparentTempC <= 0:
		read = fmt.Sprintf("cold, %s, layer up", temp)
	default:
		read = fmt.Sprintf("%s, %s", condPhrase(hour.Condition), temp)
	}
	return fmt.Sprintf("%s at %s: %s.", opts.EventTitle, opts.EventWhen, read)
}

// Speak renders the built-in line and briefing for f at the given level. An
// active occasion pack takes over the whole voice.
func (v *TemplateVoicer) Speak(ctx context.Context, f Forecast, opts VoiceOpts) (Voice, error) {
	if party, ok := speakParty(f, opts); ok {
		return party, nil
	}
	b := bucketFor(f)
	level := opts.Level
	if _, ok := voiceLines[b][level]; !ok {
		level = DefaultVoiceLevel
	}
	vals := voiceVals(f, opts.Imperial)

	seed := fmt.Sprintf("%s|%s|%s|%.1f,%.1f",
		b, level, f.Current.Time.Format("2006-01-02"), f.Location.Lat, f.Location.Lon)
	line := renderVoice(pickLine(voiceLines[b][level], seed), vals)

	var parts []string
	if ev := eventLine(f, opts); ev != "" {
		parts = append(parts, ev)
	}
	parts = append(parts, capitalize(renderVoice(pickLine(briefingOpeners[level], seed+"|open"), vals)))
	if ctxClause := forecastContext(f, opts.Imperial); ctxClause != "" {
		parts = append(parts, ctxClause)
	}
	if len(f.Daily) > 0 && f.Daily[0].PrecipProb >= 20 {
		parts = append(parts, renderVoice(briefingRain[level], vals))
	}
	if advice, ok := voiceAdvice[b][level]; ok {
		parts = append(parts, advice)
	}
	return Voice{Line: capitalize(line), Briefing: strings.Join(parts, " ")}, nil
}

// capitalize upper-cases the first letter of s, since a rendered placeholder can
// land at the start of a sentence.
func capitalize(s string) string {
	if s == "" {
		return s
	}
	return strings.ToUpper(s[:1]) + s[1:]
}

// pickLine chooses one line deterministically from a seed, so the voice is
// stable within a day and varies across days and places.
func pickLine(lines []string, seed string) string {
	if len(lines) == 0 {
		return ""
	}
	h := fnv.New32a()
	_, _ = h.Write([]byte(seed))
	return lines[int(h.Sum32())%len(lines)]
}

// voiceVals builds the placeholder values in the requested unit system.
func voiceVals(f Forecast, imperial bool) map[string]string {
	deg := func(c float64) string {
		if imperial {
			return fmt.Sprintf("%d°", int(math.Round(c*1.8+32)))
		}
		return fmt.Sprintf("%d°", int(math.Round(c)))
	}
	speed := func(kph float64) string {
		if imperial {
			return fmt.Sprintf("%d mph", int(math.Round(kph*0.621371)))
		}
		return fmt.Sprintf("%d kph", int(math.Round(kph)))
	}
	high, low, rain := f.Current.TempC, f.Current.TempC, 0
	if len(f.Daily) > 0 {
		high, low, rain = f.Daily[0].HighC, f.Daily[0].LowC, f.Daily[0].PrecipProb
	}
	return map[string]string{
		"{temp}":  deg(f.Current.TempC),
		"{feels}": deg(f.Current.ApparentTempC),
		"{high}":  deg(high),
		"{low}":   deg(low),
		"{wind}":  speed(f.Current.WindKph),
		"{gust}":  speed(f.Current.WindGustKph),
		"{rain}":  fmt.Sprintf("%d%%", rain),
		"{cond}":  condPhrase(f.Current.Condition),
	}
}

// condPhrase turns a condition name into a noun phrase that reads naturally in
// a sentence: "clear" becomes "clear skies", "thunderstorm" pluralizes, and
// precipitation names pass through.
func condPhrase(condition string) string {
	c := strings.ToLower(condition)
	switch {
	case strings.Contains(c, "skies"):
		return c
	case strings.Contains(c, "thunderstorm"):
		return strings.Replace(c, "thunderstorm", "thunderstorms", 1)
	case strings.Contains(c, "clear"), strings.Contains(c, "cloudy"), strings.Contains(c, "overcast"):
		return c + " skies"
	default:
		return c
	}
}

// renderVoice fills a template's placeholders from vals.
func renderVoice(tmpl string, vals map[string]string) string {
	pairs := make([]string, 0, len(vals)*2)
	for k, v := range vals {
		pairs = append(pairs, k, v)
	}
	return strings.NewReplacer(pairs...).Replace(tmpl)
}
