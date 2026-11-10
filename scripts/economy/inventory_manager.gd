class_name InventoryManager
extends RefCounted

## Tracks inventory of consumable supplies (ingredients, tools)
## and ownership of unique purchases (furniture, house & business upgrades).

signal item_count_changed(product_id: String, new_count: int)
signal upgrade_unlocked(upgrade_id: String)
signal furniture_unlocked(furniture_id: String)

# Consumable items: product_id -> int quantity
var items: Dictionary = {}

# Unique owned upgrades: upgrade_id -> true
var owned_upgrades: Dictionary = {}

# Unique owned furniture: furniture_id -> true
var owned_furniture: Dictionary = {}

func add_item(product_id: String, count := 1) -> void:
	if count <= 0: return
	items[product_id] = items.get(product_id, 0) + count
	item_count_changed.emit(product_id, items[product_id])

func remove_item(product_id: String, count := 1) -> bool:
	if count <= 0: return false
	var current: int = items.get(product_id, 0)
	if current < count: return false
	
	items[product_id] = current - count
	if items[product_id] == 0:
		items.erase(product_id)
	item_count_changed.emit(product_id, items.get(product_id, 0))
	return true

func has_item(product_id: String, count := 1) -> bool:
	return items.get(product_id, 0) >= count

func get_item_count(product_id: String) -> int:
	return items.get(product_id, 0)

func is_upgrade_owned(upgrade_id: String) -> bool:
	return owned_upgrades.get(upgrade_id, false)

func unlock_upgrade(upgrade_id: String) -> bool:
	if owned_upgrades.get(upgrade_id, false):
		return false # Already owned
	owned_upgrades[upgrade_id] = true
	upgrade_unlocked.emit(upgrade_id)
	return true

func is_furniture_owned(furniture_id: String) -> bool:
	return owned_furniture.get(furniture_id, false)

func unlock_furniture(furniture_id: String) -> bool:
	if owned_furniture.get(furniture_id, false):
		return false # Already owned
	owned_furniture[furniture_id] = true
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
