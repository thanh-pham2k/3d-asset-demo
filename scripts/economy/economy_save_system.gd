class_name EconomySaveSystem
extends RefCounted

## Robust JSON serialization and deserialization for the economy system.
## Supports atomic writes, schema validation, and graceful recovery from missing or corrupted files.

const DEFAULT_SAVE_PATH: String = "user://couple_chaos_economy.json"

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
	var tmp_path := path + ".tmp"
	
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if not file:
		printerr("Failed to open temp file for economy save: ", tmp_path)
		return false
	
	file.store_string(json_string)
	file.close()
	
	# Atomic move / replace
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	
	var rename_err := DirAccess.rename_absolute(tmp_path, path)
	if rename_err != OK:
		# Fallback: direct write to path
		var fallback_file := FileAccess.open(path, FileAccess.WRITE)
		if fallback_file:
			fallback_file.store_string(json_string)
			fallback_file.close()
			DirAccess.remove_absolute(tmp_path)
			return true
		return false
	
	return true

static func load_economy(
	wallet: HouseholdWallet,
	inventory: InventoryManager,
	path := DEFAULT_SAVE_PATH
) -> Dictionary:
	var business_data := {}
	
	if not FileAccess.file_exists(path):
		# Missing save file: return empty business data, wallet and inventory stay at clean defaults
		return business_data
	
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		printerr("Could not open economy save file: ", path)
		return business_data
	
	var content := file.get_as_text()
	file.close()
	
	var parsed: Variant = JSON.parse_string(content)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		printerr("Economy save file is corrupted or invalid JSON. Recovering safely...")
		_backup_corrupted_file(path)
		return business_data
	
	var data: Dictionary = parsed
	
	# 1. Restore Wallet
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
	
	# 2. Restore Inventory
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
	
	# 3. Restore Business Progress & House Data
	if data.has("businesses") and typeof(data["businesses"]) == TYPE_DICTIONARY:
		business_data = data["businesses"]
	
	if data.has("day"):
		business_data["day"] = int(data["day"])
	elif not business_data.has("day"):
		business_data["day"] = 1
	
	if data.has("house") and typeof(data["house"]) == TYPE_DICTIONARY:
		business_data["house"] = data["house"]
	
	return business_data

static func load_house_data(path := DEFAULT_SAVE_PATH) -> Dictionary:
	var default_house := {
		"level": 1,
		"unlocked_areas": ["main_room"],
		"placed_furniture": []
	}
	if not FileAccess.file_exists(path):
		return default_house
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return default_house
	var content := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(content) != OK:
		return default_house
	var data = json.data
	if typeof(data) == TYPE_DICTIONARY and data.has("house") and typeof(data["house"]) == TYPE_DICTIONARY:
		return data["house"]
	return default_house

static func _backup_corrupted_file(path: String) -> void:
	var backup_path := path + ".corrupted_" + str(Time.get_unix_time_from_system())
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, backup_path)
