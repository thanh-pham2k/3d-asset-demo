extends SceneTree

const EconomyProduct = preload("res://scripts/economy/economy_product.gd")
const HouseholdWallet = preload("res://scripts/economy/household_wallet.gd")
const InventoryManager = preload("res://scripts/economy/inventory_manager.gd")
const EconomySaveSystem = preload("res://scripts/economy/economy_save_system.gd")
const EconomyManager = preload("res://scripts/economy/economy_manager.gd")
const BusinessOrder = preload("res://scripts/neighborhood/business/business_order.gd")
const GarageBusiness = preload("res://scripts/neighborhood/business/garage_business.gd")
const HuTieuBusiness = preload("res://scripts/neighborhood/business/hutieu_business.gd")
const ShopKiosk = preload("res://scripts/neighborhood/shop_kiosk.gd")

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
	print("--- Running Persistent Economy System Tests ---")
	
	var temp_save_path := "user://test_economy_save.json"
	if FileAccess.file_exists(temp_save_path):
		DirAccess.remove_absolute(temp_save_path)
	
	# -------------------------------------------------------------
	# Test 1: Shared Household Wallet - Initial Balance & Formatting
	# -------------------------------------------------------------
	var wallet := HouseholdWallet.new()
	check(wallet.balance == 100000, "Initial starting savings is 100,000đ")
	check(wallet.can_afford(50000), "Can afford 50,000đ")
	check(not wallet.can_afford(150000), "Cannot afford 150,000đ with 100,000đ balance")
	check(HouseholdWallet.format_money(100000) == "100,000 đ", "Money format: '100,000 đ'")
	
	# -------------------------------------------------------------
	# Test 2: Deposit Earnings & Deduplication
	# -------------------------------------------------------------
	var ok_dep1 := wallet.deposit(35000, "garage_revenue", "Vá săm xe Chú Ba", "tx_test_1")
	check(ok_dep1, "Deposit 35,000đ succeeded")
	check(wallet.balance == 135000, "Balance updated to 135,000đ")
	check(wallet.total_earned == 35000, "Total earned is 35,000đ")
	
	# Attempt duplicate deposit with same transaction id
	var ok_dep_dup := wallet.deposit(35000, "garage_revenue", "Vá săm xe Chú Ba", "tx_test_1")
	check(not ok_dep_dup, "Duplicate deposit blocked by transaction ID")
	check(wallet.balance == 135000, "Balance remains 135,000đ after duplicate deposit attempt")
	
	# Hu Tieu order deposit
	var ok_dep2 := wallet.deposit(45000, "hutieu_revenue", "Bán Hủ tiếu Nam Vang Cô Bảy", "tx_test_2")
	check(ok_dep2, "Deposit 45,000đ from Hu Tieu order succeeded")
	check(wallet.balance == 180000, "Balance updated to 180,000đ")
	
	# -------------------------------------------------------------
	# Test 3: Withdrawal, Insufficient Funds & History
	# -------------------------------------------------------------
	var ok_wdr := wallet.withdraw(50000, "groceries", "Mua đồ ăn tươi", "tx_wdr_1")
	check(ok_wdr, "Withdrawal of 50,000đ succeeded")
	check(wallet.balance == 130000, "Balance is now 130,000đ")
	check(wallet.total_spent == 50000, "Total spent is 50,000đ")
	
	# Duplicate withdrawal blocked
	var ok_wdr_dup := wallet.withdraw(50000, "groceries", "Mua đồ ăn tươi", "tx_wdr_1")
	check(not ok_wdr_dup, "Duplicate withdrawal blocked by transaction ID")
	check(wallet.balance == 130000, "Balance remains 130,000đ after duplicate withdrawal attempt")
	
	# Insufficient funds check
	var ok_overdraw := wallet.withdraw(999999, "luxury", "Mua siêu xe")
	check(not ok_overdraw, "Overdraft attempt blocked (insufficient funds)")
	check(wallet.balance == 130000, "Balance preserved at 130,000đ (no negative balance)")
	
	# Transaction history
	var history := wallet.get_history(10)
	check(history.size() == 3, "Transaction history recorded 3 distinct entries")
	check(history[0]["type"] == "SPEND" and history[0]["amount"] == -50000, "Most recent transaction was 50,000đ withdrawal")
	check(history[1]["type"] == "EARN" and history[1]["amount"] == 45000, "Second transaction was 45,000đ deposit")
	
	# -------------------------------------------------------------
	# Test 4: Inventory & Ownership Manager
	# -------------------------------------------------------------
	var inv := InventoryManager.new()
	inv.add_item("ing_fresh_shrimp", 5)
	check(inv.get_item_count("ing_fresh_shrimp") == 5, "Added 5 fresh shrimps to inventory")
	check(inv.has_item("ing_fresh_shrimp", 3), "Has at least 3 shrimps")
	
	var rem_ok := inv.remove_item("ing_fresh_shrimp", 2)
	check(rem_ok, "Removed 2 shrimps")
	check(inv.get_item_count("ing_fresh_shrimp") == 3, "3 shrimps remain")
	
	var rem_fail := inv.remove_item("ing_fresh_shrimp", 10)
	check(not rem_fail, "Cannot remove more shrimps than available")
	check(inv.get_item_count("ing_fresh_shrimp") == 3, "Shrimp count unchanged after failed removal")
	
	# Upgrades & furniture
	check(not inv.is_upgrade_owned("upg_garage_second_bay"), "Second bay upgrade not initially owned")
	inv.unlock_upgrade("upg_garage_second_bay")
	check(inv.is_upgrade_owned("upg_garage_second_bay"), "Second bay upgrade unlocked")
	var dup_upg := inv.unlock_upgrade("upg_garage_second_bay")
	check(not dup_upg, "Duplicate upgrade unlock returns false")
	
	inv.unlock_furniture("furn_deluxe_sofa")
	check(inv.is_furniture_owned("furn_deluxe_sofa"), "Deluxe sofa unlocked")
	
	# -------------------------------------------------------------
	# Test 5: EconomyManager - Purchases Across All 5 Categories
	# -------------------------------------------------------------
	var mgr := EconomyManager.new()
	mgr.save_file_path = temp_save_path
	mgr.auto_save_on_change = false
	mgr.wallet.balance = 1000000 # Give funds for testing purchases
	
	# 1. Food ingredient
	var p_res1 := mgr.purchase_product("ing_fresh_shrimp", 2)
	check(p_res1["success"], "Purchased 2 fresh shrimps")
	check(mgr.inventory.get_item_count("ing_fresh_shrimp") == 2, "Shrimps stored in inventory")
	check(mgr.wallet.balance == 1000000 - (30000 * 2), "Deducted 60,000đ exactly once (balance = %d)" % mgr.wallet.balance)
	
	# 2. Repair tool
	var p_res2 := mgr.purchase_product("tool_patch_strip", 3)
	check(p_res2["success"], "Purchased 3 patch strips")
	check(mgr.inventory.get_item_count("tool_patch_strip") == 3, "Patch strips stored in inventory")
	
	# 3. Furniture (unique item)
	var p_res3 := mgr.purchase_product("furn_deluxe_sofa", 1)
	check(p_res3["success"], "Purchased deluxe sofa")
	check(mgr.inventory.is_furniture_owned("furn_deluxe_sofa"), "Sofa marked owned")
	# Try buying same unique furniture again
	var p_res3_dup := mgr.purchase_product("furn_deluxe_sofa", 1)
	check(not p_res3_dup["success"] and p_res3_dup["reason"] == "ALREADY_OWNED", "Blocked re-purchasing unique furniture")
	
	# 4. Business upgrade
	var p_res4 := mgr.purchase_product("upg_garage_second_bay", 1)
	check(p_res4["success"], "Purchased second service bay upgrade")
	check(mgr.inventory.is_upgrade_owned("upg_garage_second_bay"), "Second service bay marked unlocked")
	
	# 5. House upgrade
	var p_res5 := mgr.purchase_product("upg_house_flower_garden", 1)
	check(p_res5["success"], "Purchased flower garden house upgrade")
	check(mgr.inventory.is_upgrade_owned("upg_house_flower_garden"), "Flower garden marked unlocked")
	
	# Insufficient funds check via EconomyManager
	mgr.wallet.balance = 10000 # Only 10,000đ left
	var p_fail := mgr.purchase_product("furn_smart_tv", 1) # Costs 250,000đ
	check(not p_fail["success"] and p_fail["reason"] == "INSUFFICIENT_FUNDS", "Blocked purchase when funds insufficient")
	check(mgr.wallet.balance == 10000, "Balance unchanged after blocked purchase")
	
	# -------------------------------------------------------------
	# Test 6: Persistence - Save and Load
	# -------------------------------------------------------------
	var saved_balance := mgr.wallet.balance
	var saved_earned := mgr.wallet.total_earned
	var saved_spent := mgr.wallet.total_spent
	
	var save_ok := mgr.save_economy_state(temp_save_path)
	check(save_ok, "Economy state saved to %s" % temp_save_path)
	check(FileAccess.file_exists(temp_save_path), "Save file exists on filesystem")
	
	# Load on fresh economy instance
	var loaded_mgr := EconomyManager.new()
	loaded_mgr.save_file_path = temp_save_path
	var load_ok := loaded_mgr.load_economy_state(temp_save_path)
	check(load_ok, "Economy state loaded successfully")
	check(loaded_mgr.wallet.balance == saved_balance, "Loaded wallet balance matches saved balance (%d)" % saved_balance)
	check(loaded_mgr.wallet.total_earned == saved_earned, "Loaded total earned matches (%d)" % saved_earned)
	check(loaded_mgr.wallet.total_spent == saved_spent, "Loaded total spent matches (%d)" % saved_spent)
	check(loaded_mgr.inventory.get_item_count("ing_fresh_shrimp") == 2, "Loaded shrimp count matches (2)")
	check(loaded_mgr.inventory.is_furniture_owned("furn_deluxe_sofa"), "Loaded deluxe sofa ownership preserved")
	check(loaded_mgr.inventory.is_upgrade_owned("upg_garage_second_bay"), "Loaded garage second bay upgrade preserved")
	check(loaded_mgr.inventory.is_upgrade_owned("upg_house_flower_garden"), "Loaded flower garden upgrade preserved")
	
	# -------------------------------------------------------------
	# Test 7: Missing & Corrupted Save File Resiliency
	# -------------------------------------------------------------
	var missing_mgr := EconomyManager.new()
	var missing_load_ok := missing_mgr.load_economy_state("user://non_existent_file_xyz.json")
	check(missing_load_ok, "Missing save file loads clean default state safely without crashing")
	check(missing_mgr.wallet.balance == HouseholdWallet.DEFAULT_STARTING_BALANCE, "Default starting balance retained")
	
	# Write corrupted content to temp file
	var bad_file := FileAccess.open(temp_save_path, FileAccess.WRITE)
	bad_file.store_string("THIS_IS_CORRUPTED_GARBAGE_JSON_}{}{][!@#")
	bad_file.close()
	
	var corrupt_mgr := EconomyManager.new()
	var corrupt_load_ok := corrupt_mgr.load_economy_state(temp_save_path)
	check(corrupt_load_ok, "Corrupted save file recovered safely without crashing")
	check(corrupt_mgr.wallet.balance == HouseholdWallet.DEFAULT_STARTING_BALANCE, "Corrupted file fell back to default balance")
	
	# Cleanup temp file
	if FileAccess.file_exists(temp_save_path):
		DirAccess.remove_absolute(temp_save_path)
	
	# -------------------------------------------------------------
	# Test 8: Full Neighborhood World Integration
	# -------------------------------------------------------------
	# Clean any default save file before testing world integration
	if FileAccess.file_exists(temp_save_path):
		DirAccess.remove_absolute(temp_save_path)
	
	var world: Node = load("res://scenes/neighborhood.tscn").instantiate()
	world.economy_save_path = temp_save_path
	root.add_child(world)
	current_scene = world
	
	for i in range(5): await process_frame
	
	var world_econ: EconomyManager = world.get_node_or_null("EconomyManager") as EconomyManager
	check(is_instance_valid(world_econ), "EconomyManager active in neighborhood world")
	
	var world_wallet_lbl: Label = world.wallet_label
	check(is_instance_valid(world_wallet_lbl), "HUD has wallet display label")
	check("Ví Gia Đình" in world_wallet_lbl.text, "Wallet label displays: '%s'" % world_wallet_lbl.text)
	
	# Test Kiosks
	var furn_kiosk: ShopKiosk = world.get_node_or_null("Kiosk_Furniture") as ShopKiosk
	check(is_instance_valid(furn_kiosk), "Furniture store kiosk present in world")
	check("Mua sắm" in furn_kiosk.prompt(world.player), "Kiosk prompt: '%s'" % furn_kiosk.prompt(world.player))
	
	var initial_world_bal := world_econ.wallet.balance
	# Simulate garage order completion connecting to shared wallet
	var garage: GarageBusiness = world.get_node_or_null("GarageBusiness") as GarageBusiness
	check(is_instance_valid(garage), "GarageBusiness present in world")
	
	var test_order_id := "ord_int_%d" % Time.get_ticks_msec()
	var test_order := BusinessOrder.new(test_order_id, "inflate", "Bơm lốp xe", 20000, ["pump_air"])
	garage.active_orders.append(test_order)
	garage.complete_order(test_order)
	
	check(world_econ.wallet.balance == initial_world_bal + 20000, "Garage order completed deposited +20,000đ into shared wallet (new bal = %d)" % world_econ.wallet.balance)
	
	# Process frame and verify HUD label update
	world._process(0.1)
	check(HouseholdWallet.format_money(world_econ.wallet.balance) in world_wallet_lbl.text, "HUD wallet label updated with new balance: '%s'" % world_wallet_lbl.text)
	
	# Clean up default save file created during test run
	if FileAccess.file_exists(temp_save_path):
		DirAccess.remove_absolute(temp_save_path)
	
	print("\nECONOMY_SYSTEM_RESULT failures=", failures)
	world.free()
	quit(1 if failures else 0)
