class_name CoupleMessInteractable
extends Interactable

## Small household mess near home that Boy and Girl clean up together.
## Works in both single-player (first character starts, partner finishes, or
## instant duo clean if both are within 4.5m) and 2-player local co-op.

signal mess_cleaned(by_couple: bool)

var first_cleaner: String = ""
var is_cleaned: bool = false

var mess_visual: Node3D
var status_label: Label3D

func _ready() -> void:
	kind = "couple_mess"
	display_name = "Đống bừa bộn trước sân"
	interaction_radius = 2.6
	add_to_group("interactables")
	_build_visual()
	_refresh_visual()

func _build_visual() -> void:
	mess_visual = Node3D.new()
	add_child(mess_visual)

	var colors := [Color("bcaaa4"), Color("ffab91"), Color("90caf9"), Color("ffe082")]
	var offsets := [
		Vector3(-0.32, 0.14, -0.18),
		Vector3(0.28, 0.12, 0.15),
		Vector3(-0.08, 0.16, 0.28),
		Vector3(0.18, 0.10, -0.25),
	]
	for i in offsets.size():
		var m := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.32, 0.22, 0.28)
		m.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colors[i]
		m.material_override = mat
		m.position = offsets[i]
		m.rotation.y = float(i) * 0.65
		mess_visual.add_child(m)

	status_label = Label3D.new()
	status_label.position = Vector3(0, 1.05, 0)
	status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	status_label.font_size = 24
	status_label.outline_size = 6
	status_label.modulate = Color("ffe082")
	add_child(status_label)

func available(_player_node: Node3D) -> bool:
	return enabled and not is_cleaned

func prompt(player_node: Node3D) -> String:
	if is_cleaned:
		return "Đã dọn sạch sẽ"
	var char_id := str(player_node.get("selected_character")) if "selected_character" in player_node else "boy"
	if first_cleaner == "":
		return "Cùng dọn đống bừa bộn (E)"
	if first_cleaner == char_id:
		return "Đợi người kia phụ dọn nốt (hoặc nhấn C đổi người)"
	return "Phụ dọn nốt cùng nhau! (E)"

func interact(player_node: Node3D) -> void:
	if is_cleaned:
		return
	var char_id := str(player_node.get("selected_character")) if "selected_character" in player_node else "boy"
	var partner_nearby := _is_partner_nearby(player_node, 4.5)

	if first_cleaner == "" and not partner_nearby:
		first_cleaner = char_id
		_refresh_visual()
		var fx = get_tree().get_first_node_in_group("chaos_feedback")
		if is_instance_valid(fx) and fx.has_method("show_toast"):
			var who := "Boy" if char_id == "boy" else "Girl"
			fx.show_toast("🧹 %s đã gom một nửa — nhờ người kia phụ dọn nốt nhé!" % who)
		return

	if first_cleaner == char_id and not partner_nearby:
		var fx = get_tree().get_first_node_in_group("chaos_feedback")
		if is_instance_valid(fx) and fx.has_method("show_toast"):
			fx.show_toast("🤝 Nhấn C chuyển sang người kia để cùng dọn nốt!")
		return

	set_cleaned(true)
	var econ := get_tree().get_first_node_in_group("economy_manager") as EconomyManager
	if is_instance_valid(econ) and is_instance_valid(econ.wallet):
		econ.wallet.deposit(5000, "couple_bonus", "Dọn dẹp nhà cửa cùng nhau")
	mess_cleaned.emit(true)

func set_cleaned(cleaned: bool) -> void:
	is_cleaned = cleaned
	if cleaned:
		first_cleaner = ""
	_refresh_visual()

func _refresh_visual() -> void:
	if is_instance_valid(mess_visual):
		mess_visual.visible = not is_cleaned
	if is_instance_valid(status_label):
		if is_cleaned:
			status_label.text = ""
			status_label.visible = false
		else:
			status_label.visible = true
			if first_cleaner == "":
				status_label.text = "🧹 Đống bừa bộn (50% mỗi người)"
			else:
				var next_who := "Girl" if first_cleaner == "boy" else "Boy"
				status_label.text = "🧹 Còn 50%% — cần %s phụ!" % next_who

func _is_partner_nearby(player_node: Node3D, max_dist: float) -> bool:
	if not is_inside_tree():
		return false
	for p in get_tree().get_nodes_in_group("players"):
		if p != player_node and is_instance_valid(p) and p is Node3D:
			if (p as Node3D).global_position.distance_to(global_position) <= max_dist:
				return true
	return false
