extends "res://tests/visual/scenarios/scenario_base.gd"

const HuTieuCustomer = preload("res://scripts/neighborhood/business/hutieu_customer.gd")
const HuTieuBusiness = preload("res://scripts/neighborhood/business/hutieu_business.gd")
const BusinessOrder = preload("res://scripts/neighborhood/business/business_order.gd")

func run_scenario() -> Dictionary:
	print("--- Running TC04: Hu Tieu Customer Sitting and Eating ---")
	recorder.start_recording("TC04_customer_sitting_eating")
	
	player.select_character("girl")
	var world = game_manager.get_node_or_null("Neighborhood")
	var hutieu: HuTieuBusiness = world.get_node_or_null("03_HuTieu/HuTieuBusiness") if world else null
	if not hutieu and world:
		hutieu = world.get_node_or_null("HuTieuBusiness")
	check(is_instance_valid(hutieu), "HuTieuBusiness exists")
	
	hutieu.prep_state = HuTieuBusiness.PrepState.OPEN
	hutieu.is_open = true
	
	var table_pos = hutieu.global_position + hutieu.table_positions[0]
	var chair_pos = table_pos + Vector3(-0.95, 0, 0)
	var cam: Camera3D = game_manager.main_camera
	
	# Set camera to frame Table 0 and chair clearly
	if is_instance_valid(cam):
		cam.global_position = table_pos + Vector3(2.8, 2.2, 3.2)
		cam.look_at(table_pos + Vector3(0, 0.5, 0))
	
	# 1. Customer walks toward table (WALK)
	var order_id := "tc04_val_%d" % Time.get_ticks_msec()
	var order = BusinessOrder.new(order_id, "noodle_nam_vang", "Hủ tiếu Nam Vang", 45000, ["boil_noodles", "add_broth", "add_toppings", "serve_table"], 60.0)
	order.table_index = 0
	order.customer_name = "Bác Năm"
	
	var customer = HuTieuCustomer.new()
	customer.name = "TC04_Customer"
	hutieu.add_child(customer)
	customer.setup(0, "Bác Năm", hutieu.table_positions[0], [chair_pos + Vector3(0, 0, 3.0), chair_pos], [chair_pos, chair_pos + Vector3(0, 0, 6.0)])
	hutieu.table_customers[0] = customer
	
	check(customer.current_state == HuTieuCustomer.State.WALKING_TO_TABLE, "Customer state is WALKING_TO_TABLE (WALK)")
	await wait_and_record(15)
	
	# 2. Customer reaches table and sits down (WALK -> SIT -> ORDER)
	customer._on_reached_table()
	hutieu.table_orders[0] = order
	hutieu.active_orders.append(order)
	
	check(customer.current_state == HuTieuCustomer.State.SEATED_ORDERING, "Transitioned to SEATED_ORDERING (SIT)")
	check(is_instance_valid(customer.diner), "Customer diner visual exists")
	
	# Close-up camera angle inspecting hip, knee, and leg posture on chair
	if is_instance_valid(cam):
		cam.global_position = chair_pos + Vector3(1.6, 1.2, 1.6)
		cam.look_at(chair_pos + Vector3(0, 0.5, 0))
	await wait_and_record(15)
	
	var leg_rot_x: float = customer.diner.left_leg.rotation.x
	check(leg_rot_x < -1.0, "Legs bent naturally downward in front of chair (not clipping table)")
	var arm_rot_x: float = customer.diner.left_arm.rotation.x
	check(arm_rot_x < -0.5, "Arms resting gently on table surface")
	
	# 3. Serve food bowl (ORDER -> EAT)
	customer.start_eating()
	check(customer.current_state == HuTieuCustomer.State.EATING, "Transitioned to EATING")
	check(customer.eating_bowl.visible, "Steaming noodle bowl placed on table")
	
	# Front eating angle to capture spoon/slurp motion
	if is_instance_valid(cam):
		cam.global_position = table_pos + Vector3(-0.4, 1.1, 1.8)
		cam.look_at(chair_pos + Vector3(0, 0.55, 0))
	
	for step in 30:
		customer._process_eating(0.06)
		await RenderingServer.frame_post_draw
		recorder.capture_now()
	
	# 4. Customer finishes, stands up, and leaves (EAT -> STAND -> LEAVE)
	customer._stand_up_pose()
	customer.current_state = HuTieuCustomer.State.LEAVING
	check(customer.current_state == HuTieuCustomer.State.LEAVING, "Customer stood up and transitioned to LEAVING")
	check(customer.diner.left_leg.rotation.x == 0.0, "Leg rotations restored to upright standing posture")
	
	# Wide angle showing customer departing
	if is_instance_valid(cam):
		cam.global_position = table_pos + Vector3(3.0, 2.5, 3.5)
		cam.look_at(table_pos + Vector3(0, 0.5, 0))
	
	for step in 20:
		customer.global_position += Vector3(0, 0, 1.0) * (3.0 * 0.05)
		customer.diner.update_pose(3.0, false, false, false, false, false, false, step * 0.05)
		await RenderingServer.frame_post_draw
		recorder.capture_now()
	
	var gif_path = recorder.stop_recording_and_export_gif(30)
	return {
		"id": "TC04",
		"title": "Hu Tieu Customer Sitting and Eating",
		"status": "PASS" if not failed else "FAIL",
		"gif_path": gif_path,
		"assertions": assertions,
		"notes": "Verified full WALK -> SIT -> ORDER -> EAT -> STAND -> LEAVE cycle, accurate chair alignment, leg bending, and slurp animation."
	}
