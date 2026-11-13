class_name GarageBusiness
extends BusinessShop

const MotorcycleCustomer = preload("res://scripts/neighborhood/business/motorcycle_customer.gd")
const REPAIR_KIT_ID := "tool_repair_kit"

## Boy's Motorcycle Repair Shop gameplay controller.
## Manages arriving customers with scooters, 3-second timed repair using Repair Kits,
## repair HUD/progress UI, and customer patience.

class RepairStation extends Interactable:
	var garage: GarageBusiness
	var station_type: String = "" # "bike_bay", "air_pump", "workbench", "tire_rack", "shop_sign"
	var bay_index: int = 0
	func _init() -> void:
		interaction_radius = 2.6
	
	func available(player_node: Node3D) -> bool:
		if station_type == "shop_sign":
			return enabled and is_instance_valid(garage)
		if station_type in ["air_pump", "workbench", "tire_rack"]:
			return false
		return enabled and is_instance_valid(garage) and garage.is_open
	
	func prompt(player_node: Node3D) -> String:
		if not garage: return "Tiệm sửa xe"
		return garage.get_station_prompt(self, player_node)
	
	func interact(player_node: Node3D) -> void:
		if garage: garage.on_station_interacted(self, player_node)

@export var repair_duration: float = 3.0
@export var base_repair_reward: int = 35000

var bay_positions: Array[Vector3] = [
	Vector3(-104, 0, -11),
	Vector3(-108, 0, -11)
]

# Track orders per bay: bay_index -> BusinessOrder
var bay_orders: Dictionary = {}
var bay_scooters: Dictionary = {}
var bay_status_labels: Dictionary = {}
var bay_reserved: Dictionary = {} # bay_index -> bool
var bay_customers: Dictionary = {} # bay_index -> MotorcycleCustomer

# Active 3-second repair state
var is_repairing: bool = false
var active_repair_bay: int = -1
var active_repair_order: BusinessOrder = null
var active_repair_player: Node3D = null
var repair_elapsed: float = 0.0
var needs_tool_shop_guidance: bool = false

# Repair HUD Elements (Minimal, non-overlapping bottom-center panel)
var repair_hud_layer: CanvasLayer = null
var repair_hud_panel: PanelContainer = null
var repair_status_label: Label = null
var repair_bar_text_label: Label = null
var repair_progress_bar: ProgressBar = null
var repair_kit_label: Label = null
var hud_message_timer: float = 0.0
var hud_override_mode: String = "" # "", "success", "error"

# Business Upgrades State
var is_second_bay_unlocked: bool = false
var is_better_tools_unlocked: bool = false
var is_faster_service_unlocked: bool = false

var second_bay_visual_node: Node3D = null
var tools_visual_node: Node3D = null
var compressor_visual_node: Node3D = null

# Legacy compatibility properties
var player_holding_tool: String = ""
var player_holding_tools: Dictionary = {}
var held_tool_visuals: Dictionary = {}

func get_holding_tool(player_node: Node3D = null) -> String:
	if not is_instance_valid(player_node): return player_holding_tool
	var pid: int = player_node.get("player_id") if "player_id" in player_node else 1
	return player_holding_tools.get(pid, player_holding_tool)

func set_holding_tool(player_node: Node3D, tool: String) -> void:
	var pid: int = player_node.get("player_id") if (is_instance_valid(player_node) and "player_id" in player_node) else 1
	player_holding_tools[pid] = tool
	player_holding_tool = tool

var service_catalog: Array[Dictionary] = [
	{
		"type": "inflate",
		"title": "Bảo dưỡng & bơm lốp",
		"reward": 30000,
		"patience": 60.0,
		"steps": ["repair"]
	},
	{
		"type": "patch",
		"title": "Sửa chữa & vá săm xe",
		"reward": 35000,
		"patience": 65.0,
		"steps": ["repair"]
	},
	{
		"type": "replace",
		"title": "Đại tu & thay phụ tùng",
		"reward": 45000,
		"patience": 75.0,
		"steps": ["repair"]
	}
]

var customer_names: Array[String] = [
	"Anh Tuấn", "Bác Năm", "Chú Tư", "Chị Lan", "Cô Mai", "Em Linh", "Anh Dũng"
]

func _ready() -> void:
	add_to_group("garage_business")
	shop_id = "garage"
	shop_name = "Tiệm Sửa Xe Máy Chú Ba"
	open_hour = 6.0
	close_hour = 21.0
	spawn_interval = 12.0
	super._ready()
	
	_create_work_stations()
	_build_repair_hud()

