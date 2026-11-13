class_name HouseProgressionManager
extends Node

## Manages home upgrade progression levels (Level 1, 2, 3),
## area unlocking, wallet checks, confirmation, and persistent placement state.

signal house_upgraded(new_level: int, unlocked_areas: Array)
signal furniture_list_changed()
signal cozy_score_changed(new_score: int, bonus_pct: float)

const MAX_COZY_PER_CATEGORY: int = 3
const UNIQUE_FURNITURE_IDS: Array[String] = ["furn_inverter_fridge", "furn_wooden_bed", "furn_sleeping_mat"]

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

# Functional flags for standalone house upgrades
var has_tile_yard: bool = false
var has_flower_garden: bool = false
var has_modern_kitchen: bool = false

## Array of dictionaries: [ {"id": "furn_...", "pos": [x, y, z], "rot_y": float} ]
var placed_furniture: Array = []
var cozy_score: int = 0
var dinner_buff_active_day: int = 0

func _ready() -> void:
	add_to_group("house_progression_manager")
	recalculate_cozy_score()

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

func apply_tile_yard_upgrade() -> void:
	has_tile_yard = true
	_update_unlocked_areas()

func apply_flower_garden_upgrade() -> void:
	has_flower_garden = true
	_update_unlocked_areas()

func apply_modern_kitchen_upgrade() -> void:
	has_modern_kitchen = true
	_update_unlocked_areas()

func is_area_unlocked(area_name: String) -> bool:
	return area_name in unlocked_areas

func has_upgrade(upgrade_id: String) -> bool:
	match upgrade_id:
		"upg_house_level_2": return house_level >= 2
		"upg_house_level_3": return house_level >= 3
		"upg_house_tile_yard": return has_tile_yard
		"upg_house_flower_garden": return has_flower_garden
		"upg_house_modern_kitchen": return has_modern_kitchen
		_: return false

func sync_with_economy(econ: EconomyManager) -> void:
	if not is_instance_valid(econ) or not is_instance_valid(econ.inventory): return
	if econ.inventory.is_upgrade_owned("upg_house_level_3"):
		house_level = maxi(house_level, 3)
	elif econ.inventory.is_upgrade_owned("upg_house_level_2"):
		house_level = maxi(house_level, 2)

	if econ.inventory.is_upgrade_owned("upg_house_tile_yard"):
		has_tile_yard = true
	if econ.inventory.is_upgrade_owned("upg_house_flower_garden"):
		has_flower_garden = true
	if econ.inventory.is_upgrade_owned("upg_house_modern_kitchen"):
		has_modern_kitchen = true
	_update_unlocked_areas()

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
	recalculate_cozy_score()
	
	if is_inside_tree():
		var econ: EconomyManager = get_tree().get_first_node_in_group("economy_manager") as EconomyManager
		if is_instance_valid(econ):
			econ.inventory.unlock_upgrade("upg_house_level_%d" % house_level)
			if econ.auto_save_on_change:
				econ.save_economy_state()
	
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

	if has_tile_yard and not "tile_yard" in unlocked_areas:
		unlocked_areas.append("tile_yard")
	if has_flower_garden and not "flower_garden" in unlocked_areas:
		unlocked_areas.append("flower_garden")
	if has_modern_kitchen and not "modern_kitchen" in unlocked_areas:
		unlocked_areas.append("modern_kitchen")

func register_placed_furniture(furniture_id: String, pos: Vector3, rot_y: float) -> void:
	placed_furniture.append({
		"id": furniture_id,
		"pos": [pos.x, pos.y, pos.z],
		"rot_y": rot_y
	})
	recalculate_cozy_score()
	furniture_list_changed.emit()

func unregister_placed_furniture(furniture_id: String, pos: Vector3) -> bool:
	for i in range(placed_furniture.size() - 1, -1, -1):
		var item: Dictionary = placed_furniture[i]
		if item.get("id", "") == furniture_id:
			var ipos: Array = item.get("pos", [0, 0, 0])
			var vpos := Vector3(ipos[0], ipos[1], ipos[2])
			if vpos.distance_to(pos) < 0.5:
				placed_furniture.remove_at(i)
				recalculate_cozy_score()
				furniture_list_changed.emit()
				return true
	return false

func has_placed_furniture(furniture_id: String) -> bool:
	for item in placed_furniture:
		if item is Dictionary and String(item.get("id", "")) == furniture_id:
			return true
	return false

