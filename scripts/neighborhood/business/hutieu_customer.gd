class_name HuTieuCustomer
extends Node3D

## Manages an animated dining customer at the Hu Tieu Shop.
## Physically walks from the sidewalk to an available dining table, sits on a chair,
## orders food, eats upon being served, pays, and walks away naturally.

signal arrived_at_table(table_index: int)
signal departed_from_table(table_index: int)

enum State {
	WALKING_TO_TABLE,
	SEATED_ORDERING,
	EATING,
	ORDER_FAILED,
	LEAVING,
	DESPAWNED
}

var current_state: State = State.WALKING_TO_TABLE

var table_index: int = 0
var customer_name: String = "Bác Năm"
var customer_type: int = BusinessOrder.CustomerType.NORMAL
var table_position: Vector3 = Vector3.ZERO
var chair_position: Vector3 = Vector3.ZERO

var diner: NPCVisual
var speech_label: Label3D
var vip_marker: Label3D
var eating_bowl: Node3D

var waypoints: Array[Vector3] = []
var current_waypoint_idx: int = 0
var move_speed: float = 3.5

var departure_waypoints: Array[Vector3] = []
var state_timer: float = 0.0
var anim_time: float = 0.0
var movement_watchdog: float = 0.0
const MAX_MOVEMENT_TIME: float = 25.0

func setup(
	p_table_index: int,
	p_customer_name: String,
	p_table_pos: Vector3,
	p_approach_path: Array[Vector3],
	p_departure_path: Array[Vector3]
) -> void:
	table_index = p_table_index
	customer_name = p_customer_name
	table_position = p_table_pos
	chair_position = p_table_pos + Vector3(-0.95, 0, 0) # Chair on left side of table
	waypoints = p_approach_path
	departure_waypoints = p_departure_path
	
	if waypoints.size() > 0:
		position = waypoints[0]
		current_waypoint_idx = 1
	else:
		position = chair_position
	
	_build_visuals()

func _build_visuals() -> void:
	# 1. Customer NPCVisual
	diner = NPCVisual.new()
	diner.gender = "girl" if (randi() % 2 == 0) else "boy"
	diner.accessory = ["conical_hat", "glasses", "headband", "none"][randi() % 4]
	if customer_type == BusinessOrder.CustomerType.VIP:
		diner.shirt_color = Color("ffd54f")
	elif customer_type == BusinessOrder.CustomerType.EXPRESS:
		diner.shirt_color = Color("ff7043")
	else:
		diner.shirt_color = [Color("80deea"), Color("ce93d8"), Color("ffcc80"), Color("a5d6a7")][randi() % 4]
	diner.pants_color = Color("455a64")
	diner.hair_color = Color("212121")
	add_child(diner)
	
	# 2. Speech bubble (offset above table status label to avoid overlap)
	speech_label = Label3D.new()
	speech_label.position = Vector3(0, 3.0, 0)
	speech_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	speech_label.font_size = 20
	speech_label.pixel_size = 0.004
	speech_label.outline_size = 6
	speech_label.modulate = Color("fff9c4")
	speech_label.outline_modulate = Color("212121")
	speech_label.visible = false
	add_child(speech_label)
	
	if customer_type == BusinessOrder.CustomerType.VIP:
		vip_marker = Label3D.new()
		vip_marker.text = "👑 VIP"
		vip_marker.position = Vector3(0, 2.05, 0)
		vip_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		vip_marker.font_size = 24
		vip_marker.pixel_size = 0.004
		vip_marker.outline_size = 8
		vip_marker.modulate = Color("ffd54f")
		vip_marker.outline_modulate = Color("1a1a1a")
		diner.add_child(vip_marker)
	
	# 3. Eating bowl on table (appears when served)
	eating_bowl = Node3D.new()
	var b_mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.22
	cyl.bottom_radius = 0.12
	cyl.height = 0.16
	cyl.radial_segments = 16
	b_mesh.mesh = cyl
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("fafafa")
	b_mesh.material_override = m
	eating_bowl.add_child(b_mesh)
	eating_bowl.position = Vector3(0.55, 0.78, 0) # Sits on the table
	eating_bowl.visible = false
	add_child(eating_bowl)

func _process(delta: float) -> void:
	anim_time += delta
	
	match current_state:
		State.WALKING_TO_TABLE:
			_process_walking(delta, waypoints, true)
		State.SEATED_ORDERING:
			_process_seated(delta)
		State.EATING:
			_process_eating(delta)
		State.ORDER_FAILED:
			_process_order_failed(delta)
		State.LEAVING:
			_process_walking(delta, departure_waypoints, false)

func _process_walking(delta: float, path: Array[Vector3], is_arriving: bool) -> void:
	movement_watchdog += delta
	if movement_watchdog > MAX_MOVEMENT_TIME:
		movement_watchdog = 0.0
		if is_arriving:
			position = chair_position
			_on_reached_table()
		else:
			_on_departed()
		return
	
	if current_waypoint_idx >= path.size():
		movement_watchdog = 0.0
		if is_arriving:
			_on_reached_table()
		else:
			_on_departed()
		return
	
	var target: Vector3 = path[current_waypoint_idx]
	var to_target: Vector3 = target - position
	to_target.y = 0.0
	var dist: float = to_target.length()
	
	if dist > 0.05:
		var target_rot: float = atan2(to_target.x, to_target.z)
		rotation.y = lerp_angle(rotation.y, target_rot, 1.0 - exp(-10.0 * delta))
	
	var step: float = move_speed * delta
	if dist <= step:
		position.x = target.x
		position.z = target.z
		current_waypoint_idx += 1
	else:
		position += to_target.normalized() * step
	
	# Walking limb swing
	if is_instance_valid(diner):
		diner.update_animation(move_speed, anim_time, false)

