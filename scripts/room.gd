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

var structure_root: Node3D
var default_furniture_root: Node3D
var custom_furniture_root: Node3D

var player: CharacterBody3D
var placement_hud: CanvasLayer
var placement_banner: Label

# References to base interactables to satisfy smoke test
var current_sofa: Interactable
var current_bed: Interactable
var current_lamp: Interactable
var current_door: Interactable

func _ready() -> void:
	# 1. Initialize Managers
	progression_manager = HouseProgressionManager.new()
	progression_manager.name = "HouseProgressionManager"
	add_child(progression_manager)
	
	placement_manager = FurniturePlacementManager.new()
	placement_manager.name = "FurniturePlacementManager"
	add_child(placement_manager)
	
	storage = HouseStorage.new()
	
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
	
	# 4. Load persistent house state if available
	_load_persistent_house_data()
	
	# 5. Build geometry for current level
	rebuild_house()
	
	# 6. Discover player and economy manager
	call_deferred("_discover_scene_nodes")

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
		storage.sync_with_inventory(econ.inventory, progression_manager.placed_furniture)

func _load_persistent_house_data() -> void:
	var h_data := EconomySaveSystem.load_house_data()
	progression_manager.apply_save_data(h_data)

func rebuild_house() -> void:
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
			
	# Restore custom placed furniture
	_restore_placed_furniture()
	
	# Spawn Delivery Box & Upgrade Board
	_spawn_interactive_stations()

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
	
	# Back wall (solid continuous)
	wall(structure_root, Vector3(0, 1.35, -4.48), Vector3(18, 2.7, 0.16))
	
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
	current_door = make_interaction("door", Vector3(0, 0, -3.73), Vector3.ZERO, Vector3.ZERO)
	current_door.moving_part = hinge
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
	current_bed = make_interaction("bed", Vector3(-4.55, 0, 2.7), Vector3(-4.4, 0, 2.7), Vector3(-5.5, 0.45, 2.75))
	current_bed.display_name = "Chiếu ngủ truyền thống"
	default_furniture_root.add_child(current_bed)
	
	# 2. Minimal Cozy Sofa
	var sofa_inst := FurnitureData.create_visual_model("furn_basic_sofa")
	sofa_inst.position = Vector3(-2.35, 0, -0.40)
	default_furniture_root.add_child(sofa_inst)
	Art.solid(default_furniture_root, Vector3(-2.35, 0.25, -0.40), Vector3(1.5, 0.5, 0.8))
	current_sofa = make_interaction("sofa", Vector3(-2.35, 0, 0.25), Vector3(-2.35, 0, 0.48), Vector3(-2.35, 0.75, -0.38))
	current_sofa.display_name = "Ghế sofa nhỏ gọn"
	default_furniture_root.add_child(current_sofa)
	
	# 3. Basic Kitchen: Wooden stove counter & cooking pot
	box(default_furniture_root, Vector3(4.55, 0.45, -4.02), Vector3(1.8, 0.9, 0.75), Color("a8764a"), true)
	box(default_furniture_root, Vector3(4.2, 0.94, -4.02), Vector3(0.5, 0.08, 0.45), Color("4a4a4a"))
	cylinder(default_furniture_root, Vector3(4.2, 1.08, -4.02), 0.16, 0.2, Color("bdc3c7"))
	
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
	# Right exterior wall
	wall(structure_root, Vector3(8.98, 1.35, 0), Vector3(0.16, 2.7, 9))
	
	# 1. Tiled Kitchen Area on right
	box(default_furniture_root, Vector3(5.15, 0.014, -0.8), Vector3(3.65, 0.025, 7.1), Color("e9d8d0"))
	for x in range(7, 15):
		box(default_furniture_root, Vector3(x * 0.5 - 0.1, 0.03, -0.8), Vector3(0.014, 0.012, 7.1), Color("cbbab5"))
	for z in range(-8, 6):
		box(default_furniture_root, Vector3(5.15, 0.03, z * 0.5), Vector3(3.65, 0.012, 0.014), Color("cbbab5"))
		
	# Kitchen counter, sink and faucet
	box(default_furniture_root, Vector3(4.55, 0.45, -4.02), Vector3(1.9, 0.9, 0.75), GREEN, true)
	box(default_furniture_root, Vector3(4.55, 0.93, -4.02), Vector3(2.0, 0.1, 0.84), WHITE)
	box(default_furniture_root, Vector3(4.65, 0.99, -3.98), Vector3(0.65, 0.025, 0.48), Color("85848a"))
	box(default_furniture_root, Vector3(4.65, 1.01, -3.98), Vector3(0.49, 0.018, 0.33), Color("656b6c"))
	box(default_furniture_root, Vector3(4.65, 1.15, -4.25), Vector3(0.055, 0.33, 0.055), Color("8a9091"))
	box(default_furniture_root, Vector3(4.65, 1.31, -4.16), Vector3(0.055, 0.055, 0.20), Color("8a9091"))
	for x in [3.95, 4.35, 5.0, 5.35]:
		box(default_furniture_root, Vector3(x, 0.46, -3.63), Vector3(0.025, 0.66, 0.03), Color("c0c28b"))
		
	# Refrigerator
	var fridge_root := Node3D.new()
	fridge_root.position = Vector3(6.20, 0, -4.00)
	fridge_root.rotation.y = PI
	default_furniture_root.add_child(fridge_root)
	Art.kenney(fridge_root, "kitchenFridge", Vector3.ZERO, 1.84)
	Art.solid(default_furniture_root, Vector3(6.20, 0.92, -4.00), Vector3(0.85, 1.84, 0.8))
	plant(default_furniture_root, Vector3(6.2, 1.85, -4.0))
	
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
	
	# 3. Wardrobe & Cabinet
	box(default_furniture_root, Vector3(-7.75, 0.93, -4.0), Vector3(1.12, 1.86, 0.76), Color("c89464"), true)
	for x in [-8.02, -7.48]:
		box(default_furniture_root, Vector3(x, 1.0, -3.59), Vector3(0.48, 1.53, 0.04), Color("dfb888"))
		Art.ball(default_furniture_root, Vector3(x + 0.15, 1.0, -3.54), 0.035, Color("80624c"))
		
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
	current_sofa = make_interaction("sofa", Vector3(-2.35, 0, 0.25), Vector3(-2.35, 0, 0.48), Vector3(-2.35, 0.75, -0.38))
	default_furniture_root.add_child(current_sofa)
	
	# Coffee table
	Art.kenney(default_furniture_root, "tableCoffee", Vector3(-2.35, 0, -1.75), 0.56)
	Art.solid(default_furniture_root, Vector3(-2.35, 0.32, -1.75), Vector3(1.25, 0.64, 0.58))
	
	# TV Console
	Art.kenney(default_furniture_root, "cabinetTelevision", Vector3(-2.55, 0, -4.03), 0.65)
	Art.solid(default_furniture_root, Vector3(-2.55, 0.34, -4.03), Vector3(1.8, 0.65, 0.65))
	Art.kenney(default_furniture_root, "televisionModern", Vector3(-2.55, 0.65, -4.04), 0.75)
	
	# 5. Wooden Bed (Double)
	var bed_root := Node3D.new()
	bed_root.position = Vector3(-5.5, 0, 2.75)
	bed_root.rotation.y = PI
	bed_root.scale = Vector3(0.76, 1.0, 0.92)
	default_furniture_root.add_child(bed_root)
	Art.kenney(bed_root, "bedDouble", Vector3.ZERO, 0.8)
	Art.solid(default_furniture_root, Vector3(-5.5, 0.27, 2.75), Vector3(1.55, 0.54, 2.2))
	Art.kenney(default_furniture_root, "cabinetBedDrawer", Vector3(-7.02, 0, 1.95), 0.70)
	Art.solid(default_furniture_root, Vector3(-7.02, 0.35, 1.95), Vector3(0.72, 0.70, 0.72))
	current_bed = make_interaction("bed", Vector3(-4.55, 0, 2.7), Vector3(-4.4, 0, 2.7), Vector3(-5.5, 0.82, 2.7))
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
	var fb2 := FurnitureData.create_visual_model("furn_potted_plant")
	fb2.position = Vector3(13.8, 0, -6.0)
	default_furniture_root.add_child(fb2)
	# Decorative garden rail
	box(default_furniture_root, Vector3(11.9, 0.4, -8.2), Vector3(6.5, 0.8, 0.08), Color("8c5432"), true)

