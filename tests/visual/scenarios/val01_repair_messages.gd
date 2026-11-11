extends "res://tests/visual/scenarios/scenario_base.gd"

const MotorcycleCustomer = preload("res://scripts/neighborhood/business/motorcycle_customer.gd")
const GarageBusiness = preload("res://scripts/neighborhood/business/garage_business.gd")
const BusinessOrder = preload("res://scripts/neighborhood/business/business_order.gd")
const EconomyManager = preload("res://scripts/economy/economy_manager.gd")

func run_scenario() -> Dictionary:
	print("--- Running TC01: Motorcycle Repair Messages ---")
	recorder.start_recording("TC01_repair_messages")
	
	player.global_position = Vector3(-60.0, 0, -14.0)
	player.select_character("boy")
	await wait_and_record(6)
	
	var world = game_manager.get_node_or_null("Neighborhood")
	var garage: GarageBusiness = world.get_node_or_null("GarageBusiness") if world else null
	check(is_instance_valid(garage), "GarageBusiness exists")
	
	garage.is_open = true
	
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
	
	var order_id := "tc01_order_%d" % Time.get_ticks_msec()
	var cust_order = BusinessOrder.new(order_id, "patch", "Vá săm xe", 35000, ["patch_kit", "pump_air"], 60.0)
	cust_order.table_index = 0
	cust_order.customer_name = "Anh Tuấn"
	cust_order.target_spot = bay_world
	
	var customer = MotorcycleCustomer.new()
	customer.name = "TC01_Customer"
	garage.add_child(customer)
	customer.setup(0, "Anh Tuấn", bay_local, approach_path, depart_path)
	customer.order = cust_order
	garage.bay_customers[0] = customer
	
	customer.arrived_at_bay.connect(func(bay_idx: int):
		garage.bay_orders[bay_idx] = cust_order
		garage.active_orders.append(cust_order)
		garage._update_bay_display(bay_idx)
	)
	
	# Customer arrives at bay
	customer._on_arrived_at_bay()
	await wait_and_record(8)
	
	var bay0_station = garage.get_node_or_null("BikeBay_0")
	check(is_instance_valid(bay0_station), "BikeBay_0 exists")
	
	# 1. Focus camera on bay interaction area
	var cam: Camera3D = game_manager.main_camera
	if is_instance_valid(cam):
		cam.global_position = bay_world + Vector3(3.2, 2.5, 4.0)
		cam.look_at(bay_world + Vector3(0, 1.0, 0))
	
	# 2. Boy approaches Bay 0 empty-handed
	await simulate_walk(bay_world + Vector3(1.2, 0, 0), 1.5)
	await wait_and_record(8)
	
	var prompt_empty: String = bay0_station.prompt(player)
	print("  Prompt empty-handed: '%s'" % prompt_empty)
	check(prompt_empty.find("Cần lấy bộ vá săm ở Bàn Thợ trước!") != -1, "Prompt guides player: 'Cần lấy bộ vá săm ở Bàn Thợ trước!'")
	check(customer.speech_label.position.y > garage.bay_status_labels[0].position.y, "Speech label sits above bay label (no overlapping text)")
	
	# 3. Boy walks to WorkbenchStation and interacts
	var bench_station = garage.get_node_or_null("WorkbenchStation")
	check(is_instance_valid(bench_station), "WorkbenchStation exists")
	var bench_world = garage.to_global(bench_station.position)
	await simulate_walk(bench_world + Vector3(0, 0, 1.2), 1.5)
	await wait_and_record(6)
	
	var bench_prompt: String = bench_station.prompt(player)
	print("  Workbench prompt: '%s'" % bench_prompt)
	check(bench_prompt.find("Lấy bộ vá săm") != -1, "Workbench prompts: 'Lấy bộ vá săm & keo dán'")
	
	bench_station.interact(player)
	await wait_and_record(6)
	check(garage.get_holding_tool(player) == "patch_kit", "Boy picked up patch kit from workbench via physical interaction")
	
	# 4. Boy walks back to Bay 0 with patch kit
	await simulate_walk(bay_world + Vector3(1.2, 0, 0), 1.5)
	await wait_and_record(6)
	
	var prompt_with_tool: String = bay0_station.prompt(player)
	print("  Prompt with patch kit: '%s'" % prompt_with_tool)
	check(prompt_with_tool.find("Dán miếng vá săm (Khoang 1)") != -1, "Prompt with patch kit: 'Dán miếng vá săm (Khoang 1)'")
	
	# 5. Boy interacts [E] to apply patch kit
	bay0_station.interact(player)
	await wait_and_record(8)
	check(cust_order.get_current_required_step() == "pump_air", "Patch kit applied through station interaction; next step is pump_air")
	check(garage.get_holding_tool(player) == "", "Patch kit consumed from player inventory")
	
	var prompt_pump: String = bay0_station.prompt(player)
	print("  Prompt after patch: '%s'" % prompt_pump)
	check(prompt_pump.find("Bơm") != -1, "Prompt guides next step: 'Bơm lốp xe (Khoang 1)'")
	
	# 6. Boy interacts with Bay 0 again to pump air and complete repair
	var econ: EconomyManager = world.economy_manager
	var wallet_before = econ.wallet.balance
	
	bay0_station.interact(player)
	await wait_and_record(10)
	
	check(cust_order.status == BusinessOrder.Status.PAID, "Order status marked PAID")
	check(econ.wallet.balance == wallet_before + 35000, "Household wallet received +35,000đ")
	check(customer.current_state == MotorcycleCustomer.State.SERVICE_COMPLETED or customer.current_state == MotorcycleCustomer.State.DEPARTING, "Customer celebrates completed service")
	
	# Customer rides away
	await wait_and_record(12)
	customer._process_service_completed(1.0)
	await wait_and_record(10)
	
	var gif_path = recorder.stop_recording_and_export_gif(30)
	return {
		"id": "TC01",
		"title": "Motorcycle Repair Messages",
		"status": "PASS" if not failed else "FAIL",
		"gif_path": gif_path,
		"assertions": assertions,
		"notes": "Verified clear guidance when empty-handed, workbench tool pickup, next action prompts, and non-overlapping labels."
	}
