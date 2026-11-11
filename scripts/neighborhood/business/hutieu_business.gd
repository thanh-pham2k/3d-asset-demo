class_name HuTieuBusiness
extends BusinessShop

const HuTieuCustomer = preload("res://scripts/neighborhood/business/hutieu_customer.gd")

## Girl's Hu Tieu Shop gameplay controller.
## Manages preparation & opening phases, customer seating at dining tables, food orders,
## interactive cooking stations, dish assembly, serving, and customer satisfaction.

enum PrepState {
	CLOSED,
	PREPARING,
	READY,
	OPEN
}

var prep_state: PrepState = PrepState.CLOSED
var prep_progress: float = 0.0 # 0 to 100
var prep_station: NoodleStation
var prep_billboard: Label3D
const PREP_SPEED: float = 30.0 # ~3.3s to prepare

var table_occupied: Dictionary = {} # table_index -> bool
var table_customers: Dictionary = {} # table_index -> HuTieuCustomer

class NoodleStation extends Interactable:
	var hutieu: HuTieuBusiness
	var station_type: String = "" # "table", "blanch_pot", "broth_pot", "topping_counter"
	var table_index: int = 0
	
	func available(player_node: Node3D) -> bool:
		return enabled and is_instance_valid(hutieu) and hutieu.is_open
	
	func prompt(player_node: Node3D) -> String:
		if not hutieu: return "Quán hủ tiếu"
		return hutieu.get_station_prompt(self, player_node)
	
	func interact(player_node: Node3D) -> void:
		if hutieu: hutieu.on_station_interacted(self, player_node)

enum BowlState {
	EMPTY,
	BLANCHING,
	NOODLES_DONE,
	BROTH_ADDED,
	FULLY_PREPARED
}

var table_positions: Array[Vector3] = [
	Vector3(-55, 0, -23),
	Vector3(-50, 0, -23),
	Vector3(-45, 0, -23)
]

# Track orders per table: table_index -> BusinessOrder
var table_orders: Dictionary = {}
var table_status_labels: Dictionary = {}

# Current bowl cooking state on counter
var current_bowl_state: BowlState = BowlState.EMPTY
var current_bowl_dish: String = "" # e.g. "Hủ tiếu Nam Vang"
var blanch_timer: float = 0.0
const BLANCH_DURATION: float = 1.6

var menu_catalog: Array[Dictionary] = [
	{
		"type": "noodle_nam_vang",
		"title": "Hủ tiếu Nam Vang",
		"reward": 45000,
		"patience": 55.0
	},
	{
		"type": "noodle_xuong",
		"title": "Hủ tiếu sườn heo",
		"reward": 40000,
		"patience": 50.0
	},
	{
		"type": "noodle_tom_thit",
		"title": "Hủ tiếu tôm thịt tươi",
		"reward": 45000,
		"patience": 55.0
	}
]

var customer_names: Array[String] = [
	"Bác Năm", "Cô Mai", "Em Linh", "Chú Ba", "Anh Dũng", "Chị Hoa", "Bác Tám"
]

func _ready() -> void:
	shop_id = "hutieu"
	shop_name = "Quán Hủ Tiếu Cô Bảy"
	open_hour = 6.0
	close_hour = 21.0
	spawn_interval = 15.0
	super._ready()
	
	_create_kitchen_and_table_stations()

func _create_kitchen_and_table_stations() -> void:
	# 1. Dining Tables
	for i in range(table_positions.size()):
		var table := NoodleStation.new()
		table.name = "DiningTable_%d" % i
		table.hutieu = self
		table.station_type = "table"
		table.table_index = i
		table.position = table_positions[i]
		add_child(table)
		
		var lbl := Label3D.new()
		lbl.position = Vector3(0, 1.8, 0)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.font_size = 22
		lbl.pixel_size = 0.004
		lbl.outline_size = 6
		lbl.modulate = Color("ffcc80")
		lbl.outline_modulate = Color("1a1a1a")
		lbl.visible = false
		table.add_child(lbl)
		table_status_labels[i] = lbl
	
	# 2. Blanching pot (noodle strainer)
	var blanch := NoodleStation.new()
	blanch.name = "BlanchingStation"
	blanch.hutieu = self
	blanch.station_type = "blanch_pot"
	blanch.position = Vector3(-51.8, 0, -17.2)
	add_child(blanch)
	
	# 3. Broth cauldron (simmering bone broth)
	var broth := NoodleStation.new()
	broth.name = "BrothStation"
	broth.hutieu = self
	broth.station_type = "broth_pot"
	broth.position = Vector3(-50.0, 0, -17.2)
	add_child(broth)
	
	# 4. Topping counter (pork, shrimp, quail egg, fried shallots)
	var toppings := NoodleStation.new()
	toppings.name = "ToppingsStation"
	toppings.hutieu = self
	toppings.station_type = "topping_counter"
	toppings.position = Vector3(-48.2, 0, -17.2)
	add_child(toppings)
	
	# 5. Preparation & Opening Station
	prep_station = NoodleStation.new()
	prep_station.name = "PrepStation"
	prep_station.hutieu = self
	prep_station.station_type = "prep_station"
	prep_station.position = Vector3(-46.0, 0, -17.2)
	add_child(prep_station)
	
	prep_billboard = Label3D.new()
	prep_billboard.name = "PrepBillboard"
	prep_billboard.position = Vector3(-50.0, 3.2, -17.2)
	prep_billboard.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prep_billboard.font_size = 24
	prep_billboard.pixel_size = 0.005
	prep_billboard.outline_size = 8
	prep_billboard.modulate = Color("fff59d")
	prep_billboard.outline_modulate = Color("1a1a1a")
	add_child(prep_billboard)
	_update_prep_billboard()

