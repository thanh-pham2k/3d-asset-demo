class_name HouseDeliveryBox
extends Interactable

## In-house delivery container and storage access.
## Players interact here to retrieve purchased furniture from the store and place it.

var house_storage: HouseStorage
var room_node: Node3D

func _ready() -> void:
	kind = "delivery_box"
	display_name = "Thùng Giao Hàng"
	add_to_group("interactables")
	_build_visual()

func _build_visual() -> void:
	# Cardboard package box
	var box_mesh := MeshInstance3D.new()
	var b_geom := BoxMesh.new()
	b_geom.size = Vector3(0.7, 0.55, 0.6)
	box_mesh.mesh = b_geom
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("c49a6c") # Cardboard craft brown
	box_mesh.material_override = mat
	box_mesh.position = Vector3(0, 0.275, 0)
	add_child(box_mesh)
	
	# Tape strip
	var tape := MeshInstance3D.new()
	var t_geom := BoxMesh.new()
	t_geom.size = Vector3(0.12, 0.56, 0.62)
	tape.mesh = t_geom
	var t_mat := StandardMaterial3D.new()
	t_mat.albedo_color = Color("eed99d")
	tape.material_override = t_mat
	tape.position = Vector3(0, 0.28, 0)
	add_child(tape)
	
	# Solid collision
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var c_box := BoxShape3D.new()
	c_box.size = Vector3(0.7, 0.55, 0.6)
	shape.shape = c_box
	shape.position = Vector3(0, 0.275, 0)
	body.add_child(shape)
	add_child(body)

func prompt(_player: Node3D) -> String:
	if not house_storage: return "Thùng Giao Hàng"
	var items := house_storage.get_items()
	if items.is_empty():
		return "Kho đồ trống (Hãy ghé Tiệm Nội Thất mua sắm)"
	var first_id := items[0]
	var def := FurnitureData.get_definition(first_id)
	return "Đặt %s (Còn %d món trong kho)" % [def["name"], items.size()]

func interact(player: Node3D) -> void:
	if not house_storage or not room_node: return
	var items := house_storage.get_items()
	if items.is_empty():
		return
	
	var item_id := items[0]
	house_storage.remove_item(item_id)
	if room_node.has_method("start_placement"):
		room_node.call("start_placement", item_id, player)
