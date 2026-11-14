class_name GarageSystem
extends RefCounted
## Manages the unlockable Garage, fleet expansion (overlapping deliveries), vehicle durability & repair, routes, and upgrades.

signal garage_changed()

var unlock_level: int = 2
var unlock_cost: int = 120
var max_speed_level: int = 3
var speed_upgrade_costs: Array[int] = [90, 180]
var speed_multipliers: Array[float] = [1.0, 0.75, 0.55]

var vehicles_by_id: Dictionary = {}
var vehicle_ids_sorted: Array[String] = []
var routes_by_id: Dictionary = {}
var route_ids_sorted: Array[String] = []

# Persistent state
var is_unlocked: bool = false
var owned_vehicles: Dictionary = {} # vehicle_id -> true
var vehicle_durability: Dictionary = {} # vehicle_id -> int
var speed_level: int = 1
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

	speed_upgrade_costs.clear()
	for c in (cfg.get("speed_upgrade_costs", [90, 180]) as Array):
		speed_upgrade_costs.append(int(c))
	speed_multipliers.clear()
	for m in (cfg.get("speed_multipliers", [1.0, 0.75, 0.55]) as Array):
		speed_multipliers.append(float(m))

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
	owned_vehicles.clear()
	vehicle_durability.clear()
	for vid: String in vehicle_ids_sorted:
		var v := vehicles_by_id[vid] as Dictionary
		if bool(v.get("owned_by_default", false)):
			owned_vehicles[vid] = true
			vehicle_durability[vid] = maxi(1, int(v.get("max_durability", 5)))
	speed_level = 1
	active_deliveries.clear()
	claimed_route_rewards.clear()
	auto_dispatch_enabled = false
	auto_route_id = route_ids_sorted[0] if not route_ids_sorted.is_empty() else "route_market"
	delivered_count = 0
	_next_seq = 0
	garage_changed.emit()

func get_max_slots() -> int:
	return maxi(1, owned_vehicles.size())

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

func is_vehicle_owned(vid: String) -> bool:
	return owned_vehicles.has(vid)

func get_vehicle_max_durability(vid: String) -> int:
	var v := vehicles_by_id.get(vid, {}) as Dictionary
	return maxi(1, int(v.get("max_durability", 5)))

func get_vehicle_durability(vid: String) -> int:
	return int(vehicle_durability.get(vid, 0))

func is_vehicle_busy(vid: String) -> bool:
	for job in active_deliveries:
		if String(job.get("vehicle_id", "")) == vid:
			return true
	return false

func get_idle_healthy_count() -> int:
	var cnt := 0
	for vid: String in vehicle_ids_sorted:
		if owned_vehicles.has(vid) and get_vehicle_durability(vid) > 0 and not is_vehicle_busy(vid):
			cnt += 1
	return cnt

func buy_vehicle(vid: String, player_level: int, wallet: Wallet) -> Dictionary:
	if not is_unlocked:
		return {"ok": false, "reason": "Hãy mở khóa Ga-ra trước."}
	if not vehicles_by_id.has(vid):
		return {"ok": false, "reason": "Phương tiện không tồn tại."}
	if owned_vehicles.has(vid):
		return {"ok": false, "reason": "Bạn đã sở hữu xe này rồi."}
	var v := vehicles_by_id[vid] as Dictionary
	var req_lv := int(v.get("min_level", 2))
	if player_level < req_lv:
		return {"ok": false, "reason": "Cần Lv.%d để mua %s." % [req_lv, String(v.get("display_name", vid))]}
	var cost := maxi(0, int(v.get("buy_cost", 0)))
	if not wallet.spend(cost):
		return {"ok": false, "reason": "Không đủ xu (cần %d xu)." % cost}
	owned_vehicles[vid] = true
	vehicle_durability[vid] = get_vehicle_max_durability(vid)
	garage_changed.emit()
	return {"ok": true, "cost": cost, "vehicle_id": vid}

