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
var close_sign_label: Label3D
const PREP_SPEED: float = 33.34 # Exactly 3.0s to complete 0% to 100%
var current_prep_speed: float = 33.34

# Business Upgrades State
var is_extra_table_unlocked: bool = false
var is_quick_stove_unlocked: bool = false
var is_kitchen_capacity_unlocked: bool = false

var extra_table_node: Node3D = null
var stove_upgrade_node: Node3D = null
var kitchen_capacity_node: Node3D = null

var table_occupied: Dictionary = {} # table_index -> bool
var table_customers: Dictionary = {} # table_index -> HuTieuCustomer

class NoodleStation extends Interactable:
	var hutieu: HuTieuBusiness
	var station_type: String = "" # "table", "blanch_pot", "broth_pot", "topping_counter", "prep_station"
	var table_index: int = 0
	func _init() -> void:
		interaction_radius = 2.4
	
	func available(player_node: Node3D) -> bool:
		if not enabled or not is_instance_valid(hutieu):
			return false
		if station_type == "prep_station":
			return hutieu.prep_state != HuTieuBusiness.PrepState.OPEN
		if station_type == "close_sign":
			return hutieu.prep_state == HuTieuBusiness.PrepState.OPEN
		return hutieu.is_open
	
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
var current_bowl_stock_bonus: int = 0
var bowl_visual: Node3D
var bowl_carrier: Node3D
var selected_recipe_index: int = 0 # 0: Nam Vang, 1: Sườn heo, 2: Tôm thịt
var blanch_timer: float = 0.0
const BLANCH_DURATION: float = 1.6
var current_blanch_duration: float = 1.6

var menu_catalog: Array[Dictionary] = [
	{
		"type": "noodle_nam_vang",
		"title": "Hủ tiếu Nam Vang",
		"reward": 45000,
		"patience": 55.0,
		"blanch_time": 1.5,
		"ingredients": "Tôm, thịt băm, trứng cút & tỏi phi",
		"stock_item": "ing_cracklings",
		"broth_desc": "Nước lèo xương hầm ngọt thanh"
	},
	{
		"type": "noodle_xuong",
		"title": "Hủ tiếu sườn heo",
		"reward": 40000,
		"patience": 50.0,
		"blanch_time": 1.8,
		"ingredients": "Sườn non ninh mềm & hành lá",
		"stock_item": "ing_pork_ribs",
		"broth_desc": "Nước lèo sườn béo ngậy đậm đà"
	},
	{
		"type": "noodle_tom_thit",
		"title": "Hủ tiếu tôm thịt tươi",
		"reward": 45000,
		"patience": 55.0,
		"blanch_time": 1.2,
		"ingredients": "Tôm luộc, xá xíu & giá hẹ tươi",
		"stock_item": "ing_fresh_shrimp",
		"broth_desc": "Nước dùng thanh đạm tự nhiên"
	},
	{
		"type": "noodle_greens",
		"title": "Hủ tiếu rau cải vườn nhà",
		"reward": 40000,
		"patience": 55.0,
		"blanch_time": 1.5,
		"ingredients": "Rau cải xanh, hành lá & tỏi phi",
		"stock_item": "produce_lettuce",
		"broth_desc": "Nước dùng rau củ thanh ngọt"
	}
]

var customer_names: Array[String] = [
	"Bác Năm", "Cô Mai", "Em Linh", "Chú Ba", "Anh Dũng", "Chị Hoa", "Bác Tám"
]

func _ready() -> void:
	add_to_group("hutieu_business")
	shop_id = "hutieu"
	shop_name = "Quán Hủ Tiếu Cô Bảy"
	open_hour = 6.0
	close_hour = 21.0
	spawn_interval = 15.0
	super._ready()
	
	_create_kitchen_and_table_stations()
	_build_cooking_details()
	bowl_visual = preload("res://scenes/business/noodle_bowl_visual.tscn").instantiate()
	bowl_visual.name = "PreparedBowlVisual"
	add_child(bowl_visual)

