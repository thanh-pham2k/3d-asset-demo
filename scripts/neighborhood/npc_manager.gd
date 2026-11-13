class_name NPCManager
extends Node3D

## Manager responsible for spawning, updating schedules, coordinating
## neighborhood NPCs, lightweight 0-100 relationships, and optional neighbor requests.

signal npc_spawned(npc: NPCController)
signal npc_interaction_started(npc: NPCController, player: Node3D)
signal relationship_changed(npc_id: String, new_score: int, level_name: String)
signal request_completed(request_id: String, npc_id: String, reward: int)

@export var time_manager: NeighborhoodTimeManager
var npcs: Dictionary = {} # id -> NPCController
var _schedule_keys: Dictionary = {}
var _last_schedule_slot: int = -1

# Relationship & Request State (Part A, B, F)
var relationships: Dictionary = {} # npc_id -> int (0..100)
var talked_day: Dictionary = {} # npc_id -> int (day)
var served_today_counts: Dictionary = {} # npc_id -> { "day": int, "count": int }
var gifted_day: Dictionary = {} # npc_id -> int (day)
var last_npc_gift_day: Dictionary = {} # npc_id -> int (day)
var active_requests: Dictionary = {} # npc_id -> Dictionary
var completed_request_ids: Dictionary = {} # req_id -> true

# Clean Neighbor Card UI (Part E)
var neighbor_ui_layer: CanvasLayer = null
var neighbor_name_label: Label = null
var neighbor_level_label: Label = null
var neighbor_dialogue_label: Label = null
var neighbor_request_label: Label = null
var neighbor_gift_btn: Button = null
var neighbor_request_btn: Button = null
var current_ui_npc: NPCController = null

const REQUEST_TEMPLATES: Dictionary = {
	"chu_ba": {
		"id": "req_chu_ba_repair",
		"npc_id": "chu_ba",
		"title": "Phụ giúp Tiệm Sửa Xe",
		"desc": "Hoàn thành 1 đơn sửa xe máy tại Tiệm Sửa Xe",
		"type": "garage_repair",
		"target": 1,
		"reward_money": 12000,
		"reward_affection": 15
	},
	"co_bay": {
		"id": "req_co_bay_noodle",
		"npc_id": "co_bay",
		"title": "Tô Hủ Tiếu Nam Vang",
		"desc": "Phục vụ 1 tô Hủ tiếu Nam Vang tại Quán Hủ Tiếu",
		"type": "hutieu_dish",
		"dish_title": "Hủ tiếu Nam Vang",
		"target": 1,
		"reward_money": 15000,
		"reward_affection": 15
	},
	"chi_lan": {
		"id": "req_chi_lan_veggie",
		"npc_id": "chi_lan",
		"title": "Rau Sạch Vườn Nhà",
		"desc": "Mang tặng Chị Lan 2 rau tươi thu hoạch từ vườn",
		"type": "deliver_veggie",
		"target": 2,
		"reward_money": 18000,
		"reward_affection": 15
	},
	"anh_tuan": {
		"id": "req_anh_tuan_serve",
		"npc_id": "anh_tuan",
		"title": "Nhịp Sống Xóm Nhỏ",
		"desc": "Phục vụ 2 khách hàng tại tiệm sửa xe hoặc quán hủ tiếu",
		"type": "serve_any",
		"target": 2,
		"reward_money": 15000,
		"reward_affection": 15
	}
}

func _ready() -> void:
	add_to_group("npc_manager")
	if not is_instance_valid(time_manager):
		time_manager = get_node_or_null("../TimeManager") as NeighborhoodTimeManager
	if is_instance_valid(time_manager):
		time_manager.hour_ticked.connect(_on_hour_ticked)
		time_manager.period_changed.connect(_on_period_changed)
		time_manager.time_updated.connect(_on_time_updated)

	_build_neighbor_ui()
	call_deferred("spawn_all_default_npcs")
	call_deferred("_discover_economy_and_businesses")

func _discover_economy_and_businesses() -> void:
	var econ := get_tree().get_first_node_in_group("economy_manager") as EconomyManager
	if is_instance_valid(econ):
		var saved := EconomySaveSystem.load_relationship_data(econ.save_file_path)
		if not saved.is_empty():
			apply_save_data(saved)

	var garage := get_tree().get_first_node_in_group("garage_business") as GarageBusiness
	if is_instance_valid(garage) and not garage.order_completed.is_connected(_on_business_order_completed):
		garage.order_completed.connect(_on_business_order_completed)

	var hutieu := get_tree().get_first_node_in_group("hutieu_business") as HuTieuBusiness
	if is_instance_valid(hutieu) and not hutieu.order_completed.is_connected(_on_business_order_completed):
		hutieu.order_completed.connect(_on_business_order_completed)

	var loop_mgr := get_tree().get_first_node_in_group("daily_loop_manager") as DailyLoopManager
	if is_instance_valid(loop_mgr) and not loop_mgr.day_advanced.is_connected(_on_day_advanced):
		loop_mgr.day_advanced.connect(_on_day_advanced)

