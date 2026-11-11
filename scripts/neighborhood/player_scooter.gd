class_name PlayerScooter
extends Interactable

## Playable motorcycle controller for Boy & Girl to commute between home and workplace.
## Supports mounting/dismounting with E, driving at 8.5 m/s (13 m/s turbo Shift),
## rotating wheels, realistic lean banking, exhaust smoke, and dedicated parking spots.

signal mounted_by_player(player_node: CharacterBody3D)
signal dismounted_by_player(player_node: CharacterBody3D)
signal parked_at_destination(spot_name: String)

@export var owner_character: String = "boy" # "boy" or "girl"
@export var scooter_color: Color = Color("00897b") # Teal for Boy, Coral for Girl
@export var destination_name: String = "Chỗ làm"
@export var home_parking_pos: Vector3 = Vector3(-48, 0, 72)
@export var work_parking_pos: Vector3 = Vector3(-58, 0, -13)

var is_mounted: bool = false
var rider: CharacterBody3D = null

var scooter_root: Node3D
var wheels: Array[MeshInstance3D] = []
var exhaust_particles: CPUParticles3D
var kickstand: MeshInstance3D
var headlight: OmniLight3D
var status_label: Label3D

var auto_cruising: bool = false
var cruise_waypoints: Array[Vector3] = []
var cruise_waypoint_idx: int = 0
var cruise_target_is_work: bool = true

var roll_distance: float = 0.0
var current_lean: float = 0.0

func _ready() -> void:
	kind = "player_scooter"
	add_to_group("interactables")
	add_to_group("player_scooters")
	
	_build_scooter_mesh()
	_update_label()

func available(player_node: Node3D) -> bool:
	if not enabled or is_mounted: return false
	# Can only mount if not carrying heavy furniture
	if player_node.has_meta("carrying_heavy"): return false
	# Optional soft character preference (allows anyone to ride if solo)
	return true

func prompt(player_node: Node3D) -> String:
	var char_name: String = player_node.get("selected_character") if "selected_character" in player_node else ""
	var is_owner: bool = (char_name == owner_character)
	var title := "Xe máy của %s" % ("Boy" if owner_character == "boy" else "Girl")
	var dest := destination_name if global_position.distance_to(home_parking_pos) < 15.0 else "Nhà"
	return "Lên %s đi %s" % [title, dest]

func interact(player_node: Node3D) -> void:
	if is_mounted: return
	if player_node is CharacterBody3D:
		mount(player_node as CharacterBody3D)

