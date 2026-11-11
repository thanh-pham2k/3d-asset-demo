extends "res://tests/visual/scenarios/scenario_base.gd"

func run_scenario() -> Dictionary:
	print("--- Running TC07: Incorrect Order Rejection ---")
	recorder.start_recording("TC07_incorrect_order")
	
	player.global_position = Vector3(-50.0, 0, -17.0)
	player.select_character("girl")
	await wait_and_record(6)
	
	var world = game_manager.get_node_or_null("Neighborhood")
	var hutieu: HuTieuBusiness = world.get_node_or_null("03_HuTieu/HuTieuBusiness") if world else null
	if not hutieu and world:
		hutieu = world.get_node_or_null("HuTieuBusiness")
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
	await wait_and_record(15)
	
	check(order.status == BusinessOrder.Status.PENDING, "Order REJECTED and remains PENDING")
	check(econ.wallet.balance == wallet_before, "Zero reward granted for incorrect dish")
	check(hutieu.current_bowl_state == HuTieuBusiness.BowlState.FULLY_PREPARED, "Kitchen bowl was not consumed")
	
	# 3. Discard wrong bowl at blanch pot
	await simulate_walk(hutieu.global_position + Vector3(-51.8, 0, -16.0), 1.2)
	blanch.interact(player)
	await wait_and_record(12)
	
	check(hutieu.current_bowl_state == HuTieuBusiness.BowlState.EMPTY, "Wrong bowl safely discarded to allow remaking")
	check(hutieu.current_bowl_dish == "", "Bowl dish cleared")
	
	var gif_path = recorder.stop_recording_and_export_gif(12)
	return {
		"id": "TC07",
		"title": "Incorrect Order",
		"status": "PASS" if not failed else "FAIL",
		"gif_path": gif_path,
		"assertions": assertions,
		"notes": "Verified dish validation rejecting incorrect food, zero payment, and bowl discard capability."
	}
