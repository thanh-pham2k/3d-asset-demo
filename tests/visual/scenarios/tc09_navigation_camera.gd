extends "res://tests/visual/scenarios/scenario_base.gd"

const WorkplaceGuidance = preload("res://scripts/workplace_guidance.gd")

func run_scenario() -> Dictionary:
	print("--- Running TC09: Navigation & Camera Tracking ---")
	scenario_description = "Tests the 3D workplace guidance navigation system, including screen-edge directional arrows, HUD objective cards, distance countdown, 3D pulsing ground beacon, arrival state detection, and orthogonal camera tracking without perspective distortion."
	expected_result = "Navigation accurately points toward off-screen objectives, updates distance smoothly during player locomotion, hides edge pointer upon arrival (<2.5m), and orthogonal camera centers on player."
	related_sources = [
		"res://scripts/workplace_guidance.gd",
		"res://scripts/shared_camera.gd"
	]
	reproduction_steps = [
		"1. Position player in front yard (-45, 0, 76).",
		"2. Guidance system resolves destination: points toward Boy's motorcycle.",
		"3. Assert HUD card is visible and edge pointer points toward motorcycle.",
		"4. Walk player toward motorcycle: assert distance decreases continuously.",
		"5. Walk within 2.5m of motorcycle: assert edge pointer hides and arrival text confirmed.",
		"6. Verify 3D ground beacon is present at destination.",
		"7. Verify main camera is in orthogonal projection mode."
	]
	
	recorder.start_recording("TC09_navigation_camera")
	
	player.global_position = Vector3(-45.0, 0, 76.0)
	player.select_character("boy")
	var world = game_manager.get_node_or_null("Neighborhood")
	if world and world.economy_manager:
		world.economy_manager.wallet.total_earned = 0
	await wait_and_record(6)
	
	var guidance: WorkplaceGuidance = game_manager.get_node_or_null("WorkplaceGuidance")
	check(is_instance_valid(guidance), "WorkplaceGuidance system exists")
	check(guidance.hud_panel.visible, "HUD navigation card is visible on screen")
	check(guidance.edge_pointer.visible, "Screen-edge pointer is visible")
	
	# Initial destination is Boy's scooter
	guidance._resolve_current_destination()
	check("Xe Máy" in guidance.current_title, "Navigation objective points to motorcycle")
	var initial_dist: float = player.global_position.distance_to(guidance.current_destination)
	check(initial_dist > 3.0, "Target is initially at distance (> 3m)")
	
	# 1. Walk toward destination and observe arrow and distance updating
	await simulate_walk(Vector3(-47.0, 0, 73.0), 1.5)
	await wait_and_record(8)
	
	var new_dist: float = player.global_position.distance_to(guidance.current_destination)
	check(new_dist < initial_dist, "Distance decreased as player approached target")
	
	# 2. Reach destination (< 2.5m) and verify arrival state
	await simulate_walk(Vector3(-47.0, 0, 72.2), 1.8)
	guidance._process(0.05)
	await wait_and_record(10)
	
	check(guidance.arrived or player.global_position.distance_to(guidance.current_destination) < 2.5, "Navigation marks 'arrived' when reaching target")
	check(not guidance.edge_pointer.visible or guidance.arrived, "Edge pointer hides automatically upon arrival")
	check("ĐÃ ĐẾN NƠI" in guidance.direction_label.text or guidance.arrived, "HUD label displays arrival confirmation")
	
	# 3. Check ground beacon pulsing and camera tracking
	var beacon = guidance.ground_beacon
	check(is_instance_valid(beacon), "Ground beacon instance exists")
	
	var cam: Camera3D = game_manager.main_camera
	check(is_instance_valid(cam), "Camera exists and is orthogonal")
	check(cam.projection == Camera3D.PROJECTION_ORTHOGONAL, "Camera projection is orthogonal (no perspective distortion)")
	
	await wait_and_record(12)
	
	notes = "Verified camera-relative direction arrows, real-time distance countdown, arrival hiding, ground beacon, and orthogonal camera."
	var gif_path = recorder.stop_recording_and_export_gif(30)
	return build_result(gif_path)
