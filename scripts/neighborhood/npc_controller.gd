class_name NPCController
extends CharacterBody3D

## Full AI controller for neighborhood NPCs.
## Uses NavigationAgent3D for pathfinding, follows daily schedules, handles states,
## provides player dialogue interaction, stuck recovery, and anti-overlap separation.

enum State {
	IDLE,
	WALKING,
	WAITING,
	INTERACTING
}

@export var data: NPCData
@export var walk_speed: float = 2.4
@export var run_speed: float = 4.2

var kind: String = "npc"
var user: Node3D = null
var enabled: bool = true
var display_name: String = "Người dân"

var current_state: State = State.IDLE
var previous_state: State = State.IDLE

var visual: NPCVisual
var nav_agent: NavigationAgent3D
var collision_shape: CollisionShape3D
var dialogue_label: Label3D
var nameplate_label: Label3D

var target_destination: Vector3 = Vector3.ZERO
var wait_timer: float = 0.0
var max_wait_time: float = 10.0
var stuck_timer: float = 0.0
var last_progress_position: Vector3 = Vector3.ZERO

var interacting_player: Node3D = null
var current_dialogue_key: String = "morning"
var dialogue_index: int = 0
var dialogue_timer: float = 0.0

var internal_time: float = 0.0
var current_activity: String = "idle"

func _init(p_data: NPCData = null) -> void:
	if p_data: data = p_data

func _ready() -> void:
	add_to_group("neighborhood_npcs")
	add_to_group("interactables")
	
	_setup_collision()
	_setup_navigation()
	_setup_visual()
	_setup_dialogue_ui()
	
	last_progress_position = global_position
	
	if data:
		display_name = data.name
		target_destination = data.home_position

func _setup_collision() -> void:
	collision_layer = 4
	collision_mask = 1 # Collides with static world geometry
	
	collision_shape = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 1.1
	collision_shape.shape = capsule
	collision_shape.position = Vector3(0, 0.55, 0)
	add_child(collision_shape)

func _setup_navigation() -> void:
	nav_agent = NavigationAgent3D.new()
	nav_agent.name = "NavigationAgent3D"
	nav_agent.path_desired_distance = 0.8
	nav_agent.target_desired_distance = 1.0
	nav_agent.path_max_distance = 4.0
	nav_agent.avoidance_enabled = true
	nav_agent.radius = 0.4
	nav_agent.neighbor_distance = 8.0
	nav_agent.max_neighbors = 6
	nav_agent.time_horizon_agents = 1.5
	nav_agent.max_speed = run_speed
	add_child(nav_agent)

func _setup_visual() -> void:
	visual = NPCVisual.new()
	visual.name = "Visual"
	if data: visual.setup(data)
	add_child(visual)

func _setup_dialogue_ui() -> void:
	# Floating nameplate
	nameplate_label = Label3D.new()
	nameplate_label.position = Vector3(0, 1.60, 0)
	nameplate_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nameplate_label.font_size = 22
	nameplate_label.pixel_size = 0.004
	nameplate_label.outline_size = 6
	nameplate_label.modulate = Color("ffe082")
	nameplate_label.outline_modulate = Color("1a1a1a")
	if data: nameplate_label.text = "%s (%s)" % [data.name, data.role]
	add_child(nameplate_label)
	
	# Speech bubble for dialogue
	dialogue_label = Label3D.new()
	dialogue_label.position = Vector3(0, 1.95, 0)
	dialogue_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	dialogue_label.font_size = 24
	dialogue_label.pixel_size = 0.0045
	dialogue_label.outline_size = 8
	dialogue_label.modulate = Color("ffffff")
	dialogue_label.outline_modulate = Color("1a1a1a")
	dialogue_label.visible = false
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.width = 320.0
	add_child(dialogue_label)

func _physics_process(delta: float) -> void:
	internal_time += delta
	
	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.WALKING:
			_process_walking(delta)
		State.WAITING:
			_process_waiting(delta)
		State.INTERACTING:
			_process_interacting(delta)
	
	_apply_separation(delta)
	
	if current_state != State.INTERACTING:
		move_and_slide()
	
	var cur_speed := Vector2(velocity.x, velocity.z).length()
	visual.update_animation(cur_speed, internal_time, current_state == State.INTERACTING)

func _process_idle(delta: float) -> void:
	velocity = Vector3.ZERO
	wait_timer -= delta
	if wait_timer <= 0.0:
		if global_position.distance_to(target_destination) > 1.5:
			set_destination(target_destination)
		else:
			wait_timer = randf_range(4.0, 8.0)

