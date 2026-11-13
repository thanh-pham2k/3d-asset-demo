class_name Room
extends Node3D

## Core house scene for Couple Chaos.
## Supports 3-level progression (Level 1: Minimal/Sleeping Mat, Level 2: Full Cozy Home,
## Level 3: Renovated Villa + Sunroom Wing + Courtyard Garden),
## interactive furniture placement & rearrangement, and save/load persistence.

const CREAM = Color("efd0bf")
const WOOD = Color("c98256")
const DARK = Color("9b6040")
const WHITE = Color("fff0df")
const GREEN = Color("879447")
const PINK = Color("e69da9")
const RED_TILE = Color("b4533c")

var progression_manager: HouseProgressionManager
var placement_manager: FurniturePlacementManager
var storage: HouseStorage
var delivery_box: HouseDeliveryBox
var upgrade_board: HouseUpgradeBoard
var pet_manager: PetManager
var garden_manager: GardenManager

var structure_root: Node3D
var default_furniture_root: Node3D
var custom_furniture_root: Node3D

var player: CharacterBody3D
var placement_hud: CanvasLayer
var placement_banner: Label
var was_rearranging_node: Node3D = null
var rebuild_pending := false
var pending_preserve_furniture_state := true

# References to base interactables to satisfy smoke test
var current_sofa: Interactable
var current_bed: Interactable
var current_lamp: Interactable
var current_door: Interactable

func _ready() -> void:
	add_to_group("room")
	add_to_group("house_manager")

	# 1. Initialize Managers
	progression_manager = HouseProgressionManager.new()
	progression_manager.name = "HouseProgressionManager"
	add_child(progression_manager)
	
	placement_manager = FurniturePlacementManager.new()
	placement_manager.name = "FurniturePlacementManager"
	add_child(placement_manager)
	
	storage = HouseStorage.new()
	
	# Pet Manager MVP
	pet_manager = PetManager.new()
	pet_manager.name = "PetManager"
	add_child(pet_manager)

	# Garden Manager MVP (Farming System)
	garden_manager = GardenManager.new()
	garden_manager.name = "GardenManager"
	add_child(garden_manager)

	# Container nodes
	structure_root = Node3D.new()
	structure_root.name = "StructureRoot"
	add_child(structure_root)
	
	default_furniture_root = Node3D.new()
	default_furniture_root.name = "DefaultFurnitureRoot"
	add_child(default_furniture_root)
	
	custom_furniture_root = Node3D.new()
	custom_furniture_root.name = "CustomFurnitureRoot"
	add_child(custom_furniture_root)
	
	# 2. Setup HUD for placement
	_setup_placement_hud()
	
	# 3. Connect signals
	placement_manager.placement_started.connect(_on_placement_started)
	placement_manager.placement_confirmed.connect(_on_placement_confirmed)
	placement_manager.placement_cancelled.connect(_on_placement_cancelled)
	placement_manager.placement_rejected.connect(_on_placement_rejected)
	
	# Build a default room until the economy manager selects the save path.
	rebuild_house()
	
	# Restore after the managers and plots exist, regardless of scene ready order.
	call_deferred("_restore_life_simulation_data")

	# 6. Discover player and economy manager
	call_deferred("_discover_scene_nodes")

func _restore_life_simulation_data() -> void:
	var econ := get_tree().get_first_node_in_group("economy_manager") as EconomyManager
	var path := econ.save_file_path if is_instance_valid(econ) else ""
	progression_manager.apply_save_data(EconomySaveSystem.load_house_data(path))
	rebuild_house(false)
	pet_manager.apply_save_data(EconomySaveSystem.load_pet_data(path))
	garden_manager.apply_save_data(EconomySaveSystem.load_farm_data(path))

func _setup_placement_hud() -> void:
	placement_hud = CanvasLayer.new()
	placement_hud.name = "PlacementHUD"
	placement_hud.visible = false
	add_child(placement_hud)
	
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 1.0
	panel.offset_left = -280
	panel.offset_right = 280
	panel.offset_bottom = -30
	panel.offset_top = -80
	placement_hud.add_child(panel)
	
	placement_banner = Label.new()
	placement_banner.text = "[WASD] Di chuyển  ·  [R] Xoay 90°  ·  [E] Đặt xuống  ·  [F] Hủy"
	placement_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placement_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(placement_banner)

func _discover_scene_nodes() -> void:
	player = get_tree().get_first_node_in_group("players") as CharacterBody3D
	var econ: EconomyManager = get_tree().get_first_node_in_group("economy_manager") as EconomyManager
	if is_instance_valid(econ):
		econ.house_manager = self
		if is_instance_valid(upgrade_board):
			upgrade_board.wallet = econ.wallet
		progression_manager.sync_with_economy(econ)
		sync_furniture_storage(econ.inventory)
		if not econ.inventory.furniture_unlocked.is_connected(_on_furniture_unlocked_sync):
			econ.inventory.furniture_unlocked.connect(_on_furniture_unlocked_sync)
		if not econ.inventory.upgrade_unlocked.is_connected(_on_upgrade_unlocked_sync):
			econ.inventory.upgrade_unlocked.connect(_on_upgrade_unlocked_sync)
		rebuild_house()

func _on_upgrade_unlocked_sync(upgrade_id: String) -> void:
	if not upgrade_id.begins_with("upg_house_"):
		return
	var econ: EconomyManager = get_tree().get_first_node_in_group("economy_manager") as EconomyManager
	if is_instance_valid(econ):
		progression_manager.sync_with_economy(econ)
		rebuild_house()

func _on_furniture_unlocked_sync(_id: String) -> void:
	var econ: EconomyManager = get_tree().get_first_node_in_group("economy_manager") as EconomyManager
	if is_instance_valid(econ):
		sync_furniture_storage(econ.inventory)

func sync_furniture_storage(inventory: InventoryManager) -> void:
	storage.sync_with_inventory(inventory, progression_manager.placed_furniture)
	# A new placement has already taken one item from storage. Rearranging an
	# existing item needs no reservation because it remains in placed_furniture.
	if is_instance_valid(placement_manager) and placement_manager.state == FurniturePlacementManager.State.PLACING:
		storage.remove_item(placement_manager.active_furniture_id)

