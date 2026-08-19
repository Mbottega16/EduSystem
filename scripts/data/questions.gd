class_name Questions
extends RefCounted

## The homework question bank, and the generator that turns it into a sheet.
##
## THE DESIGN CONSTRAINT: the answer key is hidden. What you are scoring is
## whether you AGREED with a truth you can't see, and marking a right answer
## wrong hurts exactly as much as marking a wrong one right.
##
## Every answer is genuinely checkable, so the game is fair. But there are
## more sheets than patience, so in practice you learn to triage on TELLS —
## neat or rushed, working shown or not. The tells correlate with
## correctness without determining it, which is what skim-marking actually
## is, and it keeps the minigame from collapsing into a mental-arithmetic
## test.

## Which bank tonight's homework comes from. Before this every sheet was
## arithmetic, so a Reading Fluency lesson still set 7 x 8 for homework and
## the subject on the board meant nothing.
static func bank_for(strand: String) -> Array:
	match strand:
		"ela": return BANK_ELA
		"science": return BANK_SCIENCE
		"social": return BANK_SOCIAL
	return BANK


const BANK_ELA := [
	{"q": "plural of child", "a": "children", "wrong": ["childs", "childes", "childrens"]},
	{"q": "past tense of run", "a": "ran", "wrong": ["runned", "runed", "running"]},
	{"q": "opposite of ancient", "a": "modern", "wrong": ["olden", "aged", "antique"]},
	{"q": "noun in: the dog barked", "a": "dog", "wrong": ["barked", "the", "loudly"]},
	{"q": "correct spelling", "a": "necessary", "wrong": ["neccessary", "necesary", "necessery"]},
	{"q": "plural of leaf", "a": "leaves", "wrong": ["leafs", "leafes", "leave"]},
	{"q": "opposite of generous", "a": "mean", "wrong": ["giving", "kind", "wealthy"]},
	{"q": "verb in: she reads fast", "a": "reads", "wrong": ["she", "fast", "reading"]},
	{"q": "past tense of bring", "a": "brought", "wrong": ["bringed", "brang", "broughten"]},
	{"q": "a word that rhymes with though", "a": "slow", "wrong": ["cough", "rough", "through"]},
	{"q": "plural of mouse", "a": "mice", "wrong": ["mouses", "mices", "meese"]},
	{"q": "adjective in: the tall tree", "a": "tall", "wrong": ["tree", "the", "grows"]},
	{"q": "plural of mouse", "a": "mice", "wrong": ["mouses", "mices", "mouse"]},
	{"q": "past tense of teach", "a": "taught", "wrong": ["teached", "teach", "teaching"]},
	{"q": "opposite of narrow", "a": "wide", "wrong": ["thin", "small", "short"]},
	{"q": "noun in: birds flew", "a": "birds", "wrong": ["flew", "in", "the"]},
	{"q": "adjective in: red coat", "a": "red", "wrong": ["coat", "the", "in"]},
	{"q": "plural of knife", "a": "knives", "wrong": ["knifes", "knivs", "knife"]},
	{"q": "past tense of catch", "a": "caught", "wrong": ["catched", "catch", "catching"]},
	{"q": "synonym for angry", "a": "cross", "wrong": ["calm", "quiet", "happy"]},
	{"q": "verb in: Sam ran home", "a": "ran", "wrong": ["Sam", "home", "the"]},
	{"q": "rhymes with light", "a": "night", "wrong": ["late", "left", "lit"]},
]

