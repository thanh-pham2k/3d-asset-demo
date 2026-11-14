class_name UnlockRules
extends RefCounted
## Pure unlock rule evaluator shared across Farm, Orders, and Upgrades.

static func get_required_level_for_plot(plot_id: int) -> int:
	if plot_id < 6:
		return 1
	if plot_id < 8:
		return 2
	if plot_id < 10:
		return 3
	return 4

static func is_plot_tier_unlocked(plot_id: int, progression: ProgressionSystem) -> bool:
	if progression == null:
		return true
	return progression.level >= get_required_level_for_plot(plot_id)

static func get_required_level_for_crop(crop_id: String, progression: ProgressionSystem) -> int:
	if progression == null:
		return 1
	for row in progression.levels_data:
		var lv := int(row.get("level", 1))
		var unlocks: Variant = row.get("unlocks", [])
		if typeof(unlocks) == TYPE_ARRAY and (unlocks as Array).has(crop_id):
			return lv
	return 1

static func is_crop_unlocked(crop_id: String, progression: ProgressionSystem) -> bool:
	if progression == null:
		return true
	return progression.is_unlocked(crop_id)