func rebuild_house(preserve_furniture_state: bool = true) -> void:
	# Resting players retain a reference to their furniture interaction node.
	# Keep it alive until everyone has stood up before replacing the geometry.
	if _has_occupied_furniture():
		rebuild_pending = true
		pending_preserve_furniture_state = pending_preserve_furniture_state and preserve_furniture_state
		return
	rebuild_pending = false
	pending_preserve_furniture_state = true
	# A rebuild replaces placed nodes; finish any reservation before doing so.
	if is_instance_valid(placement_manager) and placement_manager.is_active():
		placement_manager.cancel_placement()
	if preserve_furniture_state and is_instance_valid(custom_furniture_root):
		get_save_data()
	# Clear previous level dynamic nodes
	for child in structure_root.get_children():
		child.queue_free()
	for child in default_furniture_root.get_children():
		child.queue_free()
		
	# Build Base Architecture (Perimeter walls, door, fixed lighting)
	_build_base_architecture()
	
	# Build Level-specific geometry and furnishings
	match progression_manager.house_level:
		1:
			_build_level_1()
		2:
			_build_level_2()
		3:
			_build_level_3()
			
	# Build Standalone Functional & Visual House Upgrades
	if progression_manager.has_tile_yard:
		_build_tile_yard()
	if progression_manager.has_flower_garden:
		_build_flower_garden()
	if progression_manager.has_modern_kitchen:
		_build_modern_kitchen()

	# Restore custom placed furniture
	_restore_placed_furniture()
	
	# Spawn Delivery Box & Upgrade Board
	_spawn_interactive_stations()

	# Ensure Pet is present if adopted (Requirement 1, 3, 7)
	if is_instance_valid(pet_manager) and pet_manager.is_adopted:
		pet_manager.ensure_pet_spawned(self)

	# Setup Garden Plots (Requirement 2 & 4)
	if is_instance_valid(garden_manager):
		garden_manager.setup_garden_plots(self)

func _has_occupied_furniture() -> bool:
	if not is_inside_tree(): return false
	for actor in get_tree().get_nodes_in_group("players"):
		var item = actor.get("resting")
		if is_instance_valid(item) and (default_furniture_root.is_ancestor_of(item) or custom_furniture_root.is_ancestor_of(item)):
			return true
	return false

func _build_base_architecture() -> void:
	# Main Wood Floor (18m x 9m)
	box(structure_root, Vector3(0, -0.12, 0), Vector3(18, 0.24, 9), WOOD, true)
	
	# Decorative floor plank lines
	for z in range(-8, 9):
		box(structure_root, Vector3(0, 0.006, z * 0.5), Vector3(18, 0.01, 0.015), Color("b9754d"))
	for row in range(-8, 9):
		for col in range(-4, 5):
			box(structure_root, Vector3(col * 2.0 + (1.0 if row % 2 else 0.0), 0.008, row * 0.5 + 0.25), Vector3(0.012, 0.012, 0.5), Color("bb7850"))
			
	# Left wall: at x = -8.98 (MUST match smoke test wall check at (-8.2, 0, 2.8) moving left)
	wall(structure_root, Vector3(-8.98, 1.35, 0), Vector3(0.16, 2.7, 9))
	
	# Back wall with a walkable doorway.
	wall(structure_root, Vector3(-4.8, 1.35, -4.48), Vector3(8.4, 2.7, 0.16))
	wall(structure_root, Vector3(4.8, 1.35, -4.48), Vector3(8.4, 2.7, 0.16))
	wall(structure_root, Vector3(0, 2.4, -4.48), Vector3(1.2, 0.6, 0.16))
	
	# Front open cutaway invisible collision barrier
	Art.solid(structure_root, Vector3(0, 1, 4.48), Vector3(18, 2, 0.16))
	box(structure_root, Vector3(0, 0.14, -4.36), Vector3(18, 0.28, 0.1), DARK)
	
	# Rear wall: window and work desk (bottle rests on this desk in game_manager)
	box(structure_root, Vector3(-5.25, 1.75, -4.37), Vector3(1.55, 1.05, 0.05), WHITE)
	box(structure_root, Vector3(-5.25, 1.75, -4.33), Vector3(1.38, 0.90, 0.04), Color("8dc5d7"))
	box(structure_root, Vector3(-5.25, 1.75, -4.29), Vector3(0.06, 0.95, 0.05), WHITE)
	box(structure_root, Vector3(-5.25, 1.75, -4.28), Vector3(1.4, 0.06, 0.05), WHITE)
	box(structure_root, Vector3(-5.25, 2.37, -4.25), Vector3(1.95, 0.07, 0.08), DARK)
	for x in [-6.07, -5.98, -5.89, -4.61, -4.52, -4.43]:
		box(structure_root, Vector3(x, 1.86, -4.23), Vector3(0.11, 1.08, 0.09), Color("e8b9b0"))
	for x in [-5.99, -4.51]:
		box(structure_root, Vector3(x, 1.55, -4.16), Vector3(0.31, 0.07, 0.08), Color("f8dfc0"))
	var desk_root := Node3D.new()
	desk_root.position = Vector3(-5.2, 0, -3.9)
	desk_root.scale = Vector3(1.25, 1, 1)
	structure_root.add_child(desk_root)
	Art.kenney(desk_root, "desk", Vector3.ZERO, 0.78)
	Art.solid(structure_root, Vector3(-5.2, 0.72, -3.9), Vector3(1.75, 0.12, 0.85))
	Art.kenney(structure_root, "laptop", Vector3(-5.2, 0.79, -3.87), 0.39)
	Art.kenney(structure_root, "books", Vector3(-5.85, 0.79, -3.85), 0.16)
	var book_interact := make_interaction("bookshelf", Vector3(-5.85, 0.79, -3.3), Vector3(-5.85, 0, -3.3), Vector3.ZERO)
	structure_root.add_child(book_interact)
	Art.kenney(structure_root, "chairDesk", Vector3(-5.2, 0, -2.95), 0.75)
	
	# Door with hinge
	var hinge := Node3D.new()
	hinge.name = "DoorHinge"
	hinge.position = Vector3(-0.55, 0, -4.35)
	structure_root.add_child(hinge)
	Art.box(hinge, Vector3(0.5, 1.05, 0), Vector3(1.0, 2.1, 0.12), Color("995332"))
	Art.ball(hinge, Vector3(0.83, 1.0, 0.10), 0.08, Color("e8b354"))
	for y in [0.62, 1.52]:
		Art.box(hinge, Vector3(0.47, y, 0.075), Vector3(0.62, 0.62, 0.035), Color("ad6742"))
		Art.box(hinge, Vector3(0.47, y, 0.10), Vector3(0.50, 0.50, 0.02), Color("995332"))
	current_door = make_interaction("door", Vector3(0, 0, -4.4), Vector3.ZERO, Vector3.ZERO)
	current_door.moving_part = hinge
	var door_hint := Label3D.new()
	door_hint.name = "DoorHint"
	door_hint.text = "E — Mở cửa"
	door_hint.position = Vector3(0, 1.85, 0.8)
	door_hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	door_hint.font_size = 48
	door_hint.pixel_size = 0.007
	door_hint.outline_size = 8
	current_door.add_child(door_hint)
	var door_body := Art.solid(structure_root, Vector3(0, 1.05, -4.48), Vector3(1.1, 2.1, 0.16))
	current_door.set_meta("door_body", door_body)
	structure_root.add_child(current_door)
	
	# Lamp on rear wall
	box(structure_root, Vector3(-4.4, 1.02, -4.0), Vector3(0.08, 0.5, 0.08), DARK)
	Art.ball(structure_root, Vector3(-4.4, 1.3, -4.0), 0.18, Color("f8d28b"))
	current_lamp = make_interaction("lamp", Vector3(-4.35, 0, -3.5), Vector3.ZERO, Vector3.ZERO)
	current_lamp.toggle = true
	current_lamp.light = OmniLight3D.new()
	current_lamp.light.position = Vector3(0, 1.4, 0)
	current_lamp.light.light_color = Color("ffd49a")
	current_lamp.light.light_energy = 0.6
	current_lamp.light.omni_range = 3.5
	current_lamp.add_child(current_lamp.light)
	structure_root.add_child(current_lamp)
	_add_home_detail(structure_root, "wall_clock", Vector3(7.6, 1.9, -4.3))

