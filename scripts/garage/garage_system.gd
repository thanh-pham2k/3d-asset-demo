class_name GarageSystem
extends RefCounted
## Manages the unlockable Garage, vehicle repairs, delivery routes, speed/capacity upgrades, and special rewards.

signal garage_changed()

var unlock_level: int = 2
var unlock_cost: int = 120
var max_speed_level: int = 3
var speed_upgrade_costs: Array[int] = [90, 180]
var speed_multipliers: Array[float] = [1.0, 0.75, 0.55]
var max_capacity_level: int = 3
var capacity_upgrade_costs: Array[int] = [100, 200]
var capacity_slots: Array[int] = [1, 2, 3]

var vehicles_by_id: Dictionary = {}
var vehicle_ids_sorted: Array[String] = []
var routes_by_id: Dictionary = {}
var route_ids_sorted: Array[String] = []

# Persistent state
var is_unlocked: bool = false
var repaired_vehicles: Dictionary = {} # vehicle_id -> true
var speed_level: int = 1
var capacity_level: int = 1
var active_deliveries: Array[Dictionary] = []
var claimed_route_rewards: Dictionary = {} # route_id -> true
var auto_dispatch_enabled: bool = false
var auto_route_id: String = "route_market"
var delivered_count: int = 0
var _next_seq: int = 0

func _init(cfg: Dictionary = {}) -> void:
	apply_config(cfg)
	reset()

func apply_config(cfg: Dictionary) -> void:
	unlock_level = maxi(1, int(cfg.get("unlock_level", 2)))
	unlock_cost = maxi(0, int(cfg.get("unlock_cost", 120)))
	max_speed_level = maxi(1, int(cfg.get("max_speed_level", 3)))
	max_capacity_level = maxi(1, int(cfg.get("max_capacity_level", 3)))

	speed_upgrade_costs.clear()
	for c in (cfg.get("speed_upgrade_costs", [90, 180]) as Array):
		speed_upgrade_costs.append(int(c))
	speed_multipliers.clear()
	for m in (cfg.get("speed_multipliers", [1.0, 0.75, 0.55]) as Array):
		speed_multipliers.append(float(m))

	capacity_upgrade_costs.clear()
	for c in (cfg.get("capacity_upgrade_costs", [100, 200]) as Array):
		capacity_upgrade_costs.append(int(c))
	capacity_slots.clear()
	for s in (cfg.get("capacity_slots", [1, 2, 3]) as Array):
		capacity_slots.append(int(s))

	vehicles_by_id.clear()
	vehicle_ids_sorted.clear()
	var raw_v: Variant = cfg.get("vehicles", [])
	if typeof(raw_v) == TYPE_ARRAY:
		for entry in (raw_v as Array):
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var v := (entry as Dictionary).duplicate(true)
			var vid := String(v.get("id", ""))
			if vid != "":
				vehicles_by_id[vid] = v
				vehicle_ids_sorted.append(vid)

	routes_by_id.clear()
	route_ids_sorted.clear()
	var raw_r: Variant = cfg.get("routes", [])
	if typeof(raw_r) == TYPE_ARRAY:
		for entry in (raw_r as Array):
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var r := (entry as Dictionary).duplicate(true)
			var rid := String(r.get("id", ""))
			if rid != "":
				routes_by_id[rid] = r
				route_ids_sorted.append(rid)

func reset() -> void:
	is_unlocked = false
	repaired_vehicles.clear()
	speed_level = 1
	capacity_level = 1
	active_deliveries.clear()
	claimed_route_rewards.clear()
	auto_dispatch_enabled = false
	auto_route_id = route_ids_sorted[0] if not route_ids_sorted.is_empty() else "route_market"
	delivered_count = 0
	_next_seq = 0
	garage_changed.emit()

func get_max_slots() -> int:
	var idx := clampi(capacity_level - 1, 0, capacity_slots.size() - 1)
	return maxi(1, capacity_slots[idx]) if not capacity_slots.is_empty() else 1

func get_speed_multiplier() -> float:
	var idx := clampi(speed_level - 1, 0, speed_multipliers.size() - 1)
	return speed_multipliers[idx] if not speed_multipliers.is_empty() else 1.0

func unlock(player_level: int, wallet: Wallet) -> Dictionary:
	if is_unlocked:
		return {"ok": false, "reason": "Ga-ra đã được mở khóa."}
	if player_level < unlock_level:
		return {"ok": false, "reason": "Cần đạt Lv.%d để mở Ga-ra." % unlock_level}
	if not wallet.spend(unlock_cost):
		return {"ok": false, "reason": "Không đủ xu (cần %d xu)." % unlock_cost}
	is_unlocked = true
	garage_changed.emit()
	return {"ok": true, "cost": unlock_cost}

