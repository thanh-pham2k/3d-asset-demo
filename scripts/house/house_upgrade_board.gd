class_name HouseUpgradeBoard
extends Interactable

## In-house architectural board where players view requirements and confirm house upgrades.

var house_progression: HouseProgressionManager
var wallet: HouseholdWallet
var room_node: Node3D

var awaiting_confirmation_level: int = 0
var confirmation_timer: float = 0.0

func _ready() -> void:
	kind = "upgrade_board"
	display_name = "Bảng Nâng Cấp Nhà"
	add_to_group("interactables")
	_build_visual()

func _build_visual() -> void:
	# Wooden board on wall
	var board := MeshInstance3D.new()
	var b_geom := BoxMesh.new()
	b_geom.size = Vector3(1.1, 0.8, 0.08)
	board.mesh = b_geom
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("8c5432")
	board.material_override = mat
	board.position = Vector3(0, 1.4, 0)
	add_child(board)
	
	# Blueprint blueprint paper
	var paper := MeshInstance3D.new()
	var p_geom := BoxMesh.new()
	p_geom.size = Vector3(0.95, 0.68, 0.04)
	paper.mesh = p_geom
	var p_mat := StandardMaterial3D.new()
	p_mat.albedo_color = Color("2c5282") # Blueprint blue
	paper.material_override = p_mat
	paper.position = Vector3(0, 1.4, 0.04)
	add_child(paper)

func _process(delta: float) -> void:
	if awaiting_confirmation_level > 0:
		confirmation_timer -= delta
		if confirmation_timer <= 0.0:
			awaiting_confirmation_level = 0

func prompt(_player: Node3D) -> String:
	if not house_progression: return "Bảng Nâng Cấp Nhà"
	
	var check := house_progression.can_upgrade(wallet)
	if not check["can_upgrade"]:
		if check["reason"] == "MAX_LEVEL":
			return "Nhà đã đạt Cấp 3 tối đa (Biệt thự sân vườn)"
		return check["message"]
	
	var next_lvl: int = check["next_level"]
	var cost: int = check["cost"]
	var title: String = check["title"]
	
	if awaiting_confirmation_level == next_lvl:
		return "⚠️ Nhấn E lần nữa để XÁC NHẬN nâng cấp lên %s (%s)" % [title, HouseholdWallet.format_money(cost)]
	
	return "Nâng cấp lên %s (Phí: %s)" % [title, HouseholdWallet.format_money(cost)]

func interact(_player: Node3D) -> void:
	if not house_progression: return
	
	var check := house_progression.can_upgrade(wallet)
	if not check["can_upgrade"]:
		return
	
	var next_lvl: int = check["next_level"]
	if awaiting_confirmation_level == next_lvl:
		# Player confirmed! Execute upgrade!
		awaiting_confirmation_level = 0
		var res := house_progression.upgrade_house(wallet)
		if res["success"]:
			if room_node and room_node.has_method("rebuild_house"):
				room_node.call("rebuild_house")
	else:
		# First click: request confirmation
		awaiting_confirmation_level = next_lvl
		confirmation_timer = 6.0
