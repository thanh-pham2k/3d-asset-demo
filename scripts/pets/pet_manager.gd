class_name PetManager
extends Node

## Comprehensive Manager for the Pet System MVP in Couple Chaos 3D.
## Coordinates pet ownership, persistent stats (hunger, happiness, affection),
## spawning inside the house, daily lifecycle updates, and player care progression.

signal pet_adopted(pet_name: String)
signal pet_stats_updated(hunger: float, happiness: float, affection: float)
signal pet_interacted(action: String, pet_node: Node)

@export var is_adopted: bool = false
@export var pet_id: String = "pet_orange_tabby_01"
@export var pet_name: String = "Miu Miu"
@export var hunger: float = 75.0      # 0.0 = starving, 100.0 = full
@export var thirst: float = 80.0      # 0.0 = thirsty, 100.0 = quenched
@export var happiness: float = 80.0   # 0.0 to 100.0
@export var affection: float = 25.0   # 0.0 to 100.0 (affects pet behavior and bonding)
@export var has_collar: bool = true
const DEFAULT_HOME_POSITION := Vector3(1.5, 0.0, -1.0)
@export var home_position: Vector3 = DEFAULT_HOME_POSITION
@export var current_activity_name: String = "IDLE"
var last_pet_gift_day: int = -99

var pet_instance: OrangeTabbyCat = null
var room_node: Node3D = null
var rename_dialog: ConfirmationDialog
var rename_field: LineEdit
var renaming_player: CharacterBody3D
var pet_hud_layer: CanvasLayer = null
var pet_status_label: Label = null

func _ready() -> void:
	add_to_group("pet_manager")
	_build_rename_dialog()
	_build_pet_hud()
	
	# Discover Room or House root
	call_deferred("_discover_dependencies")

func _discover_dependencies() -> void:
	if not is_instance_valid(room_node):
		room_node = get_tree().get_first_node_in_group("room") as Node3D
		if not room_node:
			room_node = get_parent() as Node3D
			
	# Connect to DailyLoopManager for new day wake-up and stat decay
	var daily_loop := get_tree().get_first_node_in_group("daily_loop_manager") as DailyLoopManager
	if is_instance_valid(daily_loop):
		if not daily_loop.day_started.is_connected(_on_day_started):
			daily_loop.day_started.connect(_on_day_started)
		if not daily_loop.day_advanced.is_connected(_on_day_advanced):
			daily_loop.day_advanced.connect(_on_day_advanced)
			
	# Check if adoption was already purchased in inventory
	var econ := get_tree().get_first_node_in_group("economy_manager") as EconomyManager
	if is_instance_valid(econ) and econ.inventory:
		if econ.inventory.is_upgrade_owned("pet_cat_adoption"):
			is_adopted = true
			
	if is_adopted:
		ensure_pet_spawned()
	_refresh_pet_hud()

func _build_rename_dialog() -> void:
	var layer := CanvasLayer.new()
	layer.name = "PetNameUI"
	layer.layer = 70
	add_child(layer)
	rename_dialog = ConfirmationDialog.new()
	rename_dialog.title = "Đặt tên cho mèo"
	rename_dialog.ok_button_text = "Lưu tên"
	rename_dialog.cancel_button_text = "Hủy"
	rename_dialog.min_size = Vector2i(380, 110)
	layer.add_child(rename_dialog)
	rename_field = LineEdit.new()
	rename_field.placeholder_text = "Tên mèo (tối đa 24 ký tự)"
	rename_field.max_length = 24
	rename_dialog.add_child(rename_field)
	rename_dialog.confirmed.connect(_confirm_pet_name)
	rename_dialog.canceled.connect(_end_rename)
	rename_dialog.close_requested.connect(_end_rename)

