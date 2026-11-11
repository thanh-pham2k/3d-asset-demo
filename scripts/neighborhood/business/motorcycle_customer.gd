class_name MotorcycleCustomer
extends Node3D

## Manages an animated NPC customer arriving on a motorcycle, parking in a service bay,
## waiting during maintenance, celebrating completion, and riding away safely.

signal arrived_at_bay(bay_index: int)
signal departed_from_bay(bay_index: int)

enum State {
	APPROACHING,
	PARKED,
	WAITING_FOR_REPAIR,
	SERVICE_COMPLETED,
	DEPARTING,
	DESPAWNED
}

var current_state: State = State.APPROACHING

var bay_index: int = 0
var customer_name: String = "Anh Tuấn"
var order: BusinessOrder = null

var scooter: Node3D
var driver: NPCVisual
var speech_label: Label3D
var exhaust_particles: CPUParticles3D

var waypoints: Array[Vector3] = []
var current_waypoint_idx: int = 0
var move_speed: float = 6.0
var final_bay_position: Vector3 = Vector3.ZERO
var final_bay_rotation: float = PI / 2.0

var departure_waypoints: Array[Vector3] = []
var wait_timer: float = 0.0
var wheels: Array[Node3D] = []

func setup(
	p_bay_index: int,
	p_customer_name: String,
	p_bay_pos: Vector3,
	p_approach_path: Array[Vector3],
	p_departure_path: Array[Vector3]
) -> void:
	bay_index = p_bay_index
	customer_name = p_customer_name
	final_bay_position = p_bay_pos
	waypoints = p_approach_path
	departure_waypoints = p_departure_path
	
	if waypoints.size() > 0:
		position = waypoints[0]
		current_waypoint_idx = 1
	else:
		position = p_bay_pos
	
	_build_visuals()

func _build_visuals() -> void:
	# 1. Motorcycle / Scooter
	var scooter_scene: PackedScene = load("res://scenes/neighborhood/scooter.tscn")
	if scooter_scene:
		scooter = scooter_scene.instantiate()
	else:
		scooter = Node3D.new()
	add_child(scooter)
	
	# Cache wheels for rolling animation
	wheels.clear()
	for child in scooter.get_children():
		if child is MeshInstance3D and child.mesh is CylinderMesh:
			wheels.append(child)
	
	# 2. Driver NPC
	driver = NPCVisual.new()
	driver.gender = "boy" if (randi() % 2 == 0) else "girl"
	driver.accessory = "cap" if driver.gender == "boy" else "helmet"
	driver.shirt_color = [Color("e57373"), Color("64b5f6"), Color("81c784"), Color("ffb74d")][randi() % 4]
	driver.pants_color = Color("37474f")
	driver.hair_color = Color("2c3e50")
	scooter.add_child(driver)
	
	# Position driver on scooter seat
	_seat_driver_on_scooter()
	
	# 3. Speech bubble
	speech_label = Label3D.new()
	speech_label.position = Vector3(0, 2.1, 0)
	speech_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	speech_label.font_size = 22
	speech_label.pixel_size = 0.004
	speech_label.outline_size = 6
	speech_label.modulate = Color("fff9c4")
	speech_label.outline_modulate = Color("212121")
	speech_label.visible = false
	add_child(speech_label)
	
	# 4. Subtle exhaust smoke
	exhaust_particles = CPUParticles3D.new()
	exhaust_particles.emitting = true
	exhaust_particles.amount = 8
	exhaust_particles.lifetime = 0.4
	exhaust_particles.direction = Vector3(0, 0.3, 1.0)
	exhaust_particles.spread = 20.0
	exhaust_particles.initial_velocity_min = 1.0
	exhaust_particles.initial_velocity_max = 2.0
	exhaust_particles.gravity = Vector3(0, 0.5, 0)
	exhaust_particles.scale_amount_min = 0.08
	exhaust_particles.scale_amount_max = 0.16
	exhaust_particles.color = Color(0.8, 0.8, 0.8, 0.35)
	exhaust_particles.position = Vector3(0, 0.3, 0.7)
	scooter.add_child(exhaust_particles)