func _get_peak_hour_ranges() -> Array[Vector2]:
	return [
		Vector2(6.5, 8.5),   # Breakfast rush
		Vector2(11.5, 13.5), # Lunch rush
		Vector2(18.0, 20.0)  # Dinner rush
	]

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
		lbl.position = Vector3(0, 2.2, 0)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.font_size = 20
		lbl.pixel_size = 0.004
		lbl.outline_size = 8
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
	prep_station.position = Vector3(-50.0, 0, -17.0)
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

	# A separate sign remains reachable after opening, without hiding the broth pot.
	var close_sign := NoodleStation.new()
	close_sign.name = "CloseShopSign"
	close_sign.hutieu = self
	close_sign.station_type = "close_sign"
	close_sign.position = Vector3(-53.0, 0, -15.4)
	add_child(close_sign)
	var sign_label := Label3D.new()
	sign_label.text = "ĐÓNG QUÁN · E"
	sign_label.position = Vector3(0, 1.4, 0)
	sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign_label.font_size = 22
	sign_label.pixel_size = 0.004
	sign_label.outline_size = 6
	close_sign.add_child(sign_label)
	close_sign_label = sign_label
	close_sign_label.visible = prep_state == PrepState.OPEN

func _build_cooking_details() -> void:
	# Decorative meshes stay separate from the existing stations and colliders.
	var details := Node3D.new()
	details.name = "CookingDetails"
	add_child(details)
	var metal := Art.material(Color("aabcb9"))
	for x in [-51.8, -50.0]:
		var pot := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.32
		mesh.bottom_radius = 0.29
		mesh.height = 0.35
		mesh.radial_segments = 12
		pot.mesh = mesh
		pot.material_override = metal
		pot.position = Vector3(x, 1.30, -17.2)
		details.add_child(pot)
		var rim := MeshInstance3D.new()
		var rim_mesh := TorusMesh.new()
		rim_mesh.inner_radius = 0.27
		rim_mesh.outer_radius = 0.34
		rim_mesh.rings = 12
		rim_mesh.ring_segments = 6
		rim.mesh = rim_mesh
		rim.material_override = metal
		rim.position = Vector3(x, 1.49, -17.2)
		details.add_child(rim)
	# Trays of ingredients and two condiment bottles.
	for i in range(4):
		var x := -48.8 + float(i) * 0.37
		Art.box(details, Vector3(x, 1.15, -17.15), Vector3(0.32, 0.08, 0.38), Color("d7dfd7"))
		var colors := [Color("e89579"), Color("b9765a"), Color("8bac6d"), Color("f0ddad")]
		for j in range(3):
			Art.ball(details, Vector3(x + (float(j) - 1.0) * 0.08, 1.22, -17.15), 0.06, colors[i], Vector3(1, 0.6, 1))
	for i in range(2):
		Art.box(details, Vector3(-47.55 + float(i) * 0.18, 1.29, -17.28), Vector3(0.13, 0.29, 0.13), Color("b85842") if i == 0 else Color("e3ad62"))
	var menu := Label3D.new()
	menu.text = "HỦ TIẾU SA ĐÉC\nNam Vang · Sườn · Tôm thịt · Rau cải"
	menu.position = Vector3(-50, 2.4, -16.46)
	menu.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	menu.font_size = 26
	menu.pixel_size = 0.004
	menu.modulate = Color("fff1cf")
	menu.outline_size = 6
	menu.outline_modulate = Color("593f34")
	details.add_child(menu)

func _update_prep_billboard() -> void:
	if is_instance_valid(close_sign_label):
		close_sign_label.visible = prep_state == PrepState.OPEN
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

func close_shop() -> void:
	prep_state = PrepState.CLOSED
	prep_progress = 0.0
	super.close_shop()
	_update_prep_billboard()