func _add_home_detail(parent: Node3D, detail: String, at: Vector3) -> void:
	var visual := preload("res://scenes/house/home_detail_visual.tscn").instantiate() as Node3D
	visual.set("detail", detail)
	visual.position = at
	parent.add_child(visual)

# -----------------------------------------------------------------
# Level 1: Modest Starter Home (Sleeping Mat, Minimal Furniture, Basic Kitchen)
# -----------------------------------------------------------------
func _build_level_1() -> void:
	# Right boundary wall
	wall(structure_root, Vector3(8.98, 1.35, 0), Vector3(0.16, 2.7, 9))
	
	# 1. Sleeping Mat (Chiếu ngủ truyền thống)
	# Functions as 'bed' Interactable so smoke test bed interaction passes
	var mat_inst := FurnitureData.create_visual_model("furn_sleeping_mat")
	mat_inst.position = Vector3(-5.5, 0, 2.75)
	default_furniture_root.add_child(mat_inst)
	current_bed = make_interaction("bed", Vector3(-4.55, 0, 2.7), Vector3(-4.4, 0, 2.7), Vector3(-5.5, 0.12, 2.75))
	current_bed.display_name = "Chiếu ngủ truyền thống"
	default_furniture_root.add_child(current_bed)
	
	# 2. Minimal Cozy Sofa
	var sofa_inst := FurnitureData.create_visual_model("furn_basic_sofa")
	sofa_inst.position = Vector3(-2.35, 0, -0.40)
	default_furniture_root.add_child(sofa_inst)
	Art.solid(default_furniture_root, Vector3(-2.35, 0.25, -0.40), Vector3(1.5, 0.5, 0.8))
	current_sofa = make_interaction("sofa", Vector3(-2.35, 0, 0.25), Vector3(-2.35, 0, 0.48), Vector3(-2.35, 0.42, -0.38))
	current_sofa.display_name = "Ghế sofa nhỏ gọn"
	default_furniture_root.add_child(current_sofa)
	
	# 3. Basic Kitchen: Wooden stove counter & cooking pot (unless modern kitchen upgrade is owned)
	if not progression_manager.has_modern_kitchen:
		box(default_furniture_root, Vector3(4.55, 0.45, -4.02), Vector3(1.8, 0.9, 0.75), Color("a8764a"), true)
		box(default_furniture_root, Vector3(4.2, 0.94, -4.02), Vector3(0.5, 0.08, 0.45), Color("4a4a4a"))
		cylinder(default_furniture_root, Vector3(4.2, 1.08, -4.02), 0.16, 0.2, Color("bdc3c7"))
		_add_home_detail(default_furniture_root, "rice_cooker", Vector3(5.02, 0.99, -4.03))
		var k_interact := make_interaction("kitchen_counter", Vector3(4.55, 0.45, -3.3), Vector3(4.55, 0, -3.3), Vector3.ZERO)
		default_furniture_root.add_child(k_interact)
	
	# Modest table and chairs
	var table_root := Node3D.new()
	table_root.position = Vector3(5.0, 0, 0.25)
	table_root.scale = Vector3(0.94, 1, 0.82)
	default_furniture_root.add_child(table_root)
	Art.kenney(table_root, "tableRound", Vector3.ZERO, 0.80)
	Art.solid(default_furniture_root, Vector3(5, 0.35, 0.25), Vector3(0.16, 0.7, 0.16))
	
	for x in [4.0, 6.0]:
		var chair_root := Node3D.new()
		chair_root.position = Vector3(x, 0, 0.25)
		chair_root.rotation.y = PI / 2.0 if x < 5.0 else -PI / 2.0
		default_furniture_root.add_child(chair_root)
		Art.kenney(chair_root, "chairCushion", Vector3.ZERO, 0.9)
		Art.solid(default_furniture_root, Vector3(x, 0.46, 0.25), Vector3(0.55, 0.14, 0.55))
		var ch := make_interaction("chair", Vector3(x, 0, 0.25), Vector3(x, 0, 0.8 if x < 5.0 else -0.3), Vector3(x, 0.45, 0.25))
		default_furniture_root.add_child(ch)

