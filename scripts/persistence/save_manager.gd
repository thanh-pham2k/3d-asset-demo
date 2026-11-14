class_name SaveManager
extends RefCounted
## Persists Game Core state and reconciles deterministic GameClock offline progress.

const SAVE_VERSION := 1
const DEFAULT_SAVE_PATH := "user://save_very_mvp.json"

static func save_game(
	clock: GameClock,
	wallet: Wallet,
	inventory: Inventory,
	farm: FarmSystem,
	path: String = DEFAULT_SAVE_PATH
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

	var payload := {
		"save_version": SAVE_VERSION,
		"saved_at_real_unix": int(Time.get_unix_time_from_system()),
		"clock_offset_sec": clock.get_offset(),
		"wallet_coins": wallet.balance,
		"inventory_carrots": inventory.get_count("carrot"),
		"plots": plots_data
	}

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	return true

static func load_game(
	clock: GameClock,
	wallet: Wallet,
	inventory: Inventory,
	farm: FarmSystem,
	path: String = DEFAULT_SAVE_PATH
) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"loaded": false, "offline_elapsed": 0, "matured_count": 0}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"loaded": false, "offline_elapsed": 0, "matured_count": 0}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"loaded": false, "offline_elapsed": 0, "matured_count": 0}

	var data := parsed as Dictionary
	var saved_real_unix := int(data.get("saved_at_real_unix", 0))
	var offline_sec := clock.offline_elapsed(saved_real_unix)
	clock.set_offset(int(data.get("clock_offset_sec", 0)))

	wallet.set_balance(int(data.get("wallet_coins", wallet.balance)))
	inventory.set_count("carrot", int(data.get("inventory_carrots", 0)))

	var plots_raw: Variant = data.get("plots", [])
	if typeof(plots_raw) == TYPE_ARRAY:
		for entry in (plots_raw as Array):
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var p_dict := entry as Dictionary
			var pid := int(p_dict.get("id", -1))
			var plot := farm.get_plot(pid)
			if plot == null:
				continue
			plot.state = FarmPlot.parse_state(String(p_dict.get("state", "EMPTY")))
			plot.crop_id = String(p_dict.get("crop_id", ""))
			plot.timer.planted_at_unix = int(p_dict.get("planted_at_unix", 0))
			plot.timer.grow_duration_sec = int(p_dict.get("grow_duration_sec", 300))

	var matured_count := farm.tick(clock)
	return {
		"loaded": true,
		"save_version": int(data.get("save_version", 1)),
		"offline_elapsed": offline_sec,
		"matured_count": matured_count
	}

static func reset_save(path: String = DEFAULT_SAVE_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