func _unhandled_input(event: InputEvent) -> void:
	if not is_adopted or not is_instance_valid(pet_instance) or rename_dialog.visible:
		return
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_N):
		return
	var player := get_tree().get_first_node_in_group("active_player") as CharacterBody3D
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("players") as CharacterBody3D
	if not is_instance_valid(player) or player.has_meta("shopping_open") or player.has_meta("daily_summary_open") or player.has_meta("map_open") or player.global_position.distance_to(pet_instance.global_position) > 2.0:
		return
	renaming_player = player
	player.set_meta("pet_rename_open", true)
	player.velocity = Vector3.ZERO
	rename_field.text = pet_name
	rename_dialog.popup_centered()
	rename_field.grab_focus()
	rename_field.select_all()
	get_viewport().set_input_as_handled()

func _confirm_pet_name() -> void:
	var chosen := rename_field.text.strip_edges()
	if chosen != "":
		pet_name = chosen.substr(0, 24)
		if is_instance_valid(pet_instance):
			pet_instance.pet_name = pet_name
		var econ := get_tree().get_first_node_in_group("economy_manager") as EconomyManager
		if is_instance_valid(econ) and econ.auto_save_on_change:
			econ.save_economy_state()
	_end_rename()

func _end_rename() -> void:
	if is_instance_valid(renaming_player) and renaming_player.has_meta("pet_rename_open"):
		renaming_player.remove_meta("pet_rename_open")
		renaming_player.set_meta("ui_input_block_until_msec", Time.get_ticks_msec() + 200)
	renaming_player = null

# -----------------------------------------------------------------
# Spawning & Lifecycle
# -----------------------------------------------------------------
func ensure_pet_spawned(parent_override: Node3D = null) -> OrangeTabbyCat:
	if is_instance_valid(pet_instance) and pet_instance.is_inside_tree():
		return pet_instance
		
	var parent: Node = parent_override if is_instance_valid(parent_override) else room_node
	if not is_instance_valid(parent):
		parent = get_tree().get_first_node_in_group("room") as Node3D
	if not is_instance_valid(parent):
		parent = self
		
	var cat_scene: PackedScene = load("res://scenes/pets/orange_tabby_cat.tscn")
	if not cat_scene:
		printerr("PetManager: Could not load cat scene at res://scenes/pets/orange_tabby_cat.tscn")
		return null
		
	pet_instance = cat_scene.instantiate() as OrangeTabbyCat
	pet_instance.name = "OrangeTabbyCat"
	pet_instance.pet_id = pet_id
	pet_instance.pet_name = pet_name
	pet_instance.hunger = hunger
	pet_instance.thirst = thirst
	pet_instance.happiness = happiness
	pet_instance.affection = affection
	pet_instance.has_collar = has_collar
	pet_instance.home_position = home_position
	pet_instance.position = home_position
	
	parent.add_child(pet_instance)
	
	# Connect signals
	if not pet_instance.pet_interacted.is_connected(_on_pet_interacted):
		pet_instance.pet_interacted.connect(_on_pet_interacted)
		
	return pet_instance

func adopt_cat(new_name: String = "Miu Miu") -> void:
	is_adopted = true
	pet_name = new_name
	hunger = 80.0
	thirst = 85.0
	happiness = 85.0
	affection = 25.0
	
	# Ensure unlock in economy inventory
	var econ := get_tree().get_first_node_in_group("economy_manager") as EconomyManager
	if is_instance_valid(econ) and econ.inventory:
		econ.inventory.unlock_upgrade("pet_cat_adoption")
		
	ensure_pet_spawned()
	
	if is_instance_valid(pet_instance):
		pet_instance.pet_name = pet_name
		pet_instance.position = home_position
		pet_instance.play_animation("happy")
		pet_instance.set_expression("happy")
		pet_instance.show_mood_emote("❤️")
		
	var fx = get_tree().get_first_node_in_group("chaos_feedback")
	if is_instance_valid(fx):
		if fx.has_method("play_event") and is_instance_valid(pet_instance):
			fx.play_event("pickup", pet_instance.global_position + Vector3(0, 0.4, 0))
		if fx.has_method("show_toast"):
			fx.show_toast("🎉 Chúc mừng! Bạn đã nhận nuôi mèo vàng %s về chung một nhà! 🐱💖" % pet_name)
			
	pet_adopted.emit(pet_name)