# -----------------------------------------------------------------
# Level 2: Full Cozy Home (Wooden Bed, Wardrobe, Dining Table, Fridge, Sofa)
# -----------------------------------------------------------------
func _build_level_2() -> void:
	# Level 3 replaces this wall with the sunroom archway.
	if progression_manager.house_level < 3:
		wall(structure_root, Vector3(8.98, 1.35, 0), Vector3(0.16, 2.7, 9))
	
	# 1. Tiled Kitchen Area on right
	box(default_furniture_root, Vector3(5.15, 0.014, -0.8), Vector3(3.65, 0.025, 7.1), Color("e9d8d0"))
	for x in range(7, 15):
		box(default_furniture_root, Vector3(x * 0.5 - 0.1, 0.03, -0.8), Vector3(0.014, 0.012, 7.1), Color("cbbab5"))
	for z in range(-8, 6):
		box(default_furniture_root, Vector3(5.15, 0.03, z * 0.5), Vector3(3.65, 0.012, 0.014), Color("cbbab5"))
		
	# Kitchen counter, sink and faucet (unless modern kitchen upgrade is owned)
	if not progression_manager.has_modern_kitchen:
		box(default_furniture_root, Vector3(4.55, 0.45, -4.02), Vector3(1.9, 0.9, 0.75), GREEN, true)
		box(default_furniture_root, Vector3(4.55, 0.93, -4.02), Vector3(2.0, 0.1, 0.84), WHITE)
		box(default_furniture_root, Vector3(4.65, 0.99, -3.98), Vector3(0.65, 0.025, 0.48), Color("85848a"))
		box(default_furniture_root, Vector3(4.65, 1.01, -3.98), Vector3(0.49, 0.018, 0.33), Color("656b6c"))
		box(default_furniture_root, Vector3(4.65, 1.15, -4.25), Vector3(0.055, 0.33, 0.055), Color("8a9091"))
		box(default_furniture_root, Vector3(4.65, 1.31, -4.16), Vector3(0.055, 0.055, 0.20), Color("8a9091"))
		for x in [3.95, 4.35, 5.0, 5.35]:
			box(default_furniture_root, Vector3(x, 0.46, -3.63), Vector3(0.025, 0.66, 0.03), Color("c0c28b"))
		var k_interact := make_interaction("kitchen_counter", Vector3(4.55, 0.45, -3.3), Vector3(4.55, 0, -3.3), Vector3.ZERO)
		default_furniture_root.add_child(k_interact)
		
	if not progression_manager.has_modern_kitchen:
		_add_home_detail(default_furniture_root, "kitchen_shelf", Vector3(5.1, 1.72, -4.17))
	_add_home_detail(default_furniture_root, "rice_cooker", Vector3(5.3, 1.00, -4.05))

	# Refrigerator
	var fridge_root := FurnitureData.create_visual_model("furn_inverter_fridge")
	fridge_root.position = Vector3(6.20, 0, -4.00)
	default_furniture_root.add_child(fridge_root)
	Art.solid(default_furniture_root, Vector3(6.20, 0.92, -4.00), Vector3(0.85, 1.84, 0.8))
	plant(default_furniture_root, Vector3(6.2, 1.85, -4.0))
	var fr_interact := make_interaction("fridge", Vector3(6.20, 0.9, -3.3), Vector3(6.20, 0, -3.3), Vector3.ZERO)
	fr_interact.moving_part = fridge_root.find_child("FridgeDoor", true, false) as Node3D
	default_furniture_root.add_child(fr_interact)
	
	# 2. Dining Table and cushioned chairs
	var table_root := Node3D.new()
	table_root.position = Vector3(5.0, 0, 0.25)
	table_root.scale = Vector3(0.94, 1, 0.82)
	default_furniture_root.add_child(table_root)
	Art.kenney(table_root, "tableRound", Vector3.ZERO, 0.80)
	Art.solid(default_furniture_root, Vector3(5, 0.35, 0.25), Vector3(0.16, 0.7, 0.16))
	
	for x in [4.0, 6.0]:
		var chair_root := Node3D.new()
		chair_root.position = Vector3(x, 0, 0.25)
		chair_root.rotation.y = PI / 2.0 if x < 5.0 else -PI / 2.0
		default_furniture_root.add_child(chair_root)
		Art.kenney(chair_root, "chairCushion", Vector3.ZERO, 0.9)
		Art.solid(default_furniture_root, Vector3(x, 0.46, 0.25), Vector3(0.55, 0.14, 0.55))
		var ch := make_interaction("chair", Vector3(x, 0, 0.25), Vector3(x, 0, 0.8 if x < 5.0 else -0.3), Vector3(x, 0.45, 0.25))
		default_furniture_root.add_child(ch)
	plant(default_furniture_root, Vector3(5, 0.8, 0.25))
	var pl_interact := make_interaction("plant", Vector3(5, 0.8, 0.25), Vector3(5, 0, 0.8), Vector3.ZERO)
	default_furniture_root.add_child(pl_interact)
	
	# 3. Wardrobe & Cabinet
	box(default_furniture_root, Vector3(-7.75, 0.93, -4.0), Vector3(1.12, 1.86, 0.76), Color("c89464"), true)
	var wardrobe_doors: Array[Node3D] = []
	for side in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.position = Vector3(-7.75 + side * 0.51, 1.0, -3.59)
		default_furniture_root.add_child(hinge)
		box(hinge, Vector3(-side * 0.24, 0, 0), Vector3(0.48, 1.53, 0.04), Color("dfb888"))
		Art.ball(hinge, Vector3(-side * 0.40, 0, 0.05), 0.035, Color("80624c"))
		wardrobe_doors.append(hinge)
	var w_interact := make_interaction("wardrobe", Vector3(-7.75, 0.93, -3.3), Vector3(-7.75, 0, -3.3), Vector3.ZERO)
	w_interact.moving_part = wardrobe_doors[0]
	w_interact.moving_part_2 = wardrobe_doors[1]
	default_furniture_root.add_child(w_interact)
		
	# 4. Living room Sofa and rug
	cylinder(default_furniture_root, Vector3(-2.35, 0.035, -0.6), 1.38, 0.035, Color("f1d1b1"))
	cylinder(default_furniture_root, Vector3(-2.35, 0.058, -0.6), 1.15, 0.016, Color("e9ad8e"))
	var sofa_root := Node3D.new()
	sofa_root.position = Vector3(-2.35, 0, -0.40)
	sofa_root.rotation.y = PI
	default_furniture_root.add_child(sofa_root)
	var sofa := Art.kenney(sofa_root, "loungeSofa", Vector3.ZERO, 0.95)
	for surface in range(sofa.mesh.get_surface_count()):
		var mat := sofa.mesh.surface_get_material(surface)
		if mat and "carpet" in mat.resource_name.to_lower():
			var sage := mat.duplicate() as StandardMaterial3D
			sage.albedo_color = Color("8b9e59")
			sofa.set_surface_override_material(surface, sage)
	Art.solid(default_furniture_root, Vector3(-2.35, 0.29, -0.40), Vector3(2.15, 0.58, 0.78))
	current_sofa = make_interaction("sofa", Vector3(-2.35, 0, 0.25), Vector3(-2.35, 0, 0.48), Vector3(-2.35, 0.42, -0.38))
	default_furniture_root.add_child(current_sofa)
	
	# Coffee table
	Art.kenney(default_furniture_root, "tableCoffee", Vector3(-2.35, 0, -1.75), 0.56)
	Art.solid(default_furniture_root, Vector3(-2.35, 0.32, -1.75), Vector3(1.25, 0.64, 0.58))
	
	# TV Console
	Art.kenney(default_furniture_root, "cabinetTelevision", Vector3(-2.55, 0, -4.03), 0.65)
	Art.solid(default_furniture_root, Vector3(-2.55, 0.34, -4.03), Vector3(1.8, 0.65, 0.65))
	Art.kenney(default_furniture_root, "televisionModern", Vector3(-2.55, 0.65, -4.04), 0.75)
	var tv_interact := make_interaction("tv", Vector3(-2.55, 0.65, -3.3), Vector3(-2.55, 0, -3.3), Vector3.ZERO)
	var tv_screen := Art.box(default_furniture_root, Vector3(-2.55, 1.12, -3.87), Vector3(0.92, 0.43, 0.018), Color("141416"))
	tv_screen.name = "TVScreen"
	tv_interact.screen_mesh = tv_screen
	tv_interact._update_tv_visual()
	default_furniture_root.add_child(tv_interact)
	
	# 5. Wooden Bed (Double)
	var bed_root := Node3D.new()
	bed_root.position = Vector3(-5.5, 0, 2.75)
	bed_root.rotation.y = PI
	bed_root.scale = Vector3(0.76, 1.0, 0.92)
	default_furniture_root.add_child(bed_root)
	Art.kenney(bed_root, "bedDouble", Vector3.ZERO, 0.8)
	Art.solid(default_furniture_root, Vector3(-5.5, 0.27, 2.75), Vector3(1.55, 0.54, 2.2))
	Art.kenney(default_furniture_root, "cabinetBedDrawer", Vector3(-7.02, 0, 1.95), 0.70)
	_add_home_detail(default_furniture_root, "bedside_lamp", Vector3(-7.02, 0.71, 1.95))
	Art.solid(default_furniture_root, Vector3(-7.02, 0.35, 1.95), Vector3(0.72, 0.70, 0.72))
	current_bed = make_interaction("bed", Vector3(-4.55, 0, 2.7), Vector3(-4.4, 0, 2.7), Vector3(-5.5, 0.48, 2.7))
	default_furniture_root.add_child(current_bed)

