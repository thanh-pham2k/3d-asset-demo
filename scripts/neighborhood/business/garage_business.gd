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
		if station_type in ["shop_sign", "upgrade_board"]:
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

# Business Upgrades & 5-Level Progression State
const GARAGE_LEVEL_CONFIG: Dictionary = {
	1: {
		"title": "Cấp 1 — Tiệm Nhỏ Khởi Nghiệp",
		"cost": 0,
		"min_customers": 0,
		"benefit": "1 khoang sửa xe, khách tiêu chuẩn, sửa 3.0 giây (1 Bộ dụng cụ/lần)"
	},
	2: {
		"title": "Cấp 2 — Tiệm Mở Rộng 2 Khoang",
		"cost": 65000,
		"min_customers": 3,
		"benefit": "Mở Khoang sửa xe số 2, thêm khách mới & đơn Cao Cấp (4.5s · thưởng 2x)"
	},
	3: {
		"title": "Cấp 3 — Trang Bị Máy Nén Khí",
		"cost": 110000,
		"min_customers": 8,
		"benefit": "Sửa thường giảm còn 2.0s, thêm máy nén khí & tăng 15% kiên nhẫn khách"
	},
	4: {
		"title": "Cấp 4 — Thuê Thợ Phụ Tiệm Xe",
		"cost": 160000,
		"min_customers": 14,
		"benefit": "Thợ phụ tự sửa ở Khoang 2 khi mở cửa (chậm hơn người chơi, tốn 15,000 đ/ngày)"
	},
	5: {
		"title": "Cấp 5 — Gara Uy Tín Khu Phố",
		"cost": 240000,
		"min_customers": 22,
		"benefit": "Nâng cấp diện mạo gara, tăng tỉ lệ đơn Cao Cấp & VIP, cộng uy tín dịch vụ"
	}
}

var is_second_bay_unlocked: bool = false
var is_better_tools_unlocked: bool = false
var is_faster_service_unlocked: bool = false
var assistant_hired: bool = false
var assistant_daily_cost: int = 15000
var assistant_paid_day: int = 0
var assistant_repairing: bool = false
var assistant_order: BusinessOrder = null
var assistant_elapsed: float = 0.0
var assistant_duration: float = 5.5

var second_bay_visual_node: Node3D = null
var tools_visual_node: Node3D = null
var compressor_visual_node: Node3D = null
var assistant_visual_node: Node3D = null
var assistant_arm_node: Node3D = null
var assistant_status_label: Label3D = null
var established_visual_node: Node3D = null
var established_sign_light: MeshInstance3D = null

var upgrade_ui_layer: CanvasLayer = null
var upgrade_current_label: Label = null
var upgrade_next_label: Label = null
var upgrade_cost_label: Label = null
var upgrade_benefit_label: Label = null
var upgrade_confirm_btn: Button = null
var upgrade_feedback_label: Label = null

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

var premium_service_catalog: Array[Dictionary] = [
	{
		"type": "premium_engine",
		"title": "Đại tu động cơ & phanh ABS",
		"reward": 70000,
		"patience": 75.0,
		"duration": 4.5,
		"steps": ["repair"]
	},
	{
		"type": "premium_overhaul",
		"title": "Bảo dưỡng toàn diện xe ga",
		"reward": 80000,
		"patience": 80.0,
		"duration": 4.5,
		"steps": ["repair"]
	}
]

var customer_names: Array[String] = [
	"Anh Tuấn", "Bác Năm", "Chú Tư", "Chị Lan", "Cô Mai", "Em Linh", "Anh Dũng"
]

var extra_customer_names: Array[String] = [
	"Anh Khang", "Chị Thảo", "Bác Hùng", "Anh Minh", "Cô Hương"
]