func reset_daily_state() -> void:
	prep_state = PrepState.CLOSED
	prep_progress = 0.0
	current_bowl_state = BowlState.EMPTY
	current_bowl_dish = ""
	current_bowl_stock_bonus = 0
	super.reset_daily_state()
	_safe_clear_remaining_customers()
	_update_prep_billboard()

func _safe_clear_remaining_customers() -> void:
	for tbl in table_customers.keys():
		var cust = table_customers[tbl]
		if is_instance_valid(cust) and cust.current_state != HuTieuCustomer.State.LEAVING and cust.current_state != HuTieuCustomer.State.DESPAWNED:
			cust.notify_order_failed("shop_closed")
	table_orders.clear()
	# Keep tables occupied until their current customers finish departing.
	for tbl in table_status_labels:
		if is_instance_valid(table_status_labels[tbl]):
			table_status_labels[tbl].visible = false
	current_bowl_state = BowlState.EMPTY
	current_bowl_dish = ""
	current_bowl_stock_bonus = 0

func _process(delta: float) -> void:
	super._process(delta)
	
	# Update preparation progression
	if prep_state == PrepState.PREPARING:
		prep_progress = minf(100.0, prep_progress + current_prep_speed * delta)
		if prep_progress >= 100.0:
			prep_state = PrepState.READY
			_show_feedback(Vector3(-50.0, 0, -17.2), "✅ Chuẩn bị hoàn tất! Nhấn E để sẵn sàng bán!", Color("ffd54f"))
	
	_update_prep_billboard()
	
	if current_bowl_state == BowlState.BLANCHING:
		blanch_timer -= delta
		if blanch_timer <= 0.0:
			current_bowl_state = BowlState.NOODLES_DONE
			_show_feedback(Vector3(-51.8, 0, -17.2), "🍜 Sợi hủ tiếu chín dai ngon! Vớt ra tô nào!", Color("ffe082"))
	
	_update_bowl_visual()
	for table in table_orders:
		_update_table_display(table)

func _update_bowl_visual() -> void:
	if not is_instance_valid(bowl_visual): return
	var stage := 0
	match current_bowl_state:
		BowlState.BLANCHING: stage = 1
		BowlState.NOODLES_DONE: stage = 2
		BowlState.BROTH_ADDED: stage = 3
		BowlState.FULLY_PREPARED: stage = 4
	bowl_visual.call("set_content", stage, current_bowl_dish)
	var anchor: Node3D = null
	if is_instance_valid(bowl_carrier) and "hold_anchor" in bowl_carrier and "held_pillow" in bowl_carrier and not bowl_carrier.get("held_pillow"):
		anchor = bowl_carrier.get("hold_anchor") as Node3D
	if stage == 4 and is_instance_valid(anchor):
		bowl_visual.global_position = anchor.global_position
		bowl_visual.global_rotation = Vector3.ZERO
	else:
		bowl_visual.position = Vector3(-48.2, 1.12, -17.0) if stage >= 3 else Vector3(-51.8, 1.12, -17.0)
		bowl_visual.rotation = Vector3.ZERO

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
	var order_id := "hutieu_%d_%d_%d_%d" % [free_table, int(Time.get_unix_time_from_system()), Time.get_ticks_usec(), randi()]
	
	var adjusted_patience: float = float(dish["patience"]) * get_patience_multiplier()
	var order := BusinessOrder.new(
		order_id,
		dish["type"],
		dish["title"],
		dish["reward"],
		["boil_noodles", "add_broth", "add_toppings", "serve_table"],
		adjusted_patience
	)
	order.is_peak_hour = is_peak_hour
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
		if table_customers.get(tbl_idx) != customer: return
		table_occupied.erase(tbl_idx)
		table_customers.erase(tbl_idx)
		table_orders.erase(tbl_idx)
		if table_status_labels.has(tbl_idx):
			table_status_labels[tbl_idx].visible = false
	)

