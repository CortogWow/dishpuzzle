extends RefCounted
class_name DishState

# ─── Signals ─────────────────────────────────────────────────────────────────
signal step_completed(step: GameData.WashStep)
signal step_failed(step: GameData.WashStep, reason: String)
signal dish_completed(stars: int, bonus_steps: int)
signal debris_removed(remaining: int)

# ─── State ────────────────────────────────────────────────────────────────────
var dish_type: GameData.DishType
var data: Dictionary

var completed_steps: Array[GameData.WashStep] = []
var failed_attempts: int = 0
var bonus_steps_done: int = 0

var debris_remaining: int = 0
var scrub_progress: float = 0.0   # 0.0 - 100.0
var is_soaking: bool = false
var soak_timer: float = 0.0
var soak_required_time: float = 5.0
var is_soaped: bool = false
var water_on: bool = false
var is_finished: bool = false

# ─── Init ─────────────────────────────────────────────────────────────────────
func _init(type: GameData.DishType) -> void:
	dish_type = type
	data = GameData.DISH_DATA[type]
	debris_remaining = data["debris_spots"]

# ─── Step helpers ─────────────────────────────────────────────────────────────
func has_completed(step: GameData.WashStep) -> bool:
	return step in completed_steps

func next_required_step() -> GameData.WashStep:
	for step in data["required_steps"]:
		if step not in completed_steps:
			return step
	return -1  # all done

func _complete_step(step: GameData.WashStep) -> void:
	if step not in completed_steps:
		completed_steps.append(step)
	if step in data.get("optional_steps", []):
		bonus_steps_done += 1
	step_completed.emit(step)
	_check_completion()

func _fail(step: GameData.WashStep, reason: String) -> void:
	failed_attempts += 1
	step_failed.emit(step, reason)

# ─── Actions (called by the scene) ────────────────────────────────────────────

## Click on a debris spot to remove it
func remove_debris() -> void:
	if debris_remaining <= 0:
		return
	debris_remaining -= 1
	debris_removed.emit(debris_remaining)
	if debris_remaining == 0:
		_complete_step(GameData.WashStep.SCRAPE)

## Toggle the tap water on/off
func toggle_water() -> void:
	# Rinsing: water on after soap+scrub = rinse step
	if has_completed(GameData.WashStep.SCRUB) and is_soaped and not has_completed(GameData.WashStep.RINSE):
		water_on = !water_on
		if water_on:
			is_soaped = false
			_complete_step(GameData.WashStep.RINSE)
		return

	# Soaking: water on before soap to start soak
	if not has_completed(GameData.WashStep.SOAK) and not is_soaking and not is_soaped:
		water_on = !water_on
		is_soaking = water_on
		soak_timer = 0.0
		return

	water_on = !water_on

## Apply / remove soap
func toggle_soap() -> void:
	if not has_completed(GameData.WashStep.SOAP):
		# Validate: if soak required, must have soaked first
		if data["soak_required"] and not has_completed(GameData.WashStep.SOAK):
			_fail(GameData.WashStep.SOAP, "This dish needs soaking first before soap!")
			return
		# Validate: must have scraped if there were debris
		if data["debris_spots"] > 0 and not has_completed(GameData.WashStep.SCRAPE):
			_fail(GameData.WashStep.SOAP, "Scrape the food off first!")
			return
		is_soaped = true
		_complete_step(GameData.WashStep.SOAP)
	else:
		is_soaped = !is_soaped

## Drag scrubbing — pass delta scrub amount (e.g. mouse speed * 0.5)
func add_scrub(amount: float) -> void:
	if not has_completed(GameData.WashStep.SOAP):
		_fail(GameData.WashStep.SCRUB, "Apply soap before scrubbing!")
		return
	if data["soak_required"] and not has_completed(GameData.WashStep.SOAK):
		_fail(GameData.WashStep.SCRUB, "You need to soak this first — soap alone won't cut it!")
		return

	scrub_progress = min(100.0, scrub_progress + amount)
	if scrub_progress >= data["scrub_threshold"] and not has_completed(GameData.WashStep.SCRUB):
		_complete_step(GameData.WashStep.SCRUB)

## Press E to dry
func try_dry() -> void:
	if not has_completed(GameData.WashStep.RINSE):
		_fail(GameData.WashStep.DRY, "Rinse the soap off first!")
		return
	_complete_step(GameData.WashStep.DRY)

## Called every frame to tick soak timer
func process(delta: float) -> void:
	if is_soaking and not has_completed(GameData.WashStep.SOAK):
		soak_timer += delta
		if soak_timer >= soak_required_time:
			is_soaking = false
			_complete_step(GameData.WashStep.SOAK)

# ─── Completion & Scoring ─────────────────────────────────────────────────────
func _check_completion() -> void:
	var required = data["required_steps"] as Array
	for step in required:
		if step not in completed_steps:
			return
	is_finished = true
	var stars = _calculate_stars()
	dish_completed.emit(stars, bonus_steps_done)

func _calculate_stars() -> int:
	if failed_attempts == 0 and bonus_steps_done >= data.get("optional_steps", []).size():
		return 3
	elif failed_attempts <= 1:
		return 2
	else:
		return 1

func get_soak_progress() -> float:
	if not is_soaking:
		return 1.0 if has_completed(GameData.WashStep.SOAK) else 0.0
	return clamp(soak_timer / soak_required_time, 0.0, 1.0)