func _update_prep_billboard() -> void:
	if not is_instance_valid(prep_billboard): return
	match prep_state:
		PrepState.CLOSED:
			prep_billboard.text = "%s\n[CHƯA MỞ CỬA]\n[E] Chuẩn bị mở quán" % shop_name
			prep_billboard.modulate = Color("ffcc80")
		PrepState.PREPARING:
			var stage := "Sơ chế nguyên liệu & hầm nước lèo..."
			if prep_progress > 60.0: stage = "Trụng hủ tiếu & sắp xếp bàn ghế..."
			var bar_blocks := int(prep_progress / 10.0)
			var bar_str := "█".repeat(bar_blocks) + "░".repeat(10 - bar_blocks)
			prep_billboard.text = "⏳ Đang chuẩn bị quán... %d%%\n[%s]\n%s" % [int(prep_progress), bar_str, stage]
			prep_billboard.modulate = Color("80deea")
		PrepState.READY:
			prep_billboard.text = "✅ Chuẩn bị hoàn tất (100%)!\n[E] Sẵn sàng bán - Mở cửa quán"
			prep_billboard.modulate = Color("69f0ae")
		PrepState.OPEN:
			prep_billboard.text = "🍜 %s\nĐang Mở Cửa Đón Khách!" % shop_name
			prep_billboard.modulate = Color("fff59d")

func set_shop_open_ready() -> void:
	prep_state = PrepState.OPEN
	prep_progress = 100.0
	is_open = true
	_update_prep_billboard()

func _process(delta: float) -> void:
	super._process(delta)
	
	# Update preparation progression
	if prep_state == PrepState.PREPARING:
		prep_progress = minf(100.0, prep_progress + PREP_SPEED * delta)
		if prep_progress >= 100.0:
			prep_state = PrepState.READY
			_show_feedback(Vector3(-50.0, 0, -17.2), "✅ Chuẩn bị hoàn tất! Nhấn E để sẵn sàng bán!", Color("ffd54f"))
	
	_update_prep_billboard()
	
	if current_bowl_state == BowlState.BLANCHING:
		blanch_timer -= delta
		if blanch_timer <= 0.0:
			current_bowl_state = BowlState.NOODLES_DONE
			_show_feedback(Vector3(-51.8, 0, -17.2), "🍜 Sợi hủ tiếu chín dai ngon! Vớt ra tô nào!", Color("ffe082"))
	
	for table in table_orders:
		_update_table_display(table)

func _try_spawn_customer() -> void:
	if prep_state != PrepState.OPEN or not is_open:
		return # Customers cannot arrive before opening
	
	var free_table := -1
	for i in range(table_positions.size()):
		if not table_occupied.get(i, false) and not table_orders.has(i):
			free_table = i
			break
	if free_table == -1: return # All tables occupied
	
	table_occupied[free_table] = true
	var dish: Dictionary = menu_catalog[randi() % menu_catalog.size()]
	var cust_name: String = customer_names[randi() % customer_names.size()]
	var order_id := "hutieu_%d_%d" % [free_table, Time.get_ticks_msec()]
	
	var order := BusinessOrder.new(
		order_id,
		dish["type"],
		dish["title"],
		dish["reward"],
		["boil_noodles", "add_broth", "add_toppings", "serve_table"],
		dish["patience"]
	)
	order.customer_name = cust_name
	order.table_index = free_table
	order.target_spot = table_positions[free_table]
	
	# Spawn customer walking from sidewalk to chair
	var chair_target := table_positions[free_table] + Vector3(-0.95, 0, 0)
	var approach_path: Array[Vector3] = [
		Vector3(-50, 0, -5),
		Vector3(-50, 0, -12),
		chair_target
	]
	var departure_path: Array[Vector3] = [
		chair_target,
		Vector3(-50, 0, -12),
		Vector3(-70, 0, -5)
	]
	
	var customer := HuTieuCustomer.new()
	customer.name = "HuTieuCustomer_%d" % free_table
	add_child(customer)
	customer.setup(free_table, cust_name, table_positions[free_table], approach_path, departure_path)
	table_customers[free_table] = customer
	
	customer.arrived_at_table.connect(func(tbl_idx: int):
		if not is_instance_valid(self): return
		table_orders[tbl_idx] = order
		active_orders.append(order)
		order_received.emit(order)
		_update_table_display(tbl_idx)
	)
	
	customer.departed_from_table.connect(func(tbl_idx: int):
		if not is_instance_valid(self): return
		table_occupied.erase(tbl_idx)
		table_customers.erase(tbl_idx)
		table_orders.erase(tbl_idx)
		if table_status_labels.has(tbl_idx):
			table_status_labels[tbl_idx].visible = false
	)

