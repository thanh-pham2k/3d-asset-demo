class_name ProductionSystem
extends RefCounted
## Manages data-driven crafting recipes, sequential processing queue, station upgrades, and offline completion.

signal queue_changed()

const BATCH_UNLOCK_COST := 140
const BATCH_UNLOCK_LEVEL := 2

var recipes_by_id: Dictionary = {}
var recipe_ids_sorted: Array[String] = []
var initial_slots: int = 2
var max_slots_cap: int = 5
var slot_upgrade_base_cost: int = 80
var slot_upgrade_cost_step: int = 80

var max_slots: int = 2
var batch_unlocked: bool = false
var batch_mode: bool = false
var queue: Array[Dictionary] = []
var _next_job_seq: int = 0

func _init(cfg: Dictionary = {}) -> void:
	apply_config(cfg)

func apply_config(cfg: Dictionary) -> void:
	initial_slots = maxi(1, int(cfg.get("initial_slots", 2)))
	max_slots_cap = maxi(initial_slots, int(cfg.get("max_slots", 5)))
	slot_upgrade_base_cost = maxi(10, int(cfg.get("slot_upgrade_base_cost", 80)))
	slot_upgrade_cost_step = maxi(0, int(cfg.get("slot_upgrade_cost_step", 80)))
	max_slots = initial_slots

	recipes_by_id.clear()
	recipe_ids_sorted.clear()
	var raw: Variant = cfg.get("recipes", [])
	if typeof(raw) == TYPE_ARRAY:
		for entry in (raw as Array):
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var r := (entry as Dictionary).duplicate(true)
			var rid := String(r.get("id", ""))
			if rid != "":
				recipes_by_id[rid] = r
				recipe_ids_sorted.append(rid)

func reset() -> void:
	max_slots = initial_slots
	batch_unlocked = false
	batch_mode = false
	queue.clear()
	_next_job_seq = 0
	queue_changed.emit()

func get_active_batch_mult() -> int:
	return 2 if (batch_unlocked and batch_mode) else 1

func unlock_batch_mode(wallet: Wallet, player_level: int) -> Dictionary:
	if batch_unlocked:
		return {"ok": false, "reason": "Đã mở khóa Chế biến đôi (x2)."}
	if player_level < BATCH_UNLOCK_LEVEL:
		return {"ok": false, "reason": "Cần Level %d để mở Chế biến đôi." % BATCH_UNLOCK_LEVEL}
	if not wallet.can_afford(BATCH_UNLOCK_COST) or not wallet.spend(BATCH_UNLOCK_COST):
		return {"ok": false, "reason": "Cần %d xu để mở Chế biến đôi." % BATCH_UNLOCK_COST}
	batch_unlocked = true
	batch_mode = true
	queue_changed.emit()
	return {"ok": true, "cost": BATCH_UNLOCK_COST}

func toggle_batch_mode() -> bool:
	if not batch_unlocked:
		return false
	batch_mode = not batch_mode
	queue_changed.emit()
	return batch_mode

func get_recipe(recipe_id: String) -> Dictionary:
	return recipes_by_id.get(recipe_id, {}) as Dictionary

func can_start_recipe(recipe_id: String, inventory: Inventory, player_level: int) -> Dictionary:
	if not recipes_by_id.has(recipe_id):
		return {"ok": false, "reason": "Công thức không tồn tại."}
	var r := recipes_by_id[recipe_id] as Dictionary
	var req_lv := int(r.get("min_level", 1))
	if player_level < req_lv:
		return {"ok": false, "reason": "Cần đạt Level %d để chế biến món này." % req_lv}
	if queue.size() >= max_slots:
		return {"ok": false, "reason": "Hàng đợi chế biến đã đầy (%d/%d)." % [queue.size(), max_slots]}
	var inputs: Dictionary = r.get("inputs", {}) as Dictionary
	if inputs.is_empty():
		return {"ok": false, "reason": "Công thức không hợp lệ."}
	var mult := get_active_batch_mult()
	for item_id in inputs.keys():
		var need := maxi(1, int(inputs[item_id])) * mult
		if not inventory.has_item(String(item_id), need):
			return {"ok": false, "reason": "Thiếu nguyên liệu: %s (cần %d)." % [String(item_id), need]}
	return {"ok": true}

func start_recipe(recipe_id: String, inventory: Inventory, clock: GameClock, player_level: int) -> Dictionary:
	var check := can_start_recipe(recipe_id, inventory, player_level)
	if not bool(check.get("ok", false)):
		return check

	var r := recipes_by_id[recipe_id] as Dictionary
	var inputs: Dictionary = r.get("inputs", {}) as Dictionary
	var mult := get_active_batch_mult()
	# All inputs validated above — deduct atomically.
	for item_id in inputs.keys():
		var need := maxi(1, int(inputs[item_id])) * mult
		if not inventory.remove_item(String(item_id), need):
			return {"ok": false, "reason": "Lỗi trừ nguyên liệu."}

	_next_job_seq += 1
	var has_active := false
	for j in queue:
		if String(j.get("status", "")) == "PROCESSING":
			has_active = true
			break

	var base_dur := maxi(1, int(r.get("duration_sec", 10)))
	var duration := base_dur if mult == 1 else maxi(base_dur + 1, int(ceil(float(base_dur) * 1.6)))
	var status := "QUEUED" if has_active else "PROCESSING"
	var started := 0 if has_active else clock.now()

	var job := {
		"job_id": "job_%d" % _next_job_seq,
		"recipe_id": recipe_id,
		"display_name": String(r.get("display_name", recipe_id)) + (" (x2)" if mult == 2 else ""),
		"output_id": String(r.get("output_id", recipe_id)),
		"output_yield": maxi(1, int(r.get("output_yield", 1))) * mult,
		"duration_sec": duration,
		"started_at_unix": started,
		"status": status
	}
	queue.append(job)
	queue_changed.emit()
	return {"ok": true, "job": job}