func cycle_recipe() -> String:
	selected_recipe_index = (selected_recipe_index + 1) % menu_catalog.size()
	var current_title: String = menu_catalog[selected_recipe_index]["title"]
	_show_feedback(Vector3(-48.2, 0, -17.2), "Đã chọn món: %s 🥢" % current_title, Color("80d8ff"))
	return current_title

func set_recipe_by_title(dish_title: String) -> bool:
	for i in range(menu_catalog.size()):
		if menu_catalog[i]["title"] == dish_title:
			selected_recipe_index = i
			return true
	return false

func get_patience_multiplier() -> float:
	var base_mult := super.get_patience_multiplier()
	if is_kitchen_capacity_unlocked:
		base_mult *= 1.35 # 35% longer patience while enjoying iced tea & atmosphere
	return base_mult

func apply_extra_table_upgrade() -> void:
	is_extra_table_unlocked = true
	if table_positions.size() < 4:
		var pos4 := Vector3(-40, 0, -23)
		table_positions.append(pos4)
		_build_extra_table_visual(pos4)

func apply_quick_stove_upgrade() -> void:
	is_quick_stove_unlocked = true
	current_prep_speed = 66.7 # 2x morning prep speed (completes in 1.5s)
	current_blanch_duration = 0.4 # Super rapid noodle boiling
	_build_quick_stove_visual()

func apply_kitchen_capacity_upgrade() -> void:
	is_kitchen_capacity_unlocked = true
	_build_kitchen_capacity_visual()

func _build_extra_table_visual(pos: Vector3) -> void:
	if is_instance_valid(extra_table_node): return
	extra_table_node = Node3D.new()
	extra_table_node.name = "ExtraTableUpgradeVisual"
	
	var idx := 3
	var table_station := NoodleStation.new()
	table_station.name = "DiningTable_%d" % idx
	table_station.hutieu = self
	table_station.station_type = "table"
	table_station.table_index = idx
	table_station.position = pos
	extra_table_node.add_child(table_station)
	
	var lbl := Label3D.new()
	lbl.position = Vector3(0, 1.8, 0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size = 22
	lbl.pixel_size = 0.004
	lbl.outline_size = 6
	lbl.modulate = Color("ffcc80")
	lbl.outline_modulate = Color("1a1a1a")
	lbl.visible = false
	table_station.add_child(lbl)
	table_status_labels[idx] = lbl
	
	# Table mesh
	var t_mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.75
	cyl.bottom_radius = 0.75
	cyl.height = 0.75
	t_mesh.mesh = cyl
	var t_mat := StandardMaterial3D.new()
	t_mat.albedo_color = Color("eaa187")
	t_mesh.material_override = t_mat
	t_mesh.position = pos + Vector3(0, 0.375, 0)
	extra_table_node.add_child(t_mesh)
	
	# Parasol shade umbrella over the extra outdoor table
	var pole := MeshInstance3D.new()
	var p_cyl := CylinderMesh.new()
	p_cyl.top_radius = 0.04
	p_cyl.bottom_radius = 0.04
	p_cyl.height = 2.4
	pole.mesh = p_cyl
	var pol_mat := StandardMaterial3D.new()
	pol_mat.albedo_color = Color("8d6e63")
	pole.material_override = pol_mat
	pole.position = pos + Vector3(0, 1.2, 0)
	extra_table_node.add_child(pole)
	
	var canopy := MeshInstance3D.new()
	var can_cone := CylinderMesh.new()
	can_cone.top_radius = 0.0
	can_cone.bottom_radius = 1.6
	can_cone.height = 0.6
	canopy.mesh = can_cone
	var can_mat := StandardMaterial3D.new()
	can_mat.albedo_color = Color("ff7043") # Bright welcoming orange
	canopy.material_override = can_mat
	canopy.position = pos + Vector3(0, 2.4, 0)
	extra_table_node.add_child(canopy)
	
	# Chairs
	for x_offset in [-1.0, 1.0]:
		var chair_mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.5, 0.45, 0.5)
		chair_mesh.mesh = box
		var c_mat := StandardMaterial3D.new()
		c_mat.albedo_color = Color("84acb5") if x_offset > 0 else Color("dc7666")
		chair_mesh.material_override = c_mat
		chair_mesh.position = pos + Vector3(x_offset, 0.225, 0)
		extra_table_node.add_child(chair_mesh)
	
	add_child(extra_table_node)

