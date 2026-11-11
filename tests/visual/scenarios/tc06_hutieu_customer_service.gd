extends "res://tests/visual/scenarios/scenario_base.gd"

const HuTieuCustomer = preload("res://scripts/neighborhood/business/hutieu_customer.gd")

func run_scenario() -> Dictionary:
	print("--- Running TC06: Hu Tieu Customer Service ---")
	scenario_description = "Tests complete dining service cycle: customer arriving and seating at Table 0, placing order, player sequentially cooking dish (blanching noodles naturally, ladling broth, garnishing toppings), serving food to table, payment processing, eating, and customer departure."
	expected_result = "Customer seats naturally, player cooks complete dish through physical kitchen stations, customer receives food, wallet earns 45,000đ, and customer departs cleanly."
	related_sources = [
		"res://scripts/neighborhood/business/hutieu_business.gd",
		"res://scripts/neighborhood/business/hutieu_customer.gd",
		"res://scripts/neighborhood/business/business_order.gd"
	]
	reproduction_steps = [
		"1. Position player at Hu Tieu kitchen (-50, 0, -17).",
		"2. Customer approaches from sidewalk and sits at Table 0: assert order placed for Hủ tiếu Nam Vang.",
		"3. Walk to BlanchingStation and press [E]: wait for blanch timer (1.6s) to cook noodles naturally.",
		"4. Walk to BrothStation and press [E] to ladle broth.",
		"5. Walk to ToppingsStation, select Nam Vang recipe, and press [E] to assemble dish.",
		"6. Walk to Table 0 and press [E] to serve food: assert order marked PAID and +45,000đ credited.",
		"7. Customer enters EATING state with visible noodle bowl.",
		"8. Customer finishes meal and departs along sidewalk waypoints."
	]
	
	recorder.start_recording("TC06_hutieu_customer_service")
	
	player.global_position = Vector3(-50.0, 0, -17.0)
	player.select_character("girl")
	await wait_and_record(6)
	
	var world = game_manager.get_node_or_null("Neighborhood")
	var hutieu: HuTieuBusiness = world.get_node_or_null("HuTieuBusiness") if world else null
	check(is_instance_valid(hutieu), "HuTieuBusiness exists")
	
	hutieu.prep_state = HuTieuBusiness.PrepState.OPEN
	hutieu.is_open = true
	
	var table_local_pos: Vector3 = hutieu.table_positions[0]
	var chair_local_pos: Vector3 = table_local_pos + Vector3(-0.95, 0, 0)
	var table_world_pos: Vector3 = hutieu.global_position + table_local_pos
	
	# 1. Customer arrives and walks to Table 0
	var order_id := "tc06_order_%d" % Time.get_ticks_msec()
	var order = BusinessOrder.new(order_id, "noodle_nam_vang", "Hủ tiếu Nam Vang", 45000, ["boil_noodles", "add_broth", "add_toppings", "serve_table"], 60.0)
	order.table_index = 0
	order.customer_name = "Bác Năm"
	order.target_spot = table_world_pos
	
	var customer = HuTieuCustomer.new()
	customer.name = "TC06_Customer"
	hutieu.add_child(customer)
	
	var approach_path: Array[Vector3] = [
		chair_local_pos + Vector3(0, 0, 4.0),
		chair_local_pos
	]
	var depart_path: Array[Vector3] = [
		chair_local_pos,
		chair_local_pos + Vector3(0, 0, 6.0)
	]
	
	customer.setup(0, "Bác Năm", table_local_pos, approach_path, depart_path)
	hutieu.table_customers[0] = customer
	
	customer.arrived_at_table.connect(func(tbl_idx: int):
		hutieu.table_orders[tbl_idx] = order
		hutieu.active_orders.append(order)
		hutieu._update_table_display(tbl_idx)
	)
	
	# Wait for customer to walk to table naturally
	var arrival_timeout := 4.0
	var elapsed := 0.0
	while customer.current_state == HuTieuCustomer.State.WALKING_TO_TABLE and elapsed < arrival_timeout:
		customer._process(0.1)
		await wait_and_record(2)
		elapsed += 0.1
	
	check(customer.current_state == HuTieuCustomer.State.SEATED_ORDERING, "Customer is seated on chair")
	check(hutieu.table_orders.has(0), "Customer placed order for 'Hủ tiếu Nam Vang'")
	
	# 2. Girl cooks dish: Blanch noodles
	var blanch = hutieu.get_node_or_null("BlanchingStation")
	await simulate_walk(hutieu.global_position + blanch.position + Vector3(0, 0, 1.0), 1.2)
	blanch.interact(player)
	await wait_and_record(4)
	check(hutieu.current_bowl_state == HuTieuBusiness.BowlState.BLANCHING, "Bowl in blanching strainer")
	
	# Wait for natural blanch timer (1.6s)
	var blanch_timeout := 3.0
	elapsed = 0.0
	while hutieu.current_bowl_state == HuTieuBusiness.BowlState.BLANCHING and elapsed < blanch_timeout:
		hutieu._process(0.1)
		await wait_and_record(2)
		elapsed += 0.1
	
	check(hutieu.current_bowl_state == HuTieuBusiness.BowlState.NOODLES_DONE, "Noodles cooked to perfection naturally")
	
	# 3. Ladle bone broth
	var broth = hutieu.get_node_or_null("BrothStation")
	await simulate_walk(hutieu.global_position + broth.position + Vector3(0, 0, 1.0), 1.0)
	broth.interact(player)
	await wait_and_record(6)
	check(hutieu.current_bowl_state == HuTieuBusiness.BowlState.BROTH_ADDED, "Hot bone broth ladled into bowl")
	
	# 4. Add Nam Vang toppings
	var topping = hutieu.get_node_or_null("ToppingsStation")
	await simulate_walk(hutieu.global_position + topping.position + Vector3(0, 0, 1.0), 1.0)
	hutieu.set_recipe_by_title("Hủ tiếu Nam Vang")
	topping.interact(player)
	await wait_and_record(6)
	check(hutieu.current_bowl_state == HuTieuBusiness.BowlState.FULLY_PREPARED, "Bowl fully prepared")
	check(hutieu.current_bowl_dish == "Hủ tiếu Nam Vang", "Prepared dish is 'Hủ tiếu Nam Vang'")
	
	# 5. Serve customer at Table 0
	var table0 = hutieu.get_node_or_null("DiningTable_0")
	await simulate_walk(table_world_pos + Vector3(1.2, 0, 0), 1.4)
	var econ: EconomyManager = world.economy_manager
	var wallet_before = econ.wallet.balance
	table0.interact(player)
	await wait_and_record(10)
	
	check(order.status == BusinessOrder.Status.PAID, "Order marked PAID")
	check(econ.wallet.balance == wallet_before + 45000, "Shared wallet credited +45,000đ")
	check(customer.current_state == HuTieuCustomer.State.EATING, "Customer is eating served food")
	check(customer.eating_bowl.visible, "Hot noodle bowl visible on dining table")
	
	# 6. Customer finishes meal and leaves
	var eat_timeout := 3.5
	elapsed = 0.0
	while customer.current_state == HuTieuCustomer.State.EATING and elapsed < eat_timeout:
		customer._process(0.1)
		await wait_and_record(2)
		elapsed += 0.1
	
	check(customer.current_state == HuTieuCustomer.State.LEAVING or customer.current_state == HuTieuCustomer.State.DESPAWNED or not is_instance_valid(customer), "Customer finished meal and departed along sidewalk")
	
	notes = "Verified customer seating, realistic sequential cooking (natural blanch, broth, toppings), table serving, payment, and departure."
	var gif_path = recorder.stop_recording_and_export_gif(30)
	return build_result(gif_path)
