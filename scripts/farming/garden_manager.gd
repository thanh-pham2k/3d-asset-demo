class_name GardenManager
extends Node

## Central Coordinator for the Home Garden & Farming System in Couple Chaos 3D.
## Manages independent farm plots, growth cycles tied to in-game time and day advances,
## default garden environment layout in the house yard, and persistence.

signal garden_updated()
signal plot_added(plot: FarmPlot)

@export var plot_count: int = 4
var plots: Array[FarmPlot] = []
var garden_root: Node3D
var growth_save_pending := false
var pending_plot_data: Dictionary = {}

func _ready() -> void:
	add_to_group("garden_manager")
	call_deferred("_discover_dependencies")

func _discover_dependencies() -> void:
	# Discover time managers
	var time_mgr := get_tree().get_first_node_in_group("time_manager") as NeighborhoodTimeManager
	if is_instance_valid(time_mgr):
		if not time_mgr.hour_elapsed.is_connected(_on_hour_ticked):
			time_mgr.hour_elapsed.connect(_on_hour_ticked)
		if not time_mgr.sleep_time_advanced.is_connected(_on_sleep_time_advanced):
			time_mgr.sleep_time_advanced.connect(_on_sleep_time_advanced)
		if not time_mgr.day_advanced.is_connected(_on_day_advanced):
			time_mgr.day_advanced.connect(_on_day_advanced)
			
	var daily_loop := get_tree().get_first_node_in_group("daily_loop_manager") as DailyLoopManager
	if is_instance_valid(daily_loop):
		if not daily_loop.day_advanced.is_connected(_on_day_advanced):
			daily_loop.day_advanced.connect(_on_day_advanced)

func setup_garden_plots(parent: Node3D) -> void:
	garden_root = parent.get_node_or_null("GardenPlotsRoot") as Node3D
	if not garden_root:
		garden_root = Node3D.new()
		garden_root.name = "GardenPlotsRoot"
		parent.add_child(garden_root)
		
	plots.clear()
	
	# Default layout: 4 garden plots outside back doorway in the home garden area
	var plot_positions := [
		Vector3(-1.8, 0.0, -6.4),
		Vector3(-0.6, 0.0, -6.4),
		Vector3(0.6, 0.0, -6.4),
		Vector3(1.8, 0.0, -6.4)
	]
	# Level 2+ (Cozy Home) or Flower Garden upgrade adds two plots without occupying the doorway.
	var room := parent as Room
	if is_instance_valid(room) and is_instance_valid(room.progression_manager) and (room.progression_manager.house_level >= 2 or room.progression_manager.has_flower_garden):
		plot_positions.append(Vector3(-1.9, 0.0, -4.95))
		plot_positions.append(Vector3(1.9, 0.0, -4.95))
	
	for i in range(plot_positions.size()):
		var p_id := "plot_%d" % (i + 1)
		var existing := garden_root.get_node_or_null(p_id) as FarmPlot
		if not existing:
			var plot := FarmPlot.new()
			plot.name = p_id
			plot.plot_id = p_id
			plot.position = plot_positions[i]
			garden_root.add_child(plot)
			plots.append(plot)
			if pending_plot_data.has(p_id):
				plot.apply_save_data(pending_plot_data[p_id])
				pending_plot_data.erase(p_id)
			plot_added.emit(plot)
		else:
			plots.append(existing)
			if pending_plot_data.has(p_id):
				existing.apply_save_data(pending_plot_data[p_id])
				pending_plot_data.erase(p_id)
			
	# Spawn decorative garden accessories around the plots
	_spawn_garden_decorations(garden_root)