func repair_vehicle(vid: String, wallet: Wallet) -> Dictionary:
	if not is_unlocked:
		return {"ok": false, "reason": "Hãy mở khóa Ga-ra trước."}
	if not owned_vehicles.has(vid) or not vehicles_by_id.has(vid):
		return {"ok": false, "reason": "Bạn chưa sở hữu xe này."}
	if is_vehicle_busy(vid):
		return {"ok": false, "reason": "Xe đang chạy giao hàng, chờ về bến rồi sửa."}
	var max_dur := get_vehicle_max_durability(vid)
	if get_vehicle_durability(vid) >= max_dur:
		return {"ok": false, "reason": "Xe vẫn còn tốt (%d/%d)." % [max_dur, max_dur]}
	var v := vehicles_by_id[vid] as Dictionary
	var cost := maxi(0, int(v.get("repair_cost", 20)))
	if not wallet.spend(cost):
		return {"ok": false, "reason": "Không đủ xu sửa xe (cần %d xu)." % cost}
	vehicle_durability[vid] = max_dur
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

func _find_available_vehicle(req_veh: String) -> String:
	if req_veh != "":
		if owned_vehicles.has(req_veh) and get_vehicle_durability(req_veh) > 0 and not is_vehicle_busy(req_veh):
			return req_veh
		return ""
	for vid: String in vehicle_ids_sorted:
		if owned_vehicles.has(vid) and get_vehicle_durability(vid) > 0 and not is_vehicle_busy(vid):
			return vid
	return ""

func is_route_unlocked(rid: String, player_level: int) -> bool:
	if not is_unlocked or not routes_by_id.has(rid):
		return false
	var r := routes_by_id[rid] as Dictionary
	if player_level < int(r.get("min_level", 2)):
		return false
	var req_veh := String(r.get("requires_vehicle", ""))
	if req_veh != "" and not owned_vehicles.has(req_veh):
		return false
	return true

