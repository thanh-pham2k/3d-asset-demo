class_name GarageBusiness
extends BusinessShop

const MotorcycleCustomer = preload("res://scripts/neighborhood/business/motorcycle_customer.gd")

## Boy's Motorcycle Repair Shop gameplay controller.
## Manages arriving customers with scooters, repair requests (inflate, patch, replace),
## interactive tool stations, sequential validation, and customer patience.

class RepairStation extends Interactable:
	var garage: GarageBusiness
	var station_type: String = "" # "bike_bay", "air_pump", "workbench", "tire_rack"
	var bay_index: int = 0
	var interaction_radius: float = 2.4
	
	func available(player_node: Node3D) -> bool:
		if station_type == "shop_sign":
			return enabled and is_instance_valid(garage)
		return enabled and is_instance_valid(garage) and garage.is_open
	
	func prompt(player_node: Node3D) -> String:
		if not garage: return "Tiệm sửa xe"
		return garage.get_station_prompt(self, player_node)
	
	func interact(player_node: Node3D) -> void:
		if garage: garage.on_station_interacted(self, player_node)

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

# Business Upgrades State
var is_second_bay_unlocked: bool = false
var is_better_tools_unlocked: bool = false
var is_faster_service_unlocked: bool = false

var second_bay_visual_node: Node3D = null
var tools_visual_node: Node3D = null
var compressor_visual_node: Node3D = null

# Inventory/holding state of player at garage
var player_holding_tool: String = "" # "", "patch_kit", "new_tire", "worn_tire"
var player_holding_tools: Dictionary = {} # player_id -> tool_string

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
		"title": "Bơm lốp xe",
		"reward": 20000,
		"patience": 55.0,
		"steps": ["pump_air"]
	},
	{
		"type": "patch",
		"title": "Vá săm xe",
		"reward": 35000,
		"patience": 65.0,
		"steps": ["patch_kit", "pump_air"]
	},
	{
		"type": "replace",
		"title": "Thay lốp mới",
		"reward": 50000,
		"patience": 75.0,
		"steps": ["remove_tire", "mount_tire", "pump_air"]
	}
]

var customer_names: Array[String] = [
	"Anh Tuấn", "Bác Năm", "Chú Tư", "Chị Lan", "Cô Mai", "Em Linh", "Anh Dũng"
]

func _ready() -> void:
	shop_id = "garage"
	shop_name = "Tiệm Sửa Xe Máy Chú Ba"
	open_hour = 6.0
	close_hour = 21.0
	spawn_interval = 14.0
	super._ready()
	
	_create_work_stations()

func _get_peak_hour_ranges() -> Array[Vector2]:
	return [
		Vector2(7.0, 9.0),   # Morning commuter rush
		Vector2(17.0, 19.0)  # Evening rush hour
	]

func _create_work_stations() -> void:
	# 1. Motorcycle service bays (where customer bikes park)
	for i in range(bay_positions.size()):
		var bay := RepairStation.new()
		bay.name = "BikeBay_%d" % i
		bay.garage = self
		bay.station_type = "bike_bay"
		bay.bay_index = i
		bay.position = bay_positions[i]
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
	
	# 2. Air pump station
	var pump := RepairStation.new()
	pump.name = "AirPumpStation"
	pump.garage = self
	pump.station_type = "air_pump"
	pump.position = Vector3(-111, 0, -16)
	add_child(pump)
	
	# 3. Workbench station (patching)
	var bench := RepairStation.new()
	bench.name = "WorkbenchStation"
	bench.garage = self
	bench.station_type = "workbench"
	bench.position = Vector3(-101, 0, -20)
	add_child(bench)
	
	# 4. Tire rack station (new tires)
	var rack := RepairStation.new()
	rack.name = "TireRackStation"
	rack.garage = self
	rack.station_type = "tire_rack"
	rack.position = Vector3(-112, 0, -12)
	add_child(rack)
	
	# 5. Shop open/close sign station
	var sign_station := RepairStation.new()
	sign_station.name = "ShopSignStation"
	sign_station.garage = self
	sign_station.station_type = "shop_sign"
	sign_station.position = Vector3(-101.5, 0, -16.0)
	add_child(sign_station)

func reset_daily_state() -> void:
	super.reset_daily_state()
	_safe_clear_remaining_customers()
	_update_status_display()

