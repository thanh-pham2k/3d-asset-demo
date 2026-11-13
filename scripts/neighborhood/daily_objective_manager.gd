class_name DailyObjectiveManager
extends Node

## Manages Cozy Daily Objectives for Couple Chaos 3D.
## Generates a balanced set of daily activities (Work, Earn, Pet Care, Farming, Home)
## every morning, tracks progress dynamically, grants bonus rewards to HouseholdWallet,
## and displays achievements in the end-of-day summary dialog.

signal objective_completed(objective_id: String, reward: int)
signal all_objectives_completed()
signal objectives_updated()

@export var current_day: int = 1
var objectives: Array[Dictionary] = []
var completed_count: int = 0
var objective_label: Label

func _ready() -> void:
	add_to_group("daily_objective_manager")
	_build_hud()
	objectives_updated.connect(_refresh_hud)
	call_deferred("_discover_dependencies")

func _discover_dependencies() -> void:
	# Connect to DailyLoopManager for new day triggers
	var daily_loop := get_tree().get_first_node_in_group("daily_loop_manager") as DailyLoopManager
	if is_instance_valid(daily_loop):
		if not daily_loop.day_advanced.is_connected(_on_day_started):
			daily_loop.day_advanced.connect(_on_day_started)
			
	# Connect to Business orders
	var garage := get_tree().get_first_node_in_group("garage_business") as GarageBusiness
	if is_instance_valid(garage):
		if not garage.order_completed.is_connected(_on_business_order_completed):
			garage.order_completed.connect(_on_business_order_completed)
			
	var hutieu := get_tree().get_first_node_in_group("hutieu_business") as HuTieuBusiness
	if is_instance_valid(hutieu):
		if not hutieu.order_completed.is_connected(_on_business_order_completed):
			hutieu.order_completed.connect(_on_business_order_completed)
			
	var econ := get_tree().get_first_node_in_group("economy_manager") as EconomyManager
	if is_instance_valid(econ):
		if not econ.purchase_completed.is_connected(_on_purchase_completed):
			econ.purchase_completed.connect(_on_purchase_completed)
		var saved := EconomySaveSystem.load_objective_data(econ.save_file_path)
		if not saved.is_empty():
			apply_save_data(saved)
	var day := daily_loop.current_day if is_instance_valid(daily_loop) else 1
	if objectives.is_empty() or current_day != day:
		generate_daily_objectives(day)

	var room := get_tree().get_first_node_in_group("room") as Room
	if is_instance_valid(room) and is_instance_valid(room.placement_manager):
		if not room.placement_manager.placement_confirmed.is_connected(_on_furniture_placed):
			room.placement_manager.placement_confirmed.connect(_on_furniture_placed)

	# Connect to Pet care
	var pet_mgr := get_tree().get_first_node_in_group("pet_manager") as PetManager
	if is_instance_valid(pet_mgr):
		if not pet_mgr.pet_interacted.is_connected(_on_pet_action):
			pet_mgr.pet_interacted.connect(_on_pet_action)
			
	# Connect to Farming actions
	var garden_mgr := get_tree().get_first_node_in_group("garden_manager") as GardenManager
	if is_instance_valid(garden_mgr):
		if not garden_mgr.plot_added.is_connected(_connect_plot_signals):
			garden_mgr.plot_added.connect(_connect_plot_signals)
		for plot in garden_mgr.plots:
			_connect_plot_signals(plot)

func _connect_plot_signals(plot: FarmPlot) -> void:
	if not is_instance_valid(plot): return
	if not plot.crop_watered.is_connected(_on_crop_watered):
		plot.crop_watered.connect(_on_crop_watered)
	if not plot.crop_harvested.is_connected(_on_crop_harvested):
		plot.crop_harvested.connect(_on_crop_harvested)

