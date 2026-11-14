class_name Inventory
extends RefCounted
## Shared multi-item storage with configurable capacity and atomic add/remove checks.

signal inventory_changed(item_id: String, new_count: int)
signal capacity_changed(new_capacity: int)

var items: Dictionary = {}
var capacity: int = 20

func _init(initial_capacity: int = 20) -> void:
	capacity = maxi(1, initial_capacity)

func get_count(item_id: String = "carrot") -> int:
	return int(items.get(item_id, 0))

func get_total_count() -> int:
	var total := 0
	for key in items.keys():
		total += maxi(0, int(items[key]))
	return total

func get_free_space() -> int:
	return maxi(0, capacity - get_total_count())

func can_add(count: int) -> bool:
	return count >= 0 and get_free_space() >= count

func has_item(item_id: String, count: int) -> bool:
	return count >= 0 and get_count(item_id) >= count

func add_item(item_id: String, count: int) -> bool:
	if item_id == "" or count <= 0:
		return false
	if not can_add(count):
		return false
	var next := get_count(item_id) + count
	items[item_id] = next
	inventory_changed.emit(item_id, next)
	return true

func remove_item(item_id: String, count: int) -> bool:
	if item_id == "" or count < 0 or not has_item(item_id, count):
		return false
	var next := get_count(item_id) - count
	if next <= 0:
		items.erase(item_id)
		next = 0
	else:
		items[item_id] = next
	inventory_changed.emit(item_id, next)
	return true

func set_count(item_id: String, count: int) -> void:
	if item_id == "":
		return
	var next := maxi(0, count)
	if next == 0:
		items.erase(item_id)
	else:
		items[item_id] = next
	inventory_changed.emit(item_id, next)

func set_all_items(new_items: Dictionary) -> void:
	items.clear()
	for key in new_items.keys():
		var cid := String(key)
		var cnt := maxi(0, int(new_items[key]))
		if cid != "" and cnt > 0:
			items[cid] = cnt
	inventory_changed.emit("", get_total_count())

func clear_all() -> void:
	items.clear()
	inventory_changed.emit("", 0)

func set_capacity(new_capacity: int) -> void:
	capacity = maxi(1, new_capacity)
	capacity_changed.emit(capacity)

func upgrade_capacity(step: int) -> void:
	if step <= 0:
		return
	capacity += step
	capacity_changed.emit(capacity)

func get_all_items() -> Dictionary:
	return items.duplicate(true)