func _spawn_garden_decorations(parent: Node3D) -> void:
	if parent.get_node_or_null("GardenCompost"):
		return
		
	# 1. Garden fence along the rear of the garden
	var fence_sc: PackedScene = load("res://scenes/farming/garden_fence.tscn")
	if fence_sc:
		for x_pos in [-1.5, 1.5]:
			var fence = fence_sc.instantiate()
			fence.name = "GardenFence_%s" % str(x_pos)
			fence.position = Vector3(x_pos, 0, -7.4)
			parent.add_child(fence)
			
	# 2. Compost bag near the right plot
	var compost_sc: PackedScene = load("res://scenes/farming/compost_bag.tscn")
	if compost_sc:
		var compost = compost_sc.instantiate()
		compost.name = "GardenCompost"
		compost.position = Vector3(2.8, 0, -6.0)
		parent.add_child(compost)
		
	# 3. Watering can tool prop near left plot
	var can_sc: PackedScene = load("res://scenes/farming/tool_watering_can.tscn")
	if can_sc:
		var can = can_sc.instantiate()
		can.name = "GardenWateringCan"
		can.position = Vector3(-2.8, 0, -6.0)
		parent.add_child(can)
		
	# 4. Garden stepping stone pathway in front of the plots
	var path_sc: PackedScene = load("res://scenes/farming/garden_pathway.tscn")
	if path_sc:
		for x_pos in [-1.2, 0.0, 1.2]:
			var pathway = path_sc.instantiate()
			pathway.name = "Pathway_%s" % str(x_pos)
			pathway.position = Vector3(x_pos, 0, -5.3)
			parent.add_child(pathway)

# -----------------------------------------------------------------
# Time & Day Handlers
# -----------------------------------------------------------------
func _on_hour_ticked(_hour: int) -> void:
	var changed := false
	for p in _get_all_plots():
		if p.crop_id != "" and p.is_watered and p.stage < 3:
			p.advance_growth_hour()
			changed = true
	if changed:
		garden_updated.emit()
		# At midnight this signal precedes the day change. Save only after all
		# clock and day listeners have applied the transition.
		if not growth_save_pending:
			growth_save_pending = true
			call_deferred("_save_growth")

func _save_growth() -> void:
	growth_save_pending = false
	if not is_inside_tree(): return
	var econ := get_tree().get_first_node_in_group("economy_manager") as EconomyManager
	if is_instance_valid(econ) and econ.auto_save_on_change:
		econ.save_economy_state()

func _on_sleep_time_advanced(hours_before_midnight: float) -> void:
	# Advance actual skipped time once; day_advanced only dries the soil.
	var whole_hours := maxi(0, int(ceil(hours_before_midnight)))
	for p in _get_all_plots():
		for _hour in range(whole_hours):
			p.advance_growth_hour()
	garden_updated.emit()

func _on_day_advanced(new_day: int) -> void:
	for p in _get_all_plots():
		p.advance_growth_day(new_day)
	garden_updated.emit()

func _get_all_plots() -> Array[FarmPlot]:
	if not plots.is_empty():
		return plots
	var list: Array[FarmPlot] = []
	for node in get_tree().get_nodes_in_group("farm_plots"):
		if node is FarmPlot:
			list.append(node)
	return list

# -----------------------------------------------------------------
# Persistence
# -----------------------------------------------------------------
func get_save_data() -> Dictionary:
	var plot_list: Array = []
	for p in _get_all_plots():
		plot_list.append(p.get_save_data())
	for p_data in pending_plot_data.values():
		plot_list.append(p_data)
	return {
		"plots": plot_list
	}

func apply_save_data(data: Dictionary) -> void:
	if not data.has("plots") or not (data["plots"] is Array):
		return
	var loaded_plots: Array = data["plots"]
	pending_plot_data.clear()
	var plot_map := {}
	for p in _get_all_plots():
		plot_map[p.plot_id] = p
		# A plot omitted by an older or different save is an empty plot.
		p.apply_save_data({"plot_id": p.plot_id, "is_tilled": false})
		
	for p_data in loaded_plots:
		if p_data is Dictionary and p_data.get("plot_id", null) is String:
			var p_id: String = p_data["plot_id"]
			if plot_map.has(p_id):
				plot_map[p_id].apply_save_data(p_data)
			else:
				pending_plot_data[p_id] = p_data.duplicate(true)
				
	garden_updated.emit()
