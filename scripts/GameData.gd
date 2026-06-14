extends Node

# ─── Enums ───────────────────────────────────────────────────────────────────

enum WashStep {
	SCRAPE,    # Remove food debris (click debris spots)
	SOAK,      # Submerge in water (toggle water, wait)
	SOAP,      # Apply soap (toggle soap)
	SCRUB,     # Scrub with sponge (drag over dish)
	RINSE,     # Rinse under clean water (toggle water after soap)
	DRY        # Dry with towel (press E)
}

enum DishType {
	PLATE,
	POT,
	GLASS,
	CUTTING_BOARD,
	BOWL
}

# ─── Dish Definitions ─────────────────────────────────────────────────────────
# required_steps: ordered list that MUST be completed in sequence
# optional_steps: steps that earn bonus stars if done
# soak_required: true = must soak BEFORE scrubbing or scrub fails

const DISH_DATA = {
	DishType.PLATE: {
		"name": "Dinner Plate",
		"required_steps": [WashStep.SCRAPE, WashStep.SOAP, WashStep.SCRUB, WashStep.RINSE, WashStep.DRY],
		"optional_steps": [WashStep.SOAK],
		"soak_required": false,
		"debris_spots": 3,
		"scrub_threshold": 80,   # % of surface that must be scrubbed
		"description": "Watch out for dried tomato sauce — scrape first!",
		"color": Color(0.9, 0.85, 0.75)
	},
	DishType.POT: {
		"name": "Crusty Pot",
		"required_steps": [WashStep.SCRAPE, WashStep.SOAK, WashStep.SOAP, WashStep.SCRUB, WashStep.RINSE, WashStep.DRY],
		"optional_steps": [],
		"soak_required": true,
		"debris_spots": 6,
		"scrub_threshold": 90,
		"description": "Burnt-on food. You MUST soak this before scrubbing!",
		"color": Color(0.4, 0.35, 0.3)
	},
	DishType.GLASS: {
		"name": "Tall Glass",
		"required_steps": [WashStep.SOAP, WashStep.SCRUB, WashStep.RINSE, WashStep.DRY],
		"optional_steps": [],
		"soak_required": false,
		"debris_spots": 1,
		"scrub_threshold": 70,
		"description": "No food residue — skip straight to soap.",
		"color": Color(0.6, 0.85, 0.95, 0.7)
	},
	DishType.CUTTING_BOARD: {
		"name": "Cutting Board",
		"required_steps": [WashStep.SCRAPE, WashStep.SOAP, WashStep.SCRUB, WashStep.RINSE, WashStep.DRY],
		"optional_steps": [WashStep.SOAK],
		"soak_required": false,
		"debris_spots": 4,
		"scrub_threshold": 95,
		"description": "Lots of grooves — scrub extra thoroughly.",
		"color": Color(0.7, 0.55, 0.35)
	},
	DishType.BOWL: {
		"name": "Cereal Bowl",
		"required_steps": [WashStep.SCRAPE, WashStep.SOAK, WashStep.SOAP, WashStep.SCRUB, WashStep.RINSE, WashStep.DRY],
		"optional_steps": [],
		"soak_required": true,
		"debris_spots": 2,
		"scrub_threshold": 75,
		"description": "Dried cereal is stubborn. Soak required!",
		"color": Color(0.85, 0.8, 0.9)
	}
}

# ─── Levels ───────────────────────────────────────────────────────────────────

const LEVELS = [
	{
		"id": 1,
		"name": "First Day",
		"dishes": [DishType.PLATE],
		"par_time": 90,
		"hint": "Scrape the food off, then Soap → Scrub → Rinse → Dry."
	},
	{
		"id": 2,
		"name": "After Dinner",
		"dishes": [DishType.PLATE, DishType.BOWL, DishType.GLASS],
		"par_time": 120,
		"hint": "The bowl needs soaking. Plan ahead!"
	},
	{
		"id": 3,
		"name": "Sunday Roast",
		"dishes": [DishType.CUTTING_BOARD, DishType.POT, DishType.PLATE, DishType.BOWL],
		"par_time": 180,
		"hint": "Two dishes need soaking. Start them early while you clean others."
	}
]

# ─── Runtime State ────────────────────────────────────────────────────────────

var current_level_index: int = 0
var stars_per_level: Dictionary = {}   # level_id -> star count (0-3)
var total_score: int = 0

func get_current_level() -> Dictionary:
	return LEVELS[current_level_index]

func get_next_level_index() -> int:
	return current_level_index + 1

func has_next_level() -> bool:
	return current_level_index + 1 < LEVELS.size()

func record_level_result(level_id: int, stars: int, score: int) -> void:
	var prev = stars_per_level.get(level_id, 0)
	stars_per_level[level_id] = max(prev, stars)
	total_score += score

func step_name(step: WashStep) -> String:
	match step:
		WashStep.SCRAPE: return "Scrape"
		WashStep.SOAK:   return "Soak"
		WashStep.SOAP:   return "Soap"
		WashStep.SCRUB:  return "Scrub"
		WashStep.RINSE:  return "Rinse"
		WashStep.DRY:    return "Dry"
	return "?"