func _build_quick_stove_visual() -> void:
	if is_instance_valid(stove_upgrade_node): return
	stove_upgrade_node = Node3D.new()
	stove_upgrade_node.name = "QuickStoveUpgradeVisual"
	
	# Stainless steel high-pressure boiling boiler at blanch station
	var pot_pos := Vector3(-51.8, 0, -17.2)
	var burner := MeshInstance3D.new()
	var b_cyl := CylinderMesh.new()
	b_cyl.top_radius = 0.4
	b_cyl.bottom_radius = 0.4
	b_cyl.height = 0.1
	burner.mesh = b_cyl
	var b_mat := StandardMaterial3D.new()
	b_mat.albedo_color = Color("0288d1") # Glowing blue flame burner
	b_mat.emission_enabled = true
	b_mat.emission = Color("03a9f4")
	b_mat.emission_energy_multiplier = 2.0
	burner.material_override = b_mat
	burner.position = pot_pos + Vector3(0, 0.82, 0)
	stove_upgrade_node.add_child(burner)
	
	# Steel pressure valve
	var valve := MeshInstance3D.new()
	var v_box := BoxMesh.new()
	v_box.size = Vector3(0.12, 0.2, 0.12)
	valve.mesh = v_box
	var v_mat := StandardMaterial3D.new()
	v_mat.albedo_color = Color("ffd54f")
	v_mat.metallic = 0.9
	valve.material_override = v_mat
	valve.position = pot_pos + Vector3(0, 1.45, 0)
	stove_upgrade_node.add_child(valve)
	
	add_child(stove_upgrade_node)

func _build_kitchen_capacity_visual() -> void:
	if is_instance_valid(kitchen_capacity_node): return
	kitchen_capacity_node = Node3D.new()
	kitchen_capacity_node.name = "KitchenCapacityUpgradeVisual"
	var topping_pos := Vector3(-48.2, 0, -17.2)
	
	# Iced Tea Dispenser ("Trà Đá Miễn Phí")
	var dispenser := MeshInstance3D.new()
	var d_cyl := CylinderMesh.new()
	d_cyl.top_radius = 0.22
	d_cyl.bottom_radius = 0.22
	d_cyl.height = 0.65
	dispenser.mesh = d_cyl
	var d_mat := StandardMaterial3D.new()
	d_mat.albedo_color = Color("e65100") # Amber iced tea
	d_mat.roughness = 0.2
	dispenser.material_override = d_mat
	dispenser.position = topping_pos + Vector3(0.7, 1.15, 0)
	kitchen_capacity_node.add_child(dispenser)
	
	var tea_sign := Label3D.new()
	tea_sign.position = topping_pos + Vector3(0.7, 1.7, 0)
	tea_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tea_sign.font_size = 18
	tea_sign.pixel_size = 0.0035
	tea_sign.outline_size = 6
	tea_sign.modulate = Color("80d8ff")
	tea_sign.outline_modulate = Color("1a1a1a")
	tea_sign.text = "🍵 TRÀ ĐÁ MIỄN PHÍ"
	kitchen_capacity_node.add_child(tea_sign)
	
	add_child(kitchen_capacity_node)