func generate_daily_objectives(day: int) -> void:
	current_day = day
	objectives.clear()
	completed_count = 0
	
	# Objective 1: Work (Serve Customers)
	var cust_target := 2 if day <= 2 else 3
	objectives.append({
		"id": "obj_serve_customers",
		"category": "work",
		"title": "Phục vụ khách hàng",
		"desc": "Phục vụ %d khách tại nơi làm việc hôm nay" % cust_target,
		"target": cust_target,
		"current": 0,
		"reward": 10000,
		"is_completed": false,
		"is_optional": false
	})
	
	# Objective 2: Earn Daily Target
	var rev_target := 40000 if day <= 2 else 60000
	objectives.append({
		"id": "obj_daily_revenue",
		"category": "earn",
		"title": "Doanh thu ngày",
		"desc": "Đạt doanh thu %s từ công việc kinh doanh" % HouseholdWallet.format_money(rev_target),
		"target": rev_target,
		"current": 0,
		"reward": 10000,
		"is_completed": false,
		"is_optional": false
	})
	
	# Objective 3: Cozy Home & Pet Care
	objectives.append({
		"id": "obj_care_pet",
		"category": "pet",
		"title": "Chăm sóc mèo cưng",
		"desc": "Cho bé mèo Miu Miu ăn hạt, uống nước hoặc vuốt ve",
		"target": 1,
		"current": 0,
		"reward": 5000,
		"is_completed": false,
		"is_optional": true
	})
	
	# Objective 4: Garden / Home Activity (Rotates cozy activities)
	if day % 2 == 1:
		objectives.append({
			"id": "obj_water_crops",
			"category": "farm",
			"title": "Tưới nước vườn rau",
			"desc": "Tưới nước cho ít nhất 1 luống rau sau nhà",
			"target": 1,
			"current": 0,
			"reward": 5000,
			"is_completed": false,
			"is_optional": true
		})
	else:
		objectives.append({
			"id": "obj_harvest_produce",
			"category": "farm",
			"title": "Thu hoạch nông sản",
			"desc": "Thu hoạch rau củ chín từ vườn sau nhà",
			"target": 1,
			"current": 0,
			"reward": 8000,
			"is_completed": false,
			"is_optional": true
		})
		
	if day % 3 == 0:
		objectives.append({
			"id": "obj_furniture", "category": "home",
			"title": "Trang trí nhà", "desc": "Mua hoặc đặt một món nội thất",
			"target": 1, "current": 0, "reward": 5000,
			"is_completed": false, "is_optional": true
		})
	objectives_updated.emit()

func _on_day_started(day_number: int) -> void:
	if day_number == current_day and not objectives.is_empty():
		return
	generate_daily_objectives(day_number)
	# Save after all day-advance listeners have updated their state.
	call_deferred("_save_progress")
	# Reconnect plots if newly spawned
	var garden_mgr := get_tree().get_first_node_in_group("garden_manager") as GardenManager
	if is_instance_valid(garden_mgr):
		for plot in garden_mgr.plots:
			_connect_plot_signals(plot)

func record_customer_served() -> void:
	advance_progress("obj_serve_customers", 1)

func record_revenue(amount: int) -> void:
	advance_progress("obj_daily_revenue", amount)

func record_pet_care() -> void:
	advance_progress("obj_care_pet", 1)

func record_crop_watered() -> void:
	advance_progress("obj_water_crops", 1)

func record_crop_harvested(_qty: int = 1) -> void:
	advance_progress("obj_harvest_produce", 1)

func advance_progress(obj_id: String, amount: int = 1, persist: bool = true) -> void:
	for obj in objectives:
		if obj["id"] == obj_id and not obj["is_completed"]:
			obj["current"] = mini(obj["target"], obj["current"] + amount)
			if obj["current"] >= obj["target"]:
				_complete_objective(obj)
			objectives_updated.emit()
			if persist: _save_progress()
			break