func _build_scooter_mesh() -> void:
	scooter_root = Node3D.new()
	scooter_root.name = "ScooterVisual"
	add_child(scooter_root)
	
	var dark_mat := StandardMaterial3D.new()
	dark_mat.albedo_color = Color("263238")
	dark_mat.roughness = 0.8
	
	var paint_mat := StandardMaterial3D.new()
	paint_mat.albedo_color = scooter_color
	paint_mat.roughness = 0.5
	
	var metal_mat := StandardMaterial3D.new()
	metal_mat.albedo_color = Color("cfd8dc")
	metal_mat.metallic = 0.8
	
	# 1. Wheels (front and rear)
	for z_pos in [-0.62, 0.62]:
		var wheel_mesh := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.28
		cyl.bottom_radius = 0.28
		cyl.height = 0.18
		cyl.radial_segments = 14
		wheel_mesh.mesh = cyl
		wheel_mesh.material_override = dark_mat
		wheel_mesh.position = Vector3(0, 0.3, z_pos)
		wheel_mesh.rotation.z = PI / 2.0
		scooter_root.add_child(wheel_mesh)
		wheels.append(wheel_mesh)
	
	# 2. Main body and footboard
	var body := MeshInstance3D.new()
	var b_box := BoxMesh.new()
	b_box.size = Vector3(0.48, 0.42, 1.15)
	body.mesh = b_box
	body.material_override = paint_mat
	body.position = Vector3(0, 0.62, 0.15)
	scooter_root.add_child(body)
	
	# 3. Comfortable seat
	var seat := MeshInstance3D.new()
	var s_box := BoxMesh.new()
	s_box.size = Vector3(0.42, 0.15, 0.65)
	seat.mesh = s_box
	seat.material_override = dark_mat
	seat.position = Vector3(0, 0.94, 0.32)
	scooter_root.add_child(seat)
	
	# 4. Front steering column and handlebars
	var column := MeshInstance3D.new()
	var c_box := BoxMesh.new()
	c_box.size = Vector3(0.28, 1.05, 0.25)
	column.mesh = c_box
	column.material_override = paint_mat
	column.position = Vector3(0, 1.0, -0.6)
	scooter_root.add_child(column)
	
	var bar := MeshInstance3D.new()
	var bar_box := BoxMesh.new()
	bar_box.size = Vector3(0.75, 0.09, 0.12)
	bar.mesh = bar_box
	bar.material_override = dark_mat
	bar.position = Vector3(0, 1.55, -0.6)
	scooter_root.add_child(bar)
	
	# 5. Headlight
	var light_mesh := MeshInstance3D.new()
	var l_cyl := CylinderMesh.new()
	l_cyl.top_radius = 0.12
	l_cyl.bottom_radius = 0.12
	l_cyl.height = 0.08
	light_mesh.mesh = l_cyl
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color("fff9c4")
	glow_mat.emission_enabled = true
	glow_mat.emission = Color("fff9c4")
	glow_mat.emission_energy_multiplier = 1.5
	light_mesh.material_override = glow_mat
	light_mesh.position = Vector3(0, 1.35, -0.74)
	light_mesh.rotation.x = PI / 2.0
	scooter_root.add_child(light_mesh)
	
	# 6. Kickstand
	kickstand = MeshInstance3D.new()
	var k_box := BoxMesh.new()
	k_box.size = Vector3(0.06, 0.45, 0.06)
	kickstand.mesh = k_box
	kickstand.material_override = metal_mat
	kickstand.position = Vector3(-0.25, 0.2, 0.1)
	kickstand.rotation.z = -0.35
	scooter_root.add_child(kickstand)
	
	# 7. Subtle exhaust smoke
	exhaust_particles = CPUParticles3D.new()
	exhaust_particles.emitting = false
	exhaust_particles.amount = 6
	exhaust_particles.lifetime = 0.35
	exhaust_particles.direction = Vector3(0, 0.2, 1.0)
	exhaust_particles.spread = 22.0
	exhaust_particles.initial_velocity_min = 1.0
	exhaust_particles.initial_velocity_max = 2.0
	exhaust_particles.gravity = Vector3(0, 0.5, 0)
	exhaust_particles.scale_amount_min = 0.08
	exhaust_particles.scale_amount_max = 0.16
	exhaust_particles.color = Color(0.85, 0.85, 0.85, 0.35)
	exhaust_particles.position = Vector3(0.18, 0.32, 0.72)
	scooter_root.add_child(exhaust_particles)
	
	# 8. Floating status label
	status_label = Label3D.new()
	status_label.position = Vector3(0, 2.1, 0)
	status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	status_label.font_size = 22
	status_label.pixel_size = 0.004
	status_label.outline_size = 6
	status_label.modulate = Color("e0f2f1")
	status_label.outline_modulate = Color("1a1a1a")
	add_child(status_label)

func _update_label() -> void:
	if not is_instance_valid(status_label): return
	if is_mounted:
		status_label.visible = false
		return
	
	status_label.visible = true
	var char_title := "Boy" if owner_character == "boy" else "Girl"
	var at_home: bool = global_position.distance_to(home_parking_pos) < 15.0
	if at_home:
		status_label.text = "🛵 Xe máy của %s\n[E] Lên xe đi %s" % [char_title, destination_name]
	else:
		status_label.text = "🛵 Xe máy của %s\n[E] Lên xe về nhà" % char_title

func mount(player_node: CharacterBody3D) -> void:
	if is_mounted: return
	is_mounted = true
	rider = player_node
	rider.set_meta("riding_scooter", self)
	
	# Fold kickstand up
	if is_instance_valid(kickstand):
		kickstand.visible = false
	if is_instance_valid(exhaust_particles):
		exhaust_particles.emitting = true
	
	# Attach scooter to player node
	reparent(rider)
	position = Vector3(0, 0, 0)
	rotation = Vector3.ZERO
	
	# Seat rider onto scooter
	_apply_seated_pose(true)
	_update_label()
	
	mounted_by_player.emit(rider)