func _seat_driver_on_scooter() -> void:
	if not is_instance_valid(driver): return
	driver.position = Vector3(0, 0.45, 0.20)
	driver.rotation = Vector3.ZERO
	driver.visible = true
	
	# Sitting pose
	if driver.has_method("_pose_joint"):
		driver._pose_joint("left_leg", Vector3(-1.1, 0, 0.2))
		driver._pose_joint("right_leg", Vector3(-1.1, 0, -0.2))
		driver._pose_joint("left_arm", Vector3(-0.6, 0, 0.2))
		driver._pose_joint("right_arm", Vector3(-0.6, 0, -0.2))

func _stand_driver_beside_scooter() -> void:
	if not is_instance_valid(driver): return
	# Move driver to stand beside motorcycle
	driver.position = Vector3(-0.75, 0, 0.1)
	driver.rotation.y = PI / 4.0
	if driver.has_method("_pose_joint"):
		driver._pose_joint("left_leg", Vector3.ZERO)
		driver._pose_joint("right_leg", Vector3.ZERO)
		driver._pose_joint("left_arm", Vector3.ZERO)
		driver._pose_joint("right_arm", Vector3.ZERO)

func _process(delta: float) -> void:
	match current_state:
		State.APPROACHING:
			_process_movement(delta, waypoints, true)
		State.WAITING_FOR_REPAIR:
			_process_waiting(delta)
		State.SERVICE_COMPLETED:
			_process_service_completed(delta)
		State.DEPARTING:
			_process_movement(delta, departure_waypoints, false)

func _process_movement(delta: float, path: Array[Vector3], is_arriving: bool) -> void:
	if current_waypoint_idx >= path.size():
		if is_arriving:
			_on_arrived_at_bay()
		else:
			_on_departed()
		return
	
	var target: Vector3 = path[current_waypoint_idx]
	var to_target: Vector3 = target - position
	to_target.y = 0.0
	var dist: float = to_target.length()
	
	# Slow down smoothly when nearing the bay
	var current_speed: float = move_speed
	if is_arriving and current_waypoint_idx == path.size() - 1:
		current_speed = clampf(dist * 2.2, 1.2, move_speed)
	
	# Smoothly orient towards movement direction
	if dist > 0.05:
		var target_rot: float = atan2(to_target.x, to_target.z)
		rotation.y = lerp_angle(rotation.y, target_rot, 1.0 - exp(-10.0 * delta))
	
	# Move towards waypoint
	var step: float = current_speed * delta
	if dist <= step:
		position.x = target.x
		position.z = target.z
		current_waypoint_idx += 1
	else:
		position += to_target.normalized() * step
	
	# Roll wheels
	var roll_amount: float = current_speed * delta * 3.5
	for w in wheels:
		if is_instance_valid(w):
			w.rotate_x(roll_amount)

func _on_arrived_at_bay() -> void:
	current_state = State.PARKED
	position = final_bay_position
	rotation.y = final_bay_rotation
	
	if is_instance_valid(exhaust_particles):
		exhaust_particles.emitting = false
	
	_stand_driver_beside_scooter()
	_show_speech("Chào chú! Xem giúp tôi chiếc xe với!", 2.5)
	
	current_state = State.WAITING_FOR_REPAIR
	arrived_at_bay.emit(bay_index)

func _process_waiting(delta: float) -> void:
	if is_instance_valid(driver):
		# Gentle idle breathing
		wait_timer += delta
		driver.skeleton.position.y = sin(wait_timer * 2.5) * 0.015

func notify_service_done() -> void:
	current_state = State.SERVICE_COMPLETED
	wait_timer = 0.0
	_show_speech("Cảm ơn chú thợ! Xe chạy êm ru!", 2.0)
	
	# Driver mounts scooter
	_seat_driver_on_scooter()
	if is_instance_valid(exhaust_particles):
		exhaust_particles.emitting = true

func _process_service_completed(delta: float) -> void:
	wait_timer += delta
	# Pause 0.8s for celebration and engine startup
	if wait_timer >= 0.8:
		current_state = State.DEPARTING
		current_waypoint_idx = 0
		move_speed = 5.5

func _on_departed() -> void:
	current_state = State.DESPAWNED
	departed_from_bay.emit(bay_index)
	queue_free()

func _show_speech(text: String, duration: float = 2.0) -> void:
	if not is_instance_valid(speech_label): return
	speech_label.text = text
	speech_label.visible = true
	var tween := create_tween()
	tween.tween_interval(duration)
	tween.tween_property(speech_label, "visible", false, 0.0)
