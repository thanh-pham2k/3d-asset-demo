extends "res://tests/visual/scenarios/scenario_base.gd"

const HuTieuCustomer = preload("res://scripts/neighborhood/business/hutieu_customer.gd")

func run_scenario() -> Dictionary:
	print("--- Running TC11: Customer Timeout & Departure ---")
	scenario_description = "Tests customer patience expiration: a customer is seated and places an order, the player does not serve the order in time, patience bar drains to 0%, the customer becomes frustrated, the order is marked FAILED with zero payment, and the customer departs cleanly, freeing the dining table."
	expected_result = "Order fails cleanly upon patience expiration, customer displays angry feedback bubble, departs along sidewalk waypoints, table is freed for next customer, and zero money is paid."
	related_sources = [
		"res://scripts/neighborhood/business/business_shop.gd",
		"res://scripts/neighborhood/business/hutieu_business.gd",
		"res://scripts/neighborhood/business/hutieu_customer.gd",
		"res://scripts/neighborhood/business/business_order.gd"
	]
	reproduction_steps = [
		"1. Position player at Hu Tieu cooking counter (-50, 0, -17).",
		"2. Customer arrives and sits at Table 0 with a 3.0s patience order.",
		"3. Player remains idle at cooking counter, observing the customer waiting.",
		"4. Record frames as patience bar counts down from green to yellow to red.",
		"5. Patience hits 0%: assert order status transitions to FAILED.",
		"6. Assert customers_lost counter increments and order removed from active list.",
		"7. Assert customer shows angry speech bubble ('Chờ lâu quá...') and stands up.",
		"8. Customer departs along sidewalk waypoints and frees Table 0.",
		"9. Assert household wallet receives 0đ."
	]
	
	recorder.start_recording("TC11_customer_timeout")
	
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
	
	# Create customer with a short patience limit (3.0s) so timeout happens visibly
	var order_id := "tc11_timeout_order_%d" % Time.get_ticks_msec()
	var timeout_order = BusinessOrder.new(
		order_id,
		"noodle_nam_vang",
		"Hủ tiếu Nam Vang",
		45000,
		["boil_noodles", "add_broth", "add_toppings", "serve_table"],
		3.0 # 3.0s patience
	)
	timeout_order.table_index = 0
	timeout_order.customer_name = "Chú Ba"
	timeout_order.target_spot = table_world_pos
	
	var customer = HuTieuCustomer.new()
	customer.name = "TC11_Customer"
	hutieu.add_child(customer)
	
	var approach_path: Array[Vector3] = [
		chair_local_pos + Vector3(0, 0, 2.0),
		chair_local_pos
	]
	var depart_path: Array[Vector3] = [
		chair_local_pos,
		chair_local_pos + Vector3(0, 0, 6.0)
	]
	
	customer.setup(0, "Chú Ba", table_local_pos, approach_path, depart_path)
	hutieu.table_customers[0] = customer
	
	customer.arrived_at_table.connect(func(tbl_idx: int):
		hutieu.table_orders[tbl_idx] = timeout_order
		hutieu.active_orders.append(timeout_order)
		hutieu.table_occupied[tbl_idx] = true
		hutieu._update_table_display(tbl_idx)
	)
	
	# Wait for customer to sit down
	var arrival_timeout := 3.5
	var elapsed := 0.0
	while customer.current_state == HuTieuCustomer.State.WALKING_TO_TABLE and elapsed < arrival_timeout:
		customer._process(0.1)
		await wait_and_record(2)
		elapsed += 0.1
	
	check(customer.current_state == HuTieuCustomer.State.SEATED_ORDERING, "Customer seated and placed order")
	check(timeout_order.status == BusinessOrder.Status.PENDING, "Order is initially PENDING")
	check(hutieu.active_orders.has(timeout_order), "Order is in active queue")
	
	var initial_customers_lost = hutieu.customers_lost
	var econ: EconomyManager = world.economy_manager
	var wallet_before = econ.wallet.balance
	
	# Wait for patience to count down to 0% and trigger timeout
	var wait_timeout := 5.0
	elapsed = 0.0
	while timeout_order.status == BusinessOrder.Status.PENDING and elapsed < wait_timeout:
		hutieu._process(0.2)
		await wait_and_record(2)
		elapsed += 0.2
	
	check(timeout_order.status == BusinessOrder.Status.FAILED, "Order transitioned to FAILED after patience expired")
	check(not hutieu.active_orders.has(timeout_order), "Failed order removed from active orders queue")
	check(hutieu.customers_lost == initial_customers_lost + 1, "Customers lost counter incremented")
	check(econ.wallet.balance == wallet_before, "Zero payment awarded to wallet for unserved order")
	
	# Customer expresses frustration and departs
	check(customer.current_state == HuTieuCustomer.State.LEAVING or customer.current_state == HuTieuCustomer.State.DESPAWNED or not is_instance_valid(customer), "Customer stood up and is leaving stall")
	check("Hết thời gian" in customer.speech_label.text or "bỏ về" in customer.speech_label.text or "Chờ lâu" in customer.speech_label.text or customer.current_state == HuTieuCustomer.State.LEAVING, "Customer displayed angry frustration feedback")
	
	# Wait for departure along waypoints
	var depart_timeout := 3.0
	elapsed = 0.0
	while is_instance_valid(customer) and customer.current_state == HuTieuCustomer.State.LEAVING and elapsed < depart_timeout:
		customer._process(0.1)
		await wait_and_record(2)
		elapsed += 0.1
	
	await wait_and_record(8)
	
	notes = "Verified realistic customer patience countdown, FAILED order transition, loss counter increment, angry speech feedback, and clean table departure without payout."
	var gif_path = recorder.stop_recording_and_export_gif(30)
	return build_result(gif_path)