func _ready() -> void:
	add_to_group("garage_business")
	shop_id = "garage"
	shop_name = "Tiệm Sửa Xe Máy Chú Ba"
	open_hour = 6.0
	close_hour = 21.0
	auto_open_by_schedule = true
	spawn_interval = 12.0
	auto_level_up_enabled = false
	super._ready()
	var tm := get_tree().get_first_node_in_group("time_manager") as NeighborhoodTimeManager
	_check_operating_hours(tm.current_hour if is_instance_valid(tm) else 8.0)
	
	_create_work_stations()
	_build_repair_hud()
	_build_upgrade_ui()

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

	# 4. Garage Upgrade Board station
	var upgrade_station := RepairStation.new()
	upgrade_station.name = "UpgradeBoardStation"
	upgrade_station.garage = self
	upgrade_station.station_type = "upgrade_board"
	upgrade_station.position = Vector3(-99.0, 0, -14.5)
	upgrade_station.interaction_radius = 2.2
	add_child(upgrade_station)

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
	_cancel_assistant_repair()
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
	if business_level >= 3 or is_faster_service_unlocked:
		base_mult *= 1.15 # +15% patience bonus from Level 3 equipment
	return base_mult

func get_order_repair_duration(order: BusinessOrder) -> float:
	if is_instance_valid(order) and order.repair_duration_override > 0.0:
		# Level 3+ slightly smooths premium prep without stacking to instantaneous
		var prem_dur := order.repair_duration_override
		if business_level >= 3:
			prem_dur = maxf(3.5, prem_dur - 0.5)
		return maxf(1.8, prem_dur)
	if business_level >= 3 or is_faster_service_unlocked:
		return 2.0
	return maxf(1.8, repair_duration)

func apply_second_bay_upgrade() -> void:
	is_second_bay_unlocked = true
	business_level = maxi(business_level, 2)
	_build_second_bay_visual()

func apply_better_tools_upgrade() -> void:
	is_better_tools_unlocked = true
	_build_better_tools_visual()

func apply_compressor_upgrade() -> void:
	is_faster_service_unlocked = true
	business_level = maxi(business_level, 3)
	spawn_interval = 9.0
	_build_better_tools_visual()
	_build_compressor_visual()

func apply_garage_level_unlocks(lvl: int) -> void:
	business_level = clampi(lvl, 1, 5)
	if business_level >= 2:
		apply_second_bay_upgrade()
	if business_level >= 3:
		apply_compressor_upgrade()
	if business_level >= 4:
		assistant_hired = true
		_build_assistant_visual()
	if business_level >= 5:
		_build_established_garage_visual()
	_update_status_display()

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

func _build_assistant_visual() -> void:
	if is_instance_valid(assistant_visual_node):
		return
	assistant_visual_node = Node3D.new()
	assistant_visual_node.name = "AssistantMechanicVisual"
	assistant_visual_node.position = bay_positions[1] + Vector3(1.15, 0, -0.3)

	var body := MeshInstance3D.new()
	var b_mesh := CapsuleMesh.new()
	b_mesh.radius = 0.24
	b_mesh.height = 0.72
	body.mesh = b_mesh
	var b_mat := StandardMaterial3D.new()
	b_mat.albedo_color = Color("1e88e5")
	body.material_override = b_mat
	body.position = Vector3(0, 0.58, 0)
	assistant_visual_node.add_child(body)

	var head := MeshInstance3D.new()
	var h_mesh := SphereMesh.new()
	h_mesh.radius = 0.20
	head.mesh = h_mesh
	var h_mat := StandardMaterial3D.new()
	h_mat.albedo_color = Color("f4c9ab")
	head.material_override = h_mat
	head.position = Vector3(0, 1.12, 0)
	assistant_visual_node.add_child(head)

	assistant_arm_node = Node3D.new()
	assistant_arm_node.position = Vector3(-0.24, 0.75, 0)
	var arm_mesh := MeshInstance3D.new()
	var a_box := BoxMesh.new()
	a_box.size = Vector3(0.10, 0.36, 0.10)
	arm_mesh.mesh = a_box
	arm_mesh.material_override = b_mat
	arm_mesh.position = Vector3(0, -0.14, 0.10)
	assistant_arm_node.add_child(arm_mesh)
	assistant_visual_node.add_child(assistant_arm_node)

	assistant_status_label = Label3D.new()
	assistant_status_label.position = Vector3(0, 1.65, 0)
	assistant_status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	assistant_status_label.font_size = 18
	assistant_status_label.pixel_size = 0.004
	assistant_status_label.outline_size = 6
	assistant_status_label.modulate = Color("80d8ff")
	assistant_status_label.text = "🔧 Tí Thợ Phụ (Sẵn sàng)"
	assistant_visual_node.add_child(assistant_status_label)

	add_child(assistant_visual_node)