# -----------------------------------------------------------------
# Day Transition & Daily Care
# -----------------------------------------------------------------
func _on_day_advanced(new_day: int) -> void:
	if not is_adopted: return
	if is_instance_valid(pet_instance):
		hunger = pet_instance.hunger
		thirst = pet_instance.thirst
		happiness = pet_instance.happiness
		affection = pet_instance.affection

	# Gentle decay - no harsh penalties or loss of pet
	hunger = maxf(15.0, hunger - 25.0)
	thirst = maxf(15.0, thirst - 25.0)
	
	# Mild happiness adjustment if hungry
	if hunger < 30.0:
		happiness = maxf(30.0, happiness - 15.0)
	else:
		happiness = minf(100.0, happiness + 5.0)
		
	# Sync with active pet instance
	if is_instance_valid(pet_instance):
		pet_instance.hunger = hunger
		pet_instance.thirst = thirst
		pet_instance.happiness = happiness
		pet_instance.on_day_advanced(new_day)
		
	pet_stats_updated.emit(hunger, happiness, affection)

func _on_day_started(day_number: int) -> void:
	if not is_adopted: return
	
	if is_instance_valid(pet_instance):
		pet_instance.on_morning_wake_up()
	try_grant_pet_gift(day_number)
	_refresh_pet_hud()

func get_pet_mood_text() -> String:
	if happiness >= 75.0:
		return "Rất vui vẻ 💖"
	if hunger < 30.0:
		return "Hơi đói 🐟"
	if current_activity_name == "SLEEPING":
		return "Đang ngủ 💤"
	return "Thoải mái 😊"

func get_pet_status_summary() -> String:
	return "🐱 %s · Tình cảm: %d/100 · %s" % [pet_name, int(round(affection)), get_pet_mood_text()]

func _build_pet_hud() -> void:
	pet_hud_layer = CanvasLayer.new()
	pet_hud_layer.name = "PetStatusHUD"
	pet_hud_layer.layer = 5
	pet_hud_layer.visible = false
	add_child(pet_hud_layer)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -290
	panel.offset_right = -16
	panel.offset_top = 128
	panel.offset_bottom = 160
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("141a21", 0.72)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", sb)
	pet_hud_layer.add_child(panel)
	pet_status_label = Label.new()
	pet_status_label.add_theme_font_size_override("font_size", 12)
	pet_status_label.add_theme_color_override("font_color", Color("ffe082"))
	panel.add_child(pet_status_label)

func _refresh_pet_hud() -> void:
	if not is_instance_valid(pet_hud_layer) or not is_instance_valid(pet_status_label):
		return
	pet_hud_layer.visible = is_adopted
	if is_adopted:
		pet_status_label.text = get_pet_status_summary()

func try_grant_pet_gift(day_number: int) -> Dictionary:
	if not is_adopted or affection < 50.0:
		return {}
	if day_number - last_pet_gift_day < 2:
		return {} # Cooldown prevents economy exploitation
	last_pet_gift_day = day_number
	var econ := get_tree().get_first_node_in_group("economy_manager") as EconomyManager if is_inside_tree() else null
	var gift_text := ""
	var gift_type := "seed"
	if is_instance_valid(econ):
		if day_number % 2 == 0 and is_instance_valid(econ.inventory):
			econ.inventory.add_item("seed_lettuce", 1)
			gift_text = "🌱 %s tha về tặng bạn 1 Hạt giống Xà Lách!" % pet_name
		elif is_instance_valid(econ.wallet):
			gift_type = "money"
			econ.wallet.deposit(3000, "pet_gift", "Quà nhỏ từ mèo %s" % pet_name, "pet_gift_day_%d" % day_number)
			gift_text = "🪙 %s nhặt được 3,000 đ mang về tặng bạn!" % pet_name
	var fx = get_tree().get_first_node_in_group("chaos_feedback") if is_inside_tree() else null
	if gift_text != "" and is_instance_valid(fx) and fx.has_method("show_toast"):
		fx.show_toast(gift_text)
	return {"type": gift_type, "message": gift_text, "day": day_number}

func record_care_action(action: String) -> void:
	if is_adopted and is_instance_valid(pet_instance):
		pet_interacted.emit(action, pet_instance)