func is_vehicle_repaired(vid: String) -> bool:
	return repaired_vehicles.has(vid)

func repair_vehicle(vid: String, player_level: int, wallet: Wallet, inventory: Inventory) -> Dictionary:
	if not is_unlocked:
		return {"ok": false, "reason": "Hãy mở khóa Ga-ra trước."}
	if not vehicles_by_id.has(vid):
		return {"ok": false, "reason": "Phương tiện không tồn tại."}
	if repaired_vehicles.has(vid):
		return {"ok": false, "reason": "Phương tiện này đã được sửa xong."}
	var v := vehicles_by_id[vid] as Dictionary
	var req_lv := int(v.get("min_level", 2))
	if player_level < req_lv:
		return {"ok": false, "reason": "Cần Lv.%d để sửa %s." % [req_lv, String(v.get("display_name", vid))]}

	var cost := maxi(0, int(v.get("repair_cost", 0)))
	var req_items := v.get("repair_items", {}) as Dictionary
	if not wallet.can_afford(cost):
		return {"ok": false, "reason": "Không đủ xu (cần %d xu)." % cost}
	for item_id: String in req_items.keys():
		if inventory.get_count(item_id) < int(req_items[item_id]):
			return {"ok": false, "reason": "Thiếu vật tư sửa xe (%s x%d)." % [item_id, int(req_items[item_id])]}

	# Atomic deduction
	if not wallet.spend(cost):
		return {"ok": false, "reason": "Không đủ xu."}
	for item_id: String in req_items.keys():
		if not inventory.remove_item(item_id, int(req_items[item_id])):
			wallet.earn(cost)
			return {"ok": false, "reason": "Lỗi trừ vật tư kho."}

	repaired_vehicles[vid] = true
	garage_changed.emit()
	return {"ok": true, "cost": cost, "vehicle_id": vid}

func get_next_speed_upgrade_cost() -> int:
	if speed_level >= max_speed_level:
		return -1
	var idx := speed_level - 1
	return speed_upgrade_costs[idx] if idx >= 0 and idx < speed_upgrade_costs.size() else 180

func upgrade_speed(wallet: Wallet) -> Dictionary:
	if not is_unlocked:
		return {"ok": false, "reason": "Hãy mở khóa Ga-ra trước."}
	var cost := get_next_speed_upgrade_cost()
	if cost < 0:
		return {"ok": false, "reason": "Tốc độ giao hàng đã đạt tối đa."}
	if not wallet.spend(cost):
		return {"ok": false, "reason": "Không đủ xu (cần %d xu)." % cost}
	speed_level += 1
	garage_changed.emit()
	return {"ok": true, "cost": cost, "new_level": speed_level}

func get_next_capacity_upgrade_cost() -> int:
	if capacity_level >= max_capacity_level:
		return -1
	var idx := capacity_level - 1
	return capacity_upgrade_costs[idx] if idx >= 0 and idx < capacity_upgrade_costs.size() else 200

func upgrade_capacity(wallet: Wallet) -> Dictionary:
	if not is_unlocked:
		return {"ok": false, "reason": "Hãy mở khóa Ga-ra trước."}
	var cost := get_next_capacity_upgrade_cost()
	if cost < 0:
		return {"ok": false, "reason": "Sức chứa đội xe đã đạt tối đa."}
	if not wallet.spend(cost):
		return {"ok": false, "reason": "Không đủ xu (cần %d xu)." % cost}
	capacity_level += 1
	garage_changed.emit()
	return {"ok": true, "cost": cost, "new_level": capacity_level}

func is_route_unlocked(rid: String, player_level: int) -> bool:
	if not is_unlocked or not routes_by_id.has(rid):
		return false
	var r := routes_by_id[rid] as Dictionary
	if player_level < int(r.get("min_level", 2)):
		return false
	var req_veh := String(r.get("requires_vehicle", ""))
	if req_veh != "" and not repaired_vehicles.has(req_veh):
		return false
	return true

func can_start_delivery(rid: String, player_level: int, inventory: Inventory) -> bool:
	if not is_route_unlocked(rid, player_level):
		return false
	if active_deliveries.size() >= get_max_slots():
		return false
	var r := routes_by_id[rid] as Dictionary
	var reqs := r.get("requirements", {}) as Dictionary
	for iid: String in reqs.keys():
		if inventory.get_count(iid) < int(reqs[iid]):
			return false
	return true

