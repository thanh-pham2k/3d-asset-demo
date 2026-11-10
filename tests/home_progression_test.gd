extends SceneTree

## Automated test suite for Home Progression, Upgrade Progression,
## Furniture Placement, Collision Validation, and Persistence.

const FurnitureData = preload("res://scripts/house/furniture_data.gd")
const FurniturePlacementManager = preload("res://scripts/house/furniture_placement_manager.gd")
const HouseProgressionManager = preload("res://scripts/house/house_progression_manager.gd")
const HouseStorage = preload("res://scripts/house/house_storage.gd")
const HouseholdWallet = preload("res://scripts/economy/household_wallet.gd")
const InventoryManager = preload("res://scripts/economy/inventory_manager.gd")
const EconomyManager = preload("res://scripts/economy/economy_manager.gd")
const EconomySaveSystem = preload("res://scripts/economy/economy_save_system.gd")

var failures := 0

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: ", label)
	else:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	print("--- Running Home Progression & Furniture Placement Tests ---")
	
	var temp_save_path := "user://test_home_progression_save.json"
	if FileAccess.file_exists(temp_save_path):
		DirAccess.remove_absolute(temp_save_path)
	
	# -------------------------------------------------------------
	# Test 1: House Progression Levels & Initial State (Level 1)
	# -------------------------------------------------------------
	var prog := HouseProgressionManager.new()
	check(prog.house_level == 1, "House starts at Level 1")
	check("main_room" in prog.unlocked_areas, "Level 1 has main_room unlocked")
	check(prog.get_room_bounds().size.x < 15.0, "Level 1 has compact starter bounds")
	
	# -------------------------------------------------------------
	# Test 2: Upgrade Requirements & Confirmation (Level 1 -> 2 -> 3)
	# -------------------------------------------------------------
	var wallet := HouseholdWallet.new()
	wallet.balance = 50000 # Not enough for Level 2 (75,000đ)
	
	var can_upg1 := prog.can_upgrade(wallet)
	check(not can_upg1["can_upgrade"] and can_upg1["reason"] == "INSUFFICIENT_FUNDS", "Blocked upgrade when wallet has insufficient funds (50,000đ < 75,000đ)")
	
	# Deposit sufficient funds
	wallet.deposit(50000, "earnings", "Sửa xe & bán hủ tiếu")
	check(wallet.balance == 100000, "Wallet balance increased to 100,000đ")
	
	var can_upg2 := prog.can_upgrade(wallet)
	check(can_upg2["can_upgrade"], "Eligible to upgrade to Level 2 with 100,000đ balance")
	check(can_upg2["cost"] == 75000, "Level 2 cost is 75,000đ")
	
	# Execute upgrade to Level 2
	var res_upg2 := prog.upgrade_house(wallet)
	check(res_upg2["success"], "Upgrade to Level 2 succeeded")
	check(prog.house_level == 2, "House is now Level 2")
	check(wallet.balance == 25000, "Wallet deducted 75,000đ (new balance = 25,000đ)")
	check("tiled_kitchen" in prog.unlocked_areas, "Unlocked tiled_kitchen area in Level 2")
	check(prog.get_room_bounds().size.x > 15.0, "Room bounds expanded in Level 2")
	
	# Upgrade to Level 3 requires 150,000đ
	wallet.deposit(200000, "earnings", "Thu nhập kinh doanh phát đạt")
	var can_upg3 := prog.can_upgrade(wallet)
	check(can_upg3["can_upgrade"] and can_upg3["cost"] == 150000, "Eligible for Level 3 with 225,000đ balance (cost = 150,000đ)")
	
	var res_upg3 := prog.upgrade_house(wallet)
	check(res_upg3["success"], "Upgrade to Level 3 succeeded")
	check(prog.house_level == 3, "House is now Level 3 (Biệt thự sân vườn)")
	check("sunroom_wing" in prog.unlocked_areas and "courtyard_garden" in prog.unlocked_areas, "Level 3 unlocked sunroom_wing and courtyard_garden")
	check(prog.get_room_bounds().size.x > 20.0, "Room bounds further expanded to include sunroom wing")
	
	# Attempt upgrade past Level 3
	var can_upg_max := prog.can_upgrade(wallet)
	check(not can_upg_max["can_upgrade"] and can_upg_max["reason"] == "MAX_LEVEL", "Cannot upgrade past Level 3 (MAX_LEVEL)")
	
	# -------------------------------------------------------------
	# Test 3: Furniture Catalog & Definitions
	# -------------------------------------------------------------
	var bed_def := FurnitureData.get_definition("furn_wooden_bed")
	check(bed_def["interact_kind"] == "bed", "Wooden bed has 'bed' interact kind")
	check(bed_def["solid"], "Wooden bed is solid")
	
	var chair_def := FurnitureData.get_definition("furn_chair")
	check(chair_def["interact_kind"] == "chair", "Chair has 'chair' interact kind")
	
	var lamp_def := FurnitureData.get_definition("furn_floor_lamp")
	check(lamp_def["interact_kind"] == "lamp", "Floor lamp has 'lamp' interact kind")
	
	# -------------------------------------------------------------
	# Test 4: Furniture Placement, Movement & Rotation
	# -------------------------------------------------------------
	var place_mgr := FurniturePlacementManager.new()
	root.add_child(place_mgr)
	
	check(not place_mgr.is_active(), "Placement manager starts in IDLE")
	place_mgr.start_placement("furn_deluxe_sofa")
	check(place_mgr.is_active(), "Placement manager active in PLACING mode")
	check(place_mgr.active_furniture_id == "furn_deluxe_sofa", "Active furniture is furn_deluxe_sofa")
	check(is_instance_valid(place_mgr.preview_node), "Ghost preview node spawned")
	
	# Rotation
	var initial_rot := place_mgr.current_rotation
	place_mgr.rotate_preview()
	check(is_equal_approx(place_mgr.current_rotation, initial_rot + PI / 2.0), "Rotate preview turned 90°")
	
	# Room bounds check: Out of bounds rejection
	var bounds := prog.get_room_bounds()
	var out_of_bounds_pos := Vector3(99.0, 0.0, 99.0)
	var val_oob := place_mgr.validate_placement(out_of_bounds_pos, place_mgr.current_rotation, null, bounds)
	check(not val_oob["valid"] and val_oob["reason"] == "OUT_OF_BOUNDS", "Out-of-bounds position rejected: %s" % val_oob["reason"])
	
	# Valid position inside room
	var valid_pos := Vector3(0.0, 0.0, 0.0)
	var val_ok := place_mgr.validate_placement(valid_pos, place_mgr.current_rotation, null, bounds)
	check(val_ok["valid"], "Valid in-room position accepted")
	
	# Confirm placement creates real physical instance
	var placed_sofa := place_mgr.confirm_placement(valid_pos, null, bounds)
	check(is_instance_valid(placed_sofa), "Placed sofa instance successfully created")
	root.add_child(placed_sofa)
	check(not place_mgr.is_active(), "Placement manager returned to IDLE after confirm")
	check(placed_sofa.has_node("Collider"), "Placed furniture has physical static collider")
	check(placed_sofa.has_node("Interactable"), "Placed sofa has Interactable component")
	
	var sofa_interact: Interactable = placed_sofa.get_node("Interactable") as Interactable
	check(sofa_interact.kind == "sofa", "Interactable kind is sofa")
	
	# -------------------------------------------------------------
	# Test 5: Furniture Rearrangement & Moving Owned Pieces
	# -------------------------------------------------------------
	var rearrange_ok := place_mgr.start_rearrange(placed_sofa)
	check(rearrange_ok, "Started rearranging existing placed sofa")
	check(place_mgr.state == FurniturePlacementManager.State.REARRANGING, "Manager entered REARRANGING state")
	check(not placed_sofa.visible, "Original furniture hidden during rearrange")
	
	# Rotate during rearrange
	place_mgr.rotate_preview()
	var new_pos := Vector3(2.0, 0.0, 1.0)
	var moved_sofa := place_mgr.confirm_placement(new_pos, null, bounds)
	check(is_instance_valid(moved_sofa), "Sofa placed at new position")
	root.add_child(moved_sofa)
	check(moved_sofa.position.is_equal_approx(new_pos), "Sofa coordinates updated to new position (2, 0, 1)")
	
	# -------------------------------------------------------------
	# Test 6: Interactions with Bed, Chair, Lamp, and Door
	# -------------------------------------------------------------
	# Bed interaction (chiếu ngủ & giường gỗ)
	var bed_instance := FurnitureData.create_placed_instance("furn_wooden_bed", Vector3(-4, 0, 2), 0.0)
	root.add_child(bed_instance)
	var bed_interact: Interactable = bed_instance.get_node("Interactable") as Interactable
	check(bed_interact.kind == "bed", "Bed interactable kind is 'bed'")
	check(bed_interact.prompt(null) == "Nằm nghỉ", "Bed prompt shows 'Nằm nghỉ'")
	
	# Chair interaction
	var chair_instance := FurnitureData.create_placed_instance("furn_chair", Vector3(1, 0, 1), 0.0)
	root.add_child(chair_instance)
	var chair_interact: Interactable = chair_instance.get_node("Interactable") as Interactable
	check(chair_interact.kind == "chair", "Chair interactable kind is 'chair'")
	check(chair_interact.prompt(null) == "Ngồi ghế", "Chair prompt shows 'Ngồi ghế'")
	
	# Lamp interaction
	var lamp_instance := FurnitureData.create_placed_instance("furn_floor_lamp", Vector3(-3, 0, -3), 0.0)
	root.add_child(lamp_instance)
	var lamp_interact: Interactable = lamp_instance.get_node("Interactable") as Interactable
	check(lamp_interact.kind == "lamp", "Lamp interactable kind is 'lamp'")
	var initial_toggle := lamp_interact.toggle
	lamp_interact.interact(null)
	check(lamp_interact.toggle != initial_toggle, "Lamp toggled state on interact")
	
	# -------------------------------------------------------------
	# Test 7: Persistence - Save and Restore House State
	# -------------------------------------------------------------
	var save_wallet := HouseholdWallet.new()
	save_wallet.balance = 180000
	var save_inv := InventoryManager.new()
	save_inv.unlock_furniture("furn_deluxe_sofa")
	save_inv.unlock_furniture("furn_wooden_bed")
	
	var save_prog := HouseProgressionManager.new()
	save_prog.house_level = 2
	save_prog.unlocked_areas = ["main_room", "tiled_kitchen"]
	save_prog.register_placed_furniture("furn_deluxe_sofa", Vector3(-2.0, 0.0, 1.0), PI)
	save_prog.register_placed_furniture("furn_wooden_bed", Vector3(-5.0, 0.0, 2.5), 0.0)
	
	var house_save_data := save_prog.get_save_data()
	var save_ok := EconomySaveSystem.save_economy(save_wallet, save_inv, {}, house_save_data, temp_save_path)
	check(save_ok, "Saved economy and house progression state to %s" % temp_save_path)
	check(FileAccess.file_exists(temp_save_path), "Save file created on disk")
	
	# Restore on fresh progression manager
	var restored_house_data := EconomySaveSystem.load_house_data(temp_save_path)
	var restored_prog := HouseProgressionManager.new()
	restored_prog.apply_save_data(restored_house_data)
	
	check(restored_prog.house_level == 2, "Restored house level is Level 2")
	check("tiled_kitchen" in restored_prog.unlocked_areas, "Restored unlocked_areas preserved tiled_kitchen")
	check(restored_prog.placed_furniture.size() == 2, "Restored 2 placed furniture items")
	check(restored_prog.placed_furniture[0]["id"] == "furn_deluxe_sofa", "First item is deluxe sofa")
	check(restored_prog.placed_furniture[1]["id"] == "furn_wooden_bed", "Second item is wooden bed")
	
	# Missing save file safe recovery
	var missing_data := EconomySaveSystem.load_house_data("user://non_existent_save_xyz.json")
	check(missing_data["level"] == 1, "Missing save file safely defaults to Level 1 without crashing")
	
	# Cleanup temp file
	if FileAccess.file_exists(temp_save_path):
		DirAccess.remove_absolute(temp_save_path)
		
	# Clean up test nodes
	place_mgr.free()
	moved_sofa.free()
	bed_instance.free()
	chair_instance.free()
	lamp_instance.free()
	
	print("\nHOME_PROGRESSION_RESULT failures=", failures)
	quit(1 if failures else 0)
