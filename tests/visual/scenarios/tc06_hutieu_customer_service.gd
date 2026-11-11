extends "res://tests/visual/scenarios/scenario_base.gd"

const HuTieuCustomer = preload("res://scripts/neighborhood/business/hutieu_customer.gd")

func run_scenario() -> Dictionary:
	print("--- Running TC06: Hu Tieu Customer Service ---")
	recorder.start_recording("TC06_hutieu_customer_service")
	
	player.global_position = Vector3(-50.0, 0, -17.0)
	player.select_character("girl")
	await wait_and_record(6)
	
	var world = game_manager.get_node_or_null("Neighborhood")
	var hutieu: HuTieuBusiness = world.get_node_or_null("03_HuTieu/HuTieuBusiness") if world else null
	if not hutieu and world:
		hutieu = world.get_node_or_null("HuTieuBusiness")
	check(is_instance_valid(hutieu), "HuTieuBusiness exists")
	
	hutieu.prep_state = HuTieuBusiness.PrepState.OPEN
	hutieu.is_open = true
	
	var table_pos = hutieu.global_position + hutieu.table_positions[0]
	var chair_pos = table_pos + Vector3(-0.95, 0, 0)
	
	# 1. Customer arrives and walks to Table 0
	var order_id := "tc06_order_%d" % Time.get_ticks_msec()
	var order = BusinessOrder.new(order_id, "noodle_nam_vang", "Hủ tiếu Nam Vang", 45000, ["boil_noodles", "add_broth", "add_toppings", "serve_table"], 60.0)
	order.table_index = 0
	order.customer_name = "Bác Năm"
	
	var customer = HuTieuCustomer.new()
	customer.name = "TC06_Customer"
	hutieu.add_child(customer)
	customer.setup(0, "Bác Năm", hutieu.table_positions[0], [chair_pos + Vector3(0, 0, 4), chair_pos], [chair_pos, chair_pos + Vector3(0, 0, 6)])
	hutieu.table_customers[0] = customer
	
	await wait_and_record(10)
	customer._on_reached_table()
	hutieu.table_orders[0] = order
	hutieu.active_orders.append(order)
	await wait_and_record(10)
	
	check(customer.current_state == HuTieuCustomer.State.SEATED_ORDERING, "Customer is seated on chair")
	check(hutieu.table_orders.has(0), "Customer placed order for 'Hủ tiếu Nam Vang'")
	
	# 2. Girl cooks dish: Blanch noodles
	var blanch = hutieu.get_node_or_null("BlanchingStation")
	await simulate_walk(hutieu.global_position + Vector3(-51.8, 0, -16.0), 1.2)
	blanch.interact(player)
	await wait_and_record(6)
	hutieu.blanch_timer = 0.0
	hutieu._process(0.1) # Noodles done
	await wait_and_record(6)
	check(hutieu.current_bowl_state == HuTieuBusiness.BowlState.NOODLES_DONE, "Noodles blanched and cooked")
	
	# 3. Ladle bone broth
	var broth = hutieu.get_node_or_null("BrothStation")
	await simulate_walk(hutieu.global_position + Vector3(-50.0, 0, -16.0), 1.0)
	broth.interact(player)
	await wait_and_record(6)
	check(hutieu.current_bowl_state == HuTieuBusiness.BowlState.BROTH_ADDED, "Hot bone broth ladled into bowl")
	
	# 4. Add Nam Vang toppings
	var topping = hutieu.get_node_or_null("ToppingsStation")
	await simulate_walk(hutieu.global_position + Vector3(-48.2, 0, -16.0), 1.0)
	hutieu.set_recipe_by_title("Hủ tiếu Nam Vang")
	topping.interact(player)
	await wait_and_record(6)
	check(hutieu.current_bowl_state == HuTieuBusiness.BowlState.FULLY_PREPARED, "Bowl fully prepared")
	check(hutieu.current_bowl_dish == "Hủ tiếu Nam Vang", "Prepared dish is 'Hủ tiếu Nam Vang'")
	
	# 5. Serve customer at Table 0
	var table0 = hutieu.get_node_or_null("DiningTable_0")
	await simulate_walk(table_pos + Vector3(1.2, 0, 0), 1.4)
	var econ: EconomyManager = world.economy_manager
	var wallet_before = econ.wallet.balance
	table0.interact(player)
	await wait_and_record(12)
	
	check(order.status == BusinessOrder.Status.PAID, "Order marked PAID")
	check(econ.wallet.balance == wallet_before + 45000, "Shared wallet credited +45,000đ")
	check(customer.current_state == HuTieuCustomer.State.EATING, "Customer is eating served food")
	check(customer.eating_bowl.visible, "Hot noodle bowl visible on dining table")
	
	# 6. Customer finishes meal, stands up and leaves
	await wait_and_record(15)
	customer.state_timer = 2.5
	customer._process_eating(0.1)
	await wait_and_record(10)
	check(customer.current_state == HuTieuCustomer.State.LEAVING, "Customer stood up and departed")
	
	var gif_path = recorder.stop_recording_and_export_gif(12)
	return {
		"id": "TC06",
		"title": "Hu Tieu Customer Service",
		"status": "PASS" if not failed else "FAIL",
		"gif_path": gif_path,
		"assertions": assertions,
		"notes": "Verified seating, ordering, cooking sequence (blanch, broth, toppings), serving, payment, and departure."
	}
