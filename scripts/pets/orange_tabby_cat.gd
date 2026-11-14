class_name OrangeTabbyCat
extends CharacterBody3D

## Primary Pet Entity & AI Controller for the Orange Tabby Cat in Couple Chaos 3D.
## Features complete 7-state machine (IDLE, FOLLOWING, EATING, DRINKING, PLAYING, SLEEPING, RESTING),
## natural room navigation, obstacle avoidance, stuck recovery, player bonding progression,
## and cozy 3D mood feedback.

signal pet_interacted(action: String)
signal activity_changed(new_activity: String)
signal stats_changed(hunger: float, happiness: float, affection: float)

enum Activity {
	IDLE,
	FOLLOWING,
	EATING,
	DRINKING,
	PLAYING,
	SLEEPING,
	RESTING
}

# -----------------------------------------------------------------
# Pet Entity Properties (Requirement 1)
# -----------------------------------------------------------------
@export var pet_id: String = "pet_orange_tabby_01"
@export var pet_name: String = "Miu Miu"
@export var hunger: float = 75.0        # 0.0 = starving, 100.0 = full
@export var thirst: float = 80.0        # 0.0 = thirsty, 100.0 = quenched
@export var happiness: float = 80.0     # 0.0 to 100.0
@export var affection: float = 25.0     # 0.0 to 100.0 (care bonding)
@export var current_activity: Activity = Activity.IDLE
@export var home_position: Vector3 = Vector3(1.5, 0.0, -1.0)
@export var has_collar: bool = true

# Movement speeds
const WALK_SPEED: float = 0.95
const RUN_SPEED: float = 2.1
const STOP_DISTANCE_TO_PLAYER: float = 1.35
const SAFE_ROOM_MIN := Vector2(-7.2, -3.4)
const SAFE_ROOM_MAX := Vector2(7.2, 3.2)

# Sub-nodes
var visual: CatVisual
var anim_controller: PetAnimationController
var collision_shape: CollisionShape3D
var mood_label: Label3D

# AI & State Machine Internal State
var target_nav_point: Vector3 = Vector3.ZERO
var target_prop: PetProp = null
var target_player: CharacterBody3D = null

var state_timer: float = 0.0
var wander_interval: float = 4.0
var stuck_timer: float = 0.0
var last_pos: Vector3 = Vector3.ZERO
var mood_display_timer: float = 0.0
var activity_elapsed: float = 0.0
var sleeping_on_bed: bool = false
var bed_exit_position: Vector3 = Vector3.ZERO
var sleep_search_delay: float = 8.0
var exploring_garden: bool = false

func _ready() -> void:
	add_to_group("pets")
	add_to_group("interactables")
	
	_setup_collision()
	_setup_visual()
	_setup_animation()
	_setup_mood_label()
	
	set_collar_visible(has_collar)
	last_pos = global_position
	
	# Start with gentle idle
	switch_activity(Activity.IDLE)

func _setup_collision() -> void:
	collision_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not collision_shape:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.14
		capsule.height = 0.38
		collision_shape.shape = capsule
		collision_shape.rotation.x = PI / 2.0
		collision_shape.position = Vector3(0, 0.14, 0)
		add_child(collision_shape)
		
	collision_layer = 4 # NPC / Pet layer
	collision_mask = 1  # Environment solids & world

func _setup_visual() -> void:
	visual = get_node_or_null("CatVisual") as CatVisual
	if not visual:
		visual = CatVisual.new()
		visual.name = "CatVisual"
		add_child(visual)

func _setup_animation() -> void:
	anim_controller = get_node_or_null("PetAnimationController") as PetAnimationController
	if not anim_controller:
		anim_controller = PetAnimationController.new()
		anim_controller.name = "PetAnimationController"
		anim_controller.cat_visual = visual
		add_child(anim_controller)

func _setup_mood_label() -> void:
	mood_label = get_node_or_null("MoodLabel") as Label3D
	if not mood_label:
		mood_label = Label3D.new()
		mood_label.name = "MoodLabel"
		mood_label.position = Vector3(0, 0.45, 0)
		mood_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		mood_label.font_size = 28
		mood_label.outline_size = 6
		mood_label.outline_modulate = Color("1a1a1a")
		mood_label.modulate = Color("ffffff")
		mood_label.text = ""
		mood_label.visible = false
		add_child(mood_label)

