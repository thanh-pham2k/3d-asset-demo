class_name SaveManager
extends RefCounted
## Persists Game Core state with atomic writes, v1->v2->v3 schema migrations, and offline progress.

const SAVE_VERSION := 11
const DEFAULT_SAVE_PATH := "user://save_very_mvp.json"

static func save_game(
	clock: GameClock,
	wallet: Wallet,
	inventory: Inventory,
	farm: FarmSystem,
	path: String = DEFAULT_SAVE_PATH,
	selected_crop_id: String = "carrot",
	progression: ProgressionSystem = null,
	order_board: OrderBoard = null,
	production: ProductionSystem = null,
	restaurant: RestaurantSystem = null,
	automation: AutomationSystem = null,
	home: HomeSystem = null,
	pets: PetSystem = null,
	garage: GarageSystem = null,
	neighborhood: NeighborhoodSystem = null,
	goals: GoalsSystem = null
) -> bool:
	var plots_data: Array[Dictionary] = []
	for plot in farm.plots:
		plots_data.append({
			"id": plot.id,
			"state": plot.state_name(),
			"crop_id": plot.crop_id,
			"planted_at_unix": plot.timer.planted_at_unix,
			"grow_duration_sec": plot.timer.grow_duration_sec
		})

	var prog_dict := progression.to_dict() if progression != null else {
		"level": 1, "xp": 0, "completed_orders": 0, "unlocked_ids": ["carrot", "scallion"]
	}
	var orders_dict := order_board.to_dict() if order_board != null else {
		"slots": [], "slot_cooldowns": {}, "next_seq": 0
	}
	var prod_dict := production.to_dict() if production != null else {
		"max_slots": 2, "queue": [], "next_job_seq": 0
	}
	var rest_dict := restaurant.to_dict() if restaurant != null else {
		"is_unlocked": false, "kitchen_slots": 1, "table_slots": 2,
		"unlocked_dishes": ["hu_tieu_chay", "hu_tieu_toi"], "special_served_ids": [],
		"customers": [], "cooking_queue": [], "served_count": 0, "next_seq": 0
	}
	var auto_dict := automation.to_dict() if automation != null else {
		"prep_hired": false, "prep_level": 1, "prep_enabled": true, "prep_priority_recipe": "auto",
		"chef_hired": false, "chef_level": 1, "chef_enabled": true, "chef_priority": "special_first"
	}
	var home_dict := home.to_dict() if home != null else {
		"active_character": "boy", "active_room_id": "living_room", "unlocked_rooms": ["living_room"],
		"owned_furniture": [], "placements": {}, "cozy_moments_count": 0, "last_moment": ""
	}
	var pets_dict := pets.to_dict() if pets != null else {
		"mood": "happy", "equipped_accessory": "", "active_bed": "",
		"owned_items": [], "claimed_milestones": [], "interactions_count": 0, "last_reaction": ""
	}
	var garage_dict := garage.to_dict() if garage != null else {
		"is_unlocked": false, "repaired_vehicles": [], "speed_level": 1, "capacity_level": 1,
		"active_deliveries": [], "claimed_route_rewards": [], "auto_dispatch_enabled": false,
		"auto_route_id": "route_market", "delivered_count": 0, "next_seq": 0
	}
	var neigh_dict := neighborhood.to_dict() if neighborhood != null else {
		"active_area_id": "alley_corner", "unlocked_areas": ["alley_corner"], "built_areas": [],
		"npc_helps": {}, "npc_chats": {}, "claimed_stories": [], "last_story_text": ""
	}
	var goals_dict := goals.to_dict() if goals != null else {
		"daily_metrics": {"harvests": 0, "orders_or_deliveries": 0, "cozy_actions": 0}, "claimed_daily": [],
		"weekly_metrics": {}, "claimed_weekly": [], "total_harvests": 0, "total_dishes": 0,
		"total_crafted": 0, "total_deliveries": 0, "total_orders": 0, "total_npc_helps": 0,
		"claimed_milestones": [], "discovered_crops": [], "discovered_recipes": [], "discovered_dishes": []
	}

	var payload := {
		"save_version": SAVE_VERSION,
		"saved_at_real_unix": int(Time.get_unix_time_from_system()),
		"clock_offset_sec": clock.get_offset(),
		"wallet_coins": maxi(0, wallet.balance),
		"inventory_capacity": maxi(1, inventory.capacity),
		"inventory_items": inventory.get_all_items(),
		"selected_crop_id": selected_crop_id,
		"plots": plots_data,
		"progression": prog_dict,
		"orders": orders_dict,
		"production": prod_dict,
		"restaurant": rest_dict,
		"automation": auto_dict,
		"home": home_dict,
		"pets": pets_dict,
		"garage": garage_dict,
		"neighborhood": neigh_dict,
		"goals": goals_dict
	}

	var json_text := JSON.stringify(payload, "\t")
	var tmp_path := path + ".tmp"
	var tmp_file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if tmp_file == null:
		return false
	tmp_file.store_string(json_text)
	tmp_file.flush()
	tmp_file = null

	var abs_path := ProjectSettings.globalize_path(path)
	var abs_tmp := ProjectSettings.globalize_path(tmp_path)
	var abs_bak := ProjectSettings.globalize_path(path + ".bak")
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(abs_path, abs_bak)
	var err := DirAccess.rename_absolute(abs_tmp, abs_path)
	return err == OK

