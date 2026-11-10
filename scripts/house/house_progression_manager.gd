class_name HouseProgressionManager
extends Node

## Manages home upgrade progression levels (Level 1, 2, 3),
## area unlocking, wallet checks, confirmation, and persistent placement state.

signal house_upgraded(new_level: int, unlocked_areas: Array)
signal furniture_list_changed()

const UPGRADE_COSTS: Dictionary = {
	2: 75000,   # Level 1 -> 2: Căn hộ ấm cúng
	3: 150000   # Level 2 -> 3: Biệt thự sân vườn
}

const LEVEL_TITLES: Dictionary = {
	1: "Cấp 1 — Nhà gỗ mộc mạc",
	2: "Cấp 2 — Căn hộ ấm cúng",
	3: "Cấp 3 — Biệt thự sân vườn"
}

@export var house_level: int = 1
var unlocked_areas: Array[String] = ["main_room"]

## Array of dictionaries: [ {"id": "furn_...", "pos": [x, y, z], "rot_y": float} ]
var placed_furniture: Array = []

func _ready() -> void:
	add_to_group("house_progression_manager")

func get_room_bounds() -> AABB:
	match house_level:
		1:
			# Cozy starter size: left wall at -8.9, boundary at +2.2
			return AABB(Vector3(-8.8, 0, -4.3), Vector3(11.0, 3.0, 8.6))
		2:
			# Full standard house: -8.8 to +8.8
			return AABB(Vector3(-8.8, 0, -4.3), Vector3(17.6, 3.0, 8.6))
		3:
			# Expanded villa with sunroom extension: -8.8 to +14.6
			return AABB(Vector3(-8.8, 0, -4.3), Vector3(23.4, 3.0, 8.6))
		_:
			return AABB(Vector3(-8.8, 0, -4.3), Vector3(17.6, 3.0, 8.6))

func get_next_level() -> int:
	return house_level + 1 if house_level < 3 else 3

func get_upgrade_cost(target_level: int) -> int:
	return UPGRADE_COSTS.get(target_level, 0)

func can_upgrade(wallet: HouseholdWallet) -> Dictionary:
	if house_level >= 3:
		return {
			"can_upgrade": false,
			"reason": "MAX_LEVEL",
			"cost": 0,
			"next_level": 3,
			"title": LEVEL_TITLES.get(3, ""),
			"message": "Ngôi nhà đã đạt cấp tối đa (Cấp 3 — Biệt thự sân vườn)!"
		}
	
	var next_lvl := house_level + 1
	var cost := get_upgrade_cost(next_lvl)
	var title: String = LEVEL_TITLES.get(next_lvl, "")
	
	if not wallet or not wallet.can_afford(cost):
		var balance: int = wallet.balance if wallet else 0
		return {
			"can_upgrade": false,
			"reason": "INSUFFICIENT_FUNDS",
			"cost": cost,
			"next_level": next_lvl,
			"title": title,
			"message": "Không đủ tiền! Cần %s để nâng cấp lên %s (Hiện có: %s)" % [
				HouseholdWallet.format_money(cost),
				title,
				HouseholdWallet.format_money(balance)
			]
		}
	
	return {
		"can_upgrade": true,
		"reason": "OK",
		"cost": cost,
		"next_level": next_lvl,
		"title": title,
		"message": "Đủ điều kiện nâng cấp lên %s (%s)!" % [title, HouseholdWallet.format_money(cost)]
	}

func upgrade_house(wallet: HouseholdWallet) -> Dictionary:
	var check := can_upgrade(wallet)
	if not check["can_upgrade"]:
		return check
	
	var next_lvl: int = check["next_level"]
	var cost: int = check["cost"]
	var tx_id := "house_upgrade_lvl_%d_%d" % [next_lvl, Time.get_ticks_msec()]
	var desc := "Nâng cấp nhà lên %s" % check["title"]
	
	var withdraw_ok := wallet.withdraw(cost, "house_upgrade", desc, tx_id)
	if not withdraw_ok:
		return {
			"success": false,
			"reason": "WITHDRAWAL_FAILED",
			"message": "Không thể trừ tiền từ ví gia đình!"
		}
	
	house_level = next_lvl
	_update_unlocked_areas()
	
	house_upgraded.emit(house_level, unlocked_areas)
	return {
		"success": true,
		"level": house_level,
		"unlocked_areas": unlocked_areas,
		"title": check["title"],
		"message": "🎉 Chúc mừng! Ngôi nhà đã được nâng cấp lên %s!" % check["title"]
	}

func _update_unlocked_areas() -> void:
	match house_level:
		1:
			unlocked_areas = ["main_room"]
		2:
			unlocked_areas = ["main_room", "tiled_kitchen", "dining_room"]
		3:
			unlocked_areas = ["main_room", "tiled_kitchen", "dining_room", "sunroom_wing", "courtyard_garden"]

func register_placed_furniture(furniture_id: String, pos: Vector3, rot_y: float) -> void:
	placed_furniture.append({
		"id": furniture_id,
		"pos": [pos.x, pos.y, pos.z],
		"rot_y": rot_y
	})
	furniture_list_changed.emit()

func unregister_placed_furniture(furniture_id: String, pos: Vector3) -> bool:
	for i in range(placed_furniture.size() - 1, -1, -1):
		var item: Dictionary = placed_furniture[i]
		if item.get("id", "") == furniture_id:
			var ipos: Array = item.get("pos", [0, 0, 0])
			var vpos := Vector3(ipos[0], ipos[1], ipos[2])
			if vpos.distance_to(pos) < 0.5:
				placed_furniture.remove_at(i)
				furniture_list_changed.emit()
				return true
	return false

func get_save_data() -> Dictionary:
	return {
		"level": house_level,
		"unlocked_areas": unlocked_areas,
		"placed_furniture": placed_furniture
	}

func apply_save_data(data: Dictionary) -> void:
	if typeof(data) != TYPE_DICTIONARY: return
	house_level = clampi(int(data.get("level", 1)), 1, 3)
	_update_unlocked_areas()
	
	var loaded_furn = data.get("placed_furniture", [])
	if typeof(loaded_furn) == TYPE_ARRAY:
		placed_furniture.clear()
		for entry in loaded_furn:
			if typeof(entry) == TYPE_DICTIONARY and entry.has("id") and entry.has("pos"):
				placed_furniture.append(entry)
	furniture_list_changed.emit()