func _get_current_day() -> int:
	if is_inside_tree():
		var loop_mgr := get_tree().get_first_node_in_group("daily_loop_manager")
		if is_instance_valid(loop_mgr) and "current_day" in loop_mgr:
			return int(loop_mgr.current_day)
		if is_instance_valid(time_manager):
			return time_manager.current_day
	return 1

func spawn_all_default_npcs() -> void:
	var database := NPCData.create_default_database()
	var current_hour := 8.0
	if is_instance_valid(time_manager):
		current_hour = time_manager.current_hour
	for data in database:
		var schedule_entry := data.get_schedule_for_hour(current_hour)
		var spawn_pos: Vector3 = schedule_entry.get("position", data.home_position)
		spawn_npc(data, spawn_pos, schedule_entry)

func spawn_npc(data: NPCData, spawn_pos: Vector3, initial_schedule: Dictionary = {}) -> NPCController:
	if npcs.has(data.id) and is_instance_valid(npcs[data.id]):
		return npcs[data.id]
	var npc := NPCController.new(data)
	npc.name = "NPC_" + data.id.to_pascal_case()
	npc.position = spawn_pos
	add_child(npc)
	npcs[data.id] = npc
	if not initial_schedule.is_empty():
		_schedule_keys[data.id] = _schedule_key(initial_schedule)
		npc.apply_schedule_entry(initial_schedule, true)
	npc_spawned.emit(npc)
	return npc

func get_npc(id: String) -> NPCController:
	if npcs.has(id) and is_instance_valid(npcs[id]):
		return npcs[id]
	return null

func get_all_npcs() -> Array[NPCController]:
	var list: Array[NPCController] = []
	for npc in npcs.values():
		if is_instance_valid(npc):
			list.append(npc)
	return list

# -----------------------------------------------------------------
# Relationship Score & Perks (Part A)
# -----------------------------------------------------------------
func get_relationship_score(npc_id: String) -> int:
	return clampi(int(relationships.get(npc_id, 0)), 0, 100)

static func get_relationship_level_name(score: int) -> String:
	if score >= 80:
		return "Bạn thân"
	if score >= 50:
		return "Bạn bè"
	if score >= 20:
		return "Quen biết"
	return "Người lạ"

func get_shop_discount_rate() -> float:
	# Close Friends (>= 80) with Chú Ba or Cô Bảy provide a modest 10% shop discount
	if get_relationship_score("chu_ba") >= 80 or get_relationship_score("co_bay") >= 80:
		return 0.10
	return 0.0

func add_relationship(npc_id: String, amount: int, source: String = "talk") -> int:
	if npc_id == "" or amount <= 0:
		return 0
	var day := _get_current_day()
	if source == "talk":
		if int(talked_day.get(npc_id, 0)) == day:
			return 0 # Prevent repetitive dialogue farming
		talked_day[npc_id] = day
	elif source == "serve":
		var rec: Dictionary = served_today_counts.get(npc_id, {"day": day, "count": 0})
		if int(rec.get("day", 0)) != day:
			rec = {"day": day, "count": 0}
		if int(rec.get("count", 0)) >= 2:
			return 0 # Cap 2 service gains per NPC per day
		rec["count"] = int(rec.get("count", 0)) + 1
		served_today_counts[npc_id] = rec
	elif source == "gift":
		if int(gifted_day.get(npc_id, 0)) == day:
			return 0
		gifted_day[npc_id] = day

	var old_score := get_relationship_score(npc_id)
	var new_score := clampi(old_score + amount, 0, 100)
	relationships[npc_id] = new_score
	var level_name := get_relationship_level_name(new_score)
	if new_score != old_score:
		relationship_changed.emit(npc_id, new_score, level_name)
	_maybe_grant_friend_gift(npc_id, new_score, day)
	_save_relationships()
	return new_score - old_score