func complete_order(order: BusinessOrder) -> bool:
	if not is_instance_valid(order): return false
	if not active_orders.has(order) or completed_order_ids.has(order.order_id):
		return false
	if order.status != BusinessOrder.Status.COMPLETED:
		return false
	
	var tbl := order.table_index
	if is_kitchen_capacity_unlocked:
		var bonus_tip := int(order.reward_money * 0.25)
		order.tip_money += bonus_tip
		_show_feedback(table_positions[tbl], "🍵 Quán chu đáo tặng trà đá! Khách thưởng thêm tip: +%s đ ✨" % HouseholdWallet.format_money(bonus_tip), Color("ffd54f"))
		
	var success := super.complete_order(order)
	if success:
		if table_customers.has(tbl) and is_instance_valid(table_customers[tbl]):
			table_customers[tbl].notify_food_served()
	return success

func _on_customer_depart(order: BusinessOrder) -> void:
	var tbl := order.table_index
	if table_customers.has(tbl) and is_instance_valid(table_customers[tbl]):
		var cust: HuTieuCustomer = table_customers[tbl]
		# If order was completed/paid, customer is enjoying the food and will leave after eating.
		# Only force departure on failed/cancelled orders.
		if order.status != BusinessOrder.Status.COMPLETED and order.status != BusinessOrder.Status.PAID:
			if table_status_labels.has(tbl):
				table_status_labels[tbl].text = "🍜 Bàn %d: [ĐÃ HỦY - KHÁCH BỎ VỀ 💢]" % (tbl + 1)
				table_status_labels[tbl].modulate = Color("ff5252")
			if cust.current_state != HuTieuCustomer.State.LEAVING and cust.current_state != HuTieuCustomer.State.DESPAWNED:
				cust.notify_order_failed("timeout")
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
	if order.status == BusinessOrder.Status.FAILED or order.status == BusinessOrder.Status.CANCELLED:
		lbl.visible = true
		lbl.text = "🍜 Bàn %d: [ĐÃ HỦY - KHÁCH BỎ VỀ 💢]" % (table_index + 1)
		lbl.modulate = Color("ff5252")
		return
	
	lbl.visible = true
	var patience_pct := int(order.get_patience_ratio() * 100.0)
	var ready_indicator := ""
	if current_bowl_state == BowlState.FULLY_PREPARED and current_bowl_dish == order.service_title:
		ready_indicator = "👉 [MÓN ĐÃ NẤU XONG - MANG TỚI BÀN!]\n"
	
	lbl.text = "%s🍜 Bàn %d: %s\nKhách: %s | ⏳ %d%%" % [
		ready_indicator,
		table_index + 1,
		order.service_title,
		order.customer_name,
		patience_pct
	]
	
	if current_bowl_state == BowlState.FULLY_PREPARED and current_bowl_dish == order.service_title:
		lbl.modulate = Color("69f0ae")
	elif order.get_patience_ratio() > 0.5:
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
					var pct := int(prep_progress)
					var blocks := int(pct / 10)
					var bar := "█".repeat(blocks) + "░".repeat(10 - blocks)
					return "Đang chuẩn bị quán... [%s] %d%%" % [bar, pct]
				PrepState.READY:
					return "Sẵn sàng bán (Nhấn E để mở cửa)"
				PrepState.OPEN:
					return "Đóng cửa quán hủ tiếu (kết thúc ngày)"
		
		"close_sign":
			return "Đóng cửa quán hủ tiếu (kết thúc ngày)"

		"blanch_pot":
			if current_bowl_state == BowlState.EMPTY:
				return "Trụng hủ tiếu tươi vào nồi nước sôi" + stock_hint("ing_rice_noodle")
			elif current_bowl_state == BowlState.BLANCHING:
				return "Đang trụng hủ tiếu... (chờ sôi)"
			elif current_bowl_state == BowlState.NOODLES_DONE:
				return "Đã có hủ tiếu trong tô! Cần thêm nước lèo"
			elif current_bowl_state == BowlState.FULLY_PREPARED:
				return "Đổ tô hủ tiếu (%s) để nấu lại" % current_bowl_dish
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
			var cur_recipe := menu_catalog[selected_recipe_index]
			var waiting_tables: Array[String] = []
			for t_idx in table_orders:
				var ord: BusinessOrder = table_orders[t_idx]
				if ord.service_title == cur_recipe["title"] and ord.status == BusinessOrder.Status.PENDING:
					waiting_tables.append("Bàn %d" % (t_idx + 1))
			var hint := ""
			if waiting_tables.size() > 0:
				hint = " (%s đang đợi)" % ", ".join(waiting_tables)
			
			if current_bowl_state == BowlState.BROTH_ADDED:
				var next_dish: String = str(menu_catalog[(selected_recipe_index + 1) % menu_catalog.size()]["title"])
				return "Thêm topping: %s%s [E] · [F] Đổi món (%s)%s" % [cur_recipe["title"], hint, next_dish, stock_hint(cur_recipe.get("stock_item", ""))]
			elif current_bowl_state == BowlState.FULLY_PREPARED:
				return "Tô %s đã xong! Mang phục vụ khách" % current_bowl_dish
			else:
				return "Quầy đồ ăn kèm: %s%s (Nhấn F đổi món)" % [cur_recipe["title"], hint]
		
		"table":
			var tbl := station.table_index
			if not table_orders.has(tbl):
				return "Bàn ăn số %d (trống)" % (tbl + 1)
			var order: BusinessOrder = table_orders[tbl]
			if order.status == BusinessOrder.Status.FAILED or order.status == BusinessOrder.Status.CANCELLED:
				return "Bàn %d: Khách đã rời đi" % (tbl + 1)
			
			if current_bowl_state == BowlState.FULLY_PREPARED:
				if current_bowl_dish == order.service_title:
					return "Phục vụ %s cho Bàn %d" % [order.service_title, tbl + 1]
				else:
					return "Sai món! Bàn %d gọi %s (Tô đang có: %s)" % [tbl + 1, order.service_title, current_bowl_dish]
			else:
				return "Bàn %d đang chờ: %s" % [tbl + 1, order.service_title]
	
	return "Tương tác"

