extends Camera3D
var players: Array = []
var trauma := 0.0
var max_trauma_offset := 0.45
var max_trauma_roll := 0.06
var trauma_decay := 1.8
var base_position: Vector3

@export var default_size: float = 16.8
@export var indoor_size: float = 13.8
@export var riding_size: float = 19.5
@export var default_offset: Vector3 = Vector3(0.0, 19.5, 16.5)
@export var indoor_offset: Vector3 = Vector3(0.0, 15.0, 14.0)
@export var riding_offset: Vector3 = Vector3(0.0, 22.0, 18.0)

var smoothed_focus: Vector3 = Vector3.ZERO
var first_track: bool = true

func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	size = default_size
	current = true
	position = default_offset
	base_position = position
	look_at(get_parent().to_global(Vector3(0, 0.2, -0.25)), Vector3.UP)

func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)

func _process(delta: float) -> void:
	if players.is_empty() or not is_instance_valid(players[0]):
		return
	var target_player: Node3D = players[0]
	var p_global: Vector3 = target_player.global_position
	var local_target: Vector3 = get_parent().to_local(p_global)
	
	var is_in_house: bool = (p_global.z > 81.5 and p_global.x > -56.0 and p_global.x < -34.0)
	var is_riding: bool = target_player.has_meta("riding_scooter") and is_instance_valid(target_player.get_meta("riding_scooter"))
	
	var desired_size: float = default_size
	var desired_offset: Vector3 = default_offset
	if is_in_house:
		desired_size = indoor_size
		desired_offset = indoor_offset
	elif is_riding:
		desired_size = riding_size
		desired_offset = riding_offset
	
	var target_base := local_target + desired_offset
	if first_track:
		base_position = target_base
		smoothed_focus = p_global + Vector3(0, 0.35, 0)
		size = desired_size
		first_track = false
	else:
		var follow_weight := 1.0 - exp(-10.0 * delta)
		base_position = base_position.lerp(target_base, follow_weight)
		smoothed_focus = smoothed_focus.lerp(p_global + Vector3(0, 0.35, 0), follow_weight)
		size = lerpf(size, desired_size, 1.0 - exp(-6.0 * delta))
	
	# Screen shake with quadratic trauma falloff
	if trauma > 0.0:
		trauma = maxf(0.0, trauma - trauma_decay * delta)
		var shake := trauma * trauma
		var offset_x := (randf() * 2.0 - 1.0) * max_trauma_offset * shake
		var offset_y := (randf() * 2.0 - 1.0) * max_trauma_offset * shake
		position = base_position + Vector3(offset_x, offset_y, 0)
		look_at(smoothed_focus, Vector3.UP)
		rotate_object_local(Vector3.BACK, (randf() * 2.0 - 1.0) * max_trauma_roll * shake)
	else:
		position = base_position
		look_at(smoothed_focus, Vector3.UP)
