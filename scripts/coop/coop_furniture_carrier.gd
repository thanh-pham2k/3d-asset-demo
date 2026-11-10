class_name CoopFurnitureCarrier
extends Interactable

## Implements 2-player cooperative heavy furniture carrying.
## Heavy items require both Player 1 and Player 2 to lift together for normal movement.
## When carried together, the furniture coordinates between both players.

signal duo_lift_started()
signal duo_lift_dropped(placement_pos: Vector3)

@export var heavy_furniture_id: String = "furn_deluxe_sofa"
@export var is_heavy: bool = true

var carrier_1: CharacterBody3D = null
var carrier_2: CharacterBody3D = null
var is_duo_carrying: bool = false

var original_y: float = 0.0

func _ready() -> void:
	furniture_id = heavy_furniture_id
	kind = "heavy_furniture"
	display_name = "Nội thất nặng"
	add_to_group("interactables")
	add_to_group("coop_carriables")
	original_y = global_position.y

func prompt(player_node: Node3D) -> String:
	if not is_duo_carrying:
		if carrier_1 == player_node or carrier_2 == player_node:
			return "Buông tay (Đang giữ 1 đầu)"
		elif carrier_1 != null or carrier_2 != null:
			var active_carrier: CharacterBody3D = carrier_1 if carrier_1 != null else carrier_2
			var active_id: int = active_carrier.player_id if "player_id" in active_carrier else 1
			return "Cùng P%d khiêng đồ nặng (Nhấn để nhấc cùng)" % active_id
		else:
			return "Khiêng vật nặng (Cần 2 người cùng khiêng)"
	else:
		return "Đặt đồ xuống (Cả hai đang cùng khiêng)"

func interact(player_node: Node3D) -> void:
	var p := player_node as CharacterBody3D
	if not is_instance_valid(p): return
	
	if is_duo_carrying:
		# Either player drops the item
		drop_furniture()
		return
	
	# If player is already holding, let go
	if carrier_1 == p:
		carrier_1 = null
		return
	elif carrier_2 == p:
		carrier_2 = null
		return
		
	# Grab side
	if carrier_1 == null:
		carrier_1 = p
	elif carrier_2 == null:
		carrier_2 = p
		
	# Check if both grabbed
	if carrier_1 != null and carrier_2 != null:
		start_duo_carry()

func start_duo_carry() -> void:
	is_duo_carrying = true
	# Lift slightly
	global_position.y = original_y + 0.35
	# Temporarily disable solid collision so players don't push into it
	_set_collision(false)
	duo_lift_started.emit()

func drop_furniture() -> void:
	is_duo_carrying = false
	global_position.y = original_y
	_set_collision(true)
	carrier_1 = null
	carrier_2 = null
	duo_lift_dropped.emit(global_position)

func _physics_process(_delta: float) -> void:
	if not is_duo_carrying:
		# If only 1 person is holding, they can pull it slowly
		if is_instance_valid(carrier_1) and carrier_2 == null:
			_single_carrier_follow(carrier_1)
		elif is_instance_valid(carrier_2) and carrier_1 == null:
			_single_carrier_follow(carrier_2)
		return
	
	if not is_instance_valid(carrier_1) or not is_instance_valid(carrier_2):
		drop_furniture()
		return
		
	# If players move too far apart (> 4.5m), drop
	var dist := carrier_1.global_position.distance_to(carrier_2.global_position)
	if dist > 4.5:
		drop_furniture()
		return
		
	# Position furniture centered between both players
	var mid_pos := (carrier_1.global_position + carrier_2.global_position) * 0.5
	global_position.x = mid_pos.x
	global_position.z = mid_pos.z
	global_position.y = original_y + 0.35

func _single_carrier_follow(carrier: CharacterBody3D) -> void:
	# Drag slowly behind single carrier
	var facing_dir: Vector3 = carrier.get("facing") if carrier.get("facing") != null else Vector3.FORWARD
	var target: Vector3 = carrier.global_position - facing_dir * 1.2
	global_position.x = move_toward(global_position.x, target.x, 0.05)
	global_position.z = move_toward(global_position.z, target.z, 0.05)

func _set_collision(active: bool) -> void:
	for child in get_children():
		if child is StaticBody3D:
			child.collision_layer = 1 if active else 0
			child.collision_mask = 1 if active else 0