func _get_peak_hour_ranges() -> Array[Vector2]:
	return [
		Vector2(7.0, 9.0),   # Morning commuter rush
		Vector2(17.0, 19.0)  # Evening rush hour
	]

func get_repair_kit_count() -> int:
	var econ := get_tree().get_first_node_in_group("economy_manager") as EconomyManager
	if not is_instance_valid(econ):
		econ = get_node_or_null("../EconomyManager") as EconomyManager
	if is_instance_valid(econ) and econ.inventory:
		return econ.inventory.get_item_count(REPAIR_KIT_ID)
	return 0

func consume_repair_kit() -> bool:
	return consume_household_stock(REPAIR_KIT_ID)

func _create_work_stations() -> void:
	# 1. Motorcycle service bays (where customer bikes park)
	for i in range(bay_positions.size()):
		var bay := RepairStation.new()
		bay.name = "BikeBay_%d" % i
		bay.garage = self
		bay.station_type = "bike_bay"
		bay.bay_index = i
		bay.position = bay_positions[i]
		bay.interaction_radius = 2.8
		add_child(bay)
		
		# Overhead status label (elevated to avoid overlapping customer speech bubbles)
		var lbl := Label3D.new()
		lbl.position = Vector3(0, 2.35, 0)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.font_size = 20
		lbl.pixel_size = 0.004
		lbl.outline_size = 8
		lbl.modulate = Color("80d8ff")
		lbl.outline_modulate = Color("1a1a1a")
		lbl.visible = false
		bay.add_child(lbl)
		bay_status_labels[i] = lbl
	
	# 2. Decorative / legacy station nodes (disabled for direct interaction in simplified loop)
	var pump := RepairStation.new()
	pump.name = "AirPumpStation"
	pump.garage = self
	pump.station_type = "air_pump"
	pump.position = Vector3(-111, 0, -16)
	pump.enabled = false
	add_child(pump)
	
	var bench := RepairStation.new()
	bench.name = "WorkbenchStation"
	bench.garage = self
	bench.station_type = "workbench"
	bench.position = Vector3(-101, 0, -20)
	bench.enabled = false
	add_child(bench)
	
	var rack := RepairStation.new()
	rack.name = "TireRackStation"
	rack.garage = self
	rack.station_type = "tire_rack"
	rack.position = Vector3(-112, 0, -12)
	rack.enabled = false
	add_child(rack)
	
	# 3. Shop open/close sign station
	var sign_station := RepairStation.new()
	sign_station.name = "ShopSignStation"
	sign_station.garage = self
	sign_station.station_type = "shop_sign"
	sign_station.position = Vector3(-100.5, 0, -14.5)
	sign_station.interaction_radius = 2.2
	add_child(sign_station)

func _build_repair_hud() -> void:
	repair_hud_layer = CanvasLayer.new()
	repair_hud_layer.name = "GarageRepairHUD"
	repair_hud_layer.layer = 85
	add_child(repair_hud_layer)
	
	repair_hud_panel = PanelContainer.new()
	repair_hud_panel.name = "RepairPanel"
	repair_hud_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	repair_hud_panel.offset_left = -210
	repair_hud_panel.offset_right = 210
	repair_hud_panel.offset_top = -148
	repair_hud_panel.offset_bottom = -44
	repair_hud_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.13, 0.16, 0.92)
	style.border_color = Color("69f0ae")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	repair_hud_panel.add_theme_stylebox_override("panel", style)
	repair_hud_layer.add_child(repair_hud_panel)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	repair_hud_panel.add_child(vbox)
	
	repair_status_label = Label.new()
	repair_status_label.name = "RepairStatusLabel"
	repair_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	repair_status_label.add_theme_font_size_override("font_size", 16)
	repair_status_label.add_theme_color_override("font_color", Color("fff9c4"))
	repair_status_label.text = "Nhấn E để sửa xe"
	vbox.add_child(repair_status_label)
	
	repair_bar_text_label = Label.new()
	repair_bar_text_label.name = "RepairBarTextLabel"
	repair_bar_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	repair_bar_text_label.add_theme_font_size_override("font_size", 15)
	repair_bar_text_label.add_theme_color_override("font_color", Color("69f0ae"))
	repair_bar_text_label.text = "░░░░░░░░░░"
	repair_bar_text_label.visible = false
	vbox.add_child(repair_bar_text_label)
	
	repair_progress_bar = ProgressBar.new()
	repair_progress_bar.name = "RepairProgressBar"
	repair_progress_bar.min_value = 0.0
	repair_progress_bar.max_value = 100.0
	repair_progress_bar.value = 0.0
	repair_progress_bar.show_percentage = false
	repair_progress_bar.custom_minimum_size = Vector2(320, 12)
	var bg_bar := StyleBoxFlat.new()
	bg_bar.bg_color = Color(0.20, 0.25, 0.29, 0.9)
	bg_bar.set_corner_radius_all(5)
	var fg_bar := StyleBoxFlat.new()
	fg_bar.bg_color = Color("69f0ae")
	fg_bar.set_corner_radius_all(5)
	repair_progress_bar.add_theme_stylebox_override("background", bg_bar)
	repair_progress_bar.add_theme_stylebox_override("fill", fg_bar)
	repair_progress_bar.visible = false
	vbox.add_child(repair_progress_bar)
	
	repair_kit_label = Label.new()
	repair_kit_label.name = "RepairKitLabel"
	repair_kit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	repair_kit_label.add_theme_font_size_override("font_size", 14)
	repair_kit_label.add_theme_color_override("font_color", Color("80d8ff"))
	repair_kit_label.text = "🧰 Bộ dụng cụ sửa xe: 0"
	vbox.add_child(repair_kit_label)
	
	repair_hud_panel.visible = false

