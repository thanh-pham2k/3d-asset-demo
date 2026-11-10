class_name HouseStorage
extends RefCounted

## Tracks unplaced owned furniture delivered to the house.

var unplaced_items: Array[String] = []

func add_item(furniture_id: String) -> void:
	unplaced_items.append(furniture_id)

func remove_item(furniture_id: String) -> bool:
	var idx := unplaced_items.find(furniture_id)
	if idx != -1:
		unplaced_items.remove_at(idx)
		return true
	return false

func get_items() -> Array[String]:
	return unplaced_items.duplicate()

func sync_with_inventory(inventory: InventoryManager, placed_list: Array) -> void:
	if not inventory: return
	unplaced_items.clear()
	
	# Count how many of each furniture item are placed
	var placed_counts := {}
	for p in placed_list:
		if p is Dictionary and p.has("id"):
			var fid: String = p["id"]
			placed_counts[fid] = placed_counts.get(fid, 0) + 1
			
	# For each owned furniture in inventory, if owned count > placed count, add to unplaced
	for fid in inventory.owned_furniture:
		var placed_count: int = placed_counts.get(fid, 0)
		# Unique furniture: 1 owned
		if placed_count < 1:
			unplaced_items.append(fid)
