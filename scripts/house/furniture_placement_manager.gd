class_name FurniturePlacementManager
extends Node

## Handles interactive furniture placement, preview ghosting,
## collision validation, movement, rotation, and rearranging.

signal placement_started(furniture_id: String)
signal placement_confirmed(furniture_id: String, placed_node: Node3D)
signal placement_cancelled(furniture_id: String)
signal placement_rejected(reason: String, message: String)

enum State { IDLE, PLACING, REARRANGING }
var state: State = State.IDLE

var active_furniture_id: String = ""
var preview_node: Node3D = null
var current_rotation: float = 0.0
var current_valid: bool = false
var last_validation_reason: String = ""

var original_node: Node3D = null
var original_transform: Transform3D
var original_collision_layers: Dictionary = {}

# Materials for preview
var mat_valid: StandardMaterial3D
var mat_invalid: StandardMaterial3D

func _init() -> void:
	mat_valid = StandardMaterial3D.new()
	mat_valid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_valid.albedo_color = Color(0.2, 0.9, 0.35, 0.6)
	mat_valid.emission_enabled = true
	mat_valid.emission = Color(0.1, 0.4, 0.15)
	
	mat_invalid = StandardMaterial3D.new()
	mat_invalid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_invalid.albedo_color = Color(0.95, 0.2, 0.2, 0.6)
	mat_invalid.emission_enabled = true
	mat_invalid.emission = Color(0.5, 0.1, 0.1)

func _ready() -> void:
	add_to_group("furniture_placement_manager")

func is_active() -> bool:
	return state != State.IDLE

func start_placement(furniture_id: String) -> void:
	cancel_placement()
	active_furniture_id = furniture_id
	current_rotation = 0.0
	state = State.PLACING
	_spawn_preview(furniture_id)
	placement_started.emit(furniture_id)

func start_rearrange(placed_node: Node3D) -> bool:
	if not is_instance_valid(placed_node): return false
	var fid: String = placed_node.get_meta("furniture_id", "")
	if fid == "": return false
	
	cancel_placement()
	original_node = placed_node
	original_transform = placed_node.transform
	active_furniture_id = fid
	current_rotation = placed_node.rotation.y
	state = State.REARRANGING
	
	# Disable collision and hide original while rearranging
	original_collision_layers.clear()
	_set_node_collision_active(original_node, false, true)
	original_node.visible = false
	
	_spawn_preview(fid)
	placement_started.emit(fid)
	return true

func rotate_preview() -> void:
	if not is_active(): return
	current_rotation = fmod(current_rotation + PI / 2.0, TAU)
	if is_instance_valid(preview_node):
		preview_node.rotation.y = current_rotation

func _spawn_preview(furniture_id: String) -> void:
	_cleanup_preview()
	preview_node = Node3D.new()
	preview_node.name = "PlacementPreview"
	preview_node.set_meta("is_furniture_preview", true)
	
	var visual := FurnitureData.create_visual_model(furniture_id)
	preview_node.add_child(visual)
	add_child(preview_node)
	_set_node_collision_active(preview_node, false)
	
	_apply_preview_material(mat_valid)

func _cleanup_preview() -> void:
	if is_instance_valid(preview_node):
		preview_node.queue_free()
		preview_node = null

func _apply_preview_material(mat: Material) -> void:
	if not is_instance_valid(preview_node): return
	_apply_material_recursive(preview_node, mat)

func _apply_material_recursive(n: Node, mat: Material) -> void:
	if n is MeshInstance3D:
		n.material_override = mat
	for child in n.get_children():
		_apply_material_recursive(child, mat)