func _process_walking(delta: float) -> void:
	if not is_instance_valid(nav_agent): return
	
	if nav_agent.is_navigation_finished() or global_position.distance_to(target_destination) <= 1.2:
		current_state = State.WAITING
		wait_timer = max_wait_time
		velocity = Vector3.ZERO
		stuck_timer = 0.0
		return
	
	var next_path_pos := nav_agent.get_next_path_position()
	var move_dir := (next_path_pos - global_position)
	move_dir.y = 0.0
	
	if move_dir.length_squared() > 0.01:
		move_dir = move_dir.normalized()
		var desired_velocity := move_dir * walk_speed
		velocity = velocity.move_toward(desired_velocity, 12.0 * delta)
		
		# Rotate towards movement direction smoothly
		var target_yaw := atan2(move_dir.x, move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 8.0 * delta)
	else:
		velocity = Vector3.ZERO
	
	# Stuck detection & recovery
	var dist_moved := global_position.distance_to(last_progress_position)
	if dist_moved < 0.15:
		stuck_timer += delta
		if stuck_timer > 2.0:
			_attempt_unstuck()
		if stuck_timer > 5.0:
			_recover_stuck_schedule()
	else:
		last_progress_position = global_position
		stuck_timer = 0.0

func _process_waiting(delta: float) -> void:
	velocity = Vector3.ZERO
	wait_timer -= delta
	if wait_timer <= 0.0:
		current_state = State.IDLE
		wait_timer = randf_range(3.0, 6.0)

func _process_interacting(delta: float) -> void:
	velocity = Vector3.ZERO
	
	if is_instance_valid(interacting_player):
		var to_player := (interacting_player.global_position - global_position)
		to_player.y = 0.0
		if to_player.length_squared() > 0.01:
			var target_yaw := atan2(to_player.x, to_player.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, 10.0 * delta)
		
		if global_position.distance_to(interacting_player.global_position) > 2.8:
			end_interaction()
	
	dialogue_timer -= delta
	if dialogue_timer <= 0.0 and dialogue_label.visible:
		dialogue_label.visible = false

func _apply_separation(_delta: float) -> void:
	var neighbors := get_tree().get_nodes_in_group("neighborhood_npcs")
	var push := Vector3.ZERO
	for other in neighbors:
		if other == self or not is_instance_valid(other): continue
		var diff: Vector3 = global_position - other.global_position
		diff.y = 0.0
		var d := diff.length()
		if d < 0.85 and d > 0.01:
			var strength := (0.85 - d) / 0.85
			push += diff.normalized() * (strength * 1.5)
	
	if push.length_squared() > 0.001:
		velocity += push

func set_destination(dest: Vector3) -> void:
	target_destination = dest
	if is_instance_valid(nav_agent):
		nav_agent.target_position = dest
		current_state = State.WALKING
		last_progress_position = global_position
		stuck_timer = 0.0

func apply_schedule_entry(entry: Dictionary, force_warp := false) -> void:
	if not entry.has("position"): return
	
	var base_dest: Vector3 = entry["position"]
	var scatter := Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
	var final_dest := base_dest + scatter
	
	current_activity = entry.get("activity", "idle")
	current_dialogue_key = entry.get("dialogue_key", "morning")
	max_wait_time = entry.get("wait_duration", 15.0)
	
	var dist := global_position.distance_to(final_dest)
	if force_warp or dist > 70.0:
		global_position = final_dest
		last_progress_position = final_dest
		current_state = State.IDLE
		wait_timer = randf_range(2.0, 5.0)
	else:
		set_destination(final_dest)

func _attempt_unstuck() -> void:
	if is_instance_valid(nav_agent):
		var nudge := Vector3(randf_range(-1.2, 1.2), 0, randf_range(-1.2, 1.2))
		nav_agent.target_position = target_destination + nudge

func _recover_stuck_schedule() -> void:
	global_position = target_destination
	stuck_timer = 0.0
	current_state = State.WAITING
	wait_timer = 4.0

# --- Interactable Duck-Typing Interface ---
func available(player_node: Node3D) -> bool:
	return enabled and (user == null or user == player_node)

func prompt(_player_node: Node3D) -> String:
	var char_name := data.name if data else "Người dân"
	return "Trò chuyện với " + char_name

func interact(player_node: Node3D) -> void:
	if current_state == State.INTERACTING:
		_advance_dialogue()
		return
	
	previous_state = current_state
	current_state = State.INTERACTING
	interacting_player = player_node
	user = player_node
	dialogue_index = 0
	_show_current_dialogue()

func _show_current_dialogue() -> void:
	if not data: return
	
	var lines: Array = data.dialogues.get(current_dialogue_key, [])
	if lines.is_empty():
		lines = data.dialogues.get("morning", ["Chào bạn! Chúc một ngày tốt lành!"])
	
	var text: String = lines[dialogue_index % lines.size()]
	dialogue_label.text = text
	dialogue_label.visible = true
	dialogue_timer = 6.0

func _advance_dialogue() -> void:
	if not data:
		end_interaction()
		return
	
	var lines: Array = data.dialogues.get(current_dialogue_key, [])
	if lines.is_empty(): lines = data.dialogues.get("morning", [])
	
	dialogue_index += 1
	if dialogue_index < lines.size():
		_show_current_dialogue()
	else:
		end_interaction()

func end_interaction() -> void:
	dialogue_label.visible = false
	user = null
	interacting_player = null
	current_state = previous_state if previous_state != State.INTERACTING else State.IDLE
	wait_timer = 2.0
