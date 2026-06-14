extends Control

@onready var play_btn: Button   = $VBox/PlayBtn
@onready var level_select: VBoxContainer = $VBox/LevelSelect
@onready var title_label: Label = $VBox/TitleLabel
@onready var sub_label: Label   = $VBox/SubLabel

func _ready() -> void:
	play_btn.pressed.connect(_start_game)
	title_label.text = "SUDS &\nSEQUENCE"
	sub_label.text = "a dish-washing puzzle game"

	# Build level buttons
	for child in level_select.get_children():
		child.queue_free()

	for i in GameData.LEVELS.size():
		var lvl = GameData.LEVELS[i]
		var btn = Button.new()
		var stars = GameData.stars_per_level.get(lvl["id"], 0)
		var star_str = "★".repeat(stars) + "☆".repeat(3 - stars) if i == 0 or _level_unlocked(i) else "🔒"
		btn.text = "Level %d: %s  %s" % [lvl["id"], lvl["name"], star_str]
		btn.disabled = not _level_unlocked(i)
		var idx = i
		btn.pressed.connect(func(): _start_level(idx))
		level_select.add_child(btn)

func _level_unlocked(index: int) -> bool:
	if index == 0:
		return true
	var prev = GameData.LEVELS[index - 1]
	return GameData.stars_per_level.get(prev["id"], 0) > 0

func _start_game() -> void:
	GameData.current_level_index = 0
	get_tree().change_scene_to_file("res://scenes/KitchenLevel.tscn")

func _start_level(index: int) -> void:
	GameData.current_level_index = index
	get_tree().change_scene_to_file("res://scenes/KitchenLevel.tscn")