static func load_game(
	clock: GameClock,
	wallet: Wallet,
	inventory: Inventory,
	farm: FarmSystem,
	path: String = DEFAULT_SAVE_PATH,
	progression: ProgressionSystem = null,
	order_board: OrderBoard = null,
	production: ProductionSystem = null,
	restaurant: RestaurantSystem = null,
	automation: AutomationSystem = null,
	home: HomeSystem = null,
	pets: PetSystem = null,
	garage: GarageSystem = null,
	neighborhood: NeighborhoodSystem = null,
	goals: GoalsSystem = null
) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"loaded": false, "error": "missing", "offline_elapsed": 0, "matured_count": 0}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"loaded": false, "error": "unreadable", "offline_elapsed": 0, "matured_count": 0}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file = null
	if typeof(parsed) != TYPE_DICTIONARY:
		_quarantine_corrupt_save(path)
		return {"loaded": false, "error": "corrupted", "offline_elapsed": 0, "matured_count": 0}

	var data := (parsed as Dictionary).duplicate(true)
	var orig_ver := int(data.get("save_version", 0))
	if orig_ver <= 0 or orig_ver > SAVE_VERSION:
		return {
			"loaded": false,
			"error": "unsupported_version",
			"save_version": orig_ver,
			"offline_elapsed": 0,
			"matured_count": 0
		}

	var migrated := false
	if orig_ver == 1:
		if not _is_valid_v1_payload(data):
			_quarantine_corrupt_save(path)
			return {"loaded": false, "error": "corrupted", "offline_elapsed": 0, "matured_count": 0}
		data = _migrate_v1_to_v2(data)
		migrated = true

	if int(data.get("save_version", 0)) == 2:
		if not _is_valid_v2_payload(data):
			_quarantine_corrupt_save(path)
			return {"loaded": false, "error": "corrupted", "offline_elapsed": 0, "matured_count": 0}
		data = _migrate_v2_to_v3(data)
		migrated = true

	if int(data.get("save_version", 0)) == 3:
		if not _is_valid_v3_payload(data):
			_quarantine_corrupt_save(path)
			return {"loaded": false, "error": "corrupted", "offline_elapsed": 0, "matured_count": 0}
		data = _migrate_v3_to_v4(data)
		migrated = true

	if int(data.get("save_version", 0)) == 4:
		if not _is_valid_v4_payload(data):
			_quarantine_corrupt_save(path)
			return {"loaded": false, "error": "corrupted", "offline_elapsed": 0, "matured_count": 0}
		data = _migrate_v4_to_v5(data)
		migrated = true

	if int(data.get("save_version", 0)) == 5:
		if not _is_valid_v5_payload(data):
			_quarantine_corrupt_save(path)
			return {"loaded": false, "error": "corrupted", "offline_elapsed": 0, "matured_count": 0}
		data = _migrate_v5_to_v6(data)
		migrated = true

	if int(data.get("save_version", 0)) == 6:
		if not _is_valid_v6_payload(data):
			_quarantine_corrupt_save(path)
			return {"loaded": false, "error": "corrupted", "offline_elapsed": 0, "matured_count": 0}
		data = _migrate_v6_to_v7(data)
		migrated = true

	if int(data.get("save_version", 0)) == 7:
		if not _is_valid_v7_payload(data):
			_quarantine_corrupt_save(path)
			return {"loaded": false, "error": "corrupted", "offline_elapsed": 0, "matured_count": 0}
		data = _migrate_v7_to_v8(data)
		migrated = true

	if int(data.get("save_version", 0)) == 8:
		if not _is_valid_v8_payload(data):
			_quarantine_corrupt_save(path)
			return {"loaded": false, "error": "corrupted", "offline_elapsed": 0, "matured_count": 0}
		data = _migrate_v8_to_v9(data)
		migrated = true

	if int(data.get("save_version", 0)) == 9:
		if not _is_valid_v9_payload(data):
			_quarantine_corrupt_save(path)
			return {"loaded": false, "error": "corrupted", "offline_elapsed": 0, "matured_count": 0}
		data = _migrate_v9_to_v10(data)
		migrated = true

	if int(data.get("save_version", 0)) == 10:
		if not _is_valid_v10_payload(data):
			_quarantine_corrupt_save(path)
			return {"loaded": false, "error": "corrupted", "offline_elapsed": 0, "matured_count": 0}
		data = _migrate_v10_to_v11(data)
		migrated = true

	if not _is_valid_v11_payload(data):
		_quarantine_corrupt_save(path)
		return {"loaded": false, "error": "corrupted", "offline_elapsed": 0, "matured_count": 0}

	# All validation passed — apply atomically to Game Core state.
	var saved_real_unix := int(data["saved_at_real_unix"])
	var offline_sec := clock.offline_elapsed(saved_real_unix)
	clock.set_offset(maxi(0, int(data["clock_offset_sec"])))

	wallet.set_balance(maxi(0, int(data["wallet_coins"])))
	inventory.set_capacity(maxi(1, int(data["inventory_capacity"])))
	inventory.set_all_items(data["inventory_items"] as Dictionary)

	for entry in (data["plots"] as Array):
		var p_dict := entry as Dictionary
		var pid := int(p_dict.get("id", -1))
		var plot := farm.get_plot(pid)
		if plot == null:
			continue
		var parsed_state := FarmPlot.parse_state(String(p_dict.get("state", "EMPTY")))
		var crop_id := String(p_dict.get("crop_id", ""))
		var planted_at := int(p_dict.get("planted_at_unix", 0))
		var duration := maxi(1, int(p_dict.get("grow_duration_sec", 300)))
		if parsed_state == FarmPlot.State.GROWING and (crop_id == "" or planted_at <= 0):
			parsed_state = FarmPlot.State.EMPTY
			crop_id = ""
			planted_at = 0
		plot.state = parsed_state
		plot.crop_id = crop_id
		plot.timer.planted_at_unix = planted_at
		plot.timer.grow_duration_sec = duration

	if progression != null:
		progression.load_from_dict(data["progression"] as Dictionary)
	var lv := progression.level if progression != null else 1
	if order_board != null:
		order_board.load_from_dict(data["orders"] as Dictionary, lv, clock)
	var prod_completed := 0
	if production != null:
		production.load_from_dict(data["production"] as Dictionary, clock)
		for j in production.queue:
			if String(j.get("status", "")) == "READY":
				prod_completed += 1
	if restaurant != null:
		restaurant.load_from_dict(data["restaurant"] as Dictionary, lv, clock)
	if automation != null:
		automation.load_from_dict(data["automation"] as Dictionary)
	if home != null:
		home.load_from_dict(data["home"] as Dictionary)
	if pets != null:
		pets.load_from_dict(data["pets"] as Dictionary)
	if garage != null:
		garage.load_from_dict(data["garage"] as Dictionary, clock)
	if neighborhood != null:
		neighborhood.load_from_dict(data["neighborhood"] as Dictionary)
	if goals != null:
		goals.load_from_dict(data["goals"] as Dictionary)

	var matured_count := farm.tick(clock)
	return {
		"loaded": true,
		"save_version": SAVE_VERSION,
		"migrated_from": orig_ver if migrated else 0,
		"selected_crop_id": String(data.get("selected_crop_id", "carrot")),
		"offline_elapsed": offline_sec,
		"matured_count": matured_count,
		"prod_ready_count": prod_completed
	}