func _maybe_grant_friend_gift(npc_id: String, score: int, day: int) -> void:
	if score < 50:
		return
	var last_day := int(last_npc_gift_day.get(npc_id, -99))
	if day - last_day < 3:
		return # Max once every 3 days per NPC
	last_npc_gift_day[npc_id] = day
	var econ := get_tree().get_first_node_in_group("economy_manager") as EconomyManager if is_inside_tree() else null
	if is_instance_valid(econ) and is_instance_valid(econ.wallet):
		var tx_id := "npc_gift_%s_day_%d" % [npc_id, day]
		econ.wallet.deposit(5000, "neighbor_gift", "Quà tri ân từ hàng xóm", tx_id)
		var fx = get_tree().get_first_node_in_group("chaos_feedback")
		if is_instance_valid(fx) and fx.has_method("show_toast"):
			fx.show_toast("🎁 Hàng xóm gửi tặng 5,000 đ vì tình cảm gắn bó!")

func give_vegetable_gift(npc_id: String) -> bool:
	var day := _get_current_day()
	if int(gifted_day.get(npc_id, 0)) == day:
		return false
	var econ := get_tree().get_first_node_in_group("economy_manager") as EconomyManager if is_inside_tree() else null
	if not is_instance_valid(econ) or not is_instance_valid(econ.inventory):
		return false
	var veg_id := ""
	for candidate in ["produce_lettuce", "produce_carrot", "produce_tomato"]:
		if econ.inventory.get_item_count(candidate) > 0:
			veg_id = candidate
			break
	if veg_id == "" or not econ.inventory.remove_item(veg_id, 1):
		return false
	add_relationship(npc_id, 10, "gift")
	if econ.auto_save_on_change:
		econ.save_economy_state()
	return true

# -----------------------------------------------------------------
# Neighbor Requests (Part B)
# -----------------------------------------------------------------
func ensure_request_for_npc(npc_id: String) -> Dictionary:
	if active_requests.has(npc_id):
		return active_requests[npc_id]
	if not REQUEST_TEMPLATES.has(npc_id):
		return {}
	var tpl: Dictionary = REQUEST_TEMPLATES[npc_id]
	if completed_request_ids.has(tpl["id"]):
		return {}
	var req := tpl.duplicate(true)
	req["current"] = 0
	req["is_completed"] = false
	req["claimed"] = false
	active_requests[npc_id] = req
	return req

func _on_business_order_completed(order: BusinessOrder, _reward: int) -> void:
	# Match named customer to NPC ID if possible
	if is_instance_valid(order):
		var cname := order.customer_name
		for npc_id in ["chu_ba", "co_bay", "anh_tuan", "chi_lan", "bac_nam", "co_mai"]:
			var npc := get_npc(npc_id)
			if npc and npc.data and cname.find(npc.data.name) != -1:
				add_relationship(npc_id, 6, "serve")
				break

	# Advance active neighbor requests
	for npc_id in active_requests.keys():
		var req: Dictionary = active_requests[npc_id]
		if req.get("is_completed", false):
			continue
		var rtype := String(req.get("type", ""))
		var matched := false
		if rtype == "garage_repair" and is_instance_valid(order) and order.service_type != "" and not order.service_type.begins_with("noodle_"):
			matched = true
		elif rtype == "hutieu_dish" and is_instance_valid(order) and order.service_title == String(req.get("dish_title", "")):
			matched = true
		elif rtype == "serve_any":
			matched = true
		if matched:
			req["current"] = mini(int(req["target"]), int(req.get("current", 0)) + 1)
			if req["current"] >= int(req["target"]):
				complete_neighbor_request(npc_id)

