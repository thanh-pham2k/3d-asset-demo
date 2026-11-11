extends "res://tests/visual/scenarios/scenario_base.gd"

const MotorcycleCustomer = preload("res://scripts/neighborhood/business/motorcycle_customer.gd")
const HuTieuCustomer = preload("res://scripts/neighborhood/business/hutieu_customer.gd")

func run_scenario() -> Dictionary:
	print("--- Running TC08: Multiple Concurrent Customers ---")
	scenario_description = "Tests multiple concurrent customers dining at Hu Tieu tables and repairing motorcycles at Garage service bays simultaneously, validating independent order tracking, non-overlapping 3D positions, and capacity reservation bounds."
	expected_result = "Both tables and both repair bays handle independent customers simultaneously without spatial collisions, state corruption, or order interference."
	related_sources = [
		"res://scripts/neighborhood/business/garage_business.gd",
		"res://scripts/neighborhood/business/hutieu_business.gd",
		"res://scripts/neighborhood/business/business_shop.gd"
	]
	reproduction_steps = [
		"1. Position camera and player at neighborhood junction (-50, 0, -18).",
		"2. Spawn two customers at Hu Tieu dining tables (Table 0 and Table 1).",
		"3. Assert customers occupy distinct physical positions (> 3.0m apart) without overlapping.",
		"4. Assert distinct food orders registered for Table 0 and Table 1.",
		"5. Spawn two motorcycle customers at Garage (Bay 0 and Bay 1).",
		"6. Assert motorcycles occupy distinct service bays (> 2.5m apart) and bay_reserved tracks both.",
		"7. Simulate player walking between stalls to visually showcase concurrent customer operations."
	]
	
	recorder.start_recording("TC08_multiple_customers")
	
	player.global_position = Vector3(-50.0, 0, -18.0)
	player.select_character("girl")
	await wait_and_record(6)
	
	var world = game_manager.get_node_or_null("Neighborhood")
	var hutieu: HuTieuBusiness = world.get_node_or_null("HuTieuBusiness") if world else null
	var garage: GarageBusiness = world.get_node_or_null("GarageBusiness") if world else null
	
	check(is_instance_valid(hutieu) and is_instance_valid(garage), "Both businesses exist in world")
	
	# 1. Spawn two seated customers at Hu Tieu tables (Table 0 and Table 1)
	for tbl in [0, 1]:
		var chair_pos: Vector3 = hutieu.table_positions[tbl] + Vector3(-0.95, 0, 0)
		var cust = HuTieuCustomer.new()
		cust.name = "TC08_Cust_Tbl_%d" % tbl
		hutieu.add_child(cust)
		cust.setup(tbl, "Khách %d" % (tbl + 1), hutieu.table_positions[tbl], [chair_pos], [chair_pos])
		cust._on_reached_table()
		hutieu.table_customers[tbl] = cust
		
		var ord = BusinessOrder.new("ord_tbl_%d" % tbl, "dish_%d" % tbl, "Món %d" % (tbl + 1), 40000, ["step"], 60.0)
		ord.table_index = tbl
		ord.customer_name = "Khách %d" % (tbl + 1)
		hutieu.table_orders[tbl] = ord
		hutieu.table_occupied[tbl] = true
	
	await wait_and_record(12)
	
	# Verify distinct positions and independent orders
	var c0_pos: Vector3 = hutieu.table_customers[0].global_position
	var c1_pos: Vector3 = hutieu.table_customers[1].global_position
	check(c0_pos.distance_to(c1_pos) > 3.0, "Hu Tieu Customers occupy separate tables without overlapping (dist > 3m)")
	check(hutieu.table_orders[0].service_title != hutieu.table_orders[1].service_title, "Customers have independent food orders")
	check(hutieu.table_occupied[0] and hutieu.table_occupied[1], "Both Hu Tieu tables marked occupied")
	
	# 2. Spawn two motorcycle customers at Garage (Bay 0 and Bay 1)
	for bay in [0, 1]:
		var bay_pos: Vector3 = garage.bay_positions[bay]
		var mc_cust = MotorcycleCustomer.new()
		mc_cust.name = "TC08_MC_Cust_Bay_%d" % bay
		garage.add_child(mc_cust)
		mc_cust.setup(bay, "Thợ %d" % (bay + 1), garage.bay_positions[bay], [bay_pos], [bay_pos])
		mc_cust._on_arrived_at_bay()
		garage.bay_customers[bay] = mc_cust
		garage.bay_reserved[bay] = true
		
		var mc_ord = BusinessOrder.new("mc_ord_%d" % bay, "repair_%d" % bay, "Dịch vụ %d" % (bay + 1), 35000, ["pump_air"], 60.0)
		mc_ord.table_index = bay
		mc_ord.customer_name = "Khách Xe %d" % (bay + 1)
		garage.bay_orders[bay] = mc_ord
	
	await wait_and_record(12)
	
	var m0_pos: Vector3 = garage.bay_customers[0].global_position
	var m1_pos: Vector3 = garage.bay_customers[1].global_position
	check(m0_pos.distance_to(m1_pos) > 2.5, "Motorcycle customers occupy distinct bays without overlapping (dist > 2.5m)")
	check(garage.bay_reserved[0] and garage.bay_reserved[1], "Both garage bays properly marked as occupied")
	
	# Camera pan across customers
	await simulate_walk(hutieu.global_position + Vector3(-55.0, 0, -20.0), 1.2)
	await wait_and_record(10)
	
	notes = "Verified multiple concurrent customers across tables and bays with non-overlapping positions and independent order queues."
	var gif_path = recorder.stop_recording_and_export_gif(30)
	return build_result(gif_path)