static func _migrate_v1_to_v2(v1: Dictionary) -> Dictionary:
	var out := v1.duplicate(true)
	var carrots := maxi(0, int(v1.get("inventory_carrots", 0)))
	var items_dict: Dictionary = {}
	if carrots > 0:
		items_dict["carrot"] = carrots
	out.erase("inventory_carrots")
	out["inventory_items"] = items_dict
	out["inventory_capacity"] = int(v1.get("inventory_capacity", 20))
	out["selected_crop_id"] = String(v1.get("selected_crop_id", "carrot"))
	out["save_version"] = 2
	return out

static func _migrate_v2_to_v3(v2: Dictionary) -> Dictionary:
	var out := v2.duplicate(true)
	if not out.has("progression") or typeof(out["progression"]) != TYPE_DICTIONARY:
		out["progression"] = {
			"level": 1,
			"xp": 0,
			"completed_orders": 0,
			"unlocked_ids": ["carrot", "scallion"]
		}
	if not out.has("orders") or typeof(out["orders"]) != TYPE_DICTIONARY:
		out["orders"] = {
			"slots": [],
			"slot_cooldowns": {},
			"next_seq": 0
		}
	out["save_version"] = 3
	return out

static func _migrate_v3_to_v4(v3: Dictionary) -> Dictionary:
	var out := v3.duplicate(true)
	if not out.has("production") or typeof(out["production"]) != TYPE_DICTIONARY:
		out["production"] = {
			"max_slots": 2,
			"queue": [],
			"next_job_seq": 0
		}
	out["save_version"] = 4
	return out