func _format_unicode_progress_bar(ratio: float, segments: int = 10) -> String:
	var clamped := clampf(ratio, 0.0, 1.0)
	var filled := clampi(int(round(clamped * float(segments))), 0, segments)
	var bar := ""
	for i in range(segments):
		bar += "█" if i < filled else "░"
	return bar

func reset_daily_state() -> void:
	_cancel_active_repair()
	super.reset_daily_state()
	_safe_clear_remaining_customers()
	_update_status_display()

func _safe_clear_remaining_customers() -> void:
	_cancel_active_repair()
	for bay in bay_customers.keys():
		var cust = bay_customers[bay]
		if is_instance_valid(cust) and cust.current_state != MotorcycleCustomer.State.DEPARTING and cust.current_state != MotorcycleCustomer.State.DESPAWNED:
			cust.notify_order_failed("shop_closed")
	bay_orders.clear()
	for bay in bay_status_labels:
		if is_instance_valid(bay_status_labels[bay]):
			bay_status_labels[bay].visible = false
	player_holding_tool = ""
	player_holding_tools.clear()

func get_patience_multiplier() -> float:
	var base_mult := super.get_patience_multiplier()
	if is_faster_service_unlocked:
		base_mult *= 1.40 # 40% more patient customers
	return base_mult

func apply_second_bay_upgrade() -> void:
	is_second_bay_unlocked = true
	_build_second_bay_visual()

func apply_better_tools_upgrade() -> void:
	is_better_tools_unlocked = true
	_build_better_tools_visual()

func apply_compressor_upgrade() -> void:
	is_faster_service_unlocked = true
	spawn_interval = 8.0
	_build_compressor_visual()

func _build_second_bay_visual() -> void:
	if is_instance_valid(second_bay_visual_node): return
	second_bay_visual_node = Node3D.new()
	second_bay_visual_node.name = "SecondBayUpgradeVisual"
	
	var platform := MeshInstance3D.new()
	var p_mesh := BoxMesh.new()
	p_mesh.size = Vector3(1.6, 0.08, 2.6)
	platform.mesh = p_mesh
	var p_mat := StandardMaterial3D.new()
	p_mat.albedo_color = Color("37474f")
	p_mat.metallic = 0.8
	p_mat.roughness = 0.3
	platform.material_override = p_mat
	platform.position = bay_positions[1] + Vector3(0, 0.04, 0)
	second_bay_visual_node.add_child(platform)
	
	for x_off in [-0.85, 0.85]:
		var stripe := MeshInstance3D.new()
		var s_mesh := BoxMesh.new()
		s_mesh.size = Vector3(0.12, 0.09, 2.6)
		stripe.mesh = s_mesh
		var s_mat := StandardMaterial3D.new()
		s_mat.albedo_color = Color("ffd600")
		stripe.material_override = s_mat
		stripe.position = bay_positions[1] + Vector3(x_off, 0.045, 0)
		second_bay_visual_node.add_child(stripe)
	
	for z_off in [-1.0, 1.0]:
		var cyl := MeshInstance3D.new()
		var c_mesh := CylinderMesh.new()
		c_mesh.top_radius = 0.07
		c_mesh.bottom_radius = 0.07
		c_mesh.height = 0.45
		cyl.mesh = c_mesh
		var c_mat := StandardMaterial3D.new()
		c_mat.albedo_color = Color("90a4ae")
		cyl.material_override = c_mat
		cyl.position = bay_positions[1] + Vector3(0, 0.22, z_off)
		second_bay_visual_node.add_child(cyl)
		
	var badge := Label3D.new()
	badge.position = bay_positions[1] + Vector3(0, 2.7, 0)
	badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	badge.font_size = 18
	badge.pixel_size = 0.004
	badge.outline_size = 6
	badge.modulate = Color("69f0ae")
	badge.outline_modulate = Color("1a1a1a")
	badge.text = "🛠️ KHOANG 2: ĐÃ NÂNG CẤP"
	second_bay_visual_node.add_child(badge)
	
	add_child(second_bay_visual_node)