func complete_order(order: BusinessOrder) -> bool:
	var tbl := order.table_index
	if table_customers.has(tbl) and is_instance_valid(table_customers[tbl]):
		table_customers[tbl].notify_food_served()
	return super.complete_order(order)

func _on_customer_depart(order: BusinessOrder) -> void:
	var tbl := order.table_index
	if table_customers.has(tbl) and is_instance_valid(table_customers[tbl]):
		var cust: HuTieuCustomer = table_customers[tbl]
		# If order was completed/paid, customer is enjoying the food and will leave after eating.
		# Only force immediate departure on failed/cancelled orders.
		if order.status != BusinessOrder.Status.COMPLETED and order.status != BusinessOrder.Status.PAID:
			if cust.current_state != HuTieuCustomer.State.LEAVING and cust.current_state != HuTieuCustomer.State.DESPAWNED:
				cust._start_leaving()
	else:
		if table_orders.has(tbl) and table_orders[tbl] == order:
			table_orders.erase(tbl)
			table_occupied.erase(tbl)
			if table_status_labels.has(tbl):
				table_status_labels[tbl].visible = false

func _update_table_display(table_index: int) -> void:
	if not table_status_labels.has(table_index): return
	var lbl: Label3D = table_status_labels[table_index]
	if not table_orders.has(table_index):
		lbl.visible = false
		return
	
	var order: BusinessOrder = table_orders[table_index]
	lbl.visible = true
	var patience_pct := int(order.get_patience_ratio() * 100.0)
	lbl.text = "🍜 Bàn %d: %s\nKhách: %s | ⏳ %d%%" % [
		table_index + 1,
		order.service_title,
		order.customer_name,
		patience_pct
	]
	
	if order.get_patience_ratio() > 0.5:
		lbl.modulate = Color("69f0ae")
	elif order.get_patience_ratio() > 0.25:
		lbl.modulate = Color("ffd740")
	else:
		lbl.modulate = Color("ff5252")

func get_station_prompt(station: NoodleStation, _player: Node3D) -> String:
	match station.station_type:
		"prep_station":
			match prep_state:
				PrepState.CLOSED:
					return "Chuẩn bị mở quán"
				PrepState.PREPARING:
					return "Đang chuẩn bị quán... (%d%%)" % int(prep_progress)
				PrepState.READY:
					return "Sẵn sàng bán (Nhấn E để mở cửa)"
				PrepState.OPEN:
					return "Quán hủ tiếu đang mở cửa"
		
		"blanch_pot":
			if current_bowl_state == BowlState.EMPTY:
				return "Trụng hủ tiếu tươi vào nồi nước sôi"
			elif current_bowl_state == BowlState.BLANCHING:
				return "Đang trụng hủ tiếu... (chờ sôi)"
			elif current_bowl_state == BowlState.NOODLES_DONE:
				return "Đã có hủ tiếu trong tô! Cần thêm nước lèo"
			else:
				return "Nồi nước sôi trụng hủ tiếu"
		
		"broth_pot":
			if current_bowl_state == BowlState.NOODLES_DONE:
				return "Chan nước lèo hầm xương nóng hổi"
			elif current_bowl_state == BowlState.EMPTY:
				return "Cần trụng hủ tiếu trước khi chan nước lèo!"
			else:
				return "Nồi nước lèo thơm nức mũi"
		
		"topping_counter":
			if current_bowl_state == BowlState.BROTH_ADDED:
				return "Thêm tôm, thịt, tóp mỡ & hành phi"
			elif current_bowl_state == BowlState.FULLY_PREPARED:
				return "Tô hủ tiếu đã sẵn sàng phục vụ khách!"
			else:
				return "Quầy đồ ăn kèm (tôm, thịt, rau thơm)"
		
		"table":
			var tbl := station.table_index
			if not table_orders.has(tbl):
				return "Bàn ăn số %d (trống)" % (tbl + 1)
			var order: BusinessOrder = table_orders[tbl]
			if current_bowl_state == BowlState.FULLY_PREPARED:
				return "Phục vụ %s cho Bàn %d" % [order.service_title, tbl + 1]
			else:
				return "Bàn %d đang chờ: %s" % [tbl + 1, order.service_title]
	
	return "Tương tác"

