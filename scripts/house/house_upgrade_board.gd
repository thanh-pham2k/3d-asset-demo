class_name HouseUpgradeBoard
extends Interactable

## In-house architectural board where players view requirements and confirm house upgrades.

var house_progression: HouseProgressionManager
var wallet: HouseholdWallet
var room_node: Node3D

func _ready() -> void:
	kind = "upgrade_board"
	interaction_radius = 2.0
	display_name = "Bảng Nâng Cấp Nhà"
	add_to_group("interactables")
	_build_visual()

func _ensure_wallet() -> void:
	if not wallet and is_inside_tree():
		var econ: EconomyManager = get_tree().get_first_node_in_group("economy_manager") as EconomyManager
		if is_instance_valid(econ):
			wallet = econ.wallet

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

func prompt(_player: Node3D) -> String:
	return "Xem nâng cấp nhà và giá"

func interact(player: Node3D) -> void:
	if not is_inside_tree(): return
	var shop_ui := ShoppingUI.get_or_create(get_tree())
	if is_instance_valid(shop_ui):
		shop_ui.open_shop("Bảng Nâng Cấp Nhà", "house_upgrade", "house", self, player)
