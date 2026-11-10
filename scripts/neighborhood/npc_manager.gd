class_name NPCManager
extends Node3D

## Manager responsible for spawning, updating schedules, and coordinating
## all neighborhood NPCs.

signal npc_spawned(npc: NPCController)
signal npc_interaction_started(npc: NPCController, player: Node3D)

@export var time_manager: NeighborhoodTimeManager
var npcs: Dictionary = {} # id -> NPCController

func _ready() -> void:
	if not is_instance_valid(time_manager):
		time_manager = get_node_or_null("../TimeManager") as NeighborhoodTimeManager
	
	if is_instance_valid(time_manager):
		time_manager.hour_ticked.connect(_on_hour_ticked)
		time_manager.period_changed.connect(_on_period_changed)
	
	call_deferred("spawn_all_default_npcs")

func spawn_all_default_npcs() -> void:
	var database := NPCData.create_default_database()
	var current_hour := 8.0
	if is_instance_valid(time_manager):
		current_hour = time_manager.current_hour
	
	for data in database:
		var schedule_entry := data.get_schedule_for_hour(current_hour)
		var spawn_pos: Vector3 = schedule_entry.get("position", data.home_position)
		spawn_npc(data, spawn_pos, schedule_entry)

func spawn_npc(data: NPCData, spawn_pos: Vector3, initial_schedule: Dictionary = {}) -> NPCController:
	if npcs.has(data.id) and is_instance_valid(npcs[data.id]):
		return npcs[data.id]
	
	var npc := NPCController.new(data)
	npc.name = "NPC_" + data.id.to_pascal_case()
	npc.position = spawn_pos
	add_child(npc)
	npcs[data.id] = npc
	
	if not initial_schedule.is_empty():
		npc.apply_schedule_entry(initial_schedule, true)
	
	npc_spawned.emit(npc)
	return npc

func get_npc(id: String) -> NPCController:
	if npcs.has(id) and is_instance_valid(npcs[id]):
		return npcs[id]
	return null

func get_all_npcs() -> Array[NPCController]:
	var list: Array[NPCController] = []
	for npc in npcs.values():
		if is_instance_valid(npc):
			list.append(npc)
	return list

func _on_hour_ticked(hour: int) -> void:
	_update_all_schedules(float(hour))

func _on_period_changed(_new_period: String) -> void:
	if is_instance_valid(time_manager):
		_update_all_schedules(time_manager.current_hour)

func _update_all_schedules(hour: float) -> void:
	for id in npcs:
		var npc: NPCController = npcs[id]
		if not is_instance_valid(npc) or not npc.data: continue
		var entry := npc.data.get_schedule_for_hour(hour)
		npc.apply_schedule_entry(entry, false)

func set_time_of_day(hour: float, force_teleport := false) -> void:
	if is_instance_valid(time_manager):
		time_manager.set_hour(hour)
	for id in npcs:
		var npc: NPCController = npcs[id]
		if not is_instance_valid(npc) or not npc.data: continue
		var entry := npc.data.get_schedule_for_hour(hour)
		npc.apply_schedule_entry(entry, force_teleport)