func on_station_interacted(station: NoodleStation, player_node: Node3D) -> void:
	match station.station_type:
		"prep_station":
			match prep_state:
				PrepState.CLOSED:
					prep_state = PrepState.PREPARING
					prep_progress = 0.0
					_show_feedback(station.global_position, "Bắt đầu chuẩn bị nguyên liệu & nấu nước lèo!", Color("80deea"))
				PrepState.PREPARING:
					_show_feedback(station.global_position, "Đang chuẩn bị: %d%%..." % int(prep_progress), Color("ffe082"))
				PrepState.READY:
					prep_state = PrepState.OPEN
					is_open = true
					_show_feedback(station.global_position, "🎉 Quán hủ tiếu chính thức MỞ CỬA đón khách!", Color("69f0ae"))
					shop_status_changed.emit(true)
				PrepState.OPEN:
					_show_feedback(station.global_position, "Quán đang mở cửa đón khách tấp nập!", Color("69f0ae"))
		
		"blanch_pot":
			if current_bowl_state == BowlState.EMPTY:
				current_bowl_state = BowlState.BLANCHING
				blanch_timer = BLANCH_DURATION
				_show_feedback(station.global_position, "💧 Đang trụng sợi hủ tiếu vào vợt nước sôi...", Color("80d8ff"))
			elif current_bowl_state == BowlState.BLANCHING:
				_show_feedback(station.global_position, "⏳ Đang trụng, vui lòng chờ vài giây...", Color("ffe082"))
			else:
				_show_feedback(station.global_position, "Tô đã có bánh hủ tiếu rồi!", Color("cfd8dc"))
		
		"broth_pot":
			if current_bowl_state == BowlState.NOODLES_DONE:
				current_bowl_state = BowlState.BROTH_ADDED
				_show_feedback(station.global_position, "🍲 Đã chan muôi nước lèo hầm xương đậm đà!", Color("69f0ae"))
			elif current_bowl_state == BowlState.EMPTY:
				_show_feedback(station.global_position, "⚠️ Phải trụng hủ tiếu trước khi chan nước lèo!", Color("ffab40"))
			else:
				_show_feedback(station.global_position, "Đã chan đủ nước lèo rồi!", Color("cfd8dc"))
		
		"topping_counter":
			if current_bowl_state == BowlState.BROTH_ADDED:
				current_bowl_state = BowlState.FULLY_PREPARED
				# Assign dish matching the nearest waiting customer order
				var assigned := "Hủ tiếu Nam Vang"
				for tbl in table_orders:
					assigned = table_orders[tbl].service_title
					break
				current_bowl_dish = assigned
				_show_feedback(station.global_position, "✨ Đã rắc tôm thịt, tóp mỡ, hành phi thơm lừng!\nTô %s đã sẵn sàng!" % current_bowl_dish, Color("69f0ae"))
			elif current_bowl_state == BowlState.FULLY_PREPARED:
				_show_feedback(station.global_position, "Tô đã chuẩn bị xong, mang phục vụ khách nào!", Color("69f0ae"))
			else:
				_show_feedback(station.global_position, "⚠️ Cần trụng hủ tiếu và chan nước lèo trước!", Color("ffab40"))
		
		"table":
			var tbl := station.table_index
			if not table_orders.has(tbl):
				_show_feedback(station.global_position, "Bàn này chưa có khách ngồi.", Color("cfd8dc"))
				return
			
			var order: BusinessOrder = table_orders[tbl]
			if current_bowl_state == BowlState.FULLY_PREPARED:
				# Complete the order
				current_bowl_state = BowlState.EMPTY
				current_bowl_dish = ""
				order.status = BusinessOrder.Status.COMPLETED
				complete_order(order)
				_show_feedback(station.global_position, "😋 Khách ăn ngon miệng khen hết lời!", Color("69f0ae"))
			else:
				_show_feedback(station.global_position, "⚠️ Chưa chuẩn bị xong tô hủ tiếu để phục vụ!", Color("ffab40"))