func dismount(snap_to_spot: Vector3 = Vector3.ZERO) -> void:
	if not is_mounted or not is_instance_valid(rider): return
	
	var current_world_pos := rider.global_position
	var current_world_rot_y := rider.rotation.y
	
	# Detach from player and place in world
	rider.remove_meta("riding_scooter")
	_apply_seated_pose(false)
	
	reparent(rider.get_parent())
	
	if snap_to_spot != Vector3.ZERO:
		global_position = snap_to_spot
	else:
		# Check if within 5.0m of home or work parking spot
		var dist_home := current_world_pos.distance_to(home_parking_pos)
		var dist_work := current_world_pos.distance_to(work_parking_pos)
		if dist_home < 5.0:
			global_position = home_parking_pos
			rotation.y = PI # Face road
			parked_at_destination.emit("home")
		elif dist_work < 5.0:
			global_position = work_parking_pos
			rotation.y = PI / 2.0 if owner_character == "boy" else 0.0
			parked_at_destination.emit("work")
		else:
			global_position = current_world_pos
			rotation.y = current_world_rot_y
	
	# Put kickstand down
	if is_instance_valid(kickstand):
		kickstand.visible = true
	if is_instance_valid(exhaust_particles):
		exhaust_particles.emitting = false
	
	is_mounted = false
	auto_cruising = false
	var ex_rider = rider
	rider = null
	
	_update_label()
	dismounted_by_player.emit(ex_rider)

func _apply_seated_pose(seated: bool) -> void:
	if not is_instance_valid(rider): return
	var model = rider.get_node_or_null("Visual/boy_model")
	if not model: model = rider.get_node_or_null("Visual/girl_model")
	if not model and rider.has_node("Visual"):
		for ch in rider.get_node("Visual").get_children():
			if ch.has_method("_pose_joint"):
				model = ch
				break
	
	if is_instance_valid(model) and model.has_method("_pose_joint"):
		if seated:
			# Natural scooter driving pose
			model.position = Vector3(0, 0.35, 0.20)
			model._pose_joint("left_leg", Vector3(-1.15, 0, 0.2))
			model._pose_joint("right_leg", Vector3(-1.15, 0, -0.2))
			model._pose_joint("left_arm", Vector3(-0.65, 0, 0.2))
			model._pose_joint("right_arm", Vector3(-0.65, 0, -0.2))
		else:
			model.position = Vector3.ZERO
			model._pose_joint("left_leg", Vector3.ZERO)
			model._pose_joint("right_leg", Vector3.ZERO)
			model._pose_joint("left_arm", Vector3.ZERO)
			model._pose_joint("right_arm", Vector3.ZERO)

func update_riding(delta: float, direction: Vector3, current_speed: float, is_running: bool) -> void:
	if not is_mounted or not is_instance_valid(rider): return
	
	# 1. Roll wheels based on distance moved
	var move_dist := current_speed * delta * direction.length()
	roll_distance += move_dist
	for w in wheels:
		if is_instance_valid(w):
			w.rotate_x(move_dist * 4.0)
	
	# 2. Smooth motorcycle lean when steering
	var target_lean := 0.0
	if direction.length() > 0.1:
		var target_rot := atan2(direction.x, direction.z) + PI # Scooter visual faces -Z
		rider.facing = direction.normalized()
		rider.rotation.y = lerp_angle(rider.rotation.y, target_rot, 1.0 - exp(-12.0 * delta))
		
		# Compute horizontal turn rate for lean angle
		var turn_diff := wrapf(target_rot - rider.rotation.y, -PI, PI)
		target_lean = clampf(turn_diff * 0.45, -0.18, 0.18)
	
	current_lean = lerpf(current_lean, target_lean, 1.0 - exp(-10.0 * delta))
	scooter_root.rotation.z = current_lean
	
	# 3. Check for auto-cruise trigger
	var prefix := "p%d_" % rider.player_id
	if InputMap.has_action(prefix + "throw") and Input.is_action_just_pressed(prefix + "throw") and not auto_cruising:
		start_auto_cruise()
	
	if auto_cruising:
		_process_auto_cruise(delta)