func _build_established_garage_visual() -> void:
	if is_instance_valid(established_visual_node):
		return
	established_visual_node = Node3D.new()
	established_visual_node.name = "EstablishedGarageVisual"

	established_sign_light = MeshInstance3D.new()
	var s_mesh := BoxMesh.new()
	s_mesh.size = Vector3(3.6, 0.55, 0.16)
	established_sign_light.mesh = s_mesh
	var s_mat := StandardMaterial3D.new()
	s_mat.albedo_color = Color("ffb300")
	s_mat.emission_enabled = true
	s_mat.emission = Color("ffd54f")
	s_mat.emission_energy_multiplier = 1.4
	established_sign_light.material_override = s_mat
	established_sign_light.position = Vector3(-105.5, 3.3, -15.5)
	established_visual_node.add_child(established_sign_light)

	var sign_lbl := Label3D.new()
	sign_lbl.position = Vector3(-105.5, 3.3, -15.35)
	sign_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign_lbl.font_size = 24
	sign_lbl.pixel_size = 0.005
	sign_lbl.outline_size = 8
	sign_lbl.modulate = Color("fff8e1")
	sign_lbl.text = "⭐ GARA UY TÍN CẤP 5 ⭐"
	established_visual_node.add_child(sign_lbl)

	add_child(established_visual_node)

func _build_upgrade_ui() -> void:
	upgrade_ui_layer = CanvasLayer.new()
	upgrade_ui_layer.name = "GarageUpgradeUILayer"
	upgrade_ui_layer.layer = 96
	upgrade_ui_layer.visible = false
	add_child(upgrade_ui_layer)

	var shade := ColorRect.new()
	shade.color = Color(0.06, 0.08, 0.11, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	upgrade_ui_layer.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	upgrade_ui_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 320)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1f2933")
	style.border_color = Color("ffd54f")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "🔧 NÂNG CẤP TIỆM SỬA XE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("ffd54f"))
	vbox.add_child(title)

	upgrade_current_label = Label.new()
	upgrade_current_label.add_theme_font_size_override("font_size", 15)
	upgrade_current_label.add_theme_color_override("font_color", Color("ffffff"))
	vbox.add_child(upgrade_current_label)

	upgrade_next_label = Label.new()
	upgrade_next_label.add_theme_font_size_override("font_size", 15)
	upgrade_next_label.add_theme_color_override("font_color", Color("80d8ff"))
	vbox.add_child(upgrade_next_label)

	upgrade_cost_label = Label.new()
	upgrade_cost_label.add_theme_font_size_override("font_size", 14)
	upgrade_cost_label.add_theme_color_override("font_color", Color("ffe082"))
	vbox.add_child(upgrade_cost_label)

	upgrade_benefit_label = Label.new()
	upgrade_benefit_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	upgrade_benefit_label.add_theme_font_size_override("font_size", 13)
	upgrade_benefit_label.add_theme_color_override("font_color", Color("cfd8dc"))
	vbox.add_child(upgrade_benefit_label)

	upgrade_feedback_label = Label.new()
	upgrade_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	upgrade_feedback_label.add_theme_font_size_override("font_size", 13)
	upgrade_feedback_label.add_theme_color_override("font_color", Color("ffab40"))
	vbox.add_child(upgrade_feedback_label)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)

	upgrade_confirm_btn = Button.new()
	upgrade_confirm_btn.text = "✅ Xác Nhận Nâng Cấp"
	upgrade_confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrade_confirm_btn.pressed.connect(func():
		var res := upgrade_garage_level()
		if res.get("success", false):
			_refresh_upgrade_ui()
		elif is_instance_valid(upgrade_feedback_label):
			upgrade_feedback_label.text = str(res.get("message", ""))
	)
	btn_row.add_child(upgrade_confirm_btn)

	var close_btn := Button.new()
	close_btn.text = "Đóng (ESC)"
	close_btn.pressed.connect(close_upgrade_ui)
	btn_row.add_child(close_btn)

