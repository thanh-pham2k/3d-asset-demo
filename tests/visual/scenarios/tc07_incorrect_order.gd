extends "res://tests/visual/scenarios/scenario_base.gd"

func run_scenario() -> Dictionary:
	print("--- Running TC07: Incorrect Order Rejection & Discard ---")
	scenario_description = "Tests order validation rejecting mismatched food orders: customer orders Nam Vang noodles, player prepares Pork Rib noodles instead, attempts to serve at dining table (rejected, 0đ reward, bowl preserved), and player discards wrong bowl at blanching pot."
	expected_result = "Serving wrong dish is rejected with zero financial reward, customer order remains pending, and wrong bowl can be discarded cleanly to remake."
	related_sources = [
		"res://scripts/neighborhood/business/hutieu_business.gd",
		"res://scripts/neighborhood/business/business_order.gd"
	]
	reproduction_steps = [
		"1. Position player at Hu Tieu stall (-50, 0, -17).",
		"2. Customer at Table 0 orders 'Hủ tiếu Nam Vang'.",
		"3. Player intentionally prepares 'Hủ tiếu sườn heo' at cooking counter.",
		"4. Walk to Table 0 and press [E] to attempt serving incorrect dish.",
		"5. Assert order is REJECTED, remains PENDING, and wallet receives 0đ.",
		"6. Assert kitchen bowl is preserved and not consumed.",
		"7. Walk to BlanchingStation and press [E] to discard incorrect bowl.",
		"8. Assert bowl state is reset to EMPTY."
	]
	
	recorder.start_recording("TC07_incorrect_order")
	
	player.global_position = Vector3(-50.0, 0, -17.0)
	player.select_character("girl")
	await wait_and_record(6)
	
	var world = game_manager.get_node_or_null("Neighborhood")
	var hutieu: HuTieuBusiness = world.get_node_or_null("HuTieuBusiness") if world else null
	check(is_instance_valid(hutieu), "HuTieuBusiness exists")
	
	# Customer orders Hủ tiếu Nam Vang
	var order_id := "tc07_order_%d" % Time.get_ticks_msec()
	var order = BusinessOrder.new(order_id, "noodle_nam_vang", "Hủ tiếu Nam Vang", 45000, ["boil_noodles", "add_broth", "add_toppings", "serve_table"], 60.0)
	order.table_index = 0
	order.customer_name = "Cô Mai"
	hutieu.table_orders[0] = order
	hutieu.active_orders.append(order)
	await wait_and_record(6)
	
	# 1. Girl cooks incorrect dish: "Hủ tiếu sườn heo"
	var blanch = hutieu.get_node_or_null("BlanchingStation")
	var broth = hutieu.get_node_or_null("BrothStation")
	var topping = hutieu.get_node_or_null("ToppingsStation")
	
	hutieu.current_bowl_state = HuTieuBusiness.BowlState.EMPTY
	blanch.interact(player)
	hutieu.blanch_timer = 0.0
	hutieu._process(0.1)
	broth.interact(player)
	
	hutieu.set_recipe_by_title("Hủ tiếu sườn heo")
	topping.interact(player)
	await wait_and_record(8)
	
	check(hutieu.current_bowl_state == HuTieuBusiness.BowlState.FULLY_PREPARED, "Bowl prepared")
	check(hutieu.current_bowl_dish == "Hủ tiếu sườn heo", "Prepared dish is 'Hủ tiếu sườn heo'")
	check(order.service_title == "Hủ tiếu Nam Vang", "Customer ordered different dish 'Hủ tiếu Nam Vang'")
	
	# 2. Attempt to serve incorrect dish at Table 0
	var table0 = hutieu.get_node_or_null("DiningTable_0")
	var econ: EconomyManager = world.economy_manager
	var wallet_before = econ.wallet.balance
	
	table0.interact(player)
	await wait_and_record(12)
	
	check(order.status == BusinessOrder.Status.PENDING, "Order REJECTED and remains PENDING")
	check(econ.wallet.balance == wallet_before, "Zero reward granted for incorrect dish")
	check(hutieu.current_bowl_state == HuTieuBusiness.BowlState.FULLY_PREPARED, "Kitchen bowl was not consumed")
	
	# 3. Discard wrong bowl at blanch pot
	await simulate_walk(hutieu.global_position + blanch.position + Vector3(0, 0, 1.0), 1.2)
	blanch.interact(player)
	await wait_and_record(10)
	
	check(hutieu.current_bowl_state == HuTieuBusiness.BowlState.EMPTY, "Wrong bowl safely discarded to allow remaking")
	check(hutieu.current_bowl_dish == "", "Bowl dish cleared")
	
	notes = "Verified dish validation rejecting incorrect food, zero payment, and bowl discard capability."
	var gif_path = recorder.stop_recording_and_export_gif(30)
	return build_result(gif_path)
