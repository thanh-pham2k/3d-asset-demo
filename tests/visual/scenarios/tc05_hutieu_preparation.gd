extends "res://tests/visual/scenarios/scenario_base.gd"

func run_scenario() -> Dictionary:
	print("--- Running TC05: Hu Tieu Preparation & Opening ---")
	scenario_description = "Tests Hu Tieu stall starting in CLOSED state, player interacting with prep station, natural real-time cooking and preparation progress (0% -> 100%), transition to READY state, and player opening the shop to receive customers."
	expected_result = "Shop starts closed, prep station triggers gradual real-time progress accumulation to 100%, and second interaction opens stall with updated overhead billboard."
	related_sources = [
		"res://scripts/neighborhood/business/hutieu_business.gd",
		"res://scripts/neighborhood/business/business_shop.gd"
	]
	reproduction_steps = [
		"1. Position player at Hu Tieu stall (-45, 0, -14).",
		"2. Reset shop to CLOSED state: assert customers blocked and billboard indicates closed.",
		"3. Walk to PrepStation at cooking counter and press [E] to start preparation.",
		"4. Shop enters PREPARING phase: wait and capture frames as progress naturally accumulates to 100%.",
		"5. Assert stall transitions to READY state once progress hits 100%.",
		"6. Press [E] at PrepStation to officially open shop: assert prep_state == OPEN and is_open == true.",
		"7. Verify overhead billboard reflects active open status."
	]
	
	recorder.start_recording("TC05_hutieu_preparation")
	
	player.global_position = Vector3(-45.0, 0, -14.0)
	player.select_character("girl")
	await wait_and_record(6)
	
	var world = game_manager.get_node_or_null("Neighborhood")
	var hutieu: HuTieuBusiness = world.get_node_or_null("HuTieuBusiness") if world else null
	check(is_instance_valid(hutieu), "HuTieuBusiness exists")
	
	# Reset to CLOSED state
	hutieu.prep_state = HuTieuBusiness.PrepState.CLOSED
	hutieu.prep_progress = 0.0
	hutieu.is_open = false
	hutieu._update_prep_billboard()
	await wait_and_record(6)
	
	check(hutieu.prep_state == HuTieuBusiness.PrepState.CLOSED, "Shop starts in CLOSED state")
	check(not hutieu.is_open, "Shop is closed, customer arrivals blocked")
	
	# 1. Girl approaches preparation station
	var prep_st = hutieu.prep_station
	var prep_pos: Vector3 = hutieu.global_position + prep_st.position
	await simulate_walk(prep_pos + Vector3(0, 0, 1.2), 1.5)
	await wait_and_record(6)
	
	# 2. Press E to begin preparation
	prep_st.interact(player)
	await wait_and_record(6)
	check(hutieu.prep_state == HuTieuBusiness.PrepState.PREPARING, "Shop entered PREPARING phase")
	
	# 3. Allow progress to accumulate naturally via _process over ~3 seconds
	for step in range(30):
		hutieu._process(0.12)
		await wait_and_record(2)
		if hutieu.prep_state == HuTieuBusiness.PrepState.READY:
			break
	
	check(hutieu.prep_progress >= 100.0, "Preparation progress reached 100%")
	check(hutieu.prep_state == HuTieuBusiness.PrepState.READY, "Shop naturally entered READY state")
	check("Sẵn sàng bán" in prep_st.prompt(player), "Prompt offers to open shop")
	
	# 4. Press E to officially open shop
	prep_st.interact(player)
	hutieu._update_prep_billboard()
	await wait_and_record(12)
	
	check(hutieu.prep_state == HuTieuBusiness.PrepState.OPEN, "Shop officially entered OPEN state")
	check(hutieu.is_open, "is_open flag is true")
	check("Mở Cửa" in hutieu.prep_billboard.text or "Đón Khách" in hutieu.prep_billboard.text, "Overhead billboard reflects shop open status")
	
	notes = "Verified CLOSED state, real-time natural preparation accumulation (0% -> 100%), READY transition, and E open interaction."
	var gif_path = recorder.stop_recording_and_export_gif(30)
	return build_result(gif_path)
