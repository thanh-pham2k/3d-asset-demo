class_name EconomySaveSystem
extends RefCounted

## Robust JSON serialization and deserialization for the economy system.
## Supports atomic writes, schema validation, isolated test paths, and graceful recovery from missing or corrupted files.

const DEFAULT_SAVE_PATH: String = "user://couple_chaos_economy.json"
static var active_save_path: String = DEFAULT_SAVE_PATH

static func get_effective_path(path: String = "") -> String:
	if path != "" and path != DEFAULT_SAVE_PATH:
		return path
	if active_save_path != "":
		return active_save_path
	return DEFAULT_SAVE_PATH

static func _is_number_like(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] or (value is String and value.is_valid_float())

static func is_usable_save(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if not (data.get("wallet", null) is Dictionary and data.get("inventory", null) is Dictionary):
		return false
	var wallet_data: Dictionary = data["wallet"]
	var inventory_data: Dictionary = data["inventory"]
	for key in ["balance", "total_earned", "total_spent"]:
		if wallet_data.has(key) and not _is_number_like(wallet_data[key]):
			return false
	for key in ["processed_ids", "history"]:
		if wallet_data.has(key) and not wallet_data[key] is Array:
			return false
	for key in ["items", "owned_upgrades", "owned_furniture"]:
		if inventory_data.has(key) and not inventory_data[key] is Dictionary:
			return false
	for amount in inventory_data.get("items", {}).values():
		if not _is_number_like(amount): return false
	for amount in inventory_data.get("owned_furniture", {}).values():
		if not (amount is bool) and not _is_number_like(amount): return false
	var pet: Variant = data.get("pet", null)
	if pet == null and data.get("businesses", null) is Dictionary:
		pet = data["businesses"].get("pet", null)
	if pet != null:
		if not pet is Dictionary: return false
		for key in ["hunger", "thirst", "happiness", "affection"]:
			if pet.has(key) and not _is_number_like(pet[key]): return false
		if pet.has("home_position"):
			var home: Variant = pet["home_position"]
			if not home is Array or home.size() < 3: return false
			for i in range(3):
				if not _is_number_like(home[i]): return false
	var farm: Variant = data.get("farm", null)
	if farm == null and data.get("businesses", null) is Dictionary:
		farm = data["businesses"].get("farm", null)
	if farm != null:
		if not farm is Dictionary: return false
		var farm_plots: Variant = farm.get("plots", [])
		if not farm_plots is Array: return false
		for plot in farm_plots:
			if not plot is Dictionary or not plot.get("plot_id", null) is String: return false
			for key in ["stage", "growth_progress", "growth_hours_accumulated", "last_growth_day"]:
				if plot.has(key) and not _is_number_like(plot[key]): return false
	# Reject malformed placement data before choosing the primary or backup.
	# Otherwise rebuilding the house can fail and a later save can overwrite
	# the only usable copy. Older saves may omit the house or furniture list.
	var house: Variant = data.get("house", null)
	if house == null and data.get("businesses", null) is Dictionary:
		house = data["businesses"].get("house", null)
	if house != null:
		if not house is Dictionary:
			return false
		var furniture: Variant = house.get("placed_furniture", [])
		if not furniture is Array:
			return false
		for entry in furniture:
			if not entry is Dictionary or not entry.get("id", null) is String:
				return false
			var pos: Variant = entry.get("pos", null)
			if not pos is Array or pos.size() < 3:
				return false
			for i in range(3):
				if typeof(pos[i]) not in [TYPE_INT, TYPE_FLOAT]:
					return false
			if entry.has("rot_y") and typeof(entry["rot_y"]) not in [TYPE_INT, TYPE_FLOAT]:
				return false
			if entry.has("state") and not entry["state"] is Dictionary:
				return false
	return true

static func _read_usable_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if is_usable_save(parsed) else {}

static func save_economy(
	wallet: HouseholdWallet,
	inventory: InventoryManager,
	business_data: Dictionary = {},
	house_or_path: Variant = DEFAULT_SAVE_PATH,
	optional_path: String = "",
	pet_data: Dictionary = {},
	farm_data: Dictionary = {}
) -> bool:
	if not wallet or not inventory: return false
	
	var house_data := {}
	var path := DEFAULT_SAVE_PATH
	if house_or_path is Dictionary:
		house_data = house_or_path
		path = optional_path if optional_path != "" else DEFAULT_SAVE_PATH
	elif house_or_path is String:
		path = house_or_path
	
	var target_path := get_effective_path(path)
	var tmp_path := target_path + ".tmp"
	var bak_path := target_path + ".bak"
	
	# Extract pet data if nested in business_data or passed explicitly
	var effective_pet: Dictionary = pet_data
	if effective_pet.is_empty() and business_data.has("pet") and business_data["pet"] is Dictionary:
		effective_pet = business_data["pet"]

	# Extract farm data if nested in business_data or passed explicitly (Requirement 7)
	var effective_farm: Dictionary = farm_data
	if effective_farm.is_empty() and business_data.has("farm") and business_data["farm"] is Dictionary:
		effective_farm = business_data["farm"]

	var data := {
		"version": 1,
		"timestamp": Time.get_unix_time_from_system(),
		"day": int(business_data.get("day", 1)),
		"wallet": {
			"balance": wallet.balance,
			"total_earned": wallet.total_earned,
			"total_spent": wallet.total_spent,
			"processed_ids": wallet.processed_transaction_ids.keys(),
			"history": wallet.transaction_history
		},
		"inventory": {
			"items": inventory.items,
			"owned_upgrades": inventory.owned_upgrades,
			"owned_furniture": inventory.owned_furniture
		},
		"businesses": business_data,
		"house": house_data,
		"pet": effective_pet,
		"farm": effective_farm
	}
	if not is_usable_save(data):
		push_error("Refusing to write an invalid economy snapshot.")
		return false
	
	# Do not replace the only copies with a fresh/default state after failed recovery.
	if (FileAccess.file_exists(target_path) or FileAccess.file_exists(bak_path)) and _read_usable_save(target_path).is_empty() and _read_usable_save(bak_path).is_empty():
		push_error("Economy save and backup are unreadable; refusing to overwrite them.")
		return false

	# Repeated callbacks may save the same snapshot within one frame. Do not
	# replace the previous recovery point solely because the timestamp changed.
	var existing := _read_usable_save(target_path)
	if not existing.is_empty():
		var old_snapshot := existing.duplicate(true)
		var new_snapshot := data.duplicate(true)
		old_snapshot.erase("timestamp")
		new_snapshot.erase("timestamp")
		if old_snapshot == new_snapshot:
			return true

	var json_string := JSON.stringify(data, "\t")
	
	# 1. Write to temporary file first
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if not file:
		printerr("Failed to open temp file for economy save: ", tmp_path)
		return false
	
	file.store_string(json_string)
	file.close()
	
	# Verify the complete payload before touching the previous save.
	var verify := FileAccess.open(tmp_path, FileAccess.READ)
	if not verify or verify.get_as_text() != json_string:
		push_error("Could not verify temporary economy save: " + tmp_path)
		return false
	verify.close()

	# Never remove or truncate the last valid save on a failed replacement.
	if FileAccess.file_exists(target_path):
		var previous := FileAccess.open(target_path, FileAccess.READ)
		if not previous:
			push_error("Could not read existing economy save: " + target_path)
			return false
		var previous_data: Variant = JSON.parse_string(previous.get_as_text())
		previous.close()
		# A corrupt primary may have been recovered from .bak. Do not replace
		# that last valid backup with the corrupt file.
		if is_usable_save(previous_data):
			var copy_err := DirAccess.copy_absolute(target_path, bak_path)
			if copy_err != OK:
				push_error("Could not back up economy save: %d" % copy_err)
				return false
	var rename_err := DirAccess.rename_absolute(tmp_path, target_path)
	if rename_err != OK:
		push_error("Could not replace economy save; previous save retained: %d" % rename_err)
		return false

	return true

static func load_economy(
	wallet: HouseholdWallet,
	inventory: InventoryManager,
	path: String = ""
) -> Dictionary:
	var business_data := {}
	var target_path := get_effective_path(path)
	var bak_path := target_path + ".bak"
	
	var data: Dictionary = {}
	var loaded_successfully := false
	
	# 1. Attempt to load primary save file
	if FileAccess.file_exists(target_path):
		var file := FileAccess.open(target_path, FileAccess.READ)
		if file:
			var content := file.get_as_text()
			file.close()
			var parsed: Variant = JSON.parse_string(content)
			if is_usable_save(parsed):
				data = parsed
				loaded_successfully = true
			else:
				printerr("Economy save file is corrupted or invalid JSON: %s. Recovering..." % target_path)
				_backup_corrupted_file(target_path)
	
	# 2. If primary file missing or corrupted, attempt recovery from backup (.bak)
	if not loaded_successfully and FileAccess.file_exists(bak_path):
		var bak_file := FileAccess.open(bak_path, FileAccess.READ)
		if bak_file:
			var bak_content := bak_file.get_as_text()
			bak_file.close()
			var bak_parsed: Variant = JSON.parse_string(bak_content)
			if is_usable_save(bak_parsed):
				print("EconomySaveSystem: Successfully recovered save data from backup file: ", bak_path)
				data = bak_parsed
				loaded_successfully = true
	
	if not loaded_successfully:
		# Return clean empty business data; wallet and inventory stay at defaults
		return business_data
	
	# 3. Restore Wallet
	if data.has("wallet") and typeof(data["wallet"]) == TYPE_DICTIONARY:
		var w: Dictionary = data["wallet"]
		wallet.balance = maxi(0, int(w.get("balance", HouseholdWallet.DEFAULT_STARTING_BALANCE)))
		wallet.total_earned = maxi(0, int(w.get("total_earned", 0)))
		wallet.total_spent = maxi(0, int(w.get("total_spent", 0)))
		
		wallet.processed_transaction_ids.clear()
		var p_ids: Array = w.get("processed_ids", [])
		for id in p_ids:
			wallet.processed_transaction_ids[str(id)] = true
		
		wallet.transaction_history.clear()
		var hist: Array = w.get("history", [])
		for entry in hist:
			if typeof(entry) == TYPE_DICTIONARY:
				wallet.transaction_history.append(entry)
	
	# 4. Restore Inventory
	if data.has("inventory") and typeof(data["inventory"]) == TYPE_DICTIONARY:
		var inv: Dictionary = data["inventory"]
		
		inventory.items.clear()
		var loaded_items: Dictionary = inv.get("items", {})
		for k in loaded_items:
			var norm_key := InventoryManager.normalize_item_id(str(k))
			var count_val := maxi(0, int(loaded_items[k]))
			if count_val > 0:
				inventory.items[norm_key] = inventory.items.get(norm_key, 0) + count_val
		
		inventory.owned_upgrades.clear()
		var loaded_upgrades: Dictionary = inv.get("owned_upgrades", {})
		for k in loaded_upgrades:
			if bool(loaded_upgrades[k]):
				inventory.owned_upgrades[str(k)] = true
		
		inventory.owned_furniture.clear()
		var loaded_furn: Dictionary = inv.get("owned_furniture", {})
		for k in loaded_furn:
			var val: Variant = loaded_furn[k]
			if val is bool:
				if val: inventory.owned_furniture[str(k)] = true
			else:
				var count := maxi(0, int(val))
				if count > 0: inventory.owned_furniture[str(k)] = count
	
	# 5. Restore Business Progress & House Data
	if data.has("businesses") and typeof(data["businesses"]) == TYPE_DICTIONARY:
		business_data = data["businesses"]
	
	if data.has("day"):
		business_data["day"] = int(data["day"])
	elif not business_data.has("day"):
		business_data["day"] = 1
	
	if data.has("house") and typeof(data["house"]) == TYPE_DICTIONARY:
		business_data["house"] = data["house"]
	elif business_data.has("house") and typeof(business_data["house"]) == TYPE_DICTIONARY:
		# Compatibility with nested house structures
		pass

	# 6. Restore Pet Data (Requirement 7)
	if data.has("pet") and typeof(data["pet"]) == TYPE_DICTIONARY:
		business_data["pet"] = data["pet"]

	# 7. Restore Farm Data (Requirement 7)
	if data.has("farm") and typeof(data["farm"]) == TYPE_DICTIONARY:
		business_data["farm"] = data["farm"]
	
	return business_data

static func load_objective_data(path: String = "") -> Dictionary:
	var target_path := get_effective_path(path)
	for candidate in [target_path, target_path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var file := FileAccess.open(candidate, FileAccess.READ)
		if not file:
			continue
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if is_usable_save(parsed):
			var businesses: Variant = parsed.get("businesses", {})
			if businesses is Dictionary and businesses.get("objectives", null) is Dictionary:
				return businesses["objectives"]
			return {}
	return {}

static func load_farm_data(path: String = "") -> Dictionary:
	var target_path := get_effective_path(path)
	var bak_path := target_path + ".bak"

	var content := ""
	if FileAccess.file_exists(target_path):
		var file := FileAccess.open(target_path, FileAccess.READ)
		if file:
			content = file.get_as_text()
			file.close()

	var parsed: Variant = null
	if content != "":
		parsed = JSON.parse_string(content)

	if not is_usable_save(parsed) and FileAccess.file_exists(bak_path):
		var bfile := FileAccess.open(bak_path, FileAccess.READ)
		if bfile:
			var bcontent := bfile.get_as_text()
			bfile.close()
			parsed = JSON.parse_string(bcontent)

	if is_usable_save(parsed):
		if parsed.has("farm") and typeof(parsed["farm"]) == TYPE_DICTIONARY:
			return parsed["farm"]
		elif parsed.has("businesses") and typeof(parsed["businesses"]) == TYPE_DICTIONARY:
			var b = parsed["businesses"]
			if b.has("farm") and typeof(b["farm"]) == TYPE_DICTIONARY:
				return b["farm"]

	return {}

static func load_pet_data(path: String = "") -> Dictionary:
	var target_path := get_effective_path(path)
	var bak_path := target_path + ".bak"

	var content := ""
	if FileAccess.file_exists(target_path):
		var file := FileAccess.open(target_path, FileAccess.READ)
		if file:
			content = file.get_as_text()
			file.close()

	var parsed: Variant = null
	if content != "":
		parsed = JSON.parse_string(content)

	if not is_usable_save(parsed) and FileAccess.file_exists(bak_path):
		var bfile := FileAccess.open(bak_path, FileAccess.READ)
		if bfile:
			var bcontent := bfile.get_as_text()
			bfile.close()
			parsed = JSON.parse_string(bcontent)

	if is_usable_save(parsed):
		if parsed.has("pet") and typeof(parsed["pet"]) == TYPE_DICTIONARY:
			return parsed["pet"]
		elif parsed.has("businesses") and typeof(parsed["businesses"]) == TYPE_DICTIONARY:
			var b = parsed["businesses"]
			if b.has("pet") and typeof(b["pet"]) == TYPE_DICTIONARY:
				return b["pet"]

	return {}

static func load_house_data(path: String = "") -> Dictionary:
	var default_house := {
		"level": 1,
		"unlocked_areas": ["main_room"],
		"placed_furniture": []
	}
	var target_path := get_effective_path(path)
	var bak_path := target_path + ".bak"
	
	var content := ""
	if FileAccess.file_exists(target_path):
		var file := FileAccess.open(target_path, FileAccess.READ)
		if file:
			content = file.get_as_text()
			file.close()
	
	var parsed: Variant = null
	if content != "":
		parsed = JSON.parse_string(content)
	
	# Fallback to backup if primary missing or invalid
	if not is_usable_save(parsed) and FileAccess.file_exists(bak_path):
		var bfile := FileAccess.open(bak_path, FileAccess.READ)
		if bfile:
			var bcontent := bfile.get_as_text()
			bfile.close()
			parsed = JSON.parse_string(bcontent)
	
	if is_usable_save(parsed):
		if parsed.has("house") and typeof(parsed["house"]) == TYPE_DICTIONARY:
			return parsed["house"]
		elif parsed.has("businesses") and typeof(parsed["businesses"]) == TYPE_DICTIONARY:
			var b = parsed["businesses"]
			if b.has("house") and typeof(b["house"]) == TYPE_DICTIONARY:
				return b["house"]
	
	return default_house

static func _backup_corrupted_file(path: String) -> void:
	var backup_path := path + ".corrupted_" + str(Time.get_unix_time_from_system())
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, backup_path)