static func _migrate_v4_to_v5(v4: Dictionary) -> Dictionary:
	var out := v4.duplicate(true)
	if not out.has("restaurant") or typeof(out["restaurant"]) != TYPE_DICTIONARY:
		out["restaurant"] = {
			"is_unlocked": false,
			"kitchen_slots": 1,
			"table_slots": 2,
			"unlocked_dishes": ["hu_tieu_chay", "hu_tieu_toi"],
			"special_served_ids": [],
			"customers": [],
			"cooking_queue": [],
			"served_count": 0,
			"next_seq": 0
		}
	out["save_version"] = 5
	return out

static func _migrate_v5_to_v6(v5: Dictionary) -> Dictionary:
	var out := v5.duplicate(true)
	if not out.has("automation") or typeof(out["automation"]) != TYPE_DICTIONARY:
		out["automation"] = {
			"prep_hired": false,
			"prep_level": 1,
			"prep_enabled": true,
			"prep_priority_recipe": "auto",
			"chef_hired": false,
			"chef_level": 1,
			"chef_enabled": true,
			"chef_priority": "special_first"
		}
	out["save_version"] = 6
	return out

static func _migrate_v6_to_v7(v6: Dictionary) -> Dictionary:
	var out := v6.duplicate(true)
	if not out.has("home") or typeof(out["home"]) != TYPE_DICTIONARY:
		out["home"] = {
			"active_character": "boy",
			"active_room_id": "living_room",
			"unlocked_rooms": ["living_room"],
			"owned_furniture": [],
			"placements": {},
			"cozy_moments_count": 0,
			"last_moment": ""
		}
	out["save_version"] = 7
	return out

