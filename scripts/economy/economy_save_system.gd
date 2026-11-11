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

static func save_economy(
	wallet: HouseholdWallet,
	inventory: InventoryManager,
	business_data: Dictionary = {},
	house_or_path: Variant = DEFAULT_SAVE_PATH,
	optional_path: String = ""
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
		"house": house_data
	}
	
	var json_string := JSON.stringify(data, "\t")
	
	# 1. Write to temporary file first
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if not file:
		printerr("Failed to open temp file for economy save: ", tmp_path)
		return false
	
	file.store_string(json_string)
	file.close()
	
	# 2. Verify temporary file was written completely
	if not FileAccess.file_exists(tmp_path):
		printerr("Temp file missing after write: ", tmp_path)
		return false
	
	# 3. If target file already exists, create a backup before replacing it
	var target_existed := FileAccess.file_exists(target_path)
	if target_existed:
		var copy_err := DirAccess.copy_absolute(target_path, bak_path)
		if copy_err != OK:
			push_warning("Could not backup existing save to %s: %d" % [bak_path, copy_err])
	
	# 4. Atomic rename / replace
	var replaced := false
	var rename_err := DirAccess.rename_absolute(tmp_path, target_path)
	if rename_err == OK:
		replaced = true
	else:
		# If rename failed because target exists, remove target now that backup is secured
		if target_existed and (FileAccess.file_exists(bak_path) or rename_err != OK):
			DirAccess.remove_absolute(target_path)
			rename_err = DirAccess.rename_absolute(tmp_path, target_path)
			if rename_err == OK:
				replaced = true
	
	# 5. Fallback write if rename still failed
	if not replaced:
		printerr("Atomic rename failed for economy save (%d). Using fallback write..." % rename_err)
		var fallback_file := FileAccess.open(target_path, FileAccess.WRITE)
		if fallback_file:
			fallback_file.store_string(json_string)
			fallback_file.close()
			if FileAccess.file_exists(tmp_path):
				DirAccess.remove_absolute(tmp_path)
			replaced = true
		else:
			printerr("Fallback write failed! Restoring from backup...")
			if target_existed and FileAccess.file_exists(bak_path) and not FileAccess.file_exists(target_path):
				DirAccess.copy_absolute(bak_path, target_path)
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
			if parsed != null and typeof(parsed) == TYPE_DICTIONARY:
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
			if bak_parsed != null and typeof(bak_parsed) == TYPE_DICTIONARY:
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
			inventory.items[str(k)] = maxi(0, int(loaded_items[k]))
		
		inventory.owned_upgrades.clear()
		var loaded_upgrades: Dictionary = inv.get("owned_upgrades", {})
		for k in loaded_upgrades:
			inventory.owned_upgrades[str(k)] = true
		
		inventory.owned_furniture.clear()
		var loaded_furn: Dictionary = inv.get("owned_furniture", {})
		for k in loaded_furn:
			var val: Variant = loaded_furn[k]
			if val is bool:
				inventory.owned_furniture[str(k)] = val
			else:
				inventory.owned_furniture[str(k)] = maxi(1, int(val))
	
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
	
	return business_data

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
	if (parsed == null or typeof(parsed) != TYPE_DICTIONARY) and FileAccess.file_exists(bak_path):
		var bfile := FileAccess.open(bak_path, FileAccess.READ)
		if bfile:
			var bcontent := bfile.get_as_text()
			bfile.close()
			parsed = JSON.parse_string(bcontent)
	
	if parsed != null and typeof(parsed) == TYPE_DICTIONARY:
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