func _build_better_tools_visual() -> void:
	if is_instance_valid(tools_visual_node): return
	tools_visual_node = Node3D.new()
	tools_visual_node.name = "BetterToolsUpgradeVisual"
	var wb_pos := Vector3(-101, 0, -20)
	
	var chest := MeshInstance3D.new()
	var ch_mesh := BoxMesh.new()
	ch_mesh.size = Vector3(0.9, 0.65, 0.5)
	chest.mesh = ch_mesh
	var ch_mat := StandardMaterial3D.new()
	ch_mat.albedo_color = Color("c62828")
	ch_mat.metallic = 0.6
	ch_mat.roughness = 0.4
	chest.material_override = ch_mat
	chest.position = wb_pos + Vector3(0, 0.8, -0.3)
	tools_visual_node.add_child(chest)
	
	for y_h in [0.65, 0.8, 0.95]:
		var handle := MeshInstance3D.new()
		var h_mesh := BoxMesh.new()
		h_mesh.size = Vector3(0.5, 0.03, 0.04)
		handle.mesh = h_mesh
		var h_mat := StandardMaterial3D.new()
		h_mat.albedo_color = Color("eceff1")
		h_mat.metallic = 0.9
		handle.material_override = h_mat
		handle.position = wb_pos + Vector3(0, y_h, -0.03)
		tools_visual_node.add_child(handle)
		
	var light_mesh := MeshInstance3D.new()
	var l_box := BoxMesh.new()
	l_box.size = Vector3(1.1, 0.06, 0.25)
	light_mesh.mesh = l_box
	var l_mat := StandardMaterial3D.new()
	l_mat.albedo_color = Color("ffffff")
	l_mat.emission_enabled = true
	l_mat.emission = Color("ffffff")
	l_mat.emission_energy_multiplier = 1.5
	light_mesh.material_override = l_mat
	light_mesh.position = wb_pos + Vector3(0, 2.3, 0)
	tools_visual_node.add_child(light_mesh)
	
	add_child(tools_visual_node)

func _build_compressor_visual() -> void:
	if is_instance_valid(compressor_visual_node): return
	compressor_visual_node = Node3D.new()
	compressor_visual_node.name = "CompressorUpgradeVisual"
	var pump_pos := Vector3(-111, 0, -16)
	
	var tank := MeshInstance3D.new()
	var t_mesh := CylinderMesh.new()
	t_mesh.top_radius = 0.28
	t_mesh.bottom_radius = 0.28
	t_mesh.height = 1.0
	tank.mesh = t_mesh
	var t_mat := StandardMaterial3D.new()
	t_mat.albedo_color = Color("b71c1c")
	t_mat.roughness = 0.4
	tank.material_override = t_mat
	tank.rotation.z = PI / 2.0
	tank.position = pump_pos + Vector3(0, 0.45, 0.4)
	compressor_visual_node.add_child(tank)
	
	for dial_x in [-0.2, 0.2]:
		var dial := MeshInstance3D.new()
		var d_mesh := CylinderMesh.new()
		d_mesh.top_radius = 0.08
		d_mesh.bottom_radius = 0.08
		d_mesh.height = 0.05
		dial.mesh = d_mesh
		var d_mat := StandardMaterial3D.new()
		d_mat.albedo_color = Color("ffd54f")
		d_mat.metallic = 0.8
		dial.material_override = d_mat
		dial.position = pump_pos + Vector3(dial_x, 0.85, 0.4)
		compressor_visual_node.add_child(dial)
	
	add_child(compressor_visual_node)

