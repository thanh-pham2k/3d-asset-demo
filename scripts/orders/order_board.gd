class_name OrderBoard
extends RefCounted
## Manages multi-slot standard and special orders with atomic validation and XP/coin rewards.

signal order_completed(reward_coins: int)
signal board_changed()

# P1 single-order compatibility fields
var order_id: String = "order_carrot_4"
var title: String = "Đơn hàng Cà rốt tươi"
var item_id: String = "carrot"
var required_count: int = 4
var reward_coins: int = 60

# P3 multi-slot catalog & state
var max_slots: int = 3
var refresh_cooldown_sec: int = 30
var templates: Array[Dictionary] = []
var slots: Array[Dictionary] = []
var slot_cooldowns: Dictionary = {} # slot_idx (String) -> next_refresh_unix (int)
var _next_seq: int = 0

func _init(order_cfg: Dictionary = {}, catalog_cfg: Dictionary = {}) -> void:
	if not order_cfg.is_empty():
		apply_config(order_cfg)
	if not catalog_cfg.is_empty():
		apply_catalog(catalog_cfg)

func apply_config(order_cfg: Dictionary) -> void:
	order_id = String(order_cfg.get("id", "order_carrot_4"))
	title = String(order_cfg.get("title", "Đơn hàng Cà rốt tươi"))
	item_id = String(order_cfg.get("item_id", "carrot"))
	required_count = maxi(1, int(order_cfg.get("required_count", 4)))
	reward_coins = maxi(0, int(order_cfg.get("reward_coins", 60)))

func apply_catalog(catalog_cfg: Dictionary) -> void:
	max_slots = maxi(1, int(catalog_cfg.get("max_slots", 3)))
	refresh_cooldown_sec = maxi(1, int(catalog_cfg.get("refresh_cooldown_sec", 30)))
	templates.clear()
	var raw: Variant = catalog_cfg.get("templates", [])
	if typeof(raw) == TYPE_ARRAY:
		for entry in (raw as Array):
			if typeof(entry) == TYPE_DICTIONARY:
				templates.append((entry as Dictionary).duplicate(true))
	if templates.is_empty():
		templates.append({
			"id": order_id,
			"title": title,
			"type": "standard",
			"min_level": 1,
			"requirements": { item_id: required_count },
			"reward_coins": reward_coins,
			"reward_xp": 25
		})

func ensure_slots(player_level: int, _clock: GameClock = null) -> void:
	while slots.size() < max_slots:
		var slot_idx := slots.size()
		var prefer_special := (slot_idx == max_slots - 1)
		slots.append(_pick_template(player_level, prefer_special))
	board_changed.emit()

func _pick_template(player_level: int, prefer_special: bool) -> Dictionary:
	var eligible: Array[Dictionary] = []
	var preferred: Array[Dictionary] = []
	for t in templates:
		if int(t.get("min_level", 1)) <= player_level:
			eligible.append(t)
			if prefer_special and String(t.get("type", "standard")) == "special":
				preferred.append(t)
	var pool := preferred if not preferred.is_empty() else eligible
	if pool.is_empty():
		pool = templates
	var chosen := pool[_next_seq % pool.size()].duplicate(true)
	_next_seq += 1
	chosen["instance_id"] = "ord_%d" % _next_seq
	return chosen

func get_slot(slot_idx: int) -> Dictionary:
	if slot_idx < 0 or slot_idx >= slots.size():
		return {}
	return slots[slot_idx]

func can_deliver_slot(slot_idx: int, inventory: Inventory) -> bool:
	var slot := get_slot(slot_idx)
	if slot.is_empty():
		return false
	var reqs: Dictionary = slot.get("requirements", {}) as Dictionary
	if reqs.is_empty():
		return false
	for req_id in reqs.keys():
		var need := maxi(1, int(reqs[req_id]))
		if not inventory.has_item(String(req_id), need):
			return false
	return true

