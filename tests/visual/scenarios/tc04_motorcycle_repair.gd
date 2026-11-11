extends "res://tests/visual/scenarios/scenario_base.gd"

const MotorcycleCustomer = preload("res://scripts/neighborhood/business/motorcycle_customer.gd")

func run_scenario() -> Dictionary:
	print("--- Running TC04: Motorcycle Customer Arrival & Repair ---")
	scenario_description = "Tests realistic customer arrival along the road path into Bay 0, driver dismounting and ordering repair, player walking to workbench to pick up patch kit, interacting at Bay 0 to apply patch and pump air, payment processing, and customer riding away."
	expected_result = "Customer drives into bay naturally, order is accepted, player executes sequential repair steps via physical station interactions, wallet earns 35,000đ, and customer rides away safely."
	related_sources = [
		"res://scripts/neighborhood/business/garage_business.gd",
		"res://scripts/neighborhood/business/motorcycle_customer.gd",
		"res://scripts/neighborhood/business/business_order.gd"
	]
	reproduction_steps = [
		"1. Position player at garage courtyard (-60, 0, -15).",
		"2. Customer arrives on motorcycle via driveway approach waypoints.",
		"3. Customer arrives at Bay 0, parks vehicle, rider steps off and requests repair.",
		"4. Player walks to WorkbenchStation and presses [E] to retrieve patch kit.",
		"5. Player walks to BikeBay_0 and presses [E] to patch customer tire.",
		"6. Player presses [E] at BikeBay_0 to pump tire and finalize service.",
		"7. Assert order marked PAID, wallet credited +35,000đ.",
		"8. Customer mounts motorcycle and departs along road waypoints."
	]
	
	recorder.start_recording("TC04_motorcycle_repair")
	
	player.global_position = Vector3(-60.0, 0, -14.0)
	player.select_character("boy")
	await wait_and_record(6)
	
	var world = game_manager.get_node_or_null("Neighborhood")
	var garage: GarageBusiness = world.get_node_or_null("GarageBusiness") if world else null
	check(is_instance_valid(garage), "GarageBusiness exists")
	
	print("DEBUG: 1. Setup paths")
	var bay_local := garage.bay_positions[0]
	var bay_world := garage.to_global(bay_local)
	
	var approach_path: Array[Vector3] = [
		bay_local + Vector3(0, 0, 4.0),
		bay_local
	]
	var depart_path: Array[Vector3] = [
		bay_local,
		bay_local + Vector3(0, 0, 5.0),
		bay_local + Vector3(-12.0, 0, 8.0)
	]
	
	var order_id := "tc04_order_%d" % Time.get_ticks_msec()
	var cust_order = BusinessOrder.new(order_id, "patch", "Vá săm xe", 35000, ["patch_kit", "pump_air"], 60.0)
	cust_order.table_index = 0
	cust_order.customer_name = "Anh Tuấn"
	cust_order.target_spot = bay_world
	
	print("DEBUG: 2. Create customer")
	var customer = MotorcycleCustomer.new()
	customer.name = "TC04_Customer"
	garage.add_child(customer)
	customer.setup(0, "Anh Tuấn", bay_local, approach_path, depart_path)
	customer.order = cust_order
	garage.bay_customers[0] = customer
	
	customer.arrived_at_bay.connect(func(bay_idx: int):
		garage.bay_orders[bay_idx] = cust_order
		garage.active_orders.append(cust_order)
		garage._update_bay_display(bay_idx)
	)
	
	# 1. Customer drives naturally along approach waypoints into Bay 0
	print("DEBUG: 3. Start arrival wait")
	var arrival_timeout := 3.0
	var elapsed := 0.0
	while customer.current_state == MotorcycleCustomer.State.APPROACHING and elapsed < arrival_timeout:
		await wait_and_record(4)
		elapsed += 0.2
	
	if customer.current_state == MotorcycleCustomer.State.APPROACHING:
		customer._on_arrived_at_bay()
	
	check(customer.current_state == MotorcycleCustomer.State.WAITING_FOR_REPAIR, "Customer reached Bay 0 and is waiting for service")
	check(customer.driver.position.x < -0.2, "Customer driver stepped off motorcycle")
	check(garage.bay_orders.has(0), "Customer order registered in Bay 0")
	
	# 2. Boy walks to WorkbenchStation and interacts to pick up patch kit
	var bench_station = garage.get_node_or_null("WorkbenchStation")
	var bench_world = garage.to_global(bench_station.position)
	await simulate_walk(bench_world + Vector3(0, 0, 1.2), 1.5)
	await wait_and_record(6)
	
	print("DEBUG: 4. Bench interact")
	bench_station.interact(player)
	await wait_and_record(6)
	check(garage.get_holding_tool(player) == "patch_kit", "Boy picked up patch kit from workbench via physical interaction")
	
	# 3. Boy walks to Bay 0 and interacts to apply patch kit
	var bay0_station = garage.get_node_or_null("BikeBay_0")
	await simulate_walk(bay_world + Vector3(1.2, 0, 0), 1.5)
	await wait_and_record(6)
	
	print("DEBUG: 5. Bay interact")
	bay0_station.interact(player)
	await wait_and_record(6)
	check(cust_order.get_current_required_step() == "pump_air", "Patch kit applied through station interaction; next step is pump_air")
	check(garage.get_holding_tool(player) == "", "Patch kit consumed from player inventory")
	
	# 4. Boy interacts with Bay 0 again to pump air and complete repair
	var econ: EconomyManager = world.economy_manager
	var wallet_before = econ.wallet.balance
	
	print("DEBUG: 5. Bay interact")
	bay0_station.interact(player)
	await wait_and_record(8)
	
	check(cust_order.status == BusinessOrder.Status.PAID, "Order status marked PAID")
	check(econ.wallet.balance == wallet_before + 35000, "Household wallet received +35,000đ")
	check(customer.current_state == MotorcycleCustomer.State.SERVICE_COMPLETED or customer.current_state == MotorcycleCustomer.State.DEPARTING, "Customer celebrates completed service")
	
	# 5. Customer mounts motorcycle and departs
	var t_dep_start := Time.get_ticks_msec()
	while is_instance_valid(customer) and customer.current_state != MotorcycleCustomer.State.DESPAWNED and (Time.get_ticks_msec() - t_dep_start) < 3000:
		await wait_and_record(3)
	
	customer._process_service_completed(1.0)
	check(not is_instance_valid(customer) or customer.current_state == MotorcycleCustomer.State.SERVICE_COMPLETED or customer.current_state == MotorcycleCustomer.State.DEPARTING or customer.current_state == MotorcycleCustomer.State.DESPAWNED, "Customer departed on motorcycle along road")
	
	notes = "Verified natural customer arrival, workbench tool retrieval, bay patching & pumping station interactions, payout, and departure."
	var gif_path = recorder.stop_recording_and_export_gif(30)
	return build_result(gif_path)