# -----------------------------------------------------------------
# Level 3: Renovated Villa + Sunroom Extension Wing + Courtyard Garden
# -----------------------------------------------------------------
func _build_level_3() -> void:
	# Build Level 2 foundation first
	_build_level_2()
	
	# Renovated molding trims
	box(default_furniture_root, Vector3(0, 2.65, -4.4), Vector3(18, 0.1, 0.15), Color("f7e6d2"))
	box(default_furniture_root, Vector3(-8.9, 2.65, 0), Vector3(0.15, 0.1, 9), Color("f7e6d2"))
	
	# Wall art paintings
	picture(default_furniture_root, Vector3(1.5, 1.85, -4.35), Vector2(0.78, 0.65), Color("9fbba9"))
	picture(default_furniture_root, Vector3(2.48, 1.85, -4.35), Vector2(0.62, 0.72), Color("e3b395"))
	
	# --- ADDITIONAL ROOM: Sunroom & Reading Lounge (x: 8.98 to 14.8) ---
	# Open archway in right wall: wall split into front and back pillars
	wall(structure_root, Vector3(8.98, 1.35, -3.2), Vector3(0.16, 2.7, 2.5))
	wall(structure_root, Vector3(8.98, 1.35, 3.2), Vector3(0.16, 2.7, 2.5))
	wall(structure_root, Vector3(8.98, 2.45, 0), Vector3(0.16, 0.5, 4.0)) # Archway lintel
	
	# Sunroom Floor
	box(structure_root, Vector3(11.9, -0.12, 0), Vector3(5.8, 0.24, 9), Color("ba7a4e"), true)
	# Parquet grid lines
	for x_sub in [9.9, 11.9, 13.9]:
		box(structure_root, Vector3(x_sub, 0.006, 0), Vector3(0.012, 0.012, 9), Color("a5683e"))
		
	# Outer perimeter walls for sunroom
	wall(structure_root, Vector3(14.8, 1.35, 0), Vector3(0.16, 2.7, 9))
	wall(structure_root, Vector3(11.9, 1.35, -4.48), Vector3(5.8, 2.7, 0.16))
	Art.solid(structure_root, Vector3(11.9, 1, 4.48), Vector3(5.8, 2, 0.16))
	
	# Panoramic picture window overlooking garden
	box(default_furniture_root, Vector3(11.9, 1.6, -4.4), Vector3(3.5, 1.4, 0.05), WHITE)
	box(default_furniture_root, Vector3(11.9, 1.6, -4.36), Vector3(3.3, 1.2, 0.04), Color("8dc5d7"))
	
	# Sunroom Furnishings: Bookshelf, Reading Chair, Potted Palm
	Art.kenney(default_furniture_root, "bookcaseOpen", Vector3(14.0, 0, -3.8), 1.66)
	Art.solid(default_furniture_root, Vector3(14.0, 0.83, -3.8), Vector3(1.16, 1.66, 0.70))
	var sun_bookshelf := make_interaction("bookshelf", Vector3(14.0, 0.83, -3.1), Vector3(14.0, 0, -3.1), Vector3.ZERO)
	default_furniture_root.add_child(sun_bookshelf)
	
	var sun_chair := make_interaction("chair", Vector3(12.0, 0, 0), Vector3(12.0, 0, 0.8), Vector3(12.0, 0.45, 0))
	sun_chair.display_name = "Ghế thư giãn đọc sách"
	default_furniture_root.add_child(sun_chair)
	Art.kenney(default_furniture_root, "chairCushion", Vector3(12.0, 0, 0), 0.95)
	Art.solid(default_furniture_root, Vector3(12.0, 0.46, 0), Vector3(0.65, 0.15, 0.65))
	
	# --- COURTYARD GARDEN: Visible Patio & Planters ---
	# Terracotta tiled patio outside the window
	box(default_furniture_root, Vector3(11.9, -0.15, -6.5), Vector3(6.5, 0.2, 3.8), RED_TILE)
	# Flower beds with blossoms
	var fb1 := FurnitureData.create_visual_model("furn_potted_plant")
	fb1.position = Vector3(10.0, 0, -6.0)
	default_furniture_root.add_child(fb1)
	var plant_fb1 := make_interaction("plant", Vector3(10.0, 0.4, -5.4), Vector3(10.0, 0, -5.4), Vector3.ZERO)
	default_furniture_root.add_child(plant_fb1)

	var fb2 := FurnitureData.create_visual_model("furn_potted_plant")
	fb2.position = Vector3(13.8, 0, -6.0)
	default_furniture_root.add_child(fb2)
	var plant_fb2 := make_interaction("plant", Vector3(13.8, 0.4, -5.4), Vector3(13.8, 0, -5.4), Vector3.ZERO)
	default_furniture_root.add_child(plant_fb2)
	# Decorative garden rail
	box(default_furniture_root, Vector3(11.9, 0.4, -8.2), Vector3(6.5, 0.8, 0.08), Color("8c5432"), true)

