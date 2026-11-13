class_name HouseDeliveryBox
extends Interactable

## In-house delivery container and storage access.
## Players interact here to retrieve purchased furniture from the store and place it.

var house_storage: HouseStorage
var room_node: Node3D
var selected_index: int = 0

func _ready() -> void:
	kind = "delivery_box"
	interaction_radius = 2.0
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
	selected_index = clampi(selected_index, 0, items.size() - 1)
	var def := FurnitureData.get_definition(items[selected_index])
	var hint := " · [R] Chọn món khác" if items.size() > 1 else ""
	return "Đặt %s (%d/%d)%s" % [def["name"], selected_index + 1, items.size(), hint]

func interact(player: Node3D) -> void:
	if not house_storage or not room_node: return
	var items := house_storage.get_items()
	if items.is_empty():
		return
	
	if not room_node.has_method("start_placement"):
		return
	selected_index = clampi(selected_index, 0, items.size() - 1)
	var item_id := items[selected_index]
	if house_storage.remove_item(item_id):
		room_node.call("start_placement", item_id, player)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R): return
	if not house_storage or not is_inside_tree(): return
	var player := get_tree().get_first_node_in_group("players") as CharacterBody3D
	if not is_instance_valid(player) or player.get("target") != self or player.has_meta("shopping_open") or player.has_meta("pet_rename_open") or player.has_meta("daily_summary_open") or player.has_meta("map_open"):
		return
	var manager := get_tree().get_first_node_in_group("furniture_placement_manager") as FurniturePlacementManager
	if is_instance_valid(manager) and manager.is_active(): return
	var items := house_storage.get_items()
	if items.size() < 2: return
	selected_index = (selected_index + 1) % items.size()
	get_viewport().set_input_as_handled()
