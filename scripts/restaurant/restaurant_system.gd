class_name RestaurantSystem
extends RefCounted
## Manages the unlockable Hu Tieu Restaurant: menu, kitchen queue, customers, and upgrades.

signal restaurant_changed()

const NORMAL_NAMES := ["Anh Minh", "Chị Lan", "Bé Na", "Anh Tuấn", "Cô Mai", "Bác Hùng"]

var unlock_level: int = 2
var unlock_cost: int = 100
var initial_kitchen_slots: int = 1
var max_kitchen_slots: int = 4
var kitchen_upgrade_base_cost: int = 120
var kitchen_upgrade_cost_step: int = 100
var initial_table_slots: int = 2
var max_table_slots: int = 5
var table_upgrade_base_cost: int = 90
var table_upgrade_cost_step: int = 90

var dishes_by_id: Dictionary = {}
var dish_ids_sorted: Array[String] = []
var starter_dishes: Array[String] = []
var special_customers_cfg: Array[Dictionary] = []

# Persistent state
var is_unlocked: bool = false
var kitchen_slots: int = 1
var table_slots: int = 2
var unlocked_dishes: Dictionary = {}
var special_served_ids: Dictionary = {}
var customers: Array[Dictionary] = []
var cooking_queue: Array[Dictionary] = []
var served_count: int = 0
var _next_seq: int = 0

func _init(cfg: Dictionary = {}) -> void:
	apply_config(cfg)
	reset()

func apply_config(cfg: Dictionary) -> void:
	unlock_level = maxi(1, int(cfg.get("unlock_level", 2)))
	unlock_cost = maxi(0, int(cfg.get("unlock_cost", 100)))
	initial_kitchen_slots = maxi(1, int(cfg.get("initial_kitchen_slots", 1)))
	max_kitchen_slots = maxi(initial_kitchen_slots, int(cfg.get("max_kitchen_slots", 4)))
	kitchen_upgrade_base_cost = maxi(10, int(cfg.get("kitchen_upgrade_base_cost", 120)))
	kitchen_upgrade_cost_step = maxi(0, int(cfg.get("kitchen_upgrade_cost_step", 100)))
	initial_table_slots = maxi(1, int(cfg.get("initial_table_slots", 2)))
	max_table_slots = maxi(initial_table_slots, int(cfg.get("max_table_slots", 5)))
	table_upgrade_base_cost = maxi(10, int(cfg.get("table_upgrade_base_cost", 90)))
	table_upgrade_cost_step = maxi(0, int(cfg.get("table_upgrade_cost_step", 90)))

	starter_dishes.clear()
	var raw_starters: Variant = cfg.get("starter_dishes", ["hu_tieu_chay", "hu_tieu_toi"])
	if typeof(raw_starters) == TYPE_ARRAY:
		for s in (raw_starters as Array):
			starter_dishes.append(String(s))

	dishes_by_id.clear()
	dish_ids_sorted.clear()
	var raw_dishes: Variant = cfg.get("dishes", [])
	if typeof(raw_dishes) == TYPE_ARRAY:
		for entry in (raw_dishes as Array):
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var d := (entry as Dictionary).duplicate(true)
			var did := String(d.get("id", ""))
			if did != "":
				dishes_by_id[did] = d
				dish_ids_sorted.append(did)

	special_customers_cfg.clear()
	var raw_spec: Variant = cfg.get("special_customers", [])
	if typeof(raw_spec) == TYPE_ARRAY:
		for entry in (raw_spec as Array):
			if typeof(entry) == TYPE_DICTIONARY:
				special_customers_cfg.append((entry as Dictionary).duplicate(true))

func reset() -> void:
	is_unlocked = false
	kitchen_slots = initial_kitchen_slots
	table_slots = initial_table_slots
	unlocked_dishes.clear()
	for did in starter_dishes:
		if dishes_by_id.has(did):
			unlocked_dishes[did] = true
	special_served_ids.clear()
	customers.clear()
	cooking_queue.clear()
	served_count = 0
	_next_seq = 0
	restaurant_changed.emit()