func _try_spawn_customer() -> void:
	var free_bay := -1
	var allowed_bays: int = bay_positions.size() if is_second_bay_unlocked else 1
	for i in range(allowed_bays):
		if not bay_orders.has(i) and not bay_reserved.get(i, false):
			free_bay = i
			break
	if free_bay == -1: return
	
	bay_reserved[free_bay] = true
	
	var service: Dictionary = service_catalog[randi() % service_catalog.size()]
	var cust_name: String = customer_names[randi() % customer_names.size()]
	var order_id := "garage_%d_%d_%d_%d" % [free_bay, int(Time.get_unix_time_from_system()), Time.get_ticks_usec(), randi()]
	var configured_reward: int = int(service.get("reward", base_repair_reward))
	
	var adjusted_patience: float = float(service["patience"]) * get_patience_multiplier()
	var order := BusinessOrder.new(
		order_id,
		service["type"],
		service["title"],
		configured_reward,
		service["steps"].duplicate(),
		adjusted_patience
	)
	order.is_peak_hour = is_peak_hour
	order.customer_name = cust_name
	order.table_index = free_bay
	order.target_spot = to_global(bay_positions[free_bay])
	
	var approach_path: Array[Vector3] = [
		Vector3(-106, 0, 8),
		Vector3(-106, 0, -4),
		bay_positions[free_bay]
	]
	var departure_path: Array[Vector3] = [
		bay_positions[free_bay],
		Vector3(-106, 0, -4),
		Vector3(-125, 0, 0)
	]
	
	var customer := MotorcycleCustomer.new()
	customer.name = "MotorcycleCustomer_%d" % free_bay
	add_child(customer)
	customer.setup(free_bay, cust_name, bay_positions[free_bay], approach_path, departure_path)
	customer.order = order
	bay_customers[free_bay] = customer
	bay_scooters[free_bay] = customer.scooter
	
	customer.arrived_at_bay.connect(func(bay_idx: int):
		if not is_instance_valid(self): return
		bay_orders[bay_idx] = order
		active_orders.append(order)
		order_received.emit(order)
		_update_bay_display(bay_idx)
	)
	
	customer.departed_from_bay.connect(func(bay_idx: int):
		if not is_instance_valid(self): return
		if bay_customers.get(bay_idx) != customer: return
		bay_reserved.erase(bay_idx)
		bay_customers.erase(bay_idx)
		bay_orders.erase(bay_idx)
		bay_scooters.erase(bay_idx)
		if bay_status_labels.has(bay_idx):
			bay_status_labels[bay_idx].visible = false
	)

func complete_order(order: BusinessOrder) -> bool:
	if not is_instance_valid(order): return false
	if not active_orders.has(order) or completed_order_ids.has(order.order_id):
		return false
	if order.status != BusinessOrder.Status.COMPLETED:
		return false
	
	var bay := order.table_index
	if is_better_tools_unlocked:
		var bonus_tip := int(order.reward_money * 0.30)
		order.tip_money += bonus_tip
		
	var success := super.complete_order(order)
	if success:
		if bay_customers.has(bay) and is_instance_valid(bay_customers[bay]):
			bay_customers[bay].notify_service_done()
	return success

func _spawn_bay_scooter(bay_index: int) -> void:
	if bay_scooters.has(bay_index) and is_instance_valid(bay_scooters[bay_index]):
		bay_scooters[bay_index].queue_free()
	
	var scooter_scene: PackedScene = load("res://scenes/neighborhood/scooter.tscn")
	var scooter: Node3D = scooter_scene.instantiate()
	scooter.position = bay_positions[bay_index]
	scooter.rotation.y = PI
	add_child(scooter)
	bay_scooters[bay_index] = scooter