func open_upgrade_ui() -> void:
	if not is_instance_valid(upgrade_ui_layer):
		return
	_refresh_upgrade_ui()
	upgrade_ui_layer.visible = true

func close_upgrade_ui() -> void:
	if is_instance_valid(upgrade_ui_layer):
		upgrade_ui_layer.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(upgrade_ui_layer) and upgrade_ui_layer.visible:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close_upgrade_ui()

func _refresh_upgrade_ui() -> void:
	if not is_instance_valid(upgrade_current_label):
		return
	var cur_cfg: Dictionary = GARAGE_LEVEL_CONFIG.get(business_level, {})
	upgrade_current_label.text = "Hiện tại: %s (Đã sửa: %d xe)" % [str(cur_cfg.get("title", "Cấp %d" % business_level)), customers_served]
	var check := can_upgrade_garage()
	if business_level >= 5:
		upgrade_next_label.text = "Mở khóa tiếp theo: Đã đạt Cấp Tối Đa (5/5)"
		upgrade_cost_label.text = "Chi phí: —"
		upgrade_benefit_label.text = "Lợi ích: %s" % str(cur_cfg.get("benefit", ""))
		upgrade_feedback_label.text = "🎉 Gara đã phát triển tối đa!"
		upgrade_confirm_btn.disabled = true
	else:
		var next_lvl: int = int(check["next_level"])
		var next_cfg: Dictionary = GARAGE_LEVEL_CONFIG.get(next_lvl, {})
		upgrade_next_label.text = "Tiếp theo: %s" % str(next_cfg.get("title", ""))
		upgrade_cost_label.text = "Chi phí: %s đ | Yêu cầu: %d/%d xe đã sửa" % [
			format_money(int(next_cfg.get("cost", 0))),
			customers_served,
			int(next_cfg.get("min_customers", 0))
		]
		upgrade_benefit_label.text = "Lợi ích: %s" % str(next_cfg.get("benefit", ""))
		upgrade_feedback_label.text = str(check.get("message", ""))
		upgrade_confirm_btn.disabled = not bool(check.get("can_upgrade", false))

func can_upgrade_garage() -> Dictionary:
	if business_level >= 5:
		return {"can_upgrade": false, "next_level": 5, "cost": 0, "message": "Đã đạt cấp tối đa!"}
	var next_lvl := business_level + 1
	var cfg: Dictionary = GARAGE_LEVEL_CONFIG.get(next_lvl, {})
	var cost: int = int(cfg.get("cost", 0))
	var min_cust: int = int(cfg.get("min_customers", 0))
	if customers_served < min_cust:
		return {
			"can_upgrade": false, "next_level": next_lvl, "cost": cost,
			"message": "Cần phục vụ thêm %d xe nữa để mở khóa cấp %d." % [min_cust - customers_served, next_lvl]
		}
	var econ := get_tree().get_first_node_in_group("economy_manager") as EconomyManager if is_inside_tree() else null
	if not is_instance_valid(econ) or not is_instance_valid(econ.wallet):
		return {"can_upgrade": false, "next_level": next_lvl, "cost": cost, "message": "Không tìm thấy ví gia đình."}
	if not econ.wallet.can_afford(cost):
		return {
			"can_upgrade": false, "next_level": next_lvl, "cost": cost,
			"message": "Chưa đủ tiền! Cần thêm %s đ." % format_money(cost - econ.wallet.balance)
		}
	return {"can_upgrade": true, "next_level": next_lvl, "cost": cost, "message": "Sẵn sàng nâng cấp!"}