# -----------------------------------------------------------------
# Main Physics & AI Loop
# -----------------------------------------------------------------
func _physics_process(delta: float) -> void:
	state_timer += delta
	sleep_search_delay = maxf(0.0, sleep_search_delay - delta)
	_update_mood_display(delta)
	
	# Gradual small hunger/thirst tick
	hunger = maxf(10.0, hunger - delta * 0.04)
	thirst = maxf(10.0, thirst - delta * 0.05)
	
	match current_activity:
		Activity.IDLE:
			_process_idle(delta)
		Activity.FOLLOWING:
			_process_following(delta)
		Activity.EATING:
			_process_eating(delta)
		Activity.DRINKING:
			_process_drinking(delta)
		Activity.PLAYING:
			_process_playing(delta)
		Activity.SLEEPING:
			_process_sleeping(delta)
		Activity.RESTING:
			_process_resting(delta)

# -----------------------------------------------------------------
# State Machine Transitions
# -----------------------------------------------------------------
func switch_activity(new_act: Activity) -> void:
	if sleeping_on_bed:
		sleep_search_delay = 90.0
		global_position = bed_exit_position
		collision_mask = 1
		sleeping_on_bed = false
	current_activity = new_act
	state_timer = 0.0
	activity_elapsed = 0.0
	stuck_timer = 0.0
	velocity = Vector3.ZERO
	
	match current_activity:
		Activity.IDLE:
			play_animation("idle")
			set_expression("alert" if randf() < 0.4 else "happy")
			wander_interval = randf_range(3.5, 7.0)
		Activity.FOLLOWING:
			play_animation("walk")
			set_expression("happy")
			show_mood_emote("❤️" if affection >= 50.0 else "😸")
		Activity.EATING:
			play_animation("eat")
			set_expression("happy")
			show_mood_emote("🐟")
		Activity.DRINKING:
			play_animation("drink")
			set_expression("happy")
			show_mood_emote("💧")
		Activity.PLAYING:
			play_animation("play")
			set_expression("happy")
			show_mood_emote("✨")
		Activity.SLEEPING:
			play_animation("sleep")
			set_expression("sleep")
			show_mood_emote("💤")
		Activity.RESTING:
			play_animation("sit")
			set_expression("happy")
			
	activity_changed.emit(get_activity_string())
	stats_changed.emit(hunger, happiness, affection)

func get_activity_string() -> String:
	match current_activity:
		Activity.IDLE: return "IDLE"
		Activity.FOLLOWING: return "FOLLOWING"
		Activity.EATING: return "EATING"
		Activity.DRINKING: return "DRINKING"
		Activity.PLAYING: return "PLAYING"
		Activity.SLEEPING: return "SLEEPING"
		Activity.RESTING: return "RESTING"
		_: return "IDLE"

func set_activity_by_string(act_str: String) -> void:
	match act_str:
		"IDLE": switch_activity(Activity.IDLE)
		"FOLLOWING": switch_activity(Activity.FOLLOWING)
		"EATING": switch_activity(Activity.EATING)
		"DRINKING": switch_activity(Activity.DRINKING)
		"PLAYING": switch_activity(Activity.PLAYING)
		"SLEEPING": switch_activity(Activity.SLEEPING)
		"RESTING": switch_activity(Activity.RESTING)
		_: switch_activity(Activity.IDLE)