func can_unlock_restaurant(wallet: Wallet, player_level: int) -> Dictionary:
	if is_unlocked:
		return {"ok": false, "reason": "Quán Hủ Tiếu đã mở."}
	if player_level < unlock_level:
		return {"ok": false, "reason": "Cần đạt Level %d để mở Quán Hủ Tiếu." % unlock_level}
	if not wallet.can_afford(unlock_cost):
		return {"ok": false, "reason": "Cần %d xu để mở Quán Hủ Tiếu." % unlock_cost}
	return {"ok": true}

func unlock_restaurant(wallet: Wallet, player_level: int) -> Dictionary:
	var chk := can_unlock_restaurant(wallet, player_level)
	if not bool(chk.get("ok", false)):
		return chk
	if not wallet.spend(unlock_cost):
		return {"ok": false, "reason": "Không thể trừ xu."}
	is_unlocked = true
	ensure_customers(player_level)
	restaurant_changed.emit()
	return {"ok": true, "cost": unlock_cost}

func ensure_customers(player_level: int) -> void:
	if not is_unlocked:
		return
	while customers.size() < table_slots:
		customers.append(_spawn_customer(player_level))

func _spawn_customer(player_level: int) -> Dictionary:
	_next_seq += 1
	# Check if an eligible special customer is not yet served or already waiting
	for sc in special_customers_cfg:
		var sid := String(sc.get("id", ""))
		if special_served_ids.has(sid):
			continue
		var already_waiting := false
		for c in customers:
			if String(c.get("special_id", "")) == sid:
				already_waiting = true
				break
		if already_waiting:
			continue
		if served_count >= int(sc.get("requires_min_served", 0)) and player_level >= int(sc.get("requires_level", 1)):
			var req_dish := String(sc.get("dish_id", "hu_tieu_chay"))
			if unlocked_dishes.has(req_dish):
				return {
					"instance_id": "cust_%d" % _next_seq,
					"special_id": sid,
					"name": String(sc.get("name", "Khách Đặc Biệt")),
					"type": "special",
					"dish_id": req_dish,
					"unlocks_dish": String(sc.get("unlocks_dish", ""))
				}

	var pool: Array[String] = []
	for did in dish_ids_sorted:
		if unlocked_dishes.has(did):
			pool.append(did)
	if pool.is_empty():
		pool.append("hu_tieu_chay")
	var chosen_dish := pool[_next_seq % pool.size()]
	return {
		"instance_id": "cust_%d" % _next_seq,
		"special_id": "",
		"name": NORMAL_NAMES[_next_seq % NORMAL_NAMES.size()],
		"type": "normal",
		"dish_id": chosen_dish,
		"unlocks_dish": ""
	}

func get_dish(dish_id: String) -> Dictionary:
	return dishes_by_id.get(dish_id, {}) as Dictionary

func can_cook(dish_id: String, inventory: Inventory) -> Dictionary:
	if not is_unlocked:
		return {"ok": false, "reason": "Quán Hủ Tiếu chưa mở khóa."}
	if not unlocked_dishes.has(dish_id) or not dishes_by_id.has(dish_id):
		return {"ok": false, "reason": "Món ăn chưa được mở khóa."}
	if cooking_queue.size() >= kitchen_slots:
		return {"ok": false, "reason": "Bếp đang bận (%d/%d)." % [cooking_queue.size(), kitchen_slots]}
	var d := dishes_by_id[dish_id] as Dictionary
	var inputs: Dictionary = d.get("inputs", {}) as Dictionary
	if inputs.is_empty():
		return {"ok": false, "reason": "Công thức món không hợp lệ."}
	for item_id in inputs.keys():
		var need := maxi(1, int(inputs[item_id]))
		if not inventory.has_item(String(item_id), need):
			return {"ok": false, "reason": "Thiếu nguyên liệu: %s (cần %d)." % [String(item_id), need]}
	return {"ok": true}

func start_cook(dish_id: String, inventory: Inventory, clock: GameClock) -> Dictionary:
	var chk := can_cook(dish_id, inventory)
	if not bool(chk.get("ok", false)):
		return chk
	var d := dishes_by_id[dish_id] as Dictionary
	var inputs: Dictionary = d.get("inputs", {}) as Dictionary
	for item_id in inputs.keys():
		var need := maxi(1, int(inputs[item_id]))
		if not inventory.remove_item(String(item_id), need):
			return {"ok": false, "reason": "Lỗi trừ nguyên liệu."}

	_next_seq += 1
	var job := {
		"job_id": "cook_%d" % _next_seq,
		"dish_id": dish_id,
		"display_name": String(d.get("display_name", dish_id)),
		"started_at_unix": clock.now(),
		"duration_sec": maxi(1, int(d.get("cook_duration_sec", 8))),
		"status": "COOKING"
	}
	cooking_queue.append(job)
	restaurant_changed.emit()
	return {"ok": true, "job": job}