const BANK_SCIENCE := [
	{"q": "water freezes at", "a": "0 C", "wrong": ["10 C", "32 C", "100 C"]},
	{"q": "plants make food by", "a": "photosynthesis", "wrong": ["digestion", "respiration", "osmosis"]},
	{"q": "living things are made of", "a": "cells", "wrong": ["atoms only", "minerals", "tissue only"]},
	{"q": "the gas we breathe out", "a": "carbon dioxide", "wrong": ["oxygen", "nitrogen", "hydrogen"]},
	{"q": "a solid becoming a liquid", "a": "melting", "wrong": ["freezing", "boiling", "condensing"]},
	{"q": "the closest star to Earth", "a": "the Sun", "wrong": ["the Moon", "Polaris", "Sirius"]},
	{"q": "a magnet attracts", "a": "iron", "wrong": ["copper", "glass", "plastic"]},
	{"q": "how many legs has an insect", "a": "6", "wrong": ["8", "4", "10"]},
	{"q": "the force that pulls things down", "a": "gravity", "wrong": ["friction", "magnetism", "pressure"]},
	{"q": "water at 100 C becomes", "a": "steam", "wrong": ["ice", "frost", "snow"]},
	{"q": "the part of a plant that takes in water", "a": "roots", "wrong": ["leaves", "flower", "stem"]},
	{"q": "how many planets orbit the Sun", "a": "8", "wrong": ["9", "7", "12"]},
	{"q": "planet we live on", "a": "Earth", "wrong": ["Mars", "Venus", "Jupiter"]},
	{"q": "liquid to gas change", "a": "evaporation", "wrong": ["freezing", "melting", "condensing"]},
	{"q": "main gas in air", "a": "nitrogen", "wrong": ["oxygen", "carbon dioxide", "hydrogen"]},
	{"q": "what carries pollen", "a": "insects", "wrong": ["rocks", "roots", "clouds"]},
	{"q": "energy from the Sun", "a": "solar energy", "wrong": ["sound energy", "chemical energy", "wind"]},
	{"q": "animal with a backbone", "a": "vertebrate", "wrong": ["invertebrate", "insect", "mollusc"]},
	{"q": "gas plants take in", "a": "carbon dioxide", "wrong": ["oxygen", "nitrogen", "hydrogen"]},
]

const BANK_SOCIAL := [
	{"q": "a map's scale shows", "a": "distance", "wrong": ["height", "weather", "population"]},
	{"q": "lines running east to west", "a": "latitude", "wrong": ["longitude", "meridians", "axes"]},
	{"q": "the largest ocean", "a": "Pacific", "wrong": ["Atlantic", "Indian", "Arctic"]},
	{"q": "a compass needle points", "a": "north", "wrong": ["south", "east", "downhill"]},
	{"q": "the capital of Maryland", "a": "Annapolis", "wrong": ["Baltimore", "Rockville", "Frederick"]},
	{"q": "a peninsula has water on", "a": "3 sides", "wrong": ["all sides", "1 side", "2 sides"]},
	{"q": "the study of past events", "a": "history", "wrong": ["geography", "civics", "economics"]},
	{"q": "a country's system of rules", "a": "government", "wrong": ["economy", "culture", "climate"]},
	{"q": "a large area of very dry land", "a": "desert", "wrong": ["tundra", "prairie", "delta"]},
	{"q": "the imaginary line at 0 degrees latitude", "a": "the equator", "wrong": ["the prime meridian", "the tropics", "the axis"]},
	{"q": "people moving to a new country", "a": "immigration", "wrong": ["emigration", "migration", "tourism"]},
	{"q": "a raised area of land, higher than a hill", "a": "mountain", "wrong": ["valley", "plateau", "basin"]},
	{"q": "largest continent", "a": "Asia", "wrong": ["Africa", "Europe", "North America"]},
	{"q": "ocean east of Maryland", "a": "Atlantic", "wrong": ["Pacific", "Indian", "Arctic"]},
	{"q": "Maryland state nickname", "a": "Old Line State", "wrong": ["Sunshine State", "Golden State", "Bay State"]},
	{"q": "lines running north to south", "a": "longitude", "wrong": ["latitude", "equator", "altitude"]},
	{"q": "land surrounded by water", "a": "island", "wrong": ["peninsula", "valley", "plateau"]},
	{"q": "map symbol key", "a": "legend", "wrong": ["scale", "compass", "grid"]},
	{"q": "Maryland borders this state to west", "a": "West Virginia", "wrong": ["Virginia", "Delaware", "Pennsylvania"]},
	{"q": "money used to buy goods", "a": "currency", "wrong": ["resource", "trade", "tax"]},
	{"q": "people who make laws", "a": "legislators", "wrong": ["judges", "voters", "citizens"]},
	{"q": "a vote in an election", "a": "ballot", "wrong": ["petition", "law", "census"]},
	{"q": "goods bought from abroad", "a": "imports", "wrong": ["exports", "resources", "taxes"]},
	{"q": "goods sold abroad", "a": "exports", "wrong": ["imports", "wages", "resources"]},
]

