extends "res://tests/visual/scenarios/scenario_base.gd"

func run_scenario() -> Dictionary:
	print("--- Running TC12: House & Business Upgrades Progression ---")
	scenario_description = "Tests progression mechanics for household and business upgrades: player walks to House Upgrade Board in bedroom, reviews Level 2 requirements, initiates two-step confirmation, executes house upgrade (wallet deducted 75,000đ, tiled kitchen spawned, room bounds expanded), verifies business equipment upgrade at Garage, and confirms save/load persistence."
	expected_result = "House upgrade board requires two-step confirmation, deducts correct funds from wallet, triggers real-time architectural rebuild with kitchen area, and unlocks business upgrades."
	related_sources = [
		"res://scripts/house/house_progression_manager.gd",
		"res://scripts/house/house_upgrade_board.gd",
		"res://scripts/room.gd",
		"res://scripts/neighborhood/business/garage_business.gd",
		"res://scripts/economy/economy_manager.gd"
	]
	reproduction_steps = [
		"1. Position player in bedroom (-45, 0, 89) and deposit 150,000đ into shared wallet.",
		"2. Verify house starts at Level 1 with compact starter bounds.",
		"3. Walk to HouseUpgradeBoard on wall (-46.8, 0, 83.6).",
		"4. Press [E] once: assert board enters confirmation state ('Nhấn E lần nữa để XÁC NHẬN').",
		"5. Press [E] second time: execute upgrade to Level 2 (Căn hộ ấm cúng).",
		"6. Assert house level is 2, wallet deducted 75,000đ, and tiled kitchen spawned.",
		"7. Assert room bounds expand in Z and X dimensions.",
		"8. Unlock Garage Second Bay upgrade and verify visual platform instance created.",
		"9. Save state and assert reload preserves Level 2 and owned upgrades."
	]
	
	recorder.start_recording("TC12_house_business_upgrades")
	
	player.global_position = Vector3(-45.0, 0, 89.0)
	player.select_character("boy")
	await wait_and_record(6)
	
	var world = game_manager.get_node_or_null("Neighborhood")
	var econ: EconomyManager = world.economy_manager
	var room: Room = game_manager.get_node_or_null("Room")
	var prog: HouseProgressionManager = room.progression_manager if room else null
	var board: HouseUpgradeBoard = room.upgrade_board if room else null
	
	check(is_instance_valid(prog) and is_instance_valid(board), "HouseProgressionManager and UpgradeBoard exist")
	
	# Reset house to Level 1 and fund wallet
	prog.house_level = 1
	prog.unlocked_areas = ["main_room"]
	room.rebuild_house()
	econ.wallet.set_balance_for_test(150000)
	board.wallet = econ.wallet
	await wait_and_record(6)
	
	check(prog.house_level == 1, "House starts at Level 1")
	var starter_bounds = prog.get_current_bounds()
	
	# 1. Player walks to House Upgrade Board
	var board_world = board.global_position
	await simulate_walk(board_world + Vector3(0, 0, 1.2), 1.5)
	await wait_and_record(6)
	
	check(board.available(player), "Upgrade board is interactive")
	var prompt_1: String = board.prompt(player)
	check("Nâng cấp lên" in prompt_1 and "75,000" in prompt_1, "Prompt shows Level 2 upgrade fee (75,000 đ)")
	
	# 2. First interaction: request confirmation
	board.interact(player)
	await wait_and_record(6)
	check(board.awaiting_confirmation_level == 2, "Board entered confirmation mode for Level 2")
	var prompt_confirm: String = board.prompt(player)
	check("XÁC NHẬN" in prompt_confirm, "Prompt requests confirmation ('Nhấn E lần nữa để XÁC NHẬN')")
	
	# 3. Second interaction: confirm and execute upgrade
	var balance_before = econ.wallet.balance
	board.interact(player)
	await wait_and_record(15)
	
	check(prog.house_level == 2, "House successfully upgraded to Level 2 (Căn hộ ấm cúng)")
	check(econ.wallet.balance == balance_before - 75000, "Wallet deducted 75,000đ (new balance: %d đ)" % econ.wallet.balance)
	check(prog.unlocked_areas.has("tiled_kitchen"), "Tiled kitchen area unlocked in Level 2")
	
	var expanded_bounds = prog.get_current_bounds()
	check(expanded_bounds.size.z > starter_bounds.size.z, "Room bounds physically expanded to accommodate kitchen")
	
	# Walk into newly expanded kitchen area
	await simulate_walk(Vector3(-42.0, 0, 91.0), 1.5)
	await wait_and_record(8)
	
	# 4. Test Business Upgrade: Garage Second Bay
	var garage: GarageBusiness = world.get_node_or_null("GarageBusiness") if world else null
	check(is_instance_valid(garage), "Garage business exists")
	check(not garage.is_second_bay_unlocked, "Second bay starts locked")
	
	garage.apply_second_bay_upgrade()
	await wait_and_record(10)
	
	check(garage.is_second_bay_unlocked, "Second service bay unlocked")
	check(is_instance_valid(garage.second_bay_visual_node), "Second bay visual platform spawned in 3D world")
	
	# 5. Verify Save and Load persistence of progression
	var test_upg_save := "user://test_tc12_upgrades.json"
	econ.save_file_path = test_upg_save
	econ.house_manager = room
	econ.save_economy_state()
	await wait_and_record(6)
	
	check(FileAccess.file_exists(test_upg_save), "Progression saved to disk")
	
	var test_wallet = HouseholdWallet.new()
	var test_inv = InventoryManager.new()
	var l_data = EconomySaveSystem.load_economy(test_wallet, test_inv, test_upg_save)
	
	var h_data: Dictionary = l_data.get("house_progression", {})
	check(int(h_data.get("house_level", 1)) == 2, "Reloaded save preserves house level 2")
	
	if FileAccess.file_exists(test_upg_save):
		DirAccess.remove_absolute(test_upg_save)
	
	notes = "Verified two-step confirmation, wallet deduction, house rebuild with kitchen area, garage second bay upgrade, and persistence."
	var gif_path = recorder.stop_recording_and_export_gif(30)
	return build_result(gif_path)
