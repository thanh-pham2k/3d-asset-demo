class_name Inventory
extends RefCounted
## Stores harvested produce counts (carrots in VERY MVP).

signal inventory_changed(item_id: String, new_count: int)

var items: Dictionary = {}

func get_count(item_id: String = "carrot") -> int:
	return int(items.get(item_id, 0))

func has_item(item_id: String, count: int) -> bool:
	return count >= 0 and get_count(item_id) >= count

func add_item(item_id: String, count: int) -> void:
	if item_id == "" or count <= 0:
		return
	var next := get_count(item_id) + count
	items[item_id] = next
	inventory_changed.emit(item_id, next)

func remove_item(item_id: String, count: int) -> bool:
	if item_id == "" or count < 0 or not has_item(item_id, count):
		return false
	var next := get_count(item_id) - count
	items[item_id] = next
	inventory_changed.emit(item_id, next)
	return true

func set_count(item_id: String, count: int) -> void:
	if item_id == "":
		return
	var next := maxi(0, count)
	items[item_id] = next
	inventory_changed.emit(item_id, next)