func _on_customer_depart(order: BusinessOrder) -> void:
	if active_repair_order == order:
		_cancel_active_repair()
	var bay := order.table_index
	if bay_customers.has(bay) and is_instance_valid(bay_customers[bay]):
		var cust: MotorcycleCustomer = bay_customers[bay]
		if cust.current_state != MotorcycleCustomer.State.DEPARTING and cust.current_state != MotorcycleCustomer.State.DESPAWNED:
			if order.status != BusinessOrder.Status.PAID and order.status != BusinessOrder.Status.COMPLETED:
				if bay_status_labels.has(bay):
					bay_status_labels[bay].text = "🏍️ %s: [ĐÃ HỦY - KHÁCH BỎ VỀ 💢]" % order.customer_name
					bay_status_labels[bay].modulate = Color("ff5252")
				cust.notify_order_failed("timeout")
	else:
		if bay_orders.has(bay) and bay_orders[bay] == order:
			bay_orders.erase(bay)
			bay_reserved.erase(bay)
			if bay_scooters.has(bay) and is_instance_valid(bay_scooters[bay]):
				bay_scooters[bay].queue_free()
				bay_scooters.erase(bay)
			if bay_status_labels.has(bay):
				bay_status_labels[bay].visible = false

func _process(delta: float) -> void:
	# Pause customer patience decay for the motorcycle currently being repaired
	if is_repairing and is_instance_valid(active_repair_order):
		active_repair_order.patience_remaining = minf(
			active_repair_order.patience_max,
			active_repair_order.patience_remaining + delta
		)
	super._process(delta)
	_update_active_repair(delta)
	_update_repair_hud(delta)
	for bay in bay_orders:
		_update_bay_display(bay)

func _update_active_repair(delta: float) -> void:
	if not is_repairing:
		return
	
	# Validate active repair state; cancel safely without consuming kit if invalid
	if not is_open or not is_instance_valid(active_repair_order) or not active_orders.has(active_repair_order):
		_cancel_active_repair()
		return
	if active_repair_order.status == BusinessOrder.Status.FAILED or active_repair_order.status == BusinessOrder.Status.CANCELLED or active_repair_order.status == BusinessOrder.Status.PAID:
		_cancel_active_repair()
		return
	if is_instance_valid(active_repair_player):
		var bay_world_pos := to_global(bay_positions[active_repair_bay])
		if active_repair_player.global_position.distance_to(bay_world_pos) > 4.5:
			_show_feedback(bay_world_pos, "⚠️ Đã dừng sửa xe do rời khỏi khoang!", Color("ffab40"))
			_cancel_active_repair()
			return
	
	var safe_duration := maxf(0.1, repair_duration)
	repair_elapsed = minf(safe_duration, repair_elapsed + delta)
	
	if repair_elapsed >= safe_duration:
		_finish_active_repair()

func _cancel_active_repair() -> void:
	if is_instance_valid(active_repair_order) and active_repair_order.status == BusinessOrder.Status.IN_PROGRESS:
		active_repair_order.status = BusinessOrder.Status.PENDING
	is_repairing = false
	active_repair_bay = -1
	active_repair_order = null
	active_repair_player = null
	repair_elapsed = 0.0

func _finish_active_repair() -> void:
	var order := active_repair_order
	var bay := active_repair_bay
	is_repairing = false
	active_repair_bay = -1
	active_repair_order = null
	active_repair_player = null
	repair_elapsed = 0.0
	
	if not is_instance_valid(order) or not active_orders.has(order):
		return
	if completed_order_ids.has(order.order_id):
		return
	
	# Verify and consume 1 Repair Kit only on successful completion
	if get_repair_kit_count() <= 0 or not consume_repair_kit():
		order.status = BusinessOrder.Status.PENDING
		needs_tool_shop_guidance = true
		_show_out_of_kits_message(to_global(bay_positions[bay]))
		return
	
	needs_tool_shop_guidance = (get_repair_kit_count() <= 0)
	
	# Complete all remaining steps on the order
	while not order.get_current_required_step().is_empty():
		var step_name := order.get_current_required_step()
		order.advance_step(step_name)
		order_step_done.emit(order, step_name)
	order.status = BusinessOrder.Status.COMPLETED
	
	var preview_reward := order.reward_money
	if is_better_tools_unlocked:
		preview_reward += int(order.reward_money * 0.30)
	if order.is_peak_hour and peak_multiplier > 1.0:
		preview_reward += int(float(order.reward_money) * (peak_multiplier - 1.0))
	var stars := order.get_star_rating()
	if stars == 5:
		preview_reward += int(float(order.reward_money) * 0.20)
	elif stars == 4:
		preview_reward += int(float(order.reward_money) * 0.10)
	
	if complete_order(order):
		var actual_payout := order.get_total_payout()
		var reward_str := format_money(actual_payout if actual_payout > 0 else preview_reward)
		_show_repair_completed_hud(reward_str)
		_show_feedback(to_global(bay_positions[bay]), "✓ Sửa xe thành công! +%s đ" % reward_str, Color("69f0ae"))