func upgrade_garage_level() -> Dictionary:
	var check := can_upgrade_garage()
	if not bool(check.get("can_upgrade", false)):
		return {"success": false, "message": check.get("message", "")}
	var next_lvl: int = int(check["next_level"])
	var cost: int = int(check["cost"])
	var econ := get_tree().get_first_node_in_group("economy_manager") as EconomyManager if is_inside_tree() else null
	var tx_id := "garage_upgrade_lvl_%d" % next_lvl
	if not econ.wallet.withdraw(cost, "business_upgrade", "Nâng cấp Gara Cấp %d" % next_lvl, tx_id):
		return {"success": false, "message": "Giao dịch đã tồn tại hoặc không đủ tiền."}
	daily_expenses += cost
	apply_garage_level_unlocks(next_lvl)
	if next_lvl >= 5:
		reputation_score = minf(100.0, reputation_score + 5.0)
	level_up.emit(business_level)
	_show_feedback(global_position + Vector3(0, 3.0, 0), "🎉 Gara lên CẤP %d! ⭐" % business_level, Color("ffd54f"))
	if econ.auto_save_on_change:
		econ.save_economy_state()
	return {"success": true, "new_level": business_level, "message": "Nâng cấp thành công!"}

func roll_customer_type() -> BusinessOrder.CustomerType:
	var rolled := super.roll_customer_type()
	if rolled == BusinessOrder.CustomerType.NORMAL and business_level >= 5 and randf() < 0.08:
		return BusinessOrder.CustomerType.VIP
	return rolled

func _try_spawn_customer() -> void:
	var free_bay := -1
	var allowed_bays: int = bay_positions.size() if is_second_bay_unlocked else 1
	for i in range(allowed_bays):
		if not bay_orders.has(i) and not bay_reserved.get(i, false):
			free_bay = i
			break
	if free_bay == -1: return
	
	bay_reserved[free_bay] = true
	
	var is_premium_order := false
	var service: Dictionary = service_catalog[randi() % service_catalog.size()]
	if business_level >= 2 and not premium_service_catalog.is_empty():
		var prem_chance := 0.40 if business_level >= 5 else 0.25
		if randf() < prem_chance:
			service = premium_service_catalog[randi() % premium_service_catalog.size()]
			is_premium_order = true

	var name_pool := customer_names.duplicate()
	if business_level >= 2:
		name_pool.append_array(extra_customer_names)
	var cust_name: String = name_pool[randi() % name_pool.size()]
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
	order.is_premium = is_premium_order
	if service.has("duration"):
		order.repair_duration_override = float(service["duration"])
	order.is_peak_hour = is_peak_hour
	order.customer_name = cust_name
	order.customer_type = roll_customer_type()
	apply_customer_type_to_order(order, configured_reward, adjusted_patience)
	if is_premium_order and not order.service_title.begins_with("💎"):
		order.service_title = "💎 " + order.service_title
	cust_name = order.customer_name
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
	customer.customer_type = order.customer_type
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
		var bonus_tip := int(order.reward_money * 0.20)
		order.tip_money += bonus_tip
	if business_level >= 5:
		reputation_score = minf(100.0, reputation_score + 0.5)
		
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
	if assistant_repairing and is_instance_valid(assistant_order):
		assistant_order.patience_remaining = minf(
			assistant_order.patience_max,
			assistant_order.patience_remaining + delta
		)
	super._process(delta)
	_update_active_repair(delta)
	_update_assistant_repair(delta)
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
	
	var safe_duration := get_order_repair_duration(active_repair_order)
	repair_elapsed = minf(safe_duration, repair_elapsed + delta)
	
	if repair_elapsed >= safe_duration:
		_finish_active_repair()