func _complete_objective(obj: Dictionary) -> void:
	obj["is_completed"] = true
	completed_count += 1
	var reward: int = obj.get("reward", 0)
	
	# Deposit bonus to shared wallet
	var econ := get_tree().get_first_node_in_group("economy_manager") as EconomyManager
	if is_instance_valid(econ) and is_instance_valid(econ.wallet) and reward > 0:
		var tx_id := "objective_%s_day_%d" % [obj["id"], current_day]
		econ.wallet.deposit(reward, "objective", "Thưởng mục tiêu ngày: %s" % obj["title"], tx_id)
		
	var fx = get_tree().get_first_node_in_group("chaos_feedback")
	if is_instance_valid(fx) and fx.has_method("show_toast"):
		fx.show_toast("🎯 Hoàn thành mục tiêu: %s! Nhận thưởng +%s! ✨" % [
			obj["title"],
			HouseholdWallet.format_money(reward)
		])
		
	objective_completed.emit(obj["id"], reward)
	
	if completed_count >= objectives.size():
		all_objectives_completed.emit()

func has_completed_any_objective() -> bool:
	return completed_count > 0

func get_summary_list() -> Array:
	return objectives.duplicate(true)

# Signal callbacks
func _on_business_order_completed(_order: BusinessOrder, reward: int) -> void:
	# Both objectives are updated before writing one snapshot.
	advance_progress("obj_serve_customers", 1, false)
	advance_progress("obj_daily_revenue", reward, false)
	# Other listeners still need to deposit revenue and update daily totals.
	call_deferred("_save_progress")

func _on_purchase_completed(product: EconomyProduct, _count: int, _cost: int) -> void:
	if product.category == "furniture" or product.id.begins_with("furn_"):
		advance_progress("obj_furniture")

func _on_furniture_placed(_furniture_id: String, _node: Node3D) -> void:
	advance_progress("obj_furniture")

func _on_pet_action(_action: String, _pet_node: Node = null) -> void:
	record_pet_care()

func _on_crop_watered(_plot_id: String) -> void:
	record_crop_watered()

func _on_crop_harvested(_plot_id: String, _crop_id: String, qty: int) -> void:
	record_crop_harvested(qty)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ObjectiveHUD"
	layer.layer = 5
	add_child(layer)
	objective_label = Label.new()
	objective_label.position = Vector2(18, 130)
	objective_label.add_theme_font_size_override("font_size", 14)
	objective_label.add_theme_color_override("font_color", Color("fff4dc"))
	objective_label.add_theme_color_override("font_shadow_color", Color("20180f"))
	objective_label.add_theme_constant_override("shadow_offset_x", 2)
	objective_label.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(objective_label)

func _refresh_hud() -> void:
	if not is_instance_valid(objective_label):
		return
	var lines := PackedStringArray(["MỤC TIÊU HÔM NAY"])
	for obj in objectives:
		var marker := "✓" if obj.get("is_completed", false) else "○"
		var optional := " (tùy chọn)" if obj.get("is_optional", false) else ""
		lines.append("%s %s %d/%d%s" % [marker, obj.get("title", ""), obj.get("current", 0), obj.get("target", 1), optional])
	objective_label.text = "\n".join(lines)

func _save_progress() -> void:
	if not is_inside_tree(): return
	var econ := get_tree().get_first_node_in_group("economy_manager") as EconomyManager
	if is_instance_valid(econ) and econ.auto_save_on_change:
		econ.save_economy_state()

# -----------------------------------------------------------------
# Persistence
# -----------------------------------------------------------------
func get_save_data() -> Dictionary:
	return {
		"day": current_day,
		"objectives": objectives,
		"completed_count": completed_count
	}

func apply_save_data(data: Dictionary) -> void:
	if data.is_empty(): return
	current_day = int(data.get("day", current_day))
	if data.has("objectives") and data["objectives"] is Array and not (data["objectives"] as Array).is_empty():
		objectives.clear()
		for entry in data["objectives"]:
			if entry is Dictionary:
				objectives.append(entry)
		completed_count = int(data.get("completed_count", 0))
		objectives_updated.emit()
	else:
		generate_daily_objectives(current_day)