func get_riding_prompt() -> String:
	var dist_work := global_position.distance_to(work_parking_pos)
	var dist_home := global_position.distance_to(home_parking_pos)
	if dist_work < 4.5:
		return "E — Đỗ xe vào bãi tiệm · [Shift] Lái xe"
	elif dist_home < 4.5:
		return "E — Đỗ xe vào bãi nhà · [Shift] Lái xe"
	elif auto_cruising:
		var dest_txt := destination_name if cruise_target_is_work else "nhà"
		return "Đang tự lái đến %s... · [E] Dừng xe" % dest_txt
	else:
		var target_txt := destination_name if dist_home < 25.0 else "về nhà"
		return "E — Xuống xe · F — Tự lái %s · [Shift] Tăng tốc" % target_txt

func start_auto_cruise() -> void:
	auto_cruising = true
	cruise_waypoint_idx = 0
	
	var is_near_home := global_position.distance_to(home_parking_pos) < 25.0
	cruise_target_is_work = is_near_home
	
	if cruise_target_is_work:
		if owner_character == "boy":
			# Road path from house to garage:
			# Home parking -> yard gate -> local road -> west avenue -> boulevard -> garage driveway -> bay
			cruise_waypoints = [
				home_parking_pos,
				Vector3(-45, 0, 64),
				Vector3(-45, 0, 50),
				Vector3(-80, 0, 50),
				Vector3(-80, 0, 0),
				Vector3(-63, 0, 0),
				Vector3(-63, 0, -8),
				work_parking_pos
			]
		else:
			# Road path from house to hu tieu shop:
			# Home parking -> yard gate -> local road -> center avenue -> boulevard -> noodle stall front -> bay
			cruise_waypoints = [
				home_parking_pos,
				Vector3(-45, 0, 64),
				Vector3(-45, 0, 50),
				Vector3(0, 0, 50),
				Vector3(0, 0, 0),
				Vector3(-44, 0, 0),
				Vector3(-44, 0, -8),
				work_parking_pos
			]
	else:
		# Return to house path strictly following the road grid
		if owner_character == "boy":
			cruise_waypoints = [
				work_parking_pos,
				Vector3(-63, 0, -8),
				Vector3(-63, 0, 0),
				Vector3(-80, 0, 0),
				Vector3(-80, 0, 50),
				Vector3(-45, 0, 50),
				Vector3(-45, 0, 64),
				home_parking_pos
			]
		else:
			cruise_waypoints = [
				work_parking_pos,
				Vector3(-44, 0, -8),
				Vector3(-44, 0, 0),
				Vector3(0, 0, 0),
				Vector3(0, 0, 50),
				Vector3(-45, 0, 50),
				Vector3(-45, 0, 64),
				home_parking_pos
			]

func _process_auto_cruise(delta: float) -> void:
	if not is_instance_valid(rider): return
	if cruise_waypoint_idx >= cruise_waypoints.size():
		auto_cruising = false
		dismount(work_parking_pos if cruise_target_is_work else home_parking_pos)
		return
	
	var target: Vector3 = cruise_waypoints[cruise_waypoint_idx]
	var to_target: Vector3 = target - rider.global_position
	to_target.y = 0.0
	var dist: float = to_target.length()
	
	var cruise_speed: float = 9.5
	# Smoothly decelerate near final destination spot
	if cruise_waypoint_idx == cruise_waypoints.size() - 1:
		cruise_speed = clampf(dist * 2.5, 2.0, 9.5)
	
	if dist <= cruise_speed * delta:
		rider.global_position.x = target.x
		rider.global_position.z = target.z
		cruise_waypoint_idx += 1
	else:
		var dir := to_target.normalized()
		rider.velocity.x = dir.x * cruise_speed
		rider.velocity.z = dir.z * cruise_speed
		rider.move_and_slide()
		
		# Face direction
		var target_rot := atan2(dir.x, dir.z) + PI
		rider.rotation.y = lerp_angle(rider.rotation.y, target_rot, 1.0 - exp(-12.0 * delta))