# -----------------------------------------------------------------
# State Logic Implementations
# -----------------------------------------------------------------
func _process_idle(delta: float) -> void:
	# Priority 1: Check hunger & food bowl
	if hunger < 40.0:
		var bowl := _find_filled_prop("food_bowl")
		if is_instance_valid(bowl):
			target_prop = bowl
			target_nav_point = bowl.get_interaction_position()
			switch_activity(Activity.EATING)
			return
		elif state_timer > 10.0:
			show_mood_emote("🐟") # Whine for food
			
	# Priority 2: Check thirst & water bowl
	if thirst < 35.0:
		var wbowl := _find_filled_prop("water_bowl")
		if is_instance_valid(wbowl):
			target_prop = wbowl
			target_nav_point = wbowl.get_interaction_position()
			switch_activity(Activity.DRINKING)
			return
			
	# At night, seek an owned bed before settling down to sleep.
	var clock := get_tree().get_first_node_in_group("time_manager") as NeighborhoodTimeManager
	if is_instance_valid(clock) and (clock.current_hour >= 21.0 or clock.current_hour < 6.0) and sleep_search_delay <= 0.0:
		var bed := _find_prop("pet_bed")
		if is_instance_valid(bed):
			target_prop = bed
			sleep_search_delay = 30.0
			switch_activity(Activity.SLEEPING)
			return

	# Priority 3: Check nearby player interaction/following
	var player := _find_nearest_player()
	if is_instance_valid(player):
		var dist_to_player := global_position.distance_to(player.global_position)
		if dist_to_player < 2.5:
			# Player approach reaction: turn head towards player
			_face_towards(player.global_position, delta * 3.0)
			
			# Follow player based on affection tier
			var follow_chance := 0.20
			if affection >= 70.0:
				follow_chance = 0.75
			elif affection >= 30.0:
				follow_chance = 0.45
				
			if player.velocity.length() > 0.3 and randf() < follow_chance:
				target_player = player
				switch_activity(Activity.FOLLOWING)
				return
				
	# Priority 4: Natural roaming wander
	if target_nav_point != Vector3.ZERO:
		var reached := _move_towards(target_nav_point, WALK_SPEED, delta)
		if reached:
			target_nav_point = Vector3.ZERO
			play_animation("idle")
			state_timer = 0.0
	else:
		if state_timer >= wander_interval:
			state_timer = 0.0
			wander_interval = randf_range(4.0, 8.0)
			# Random decision: sit, explore garden, or walk in room
			var roll := randf()
			if roll < 0.25:
				play_animation("sit")
				exploring_garden = false
			elif roll < 0.45 and hunger >= 35.0 and thirst >= 35.0:
				exploring_garden = true
				target_nav_point = _pick_random_garden_point()
				show_mood_emote("🌿")
				play_animation("walk")
			elif roll < 0.75:
				exploring_garden = false
				target_nav_point = _pick_random_room_point()
				play_animation("walk")
			else:
				exploring_garden = false
				play_animation("idle")

func _process_following(delta: float) -> void:
	if not is_instance_valid(target_player):
		target_player = _find_nearest_player()
		if not is_instance_valid(target_player):
			switch_activity(Activity.IDLE)
			return
			
	var p_pos := target_player.global_position
	var dist := global_position.distance_to(p_pos)
	
	# Stop following if player is too far (e.g. left house to neighborhood) or timeout
	if dist > 8.0 or state_timer > 25.0:
		switch_activity(Activity.RESTING)
		return
		
	# Check doorway blocking avoidance: don't get trapped in doorway
	if _is_in_doorway(global_position):
		target_nav_point = _room_to_global(Vector3(0, 0, -1.0))
		_move_towards(target_nav_point, WALK_SPEED, delta)
		return
		
	if dist > STOP_DISTANCE_TO_PLAYER:
		var speed := RUN_SPEED if dist > 3.0 else WALK_SPEED
		play_animation("run" if dist > 3.0 else "walk")
		_move_towards(p_pos, speed, delta)
	else:
		# Arrived near player
		velocity = Vector3.ZERO
		_face_towards(p_pos, delta * 5.0)
		play_animation("sit")
		
		# Occasionally purr / meow
		if randf() < 0.01:
			show_mood_emote("❤️" if affection >= 50.0 else "😸")
			
		# If player has stood still for a while, transition to resting
		if state_timer > 12.0:
			switch_activity(Activity.RESTING)

func _approach_prop(prop: PetProp, delta: float) -> bool:
	var away := global_position - prop.global_position
	away.y = 0.0
	if away.length_squared() < 0.001:
		away = Vector3.BACK
	var approach := prop.global_position + away.normalized() * 0.55
	if _move_towards(approach, WALK_SPEED, delta):
		_face_towards(prop.global_position, delta * 8.0)
		return true
	play_animation("walk")
	return false