func _safe_clear_remaining_customers() -> void:
	for bay in bay_customers.keys():
		var cust = bay_customers[bay]
		if is_instance_valid(cust) and cust.current_state != MotorcycleCustomer.State.DEPARTING and cust.current_state != MotorcycleCustomer.State.DESPAWNED:
			cust.notify_order_failed("shop_closed")
	bay_orders.clear()
	bay_reserved.clear()
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
	spawn_interval = 8.0 # Faster customer flow (down from 14.0s)
	_build_compressor_visual()

func _build_second_bay_visual() -> void:
	if is_instance_valid(second_bay_visual_node): return
	second_bay_visual_node = Node3D.new()
	second_bay_visual_node.name = "SecondBayUpgradeVisual"
	
	# Lift platform at Bay 1
	var platform := MeshInstance3D.new()
	var p_mesh := BoxMesh.new()
	p_mesh.size = Vector3(1.6, 0.08, 2.6)
	platform.mesh = p_mesh
	var p_mat := StandardMaterial3D.new()
	p_mat.albedo_color = Color("37474f") # Dark metallic steel
	p_mat.metallic = 0.8
	p_mat.roughness = 0.3
	platform.material_override = p_mat
	platform.position = bay_positions[1] + Vector3(0, 0.04, 0)
	second_bay_visual_node.add_child(platform)
	
	# Yellow safety hazard striping
	for x_off in [-0.85, 0.85]:
		var stripe := MeshInstance3D.new()
		var s_mesh := BoxMesh.new()
		s_mesh.size = Vector3(0.12, 0.09, 2.6)
		stripe.mesh = s_mesh
		var s_mat := StandardMaterial3D.new()
		s_mat.albedo_color = Color("ffd600") # Safety yellow
		stripe.material_override = s_mat
		stripe.position = bay_positions[1] + Vector3(x_off, 0.045, 0)
		second_bay_visual_node.add_child(stripe)
	
	# Hydraulic Lift Cylinders
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
		
	# Upgrade Billboard Badge
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
	
	# Chrome professional tool chest on workbench
	var chest := MeshInstance3D.new()
	var ch_mesh := BoxMesh.new()
	ch_mesh.size = Vector3(0.9, 0.65, 0.5)
	chest.mesh = ch_mesh
	var ch_mat := StandardMaterial3D.new()
	ch_mat.albedo_color = Color("c62828") # Mechanic red
	ch_mat.metallic = 0.6
	ch_mat.roughness = 0.4
	chest.material_override = ch_mat
	chest.position = wb_pos + Vector3(0, 0.8, -0.3)
	tools_visual_node.add_child(chest)
	
	# Chrome drawer handles
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
		
	# Overhead LED inspection spotlight
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
	
	# Horizontal industrial compressor red tank
	var tank := MeshInstance3D.new()
	var t_mesh := CylinderMesh.new()
	t_mesh.top_radius = 0.28
	t_mesh.bottom_radius = 0.28
	t_mesh.height = 1.0
	tank.mesh = t_mesh
	var t_mat := StandardMaterial3D.new()
	t_mat.albedo_color = Color("b71c1c") # Heavy industrial crimson
	t_mat.roughness = 0.4
	tank.material_override = t_mat
	tank.rotation.z = PI / 2.0
	tank.position = pump_pos + Vector3(0, 0.45, 0.4)
	compressor_visual_node.add_child(tank)
	
	# Dual brass pressure dial
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
	if free_bay == -1: return # All allowed bays occupied or reserved
	
	bay_reserved[free_bay] = true
	
	# Pick random service
	var service: Dictionary = service_catalog[randi() % service_catalog.size()]
	var cust_name: String = customer_names[randi() % customer_names.size()]
	var order_id := "garage_%d_%d" % [free_bay, Time.get_ticks_msec()]
	
	var adjusted_patience: float = float(service["patience"]) * get_patience_multiplier()
	var order := BusinessOrder.new(
		order_id,
		service["type"],
		service["title"],
		service["reward"],
		service["steps"].duplicate(),
		adjusted_patience
	)
	order.is_peak_hour = is_peak_hour
	order.customer_name = cust_name
	order.table_index = free_bay
	order.target_spot = bay_positions[free_bay] + position
	
	# Waypoints from road, turning into driveway to bay
	var approach_path: Array[Vector3] = [
		Vector3(-106, 0, 8),
		Vector3(-106, 0, -5),
		bay_positions[free_bay]
	]
	var departure_path: Array[Vector3] = [
		bay_positions[free_bay],
		Vector3(-106, 0, -5),
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
	if order.status == BusinessOrder.Status.PAID or order.status == BusinessOrder.Status.FAILED or order.status == BusinessOrder.Status.CANCELLED:
		return false
	
	var bay := order.table_index
	if is_better_tools_unlocked:
		var bonus_tip := int(order.reward_money * 0.30)
		order.tip_money += bonus_tip
		_show_feedback(bay_positions[bay] + position, "🧰 Thợ giỏi đồ nghề xịn! Khách thưởng thêm tip: +%s đ ✨" % HouseholdWallet.format_money(bonus_tip), Color("ffd54f"))
		
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
	scooter.rotation.y = PI / 2.0
	add_child(scooter)
	bay_scooters[bay_index] = scooter

func _on_customer_depart(order: BusinessOrder) -> void:
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
	super._process(delta)
	for bay in bay_orders:
		_update_bay_display(bay)

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
	var patience_pct := int(order.get_patience_ratio() * 100.0)
	var next_step := order.get_current_required_step()
	var step_vn := _get_step_vietnamese(next_step)
	
	lbl.text = "🏍️ %s: %s\n⏳ Kiên nhẫn: %d%% | Cần: %s" % [
		order.customer_name,
		order.service_title,
		patience_pct,
		step_vn
	]
	
	if order.get_patience_ratio() > 0.5:
		lbl.modulate = Color("69f0ae")
	elif order.get_patience_ratio() > 0.25:
		lbl.modulate = Color("ffd740")
	else:
		lbl.modulate = Color("ff5252")

func _get_step_vietnamese(step: String) -> String:
	match step:
		"pump_air": return "Bơm căng lốp"
		"patch_kit": return "Vá miếng săm (tại bàn thợ)"
		"remove_tire": return "Tháo bánh xe cũ"
		"get_new_tire": return "Lấy lốp mới từ kệ"
		"mount_tire": return "Lắp lốp mới vào xe"
		_: return "Hoàn tất"

func get_station_prompt(station: RepairStation, player_node: Node3D = null) -> String:
	match station.station_type:
		"bike_bay":
			var bay := station.bay_index
			if not bay_orders.has(bay):
				return "Khoang sửa xe trống"
			var order: BusinessOrder = bay_orders[bay]
			if order.status == BusinessOrder.Status.FAILED or order.status == BusinessOrder.Status.CANCELLED:
				return "Khách đã rời đi (Khoang %d)" % (bay + 1)
			
			var next_step := order.get_current_required_step()
			match next_step:
				"pump_air":
					return "Bơm lốp xe (Khoang %d)" % (bay + 1)
				"patch_kit":
					if get_holding_tool(player_node) == "patch_kit":
						return "Dán miếng vá săm (Khoang %d)" % (bay + 1)
					else:
						return "Cần lấy bộ vá săm ở Bàn Thợ trước!"
				"remove_tire":
					return "Tháo lốp mòn ra khỏi xe (Khoang %d)" % (bay + 1)
				"mount_tire":
					if get_holding_tool(player_node) == "new_tire":
						return "Lắp lốp mới vào xe (Khoang %d)" % (bay + 1)
					else:
						return "Cần lấy lốp mới từ Kệ Lốp trước!"
				_:
					return "Thực hiện: %s (Khoang %d)" % [order.service_title, bay + 1]
		
		"air_pump":
			return "Máy bơm hơi tự động"
		
		"workbench":
			if get_holding_tool(player_node) == "patch_kit":
				return "Cất bộ vá săm lại bàn thợ"
			return "Lấy bộ vá săm & keo dán"
		
		"tire_rack":
			if get_holding_tool(player_node) == "worn_tire":
				return "Đổi lốp cũ lấy lốp mới từ kệ"
			elif get_holding_tool(player_node) == "new_tire":
				return "Cất lốp mới lại kệ"
			return "Lấy lốp xe mới từ kệ"
		
		"shop_sign":
			if is_open:
				return "Đóng cửa tiệm sửa xe (kết thúc ngày) [E]"
			else:
				return "Mở cửa tiệm sửa xe [E]"
	
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
		
		"workbench":
			if get_holding_tool(player_node) == "patch_kit":
				set_holding_tool(player_node, "")
				_show_feedback(station.global_position, "Đã cất bộ vá săm lại bàn thợ.", Color("cfd8dc"))
			elif get_holding_tool(player_node) == "worn_tire" or get_holding_tool(player_node) == "new_tire":
				_show_feedback(station.global_position, "⚠️ Tay đang cầm lốp xe, hãy cất lốp ở kệ trước!", Color("ffab40"))
			else:
				set_holding_tool(player_node, "patch_kit")
				_show_feedback(station.global_position, "Đã chuẩn bị miếng vá săm & keo! 🧰", Color("80d8ff"))
		
		"tire_rack":
			if get_holding_tool(player_node) == "worn_tire":
				set_holding_tool(player_node, "new_tire")
				_show_feedback(station.global_position, "Đã cất lốp cũ vào kho & lấy lốp mới! 🛞", Color("80d8ff"))
			elif get_holding_tool(player_node) == "new_tire":
				set_holding_tool(player_node, "")
				_show_feedback(station.global_position, "Đã cất lốp mới lại kệ.", Color("cfd8dc"))
			elif get_holding_tool(player_node) == "patch_kit":
				_show_feedback(station.global_position, "⚠️ Đang cầm bộ vá săm, hãy cất lại bàn thợ trước khi lấy lốp!", Color("ffab40"))
			else:
				set_holding_tool(player_node, "new_tire")
				_show_feedback(station.global_position, "Đã lấy lốp mới chính hãng! 🛞", Color("80d8ff"))
		
		"air_pump":
			_show_feedback(station.global_position, "Máy bơm hơi sẵn sàng (áp suất 2.4 bar) 💨", Color("b9f6ca"))
		
		"bike_bay":
			var bay := station.bay_index
			if not bay_orders.has(bay):
				_show_feedback(station.global_position, "Khoang trống, đang chờ khách ghé...", Color("cfd8dc"))
				return
			
			var order: BusinessOrder = bay_orders[bay]
			if order.status == BusinessOrder.Status.FAILED or order.status == BusinessOrder.Status.CANCELLED or order.status == BusinessOrder.Status.PAID:
				_show_feedback(station.global_position, "⚠️ Không thể sửa xe ở khoang này!", Color("ffab40"))
				return
			
			var next_step := order.get_current_required_step()
			
			match next_step:
				"pump_air":
					if get_holding_tool(player_node) == "worn_tire":
						order.record_mistake(0.1)
						_show_feedback(station.global_position, "⚠️ Tay đang cầm lốp cũ! Hãy mang cất ở kệ lốp trước khi bơm!", Color("ffab40"))
						return
					elif get_holding_tool(player_node) == "patch_kit":
						order.record_mistake(0.1)
						_show_feedback(station.global_position, "⚠️ Đang cầm bộ vá săm! Hãy cất lại bàn thợ trước khi bơm xe!", Color("ffab40"))
						return
					
					# Successfully pump air
					order.advance_step("pump_air")
					order_step_done.emit(order, "pump_air")
					_show_feedback(station.global_position, "💨 Phì... Bơm căng đạt chuẩn 2.4 bar!", Color("69f0ae"))
					if order.status == BusinessOrder.Status.COMPLETED:
						complete_order(order)
				
				"patch_kit":
					if get_holding_tool(player_node) == "patch_kit":
						order.advance_step("patch_kit")
						set_holding_tool(player_node, "")
						order_step_done.emit(order, "patch_kit")
						_show_feedback(station.global_position, "🔧 Đã dán vá săm kín mít!", Color("69f0ae"))
					else:
						order.record_mistake(0.1)
						_show_feedback(station.global_position, "⚠️ Cần lấy bộ vá săm ở bàn thợ trước!", Color("ffab40"))
				
				"remove_tire":
					order.advance_step("remove_tire")
					set_holding_tool(player_node, "worn_tire")
					order_step_done.emit(order, "remove_tire")
					_show_feedback(station.global_position, "🔩 Đã tháo lốp mòn ra khỏi xe!", Color("69f0ae"))
				
				"mount_tire":
					if get_holding_tool(player_node) == "new_tire":
						order.advance_step("mount_tire")
						set_holding_tool(player_node, "")
						order_step_done.emit(order, "mount_tire")
						_show_feedback(station.global_position, "✨ Đã lắp lốp mới & siết ốc chặt!", Color("69f0ae"))
					else:
						order.record_mistake(0.1)
						_show_feedback(station.global_position, "⚠️ Cần lấy lốp mới từ kệ trước!", Color("ffab40"))
				
				_:
					if order.status == BusinessOrder.Status.COMPLETED:
						complete_order(order)