func validate_placement(
	target_pos: Vector3,
	rot_y: float,
	space_state: PhysicsDirectSpaceState3D,
	room_bounds: AABB,
	player: Node3D = null,
	blocked_zones: Array[AABB] = []
) -> Dictionary:
	var def := FurnitureData.get_definition(active_furniture_id)
	var fp: Vector3 = def.get("footprint", Vector3(1, 1, 1))
	
	# 1. Bounds check (is object within the walkable house bounds)
	var half_x := (fp.x * 0.5) if abs(cos(rot_y)) > 0.5 else (fp.z * 0.5)
	var half_z := (fp.z * 0.5) if abs(cos(rot_y)) > 0.5 else (fp.x * 0.5)
	
	if target_pos.x - half_x < room_bounds.position.x or \
	   target_pos.x + half_x > room_bounds.end.x or \
	   target_pos.z - half_z < room_bounds.position.z or \
	   target_pos.z + half_z > room_bounds.end.z:
		return {"valid": false, "reason": "OUT_OF_BOUNDS", "message": "Ngoài phạm vi sàn nhà!"}

	# 1b. Prevent blocking doors or important interaction zones
	var furn_aabb := AABB(
		Vector3(target_pos.x - half_x, 0.0, target_pos.z - half_z),
		Vector3(half_x * 2.0, maxf(0.5, fp.y), half_z * 2.0)
	)
	for zone in blocked_zones:
		if furn_aabb.intersects(zone):
			return {"valid": false, "reason": "BLOCKING_INTERACTION", "message": "Không được chắn cửa ra vào hoặc khu vực tương tác!"}

	# 1c. Prevent duplicate unique furniture when placing a new item
	if state == State.PLACING and active_furniture_id in HouseProgressionManager.UNIQUE_FURNITURE_IDS:
		var house_mgr := get_tree().get_first_node_in_group("house_progression_manager") as HouseProgressionManager if is_inside_tree() else null
		if is_instance_valid(house_mgr) and house_mgr.has_placed_furniture(active_furniture_id):
			return {"valid": false, "reason": "DUPLICATE_UNIQUE", "message": "Món nội thất đặc biệt này chỉ được đặt 1 cái trong nhà!"}
	
	# 2. Physics shape query (check overlap with walls or other furniture)
	if space_state:
		var query := PhysicsShapeQueryParameters3D.new()
		var box := BoxShape3D.new()
		# Slightly inset by 6cm to avoid false collisions with adjacent floor or touching walls
		box.size = Vector3(maxf(0.15, fp.x - 0.12), maxf(0.2, fp.y - 0.05), maxf(0.15, fp.z - 0.12))
		query.shape = box
		query.transform = Transform3D(Basis(Vector3.UP, rot_y), target_pos + Vector3(0, fp.y * 0.5 + 0.04, 0))
		query.collision_mask = 1 # Environment solids and furniture
		
		var excludes := []
		if is_instance_valid(player):
			if player is CollisionObject3D:
				excludes.append(player.get_rid())
			for c in player.get_children():
				if c is CollisionObject3D: excludes.append(c.get_rid())
		if is_instance_valid(original_node):
			for c in original_node.get_children():
				if c is CollisionObject3D: excludes.append(c.get_rid())
		query.exclude = excludes
		
		var hits := space_state.intersect_shape(query, 8)
		if hits.size() > 0:
			return {"valid": false, "reason": "OVERLAPPING_OBSTACLE", "message": "Vướng tường hoặc vật thể khác!"}
	
	return {"valid": true, "reason": "OK", "message": "Vị trí hợp lệ"}

func update_placement(
	target_pos: Vector3,
	space_state: PhysicsDirectSpaceState3D,
	room_bounds: AABB,
	player: Node3D = null,
	blocked_zones: Array[AABB] = []
) -> bool:
	if not is_active() or not is_instance_valid(preview_node): return false
	
	# Snap to 0.25m grid
	var snapped_pos := Vector3(
		snappedf(target_pos.x, 0.25),
		0.0,
		snappedf(target_pos.z, 0.25)
	)
	preview_node.global_position = snapped_pos
	preview_node.rotation.y = current_rotation
	
	var res := validate_placement(snapped_pos, current_rotation, space_state, room_bounds, player, blocked_zones)
	current_valid = res["valid"]
	last_validation_reason = res["reason"]
	
	_apply_preview_material(mat_valid if current_valid else mat_invalid)
	return current_valid

func confirm_placement(
	target_pos: Vector3,
	space_state: PhysicsDirectSpaceState3D,
	room_bounds: AABB,
	player: Node3D = null,
	blocked_zones: Array[AABB] = []
) -> Node3D:
	if not is_active(): return null
	
	var snapped_pos := Vector3(
		snappedf(target_pos.x, 0.25),
		0.0,
		snappedf(target_pos.z, 0.25)
	)
	
	var res := validate_placement(snapped_pos, current_rotation, space_state, room_bounds, player, blocked_zones)
	if not res["valid"]:
		placement_rejected.emit(res["reason"], res["message"])
		return null
	
	# Valid placement: instantiate real furniture
	var old_state := FurnitureData.capture_state(original_node) if state == State.REARRANGING else {}
	var placed := FurnitureData.create_placed_instance(active_furniture_id, snapped_pos, current_rotation, old_state)
	
	if state == State.REARRANGING and is_instance_valid(original_node):
		original_node.queue_free()
		original_node = null
		original_collision_layers.clear()
		
	var placed_id := active_furniture_id
	_cleanup_preview()
	state = State.IDLE
	active_furniture_id = ""
	
	placement_confirmed.emit(placed_id, placed)
	return placed

func cancel_placement() -> void:
	if not is_active(): return
	
	if state == State.REARRANGING and is_instance_valid(original_node):
		original_node.visible = true
		_set_node_collision_active(original_node, true, true)
		original_node = null
		original_collision_layers.clear()
	
	var cancelled_id := active_furniture_id
	_cleanup_preview()
	state = State.IDLE
	active_furniture_id = ""
	placement_cancelled.emit(cancelled_id)

func _set_node_collision_active(n: Node, active: bool, remember_original: bool = false) -> void:
	if n is CollisionObject3D:
		var body := n as CollisionObject3D
		if remember_original and not active:
			original_collision_layers[body] = body.collision_layer
		body.collision_layer = int(original_collision_layers.get(body, body.collision_layer)) if active else 0
	for child in n.get_children():
		_set_node_collision_active(child, active, remember_original)