func _process_eating(delta: float) -> void:
	if not _is_prop_usable(target_prop) or target_prop.prop_type != "food_bowl":
		target_prop = _find_filled_prop("food_bowl")
	if not is_instance_valid(target_prop):
		switch_activity(Activity.IDLE)
		return
	if not _approach_prop(target_prop, delta):
		activity_elapsed = 0.0
		return
	play_animation("eat")
	activity_elapsed += delta
	if activity_elapsed >= 3.5:
		if not target_prop.use_by_pet(self):
			switch_activity(Activity.IDLE)
			return
		hunger = minf(100.0, hunger + 45.0)
		happiness = minf(100.0, happiness + 15.0)
		affection = minf(100.0, affection + 2.0)
		show_mood_emote("❤️")
		switch_activity(Activity.RESTING)

func _process_drinking(delta: float) -> void:
	if not _is_prop_usable(target_prop) or target_prop.prop_type != "water_bowl":
		target_prop = _find_filled_prop("water_bowl")
	if not is_instance_valid(target_prop):
		switch_activity(Activity.IDLE)
		return
	if not _approach_prop(target_prop, delta):
		activity_elapsed = 0.0
		return
	play_animation("drink")
	activity_elapsed += delta
	if activity_elapsed >= 3.0:
		if not target_prop.use_by_pet(self):
			switch_activity(Activity.IDLE)
			return
		thirst = minf(100.0, thirst + 45.0)
		happiness = minf(100.0, happiness + 10.0)
		show_mood_emote("❤️")
		switch_activity(Activity.RESTING)

func _process_playing(delta: float) -> void:
	if target_nav_point != Vector3.ZERO:
		var away := global_position - target_nav_point
		away.y = 0.0
		if away.length_squared() < 0.001:
			away = Vector3.BACK
		var approach := target_nav_point + away.normalized() * 0.55
		if not _move_towards(approach, WALK_SPEED, delta):
			play_animation("walk")
			return
		target_nav_point = Vector3.ZERO
		activity_elapsed = 0.0
	play_animation("play")
	activity_elapsed += delta
	if activity_elapsed >= 4.0:
		happiness = minf(100.0, happiness + 25.0)
		affection = minf(100.0, affection + 5.0)
		hunger = maxf(10.0, hunger - 5.0)
		show_mood_emote("✨")
		switch_activity(Activity.IDLE)
		pet_interacted.emit("played")

func _process_sleeping(delta: float) -> void:
	if sleeping_on_bed and not _is_prop_usable(target_prop):
		switch_activity(Activity.IDLE)
		return
	if not sleeping_on_bed:
		if not _is_prop_usable(target_prop) or target_prop.prop_type != "pet_bed":
			target_prop = _find_prop("pet_bed")
		if not is_instance_valid(target_prop):
			switch_activity(Activity.RESTING)
			return
		var bed_position: Vector3 = target_prop.global_position
		var away := global_position - bed_position
		away.y = 0.0
		if away.length_squared() < 0.001:
			away = Vector3.BACK
		var approach := bed_position + away.normalized() * 0.7
		if not _move_towards(approach, WALK_SPEED, delta):
			play_animation("walk")
			return
		var player := _find_nearest_player()
		if is_instance_valid(player) and player.global_position.distance_to(bed_position) < 0.7:
			return
		# The small bed is a solid furnishing; only the cat ignores it while asleep.
		bed_exit_position = global_position
		collision_mask = 0
		global_position = bed_position
		velocity = Vector3.ZERO
		sleeping_on_bed = true
		activity_elapsed = 0.0
		target_prop.use_by_pet(self)
	play_animation("sleep")
	set_expression("sleep")
	activity_elapsed += delta
	happiness = minf(100.0, happiness + delta * 0.5)
	var clock := get_tree().get_first_node_in_group("time_manager") as NeighborhoodTimeManager
	var daytime := is_instance_valid(clock) and clock.current_hour >= 6.0 and clock.current_hour < 21.0
	if activity_elapsed > 15.0 and (hunger < 25.0 or daytime):
		switch_activity(Activity.IDLE)