func _on_reached_table() -> void:
	position = chair_position
	# Face squarely toward the dining table (+X direction)
	rotation.y = PI / 2.0
	
	# Sit down neatly on chair
	_sit_down_pose()
	current_state = State.SEATED_ORDERING
	if customer_type == BusinessOrder.CustomerType.VIP:
		_show_speech("Nghe tiếng quán ngon đã lâu, cho tôi một tô đặc biệt!", 2.8)
	elif customer_type == BusinessOrder.CustomerType.EXPRESS:
		_show_speech("Cho tôi một tô thật nhanh nhé, đang vội!", 2.5)
	else:
		_show_speech("Cô Bảy ơi, cho một tô hủ tiếu nóng nhé!", 2.5)
	
	arrived_at_table.emit(table_index)

func _sit_down_pose() -> void:
	if not is_instance_valid(diner): return
	# Align hips flush with chair seat (seat height 0.45m, hips pivot at 0.48m)
	diner.position = Vector3(0, 0.02, 0)
	if diner.has_method("_pose_joint"):
		# Legs bent forward and feet on the ground in front of chair
		diner._pose_joint("left_leg", Vector3(-1.35, 0.06, 0.06))
		diner._pose_joint("right_leg", Vector3(-1.35, -0.06, -0.06))
		# Arms resting politely on table surface
		diner._pose_joint("left_arm", Vector3(-0.75, 0.16, 0.12))
		diner._pose_joint("right_arm", Vector3(-0.75, -0.16, -0.12))
		diner._pose_joint("head", Vector3(0.04, 0, 0))

func _stand_up_pose() -> void:
	if not is_instance_valid(diner): return
	diner.position = Vector3.ZERO
	if diner.has_method("_pose_joint"):
		diner._pose_joint("left_leg", Vector3.ZERO)
		diner._pose_joint("right_leg", Vector3.ZERO)
		diner._pose_joint("left_arm", Vector3.ZERO)
		diner._pose_joint("right_arm", Vector3.ZERO)
		diner._pose_joint("head", Vector3.ZERO)

func _process_seated(delta: float) -> void:
	state_timer += delta
	if is_instance_valid(diner):
		# Gentle seated breathing
		diner.skeleton.position.y = sin(state_timer * 2.0) * 0.012

func notify_food_served() -> void:
	if current_state == State.EATING or current_state == State.LEAVING or current_state == State.DESPAWNED or current_state == State.ORDER_FAILED:
		return
	current_state = State.EATING
	state_timer = 0.0
	eating_bowl.visible = true
	_show_speech("Hủ tiếu thơm phức! Cảm ơn cô Bảy!", 2.0)

func _process_eating(delta: float) -> void:
	state_timer += delta
	if is_instance_valid(diner):
		# Left hand rests on table, right hand enjoys the hot noodle bowl
		diner._pose_joint("left_arm", Vector3(-0.75, 0.16, 0.12))
		var slurp := sin(state_timer * 5.0)
		diner._pose_joint("right_arm", Vector3(-0.95 + slurp * 0.22, -0.14, 0.08))
		diner._pose_joint("head", Vector3(0.08 + slurp * 0.10, 0, 0))
	
	# Eat for 2.4 seconds then stand up and depart
	if state_timer >= 2.4:
		_start_leaving()

func _start_leaving() -> void:
	if current_state == State.LEAVING or current_state == State.DESPAWNED:
		return
	eating_bowl.visible = false
	_stand_up_pose()
	if current_state != State.ORDER_FAILED:
		_show_speech("Ngon tuyệt cú mèo! Gửi tiền cô nhé!", 2.0)
	
	current_state = State.LEAVING
	current_waypoint_idx = 0
	move_speed = 3.6

func notify_order_failed(reason: String = "timeout") -> void:
	if current_state == State.ORDER_FAILED or current_state == State.LEAVING or current_state == State.DESPAWNED or current_state == State.EATING:
		return
	eating_bowl.visible = false
	_stand_up_pose()
	_show_speech("Đợi lâu quá đói lả cả người! Tôi đi chỗ khác đây! 💢", 2.2)
	current_state = State.ORDER_FAILED
	state_timer = 0.0

func _process_order_failed(delta: float) -> void:
	state_timer += delta
	if state_timer >= 0.8:
		_start_leaving()

func _on_departed() -> void:
	if current_state == State.DESPAWNED:
		return
	current_state = State.DESPAWNED
	departed_from_table.emit(table_index)
	queue_free()

func _show_speech(text: String, duration: float = 2.0) -> void:
	if not is_instance_valid(speech_label): return
	speech_label.text = text
	speech_label.visible = true
	var tween := create_tween()
	tween.tween_interval(duration)
	tween.tween_property(speech_label, "visible", false, 0.0)
