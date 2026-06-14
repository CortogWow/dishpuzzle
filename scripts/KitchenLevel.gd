extends Node2D

# ─── Node refs (set in scene) ─────────────────────────────────────────────────
@onready var dish_sprite: Sprite2D        = $DishArea/DishSprite
@onready var dish_label: Label            = $DishArea/DishLabel
@onready var debris_container: Node2D     = $DishArea/DebrisSpots
@onready var scrub_overlay: ColorRect     = $DishArea/ScrubOverlay
@onready var water_fill: ColorRect        = $WaterFill
@onready var water_handle: Button         = $WaterHandle
@onready var scraper_tool: Sprite2D       = $ScraperTool
@onready var foam_particles: CPUParticles2D = $DishArea/FoamParticles

@onready var step_list: VBoxContainer     = $UI/StepPanel/VBox/StepList
@onready var hint_label: Label            = $UI/HintLabel
@onready var soak_bar: TextureProgressBar = $UI/SoakBar
@onready var timer_label: Label           = $UI/InfoPanel/InfoVBox/TimerLabel
@onready var dish_counter: Label          = $UI/InfoPanel/InfoVBox/DishCounter
@onready var water_btn: Button            = $UI/Controls/WaterBtn
@onready var soap_btn: Button             = $UI/Controls/SoapBtn
@onready var dry_btn: Button              = $UI/Controls/DryBtn
@onready var next_btn: Button             = $UI/NextBtn

@onready var scrape_sound: AudioStreamPlayer = $ScrapeSound
@onready var pickup_sound: AudioStreamPlayer = $PickupSound
@onready var scrub_sound: AudioStreamPlayer  = $ScrubSound
@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var fail_flash: ColorRect        = $UI/FailFlash
@onready var result_panel: PanelContainer = $UI/ResultPanel
@onready var result_label: Label          = $UI/ResultPanel/VBox/ResultLabel
@onready var stars_label: Label           = $UI/ResultPanel/VBox/StarsLabel
@onready var continue_btn: Button         = $UI/ResultPanel/VBox/ContinueBtn

# ─── State ────────────────────────────────────────────────────────────────────
var level_data: Dictionary
var dish_queue: Array[GameData.DishType] = []
var current_dish_index: int = 0
var current_dish: DishState

var elapsed_time: float = 0.0
var level_active: bool = false
var total_stars: int = 0
var total_score: int = 0

var is_scrubbing: bool = false
var last_mouse_pos: Vector2
var tool_held: bool = false
const SCRAPER_REST = Vector2(240, 120)
const SCRAPE_THRESHOLD = 80.0
const SCRAPE_TIME = 1.0
var debris_progress: Dictionary = {}
var debris_time: Dictionary = {}

# ─── Pixel palette ────────────────────────────────────────────────────────────
const COLOR_BG       = Color(0.13, 0.11, 0.18)
const COLOR_WATER    = Color(0.2, 0.55, 0.85, 0.6)
const COLOR_FOAM     = Color(0.95, 0.97, 1.0, 0.9)
const COLOR_CLEAN    = Color(0.85, 0.95, 1.0, 0.4)
const COLOR_FAIL     = Color(0.9, 0.2, 0.2, 0.5)

# ─── Ready ────────────────────────────────────────────────────────────────────
func _ready() -> void:
	level_data = GameData.get_current_level()
	for d in level_data["dishes"]:
		dish_queue.append(d as GameData.DishType)

	var stream = music_player.stream as AudioStreamMP3
	if stream:
		stream.loop = true
	music_player.play()

	var scrub_stream = scrub_sound.stream as AudioStreamMP3
	if scrub_stream:
		scrub_stream.loop = true

	result_panel.visible = false
	fail_flash.visible = false
	fail_flash.color = COLOR_FAIL

	_load_dish(0)
	level_active = true

	# Button connections
	water_btn.pressed.connect(_on_water_pressed)
	water_handle.pressed.connect(_on_water_pressed)
	soap_btn.pressed.connect(_on_soap_pressed)
	dry_btn.pressed.connect(_on_dry_pressed)
	next_btn.pressed.connect(_on_next_pressed)
	continue_btn.pressed.connect(_on_continue_pressed)

	hint_label.text = level_data.get("hint", "")
	dish_counter.text = "Dish 1 / %d" % dish_queue.size()