func _process_resting(delta: float) -> void:
	play_animation("sit")
	velocity = Vector3.ZERO
	
	if state_timer >= 8.0:
		switch_activity(Activity.IDLE)

# -----------------------------------------------------------------
# Navigation & Obstacle Avoidance (Requirement 3 & 8)
# -----------------------------------------------------------------
func _move_towards(target_pos: Vector3, speed: float, delta: float) -> bool:
	var to_target := target_pos - global_position
	to_target.y = 0.0
	var dist := to_target.length()
	
	if dist <= 0.25:
		velocity = Vector3.ZERO
		return true # Arrived!
		
	var dir := to_target.normalized()
	
	# Avoid walls and furniture with forward avoidance probe
	var probe_offset := dir * 0.45
	var probe_target := global_position + probe_offset
	if _is_point_blocked_or_out_of_bounds(probe_target):
		# Deflect left or right to slide along obstacle
		var left_probe := dir.rotated(Vector3.UP, deg_to_rad(55.0))
		if not _is_point_blocked_or_out_of_bounds(global_position + left_probe * 0.45):
			dir = left_probe
		else:
			dir = dir.rotated(Vector3.UP, deg_to_rad(-55.0))
			
	# Do not enter doorway threshold to keep doorway clear
	if _is_in_doorway(global_position + dir * 0.3):
		dir = (_room_to_global(Vector3(0, 0, -1.0)) - global_position).normalized()
		
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	velocity.y = 0.0
	
	move_and_slide()
	
	# Rotate smoothly towards movement direction
	var target_yaw := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 10.0 * delta)
	
	# Stuck detection & recovery
	if (global_position - last_pos).length() < 0.02 * (speed / WALK_SPEED):
		stuck_timer += delta
		if stuck_timer > 2.5:
			_recover_from_stuck()
	else:
		stuck_timer = 0.0
		last_pos = global_position
		
	return false

func _face_towards(target_pos: Vector3, turn_rate: float) -> void:
	var to_target := target_pos - global_position
	to_target.y = 0.0
	if to_target.length_squared() > 0.01:
		var target_yaw := atan2(to_target.x, to_target.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, turn_rate)

func _room_to_global(point: Vector3) -> Vector3:
	var room := get_tree().get_first_node_in_group("room") as Node3D
	return room.to_global(point) if is_instance_valid(room) else point

func _room_to_local(point: Vector3) -> Vector3:
	var room := get_tree().get_first_node_in_group("room") as Node3D
	return room.to_local(point) if is_instance_valid(room) else point

