class_name FarmPlot
extends Interactable

## Independent Garden Plot for the Couple Chaos 3D Farming System.
## Handles soil preparation (tilling), seed planting, watering, growth time progression,
## 3D visual stage updates, harvesting, and state persistence.

signal crop_planted(plot_id: String, crop_id: String)
signal crop_watered(plot_id: String)
signal crop_advanced(plot_id: String, stage: int)
signal crop_harvested(plot_id: String, crop_id: String, quantity: int)

@export var plot_id: String = "plot_1"
@export var is_tilled: bool = false
@export var crop_id: String = ""
@export var stage: int = 0 # 0: SEEDED, 1: SPROUT, 2: GROWING, 3: MATURE
@export var growth_progress: float = 0.0 # 0.0 to 1.0 within stage
@export var growth_hours_accumulated: float = 0.0
@export var last_growth_day: int = -1

# Seed selection index if player owns multiple seed types
var selected_seed_index: int = 0

# Visual sub-nodes
var crop_instance: CropVisual
var status_label: Label3D

func _ready() -> void:
	kind = "farm_plot"
	interaction_radius = 1.8
	add_to_group("interactables")
	add_to_group("farm_plots")
	
	_setup_soil_visual()
	_setup_status_label()
	
	_refresh_visuals()

func _setup_soil_visual() -> void:
	soil_mesh = get_node_or_null("SoilMesh") as MeshInstance3D
	if not soil_mesh:
		soil_mesh = MeshInstance3D.new()
		soil_mesh.name = "SoilMesh"
		var b := BoxMesh.new()
		b.size = Vector3(1.15, 0.16, 1.15)
		soil_mesh.mesh = b
		soil_mesh.position = Vector3(0, 0.08, 0)
		add_child(soil_mesh)

func _setup_status_label() -> void:
	status_label = get_node_or_null("StatusLabel") as Label3D
	if not status_label:
		status_label = Label3D.new()
		status_label.name = "StatusLabel"
		status_label.position = Vector3(0, 0.65, 0)
		status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		status_label.font_size = 22
		status_label.outline_size = 6
		status_label.outline_modulate = Color("1a1a1a")
		status_label.modulate = Color("ffffff")
		add_child(status_label)

# -----------------------------------------------------------------
# Visual State Management
# -----------------------------------------------------------------
func _refresh_visuals() -> void:
	_update_soil_material()
	_update_crop_visual()
	_update_status_label()

func _update_soil_material() -> void:
	if not is_instance_valid(soil_mesh): return
	var mat := StandardMaterial3D.new()
	if not is_tilled:
		mat.albedo_color = Color("8d6e63") # Light untilled ground
		mat.roughness = 0.95
	elif is_watered:
		mat.albedo_color = Color("382418") # Deep rich moist loam
		mat.roughness = 0.45 # Wet sheen
	else:
		mat.albedo_color = Color("a68360") # Pale dry tilled soil
		mat.roughness = 0.92
	soil_mesh.material_override = mat

func _update_crop_visual() -> void:
	if crop_id == "":
		if is_instance_valid(crop_instance):
			crop_instance.queue_free()
			crop_instance = null
		return
		
	var crop_def := CropData.get_crop_definition(crop_id)
	if not crop_def: return
	
	if not is_instance_valid(crop_instance) or crop_instance.crop_type != crop_def.crop_id.replace("crop_", ""):
		if is_instance_valid(crop_instance):
			crop_instance.queue_free()
		var scene_res: PackedScene = load(crop_def.scene_path)
		if scene_res:
			crop_instance = scene_res.instantiate() as CropVisual
			add_child(crop_instance)
			
	if is_instance_valid(crop_instance):
		crop_instance.set_stage(stage, false)
		crop_instance.soil_moisture = "watered" if is_watered else "dry"