func _cancel_assistant_repair() -> void:
	if is_instance_valid(assistant_order) and assistant_order.status == BusinessOrder.Status.IN_PROGRESS:
		assistant_order.status = BusinessOrder.Status.PENDING
	assistant_repairing = false
	assistant_order = null
	assistant_elapsed = 0.0
	if is_instance_valid(assistant_arm_node):
		assistant_arm_node.rotation.x = 0.0
	if is_instance_valid(assistant_status_label):
		assistant_status_label.text = "🔧 Tí Thợ Phụ (Nghỉ)" if not is_open else "🔧 Tí Thợ Phụ (Sẵn sàng)"

func _try_pay_assistant_daily_wage() -> bool:
	var cur_day := 1
	if is_inside_tree():
		var loop_mgr := get_tree().get_first_node_in_group("daily_loop_manager")
		if is_instance_valid(loop_mgr) and "current_day" in loop_mgr:
			cur_day = int(loop_mgr.current_day)
	if assistant_paid_day == cur_day:
		return true
	var econ := get_tree().get_first_node_in_group("economy_manager") as EconomyManager if is_inside_tree() else null
	if not is_instance_valid(econ) or not is_instance_valid(econ.wallet):
		return false
	if not econ.wallet.can_afford(assistant_daily_cost):
		return false
	var tx_id := "garage_assistant_wage_day_%d" % cur_day
	if econ.wallet.withdraw(assistant_daily_cost, "operating_cost", "Tiền công Thợ Phụ Gara (Ngày %d)" % cur_day, tx_id):
		assistant_paid_day = cur_day
		daily_expenses += assistant_daily_cost
		return true
	return assistant_paid_day == cur_day

