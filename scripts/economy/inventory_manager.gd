class_name InventoryManager
extends RefCounted

## Tracks inventory of consumable supplies (ingredients, tools)
## and ownership of unique purchases (furniture, house & business upgrades).

signal item_count_changed(product_id: String, new_count: int)
signal upgrade_unlocked(upgrade_id: String)
signal furniture_unlocked(furniture_id: String)

const REPAIR_KIT_ID := "tool_repair_kit"

# Consumable items: product_id -> int quantity
var items: Dictionary = {}

# Unique owned upgrades: upgrade_id -> true
var owned_upgrades: Dictionary = {}

# Unique owned furniture: furniture_id -> true
var owned_furniture: Dictionary = {}

static func normalize_item_id(product_id: String) -> String:
	if product_id in ["tool_patch_strip", "tool_spare_tire", "repair_kit"]:
		return REPAIR_KIT_ID
	return product_id

func add_item(product_id: String, count := 1) -> void:
	if count <= 0: return
	var key := normalize_item_id(product_id)
	items[key] = items.get(key, 0) + count
	item_count_changed.emit(key, items[key])

func remove_item(product_id: String, count := 1) -> bool:
	if count <= 0: return false
	var key := normalize_item_id(product_id)
	var current: int = items.get(key, 0)
	if current < count: return false
	
	items[key] = maxi(0, current - count)
	if items[key] == 0:
		items.erase(key)
	item_count_changed.emit(key, items.get(key, 0))
	return true

func has_item(product_id: String, count := 1) -> bool:
	var key := normalize_item_id(product_id)
	return items.get(key, 0) >= count

func get_item_count(product_id: String) -> int:
	var key := normalize_item_id(product_id)
	return maxi(0, int(items.get(key, 0)))

func is_upgrade_owned(upgrade_id: String) -> bool:
	return owned_upgrades.get(upgrade_id, false)

func unlock_upgrade(upgrade_id: String) -> bool:
	if owned_upgrades.get(upgrade_id, false):
		return false # Already owned
	owned_upgrades[upgrade_id] = true
	upgrade_unlocked.emit(upgrade_id)
	return true

func is_furniture_owned(furniture_id: String) -> bool:
	var val: Variant = owned_furniture.get(furniture_id, false)
	if val is bool: return val
	return int(val) > 0

func get_furniture_count(furniture_id: String) -> int:
	var val: Variant = owned_furniture.get(furniture_id, 0)
	if val is bool: return 1 if val else 0
	return maxi(0, int(val))

func unlock_furniture(furniture_id: String, count := 1, allow_multiple := false) -> bool:
	if not allow_multiple and is_furniture_owned(furniture_id):
		return false # Already owned unique furniture
	var current := get_furniture_count(furniture_id)
	owned_furniture[furniture_id] = current + maxi(1, count)
	furniture_unlocked.emit(furniture_id)
	return true

func get_all_owned_upgrades() -> Array[String]:
	var list: Array[String] = []
	for k in owned_upgrades.keys():
		list.append(str(k))
	return list

func get_all_owned_furniture() -> Array[String]:
	var list: Array[String] = []
	for k in owned_furniture.keys():
		list.append(str(k))
	return list

func ensure_starter_supplies() -> void:
	# Called only for a new save, never when an existing inventory is empty.
	add_item("seed_lettuce", 2)
	add_item("pet_food_salmon", 2)
	add_item(REPAIR_KIT_ID, 5)
	add_item("ing_rice_noodle", 2)