func _update_status_label() -> void:
	if not is_instance_valid(status_label): return
	
	if not is_tilled:
		status_label.text = "🌾 Cần xới đất"
		status_label.modulate = Color("bcaaa4")
		status_label.visible = true
	elif crop_id == "":
		status_label.text = "🌱 Đất trống"
		status_label.modulate = Color("c8e6c9")
		status_label.visible = false
	else:
		var crop_def := CropData.get_crop_definition(crop_id)
		var c_name: String = crop_def.display_name if crop_def else "Cây trồng"
		
		if stage >= 3:
			status_label.text = "✨ THU HOẠCH NGAY! ✨\n(%s x%d)" % [c_name, crop_def.harvest_quantity if crop_def else 3]
			status_label.modulate = Color("ffd54f")
			status_label.visible = true
		else:
			var stage_str: String = ["Gieo hạt", "Nảy mầm", "Đang lớn"][stage]
			var water_str := "💧 Đã tưới" if is_watered else "⚠️ Cần nước"
			var percent := int((float(stage) / 3.0 + (growth_progress / 3.0)) * 100.0)
			status_label.text = "%s · %s (%d%%)\n%s" % [c_name, stage_str, percent, water_str]
			status_label.modulate = Color("80d8ff") if is_watered else Color("ffb74d")
			status_label.visible = true

func _process(delta: float) -> void:
	if is_instance_valid(status_label) and status_label.visible:
		# Subtle floating animation for readability
		var bob := sin(Time.get_ticks_msec() * 0.003 + hash(plot_id) % 10) * 0.03
		status_label.position.y = (0.75 if stage >= 3 else 0.65) + bob

# -----------------------------------------------------------------
# Time Progression (Requirement 5)
# -----------------------------------------------------------------
func advance_growth_hour() -> void:
	if crop_id == "" or stage >= 3: return
	if not is_watered: return
	
	var crop_def := CropData.get_crop_definition(crop_id)
	if not crop_def: return
	
	growth_hours_accumulated += 1.0
	growth_progress = clampf(growth_hours_accumulated / crop_def.growth_duration, 0.0, 1.0)
	
	if growth_hours_accumulated >= crop_def.growth_duration:
		growth_hours_accumulated = 0.0
		growth_progress = 0.0
		stage = mini(3, stage + 1)
		crop_advanced.emit(plot_id, stage)
		
	_refresh_visuals()

func advance_growth_day(new_day: int) -> void:
	# Prevent double growth on repeated calls in the same day (Requirement 5)
	if last_growth_day == new_day:
		return
	last_growth_day = new_day
	
	if crop_id == "":
		return
		
	# Hours already advanced growth; the day boundary only dries the soil.
	is_watered = false

	_refresh_visuals()

# -----------------------------------------------------------------
# Farming Action Handlers (Requirement 4)
# -----------------------------------------------------------------
func till_soil() -> void:
	is_tilled = true
	_refresh_visuals()
	var fx = get_tree().get_first_node_in_group("chaos_feedback")
	if is_instance_valid(fx):
		fx.play_event("pickup", global_position + Vector3(0, 0.2, 0))
		fx.show_toast("🌱 Đất đã được xới tơi xốp, sẵn sàng gieo hạt!")
	_save_state()

func plant_crop(selected_crop_id: String) -> bool:
	if crop_id != "":
		return false
	var crop_def := CropData.get_crop_definition(selected_crop_id)
	if not crop_def:
		return false
		
	var econ := get_tree().get_first_node_in_group("economy_manager") as EconomyManager
	if not is_tilled or not is_instance_valid(econ) or not econ.inventory:
		return false
	if not econ.inventory.remove_item(crop_def.seed_item_id, 1):
		return false
		
	crop_id = selected_crop_id
	stage = 0
	growth_progress = 0.0
	growth_hours_accumulated = 0.0
	is_watered = false
	
	_refresh_visuals()
	
	var fx = get_tree().get_first_node_in_group("chaos_feedback")
	if is_instance_valid(fx):
		fx.play_event("pickup", global_position + Vector3(0, 0.25, 0))
		fx.show_toast("🌱 Đã gieo hạt %s xuống luống đất!" % crop_def.display_name)
		
	crop_planted.emit(plot_id, crop_id)
	_save_state()
	return true

