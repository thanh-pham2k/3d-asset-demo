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
		"grow_duration_sec": 5,
		"harvest_yield": 2,
		"sell_price": 8,
		"tags": ["vegetable", "soup_base"]
	})

static func load_all_crops() -> Dictionary:
	var crops: Dictionary = {}
	var dir := DirAccess.open("res://data/crops")
	if dir != null:
		dir.list_dir_begin()
		var fname: String = dir.get_next()
		while fname != "":
			if not dir.current_is_dir() and fname.ends_with(".json"):
				var cfg := load_json_dict("res://data/crops/" + fname, {
					"id": fname.get_basename(),
					"display_name": fname.get_basename().capitalize(),
					"seed_cost": 5,
					"grow_duration_sec": 10,
					"harvest_yield": 1,
					"sell_price": 8,
					"tags": []
				})
				var cid := String(cfg.get("id", ""))
				if cid != "":
					crops[cid] = cfg
			fname = dir.get_next()
		dir.list_dir_end()
	if not crops.has("carrot"):
		crops["carrot"] = load_crop_carrot()
	return crops

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
		"total_plots": 12,
		"unlock_plot_cost": 120
	})

static func load_inventory_upgrade() -> Dictionary:
	return load_json_dict("res://data/upgrades/inventory_upgrade.json", {
		"initial_capacity": 20,
		"capacity_step": 10,
		"base_upgrade_cost": 50,
		"cost_step": 50,
		"max_capacity": 100
	})

static func load_orders_catalog() -> Dictionary:
	return load_json_dict("res://data/orders/orders_catalog.json", {
		"refresh_cooldown_sec": 30,
		"max_slots": 3,
		"templates": [load_order_carrot()]
	})

static func load_levels() -> Dictionary:
	return load_json_dict("res://data/progression/levels.json", {
		"levels": [
			{"level": 1, "xp_required": 0, "unlocks": ["carrot", "scallion"], "goal": "Giao đơn kiếm XP!"}
		]
	})

static func load_production_recipes() -> Dictionary:
	return load_json_dict("res://data/production/recipes.json", {
		"initial_slots": 2,
		"max_slots": 5,
		"slot_upgrade_base_cost": 80,
		"slot_upgrade_cost_step": 80,
		"recipes": []
	})

static func load_restaurant_hu_tieu() -> Dictionary:
	return load_json_dict("res://data/restaurant/hu_tieu.json", {
		"unlock_level": 2,
		"unlock_cost": 100,
		"initial_kitchen_slots": 1,
		"max_kitchen_slots": 4,
		"initial_table_slots": 2,
		"max_table_slots": 5,
		"starter_dishes": ["hu_tieu_chay", "hu_tieu_toi"],
		"dishes": [],
		"special_customers": []
	})

static func load_automation_staff() -> Dictionary:
	return load_json_dict("res://data/automation/staff.json", {
		"max_offline_sec": 14400,
		"offline_step_sec": 5,
		"prep_helper": {"hire_cost": 90, "unlock_level": 1, "max_level": 3, "upgrade_costs": [100, 200], "actions_per_cycle": [1, 2, 3]},
		"hu_tieu_chef": {"hire_cost": 160, "unlock_level": 2, "max_level": 3, "upgrade_costs": [140, 260], "actions_per_cycle": [1, 2, 3]}
	})

static func load_home_furniture() -> Dictionary:
	return load_json_dict("res://data/home/furniture.json", {
		"rooms": [{"id": "living_room", "display_name": "Phòng Khách", "unlock_cost": 0, "slots": 4, "unlocked_by_default": true}],
		"items": [],
		"interactions": []
	})

static func load_pets_config() -> Dictionary:
	return load_json_dict("res://data/pets/pets.json", {
		"pet": {"id": "miu_miu", "display_name": "Miu Miu", "species": "Mèo tam thể", "ascii_idle": "=^._.^="},
		"items": [],
		"behaviors": [],
		"milestones": []
	})

static func load_garage_config() -> Dictionary:
	return load_json_dict("res://data/garage/garage.json", {
		"unlock_level": 2,
		"unlock_cost": 120,
		"vehicles": [],
		"routes": []
	})

static func load_neighborhood_config() -> Dictionary:
	return load_json_dict("res://data/neighborhood/npcs.json", {
		"areas": [],
		"npcs": []
	})

static func load_goals_config() -> Dictionary:
	return load_json_dict("res://data/goals/goals.json", {
		"daily_objectives": [],
		"weekly_goals": [],
		"long_term_milestones": []
	})