func _is_point_blocked_or_out_of_bounds(p: Vector3) -> bool:
	var local := _room_to_local(p)
	if local.x < SAFE_ROOM_MIN.x or local.x > SAFE_ROOM_MAX.x:
		return true
	var min_z := -6.8 if exploring_garden else SAFE_ROOM_MIN.y
	if local.z < min_z or local.z > SAFE_ROOM_MAX.y or (not exploring_garden and _is_in_doorway(p)):
		return true
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.2, p + Vector3.UP * 0.2, 1, [get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _pick_random_garden_point() -> Vector3:
	var garden_mgr := get_tree().get_first_node_in_group("garden_manager") if is_inside_tree() else null
	if is_instance_valid(garden_mgr) and "garden_root" in garden_mgr and is_instance_valid(garden_mgr.garden_root):
		var origin: Vector3 = (garden_mgr.garden_root as Node3D).global_position
		return origin + Vector3(randf_range(-2.4, 2.4), 0.0, randf_range(-1.4, 1.0))
	var pt := Vector3(randf_range(-2.2, 2.2), 0.0, randf_range(8.4, 10.6))
	return _room_to_global(pt)

func _is_in_doorway(p: Vector3) -> bool:
	var local := _room_to_local(p)
	return local.z < -3.6 and absf(local.x) < 1.6

func _pick_random_room_point() -> Vector3:
	var pt := Vector3(
		randf_range(SAFE_ROOM_MIN.x + 0.5, SAFE_ROOM_MAX.x - 0.5),
		0.0,
		randf_range(SAFE_ROOM_MIN.y + 0.5, SAFE_ROOM_MAX.y - 0.5)
	)
	return _room_to_global(pt)

func _recover_from_stuck() -> void:
	stuck_timer = 0.0
	target_nav_point = _room_to_global(home_position)
	switch_activity(Activity.IDLE)

# -----------------------------------------------------------------
# External Notification & Prop Triggers (Requirement 4)
# -----------------------------------------------------------------
func notify_food_ready(food_pos: Vector3) -> void:
	target_nav_point = food_pos
	target_prop = _find_filled_prop("food_bowl")
	switch_activity(Activity.EATING)
	show_mood_emote("🐟")

func notify_water_ready(water_pos: Vector3) -> void:
	target_nav_point = water_pos
	target_prop = _find_filled_prop("water_bowl")
	switch_activity(Activity.DRINKING)
	show_mood_emote("💧")

func notify_toy_played(toy_pos: Vector3) -> void:
	target_nav_point = toy_pos
	switch_activity(Activity.PLAYING)
	show_mood_emote("✨")

func _is_prop_usable(prop: PetProp) -> bool:
	if not is_instance_valid(prop) or not prop.is_inside_tree():
		return false
	var node: Node = prop
	while is_instance_valid(node):
		if node.is_queued_for_deletion() or (node is Node3D and not node.visible):
			return false
		node = node.get_parent()
	return true

func _find_prop(type_name: String) -> PetProp:
	for node in get_tree().get_nodes_in_group("pet_props"):
		if node is PetProp and _is_prop_usable(node) and node.prop_type == type_name:
			return node
	return null

func _find_filled_prop(type_name: String) -> PetProp:
	for node in get_tree().get_nodes_in_group("pet_props"):
		if node is PetProp and _is_prop_usable(node) and node.prop_type == type_name and node.fill_amount > 0.05:
			return node
	return null

func _find_nearest_player() -> CharacterBody3D:
	var players := get_tree().get_nodes_in_group("players")
	var nearest: CharacterBody3D = null
	var min_dist := 999999.0
	for p in players:
		if p is CharacterBody3D:
			var d := global_position.distance_to(p.global_position)
			if d < min_dist:
				min_dist = d
				nearest = p
	return nearest

# -----------------------------------------------------------------
# Daily Progression & Wake-Up (Requirement 6)
# -----------------------------------------------------------------
func on_day_advanced(_new_day: int) -> void:
	# Stat decay was handled by PetManager, wake up if sleeping
	if current_activity == Activity.SLEEPING:
		switch_activity(Activity.IDLE)

func on_morning_wake_up() -> void:
	switch_activity(Activity.IDLE)
	set_expression("alert")
	show_mood_emote("😸")
	
	# If high affection, run to greet player!
	if affection >= 60.0:
		var p := _find_nearest_player()
		if is_instance_valid(p):
			target_player = p
			switch_activity(Activity.FOLLOWING)

# -----------------------------------------------------------------
# Mood Feedback Billboard (Requirement 4)
# -----------------------------------------------------------------
func show_mood_emote(emote: String) -> void:
	if not is_instance_valid(mood_label): return
	mood_label.text = emote
	mood_label.visible = true
	mood_display_timer = 3.5

func _update_mood_display(delta: float) -> void:
	if not is_instance_valid(mood_label): return
	if mood_display_timer > 0.0:
		mood_display_timer -= delta
		# Gentle bobbing
		mood_label.position.y = 0.45 + sin(Time.get_ticks_msec() * 0.005) * 0.04
		if mood_display_timer <= 0.0 and current_activity != Activity.SLEEPING:
			mood_label.visible = false
	elif current_activity == Activity.SLEEPING:
		mood_label.text = "💤"
		mood_label.visible = true
		mood_label.position.y = 0.42 + sin(Time.get_ticks_msec() * 0.003) * 0.03

# -----------------------------------------------------------------
# Public Animation & Visual API
# -----------------------------------------------------------------
func play_animation(anim_name: String) -> void:
	if is_instance_valid(anim_controller):
		anim_controller.set_state(anim_name)

func set_expression(expr: String) -> void:
	if is_instance_valid(visual):
		visual.set_expression(expr)

func set_collar_visible(is_vis: bool) -> void:
	has_collar = is_vis
	if is_instance_valid(visual):
		visual.set_collar_visible(is_vis)

func get_head_anchor() -> Marker3D:
	return visual.get_head_anchor() if is_instance_valid(visual) else null

func get_mouth_anchor() -> Marker3D:
	return visual.get_mouth_anchor() if is_instance_valid(visual) else null

# -----------------------------------------------------------------
# Interactable API (Petting, Feeding & Affection)
# -----------------------------------------------------------------
func available(player: Node3D) -> bool:
	if not is_inside_tree() or not is_instance_valid(player):
		return false
	var query := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP * 0.5, global_position + Vector3.UP * 0.2, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func prompt(_player: Node3D) -> String:
	var econ := get_tree().get_first_node_in_group("economy_manager") as EconomyManager
	if hunger < 50.0 and is_instance_valid(econ) and econ.inventory and econ.inventory.has_item("pet_food_salmon"):
		return "Cho %s ăn hạt cá hồi 🐟 · [N] Đổi tên" % pet_name
	return "Vuốt ve %s · [N] Đổi tên" % pet_name

func interact(player_node: Node3D) -> void:
	if current_activity == Activity.SLEEPING:
		switch_activity(Activity.IDLE)
	var econ := get_tree().get_first_node_in_group("economy_manager") as EconomyManager
	var fx = get_tree().get_first_node_in_group("chaos_feedback")
	
	# Hand-feed treat if hungry and player has food in inventory
	if hunger < 50.0 and is_instance_valid(econ) and econ.inventory and econ.inventory.has_item("pet_food_salmon"):
		econ.inventory.remove_item("pet_food_salmon", 1)
		hunger = minf(100.0, hunger + 40.0)
		happiness = minf(100.0, happiness + 20.0)
		affection = minf(100.0, affection + 5.0)
		play_animation("eat")
		set_expression("happy")
		show_mood_emote("❤️")
		if is_instance_valid(fx):
			fx.play_event("pickup", global_position + Vector3(0, 0.35, 0))
			fx.show_toast("🐟 Bạn đã cho %s ăn hạt cá hồi trực tiếp! Bé rất hạnh phúc! 💖" % pet_name)
		pet_interacted.emit("fed")
		stats_changed.emit(hunger, happiness, affection)
		return
		
	# Standard Petting Interaction (Increases affection & happiness)
	affection = minf(100.0, affection + 4.0)
	happiness = minf(100.0, happiness + 15.0)
	play_animation("happy")
	set_expression("happy")
	show_mood_emote("❤️")
	
	if is_instance_valid(fx):
		if fx.has_method("play_event"):
			fx.play_event("pickup", global_position + Vector3(0, 0.35, 0))
		if fx.has_method("show_toast"):
			var toast_msg := ""
			if affection >= 70.0:
				var t3 := [
					"🐱 %s cực kỳ quấn quýt! Nhảy cẫng lên và dụi đầu làm nũng! 🥰💖",
					"🐱 %s purr rừ rừ vang cả phòng, ngửa bụng cho bạn vuốt ve! ✨",
					"🐱 %s bám lấy chân bạn âu yếm, không nỡ rời xa! 🌸"
				]
				toast_msg = t3[randi() % t3.size()]
			elif affection >= 30.0:
				var t2 := [
					"🐱 %s dụi đầu vào tay bạn làm nũng! (Rừ rừ... ✨)",
					"🐱 %s vẫy đuôi vui sướng, kêu meo meo ngọt ngào! 💖",
					"🐱 %s thích thú ưỡn cằm cho bạn gãi! 🌸"
				]
				toast_msg = t2[randi() % t2.size()]
			else:
				toast_msg = "🐱 %s hơi bỡ ngỡ nhưng đã ngoan ngoãn để bạn vuốt ve nhẹ nhàng! 🐾"
			fx.show_toast(toast_msg)
			
	pet_interacted.emit("petted")
	stats_changed.emit(hunger, happiness, affection)