func water_crop() -> void:
	if is_watered: return
	is_watered = true
	_refresh_visuals()
	
	var fx = get_tree().get_first_node_in_group("chaos_feedback")
	if is_instance_valid(fx):
		fx.play_event("pickup", global_position + Vector3(0, 0.25, 0))
		var c_name := "luống đất"
		if crop_id != "":
			var crop_def := CropData.get_crop_definition(crop_id)
			if crop_def: c_name = crop_def.display_name
		fx.show_toast("💧 Đã tưới nước mát cho %s! Cây sẽ lớn sau khi nghỉ ngơi." % c_name)
		
	crop_watered.emit(plot_id)
	_save_state()

func harvest_crop(player_node: Node) -> bool:
	if crop_id == "" or stage < 3:
		return false
		
	var crop_def := CropData.get_crop_definition(crop_id)
	if not crop_def:
		return false
		
	var qty: int = crop_def.harvest_quantity
	var econ := get_tree().get_first_node_in_group("economy_manager") as EconomyManager
	if not is_instance_valid(econ) or not econ.inventory:
		return false
	econ.inventory.add_item(crop_def.produce_item_id, qty)
		
	var harvested_id := crop_id
	crop_id = ""
	stage = 0
	growth_progress = 0.0
	growth_hours_accumulated = 0.0
	is_watered = false
	
	_refresh_visuals()
	
	var fx = get_tree().get_first_node_in_group("chaos_feedback")
	if is_instance_valid(fx):
		fx.play_event("pickup", global_position + Vector3(0, 0.35, 0))
		fx.show_toast("🎉 Thu hoạch thành công! +%d %s đã được cất vào túi đồ! 🧺" % [qty, crop_def.display_name])
		
	crop_harvested.emit(plot_id, harvested_id, qty)
	_save_state()
	return true

# -----------------------------------------------------------------
# Interactable Contract (Player Controls)
# -----------------------------------------------------------------
func available(player: Node3D) -> bool:
	return super.available(player)

func prompt(_player: Node3D) -> String:
	if not is_tilled:
		return "Xới tơi đất chuẩn bị gieo hạt (Phím E)"
		
	if crop_id == "":
		var available_seeds := _get_available_seed_crops()
		if available_seeds.is_empty():
			return "Đất đã xới (Hết hạt giống — Hãy mua tại Chợ / Tiệm Nông Sản!)"
			
		selected_seed_index = clampi(selected_seed_index, 0, available_seeds.size() - 1)
		var current_crop: CropData = available_seeds[selected_seed_index]
		var econ := get_tree().get_first_node_in_group("economy_manager") as EconomyManager
		var seed_count: int = econ.inventory.get_item_count(current_crop.seed_item_id) if is_instance_valid(econ) and econ.inventory else 1
		
		if available_seeds.size() > 1:
			var next_crop: CropData = available_seeds[(selected_seed_index + 1) % available_seeds.size()]
			return "Gieo hạt %s (-1 túi hạt) [Còn: %d] · [R] Đổi sang %s" % [current_crop.display_name, seed_count, next_crop.display_name]
		else:
			return "Gieo hạt %s (-1 túi hạt) [Còn: %d]" % [current_crop.display_name, seed_count]
			
	var crop_def := CropData.get_crop_definition(crop_id)
	var c_name: String = crop_def.display_name if crop_def else "Cây trồng"
	
	if stage >= 3:
		return "✨ Thu hoạch %s (Phím E - Nhận x%d quả/bó!)" % [c_name, crop_def.harvest_quantity if crop_def else 3]
	elif not is_watered:
		var stage_str: String = ["Gieo hạt", "Nảy mầm", "Đang lớn"][stage]
		return "Tưới nước cho %s (%s - Cần nước 💧)" % [c_name, stage_str]
	else:
		var stage_str: String = ["Gieo hạt", "Nảy mầm", "Đang lớn"][stage]
		return "%s (%s - Đã tưới nước mát 🌱)" % [c_name, stage_str]