# ─── Load a dish ─────────────────────────────────────────────────────────────
func _load_dish(index: int) -> void:
	current_dish_index = index
	var dtype: GameData.DishType = dish_queue[index]
	current_dish = DishState.new(dtype)

	current_dish.step_completed.connect(_on_step_completed)
	current_dish.step_failed.connect(_on_step_failed)
	current_dish.dish_completed.connect(_on_dish_completed)
	current_dish.debris_removed.connect(_on_debris_removed)

	var ddata = GameData.DISH_DATA[dtype]

	# Visual setup
	dish_label.text = ddata["name"]
	scrub_overlay.modulate.a = 0.0
	foam_particles.emitting = false

	# Rebuild step checklist
	for child in step_list.get_children():
		child.queue_free()
	for step in ddata["required_steps"]:
		var lbl = Label.new()
		lbl.name = "Step_" + str(step)
		lbl.text = "☐ " + GameData.step_name(step)
		lbl.add_theme_font_size_override("font_size", 4)
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		step_list.add_child(lbl)

	# Spawn debris spots
	for child in debris_container.get_children():
		child.queue_free()
	for i in ddata["debris_spots"]:
		var spot = ColorRect.new()
		spot.size = Vector2(10, 10)
		var angle = (i / float(ddata["debris_spots"])) * TAU
		var radius = 18.0
		spot.position = Vector2(cos(angle), sin(angle)) * radius - spot.size * 0.5
		spot.color = Color(0.45, 0.25, 0.08)
		spot.name = "Debris_%d" % i
		debris_container.add_child(spot)
		# Make clickable via Area2D approach — we handle in _input instead

	soak_bar.visible = false
	next_btn.visible = false
	dish_counter.text = "Dish %d / %d" % [index + 1, dish_queue.size()]

# ─── Process ──────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if not level_active:
		return

	current_dish.process(delta)

	if tool_held:
		var mp = get_viewport().get_mouse_position()
		scraper_tool.position = mp

	# Soak bar
	if current_dish.is_soaking or current_dish.has_completed(GameData.WashStep.SOAK):
		soak_bar.visible = true
		soak_bar.value = current_dish.get_soak_progress() * 100.0
	else:
		soak_bar.visible = false

	# Scrub overlay opacity reflects scrub progress
	scrub_overlay.modulate.a = (current_dish.scrub_progress / 100.0) * 0.6

	# Foam particles when scrubbing with soap
	foam_particles.emitting = is_scrubbing and current_dish.is_soaped

# ─── Input ────────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not level_active:
		return

	# Keyboard shortcuts
	if event.is_action_pressed("toggle_water"):
		_on_water_pressed()
	elif event.is_action_pressed("toggle_soap"):
		_on_soap_pressed()
	elif event.is_action_pressed("dry"):
		_on_dry_pressed()
	elif event.is_action_pressed("next_dish"):
		if next_btn.visible:
			_on_next_pressed()

	# Pick up / put down scraper
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var tool_rect = Rect2(scraper_tool.global_position - Vector2(31, 27), Vector2(62, 54))
			if not tool_held and tool_rect.has_point(mb.global_position):
				tool_held = true
				pickup_sound.play()
				hint_label.text = "Scraper picked up! Jiggle it over the food spots."
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and tool_held:
			tool_held = false
			scraper_tool.position = SCRAPER_REST
			pickup_sound.play()
			hint_label.text = "Scraper put down."

	# Jiggle scraping
	if event is InputEventMouseMotion and tool_held:
		var moved = event.relative.length()
		var mouse_pos = get_viewport().get_mouse_position()
		var over_spot = false
		for child in debris_container.get_children():
			var cr = child as ColorRect
			var spot_rect = Rect2(debris_container.to_global(cr.position), cr.size).grow(10)
			if spot_rect.has_point(mouse_pos):
				over_spot = true
				var key = child.name
				debris_progress[key] = debris_progress.get(key, 0.0) + moved
				debris_time[key] = debris_time.get(key, 0.0) + get_process_delta_time()
				if debris_progress[key] >= SCRAPE_THRESHOLD and debris_time[key] >= SCRAPE_TIME:
					debris_progress.erase(key)
					debris_time.erase(key)
					current_dish.remove_debris()
					scrape_sound.play()
					scrub_sound.stop()
					child.queue_free()
					return
				break
		if over_spot and not scrub_sound.playing:
			scrub_sound.play()
		elif not over_spot and scrub_sound.playing:
			scrub_sound.stop()

	if event is InputEventMouseMotion and is_scrubbing:
		var speed = event.relative.length()
		current_dish.add_scrub(speed * 0.3)
		last_mouse_pos = event.global_position


