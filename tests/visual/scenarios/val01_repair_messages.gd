extends "res://tests/visual/scenarios/scenario_base.gd"

const MotorcycleCustomer = preload("res://scripts/neighborhood/business/motorcycle_customer.gd")
const GarageBusiness = preload("res://scripts/neighborhood/business/garage_business.gd")
const BusinessOrder = preload("res://scripts/neighborhood/business/business_order.gd")
const EconomyManager = preload("res://scripts/economy/economy_manager.gd")

func run_scenario() -> Dictionary:
	print("--- Running TC01: Motorcycle Repair Messages ---")
	recorder.start_recording("TC01_repair_messages")
	
	player.select_character("boy")
	var world = game_manager.get_node_or_null("Neighborhood")
	var garage: GarageBusiness = world.get_node_or_null("02_MotorcycleRepair/GarageBusiness") if world else null
	if not garage and world:
		garage = world.get_node_or_null("GarageBusiness")
	check(is_instance_valid(garage), "GarageBusiness exists")
	
	# Open garage shop
	garage.is_open = true
	
	# Spawn a customer motorcycle approaching Bay 0
	var bay_pos: Vector3 = garage.to_global(garage.bay_positions[0])
	var depart_path: Array[Vector3] = [
		bay_pos,
		bay_pos + Vector3(0, 0, 5),
		bay_pos + Vector3(-15, 0, 10)
	]
	
	var order_id := "tc01_order_%d" % Time.get_ticks_msec()
	var cust_order = BusinessOrder.new(order_id, "patch", "Vá săm xe máy", 35000, ["patch_kit", "pump_air"], 60.0)
	cust_order.table_index = 0
	
	var customer = MotorcycleCustomer.new()
	customer.name = "TC01_Customer"
	garage.add_child(customer)
	customer.setup(0, "Anh Tuấn", garage.bay_positions[0], [bay_pos + Vector3(0, 0, 4), bay_pos], depart_path)
	customer.order = cust_order
	garage.bay_customers[0] = customer
	
	# Customer arrives at bay
	customer._on_arrived_at_bay()
	garage.bay_orders[0] = cust_order
	garage.active_orders.append(cust_order)
	
	# 1. Focus camera on bay and garage interaction area
	var cam: Camera3D = game_manager.main_camera
	if is_instance_valid(cam):
		cam.global_position = bay_pos + Vector3(4.0, 3.2, 5.0)
		cam.look_at(bay_pos + Vector3(0, 1.2, 0))
	
	# 2. Boy walks towards Bay 0 empty-handed
	player.global_position = bay_pos + Vector3(2.5, 0, 1.8)
	await simulate_walk(bay_pos + Vector3(1.1, 0, 0.4), 1.5, 0.2)
	await wait_and_record(10)
	
	# Check prompt when empty-handed
	var bay_station = garage.get_node_or_null("BikeBay_0")
	check(is_instance_valid(bay_station), "BikeBay_0 exists")
	var prompt_empty: String = bay_station.prompt(player)
	print("  Prompt empty-handed: '%s'" % prompt_empty)
	check(prompt_empty.find("Cần lấy bộ vá săm ở Bàn Thợ trước!") != -1, "Prompt guides player: 'Cần lấy bộ vá săm ở Bàn Thợ trước!'")
	check(customer.speech_label.position.y > garage.bay_status_labels[0].position.y, "Speech label sits above bay label (no overlapping text)")
	
	# 3. Boy walks to Workbench station and interacts
	var bench = garage.get_node_or_null("WorkbenchStation")
	check(is_instance_valid(bench), "WorkbenchStation exists")
	var bench_world: Vector3 = garage.to_global(bench.position)
	await simulate_walk(bench_world + Vector3(0.8, 0, 0.8), 2.0, 0.3)
	
	var bench_prompt: String = bench.prompt(player)
	print("  Workbench prompt: '%s'" % bench_prompt)
	check(bench_prompt.find("Lấy bộ vá săm") != -1, "Workbench prompts: 'Lấy bộ vá săm & keo dán'")
	
	# Interact with workbench
	bench.interact(player)
	await wait_and_record(10)
	check(garage.get_holding_tool(player) == "patch_kit", "Boy picked up patch kit tool from workbench")
	
	# 4. Boy walks back to Bay 0 with patch kit
	await simulate_walk(bay_pos + Vector3(1.0, 0, 0.2), 2.0, 0.3)
	await wait_and_record(10)
	
	var prompt_with_tool: String = bay_station.prompt(player)
	print("  Prompt with patch kit: '%s'" % prompt_with_tool)
	check(prompt_with_tool.find("Dán miếng vá săm (Khoang 1)") != -1, "Prompt with patch kit: 'Dán miếng vá săm (Khoang 1)'")
	
	# 5. Boy interacts [E] to apply patch kit
	bay_station.interact(player)
	await wait_and_record(12)
	check(cust_order.get_current_required_step() == "pump_air", "Step advanced to pump_air")
	
	var prompt_pump: String = bay_station.prompt(player)
	print("  Prompt after patch: '%s'" % prompt_pump)
	check(prompt_pump.find("Bơm căng bánh xe") != -1, "Prompt guides next step: 'Bơm căng bánh xe (Khoang 1)'")
	
	# 6. Complete pump step & verify payment
	var pump = garage.get_node_or_null("AirPumpStation")
	if is_instance_valid(pump):
		pump.interact(player)
	else:
		bay_station.interact(player)
	await wait_and_record(12)
	
	var econ: EconomyManager = world.economy_manager
	check(cust_order.status == BusinessOrder.Status.PAID, "Order marked PAID after repair")
	check(econ.wallet.balance > 0, "Household wallet received payment")
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