func can_start_delivery(rid: String, player_level: int, inventory: Inventory) -> bool:
	if not is_route_unlocked(rid, player_level):
		return false
	var r := routes_by_id[rid] as Dictionary
	if _find_available_vehicle(String(r.get("requires_vehicle", ""))) == "":
		return false
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
	if req_veh != "" and not owned_vehicles.has(req_veh):
		var v_cfg := vehicles_by_id.get(req_veh, {}) as Dictionary
		return {"ok": false, "reason": "Cần mua %s trước." % String(v_cfg.get("display_name", req_veh))}
	var chosen_vid := _find_available_vehicle(req_veh)
	if chosen_vid == "":
		return {"ok": false, "reason": "Không có xe rảnh hoặc xe cần sửa chữa!"}

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
	var v_name := String((vehicles_by_id.get(chosen_vid, {}) as Dictionary).get("display_name", chosen_vid))
	var job := {
		"delivery_id": "deliv_%d" % _next_seq,
		"route_id": rid,
		"vehicle_id": chosen_vid,
		"vehicle_name": v_name,
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

func claim_delivery(idx: int, wallet: Wallet, progression: ProgressionSystem, _home: HomeSystem = null, _pets: PetSystem = null) -> Dictionary:
	if idx < 0 or idx >= active_deliveries.size():
		return {"ok": false, "reason": "Chuyến giao không tồn tại."}
	var job := active_deliveries[idx]
	if String(job.get("status", "")) != "READY":
		return {"ok": false, "reason": "Xe vẫn đang trên đường giao."}

	# Remove first so rewards can never be claimed twice
	active_deliveries.remove_at(idx)
	var rid := String(job.get("route_id", ""))
	var vid := String(job.get("vehicle_id", ""))
	if vid != "" and owned_vehicles.has(vid):
		vehicle_durability[vid] = maxi(0, get_vehicle_durability(vid) - 1)

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
		var bonus := r_cfg.get("first_clear_bonus", {}) as Dictionary
		if not bonus.is_empty():
			claimed_route_rewards[rid] = true
			var b_coins := maxi(0, int(bonus.get("coins", 0)))
			var b_xp := maxi(0, int(bonus.get("xp", 0)))
			if b_coins > 0 and wallet != null:
				wallet.earn(b_coins)
			if b_xp > 0 and progression != null:
				lv_res = progression.add_xp(b_xp)
			special_granted = "+%d xu, +%d XP (Mở tuyến lần đầu)" % [b_coins, b_xp]

	garage_changed.emit()
	return {
		"ok": true,
		"coins": coins,
		"xp": xp,
		"special": special_granted,
		"worn_out": (vid != "" and get_vehicle_durability(vid) == 0),
		"vehicle_name": String(job.get("vehicle_name", vid)),
		"leveled_up": bool(lv_res.get("leveled_up", false)),
		"new_level": int(lv_res.get("new_level", progression.level if progression != null else 1))
	}

func claim_all_ready(wallet: Wallet, progression: ProgressionSystem, home: HomeSystem = null, pets: PetSystem = null) -> Dictionary:
	var claimed := 0
	var total_coins := 0
	var total_xp := 0
	var worn_names: Array[String] = []
	var leveled_up := false
	var new_level := progression.level if progression != null else 1
	for i in range(active_deliveries.size() - 1, -1, -1):
		if String(active_deliveries[i].get("status", "")) == "READY":
			var res := claim_delivery(i, wallet, progression, home, pets)
			if bool(res.get("ok", false)):
				claimed += 1
				total_coins += int(res.get("coins", 0))
				total_xp += int(res.get("xp", 0))
				if bool(res.get("worn_out", false)):
					worn_names.append(String(res.get("vehicle_name", "Xe")))
				if bool(res.get("leveled_up", false)):
					leveled_up = true
					new_level = int(res.get("new_level", new_level))
	return {
		"ok": claimed > 0,
		"claimed": claimed,
		"coins": total_coins,
		"xp": total_xp,
		"worn_names": worn_names,
		"leveled_up": leveled_up,
		"new_level": new_level
	}

func step_automation(clock: GameClock, inventory: Inventory, wallet: Wallet, progression: ProgressionSystem, home: HomeSystem = null, pets: PetSystem = null) -> Dictionary:
	var summary := {"claimed": 0, "dispatched": 0}
	if not is_unlocked or not auto_dispatch_enabled:
		return summary
	for i in range(active_deliveries.size() - 1, -1, -1):
		if String(active_deliveries[i].get("status", "")) == "READY":
			var c_res := claim_delivery(i, wallet, progression, home, pets)
			if bool(c_res.get("ok", false)):
				summary["claimed"] = int(summary["claimed"]) + 1
	var lv := progression.level if progression != null else 1
	if can_start_delivery(auto_route_id, lv, inventory):
		var d_res := start_delivery(auto_route_id, lv, inventory, clock)
		if bool(d_res.get("ok", false)):
			summary["dispatched"] = int(summary["dispatched"]) + 1
	return summary

func to_dict() -> Dictionary:
	var veh_arr: Array[String] = []
	for vid: String in owned_vehicles.keys():
		veh_arr.append(vid)
	var claimed_arr: Array[String] = []
	for rid: String in claimed_route_rewards.keys():
		claimed_arr.append(rid)
	return {
		"is_unlocked": is_unlocked,
		"owned_vehicles": veh_arr,
		"vehicle_durability": vehicle_durability.duplicate(true),
		"speed_level": speed_level,
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
	auto_dispatch_enabled = bool(data.get("auto_dispatch_enabled", false))
	var ar := String(data.get("auto_route_id", ""))
	if ar != "" and routes_by_id.has(ar):
		auto_route_id = ar
	delivered_count = maxi(0, int(data.get("delivered_count", 0)))
	_next_seq = maxi(0, int(data.get("next_seq", 0)))

	var raw_owned: Variant = data.get("owned_vehicles", [])
	if typeof(raw_owned) == TYPE_ARRAY and not (raw_owned as Array).is_empty():
		owned_vehicles.clear()
		for v in (raw_owned as Array):
			var vid := String(v)
			if vehicles_by_id.has(vid):
				owned_vehicles[vid] = true
				vehicle_durability[vid] = get_vehicle_max_durability(vid)

	var raw_dur: Variant = data.get("vehicle_durability", {})
	if typeof(raw_dur) == TYPE_DICTIONARY:
		for vid: String in (raw_dur as Dictionary).keys():
			if owned_vehicles.has(vid):
				vehicle_durability[vid] = clampi(int((raw_dur as Dictionary)[vid]), 0, get_vehicle_max_durability(vid))

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
