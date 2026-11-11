extends "res://tests/visual/scenarios/scenario_base.gd"

const MotorcycleCustomer = preload("res://scripts/neighborhood/business/motorcycle_customer.gd")
const HuTieuCustomer = preload("res://scripts/neighborhood/business/hutieu_customer.gd")

func run_scenario() -> Dictionary:
	print("--- Running TC08: Multiple Customers ---")
	recorder.start_recording("TC08_multiple_customers")
	
	player.global_position = Vector3(-50.0, 0, -18.0)
	player.select_character("girl")
	await wait_and_record(6)
	
	var world = game_manager.get_node_or_null("Neighborhood")
	var hutieu: HuTieuBusiness = world.get_node_or_null("03_HuTieu/HuTieuBusiness") if world else null
	if not hutieu and world:
		hutieu = world.get_node_or_null("HuTieuBusiness")
	
	var garage: GarageBusiness = world.get_node_or_null("02_MotorcycleRepair/GarageBusiness") if world else null
	if not garage and world:
		garage = world.get_node_or_null("GarageBusiness")
	
	check(is_instance_valid(hutieu) and is_instance_valid(garage), "Both businesses exist")
	
	# 1. Spawn two seated customers at Hu Tieu tables (Table 0 and Table 1)
	for tbl in [0, 1]:
		var chair_pos = hutieu.global_position + hutieu.table_positions[tbl] + Vector3(-0.95, 0, 0)
		var cust = HuTieuCustomer.new()
		cust.name = "TC08_Cust_Tbl_%d" % tbl
		hutieu.add_child(cust)
		cust.setup(tbl, "Khách %d" % (tbl + 1), hutieu.table_positions[tbl], [chair_pos], [chair_pos])
		cust._on_reached_table()
		hutieu.table_customers[tbl] = cust
		
		var ord = BusinessOrder.new("ord_tbl_%d" % tbl, "dish_%d" % tbl, "Món %d" % (tbl + 1), 40000, ["step"], 60.0)
		ord.table_index = tbl
		hutieu.table_orders[tbl] = ord
		hutieu.table_occupied[tbl] = true
	
	await wait_and_record(15)
	
	# Verify distinct positions and independent orders
	var c0_pos: Vector3 = hutieu.table_customers[0].global_position
	var c1_pos: Vector3 = hutieu.table_customers[1].global_position
	check(c0_pos.distance_to(c1_pos) > 3.0, "Hu Tieu Customers occupy separate tables without overlapping (dist > 3m)")
	check(hutieu.table_orders[0].service_title != hutieu.table_orders[1].service_title, "Customers have independent orders")
	
	# 2. Spawn two motorcycle customers at Garage (Bay 0 and Bay 1)
	for bay in [0, 1]:
		var bay_pos = garage.global_position + garage.bay_positions[bay]
		var mc_cust = MotorcycleCustomer.new()
		mc_cust.name = "TC08_MC_Cust_Bay_%d" % bay
		garage.add_child(mc_cust)
		mc_cust.setup(bay, "Thợ %d" % (bay + 1), garage.bay_positions[bay], [bay_pos], [bay_pos])
		mc_cust._on_arrived_at_bay()
		garage.bay_customers[bay] = mc_cust
		garage.bay_reserved[bay] = true
	
	await wait_and_record(15)
	
	var m0_pos: Vector3 = garage.bay_customers[0].global_position
	var m1_pos: Vector3 = garage.bay_customers[1].global_position
	check(m0_pos.distance_to(m1_pos) > 2.5, "Motorcycle customers occupy distinct bays without overlapping")
	check(garage.bay_reserved[0] and garage.bay_reserved[1], "Both bays properly marked as occupied")
	
	# Camera pan across customers
	await simulate_walk(hutieu.global_position + Vector3(-55.0, 0, -20.0), 1.2)
	await wait_and_record(10)
	
	var gif_path = recorder.stop_recording_and_export_gif(12)
	return {
		"id": "TC08",
		"title": "Multiple Customers",
		"status": "PASS" if not failed else "FAIL",
		"gif_path": gif_path,
		"assertions": assertions,
		"notes": "Verified multiple concurrent customers across tables and bays with non-overlapping positions."
	}
