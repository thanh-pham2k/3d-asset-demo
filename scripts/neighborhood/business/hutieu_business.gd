class_name HuTieuBusiness
extends BusinessShop

## Girl's Hu Tieu Shop gameplay controller.
## Manages customer seating at dining tables, food orders, interactive cooking stations
## (blanching noodles, hot bone broth, fresh toppings), dish assembly, serving, and patience.

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

func _process(delta: float) -> void:
	super._process(delta)
	
	if current_bowl_state == BowlState.BLANCHING:
		blanch_timer -= delta
		if blanch_timer <= 0.0:
			current_bowl_state = BowlState.NOODLES_DONE
			_show_feedback(Vector3(-51.8, 0, -17.2), "🍜 Sợi hủ tiếu chín dai ngon! Vớt ra tô nào!", Color("ffe082"))
	
	for table in table_orders:
		_update_table_display(table)

func _try_spawn_customer() -> void:
	var free_table := -1
	for i in range(table_positions.size()):
		if not table_orders.has(i):
			free_table = i
			break
	if free_table == -1: return # All tables occupied
	
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
	
	table_orders[free_table] = order
	active_orders.append(order)
	order_received.emit(order)
	_update_table_display(free_table)

func _on_customer_depart(order: BusinessOrder) -> void:
	var tbl := order.table_index
	if table_orders.has(tbl) and table_orders[tbl] == order:
		table_orders.erase(tbl)
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
