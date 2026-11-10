class_name CoopHeavyObstacle
extends CharacterBody3D

## Large heavy object that requires dual player push force to move.
## Pushing alone barely moves it (0.1 m/s); pushing together moves it quickly (1.6 m/s).

signal obstacle_cleared()

@export var obstacle_name: String = "Xe máy chết máy cản đường"
@export var push_target_distance: float = 4.0

var total_distance_pushed: float = 0.0
var is_cleared: bool = false
var interacting_pushers: Array[CharacterBody3D] = []

var prompt_label: Label3D

func _ready() -> void:
	collision_layer = 1
	collision_mask = 7
	_build_visual()

func _build_visual() -> void:
	# Heavy wooden shipping container crate
	var mesh := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(2.2, 1.4, 1.4)
	mesh.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("8d6e63")
	mesh.material_override = mat
	mesh.position = Vector3(0, 0.7, 0)
	add_child(mesh)
	
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.2, 1.4, 1.4)
	col.shape = shape
	col.position = Vector3(0, 0.7, 0)
	add_child(col)
	
	prompt_label = Label3D.new()
	prompt_label.position = Vector3(0, 1.8, 0)
	prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt_label.font_size = 26
	prompt_label.modulate = Color("ffcc80")
	prompt_label.text = "⚠️ Vật cản nặng (Cần 2 người cùng đẩy)"
	add_child(prompt_label)

func register_pusher(p: CharacterBody3D) -> void:
	if not interacting_pushers.has(p):
		interacting_pushers.append(p)

func unregister_pusher(p: CharacterBody3D) -> void:
	interacting_pushers.erase(p)

func get_current_push_speed() -> float:
	return 1.6 if interacting_pushers.size() >= 2 else 0.2

func push(dir: Vector3, dist: float) -> void:
	total_distance_pushed += dist
	if total_distance_pushed >= push_target_distance and not is_cleared:
		is_cleared = true
		if is_instance_valid(prompt_label):
			prompt_label.text = "✨ ĐÃ DỌN SẠCH VẬT CẢN!"
			prompt_label.modulate = Color("69f0ae")
		obstacle_cleared.emit()

func _physics_process(delta: float) -> void:
	if is_cleared: return
	
	# Clean up pushers that moved away
	for i in range(interacting_pushers.size() - 1, -1, -1):
		var p := interacting_pushers[i]
		if not is_instance_valid(p) or global_position.distance_to(p.global_position) > 2.5:
			interacting_pushers.remove_at(i)
	
	if interacting_pushers.is_empty():
		velocity = velocity.move_toward(Vector3.ZERO, 5.0 * delta)
		move_and_slide()
		return
	
	# Determine combined push direction
	var push_dir := Vector3.ZERO
	for p in interacting_pushers:
		var f: Vector3 = p.get("facing") if p.get("facing") != null else Vector3.FORWARD
		push_dir += f
	push_dir = push_dir.normalized()
	
	# Speed: 1 pusher = 0.2 m/s. 2 pushers = 1.6 m/s (8x speedup!)
	var speed := 1.6 if interacting_pushers.size() >= 2 else 0.2
	velocity = push_dir * speed
	move_and_slide()
	
	var move_dist := velocity.length() * delta
	total_distance_pushed += move_dist
	
	if interacting_pushers.size() >= 2:
		prompt_label.text = "💪 CẢ HAI ĐANG ĐẨY CÙNG NHAU! (%d%%)" % int(minf(100.0, (total_distance_pushed / push_target_distance) * 100.0))
		prompt_label.modulate = Color("69f0ae")
	else:
		prompt_label.text = "⚠️ Quá nặng! Cần thêm 1 người cùng đẩy!"
		prompt_label.modulate = Color("ffcc80")
		
	if total_distance_pushed >= push_target_distance and not is_cleared:
		is_cleared = true
		prompt_label.text = "✨ ĐÃ DỌN SẠCH VẬT CẢN!"
		prompt_label.modulate = Color("69f0ae")
		obstacle_cleared.emit()