const BANK := [
	{"q": "7 x 8", "a": "56", "wrong": ["54", "63", "48"]},
	{"q": "6 x 6", "a": "36", "wrong": ["30", "42", "34"]},
	{"q": "9 x 4", "a": "36", "wrong": ["32", "45", "38"]},
	{"q": "12 + 19", "a": "31", "wrong": ["29", "32", "21"]},
	{"q": "45 - 17", "a": "28", "wrong": ["32", "38", "26"]},
	{"q": "8 x 7", "a": "56", "wrong": ["48", "64", "54"]},
	{"q": "72 / 9", "a": "8", "wrong": ["7", "9", "6"]},
	{"q": "13 + 28", "a": "41", "wrong": ["31", "42", "39"]},
	{"q": "100 - 36", "a": "64", "wrong": ["74", "66", "54"]},
	{"q": "5 x 12", "a": "60", "wrong": ["50", "55", "72"]},
	{"q": "144 / 12", "a": "12", "wrong": ["14", "11", "24"]},
	{"q": "17 + 17", "a": "34", "wrong": ["24", "35", "44"]},
	{"q": "6 x 9", "a": "54", "wrong": ["45", "56", "63"]},
	{"q": "84 / 7", "a": "12", "wrong": ["11", "13", "14"]},
	{"q": "36 + 48", "a": "84", "wrong": ["74", "82", "86"]},
	{"q": "90 - 47", "a": "43", "wrong": ["42", "47", "53"]},
	{"q": "25 x 4", "a": "100", "wrong": ["90", "80", "105"]},
	{"q": "half of 86", "a": "43", "wrong": ["42", "46", "48"]},
	{"q": "one quarter of 40", "a": "10", "wrong": ["5", "15", "20"]},
	{"q": "3/4 of 20", "a": "15", "wrong": ["12", "14", "16"]},
	{"q": "perimeter of a 5 by 3", "a": "16", "wrong": ["15", "18", "20"]},
	{"q": "7 x 12", "a": "84", "wrong": ["72", "77", "96"]},
	{"q": "1000 / 10", "a": "100", "wrong": ["10", "110", "1000"]},
	{"q": "0.5 as a fraction", "a": "1/2", "wrong": ["1/5", "5/1", "2/5"]},
]

const QUESTIONS_PER_SHEET := 3

## How strongly a tell agrees with the truth. Deliberately NOT 1.0 — a
## perfect tell would make the sheet readable at a glance and the judgement
## would stop being a judgement.
const TELL_RELIABILITY := 0.75


## Build one student's sheet. `accuracy` (0..1) is the hidden truth, rolled
## from their aptitude by the caller.
static func make_sheet(accuracy: float, rng: RandomNumberGenerator,
		strand: String = "math") -> Dictionary:
	var items: Array = []
	var pool: Array = bank_for(strand).duplicate()
	for i in QUESTIONS_PER_SHEET:
		var pick: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
		pool.erase(pick)
		var correct := rng.randf() < accuracy
		var shown: String = pick["a"]
		if not correct:
			var wrongs: Array = pick["wrong"]
			shown = String(wrongs[rng.randi_range(0, wrongs.size() - 1)])
		# the tell agrees with the truth most of the time, but not always
		var tell_good := correct if rng.randf() < TELL_RELIABILITY else not correct
		items.append({
			"q": String(pick["q"]),
			"shown": shown,
			"correct": correct,
			"neat": tell_good,
			"working": tell_good if rng.randf() < 0.8 else not tell_good,
		})
	return {"items": items, "accuracy": accuracy}


## Did the sheet genuinely deserve a pass? The threshold the player is
## implicitly being asked to guess.
static func sheet_is_good(sheet: Dictionary) -> bool:
	var right := 0
	for it: Dictionary in sheet.get("items", []):
		if bool(it["correct"]):
			right += 1
	return right >= 2