# ─── Button callbacks ─────────────────────────────────────────────────────────
func _on_water_pressed() -> void:
	current_dish.toggle_water()
	water_btn.text = "💧 Water: " + ("ON" if current_dish.water_on else "OFF")
	_animate_water(current_dish.water_on)

func _animate_water(filling: bool) -> void:
	var tween = create_tween()
	var target_height = 30.0 if filling else 0.0
	var target_y = water_fill.position.y - (30.0 - water_fill.size.y) if filling else 105.0
	tween.tween_property(water_fill, "size:y", target_height, 1.5)
	tween.parallel().tween_property(water_fill, "position:y", target_y, 1.5)

func _on_soap_pressed() -> void:
	current_dish.toggle_soap()

func _on_dry_pressed() -> void:
	current_dish.try_dry()

func _on_next_pressed() -> void:
	if current_dish_index + 1 < dish_queue.size():
		_load_dish(current_dish_index + 1)
	else:
		_end_level()

# ─── Dish event callbacks ─────────────────────────────────────────────────────
func _on_step_completed(step: GameData.WashStep) -> void:
	# Tick off the checklist
	var node_name = "Step_" + str(step)
	var lbl = step_list.find_child(node_name, true, false) as Label
	if lbl:
		lbl.text = "✔  " + GameData.step_name(step)
		lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))

	hint_label.text = "✔ " + GameData.step_name(step) + " done!"

func _on_step_failed(_step: GameData.WashStep, reason: String) -> void:
	hint_label.text = "✘ " + reason
	_flash_fail()

func _on_dish_completed(stars: int, _bonus: int) -> void:
	total_stars += stars
	var score = stars * 100 - int(current_dish.failed_attempts) * 20
	total_score += max(0, score)
	next_btn.visible = true
	hint_label.text = "Dish done! " + "★".repeat(stars) + "☆".repeat(3 - stars)

func _on_debris_removed(remaining: int) -> void:
	hint_label.text = "%d food bits left to scrape!" % remaining if remaining > 0 else "Scraped clean!"

# ─── Level End ────────────────────────────────────────────────────────────────
func _end_level() -> void:
	level_active = false
	GameData.record_level_result(level_data["id"], total_stars, total_score)

	result_panel.visible = true
	result_label.text = "Level Complete!\nScore: %d" % total_score
	stars_label.text = "★".repeat(min(total_stars, 3)) + "☆".repeat(max(0, 3 - total_stars))

	if GameData.has_next_level():
		continue_btn.text = "Next Level →"
	else:
		continue_btn.text = "Back to Menu"

func _on_continue_pressed() -> void:
	if GameData.has_next_level():
		GameData.current_level_index = GameData.get_next_level_index()
		get_tree().reload_current_scene()
	else:
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

# ─── Fail flash ───────────────────────────────────────────────────────────────
func _flash_fail() -> void:
	fail_flash.visible = true
	var tween = create_tween()
	tween.tween_property(fail_flash, "modulate:a", 1.0, 0.05)
	tween.tween_property(fail_flash, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): fail_flash.visible = false)
