extends "res://tests/visual/scenarios/scenario_base.gd"

const MotorcycleCustomer = preload("res://scripts/neighborhood/business/motorcycle_customer.gd")

func run_scenario() -> Dictionary:
	print("--- Running TC04: Motorcycle Repair ---")
	recorder.start_recording("TC04_motorcycle_repair")
	
	player.global_position = Vector3(-60.0, 0, -12.0)
	player.select_character("boy")
	await wait_and_record(6)
	
	var world = game_manager.get_node_or_null("Neighborhood")
	var garage: GarageBusiness = world.get_node_or_null("02_MotorcycleRepair/GarageBusiness") if world else null
	if not garage and world:
		garage = world.get_node_or_null("GarageBusiness")
	check(is_instance_valid(garage), "GarageBusiness exists")
	
	# Spawn a customer motorcycle approaching Bay 0
	var bay_pos: Vector3 = garage.global_position + garage.bay_positions[0]
	var approach_path: Array[Vector3] = [
		bay_pos + Vector3(0, 0, 10),
		bay_pos + Vector3(0, 0, 4),
		bay_pos
	]
	var depart_path: Array[Vector3] = [
		bay_pos,
		bay_pos + Vector3(0, 0, 5),
		bay_pos + Vector3(-15, 0, 10)
	]
	
	var order_id := "tc04_order_%d" % Time.get_ticks_msec()
	var cust_order = BusinessOrder.new(order_id, "patch", "Vá săm xe", 35000, ["patch_kit", "pump_air"], 60.0)
	cust_order.table_index = 0
	
	var customer = MotorcycleCustomer.new()
	customer.name = "TC04_Customer"
	garage.add_child(customer)
	customer.setup(0, "Anh Tuấn", garage.bay_positions[0], [bay_pos + Vector3(0, 0, 6), bay_pos], depart_path)
	customer.order = cust_order
	garage.bay_customers[0] = customer
	
	# 1. Customer arrives and parks at bay
	await wait_and_record(15)
	customer._on_arrived_at_bay()
	garage.bay_orders[0] = cust_order
	garage.active_orders.append(cust_order)
	await wait_and_record(12)
	
	check(customer.current_state == MotorcycleCustomer.State.WAITING_FOR_REPAIR, "Customer parked and waiting for service")
	check(customer.driver.position.x < -0.2, "Customer driver stepped off motorcycle")
	
	# 2. Boy walks to workbench and picks up patch kit
	var bench_world: Vector3 = garage.global_position + Vector3(-101, 0, -20)
	await simulate_walk(bench_world + Vector3(0, 0, 1.2), 1.5)
	garage.set_holding_tool(player, "patch_kit")
	await wait_and_record(8)
	check(garage.get_holding_tool(player) == "patch_kit", "Boy picked up patch kit from workbench")
	
	# 3. Boy walks to Bay 0 and applies patch kit
	await simulate_walk(bay_pos + Vector3(1.2, 0, 0), 1.6)
	cust_order.advance_step("patch_kit")
	garage.set_holding_tool(player, "")
	await wait_and_record(8)
	check(cust_order.get_current_required_step() == "pump_air", "Patch kit applied, next step is pump_air")
	
	# 4. Boy pumps tire to complete service
	cust_order.advance_step("pump_air")
	cust_order.status = BusinessOrder.Status.COMPLETED
	var econ: EconomyManager = world.economy_manager
	var wallet_before = econ.wallet.balance
	garage.complete_order(cust_order)
	await wait_and_record(12)
	
	check(cust_order.status == BusinessOrder.Status.PAID, "Order status marked PAID")
	check(econ.wallet.balance == wallet_before + 35000, "Household wallet received +35,000đ")
	check(customer.current_state == MotorcycleCustomer.State.SERVICE_COMPLETED, "Customer celebrates completed service")
	
	# 5. Customer gets on motorcycle and rides away
	await wait_and_record(15)
	customer._process_service_completed(1.0)
	check(customer.current_state == MotorcycleCustomer.State.DEPARTING, "Customer departed on motorcycle")
	
	var gif_path = recorder.stop_recording_and_export_gif(12)
	return {
		"id": "TC04",
		"title": "Motorcycle Repair",
		"status": "PASS" if not failed else "FAIL",
		"gif_path": gif_path,
		"assertions": assertions,
		"notes": "Verified customer arrival, parking, sequential repair (patch kit + pump), payment, and riding away."
	}