# -----------------------------------------------------------------
# Standalone House Upgrades: Tiled Yard, Flower Garden, Modern Kitchen
# -----------------------------------------------------------------
func _build_tile_yard() -> void:
	const PATTERN_A := Color("b4533c") # Classic terracotta red
	const PATTERN_B := Color("f5e6d3") # Warm antique cream
	const PATTERN_C := Color("5c7f67") # Vintage sage green
	const KERB_COLOR := Color("805b43") # Stone border trim

	# Main Patio Foundation Platform outside doorway (z: -4.5 to -8.5, x: -3.7 to 3.7)
	box(structure_root, Vector3(0, -0.12, -6.5), Vector3(7.4, 0.24, 4.0), Color("9e785d"), true)

	# Decorative Encaustic Tile Grid (Gạch bông họa tiết)
	for ix in range(-7, 8):
		for iz in range(-4, 5):
			var tile_pos := Vector3(ix * 0.48, 0.008, -6.5 + iz * 0.42)
			var use_color: Color
			if (abs(ix) + abs(iz)) % 3 == 0:
				use_color = PATTERN_A
			elif (ix + iz) % 2 == 0:
				use_color = PATTERN_B
			else:
				use_color = PATTERN_C
			box(structure_root, tile_pos, Vector3(0.44, 0.01, 0.38), use_color)

	# Stone Kerb Border (Gờ đá viền sân)
	box(structure_root, Vector3(0, 0.06, -8.5), Vector3(7.4, 0.14, 0.16), KERB_COLOR, true)
	box(structure_root, Vector3(-3.7, 0.06, -6.5), Vector3(0.16, 0.14, 4.0), KERB_COLOR, true)
	box(structure_root, Vector3(3.7, 0.06, -6.5), Vector3(0.16, 0.14, 4.0), KERB_COLOR, true)

	# Decorative Welcome Pedestals with stone urns flanking doorway
	for side in [-1.0, 1.0]:
		box(structure_root, Vector3(side * 1.05, 0.25, -4.9), Vector3(0.35, 0.5, 0.35), KERB_COLOR, true)
		cylinder(structure_root, Vector3(side * 1.05, 0.56, -4.9), 0.18, 0.18, Color("9b7156"))

func _build_flower_garden() -> void:
	# Lush flower garden surrounding yard with bougainvillea (hoa giấy) and portulaca (hoa mười giờ)
	const BLOSSOM_PINK := Color("e91e63")
	const BLOSSOM_MAGENTA := Color("d81b60")
	const BLOSSOM_YELLOW := Color("ffeb3b")
	const BLOSSOM_CORAL := Color("ff7043")
	const LEAF_GREEN := Color("4caf50")
	const DARK_GREEN := Color("2e7d32")
	const WOOD_BOX := Color("795548")

	# 1. Left & Right Raised Wooden Planter Beds flanking the yard
	for side in [-1.0, 1.0]:
		var x_pos: float = side * 3.3
		box(structure_root, Vector3(x_pos, 0.2, -6.5), Vector3(0.7, 0.4, 3.6), WOOD_BOX, true)
		box(structure_root, Vector3(x_pos, 0.38, -6.5), Vector3(0.62, 0.05, 3.5), Color("3e2723"))

		# Dense foliage mounds with colorful Portulaca blossoms (hoa mười giờ)
		for z_off in [-1.2, -0.4, 0.4, 1.2]:
			var shrub_pos := Vector3(x_pos, 0.48, -6.5 + z_off)
			cylinder(structure_root, shrub_pos, 0.26, 0.22, LEAF_GREEN)
			Art.ball(structure_root, shrub_pos + Vector3(-0.08, 0.12, 0.06), 0.07, BLOSSOM_YELLOW)
			Art.ball(structure_root, shrub_pos + Vector3(0.08, 0.13, -0.06), 0.07, BLOSSOM_CORAL)
			Art.ball(structure_root, shrub_pos + Vector3(0.02, 0.14, 0.08), 0.065, BLOSSOM_PINK)

	# 2. Climbing Bougainvillea (Hoa giấy) Trellis along back garden perimeter
	for side in [-1.0, 1.0]:
		var trellis_x: float = side * 2.2
		box(structure_root, Vector3(trellis_x, 1.1, -8.4), Vector3(1.8, 2.0, 0.08), Color("6d4c41"), true)
		Art.ball(structure_root, Vector3(trellis_x - 0.4, 1.5, -8.32), 0.28, BLOSSOM_PINK)
		Art.ball(structure_root, Vector3(trellis_x + 0.3, 1.7, -8.32), 0.32, BLOSSOM_MAGENTA)
		Art.ball(structure_root, Vector3(trellis_x, 1.9, -8.32), 0.26, BLOSSOM_PINK)
		Art.ball(structure_root, Vector3(trellis_x - 0.2, 1.2, -8.32), 0.22, DARK_GREEN)
		Art.ball(structure_root, Vector3(trellis_x + 0.4, 1.1, -8.32), 0.24, LEAF_GREEN)

	# 3. Garden Post Lantern with gentle illumination
	var post_pos := Vector3(2.9, 0.75, -8.2)
	cylinder(structure_root, post_pos, 0.05, 1.5, Color("424242"))
	box(structure_root, post_pos + Vector3(0, 0.78, 0), Vector3(0.24, 0.28, 0.24), Color("ffe082"))
	var garden_light := OmniLight3D.new()
	garden_light.position = post_pos + Vector3(0, 0.85, 0)
	garden_light.light_color = Color("ffecb3")
	garden_light.light_energy = 0.6
	garden_light.omni_range = 4.0
	structure_root.add_child(garden_light)