func deliver_slot(
	slot_idx: int,
	inventory: Inventory,
	wallet: Wallet,
	progression: ProgressionSystem,
	clock: GameClock
) -> Dictionary:
	var slot := get_slot(slot_idx)
	if slot.is_empty():
		return {"ok": false, "reason": "Đơn hàng không tồn tại."}
	if not can_deliver_slot(slot_idx, inventory):
		return {"ok": false, "reason": "Chưa đủ nguyên liệu cho đơn này."}

	var reqs: Dictionary = slot.get("requirements", {}) as Dictionary
	# Atomic removal: all items verified above before removing any.
	for req_id in reqs.keys():
		var need := maxi(1, int(reqs[req_id]))
		if not inventory.remove_item(String(req_id), need):
			return {"ok": false, "reason": "Lỗi trừ nguyên liệu trong kho."}

	var coins := maxi(0, int(slot.get("reward_coins", 0)))
	var xp := maxi(0, int(slot.get("reward_xp", 0)))
	wallet.earn(coins)
	var prog_res := {"leveled_up": false, "new_level": 1, "new_unlocks": []}
	if progression != null:
		progression.completed_orders += 1
		prog_res = progression.add_xp(xp)

	# Replace completed slot immediately to prevent duplicate reward claims.
	var lv := progression.level if progression != null else 1
	var prefer_special := (slot_idx == max_slots - 1)
	slots[slot_idx] = _pick_template(lv, prefer_special)
	slot_cooldowns.erase(str(slot_idx))
	order_completed.emit(coins)
	board_changed.emit()
	return {
		"ok": true,
		"title": String(slot.get("title", "")),
		"reward_coins": coins,
		"reward_xp": xp,
		"leveled_up": bool(prog_res.get("leveled_up", false)),
		"new_level": int(prog_res.get("new_level", lv)),
		"new_unlocks": prog_res.get("new_unlocks", []),
		"timestamp": clock.now() if clock != null else 0
	}

func get_refresh_remaining_sec(slot_idx: int, clock: GameClock) -> int:
	if clock == null:
		return 0
	var next_unix := int(slot_cooldowns.get(str(slot_idx), 0))
	return maxi(0, next_unix - clock.now())

func skip_slot(slot_idx: int, player_level: int, clock: GameClock) -> Dictionary:
	if slot_idx < 0 or slot_idx >= slots.size():
		return {"ok": false, "reason": "Ô đơn hàng không hợp lệ."}
	var rem := get_refresh_remaining_sec(slot_idx, clock)
	if rem > 0:
		return {"ok": false, "reason": "Đang hồi làm mới đơn (còn %s)." % GameClock.format_duration(rem)}
	var prefer_special := (slot_idx == max_slots - 1)
	slots[slot_idx] = _pick_template(player_level, prefer_special)
	if clock != null:
		slot_cooldowns[str(slot_idx)] = clock.now() + refresh_cooldown_sec
	board_changed.emit()
	return {"ok": true, "new_title": String(slots[slot_idx].get("title", ""))}

func to_dict() -> Dictionary:
	return {
		"slots": slots.duplicate(true),
		"slot_cooldowns": slot_cooldowns.duplicate(true),
		"next_seq": _next_seq
	}

func load_from_dict(d: Dictionary, player_level: int, clock: GameClock = null) -> void:
	slots.clear()
	slot_cooldowns.clear()
	_next_seq = maxi(0, int(d.get("next_seq", 0)))
	var raw_slots: Variant = d.get("slots", [])
	if typeof(raw_slots) == TYPE_ARRAY:
		for entry in (raw_slots as Array):
			if typeof(entry) == TYPE_DICTIONARY:
				slots.append((entry as Dictionary).duplicate(true))
	var raw_cd: Variant = d.get("slot_cooldowns", {})
	if typeof(raw_cd) == TYPE_DICTIONARY:
		slot_cooldowns = (raw_cd as Dictionary).duplicate(true)
	ensure_slots(player_level, clock)

# --- P1 single-order compatibility methods ---
func can_deliver(inventory: Inventory) -> bool:
	return inventory.has_item(item_id, required_count)

func deliver(inventory: Inventory, wallet: Wallet) -> Dictionary:
	if not can_deliver(inventory):
		return {
			"ok": false,
			"reason": "Cần %d %s (hiện có %d)." % [required_count, item_id, inventory.get_count(item_id)]
		}
	if not inventory.remove_item(item_id, required_count):
		return {"ok": false, "reason": "Không thể trừ nông sản trong kho."}
	wallet.earn(reward_coins)
	order_completed.emit(reward_coins)
	return {"ok": true, "reward": reward_coins, "delivered": required_count}