func _show_out_of_kits_message(world_pos: Vector3) -> void:
	var msg := "Hết dụng cụ sửa xe! Hãy đến cửa hàng mua thêm."
	_show_feedback(world_pos, msg, Color("ff5252"))
	if is_instance_valid(repair_hud_panel):
		hud_override_mode = "error"
		hud_message_timer = 3.5
		repair_hud_panel.visible = true
		repair_status_label.text = msg
		repair_status_label.add_theme_color_override("font_color", Color("ff5252"))
		repair_bar_text_label.visible = false
		repair_progress_bar.visible = false
		repair_kit_label.text = "🧰 Bộ dụng cụ sửa xe: %d" % get_repair_kit_count()

func _show_repair_completed_hud(reward_str: String) -> void:
	if not is_instance_valid(repair_hud_panel):
		return
	hud_override_mode = "success"
	hud_message_timer = 2.8
	repair_hud_panel.visible = true
	repair_status_label.text = "✓ Sửa xe thành công! +%s đ" % reward_str
	repair_status_label.add_theme_color_override("font_color", Color("69f0ae"))
	repair_bar_text_label.visible = true
	repair_bar_text_label.text = "██████████"
	repair_progress_bar.visible = true
	repair_progress_bar.value = 100.0
	repair_kit_label.text = "🧰 Bộ dụng cụ sửa xe: %d" % get_repair_kit_count()

func _update_repair_hud(delta: float) -> void:
	if not is_instance_valid(repair_hud_panel):
		return
	
	var kit_count := get_repair_kit_count()
	if kit_count > 0 and needs_tool_shop_guidance:
		needs_tool_shop_guidance = false
	
	repair_kit_label.text = "🧰 Bộ dụng cụ sửa xe: %d" % kit_count
	if kit_count > 0:
		repair_kit_label.add_theme_color_override("font_color", Color("80d8ff"))
	else:
		repair_kit_label.add_theme_color_override("font_color", Color("ff8a80"))
	
	if is_repairing and is_instance_valid(active_repair_order):
		var ratio := clampf(repair_elapsed / maxf(0.1, repair_duration), 0.0, 1.0)
		var pct := clampi(int(round(ratio * 100.0)), 0, 100)
		repair_hud_panel.visible = true
		repair_status_label.text = "Đang sửa xe... %d%%" % pct
		repair_status_label.add_theme_color_override("font_color", Color("fff9c4"))
		repair_bar_text_label.visible = true
		repair_bar_text_label.text = _format_unicode_progress_bar(ratio, 10)
		repair_progress_bar.visible = true
		repair_progress_bar.value = ratio * 100.0
		return
	
	if hud_message_timer > 0.0:
		hud_message_timer = maxf(0.0, hud_message_timer - delta)
		if hud_message_timer <= 0.0:
			hud_override_mode = ""
		else:
			repair_hud_panel.visible = true
			return
	
	# Show HUD when player is inside or near the repair shop
	var player := get_tree().get_first_node_in_group("players") as Node3D
	if not is_instance_valid(player):
		repair_hud_panel.visible = false
		return
	
	var garage_center := to_global(Vector3(-106, 0, -14))
	var dist_to_garage := player.global_position.distance_to(garage_center)
	if dist_to_garage > 15.0:
		repair_hud_panel.visible = false
		return
	
	repair_hud_panel.visible = true
	repair_bar_text_label.visible = false
	repair_progress_bar.visible = false
	
	var has_waiting_bike := false
	for bay_idx in bay_orders:
		var ord: BusinessOrder = bay_orders[bay_idx]
		if is_instance_valid(ord) and (ord.status == BusinessOrder.Status.PENDING or ord.status == BusinessOrder.Status.IN_PROGRESS):
			has_waiting_bike = true
			break
	
	if kit_count <= 0:
		repair_status_label.text = "Hết dụng cụ sửa xe! Hãy đến cửa hàng mua thêm."
		repair_status_label.add_theme_color_override("font_color", Color("ff8a80"))
	elif has_waiting_bike:
		repair_status_label.text = "Nhấn E để sửa xe"
		repair_status_label.add_theme_color_override("font_color", Color("69f0ae"))
	else:
		repair_status_label.text = "Đang chờ khách mang xe đến..."
		repair_status_label.add_theme_color_override("font_color", Color("cfd8dc"))

