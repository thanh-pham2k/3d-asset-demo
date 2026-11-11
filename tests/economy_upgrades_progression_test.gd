extends SceneTree

## Comprehensive test suite for Economy, Business Upgrades, Home Progression,
## Goals Motivation, and Persistence in Couple Chaos.

const EconomyProduct = preload("res://scripts/economy/economy_product.gd")
const HouseholdWallet = preload("res://scripts/economy/household_wallet.gd")
const InventoryManager = preload("res://scripts/economy/inventory_manager.gd")
const EconomyManager = preload("res://scripts/economy/economy_manager.gd")
const EconomySaveSystem = preload("res://scripts/economy/economy_save_system.gd")
const GarageBusiness = preload("res://scripts/neighborhood/business/garage_business.gd")
const HuTieuBusiness = preload("res://scripts/neighborhood/business/hutieu_business.gd")
const BusinessOrder = preload("res://scripts/neighborhood/business/business_order.gd")
const HouseProgressionManager = preload("res://scripts/house/house_progression_manager.gd")
const FurniturePlacementManager = preload("res://scripts/house/furniture_placement_manager.gd")
const FurnitureData = preload("res://scripts/house/furniture_data.gd")
const HouseStorage = preload("res://scripts/house/house_storage.gd")

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
	print("================================================================")
	print("--- Running Economy, Upgrades & Home Progression Test Suite ---")
	print("================================================================")
	
	var temp_save_path := "user://test_validation_save.json"
	if FileAccess.file_exists(temp_save_path):
		DirAccess.remove_absolute(temp_save_path)
	
	# =============================================================
	# SECTION 1: WALLET EARNING, SPENDING & DEDUPLICATION
	# =============================================================
	print("\n--- 1. Testing Wallet Earning, Spending & Deduplication ---")
	var wallet := HouseholdWallet.new()
	check(wallet.balance == 100000, "Starting wallet balance is 100,000 đ")
	
	# Deposit earnings from garage
	var dep1 := wallet.deposit(20000, "garage_revenue", "Bơm lốp xe", "tx_g_001")
	check(dep1 and wallet.balance == 120000, "Garage earnings deposited (+20,000đ, new bal: 120,000đ)")
	
	# Prevent duplicate deposit
	var dep1_dup := wallet.deposit(20000, "garage_revenue", "Bơm lốp xe", "tx_g_001")
	check(not dep1_dup and wallet.balance == 120000, "Duplicate reward blocked by transaction ID")
	
	# Deposit earnings from hu tieu
	var dep2 := wallet.deposit(45000, "hutieu_revenue", "Hủ tiếu Nam Vang", "tx_h_001")
	check(dep2 and wallet.balance == 165000, "Hu Tieu earnings deposited (+45,000đ, new bal: 165,000đ)")
	
	# Withdraw funds
	var wdr1 := wallet.withdraw(35000, "consumables", "Mua sườn non heo", "tx_w_001")
	check(wdr1 and wallet.balance == 130000, "Withdrawal executed (-35,000đ, new bal: 130,000đ)")
	
	# Prevent duplicate withdrawal
	var wdr1_dup := wallet.withdraw(35000, "consumables", "Mua sườn non heo", "tx_w_001")
	check(not wdr1_dup and wallet.balance == 130000, "Duplicate withdrawal blocked by transaction ID")
	
	# Verify transaction history
	var hist := wallet.get_history(10)
	check(hist.size() == 3, "Transaction history contains exactly 3 operations")
	check(hist[0]["type"] == "SPEND" and hist[0]["amount"] == -35000, "Recent operation was 35,000đ spend")
	check(hist[1]["type"] == "EARN" and hist[1]["amount"] == 45000, "Previous operation was 45,000đ earn")
	
	# =============================================================
	# SECTION 2: INSUFFICIENT FUNDS & OVERDRAFT PREVENTION
	# =============================================================
	print("\n--- 2. Testing Insufficient Funds & Overdraft Prevention ---")
	var overdraw := wallet.withdraw(500000, "luxury", "Chi tiêu vượt mức")
	check(not overdraw, "Overdraft attempt strictly rejected")
	check(wallet.balance == 130000, "Wallet balance preserved without going negative")
	
	var econ := EconomyManager.new()
	econ.save_file_path = temp_save_path
	econ.auto_save_on_change = false
	econ.wallet.balance = 20000 # Only 20,000đ left
	
	var buy_fail := econ.purchase_product("furn_deluxe_sofa", 1) # Costs 150,000đ
	check(not buy_fail["success"] and buy_fail["reason"] == "INSUFFICIENT_FUNDS", "EconomyManager blocked purchase on insufficient funds")
	check(econ.wallet.balance == 20000, "Balance unchanged after blocked purchase")
	
	# =============================================================
	# SECTION 3: REPEATED PURCHASE ATTEMPTS & MULTI-QUANTITY
	# =============================================================
	print("\n--- 3. Testing Repeated Purchases & Multi-Quantity Items ---")
	econ.wallet.balance = 1000000 # Give ample testing funds
	
	# Buy unique furniture once
	var buy_sofa := econ.purchase_product("furn_deluxe_sofa", 1)
	check(buy_sofa["success"], "First purchase of unique deluxe sofa succeeded")
	check(econ.inventory.is_furniture_owned("furn_deluxe_sofa"), "Deluxe sofa recorded in inventory")
	
	# Try buying the same unique furniture again
	var buy_sofa_dup := econ.purchase_product("furn_deluxe_sofa", 1)
	check(not buy_sofa_dup["success"] and buy_sofa_dup["reason"] == "ALREADY_OWNED", "Repeated purchase of unique furniture blocked (ALREADY_OWNED)")
	
	# Buy business upgrade
	var buy_bay := econ.purchase_product("upg_garage_second_bay", 1)
	check(buy_bay["success"], "Purchase of business upgrade (second bay) succeeded")
	check(econ.inventory.is_upgrade_owned("upg_garage_second_bay"), "Second bay upgrade marked unlocked")
	
	# Try buying the same business upgrade again
	var buy_bay_dup := econ.purchase_product("upg_garage_second_bay", 1)
	check(not buy_bay_dup["success"] and buy_bay_dup["reason"] == "ALREADY_OWNED", "Repeated purchase of business upgrade blocked (ALREADY_OWNED)")
	
	# Non-unique items (e.g. furn_chair, ing_fresh_shrimp) can be purchased multiple times
	var buy_chair1 := econ.purchase_product("furn_chair", 2)
	check(buy_chair1["success"], "Purchased 2 chairs")
	check(econ.inventory.get_furniture_count("furn_chair") == 2, "Inventory holds 2 chairs")
	
	var buy_chair2 := econ.purchase_product("furn_chair", 1)
	check(buy_chair2["success"], "Purchased 1 additional chair")
	check(econ.inventory.get_furniture_count("furn_chair") == 3, "Inventory successfully updated to 3 chairs")
	
	# =============================================================
	# SECTION 4: MOTORCYCLE SHOP UPGRADES & GAMEPLAY EFFECTS
	# =============================================================
	print("\n--- 4. Testing Motorcycle Shop Upgrades & Gameplay Effects ---")
	var garage := GarageBusiness.new()
	root.add_child(garage)
	
	# Verify baseline state (Bay 0 only, base tools, base compressor)
	check(not garage.is_second_bay_unlocked, "Second bay starts locked")
	check(not garage.is_better_tools_unlocked, "Better tools starts locked")
	check(not garage.is_faster_service_unlocked, "Faster compressor starts locked")
	check(garage.spawn_interval == 14.0, "Base spawn interval is 14.0s")
	
	# 1. Test Additional Repair Bay upgrade
	garage.apply_second_bay_upgrade()
	check(garage.is_second_bay_unlocked, "Second bay upgrade applied")
	check(is_instance_valid(garage.second_bay_visual_node), "Hydraulic lift platform visual created at Bay 1")
	
	# 2. Test Better Repair Tools upgrade
	garage.apply_better_tools_upgrade()
	check(garage.is_better_tools_unlocked, "Better tools upgrade applied")
	check(is_instance_valid(garage.tools_visual_node), "Chrome tool chest & inspection lamp visual created at workbench")
	
	# Verify 30% tip bonus on order completion
	var test_order := BusinessOrder.new("ord_tip_test", "inflate", "Bơm lốp xe", 20000, ["pump_air"])
	test_order.table_index = 0
	garage.active_orders.append(test_order)
	garage.complete_order(test_order)
	check(test_order.reward_money == 26000, "Better tools awarded +30%% bonus tip (20,000đ -> 26,000đ)")
	
	# 3. Test Faster Service upgrade
	garage.apply_compressor_upgrade()
	check(garage.is_faster_service_unlocked, "Faster compressor service applied")
	check(garage.spawn_interval == 8.0, "Customer spawn interval accelerated to 8.0s")
	check(garage.get_patience_multiplier() >= 1.4, "Customer patience multiplier increased by +40%%")
	check(is_instance_valid(garage.compressor_visual_node), "Industrial compressor tank visual created at air pump")
	
	# =============================================================
	# SECTION 5: HU TIEU SHOP UPGRADES & GAMEPLAY EFFECTS
	# =============================================================
	print("\n--- 5. Testing Hu Tieu Shop Upgrades & Gameplay Effects ---")
	var hutieu := HuTieuBusiness.new()
	root.add_child(hutieu)
	
	check(hutieu.table_positions.size() == 3, "Baseline Hu Tieu has 3 dining tables")
	check(hutieu.current_blanch_duration == 1.6, "Base blanch duration is 1.6s")
	check(hutieu.current_prep_speed == 33.34, "Base prep speed is 33.34")
	
	# 1. Test Additional Seating upgrade
	hutieu.apply_extra_table_upgrade()
	check(hutieu.is_extra_table_unlocked, "Additional seating upgrade applied")
	check(hutieu.table_positions.size() == 4, "Hu Tieu capacity expanded to 4 dining tables")
	check(is_instance_valid(hutieu.extra_table_node), "DiningTable_3 with chairs and umbrella visual spawned")
	check(hutieu.table_status_labels.has(3), "Status label created for DiningTable_3")
	
	# 2. Test Faster Cooking Equipment upgrade
	hutieu.apply_quick_stove_upgrade()
	check(hutieu.is_quick_stove_unlocked, "Quick stove equipment applied")
	check(hutieu.current_blanch_duration == 0.4, "Blanch duration reduced to 0.4s (super fast)")
	check(hutieu.current_prep_speed == 66.7, "Morning prep speed doubled to 66.7 (1.5s total)")
	check(is_instance_valid(hutieu.stove_upgrade_node), "Stainless steel boiling boiler & blue gas flames visual created")
	
	# 3. Test Improved Kitchen Capacity upgrade
	hutieu.apply_kitchen_capacity_upgrade()
	check(hutieu.is_kitchen_capacity_unlocked, "Kitchen capacity & iced tea service applied")
	check(hutieu.get_patience_multiplier() >= 1.35, "Customer patience increased by +35%% while sipping iced tea")
	check(is_instance_valid(hutieu.kitchen_capacity_node), "Free iced tea dispenser visual created at toppings station")
	
	# Verify +25% revenue bonus on served dish
	var dish_order := BusinessOrder.new("ord_dish_tip", "noodle_nam_vang", "Hủ tiếu Nam Vang", 40000, ["serve_table"])
	dish_order.table_index = 0
	hutieu.active_orders.append(dish_order)
	hutieu.complete_order(dish_order)
	check(dish_order.reward_money == 50000, "Kitchen capacity upgrade awarded +25%% bonus earnings (40,000đ -> 50,000đ)")
	
	# =============================================================
	# SECTION 6: HOME PROGRESSION, PLACEMENT & REARRANGEMENT
	# =============================================================
	print("\n--- 6. Testing Home Progression, Placement & Rearrangement ---")
	var prog := HouseProgressionManager.new()
	check(prog.house_level == 1, "House starts at Level 1")
	check(prog.get_room_bounds().size.x < 15.0, "Level 1 has compact bounds")
	
	var h_wallet := HouseholdWallet.new()
	h_wallet.balance = 75000
	var upg2_res := prog.upgrade_house(h_wallet)
	check(upg2_res["success"] and prog.house_level == 2, "Upgraded to Level 2 (Căn hộ ấm cúng)")
	check("tiled_kitchen" in prog.unlocked_areas, "Level 2 unlocked tiled_kitchen")
	
	h_wallet.balance = 150000
	var upg3_res := prog.upgrade_house(h_wallet)
	check(upg3_res["success"] and prog.house_level == 3, "Upgraded to Level 3 (Biệt thự sân vườn)")
	check("sunroom_wing" in prog.unlocked_areas, "Level 3 unlocked sunroom_wing")
	check(prog.get_room_bounds().size.x > 20.0, "Level 3 room bounds fully expanded")
	
	# Storage & Inventory sync
	var test_inv := InventoryManager.new()
	test_inv.unlock_furniture("furn_deluxe_sofa")
	test_inv.unlock_furniture("furn_chair", 2, true)
	
	var storage := HouseStorage.new()
	storage.sync_with_inventory(test_inv, [])
	var st_items := storage.get_items()
	check(st_items.size() == 3, "Storage contains 3 unplaced items (1 sofa + 2 chairs)")
	
	# Placement & bounds validation
	var place_mgr := FurniturePlacementManager.new()
	root.add_child(place_mgr)
	place_mgr.start_placement("furn_deluxe_sofa")
	
	var bounds := prog.get_room_bounds()
	var val_oob := place_mgr.validate_placement(Vector3(100, 0, 100), 0.0, null, bounds)
	check(not val_oob["valid"] and val_oob["reason"] == "OUT_OF_BOUNDS", "Prevented out-of-bounds placement")
	
	var val_valid := place_mgr.validate_placement(Vector3(0, 0, 0), 0.0, null, bounds)
	check(val_valid["valid"], "Valid placement position accepted")
	
	var placed_inst := place_mgr.confirm_placement(Vector3(0, 0, 0), null, bounds)
	check(is_instance_valid(placed_inst), "Placed furniture instance created")
	root.add_child(placed_inst)
	
	# Rearrangement
	var start_rearr := place_mgr.start_rearrange(placed_inst)
	check(start_rearr and place_mgr.state == FurniturePlacementManager.State.REARRANGING, "Started rearrangement")
	check(not placed_inst.visible, "Original furniture hidden during rearrange")
	
	var new_placed := place_mgr.confirm_placement(Vector3(1.5, 0, 0.5), null, bounds)
	check(is_instance_valid(new_placed), "Rearranged furniture confirmed at new coordinates")
	root.add_child(new_placed)
	
	# Rearrangement cancellation preserves original node
	var start_cancel_test := place_mgr.start_rearrange(new_placed)
	check(start_cancel_test, "Started another rearrange to test cancel")
	place_mgr.cancel_placement()
	check(new_placed.visible, "Cancelled rearrange restored original furniture visibility")
	check(place_mgr.state == FurniturePlacementManager.State.IDLE, "Placement manager returned to IDLE")
	
	# =============================================================
	# SECTION 7: PLAYER MOTIVATION & GOAL PROGRESSION
	# =============================================================
	print("\n--- 7. Testing Player Motivation & Goal Progression ---")
	var goal_econ := EconomyManager.new()
	goal_econ.wallet.balance = 50000
	goal_econ.wallet.total_earned = 20000
	
	var goal1 := goal_econ.get_goal_info()
	check(goal1["id"] == "goal_first_earnings", "Initial goal is early earnings milestone")
	check(goal1.has("next_upgrade_name") and goal1["next_upgrade_cost"] == 75000, "Goal shows next available upgrade (Nhà Cấp 2, 75,000đ)")
	
	goal_econ.wallet.balance = 80000
	goal_econ.wallet.total_earned = 110000
	var goal2 := goal_econ.get_goal_info()
	check(goal2["id"] == "goal_house_lvl_2", "Goal progresses to upgrading house to Level 2")
	check(goal2["is_ready_to_buy"], "Goal indicates ready to buy (balance >= 75,000đ)")
	
	# Unlock house level 2
	goal_econ.inventory.unlock_upgrade("upg_house_level_2")
	var goal3 := goal_econ.get_goal_info()
	check(goal3["id"] == "goal_first_business_upgrade", "Goal progresses to first business equipment upgrade")
	
	# =============================================================
	# SECTION 8: PERSISTENCE, SAVE/LOAD & CORRUPTED RECOVERY
	# =============================================================
	print("\n--- 8. Testing Persistence, Save/Load & Recovery ---")
	var p_wallet := HouseholdWallet.new()
	p_wallet.balance = 350000
	p_wallet.total_earned = 500000
	p_wallet.total_spent = 150000
	
	var p_inv := InventoryManager.new()
	p_inv.add_item("ing_fresh_shrimp", 4)
	p_inv.unlock_upgrade("upg_garage_second_bay")
	p_inv.unlock_upgrade("upg_garage_tools")
	p_inv.unlock_upgrade("upg_hutieu_extra_table")
	p_inv.unlock_furniture("furn_deluxe_sofa")
	p_inv.unlock_furniture("furn_chair", 2, true)
	
	var p_house_data := {
		"level": 3,
		"unlocked_areas": ["main_room", "tiled_kitchen", "sunroom_wing"],
		"placed_furniture": [
			{"id": "furn_deluxe_sofa", "pos": [1.0, 0.0, 2.0], "rot_y": 1.57}
		]
	}
	
	var p_b_data := {
		"garage_earnings": 150000,
		"garage_served": 5,
		"hutieu_earnings": 180000,
		"hutieu_served": 4
	}
	
	var save_res := EconomySaveSystem.save_economy(p_wallet, p_inv, p_b_data, p_house_data, temp_save_path)
	check(save_res, "Economy & progression state successfully saved")
	check(FileAccess.file_exists(temp_save_path), "Save file exists on disk")
	
	# Load onto clean instances
	var r_wallet := HouseholdWallet.new()
	var r_inv := InventoryManager.new()
	var r_b_data := EconomySaveSystem.load_economy(r_wallet, r_inv, temp_save_path)
	
	check(r_wallet.balance == 350000, "Loaded wallet balance is 350,000 đ")
	check(r_wallet.total_earned == 500000, "Loaded total earned matches 500,000 đ")
	check(r_wallet.total_spent == 150000, "Loaded total spent matches 150,000 đ")
	check(r_inv.get_item_count("ing_fresh_shrimp") == 4, "Consumable ingredient count preserved (4)")
	check(r_inv.is_upgrade_owned("upg_garage_second_bay"), "Garage second bay upgrade preserved")
	check(r_inv.is_upgrade_owned("upg_garage_tools"), "Garage better tools upgrade preserved")
	check(r_inv.is_upgrade_owned("upg_hutieu_extra_table"), "Hu Tieu extra table upgrade preserved")
	check(r_inv.is_furniture_owned("furn_deluxe_sofa"), "Deluxe sofa ownership preserved")
	check(r_inv.get_furniture_count("furn_chair") == 2, "Multi-quantity chair count preserved (2)")
	check(int(r_b_data["garage_earnings"]) == 150000, "Garage business earnings restored (150,000đ)")
	check(int(r_b_data["hutieu_earnings"]) == 180000, "Hu Tieu business earnings restored (180,000đ)")
	
	var r_house := EconomySaveSystem.load_house_data(temp_save_path)
	check(int(r_house["level"]) == 3, "Restored house level is Level 3")
	check("sunroom_wing" in r_house["unlocked_areas"], "Restored unlocked areas contains sunroom_wing")
	check(r_house["placed_furniture"].size() == 1, "Restored placed furniture list preserved")
	
	# Test corrupt save file recovery
	var bad_file := FileAccess.open(temp_save_path, FileAccess.WRITE)
	bad_file.store_string("{ INVALID JSON GARBAGE #%&$*^(!@ ")
	bad_file.close()
	
	var c_wallet := HouseholdWallet.new()
	var c_inv := InventoryManager.new()
	var c_b_data := EconomySaveSystem.load_economy(c_wallet, c_inv, temp_save_path)
	check(c_wallet.balance == HouseholdWallet.DEFAULT_STARTING_BALANCE, "Corrupted save file safely recovered to default balance (100,000đ)")
	
	# Cleanup
	if FileAccess.file_exists(temp_save_path):
		DirAccess.remove_absolute(temp_save_path)
	garage.free()
	hutieu.free()
	place_mgr.free()
	new_placed.free()
	
	print("\n================================================================")
	print("ECONOMY_UPGRADES_PROGRESSION_RESULT failures=", failures)
	print("================================================================")
	quit(1 if failures else 0)