func _update_assistant_repair(delta: float) -> void:
	if not assistant_hired or business_level < 4:
		return
	if not is_open:
		if assistant_repairing:
			_cancel_assistant_repair()
		elif is_instance_valid(assistant_status_label):
			assistant_status_label.text = "🔧 Tí Thợ Phụ (Đã đóng cửa)"
		return

	if not assistant_repairing:
		# Look for a waiting customer on Bay 2 (bay_index == 1) not being repaired by player
		if not bay_orders.has(1) or not bay_customers.has(1):
			return
		var cust = bay_customers[1]
		if not is_instance_valid(cust) or cust.current_state == MotorcycleCustomer.State.DEPARTING or cust.current_state == MotorcycleCustomer.State.DESPAWNED:
			return
		var ord: BusinessOrder = bay_orders[1]
		if not is_instance_valid(ord) or not active_orders.has(ord):
			return
		if ord.status != BusinessOrder.Status.PENDING or completed_order_ids.has(ord.order_id):
			return
		if is_repairing and active_repair_order == ord:
			return
		if get_repair_kit_count() < 1:
			if is_instance_valid(assistant_status_label):
				assistant_status_label.text = "🔧 Tí Thợ Phụ (Thiếu Dụng Cụ)"
			return
		if not _try_pay_assistant_daily_wage():
			if is_instance_valid(assistant_status_label):
				assistant_status_label.text = "🔧 Tí Thợ Phụ (Chờ trả công %s đ)" % format_money(assistant_daily_cost)
			return

		assistant_repairing = true
		assistant_order = ord
		assistant_elapsed = 0.0
		assistant_duration = 7.0 if ord.is_premium else 5.5 # Slower than player
		ord.status = BusinessOrder.Status.IN_PROGRESS
		return

	# Validate active assistant repair
	if not is_instance_valid(assistant_order) or not active_orders.has(assistant_order) or not bay_customers.has(1):
		_cancel_assistant_repair()
		return
	var cust_check = bay_customers[1]
	if not is_instance_valid(cust_check) or cust_check.current_state == MotorcycleCustomer.State.DEPARTING or cust_check.current_state == MotorcycleCustomer.State.DESPAWNED:
		_cancel_assistant_repair()
		return
	if assistant_order.status in [BusinessOrder.Status.FAILED, BusinessOrder.Status.CANCELLED, BusinessOrder.Status.PAID]:
		_cancel_assistant_repair()
		return

	assistant_elapsed = minf(assistant_duration, assistant_elapsed + delta)
	if is_instance_valid(assistant_arm_node):
		assistant_arm_node.rotation.x = sin(assistant_elapsed * 10.0) * 0.65
	if is_instance_valid(assistant_status_label):
		var pct := clampi(int(round((assistant_elapsed / assistant_duration) * 100.0)), 0, 100)
		assistant_status_label.text = "🔧 Tí đang sửa Khoang 2 (%d%%)" % pct

	if assistant_elapsed >= assistant_duration:
		var finished_ord := assistant_order
		_cancel_assistant_repair()
		if not is_instance_valid(finished_ord) or not active_orders.has(finished_ord) or completed_order_ids.has(finished_ord.order_id):
			return
		if get_repair_kit_count() <= 0 or not consume_repair_kit():
			finished_ord.status = BusinessOrder.Status.PENDING
			return
		while not finished_ord.get_current_required_step().is_empty():
			var step_name := finished_ord.get_current_required_step()
			finished_ord.advance_step(step_name)
			order_step_done.emit(finished_ord, step_name)
		finished_ord.status = BusinessOrder.Status.COMPLETED
		if complete_order(finished_ord):
			_show_feedback(to_global(bay_positions[1]), "🔧 Thợ phụ sửa xong! +%s đ (-1 Dụng cụ)" % format_money(finished_ord.get_total_payout()), Color("80d8ff"))

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
		_show_feedback(to_global(bay_positions[bay]), "✓ Sửa xe thành công! +%s đ · -1 Bộ dụng cụ (Còn: %d)" % [reward_str, get_repair_kit_count()], Color("69f0ae"))

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
	repair_bar_text_label.visible = false
	repair_progress_bar.visible = false
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
		var dur := get_order_repair_duration(active_repair_order)
		var ratio := clampf(repair_elapsed / dur, 0.0, 1.0)
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
	var player := get_tree().get_first_node_in_group("active_player") as Node3D
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("players") as Node3D
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
		var dur := get_order_repair_duration(order)
		var ratio := clampf(repair_elapsed / dur, 0.0, 1.0)
		var pct := clampi(int(round(ratio * 100.0)), 0, 100)
		lbl.text = "Đang sửa xe... %d%%\n%s" % [pct, _format_unicode_progress_bar(ratio, 10)]
		lbl.modulate = Color("80d8ff")
		return
	if assistant_repairing and bay_index == 1 and assistant_order == order:
		var ratio_a := clampf(assistant_elapsed / maxf(0.1, assistant_duration), 0.0, 1.0)
		var pct_a := clampi(int(round(ratio_a * 100.0)), 0, 100)
		lbl.text = "🔧 Thợ phụ đang sửa... %d%%\n%s" % [pct_a, _format_unicode_progress_bar(ratio_a, 10)]
		lbl.modulate = Color("ffd54f")
		return
	
	var patience_pct := int(order.get_patience_ratio() * 100.0)
	var kit_count := get_repair_kit_count()
	var express_tag := ""
	if order.customer_type == BusinessOrder.CustomerType.EXPRESS and order.express_deadline > 0.0:
		var left := maxf(0.0, order.express_deadline - order.time_spent)
		if left > 0.0:
			express_tag = " | ⚡ Nhanh < %ds (+10k)" % int(ceil(left))
	lbl.text = "🏍️ %s: %s (+%s đ%s)\n⏳ Kiên nhẫn: %d%% | 🧰 Dụng cụ: %d\n👉 Nhấn E để sửa xe" % [
		order.customer_name,
		order.service_title,
		format_money(order.reward_money),
		express_tag,
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
				var ratio := clampf(repair_elapsed / get_order_repair_duration(active_repair_order), 0.0, 1.0)
				return "Đang sửa xe... %d%%" % clampi(int(round(ratio * 100.0)), 0, 100)
			if not bay_orders.has(bay):
				return "Khoang sửa xe trống"
			var order: BusinessOrder = bay_orders[bay]
			if order.status == BusinessOrder.Status.FAILED or order.status == BusinessOrder.Status.CANCELLED:
				return "Khách đã rời đi"
			return "Nhấn E để sửa xe"
		
		"shop_sign":
			if is_open:
				return "🔧 Tiệm Sửa Xe: Đang mở cửa (06:00–21:00)"
			return "🌙 Tiệm Sửa Xe: Đã đóng cửa (Mở lại 06:00)"
		"upgrade_board":
			return "Nâng cấp Tiệm Sửa Xe (Cấp %d/5)" % business_level
	
	return "Tương tác"

func on_station_interacted(station: RepairStation, player_node: Node3D) -> void:
	match station.station_type:
		"shop_sign":
			if is_open:
				_show_feedback(station.global_position, "🔧 Tiệm sửa xe tự động mở cửa (06:00–21:00) — khách tự ghé!", Color("69f0ae"))
			else:
				_show_feedback(station.global_position, "🌙 Tiệm nghỉ ngơi ngoài giờ (Mở lại lúc 06:00)", Color("ffd54f"))
		"upgrade_board":
			open_upgrade_ui()
		
		"bike_bay":
			if not is_open:
				_show_feedback(station.global_position, "🌙 Tiệm đang đóng cửa (06:00–21:00)", Color("ffd54f"))
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
			
			# Instant player repair: complete immediately on E press
			active_repair_bay = bay
			active_repair_order = order
			active_repair_player = player_node
			repair_elapsed = 0.0
			_finish_active_repair()
			if is_instance_valid(player_node) and player_node.has_method("play_couple_celebration"):
				var fx = get_tree().get_first_node_in_group("chaos_feedback")
				if is_instance_valid(fx) and fx.has_method("play_event"):
					fx.play_event("bonk", station.global_position + Vector3.UP * 0.8)
			hud_override_mode = ""
			hud_message_timer = 0.0
			order.status = BusinessOrder.Status.IN_PROGRESS
			_update_bay_display(bay)
			_update_repair_hud(0.0)

func get_persistent_stats() -> Dictionary:
	var stats := super.get_persistent_stats()
	stats["is_second_bay_unlocked"] = is_second_bay_unlocked
	stats["is_better_tools_unlocked"] = is_better_tools_unlocked
	stats["is_faster_service_unlocked"] = is_faster_service_unlocked
	stats["assistant_hired"] = assistant_hired
	stats["assistant_paid_day"] = assistant_paid_day
	return stats

func apply_persistent_stats(data: Dictionary) -> void:
	super.apply_persistent_stats(data)
	if data.is_empty():
		return
	is_second_bay_unlocked = bool(data.get("is_second_bay_unlocked", is_second_bay_unlocked))
	is_better_tools_unlocked = bool(data.get("is_better_tools_unlocked", is_better_tools_unlocked))
	is_faster_service_unlocked = bool(data.get("is_faster_service_unlocked", is_faster_service_unlocked))
	assistant_hired = bool(data.get("assistant_hired", assistant_hired))
	assistant_paid_day = int(data.get("assistant_paid_day", assistant_paid_day))
	apply_garage_level_unlocks(business_level)