func start_delivery(rid: String, player_level: int, inventory: Inventory, clock: GameClock) -> Dictionary:
	if not is_unlocked:
		return {"ok": false, "reason": "Hãy mở khóa Ga-ra trước."}
	if not routes_by_id.has(rid):
		return {"ok": false, "reason": "Tuyến đường không tồn tại."}
	var r := routes_by_id[rid] as Dictionary
	var min_lv := int(r.get("min_level", 2))
	if player_level < min_lv:
		return {"ok": false, "reason": "Cần Lv.%d cho tuyến này." % min_lv}
	var req_veh := String(r.get("requires_vehicle", ""))
	if req_veh != "" and not repaired_vehicles.has(req_veh):
		var v_cfg := vehicles_by_id.get(req_veh, {}) as Dictionary
		return {"ok": false, "reason": "Cần sửa %s trước." % String(v_cfg.get("display_name", req_veh))}
	if active_deliveries.size() >= get_max_slots():
		return {"ok": false, "reason": "Đội xe đang bận (%d/%d)." % [active_deliveries.size(), get_max_slots()]}

	var reqs := r.get("requirements", {}) as Dictionary
	for iid: String in reqs.keys():
		if inventory.get_count(iid) < int(reqs[iid]):
			return {"ok": false, "reason": "Thiếu hàng giao (%s x%d)." % [iid, int(reqs[iid])]}

	# Consume real items atomically on dispatch
	var consumed: Array[Dictionary] = []
	for iid: String in reqs.keys():
		var amt := int(reqs[iid])
		if not inventory.remove_item(iid, amt):
			for prev in consumed:
				inventory.add_item(String(prev["id"]), int(prev["amt"]))
			return {"ok": false, "reason": "Lỗi xuất kho hàng giao."}
		consumed.append({"id": iid, "amt": amt})

	_next_seq += 1
	var base_dur := maxi(5, int(r.get("duration_sec", 15)))
	var dur := maxi(3, int(round(float(base_dur) * get_speed_multiplier())))
	var job := {
		"delivery_id": "deliv_%d" % _next_seq,
		"route_id": rid,
		"display_name": String(r.get("display_name", rid)),
		"started_at_unix": clock.now(),
		"duration_sec": dur,
		"status": "IN_TRANSIT",
		"reward_coins": maxi(0, int(r.get("reward_coins", 0))),
		"reward_xp": maxi(0, int(r.get("reward_xp", 0)))
	}
	active_deliveries.append(job)
	garage_changed.emit()
	return {"ok": true, "delivery": job}

func tick(clock: GameClock) -> int:
	var now_unix := clock.now()
	var completed := 0
	for job in active_deliveries:
		if String(job.get("status", "")) == "IN_TRANSIT":
			var end_unix := int(job.get("started_at_unix", 0)) + int(job.get("duration_sec", 15))
			if now_unix >= end_unix:
				job["status"] = "READY"
				completed += 1
	if completed > 0:
		garage_changed.emit()
	return completed

func claim_delivery(idx: int, wallet: Wallet, progression: ProgressionSystem, home: HomeSystem = null, pets: PetSystem = null) -> Dictionary:
	if idx < 0 or idx >= active_deliveries.size():
		return {"ok": false, "reason": "Chuyến giao không tồn tại."}
	var job := active_deliveries[idx]
	if String(job.get("status", "")) != "READY":
		return {"ok": false, "reason": "Xe vẫn đang trên đường giao."}

	# Remove first so rewards can never be claimed twice
	active_deliveries.remove_at(idx)
	var rid := String(job.get("route_id", ""))
	var coins := maxi(0, int(job.get("reward_coins", 0)))
	var xp := maxi(0, int(job.get("reward_xp", 0)))
	if coins > 0 and wallet != null:
		wallet.earn(coins)
	var lv_res := {}
	if xp > 0 and progression != null:
		lv_res = progression.add_xp(xp)
	delivered_count += 1

	var special_granted := ""
	if routes_by_id.has(rid) and not claimed_route_rewards.has(rid):
		var r_cfg := routes_by_id[rid] as Dictionary
		var spec := r_cfg.get("special_reward", {}) as Dictionary
		if not spec.is_empty():
			claimed_route_rewards[rid] = true
			var s_type := String(spec.get("type", ""))
			var s_id := String(spec.get("id", ""))
			var s_name := String(spec.get("display_name", s_id))
			if s_type == "home_furniture" and home != null and home.items_by_id.has(s_id):
				if not home.owned_furniture.has(s_id):
					home.owned_furniture[s_id] = true
					special_granted = s_name
				elif wallet != null:
					wallet.earn(25)
					special_granted = s_name + " (đã có → +25 xu)"
			elif s_type == "pet_item" and pets != null and pets.items_by_id.has(s_id):
				if not pets.owned_items.has(s_id):
					pets.owned_items[s_id] = true
					pets._sync_unlocked_behaviors()
					special_granted = s_name
				elif wallet != null:
					wallet.earn(25)
					special_granted = s_name + " (đã có → +25 xu)"

	garage_changed.emit()
	return {
		"ok": true,
		"coins": coins,
		"xp": xp,
		"special": special_granted,
		"leveled_up": bool(lv_res.get("leveled_up", false)),
		"new_level": int(lv_res.get("new_level", progression.level if progression != null else 1))
	}

