class_name BalanceLoader
extends RefCounted
## Loads data-driven JSON balance configs from data/ with safe fallback defaults.

static func load_json_dict(path: String, fallback: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(path):
		return fallback.duplicate(true)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return fallback.duplicate(true)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return fallback.duplicate(true)
	var merged := fallback.duplicate(true)
	for k in (parsed as Dictionary).keys():
		merged[k] = parsed[k]
	return merged

static func load_crop_carrot() -> Dictionary:
	return load_json_dict("res://data/crops/carrot.json", {
		"id": "carrot",
		"display_name": "Cà rốt",
		"seed_cost": 5,
		"grow_duration_sec": 300,
		"harvest_yield": 2
	})

static func load_order_carrot() -> Dictionary:
	return load_json_dict("res://data/orders/carrot_order.json", {
		"id": "order_carrot_4",
		"title": "Đơn hàng Cà rốt tươi",
		"item_id": "carrot",
		"required_count": 4,
		"reward_coins": 60
	})

static func load_farm_upgrade() -> Dictionary:
	return load_json_dict("res://data/upgrades/farm_plot_unlock.json", {
		"starting_coins": 100,
		"initial_unlocked_plots": 4,
		"total_plots": 6,
		"unlock_plot_cost": 120
	})