func _build_modern_kitchen() -> void:
	const GRANITE := Color("2d3134") # Deep charcoal granite stone
	const MARBLE := Color("f0ece1") # Polished light marble
	const METALLIC := Color("a0a4a8") # Brushed stainless steel
	const ACCENT_GLOW := Color("ffeedd") # Warm LED under-glow

	# Luxury Granite Base Cabinet
	box(default_furniture_root, Vector3(4.55, 0.45, -4.02), Vector3(2.3, 0.9, 0.8), Color("343a40"), true)

	# Solid Polished Granite Slab Countertop (đá hoa cương)
	box(default_furniture_root, Vector3(4.55, 0.93, -4.02), Vector3(2.4, 0.1, 0.88), GRANITE, true)

	# Ceramic Induction Cooktop with touch glass panel & glowing heating rings
	box(default_furniture_root, Vector3(3.85, 0.99, -4.02), Vector3(0.75, 0.02, 0.52), Color("1a1a1c"))
	cylinder(default_furniture_root, Vector3(3.7, 1.005, -4.02), 0.14, 0.01, Color("e65100"))
	cylinder(default_furniture_root, Vector3(4.0, 1.005, -4.02), 0.11, 0.01, Color("e65100"))

	# Deep Stainless Steel Double Undermount Sink & Gooseneck Faucet
	box(default_furniture_root, Vector3(4.9, 0.99, -3.98), Vector3(0.72, 0.025, 0.5), METALLIC)
	box(default_furniture_root, Vector3(4.9, 1.01, -3.98), Vector3(0.56, 0.02, 0.36), Color("454a4f"))
	box(default_furniture_root, Vector3(4.9, 1.20, -4.26), Vector3(0.05, 0.42, 0.05), METALLIC)
	box(default_furniture_root, Vector3(4.9, 1.39, -4.14), Vector3(0.05, 0.05, 0.26), METALLIC)

	# Wall Subway Tile Backsplash with marble sheen
	box(default_furniture_root, Vector3(4.55, 1.6, -4.38), Vector3(2.4, 1.2, 0.04), MARBLE)
	for row in range(5):
		box(default_furniture_root, Vector3(4.55, 1.1 + row * 0.22, -4.36), Vector3(2.38, 0.01, 0.02), Color("d1ccc0"))

	# Overhead Stainless Steel Extractor Hood (máy hút mùi hiện đại)
	box(default_furniture_root, Vector3(3.85, 2.1, -4.15), Vector3(0.8, 0.35, 0.55), METALLIC, true)
	box(default_furniture_root, Vector3(3.85, 2.45, -4.25), Vector3(0.28, 0.4, 0.28), METALLIC)

	# Luxury Upper Glass Cabinets
	box(default_furniture_root, Vector3(5.0, 2.15, -4.18), Vector3(1.2, 0.65, 0.38), Color("3e444a"), true)
	box(default_furniture_root, Vector3(5.0, 2.15, -3.98), Vector3(1.15, 0.58, 0.02), Color(0.7, 0.85, 0.9, 0.5))

	# Under-cabinet Warm LED Accent Light
	var kitchen_light := OmniLight3D.new()
	kitchen_light.position = Vector3(4.55, 1.7, -3.95)
	kitchen_light.light_color = ACCENT_GLOW
	kitchen_light.light_energy = 0.5
	kitchen_light.omni_range = 2.8
	default_furniture_root.add_child(kitchen_light)

	var k_interact := make_interaction("kitchen_counter", Vector3(4.55, 0.45, -3.3), Vector3(4.55, 0, -3.3), Vector3.ZERO)
	default_furniture_root.add_child(k_interact)

func _restore_placed_furniture() -> void:
	for child in custom_furniture_root.get_children():
		child.queue_free()
		
	for item in progression_manager.placed_furniture:
		if not item is Dictionary: continue
		var fid: String = item.get("id", "")
		var pos_arr: Array = item.get("pos", [0, 0, 0])
		var rot_y: float = float(item.get("rot_y", 0.0))
		var vpos := Vector3(pos_arr[0], pos_arr[1], pos_arr[2])
		var state: Dictionary = item.get("state", {})
		
		var node := FurnitureData.create_placed_instance(fid, vpos, rot_y, state)
		custom_furniture_root.add_child(node)

func _spawn_interactive_stations() -> void:
	# 1. Delivery & Storage Box
	delivery_box = HouseDeliveryBox.new()
	delivery_box.name = "HouseDeliveryBox"
	delivery_box.position = Vector3(1.2, 0, -3.8)
	delivery_box.house_storage = storage
	delivery_box.room_node = self
	structure_root.add_child(delivery_box)
	
	# 2. Upgrade Board
	upgrade_board = HouseUpgradeBoard.new()
	upgrade_board.name = "HouseUpgradeBoard"
	upgrade_board.position = Vector3(-1.8, 0, -4.4)
	upgrade_board.house_progression = progression_manager
	upgrade_board.room_node = self
	if is_inside_tree():
		var econ: EconomyManager = get_tree().get_first_node_in_group("economy_manager") as EconomyManager
		if is_instance_valid(econ):
			upgrade_board.wallet = econ.wallet
	structure_root.add_child(upgrade_board)

# -----------------------------------------------------------------
# Interactive Placement & Rearrangement Loop
# -----------------------------------------------------------------
func start_placement(furniture_id: String, _initiator: Node3D = null) -> void:
	placement_manager.start_placement(furniture_id)

func _on_placement_started(furniture_id: String) -> void:
	placement_hud.visible = true
	var def := FurnitureData.get_definition(furniture_id)
	placement_banner.text = "ĐANG ĐẶT: %s  ·  [WASD] Di chuyển  ·  [R] Xoay 90°  ·  [E] Xác nhận  ·  [F] Hủy  ·  [X] Thu hồi vào kho" % def["name"]

func _on_placement_confirmed(furniture_id: String, placed_node: Node3D) -> void:
	placement_hud.visible = false
	if is_instance_valid(was_rearranging_node):
		progression_manager.unregister_placed_furniture(
			furniture_id, to_local(was_rearranging_node.global_position))
	was_rearranging_node = null
	placed_node.position -= global_position
	custom_furniture_root.add_child(placed_node)
	progression_manager.register_placed_furniture(furniture_id, to_local(placed_node.global_position), placed_node.rotation.y)
	_save_state()

func _on_placement_cancelled(furniture_id: String) -> void:
	placement_hud.visible = false
	if is_instance_valid(was_rearranging_node):
		was_rearranging_node = null
	else:
		storage.add_item(furniture_id)

func _on_placement_rejected(reason: String, message: String) -> void:
	placement_banner.text = "⚠️ %s  ·  [WASD] Di chuyển tìm vị trí trống" % message

