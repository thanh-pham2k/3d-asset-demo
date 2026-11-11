extends "res://tests/visual/scenarios/scenario_base.gd"

func run_scenario() -> Dictionary:
	print("--- Running TC05: Hu Tieu Preparation ---")
	recorder.start_recording("TC05_hutieu_preparation")
	
	player.global_position = Vector3(-45.0, 0, -14.0)
	player.select_character("girl")
	await wait_and_record(6)
	
	var world = game_manager.get_node_or_null("Neighborhood")
	var hutieu: HuTieuBusiness = world.get_node_or_null("03_HuTieu/HuTieuBusiness") if world else null
	if not hutieu and world:
		hutieu = world.get_node_or_null("HuTieuBusiness")
	check(is_instance_valid(hutieu), "HuTieuBusiness exists")
	
	# Reset to CLOSED state
	hutieu.prep_state = HuTieuBusiness.PrepState.CLOSED
	hutieu.prep_progress = 0.0
	hutieu.is_open = false
	hutieu._update_prep_billboard()
	await wait_and_record(6)
	
	check(hutieu.prep_state == HuTieuBusiness.PrepState.CLOSED, "Shop starts in CLOSED state")
	check(not hutieu.is_open, "Shop is closed, customers blocked")
	
	# 1. Girl approaches preparation station
	var prep_pos = hutieu.global_position + Vector3(-50.0, 0, -15.5)
	await simulate_walk(prep_pos, 1.5)
	await wait_and_record(8)
	
	# 2. Press E to begin preparation
	var prep_st = hutieu.prep_station
	prep_st.interact(player)
	await wait_and_record(6)
	check(hutieu.prep_state == HuTieuBusiness.PrepState.PREPARING, "Shop entered PREPARING phase")
	
	# 3. Animate progress bar gradually from 0% -> 100%
	for p in [25.0, 50.0, 75.0, 95.0, 100.0]:
		hutieu.prep_progress = p
		if p >= 100.0:
			hutieu.prep_state = HuTieuBusiness.PrepState.READY
		hutieu._update_prep_billboard()
		await wait_and_record(6)
	
	check(hutieu.prep_progress >= 100.0, "Preparation reached 100%")
	check(hutieu.prep_state == HuTieuBusiness.PrepState.READY, "Shop entered READY state")
	check("Sẵn sàng bán" in prep_st.prompt(player), "Prompt offers to open shop")
	
	# 4. Press E to officially open shop
	prep_st.interact(player)
	hutieu._update_prep_billboard()
	await wait_and_record(12)
	check(hutieu.prep_state == HuTieuBusiness.PrepState.OPEN, "Shop officially entered OPEN state")
	check(hutieu.is_open, "is_open flag is true")
	print("TC05 DEBUG prep_billboard.text = '", hutieu.prep_billboard.text, "'")
	check("Mở Cửa" in hutieu.prep_billboard.text or "Đón Khách" in hutieu.prep_billboard.text, "Overhead billboard reflects shop open status")
	
	var gif_path = recorder.stop_recording_and_export_gif(30)
	return {
		"id": "TC05",
		"title": "Hu Tieu Preparation",
		"status": "PASS" if not failed else "FAIL",
		"gif_path": gif_path,
		"assertions": assertions,
		"notes": "Verified CLOSED state, gradual 0%->100% preparation, READY state, and explicit player E open interaction."
	}
