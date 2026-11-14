class_name ProgressionSystem
extends RefCounted
## Tracks shared player XP, Level, milestone unlocks, and next-goal hints.

signal progression_changed(new_level: int, new_xp: int)
signal leveled_up(new_level: int, new_unlocks: Array[String])

var level: int = 1
var xp: int = 0
var completed_orders: int = 0
var unlocked_ids: Dictionary = {}
var levels_data: Array[Dictionary] = []

func _init(levels_cfg: Dictionary = {}) -> void:
	apply_config(levels_cfg)
	reset()

func apply_config(levels_cfg: Dictionary) -> void:
	levels_data.clear()
	var raw: Variant = levels_cfg.get("levels", [])
	if typeof(raw) == TYPE_ARRAY:
		for entry in (raw as Array):
			if typeof(entry) == TYPE_DICTIONARY:
				levels_data.append((entry as Dictionary).duplicate(true))
	if levels_data.is_empty():
		levels_data.append({"level": 1, "xp_required": 0, "unlocks": ["carrot", "scallion"], "goal": "Giao đơn kiếm XP!"})
	levels_data.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("level", 1)) < int(b.get("level", 1))
	)

func reset() -> void:
	level = 1
	xp = 0
	completed_orders = 0
	unlocked_ids.clear()
	_sync_unlocks_for_level(level)
	progression_changed.emit(level, xp)

func add_xp(amount: int) -> Dictionary:
	if amount <= 0:
		return {"leveled_up": false, "new_level": level, "new_unlocks": []}
	xp += amount
	var old_level := level
	var gained_unlocks: Array[String] = []
	for row in levels_data:
		var lv := int(row.get("level", 1))
		var req := int(row.get("xp_required", 0))
		if xp >= req and lv > level:
			level = lv
			var newly := _sync_unlocks_for_level(lv)
			for u in newly:
				gained_unlocks.append(u)
	progression_changed.emit(level, xp)
	if level > old_level:
		leveled_up.emit(level, gained_unlocks)
	return {
		"leveled_up": level > old_level,
		"new_level": level,
		"new_unlocks": gained_unlocks
	}

func _sync_unlocks_for_level(target_level: int) -> Array[String]:
	var newly: Array[String] = []
	for row in levels_data:
		if int(row.get("level", 1)) <= target_level:
			var arr: Variant = row.get("unlocks", [])
			if typeof(arr) == TYPE_ARRAY:
				for item in (arr as Array):
					var uid := String(item)
					if uid != "" and not unlocked_ids.has(uid):
						unlocked_ids[uid] = true
						newly.append(uid)
	return newly

func is_unlocked(uid: String) -> bool:
	return unlocked_ids.has(uid)

func get_next_level_xp() -> int:
	for row in levels_data:
		var lv := int(row.get("level", 1))
		if lv == level + 1:
			return int(row.get("xp_required", xp))
	return xp

func get_next_goal_text() -> String:
	for row in levels_data:
		if int(row.get("level", 1)) == level:
			return String(row.get("goal", "Tiếp tục phát triển nông trại!"))
	return "Tiếp tục phát triển nông trại!"

func to_dict() -> Dictionary:
	var list: Array[String] = []
	for k in unlocked_ids.keys():
		list.append(String(k))
	list.sort()
	return {
		"level": level,
		"xp": xp,
		"completed_orders": completed_orders,
		"unlocked_ids": list
	}

func load_from_dict(d: Dictionary) -> void:
	level = maxi(1, int(d.get("level", 1)))
	xp = maxi(0, int(d.get("xp", 0)))
	completed_orders = maxi(0, int(d.get("completed_orders", 0)))
	unlocked_ids.clear()
	var arr: Variant = d.get("unlocked_ids", [])
	if typeof(arr) == TYPE_ARRAY:
		for item in (arr as Array):
			var uid := String(item)
			if uid != "":
				unlocked_ids[uid] = true
	_sync_unlocks_for_level(level)
	progression_changed.emit(level, xp)
