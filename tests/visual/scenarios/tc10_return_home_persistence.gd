extends "res://tests/visual/scenarios/scenario_base.gd"

func run_scenario() -> Dictionary:
	print("--- Running TC10: Return Home & Persistence ---")
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
	await simulate_walk(Vector3(-45.0, 0, 83.5), 2.0)
	await wait_and_record(6)
	
	# 2. Enter house interior
	await simulate_walk(Vector3(-45.0, 0, 89.0), 1.5)
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
	
	var gif_path = recorder.stop_recording_and_export_gif(12)
	return {
		"id": "TC10",
		"title": "Return Home & Persistence",
		"status": "PASS" if not failed else "FAIL",
		"gif_path": gif_path,
		"assertions": assertions,
		"notes": "Verified returning home, bed rest interaction, automatic state save, and exact reload of wallet/earnings."
	}