func _on_pet_interacted(action: String) -> void:
	if is_instance_valid(pet_instance):
		hunger = pet_instance.hunger
		thirst = pet_instance.thirst
		happiness = pet_instance.happiness
		affection = pet_instance.affection
		
	pet_interacted.emit(action, pet_instance)
	pet_stats_updated.emit(hunger, happiness, affection)
	_refresh_pet_hud()
	var econ := get_tree().get_first_node_in_group("economy_manager") as EconomyManager
	if is_instance_valid(econ) and econ.auto_save_on_change:
		econ.save_economy_state()

# -----------------------------------------------------------------
# Save / Load Persistence
# -----------------------------------------------------------------
func get_save_data() -> Dictionary:
	if is_instance_valid(pet_instance):
		hunger = pet_instance.hunger
		thirst = pet_instance.thirst
		happiness = pet_instance.happiness
		affection = pet_instance.affection
		has_collar = pet_instance.has_collar
		current_activity_name = pet_instance.get_activity_string()
		home_position = pet_instance.home_position
			
	return {
		"is_adopted": is_adopted,
		"pet_id": pet_id,
		"pet_name": pet_name,
		"hunger": hunger,
		"thirst": thirst,
		"happiness": happiness,
		"affection": affection,
		"has_collar": has_collar,
		"home_position": [home_position.x, home_position.y, home_position.z],
		"activity": current_activity_name,
		"last_pet_gift_day": last_pet_gift_day
	}

func apply_save_data(data: Dictionary) -> void:
	var econ: EconomyManager = null
	if is_inside_tree():
		econ = get_tree().get_first_node_in_group("economy_manager") as EconomyManager
	var owned_in_inventory := is_instance_valid(econ) and econ.inventory.is_upgrade_owned("pet_cat_adoption")
	is_adopted = bool(data.get("is_adopted", false)) or owned_in_inventory
	pet_id = str(data.get("pet_id", "pet_orange_tabby_01"))
	pet_name = str(data.get("pet_name", "Miu Miu"))
	hunger = clampf(float(data.get("hunger", 75.0)), 0.0, 100.0)
	thirst = clampf(float(data.get("thirst", 80.0)), 0.0, 100.0)
	happiness = clampf(float(data.get("happiness", 80.0)), 0.0, 100.0)
	affection = clampf(float(data.get("affection", 25.0)), 0.0, 100.0)
	has_collar = bool(data.get("has_collar", true))
	current_activity_name = str(data.get("activity", "IDLE"))
	last_pet_gift_day = int(data.get("last_pet_gift_day", -99))
	home_position = DEFAULT_HOME_POSITION
	
	if data.has("home_position") and data["home_position"] is Array:
		var pos_arr: Array = data["home_position"]
		if pos_arr.size() >= 3:
			home_position = Vector3(float(pos_arr[0]), float(pos_arr[1]), float(pos_arr[2]))

	if not is_adopted:
		_end_rename()
		if is_instance_valid(rename_dialog): rename_dialog.hide()
		if is_instance_valid(pet_instance):
			pet_instance.remove_from_group("pets")
			pet_instance.remove_from_group("interactables")
			pet_instance.queue_free()
			pet_instance = null
		_refresh_pet_hud()
		return
	if is_instance_valid(econ) and not owned_in_inventory:
		econ.inventory.unlock_upgrade("pet_cat_adoption")
			
	if is_adopted:
		ensure_pet_spawned()
		if is_instance_valid(pet_instance):
			pet_instance.pet_id = pet_id
			pet_instance.pet_name = pet_name
			pet_instance.hunger = hunger
			pet_instance.thirst = thirst
			pet_instance.happiness = happiness
			pet_instance.affection = affection
			pet_instance.set_collar_visible(has_collar)
			pet_instance.home_position = home_position
			# Switching away from sleep restores the old bed exit first.
			pet_instance.set_activity_by_string(current_activity_name)
			pet_instance.target_prop = null
			pet_instance.target_player = null
			pet_instance.target_nav_point = Vector3.ZERO
			pet_instance.position = home_position
	_refresh_pet_hud()