func _restore_placed_furniture() -> void:
	for child in custom_furniture_root.get_children():
		child.queue_free()
		
	for item in progression_manager.placed_furniture:
		if not item is Dictionary: continue
		var fid: String = item.get("id", "")
		var pos_arr: Array = item.get("pos", [0, 0, 0])
		var rot_y: float = float(item.get("rot_y", 0.0))
		var vpos := Vector3(pos_arr[0], pos_arr[1], pos_arr[2])
		
		var node := FurnitureData.create_placed_instance(fid, vpos, rot_y)
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
	structure_root.add_child(upgrade_board)

# -----------------------------------------------------------------
# Interactive Placement & Rearrangement Loop
# -----------------------------------------------------------------
func start_placement(furniture_id: String, _initiator: Node3D = null) -> void:
	placement_manager.start_placement(furniture_id)

func _on_placement_started(furniture_id: String) -> void:
	placement_hud.visible = true
	var def := FurnitureData.get_definition(furniture_id)
	placement_banner.text = "ĐANG ĐẶT: %s  ·  [WASD] Di chuyển  ·  [R] Xoay 90°  ·  [E] Xác nhận  ·  [F] Hủy" % def["name"]

func _on_placement_confirmed(furniture_id: String, placed_node: Node3D) -> void:
	placement_hud.visible = false
	custom_furniture_root.add_child(placed_node)
	progression_manager.register_placed_furniture(furniture_id, placed_node.global_position, placed_node.rotation.y)
	_save_state()