func complete_neighbor_request(npc_id: String) -> bool:
	if not active_requests.has(npc_id):
		return false
	var req: Dictionary = active_requests[npc_id]
	if req.get("claimed", false) or completed_request_ids.has(req["id"]):
		return false

	if req.get("type", "") == "deliver_veggie":
		var econ := get_tree().get_first_node_in_group("economy_manager") as EconomyManager if is_inside_tree() else null
		if not is_instance_valid(econ) or not is_instance_valid(econ.inventory):
			return false
		var needed: int = int(req.get("target", 2))
		var total_veg := 0
		for v in ["produce_lettuce", "produce_carrot", "produce_tomato"]:
			total_veg += econ.inventory.get_item_count(v)
		if total_veg < needed:
			return false
		var remaining := needed
		for v in ["produce_lettuce", "produce_carrot", "produce_tomato"]:
			if remaining <= 0:
				break
			var have := econ.inventory.get_item_count(v)
			if have > 0:
				var take := mini(have, remaining)
				econ.inventory.remove_item(v, take)
				remaining -= take

	req["current"] = int(req["target"])
	req["is_completed"] = true
	req["claimed"] = true
	completed_request_ids[req["id"]] = true
	active_requests.erase(npc_id)

	var reward_money: int = int(req.get("reward_money", 0))
	var econ := get_tree().get_first_node_in_group("economy_manager") as EconomyManager if is_inside_tree() else null
	if is_instance_valid(econ) and is_instance_valid(econ.wallet) and reward_money > 0:
		econ.wallet.deposit(reward_money, "neighbor_request", "Thưởng nhờ vả: %s" % req["title"], "req_%s" % req["id"])
	add_relationship(npc_id, int(req.get("reward_affection", 15)), "request")
	request_completed.emit(req["id"], npc_id, reward_money)

	var fx = get_tree().get_first_node_in_group("chaos_feedback") if is_inside_tree() else null
	if is_instance_valid(fx) and fx.has_method("show_toast"):
		fx.show_toast("🤝 Hoàn thành nhờ vả '%s'! +%s đ" % [req["title"], HouseholdWallet.format_money(reward_money)])
	_save_relationships()
	return true

# -----------------------------------------------------------------
# Clean Neighbor Card UI (Part E)
# -----------------------------------------------------------------
func _build_neighbor_ui() -> void:
	neighbor_ui_layer = CanvasLayer.new()
	neighbor_ui_layer.name = "NeighborCardLayer"
	neighbor_ui_layer.layer = 90
	neighbor_ui_layer.visible = false
	add_child(neighbor_ui_layer)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -240
	panel.offset_right = 240
	panel.offset_top = -220
	panel.offset_bottom = -28
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1d2630", 0.94)
	style.border_color = Color("ffd54f")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	neighbor_ui_layer.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var top := HBoxContainer.new()
	vbox.add_child(top)
	neighbor_name_label = Label.new()
	neighbor_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	neighbor_name_label.add_theme_font_size_override("font_size", 16)
	neighbor_name_label.add_theme_color_override("font_color", Color("ffd54f"))
	top.add_child(neighbor_name_label)
	neighbor_level_label = Label.new()
	neighbor_level_label.add_theme_font_size_override("font_size", 13)
	neighbor_level_label.add_theme_color_override("font_color", Color("80d8ff"))
	top.add_child(neighbor_level_label)

	neighbor_dialogue_label = Label.new()
	neighbor_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	neighbor_dialogue_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(neighbor_dialogue_label)

	neighbor_request_label = Label.new()
	neighbor_request_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	neighbor_request_label.add_theme_font_size_override("font_size", 12)
	neighbor_request_label.add_theme_color_override("font_color", Color("b9f6ca"))
	vbox.add_child(neighbor_request_label)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	vbox.add_child(btns)
	neighbor_gift_btn = Button.new()
	neighbor_gift_btn.text = "🎁 Tặng rau (+10)"
	neighbor_gift_btn.pressed.connect(func():
		if is_instance_valid(current_ui_npc) and current_ui_npc.data:
			give_vegetable_gift(current_ui_npc.data.id)
			show_neighbor_card(current_ui_npc, neighbor_dialogue_label.text)
	)
	btns.add_child(neighbor_gift_btn)

	neighbor_request_btn = Button.new()
	neighbor_request_btn.text = "🤝 Giao đồ nhờ vả"
	neighbor_request_btn.pressed.connect(func():
		if is_instance_valid(current_ui_npc) and current_ui_npc.data:
			complete_neighbor_request(current_ui_npc.data.id)
			show_neighbor_card(current_ui_npc, neighbor_dialogue_label.text)
	)
	btns.add_child(neighbor_request_btn)

	var close_btn := Button.new()
	close_btn.text = "Đóng"
	close_btn.pressed.connect(func():
		if is_instance_valid(current_ui_npc):
			current_ui_npc.end_interaction()
		hide_neighbor_card()
	)
	btns.add_child(close_btn)