func tick(clock: GameClock) -> int:
	if clock == null or queue.is_empty():
		return 0
	var now_unix := clock.now()
	var completed := 0
	var next_start_unix := 0

	# Sequential deterministic completion: when a PROCESSING job finishes at end_t,
	# the next QUEUED job starts at end_t so offline time completes queued jobs accurately.
	var changed := true
	while changed:
		changed = false
		var processing_idx := -1
		for i in range(queue.size()):
			if String(queue[i].get("status", "")) == "PROCESSING":
				processing_idx = i
				break
		if processing_idx != -1:
			var job := queue[processing_idx]
			var started := int(job.get("started_at_unix", 0))
			var dur := maxi(1, int(job.get("duration_sec", 10)))
			var end_t := started + dur
			if started > 0 and now_unix >= end_t:
				job["status"] = "READY"
				next_start_unix = end_t
				completed += 1
				changed = true
		else:
			for i in range(queue.size()):
				if String(queue[i].get("status", "")) == "QUEUED":
					queue[i]["status"] = "PROCESSING"
					queue[i]["started_at_unix"] = next_start_unix if next_start_unix > 0 else now_unix
					changed = true
					break

	if completed > 0:
		queue_changed.emit()
	return completed

func collect_job(job_idx: int, inventory: Inventory) -> Dictionary:
	if job_idx < 0 or job_idx >= queue.size():
		return {"ok": false, "reason": "Ô chế biến không tồn tại."}
	var job := queue[job_idx]
	if String(job.get("status", "")) != "READY":
		return {"ok": false, "reason": "Thành phẩm chưa hoàn tất."}

	var out_id := String(job.get("output_id", ""))
	var out_yield := maxi(1, int(job.get("output_yield", 1)))
	if not inventory.can_add(out_yield):
		return {
			"ok": false,
			"reason": "Kho đầy (%d/%d)! Cần trống %d chỗ để nhận thành phẩm." % [
				inventory.get_total_count(),
				inventory.capacity,
				out_yield
			]
		}
	if not inventory.add_item(out_id, out_yield):
		return {"ok": false, "reason": "Không thể thêm thành phẩm vào kho."}

	var d_name := String(job.get("display_name", out_id))
	queue.remove_at(job_idx)
	queue_changed.emit()
	return {"ok": true, "output_id": out_id, "yield": out_yield, "display_name": d_name}

func collect_all_ready(inventory: Inventory) -> Dictionary:
	var collected := 0
	var stopped_full := false
	var last_reason := ""
	var idx := 0
	while idx < queue.size():
		if String(queue[idx].get("status", "")) == "READY":
			var res := collect_job(idx, inventory)
			if bool(res.get("ok", false)):
				collected += 1
				continue # queue shrunk, stay at same idx
			else:
				stopped_full = true
				last_reason = String(res.get("reason", "Kho đầy."))
				break
		idx += 1
	return {
		"ok": collected > 0,
		"collected": collected,
		"stopped_full": stopped_full,
		"reason": last_reason
	}

func get_next_slot_upgrade_cost() -> int:
	var upgrades_done := maxi(0, max_slots - initial_slots)
	return slot_upgrade_base_cost + upgrades_done * slot_upgrade_cost_step

func can_upgrade_slot(wallet: Wallet) -> bool:
	return max_slots < max_slots_cap and wallet.can_afford(get_next_slot_upgrade_cost())

func upgrade_slot(wallet: Wallet) -> Dictionary:
	if max_slots >= max_slots_cap:
		return {"ok": false, "reason": "Hàng đợi chế biến đã đạt tối đa (%d)." % max_slots_cap}
	var cost := get_next_slot_upgrade_cost()
	if not wallet.can_afford(cost):
		return {"ok": false, "reason": "Không đủ xu nâng cấp bếp (cần %d xu)." % cost}
	if not wallet.spend(cost):
		return {"ok": false, "reason": "Không thể trừ xu."}
	max_slots += 1
	queue_changed.emit()
	return {"ok": true, "cost": cost, "new_max_slots": max_slots}

func to_dict() -> Dictionary:
	return {
		"max_slots": max_slots,
		"batch_unlocked": batch_unlocked,
		"batch_mode": batch_mode,
		"queue": queue.duplicate(true),
		"next_job_seq": _next_job_seq
	}

func load_from_dict(d: Dictionary, clock: GameClock = null) -> void:
	max_slots = clampi(int(d.get("max_slots", initial_slots)), initial_slots, max_slots_cap)
	batch_unlocked = bool(d.get("batch_unlocked", false))
	batch_mode = bool(d.get("batch_mode", false)) and batch_unlocked
	_next_job_seq = maxi(0, int(d.get("next_job_seq", 0)))
	queue.clear()
	var raw_q: Variant = d.get("queue", [])
	if typeof(raw_q) == TYPE_ARRAY:
		for entry in (raw_q as Array):
			if typeof(entry) == TYPE_DICTIONARY:
				queue.append((entry as Dictionary).duplicate(true))
	if clock != null:
		tick(clock)
	queue_changed.emit()