static func _migrate_v7_to_v8(v7: Dictionary) -> Dictionary:
	var out := v7.duplicate(true)
	if not out.has("pets") or typeof(out["pets"]) != TYPE_DICTIONARY:
		out["pets"] = {
			"mood": "happy",
			"equipped_accessory": "",
			"active_bed": "",
			"owned_items": [],
			"claimed_milestones": [],
			"interactions_count": 0,
			"last_reaction": ""
		}
	out["save_version"] = 8
	return out

static func _migrate_v8_to_v9(v8: Dictionary) -> Dictionary:
	var out := v8.duplicate(true)
	if not out.has("garage") or typeof(out["garage"]) != TYPE_DICTIONARY:
		out["garage"] = {
			"is_unlocked": false,
			"repaired_vehicles": [],
			"speed_level": 1,
			"capacity_level": 1,
			"active_deliveries": [],
			"claimed_route_rewards": [],
			"auto_dispatch_enabled": false,
			"auto_route_id": "route_market",
			"delivered_count": 0,
			"next_seq": 0
		}
	out["save_version"] = 9
	return out

static func _migrate_v9_to_v10(v9: Dictionary) -> Dictionary:
	var out := v9.duplicate(true)
	if not out.has("neighborhood") or typeof(out["neighborhood"]) != TYPE_DICTIONARY:
		out["neighborhood"] = {
			"active_area_id": "alley_corner",
			"unlocked_areas": ["alley_corner"],
			"built_areas": [],
			"npc_helps": {},
			"npc_chats": {},
			"claimed_stories": [],
			"last_story_text": ""
		}
	out["save_version"] = 10
	return out

static func _migrate_v10_to_v11(v10: Dictionary) -> Dictionary:
	var out := v10.duplicate(true)
	if not out.has("goals") or typeof(out["goals"]) != TYPE_DICTIONARY:
		out["goals"] = {
			"daily_metrics": {"harvests": 0, "orders_or_deliveries": 0, "cozy_actions": 0},
			"claimed_daily": [],
			"weekly_metrics": {},
			"claimed_weekly": [],
			"total_harvests": 0,
			"total_dishes": 0,
			"total_crafted": 0,
			"total_deliveries": 0,
			"total_orders": 0,
			"total_npc_helps": 0,
			"claimed_milestones": [],
			"discovered_crops": [],
			"discovered_recipes": [],
			"discovered_dishes": []
		}
	out["save_version"] = 11
	return out

static func _is_valid_v1_payload(data: Dictionary) -> bool:
	for key in ["saved_at_real_unix", "clock_offset_sec", "wallet_coins", "inventory_carrots", "plots"]:
		if not data.has(key):
			return false
	if int(data["wallet_coins"]) < 0 or int(data["inventory_carrots"]) < 0:
		return false
	if int(data["clock_offset_sec"]) < 0 or int(data["saved_at_real_unix"]) < 0:
		return false
	return _is_valid_plots_array(data["plots"])

static func _is_valid_v2_payload(data: Dictionary) -> bool:
	for key in ["saved_at_real_unix", "clock_offset_sec", "wallet_coins", "inventory_capacity", "inventory_items", "plots"]:
		if not data.has(key):
			return false
	if int(data["wallet_coins"]) < 0 or int(data["inventory_capacity"]) < 1:
		return false
	if int(data["clock_offset_sec"]) < 0 or int(data["saved_at_real_unix"]) < 0:
		return false
	var items_raw: Variant = data["inventory_items"]
	if typeof(items_raw) != TYPE_DICTIONARY:
		return false
	for k in (items_raw as Dictionary).keys():
		if int((items_raw as Dictionary)[k]) < 0:
			return false
	return _is_valid_plots_array(data["plots"])