func show_neighbor_card(npc: NPCController, dialogue_text: String) -> void:
	if not is_instance_valid(neighbor_ui_layer) or not is_instance_valid(npc) or not npc.data:
		return
	current_ui_npc = npc
	var npc_id := npc.data.id
	var score := get_relationship_score(npc_id)
	var lvl_name := get_relationship_level_name(score)
	neighbor_name_label.text = "%s (%s)" % [npc.data.name, npc.data.role]
	neighbor_level_label.text = "💛 %s (%d/100)" % [lvl_name, score]
	neighbor_dialogue_label.text = "“%s”" % dialogue_text

	var req := ensure_request_for_npc(npc_id)
	if req.is_empty():
		neighbor_request_label.text = "Không có nhờ vả mới."
		neighbor_request_btn.visible = false
	else:
		neighbor_request_label.text = "📌 Nhờ vả: %s (%d/%d) · Thưởng +%s đ" % [
			req["desc"], int(req.get("current", 0)), int(req.get("target", 1)),
			HouseholdWallet.format_money(int(req.get("reward_money", 0)))
		]
		neighbor_request_btn.visible = (req.get("type", "") == "deliver_veggie")

	neighbor_gift_btn.disabled = (int(gifted_day.get(npc_id, 0)) == _get_current_day())
	neighbor_ui_layer.visible = true

func hide_neighbor_card() -> void:
	if is_instance_valid(neighbor_ui_layer):
		neighbor_ui_layer.visible = false
	current_ui_npc = null

# -----------------------------------------------------------------
# Schedules & Persistence
# -----------------------------------------------------------------
func _on_day_advanced(_new_day: int) -> void:
	pass

func _on_hour_ticked(hour: int) -> void:
	_update_all_schedules(float(hour))

func _on_period_changed(_new_period: String) -> void:
	if is_instance_valid(time_manager):
		_update_all_schedules(time_manager.current_hour)

func _on_time_updated(hour: float) -> void:
	var slot := int(floor(hour * 4.0))
	if slot == _last_schedule_slot:
		return
	_last_schedule_slot = slot
	_update_all_schedules(hour)

func _schedule_key(entry: Dictionary) -> String:
	return "%s|%s|%s|%s" % [entry.get("start_hour", 0.0), entry.get("end_hour", 24.0), entry.get("activity", ""), entry.get("position", Vector3.ZERO)]

func _update_all_schedules(hour: float) -> void:
	for id in npcs:
		var npc: NPCController = npcs[id]
		if not is_instance_valid(npc) or not npc.data: continue
		var entry := npc.data.get_schedule_for_hour(hour)
		var key := _schedule_key(entry)
		if _schedule_keys.get(id, "") == key:
			continue
		_schedule_keys[id] = key
		npc.apply_schedule_entry(entry, false)

func set_time_of_day(hour: float, force_teleport := false) -> void:
	if is_instance_valid(time_manager):
		time_manager.set_hour(hour)
	for id in npcs:
		var npc: NPCController = npcs[id]
		if not is_instance_valid(npc) or not npc.data: continue
		var entry := npc.data.get_schedule_for_hour(time_manager.current_hour if is_instance_valid(time_manager) else hour)
		npc.apply_schedule_entry(entry, force_teleport)

func _save_relationships() -> void:
	if not is_inside_tree():
		return
	var econ := get_tree().get_first_node_in_group("economy_manager") as EconomyManager
	if is_instance_valid(econ) and econ.auto_save_on_change:
		econ.save_economy_state()

func get_save_data() -> Dictionary:
	return {
		"relationships": relationships.duplicate(true),
		"talked_day": talked_day.duplicate(true),
		"served_today_counts": served_today_counts.duplicate(true),
		"gifted_day": gifted_day.duplicate(true),
		"last_npc_gift_day": last_npc_gift_day.duplicate(true),
		"active_requests": active_requests.duplicate(true),
		"completed_request_ids": completed_request_ids.duplicate(true)
	}

func apply_save_data(data: Dictionary) -> void:
	if data.is_empty():
		return
	if data.get("relationships", null) is Dictionary:
		relationships = data["relationships"].duplicate(true)
	if data.get("talked_day", null) is Dictionary:
		talked_day = data["talked_day"].duplicate(true)
	if data.get("served_today_counts", null) is Dictionary:
		served_today_counts = data["served_today_counts"].duplicate(true)
	if data.get("gifted_day", null) is Dictionary:
		gifted_day = data["gifted_day"].duplicate(true)
	if data.get("last_npc_gift_day", null) is Dictionary:
		last_npc_gift_day = data["last_npc_gift_day"].duplicate(true)
	if data.get("completed_request_ids", null) is Dictionary:
		completed_request_ids = data["completed_request_ids"].duplicate(true)
	if data.get("active_requests", null) is Dictionary:
		active_requests.clear()
		for k in data["active_requests"]:
			var req: Dictionary = data["active_requests"][k]
			if req is Dictionary and not completed_request_ids.has(req.get("id", "")):
				active_requests[k] = req.duplicate(true)
