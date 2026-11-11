extends "res://tests/visual/scenarios/scenario_base.gd"

func run_scenario() -> Dictionary:
	print("--- Running TC10: Return Home & Persistence ---")
	scenario_description = "Tests end-of-day return home flow: revenue accumulation in household wallet, walking from front yard into bedroom, bed rest interaction triggering automatic state saving to disk, waking up, and reloading saved state to verify balance, earnings, and deduplication cache."
	expected_result = "Bed rest triggers automatic file save, reloaded wallet balance and lifetime earnings match exactly, and processed transaction IDs persist without data loss."
	related_sources = [
		"res://scripts/economy/economy_save_system.gd",
		"res://scripts/economy/household_wallet.gd",
		"res://scripts/room.gd",
		"res://scripts/interactable.gd"
	]
	reproduction_steps = [
		"1. Position player in yard at (-45, 0, 72).",
		"2. Simulate daily business revenue deposit (+75,000đ) into shared household wallet.",
		"3. Walk player through front yard into house interior (Z > 83).",
		"4. Interact with Bed: assert player resting pose and automatic save to disk.",
		"5. Wake up from bed via second interaction.",
		"6. Reload save file into fresh wallet and inventory instances.",
		"7. Assert reloaded balance, total earned, and transaction cache match perfectly."
	]
	
	recorder.start_recording("TC10_return_home_persistence")
	
	var test_save_path := "user://test_tc10_persistence.json"
	if FileAccess.file_exists(test_save_path):
		DirAccess.remove_absolute(test_save_path)
	
	player.global_position = Vector3(-45.0, 0, 72.0)
	player.select_character("boy")
	await wait_and_record(6)
	
	var world = game_manager.get_node_or_null("Neighborhood")
	var econ: EconomyManager = world.economy_manager
	var room: Room = game_manager.get_node_or_null("Room")
	econ.save_file_path = test_save_path
	econ.house_manager = room
	
	# Simulate completed workday revenue
	econ.wallet.deposit(75000, "workday_revenue", "Thu nhập cả ngày", "tc10_day_revenue")
	var expected_balance = econ.wallet.balance
	var expected_earned = econ.wallet.total_earned
	await wait_and_record(6)
	
	# 1. Walk through front yard towards house door
	var door: Interactable = room.current_door if room else null
	if door and not door.toggle:
		door.interact(player)
	
	await simulate_walk(Vector3(-45.0, 0, 83.5), 2.8)
	await wait_and_record(6)
	
	# 2. Enter house interior
	await simulate_walk(Vector3(-45.0, 0, 88.0), 2.5)
	await wait_and_record(8)
	check(player.global_position.z > 83.0, "Player entered house interior")
	
	# 3. Rest in bed to trigger automatic progression save
	var bed: Interactable = room.current_bed if room else null
	check(is_instance_valid(bed), "Bed interactable exists")
	bed.interact(player)
	await wait_and_record(15)
	
	check(player.resting != null, "Player is resting in bed")
	check(FileAccess.file_exists(test_save_path), "Progression saved to disk automatically upon resting")
	
	# Wake up
	bed.interact(player)
	await wait_and_record(8)
	check(player.resting == null, "Player woke up refreshed")
	
	# 4. Simulate reload from save file
	var test_wallet = HouseholdWallet.new()
	var test_inv = InventoryManager.new()
	var b_data = EconomySaveSystem.load_economy(test_wallet, test_inv, test_save_path)
	
	check(test_wallet.balance == expected_balance, "Persisted balance matches after reload (%d đ)" % test_wallet.balance)
	check(test_wallet.total_earned == expected_earned, "Persisted earnings match after reload (%d đ)" % test_wallet.total_earned)
	check(test_wallet.processed_transaction_ids.has("tc10_day_revenue"), "Transaction history and idempotency cache preserved")
	
	# Clean up test save file
	if FileAccess.file_exists(test_save_path):
		DirAccess.remove_absolute(test_save_path)
	
	notes = "Verified returning home, bed rest interaction, automatic state save, and exact reload of wallet/earnings."
	var gif_path = recorder.stop_recording_and_export_gif(30)
	return build_result(gif_path)