func tick(clock: GameClock) -> int:
	if not is_unlocked or clock == null or cooking_queue.is_empty():
		return 0
	var now_unix := clock.now()
	var finished := 0
	for job in cooking_queue:
		if String(job.get("status", "")) == "COOKING":
			var started := int(job.get("started_at_unix", 0))
			var dur := maxi(1, int(job.get("duration_sec", 8)))
			if started > 0 and now_unix >= started + dur:
				job["status"] = "READY"
				finished += 1
	if finished > 0:
		restaurant_changed.emit()
	return finished

func find_ready_dish_idx(dish_id: String) -> int:
	for i in range(cooking_queue.size()):
		var job := cooking_queue[i]
		if String(job.get("status", "")) == "READY" and String(job.get("dish_id", "")) == dish_id:
			return i
	return -1

func serve_customer(cust_idx: int, wallet: Wallet, progression: ProgressionSystem) -> Dictionary:
	if not is_unlocked:
		return {"ok": false, "reason": "Quán Hủ Tiếu chưa mở khóa."}
	if cust_idx < 0 or cust_idx >= customers.size():
		return {"ok": false, "reason": "Khách hàng không tồn tại."}
	var cust := customers[cust_idx]
	var dish_id := String(cust.get("dish_id", ""))
	var ready_idx := find_ready_dish_idx(dish_id)
	if ready_idx == -1:
		return {"ok": false, "reason": "Chưa có món '%s' nấu xong để phục vụ." % String(get_dish(dish_id).get("display_name", dish_id))}

	# Atomic removal of cooked dish and customer before granting rewards.
	cooking_queue.remove_at(ready_idx)
	var cust_name := String(cust.get("name", "Khách"))
	var special_id := String(cust.get("special_id", ""))
	var unlocks_dish := String(cust.get("unlocks_dish", ""))
	customers.remove_at(cust_idx)
	served_count += 1

	var d := get_dish(dish_id)
	var coins := maxi(0, int(d.get("reward_coins", 50)))
	var xp := maxi(0, int(d.get("reward_xp", 25)))
	wallet.earn(coins)
	var prog_res := {"leveled_up": false, "new_level": 1, "new_unlocks": []}
	if progression != null:
		prog_res = progression.add_xp(xp)

	var newly_unlocked_dish := ""
	if special_id != "":
		special_served_ids[special_id] = true
		if unlocks_dish != "" and dishes_by_id.has(unlocks_dish) and not unlocked_dishes.has(unlocks_dish):
			unlocked_dishes[unlocks_dish] = true
			newly_unlocked_dish = unlocks_dish

	var lv := progression.level if progression != null else 1
	ensure_customers(lv)
	restaurant_changed.emit()
	return {
		"ok": true,
		"customer_name": cust_name,
		"dish_name": String(d.get("display_name", dish_id)),
		"reward_coins": coins,
		"reward_xp": xp,
		"unlocked_dish": newly_unlocked_dish,
		"leveled_up": bool(prog_res.get("leveled_up", false)),
		"new_level": int(prog_res.get("new_level", lv)),
		"new_unlocks": prog_res.get("new_unlocks", [])
	}

func dismiss_customer(cust_idx: int, player_level: int) -> Dictionary:
	if not is_unlocked or cust_idx < 0 or cust_idx >= customers.size():
		return {"ok": false, "reason": "Không thể đổi khách."}
	customers.remove_at(cust_idx)
	ensure_customers(player_level)
	restaurant_changed.emit()
	return {"ok": true}

func get_next_kitchen_upgrade_cost() -> int:
	var done := maxi(0, kitchen_slots - initial_kitchen_slots)
	return kitchen_upgrade_base_cost + done * kitchen_upgrade_cost_step