func _update_bay_display(bay_index: int) -> void:
	if not bay_status_labels.has(bay_index): return
	var lbl: Label3D = bay_status_labels[bay_index]
	if not bay_orders.has(bay_index):
		lbl.visible = false
		return
	
	var order: BusinessOrder = bay_orders[bay_index]
	if order.status == BusinessOrder.Status.FAILED or order.status == BusinessOrder.Status.CANCELLED:
		lbl.visible = true
		lbl.text = "🏍️ %s: [ĐÃ HỦY - KHÁCH BỎ VỀ 💢]" % order.customer_name
		lbl.modulate = Color("ff5252")
		return
	
	lbl.visible = true
	if is_repairing and active_repair_bay == bay_index and active_repair_order == order:
		var ratio := clampf(repair_elapsed / maxf(0.1, repair_duration), 0.0, 1.0)
		var pct := clampi(int(round(ratio * 100.0)), 0, 100)
		lbl.text = "Đang sửa xe... %d%%\n%s" % [pct, _format_unicode_progress_bar(ratio, 10)]
		lbl.modulate = Color("80d8ff")
		return
	
	var patience_pct := int(order.get_patience_ratio() * 100.0)
	var kit_count := get_repair_kit_count()
	lbl.text = "🏍️ %s: %s (+%s đ)\n⏳ Kiên nhẫn: %d%% | 🧰 Dụng cụ: %d\n👉 Nhấn E để sửa xe" % [
		order.customer_name,
		order.service_title,
		format_money(order.reward_money),
		patience_pct,
		kit_count
	]
	
	if order.get_patience_ratio() > 0.5:
		lbl.modulate = Color("69f0ae")
	elif order.get_patience_ratio() > 0.25:
		lbl.modulate = Color("ffd740")
	else:
		lbl.modulate = Color("ff5252")

func get_station_prompt(station: RepairStation, _player_node: Node3D = null) -> String:
	match station.station_type:
		"bike_bay":
			var bay := station.bay_index
			if is_repairing and active_repair_bay == bay:
				var ratio := clampf(repair_elapsed / maxf(0.1, repair_duration), 0.0, 1.0)
				return "Đang sửa xe... %d%%" % clampi(int(round(ratio * 100.0)), 0, 100)
			if not bay_orders.has(bay):
				return "Khoang sửa xe trống"
			var order: BusinessOrder = bay_orders[bay]
			if order.status == BusinessOrder.Status.FAILED or order.status == BusinessOrder.Status.CANCELLED:
				return "Khách đã rời đi"
			return "Nhấn E để sửa xe"
		
		"shop_sign":
			if is_open:
				return "Đóng cửa tiệm sửa xe (kết thúc ngày)"
			else:
				return "Mở cửa tiệm sửa xe"
	
	return "Tương tác"

func on_station_interacted(station: RepairStation, player_node: Node3D) -> void:
	match station.station_type:
		"shop_sign":
			if is_open:
				close_shop()
				_show_feedback(station.global_position, "Tiệm sửa xe đã ĐÓNG CỬA nghỉ ngơi!", Color("ffd54f"))
			else:
				open_shop()
				_show_feedback(station.global_position, "🎉 Tiệm sửa xe chính thức MỞ CỬA đón khách!", Color("69f0ae"))
		
		"bike_bay":
			if is_repairing:
				return
			
			var bay := station.bay_index
			if not bay_orders.has(bay):
				_show_feedback(station.global_position, "Khoang trống, đang chờ khách ghé...", Color("cfd8dc"))
				return
			
			var order: BusinessOrder = bay_orders[bay]
			if not is_instance_valid(order) or not active_orders.has(order):
				return
			if order.status == BusinessOrder.Status.FAILED or order.status == BusinessOrder.Status.CANCELLED or order.status == BusinessOrder.Status.PAID or order.status == BusinessOrder.Status.COMPLETED:
				return
			if completed_order_ids.has(order.order_id):
				return
			
			# Check whether player has at least 1 Repair Kit
			if get_repair_kit_count() < 1:
				needs_tool_shop_guidance = true
				_show_out_of_kits_message(station.global_position)
				return
			
			# Start 3-second repair progress
			is_repairing = true
			active_repair_bay = bay
			active_repair_order = order
			active_repair_player = player_node
			repair_elapsed = 0.0
			hud_override_mode = ""
			hud_message_timer = 0.0
			order.status = BusinessOrder.Status.IN_PROGRESS
			_update_bay_display(bay)
			_update_repair_hud(0.0)