func on_station_interacted(station: NoodleStation, player_node: Node3D) -> void:
	match station.station_type:
		"prep_station", "close_sign":
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
					_update_prep_billboard()
					_show_feedback(station.global_position, "🎉 Quán hủ tiếu chính thức MỞ CỬA đón khách!", Color("69f0ae"))
					shop_status_changed.emit(true)
				PrepState.OPEN:
					close_shop()
					_show_feedback(station.global_position, "Quán hủ tiếu đã ĐÓNG CỬA nghỉ ngơi!", Color("ffd54f"))
		
		"blanch_pot":
			if current_bowl_state == BowlState.EMPTY:
				current_bowl_state = BowlState.BLANCHING
				current_bowl_stock_bonus = 18000 if consume_household_stock("ing_rice_noodle") else 0
				blanch_timer = current_blanch_duration
				var dish_name: String = menu_catalog[selected_recipe_index]["title"]
				_show_feedback(station.global_position, "💧 Đang trụng sợi hủ tiếu cho món '%s'..." % dish_name, Color("80d8ff"))
			elif current_bowl_state == BowlState.BLANCHING:
				_show_feedback(station.global_position, "⏳ Đang trụng, vui lòng chờ vài giây...", Color("ffe082"))
			elif current_bowl_state == BowlState.FULLY_PREPARED or current_bowl_state == BowlState.BROTH_ADDED or current_bowl_state == BowlState.NOODLES_DONE:
				# Clear bowl to remake
				current_bowl_state = BowlState.EMPTY
				var discarded := current_bowl_dish if current_bowl_dish != "" else "tô dở dang"
				current_bowl_dish = ""
				current_bowl_stock_bonus = 0
				_show_feedback(station.global_position, "Đã dọn sạch %s để nấu lại!" % discarded, Color("ffd54f"))
			else:
				_show_feedback(station.global_position, "Tô đã có bánh hủ tiếu rồi!", Color("cfd8dc"))
		
		"broth_pot":
			if current_bowl_state == BowlState.NOODLES_DONE:
				current_bowl_state = BowlState.BROTH_ADDED
				var b_desc: String = menu_catalog[selected_recipe_index].get("broth_desc", "nước lèo hầm xương đậm đà")
				_show_feedback(station.global_position, "🍲 Đã chan muôi %s nóng hổi!" % b_desc, Color("69f0ae"))
			elif current_bowl_state == BowlState.EMPTY:
				_show_feedback(station.global_position, "⚠️ Phải trụng hủ tiếu trước khi chan nước lèo!", Color("ffab40"))
			else:
				_show_feedback(station.global_position, "Đã chan đủ nước lèo rồi!", Color("cfd8dc"))
		
		"topping_counter":
			if current_bowl_state == BowlState.BROTH_ADDED:
				current_bowl_state = BowlState.FULLY_PREPARED
				bowl_carrier = player_node
				# Strict assignment: Exactly matches the player's selected recipe!
				current_bowl_dish = menu_catalog[selected_recipe_index]["title"]
				var ingredient_id: String = menu_catalog[selected_recipe_index].get("stock_item", "")
				if ingredient_id != "" and consume_household_stock(ingredient_id):
					var econ := get_tree().get_first_node_in_group("economy_manager") as EconomyManager
					var product: EconomyProduct = econ.get_product(ingredient_id) if is_instance_valid(econ) else null
					if product:
						current_bowl_stock_bonus += product.price + 3000
				var ings: String = menu_catalog[selected_recipe_index].get("ingredients", "topping thơm ngon")
				_show_feedback(station.global_position, "✨ Đã rắc topping (%s)!\nTô '%s' đã sẵn sàng phục vụ!" % [ings, current_bowl_dish], Color("69f0ae"))
			elif current_bowl_state == BowlState.FULLY_PREPARED:
				_show_feedback(station.global_position, "Tô '%s' đã sẵn sàng, mang phục vụ khách nào!" % current_bowl_dish, Color("69f0ae"))
			else:
				_show_feedback(station.global_position, "⚠️ Cần trụng hủ tiếu và chan nước lèo trước!", Color("ffab40"))
		
		"table":
			var tbl := station.table_index
			if not table_orders.has(tbl):
				_show_feedback(station.global_position, "Bàn này chưa có khách ngồi.", Color("cfd8dc"))
				return
			
			var order: BusinessOrder = table_orders[tbl]
			if not active_orders.has(order) or not order.is_actionable():
				_show_feedback(station.global_position, "⚠️ Không thể phục vụ Bàn %d!" % (tbl + 1), Color("ffab40"))
				return
			
			if current_bowl_state != BowlState.FULLY_PREPARED:
				_show_feedback(station.global_position, "⚠️ Chưa chuẩn bị xong tô hủ tiếu để phục vụ!", Color("ffab40"))
				return
			
			# Strict validation: prepared dish MUST match ordered dish
			if current_bowl_dish != order.service_title:
				order.record_mistake(0.15)
				_show_feedback(station.global_position, "❌ Món ăn không đúng! Khách gọi '%s', nhưng tô này là '%s'!" % [order.service_title, current_bowl_dish], Color("ff5252"))
				return # Rejected without completing order, paying reward, or consuming bowl!
			
			# Keep the prepared bowl if the order cannot be completed.
			var previous_status := order.status
			var previous_tip := order.tip_money
			order.tip_money += current_bowl_stock_bonus
			order.status = BusinessOrder.Status.COMPLETED
			if not complete_order(order):
				order.status = previous_status
				order.tip_money = previous_tip
				_show_feedback(station.global_position, "⚠️ Không thể hoàn tất đơn này.", Color("ffab40"))
				return
			current_bowl_state = BowlState.EMPTY
			current_bowl_dish = ""
			bowl_carrier = null
			current_bowl_stock_bonus = 0
			_show_feedback(station.global_position, "😋 Khách ăn ngon miệng khen hết lời!", Color("69f0ae"))