func upgrade_kitchen(wallet: Wallet) -> Dictionary:
	if not is_unlocked:
		return {"ok": false, "reason": "Hãy mở Quán Hủ Tiếu trước."}
	if kitchen_slots >= max_kitchen_slots:
		return {"ok": false, "reason": "Bếp đã đạt tối đa (%d)." % max_kitchen_slots}
	var cost := get_next_kitchen_upgrade_cost()
	if not wallet.can_afford(cost) or not wallet.spend(cost):
		return {"ok": false, "reason": "Không đủ xu nâng cấp bếp (cần %d xu)." % cost}
	kitchen_slots += 1
	restaurant_changed.emit()
	return {"ok": true, "cost": cost, "new_kitchen_slots": kitchen_slots}

func get_next_table_upgrade_cost() -> int:
	var done := maxi(0, table_slots - initial_table_slots)
	return table_upgrade_base_cost + done * table_upgrade_cost_step

func upgrade_tables(wallet: Wallet, player_level: int) -> Dictionary:
	if not is_unlocked:
		return {"ok": false, "reason": "Hãy mở Quán Hủ Tiếu trước."}
	if table_slots >= max_table_slots:
		return {"ok": false, "reason": "Số bàn đã đạt tối đa (%d)." % max_table_slots}
	var cost := get_next_table_upgrade_cost()
	if not wallet.can_afford(cost) or not wallet.spend(cost):
		return {"ok": false, "reason": "Không đủ xu mở thêm bàn (cần %d xu)." % cost}
	table_slots += 1
	ensure_customers(player_level)
	restaurant_changed.emit()
	return {"ok": true, "cost": cost, "new_table_slots": table_slots}

func to_dict() -> Dictionary:
	var u_dishes: Array[String] = []
	for k in unlocked_dishes.keys():
		u_dishes.append(String(k))
	var s_ids: Array[String] = []
	for k in special_served_ids.keys():
		s_ids.append(String(k))
	return {
		"is_unlocked": is_unlocked,
		"kitchen_slots": kitchen_slots,
		"table_slots": table_slots,
		"unlocked_dishes": u_dishes,
		"special_served_ids": s_ids,
		"customers": customers.duplicate(true),
		"cooking_queue": cooking_queue.duplicate(true),
		"served_count": served_count,
		"next_seq": _next_seq
	}

func load_from_dict(d: Dictionary, player_level: int, clock: GameClock = null) -> void:
	is_unlocked = bool(d.get("is_unlocked", false))
	kitchen_slots = clampi(int(d.get("kitchen_slots", initial_kitchen_slots)), initial_kitchen_slots, max_kitchen_slots)
	table_slots = clampi(int(d.get("table_slots", initial_table_slots)), initial_table_slots, max_table_slots)
	served_count = maxi(0, int(d.get("served_count", 0)))
	_next_seq = maxi(0, int(d.get("next_seq", 0)))

	unlocked_dishes.clear()
	var raw_ud: Variant = d.get("unlocked_dishes", starter_dishes)
	if typeof(raw_ud) == TYPE_ARRAY:
		for item in (raw_ud as Array):
			var did := String(item)
			if dishes_by_id.has(did):
				unlocked_dishes[did] = true
	for s in starter_dishes:
		if dishes_by_id.has(s):
			unlocked_dishes[s] = true

	special_served_ids.clear()
	var raw_ss: Variant = d.get("special_served_ids", [])
	if typeof(raw_ss) == TYPE_ARRAY:
		for item in (raw_ss as Array):
			special_served_ids[String(item)] = true

	customers.clear()
	var raw_c: Variant = d.get("customers", [])
	if typeof(raw_c) == TYPE_ARRAY:
		for entry in (raw_c as Array):
			if typeof(entry) == TYPE_DICTIONARY:
				customers.append((entry as Dictionary).duplicate(true))

	cooking_queue.clear()
	var raw_q: Variant = d.get("cooking_queue", [])
	if typeof(raw_q) == TYPE_ARRAY:
		for entry in (raw_q as Array):
			if typeof(entry) == TYPE_DICTIONARY:
				cooking_queue.append((entry as Dictionary).duplicate(true))

	if is_unlocked:
		ensure_customers(player_level)
	if clock != null:
		tick(clock)
	restaurant_changed.emit()