func step_automation(clock: GameClock, inventory: Inventory, wallet: Wallet, progression: ProgressionSystem, home: HomeSystem = null, pets: PetSystem = null) -> Dictionary:
	var summary := {"claimed": 0, "dispatched": 0}
	if not is_unlocked or not auto_dispatch_enabled:
		return summary
	# 1. Auto-claim READY deliveries
	for i in range(active_deliveries.size() - 1, -1, -1):
		if String(active_deliveries[i].get("status", "")) == "READY":
			var c_res := claim_delivery(i, wallet, progression, home, pets)
			if bool(c_res.get("ok", false)):
				summary["claimed"] = int(summary["claimed"]) + 1
	# 2. Auto-dispatch selected route if slot & items available
	var lv := progression.level if progression != null else 1
	if active_deliveries.size() < get_max_slots() and can_start_delivery(auto_route_id, lv, inventory):
		var d_res := start_delivery(auto_route_id, lv, inventory, clock)
		if bool(d_res.get("ok", false)):
			summary["dispatched"] = int(summary["dispatched"]) + 1
	return summary

func to_dict() -> Dictionary:
	var veh_arr: Array[String] = []
	for vid: String in repaired_vehicles.keys():
		veh_arr.append(vid)
	var claimed_arr: Array[String] = []
	for rid: String in claimed_route_rewards.keys():
		claimed_arr.append(rid)
	return {
		"is_unlocked": is_unlocked,
		"repaired_vehicles": veh_arr,
		"speed_level": speed_level,
		"capacity_level": capacity_level,
		"active_deliveries": active_deliveries.duplicate(true),
		"claimed_route_rewards": claimed_arr,
		"auto_dispatch_enabled": auto_dispatch_enabled,
		"auto_route_id": auto_route_id,
		"delivered_count": delivered_count,
		"next_seq": _next_seq
	}

func load_from_dict(data: Dictionary, clock: GameClock) -> void:
	reset()
	is_unlocked = bool(data.get("is_unlocked", false))
	speed_level = clampi(int(data.get("speed_level", 1)), 1, max_speed_level)
	capacity_level = clampi(int(data.get("capacity_level", 1)), 1, max_capacity_level)
	auto_dispatch_enabled = bool(data.get("auto_dispatch_enabled", false))
	var ar := String(data.get("auto_route_id", ""))
	if ar != "" and routes_by_id.has(ar):
		auto_route_id = ar
	delivered_count = maxi(0, int(data.get("delivered_count", 0)))
	_next_seq = maxi(0, int(data.get("next_seq", 0)))

	var raw_veh: Variant = data.get("repaired_vehicles", [])
	if typeof(raw_veh) == TYPE_ARRAY:
		for v in (raw_veh as Array):
			var vid := String(v)
			if vehicles_by_id.has(vid):
				repaired_vehicles[vid] = true

	var raw_cr: Variant = data.get("claimed_route_rewards", [])
	if typeof(raw_cr) == TYPE_ARRAY:
		for r in (raw_cr as Array):
			var rid := String(r)
			if routes_by_id.has(rid):
				claimed_route_rewards[rid] = true

	var raw_del: Variant = data.get("active_deliveries", [])
	if typeof(raw_del) == TYPE_ARRAY:
		for entry in (raw_del as Array):
			if typeof(entry) == TYPE_DICTIONARY:
				active_deliveries.append((entry as Dictionary).duplicate(true))

	if clock != null:
		tick(clock)
	garage_changed.emit()
