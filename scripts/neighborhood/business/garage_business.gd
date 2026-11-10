class_name GarageBusiness
extends BusinessShop

## Boy's Motorcycle Repair Shop gameplay controller.
## Manages arriving customers with scooters, repair requests (inflate, patch, replace),
## interactive tool stations, sequential validation, and customer patience.

class RepairStation extends Interactable:
	var garage: GarageBusiness
	var station_type: String = "" # "bike_bay", "air_pump", "workbench", "tire_rack"
	var bay_index: int = 0
	
	func available(player_node: Node3D) -> bool:
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
		
		# Overhead status label
		var lbl := Label3D.new()
		lbl.position = Vector3(0, 1.8, 0)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.font_size = 22
		lbl.pixel_size = 0.004
		lbl.outline_size = 6
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

func _try_spawn_customer() -> void:
	var free_bay := -1
	for i in range(bay_positions.size()):
		if not bay_orders.has(i):
			free_bay = i
			break
	if free_bay == -1: return # All bays busy
	
	# Pick random service
	var service: Dictionary = service_catalog[randi() % service_catalog.size()]
	var cust_name: String = customer_names[randi() % customer_names.size()]
	var order_id := "garage_%d_%d" % [free_bay, Time.get_ticks_msec()]
	
	var order := BusinessOrder.new(
		order_id,
		service["type"],
		service["title"],
		service["reward"],
		service["steps"].duplicate(),
		service["patience"]
	)
	order.customer_name = cust_name
	order.table_index = free_bay
	order.target_spot = bay_positions[free_bay] + position
	
	bay_orders[free_bay] = order
	active_orders.append(order)
	order_received.emit(order)
	
	# Spawn visual scooter in bay
	_spawn_bay_scooter(free_bay)
	_update_bay_display(free_bay)

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
	if bay_orders.has(bay) and bay_orders[bay] == order:
		bay_orders.erase(bay)
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
			var next_step := order.get_current_required_step()
			match next_step:
				"pump_air":
					return "Bơm lốp xe (Khoang %d)" % (bay + 1)
				"remove_tire":
					return "Tháo lốp cũ (Khoang %d)" % (bay + 1)
				"mount_tire":
					if get_holding_tool(player_node) == "new_tire":
						return "Lắp lốp mới vào xe (Khoang %d)" % (bay + 1)
					else:
						return "Cần lấy lốp mới từ kệ trước!"
				_:
					return "Thực hiện: %s" % order.service_title
		
		"air_pump":
			return "Máy bơm hơi tự động"
		
		"workbench":
			if get_holding_tool(player_node) == "patch_kit":
				return "Đang cầm bộ vá săm"
			return "Lấy bộ vá săm & keo dán"
		
		"tire_rack":
			if get_holding_tool(player_node) == "new_tire":
				return "Đang cầm lốp mới"
			return "Lấy lốp xe mới từ kệ"
	
	return "Tương tác"

func on_station_interacted(station: RepairStation, player_node: Node3D) -> void:
	match station.station_type:
		"workbench":
			set_holding_tool(player_node, "patch_kit")
			_show_feedback(station.global_position, "Đã chuẩn bị miếng vá săm & keo! 🧰", Color("80d8ff"))
		
		"tire_rack":
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
			var next_step := order.get_current_required_step()
			
			match next_step:
				"pump_air":
					# Successfully pump air
					order.advance_step("pump_air")
					order_step_done.emit(order, "pump_air")
					_show_feedback(station.global_position, "💨 Đã bơm căng chuẩn áp suất!", Color("69f0ae"))
					if order.status == BusinessOrder.Status.COMPLETED:
						complete_order(order)
				
				"patch_kit":
					if get_holding_tool(player_node) == "patch_kit":
						order.advance_step("patch_kit")
						set_holding_tool(player_node, "")
						order_step_done.emit(order, "patch_kit")
						_show_feedback(station.global_position, "🔧 Đã dán vá săm kín mít!", Color("69f0ae"))
					else:
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
						_show_feedback(station.global_position, "⚠️ Cần lấy lốp mới từ kệ trước!", Color("ffab40"))
				
				_:
					if order.status == BusinessOrder.Status.COMPLETED:
						complete_order(order)