func interact(player_node: Node3D) -> void:
	if not is_tilled:
		till_soil()
		return
		
	if crop_id == "":
		var available_seeds := _get_available_seed_crops()
		if available_seeds.is_empty():
			var fx = get_tree().get_first_node_in_group("chaos_feedback")
			if is_instance_valid(fx):
				fx.show_toast("⚠️ Bạn chưa có hạt giống trong túi! Hãy đến Chợ mua hạt giống.")
			return
		selected_seed_index = clampi(selected_seed_index, 0, available_seeds.size() - 1)
		plant_crop(available_seeds[selected_seed_index].crop_id)
		return
		
	if stage >= 3:
		harvest_crop(player_node)
		return
		
	if not is_watered:
		water_crop()
		return
	else:
		# Inspect crop status
		var crop_def := CropData.get_crop_definition(crop_id)
		var c_name: String = crop_def.display_name if crop_def else "Cây trồng"
		var fx = get_tree().get_first_node_in_group("chaos_feedback")
		if is_instance_valid(fx):
			fx.show_toast("🌿 %s đang phát triển tươi tốt! Đất đã đủ ẩm, hãy quay lại vào ngày mai." % c_name)

func _unhandled_input(event: InputEvent) -> void:
	if not is_inside_tree() or not visible: return
	var placement_mgr := get_tree().get_first_node_in_group("furniture_placement_manager") as FurniturePlacementManager
	if is_instance_valid(placement_mgr) and placement_mgr.is_active(): return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R and crop_id == "" and is_tilled:
			var pl := get_tree().get_first_node_in_group("players") as CharacterBody3D
			if is_instance_valid(pl) and pl.get("target") == self and not pl.has_meta("shopping_open") and not pl.has_meta("pet_rename_open") and not pl.has_meta("daily_summary_open") and not pl.has_meta("map_open") and global_position.distance_to(pl.global_position) <= interaction_radius:
				var available_seeds := _get_available_seed_crops()
				if available_seeds.size() > 1:
					selected_seed_index = (selected_seed_index + 1) % available_seeds.size()
					var next_crop: CropData = available_seeds[selected_seed_index]
					var fx = get_tree().get_first_node_in_group("chaos_feedback")
					if is_instance_valid(fx):
						fx.show_toast("🌱 Đã chọn hạt giống: %s" % next_crop.display_name)

func _get_available_seed_crops() -> Array[CropData]:
	var result: Array[CropData] = []
	var econ := get_tree().get_first_node_in_group("economy_manager") as EconomyManager
	if not is_instance_valid(econ) or not econ.inventory:
		return result
	for crop_def in CropData.get_all_crops().values():
		if econ.inventory.has_item(crop_def.seed_item_id):
			result.append(crop_def)
	return result

func _save_state() -> void:
	var econ := get_tree().get_first_node_in_group("economy_manager") as EconomyManager
	if is_instance_valid(econ) and econ.auto_save_on_change:
		econ.save_economy_state()

# -----------------------------------------------------------------
# Persistence (Requirement 7)
# -----------------------------------------------------------------
func get_save_data() -> Dictionary:
	return {
		"plot_id": plot_id,
		"is_tilled": is_tilled,
		"crop_id": crop_id,
		"stage": stage,
		"growth_progress": growth_progress,
		"growth_hours_accumulated": growth_hours_accumulated,
		"is_watered": is_watered,
		"last_growth_day": last_growth_day
	}

func apply_save_data(data: Dictionary) -> void:
	if data.is_empty(): return
	plot_id = str(data.get("plot_id", plot_id))
	is_tilled = bool(data.get("is_tilled", true))
	crop_id = str(data.get("crop_id", ""))
	stage = clampi(int(data.get("stage", 0)), 0, 3)
	growth_progress = clampf(float(data.get("growth_progress", 0.0)), 0.0, 1.0)
	growth_hours_accumulated = float(data.get("growth_hours_accumulated", 0.0))
	is_watered = bool(data.get("is_watered", false))
	last_growth_day = int(data.get("last_growth_day", -1))
	
	_refresh_visuals()