static func get_furniture_cozy_points(furniture_id: String) -> int:
	var def := FurnitureData.get_definition(furniture_id)
	var cat := String(def.get("category", "decoration"))
	if furniture_id in ["furn_deluxe_sofa", "furn_wooden_bed", "furn_inverter_fridge"]:
		return 14
	if furniture_id in ["furn_oak_table", "furn_basic_sofa", "furn_tv", "furn_bookshelf", "furn_wardrobe"]:
		return 10
	match cat:
		"bed", "sofa":
			return 12
		"table":
			return 9
		"chair":
			return 6
		_:
			return 7

func recalculate_cozy_score() -> int:
	var total := 0
	# Base cozy contribution from house tier & functional upgrades
	total += (house_level - 1) * 15
	if has_tile_yard:
		total += 6
	if has_flower_garden:
		total += 8
	if has_modern_kitchen:
		total += 8

	var category_counts: Dictionary = {}
	var id_counts: Dictionary = {}
	for entry in placed_furniture:
		if not entry is Dictionary:
			continue
		var fid := String(entry.get("id", ""))
		if fid == "":
			continue
		var def := FurnitureData.get_definition(fid)
		var cat := String(def.get("category", "decoration"))
		var cat_cnt := int(category_counts.get(cat, 0))
		if cat_cnt >= MAX_COZY_PER_CATEGORY:
			continue
		var id_cnt := int(id_counts.get(fid, 0))
		# Diminishing returns: 1st = 100%, 2nd = 50%, 3rd+ = 0% for identical items
		var mult := 1.0 if id_cnt == 0 else (0.5 if id_cnt == 1 else 0.0)
		if mult > 0.0:
			total += int(round(float(get_furniture_cozy_points(fid)) * mult))
		category_counts[cat] = cat_cnt + 1
		id_counts[fid] = id_cnt + 1

	cozy_score = clampi(total, 0, 100)
	cozy_score_changed.emit(cozy_score, get_cozy_objective_bonus_pct())
	return cozy_score

func get_cozy_objective_bonus_pct() -> float:
	if cozy_score >= 81:
		return 0.08
	if cozy_score >= 51:
		return 0.05
	if cozy_score >= 21:
		return 0.03
	return 0.0

func grant_dinner_buff_for_next_day(current_day: int) -> void:
	dinner_buff_active_day = maxi(1, current_day) + 1

func has_dinner_speed_buff(current_day: int) -> bool:
	return dinner_buff_active_day == current_day

func get_save_data() -> Dictionary:
	return {
		"level": house_level,
		"unlocked_areas": unlocked_areas,
		"placed_furniture": placed_furniture,
		"has_tile_yard": has_tile_yard,
		"has_flower_garden": has_flower_garden,
		"has_modern_kitchen": has_modern_kitchen,
		"dinner_buff_active_day": dinner_buff_active_day
	}

func apply_save_data(data: Dictionary) -> void:
	if typeof(data) != TYPE_DICTIONARY: return
	house_level = clampi(int(data.get("level", 1)), 1, 3)
	has_tile_yard = bool(data.get("has_tile_yard", false))
	has_flower_garden = bool(data.get("has_flower_garden", false))
	has_modern_kitchen = bool(data.get("has_modern_kitchen", false))
	dinner_buff_active_day = int(data.get("dinner_buff_active_day", 0))

	# Maintain compatibility with legacy saves storing unlocked_areas
	var loaded_areas = data.get("unlocked_areas", [])
	if typeof(loaded_areas) == TYPE_ARRAY:
		if "tile_yard" in loaded_areas: has_tile_yard = true
		if "flower_garden" in loaded_areas: has_flower_garden = true
		if "modern_kitchen" in loaded_areas: has_modern_kitchen = true

	_update_unlocked_areas()
	
	if is_inside_tree():
		var econ: EconomyManager = get_tree().get_first_node_in_group("economy_manager") as EconomyManager
		if is_instance_valid(econ):
			if house_level >= 2: econ.inventory.unlock_upgrade("upg_house_level_2")
			if house_level >= 3: econ.inventory.unlock_upgrade("upg_house_level_3")
			if has_tile_yard: econ.inventory.unlock_upgrade("upg_house_tile_yard")
			if has_flower_garden: econ.inventory.unlock_upgrade("upg_house_flower_garden")
			if has_modern_kitchen: econ.inventory.unlock_upgrade("upg_house_modern_kitchen")
			# Legacy saves can store upgrades only in the shared inventory.
			sync_with_economy(econ)
	
	var loaded_furn = data.get("placed_furniture", [])
	if typeof(loaded_furn) == TYPE_ARRAY:
		placed_furniture.clear()
		for entry in loaded_furn:
			if typeof(entry) == TYPE_DICTIONARY and entry.has("id") and entry.has("pos"):
				placed_furniture.append(entry)
	recalculate_cozy_score()
	furniture_list_changed.emit()