func _on_placement_cancelled(furniture_id: String) -> void:
	placement_hud.visible = false
	# Return to storage
	storage.add_item(furniture_id)

func _on_placement_rejected(reason: String, message: String) -> void:
	placement_banner.text = "⚠️ %s  ·  [WASD] Di chuyển tìm vị trí trống" % message

func _process(_delta: float) -> void:
	if placement_manager.is_active() and is_instance_valid(player):
		var target_pos: Vector3 = player.global_position + player.facing * 1.5
		var space_state := get_world_3d().direct_space_state
		var bounds := progression_manager.get_room_bounds()
		placement_manager.update_placement(target_pos, space_state, bounds, player)
		
		# Update banner text status
		if placement_manager.current_valid:
			placement_banner.modulate = Color("a7ffeb") # Soft emerald
		else:
			placement_banner.modulate = Color("ff8a80") # Soft coral red

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo): return
	
	if placement_manager.is_active():
		if event.keycode == KEY_R:
			placement_manager.rotate_preview()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("p1_interact"):
			# Confirm placement
			var target_pos: Vector3 = player.global_position + player.facing * 1.5
			var space_state := get_world_3d().direct_space_state
			var bounds := progression_manager.get_room_bounds()
			var placed := placement_manager.confirm_placement(target_pos, space_state, bounds, player)
			if placed:
				get_viewport().set_input_as_handled()
		elif event.is_action_pressed("p1_throw") or event.keycode == KEY_ESCAPE:
			placement_manager.cancel_placement()
			get_viewport().set_input_as_handled()
	else:
		# Check for picking up nearby custom furniture with 'F' (p1_throw)
		if event.is_action_pressed("p1_throw") and is_instance_valid(player):
			var nearest_node: Node3D = _find_nearest_placed_furniture(player.global_position, 1.8)
			if nearest_node:
				progression_manager.unregister_placed_furniture(
					nearest_node.get_meta("furniture_id", ""),
					nearest_node.global_position
				)
				placement_manager.start_rearrange(nearest_node)
				get_viewport().set_input_as_handled()

func _find_nearest_placed_furniture(pos: Vector3, max_dist: float) -> Node3D:
	var nearest: Node3D = null
	var min_d := max_dist
	for child in custom_furniture_root.get_children():
		if child is Node3D and child.has_meta("furniture_id"):
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
	return progression_manager.get_save_data()

func apply_save_data(data: Dictionary) -> void:
	progression_manager.apply_save_data(data)
	rebuild_house()

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
	return item