static func _is_valid_v3_payload(data: Dictionary) -> bool:
	if not _is_valid_v2_payload(data):
		return false
	if not data.has("progression") or typeof(data["progression"]) != TYPE_DICTIONARY:
		return false
	if not data.has("orders") or typeof(data["orders"]) != TYPE_DICTIONARY:
		return false
	var prog := data["progression"] as Dictionary
	if int(prog.get("level", 0)) < 1 or int(prog.get("xp", -1)) < 0:
		return false
	return true

static func _is_valid_v4_payload(data: Dictionary) -> bool:
	if not _is_valid_v3_payload(data):
		return false
	if not data.has("production") or typeof(data["production"]) != TYPE_DICTIONARY:
		return false
	var prod := data["production"] as Dictionary
	if int(prod.get("max_slots", 0)) < 1 or typeof(prod.get("queue", null)) != TYPE_ARRAY:
		return false
	return true

static func _is_valid_v5_payload(data: Dictionary) -> bool:
	if not _is_valid_v4_payload(data):
		return false
	if not data.has("restaurant") or typeof(data["restaurant"]) != TYPE_DICTIONARY:
		return false
	return true

static func _is_valid_v6_payload(data: Dictionary) -> bool:
	if not _is_valid_v5_payload(data):
		return false
	if not data.has("automation") or typeof(data["automation"]) != TYPE_DICTIONARY:
		return false
	return true

static func _is_valid_v7_payload(data: Dictionary) -> bool:
	if not _is_valid_v6_payload(data):
		return false
	if not data.has("home") or typeof(data["home"]) != TYPE_DICTIONARY:
		return false
	return true

static func _is_valid_v8_payload(data: Dictionary) -> bool:
	if not _is_valid_v7_payload(data):
		return false
	if not data.has("pets") or typeof(data["pets"]) != TYPE_DICTIONARY:
		return false
	return true

static func _is_valid_v9_payload(data: Dictionary) -> bool:
	if not _is_valid_v8_payload(data):
		return false
	if not data.has("garage") or typeof(data["garage"]) != TYPE_DICTIONARY:
		return false
	return true

static func _is_valid_v10_payload(data: Dictionary) -> bool:
	if not _is_valid_v9_payload(data):
		return false
	if not data.has("neighborhood") or typeof(data["neighborhood"]) != TYPE_DICTIONARY:
		return false
	return true

static func _is_valid_v11_payload(data: Dictionary) -> bool:
	if not _is_valid_v10_payload(data):
		return false
	if not data.has("goals") or typeof(data["goals"]) != TYPE_DICTIONARY:
		return false
	return true

static func _is_valid_plots_array(plots_raw: Variant) -> bool:
	if typeof(plots_raw) != TYPE_ARRAY:
		return false
	for entry in (plots_raw as Array):
		if typeof(entry) != TYPE_DICTIONARY:
			return false
		var p_dict := entry as Dictionary
		if not p_dict.has("id") or not p_dict.has("state"):
			return false
	return true

static func _quarantine_corrupt_save(path: String) -> void:
	if FileAccess.file_exists(path):
		var abs_path := ProjectSettings.globalize_path(path)
		var abs_corrupt := ProjectSettings.globalize_path(path + ".corrupt")
		DirAccess.rename_absolute(abs_path, abs_corrupt)

static func reset_save(path: String = DEFAULT_SAVE_PATH) -> void:
	for suffix: String in ["", ".tmp", ".bak", ".corrupt"]:
		var target: String = path + suffix
		if FileAccess.file_exists(target):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(target))