func _process(_delta: float) -> void:
	if rebuild_pending and not _has_occupied_furniture():
		rebuild_house(pending_preserve_furniture_state)
	if placement_manager.is_active() and is_instance_valid(player):
		var target_pos: Vector3 = player.global_position + player.facing * 1.5
		var space_state := get_world_3d().direct_space_state
		var bounds := progression_manager.get_room_bounds()
		bounds.position += global_position
		placement_manager.update_placement(target_pos, space_state, bounds, player)
		
		# Update banner text status
		if placement_manager.current_valid:
			placement_banner.modulate = Color("a7ffeb") # Soft emerald
		else:
			placement_banner.modulate = Color("ff8a80") # Soft coral red

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo): return
	if is_instance_valid(player) and (player.has_meta("daily_summary_open") or player.has_meta("map_open") or player.has_meta("pet_rename_open") or player.has_meta("shopping_open")):
		return
	
	if placement_manager.is_active():
		if is_instance_valid(player):
			player.set_meta("placement_input_block_until", Time.get_ticks_msec() + 200)
		if event.keycode == KEY_R:
			placement_manager.rotate_preview()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("p1_interact"):
			# Confirm placement
			var target_pos: Vector3 = player.global_position + player.facing * 1.5
			var space_state := get_world_3d().direct_space_state
			var bounds := progression_manager.get_room_bounds()
			bounds.position += global_position
			var placed := placement_manager.confirm_placement(target_pos, space_state, bounds, player)
			if placed:
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_X or event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			# Put directly into storage box
			if is_instance_valid(was_rearranging_node):
				var fid: String = was_rearranging_node.get_meta("furniture_id", "")
				progression_manager.unregister_placed_furniture(fid, to_local(was_rearranging_node.global_position))
				# Cancel while the original still exists so the cancellation handler
				# does not also return a second copy to storage.
				var old_node := was_rearranging_node
				placement_manager.cancel_placement()
				old_node.queue_free()
				storage.add_item(fid)
				_save_state()
				get_viewport().set_input_as_handled()
		elif event.is_action_pressed("p1_throw") or event.keycode == KEY_ESCAPE:
			placement_manager.cancel_placement()
			get_viewport().set_input_as_handled()
	else:
		# Rearrangement has a separate key; F remains the throw action.
		if event.keycode == KEY_G and is_instance_valid(player) and not player.has_meta("shopping_open") and not player.has_meta("pet_rename_open") and not player.held_pillow and not player.resting:
			var nearest_node: Node3D = _find_nearest_placed_furniture(player.global_position, 1.8)
			if nearest_node:
				was_rearranging_node = nearest_node
				placement_manager.start_rearrange(nearest_node)
				get_viewport().set_input_as_handled()

func _find_nearest_placed_furniture(pos: Vector3, max_dist: float) -> Node3D:
	var nearest: Node3D = null
	var min_d := max_dist
	for child in custom_furniture_root.get_children():
		if child is Node3D and not child.is_queued_for_deletion() and child.has_meta("furniture_id"):
			var interaction := child.get_node_or_null("Interactable") as Interactable
			if is_instance_valid(interaction) and (is_instance_valid(interaction.user) or not interaction.available(player)):
				continue
			var blocked := false
			for part in child.get_children():
				if part is PetProp and not part.available(player):
					blocked = true
					break
			if blocked: continue
			var d := pos.distance_to(child.global_position)
			if d < min_d:
				min_d = d
				nearest = child
	return nearest

func _save_state() -> void:
	var econ: EconomyManager = get_tree().get_first_node_in_group("economy_manager") as EconomyManager
	if is_instance_valid(econ):
		econ.save_economy_state()

func get_save_data() -> Dictionary:
	# Capture mutable state on the matching placed object before serialization.
	for entry in progression_manager.placed_furniture:
		var pos: Array = entry.get("pos", [0, 0, 0])
		if pos.size() < 3: continue
		var saved_pos := Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
		for child in custom_furniture_root.get_children():
			if child is Node3D and not child.is_queued_for_deletion() and child.get_meta("furniture_id", "") == entry.get("id", "") and child.position.distance_to(saved_pos) < 0.05:
				entry["state"] = FurnitureData.capture_state(child)
				break
	return progression_manager.get_save_data()

func apply_save_data(data: Dictionary) -> void:
	if is_instance_valid(placement_manager) and placement_manager.is_active():
		placement_manager.cancel_placement()
	progression_manager.apply_save_data(data)
	rebuild_house(false)
	var econ := get_tree().get_first_node_in_group("economy_manager") as EconomyManager
	if is_instance_valid(econ):
		sync_furniture_storage(econ.inventory)

# -----------------------------------------------------------------
# Helper Geometry Authoring Functions
# -----------------------------------------------------------------
func box(parent: Node, pos: Vector3, size: Vector3, color: Color, solid := false) -> void:
	Art.box(parent, pos, size, color)
	if solid: Art.solid(parent, pos, size)

func wall(parent: Node, pos: Vector3, size: Vector3) -> void:
	box(parent, pos, size, CREAM, true)

func cylinder(parent: Node, pos: Vector3, radius: float, height: float, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 32
	mesh.mesh = shape
	mesh.material_override = Art.material(color)
	mesh.position = pos
	parent.add_child(mesh)

func picture(parent: Node, pos: Vector3, dimensions: Vector2, color: Color) -> void:
	box(parent, pos, Vector3(dimensions.x, dimensions.y, 0.08), Color("aa7454"))
	box(parent, pos + Vector3(0, 0, 0.05), Vector3(dimensions.x - 0.10, dimensions.y - 0.10, 0.025), color)
	box(parent, pos + Vector3(0, -0.12, 0.07), Vector3(dimensions.x - 0.18, 0.12, 0.02), Color("e8d2ad"))

func plant(parent: Node, pos: Vector3) -> void:
	Art.kenney(parent, "plantSmall1", pos, 0.42)

func make_interaction(type: String, pos: Vector3, stand: Vector3, seat: Vector3) -> Interactable:
	var item := Interactable.new()
	item.kind = type
	item.position = pos
	item.stand_point = stand
	item.seat_point = seat
	item.is_furniture = true
	match type:
		"sofa":
			item.display_name = "Sofa"
			item.interaction_type = "rest"
		"bed":
			item.display_name = "Giường ngủ"
			item.interaction_type = "rest"
		"chair":
			item.display_name = "Ghế ngồi"
			item.interaction_type = "rest"
		"lamp":
			item.display_name = "Đèn phòng"
			item.interaction_type = "toggle"
		"door":
			item.display_name = "Cửa phòng"
			item.interaction_type = "toggle"
		"tv":
			item.display_name = "Tivi thông minh"
			item.interaction_type = "toggle"
			var tv_l := OmniLight3D.new()
			tv_l.position = Vector3(0, 0.5, 0.4)
			tv_l.light_color = Color("80d8ff")
			tv_l.light_energy = 0.7
			tv_l.visible = false
			item.light = tv_l
			item.add_child(tv_l)
		"fridge":
			item.display_name = "Tủ lạnh Inverter"
			item.interaction_type = "toggle"
			var fr_l := OmniLight3D.new()
			fr_l.position = Vector3(0, 0.5, 0.3)
			fr_l.light_color = Color("e0f7fa")
			fr_l.light_energy = 0.6
			fr_l.visible = false
			item.light = fr_l
			item.add_child(fr_l)
		"wardrobe":
			item.display_name = "Tủ quần áo gỗ"
			item.interaction_type = "toggle"
		"bookshelf":
			item.display_name = "Kệ sách gia đình"
		"kitchen_counter":
			item.display_name = "Bếp nấu ăn gia đình"
		"plant":
			item.display_name = "Chậu cây cảnh"
	return item
