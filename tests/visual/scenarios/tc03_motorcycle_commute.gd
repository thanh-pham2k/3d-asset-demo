extends "res://tests/visual/scenarios/scenario_base.gd"

const PlayerScooter = preload("res://scripts/neighborhood/player_scooter.gd")

func run_scenario() -> Dictionary:
	print("--- Running TC03: Motorcycle Commute & Parking ---")
	scenario_description = "Tests walking to motorcycle in front yard, mounting vehicle, folding kickstand, driving along road waypoints without building clipping, parking smoothly into garage workplace bay, and dismounting."
	expected_result = "Player mounts motorcycle, kickstand retracts, drives road grid at cruise speed (11 m/s), parks squarely in designated workplace bay with kickstand down."
	related_sources = [
		"res://scripts/neighborhood/player_scooter.gd",
		"res://scripts/neighborhood/world.gd"
	]
	reproduction_steps = [
		"1. Spawn player in front yard at (-45, 0, 76).",
		"2. Walk to Boy's motorcycle at parking bay (-47, 0, 72).",
		"3. Mount motorcycle: assert kickstand retracted and riding_scooter meta set.",
		"4. Drive along road waypoints (yard gate -> street -> West Avenue -> Boulevard -> garage driveway).",
		"5. Enter garage workplace parking bay and dismount.",
		"6. Verify motorcycle parked at work_parking_pos and kickstand deployed."
	]
	
	recorder.start_recording("TC03_motorcycle_commute")
	
	player.global_position = Vector3(-45.0, 0, 76.0)
	player.select_character("boy")
	await wait_and_record(6)
	
	var world = game_manager.get_node_or_null("Neighborhood")
	var boy_scooter: PlayerScooter = world.get("boy_scooter") if world else null
	check(is_instance_valid(boy_scooter), "Boy's commuter motorcycle exists")
	
	# 1. Walk from yard walkway to Boy's motorcycle
	await simulate_walk(Vector3(-47.0, 0, 72.0), 1.6)
	await wait_and_record(6)
	check(boy_scooter.available(player), "Motorcycle is available for mounting")
	
	# 2. Mount motorcycle
	boy_scooter.mount(player)
	await wait_and_record(10)
	check(boy_scooter.is_mounted, "Player mounted motorcycle")
	check(not boy_scooter.kickstand.visible, "Kickstand folded up automatically")
	check(player.has_meta("riding_scooter"), "Player meta indicates riding state")
	
	# 3. Commute from home to garage following exact road waypoints
	var commute_waypoints: Array[Vector3] = [
		Vector3(-45.0, 0, 64.0), # Yard gate
		Vector3(-45.0, 0, 50.0), # Local residential street
		Vector3(-80.0, 0, 50.0), # Junction with West Avenue
		Vector3(-80.0, 0, 0.0),  # Junction with Boulevard
		Vector3(-63.0, 0, 0.0),  # In front of Garage driveway
		Vector3(-63.0, 0, -8.0), # Turning into Garage driveway
		Vector3(-58.0, 0, -13.0) # Dedicated workplace parking bay
	]
	
	await simulate_scooter_drive(boy_scooter, commute_waypoints, 11.0)
	await wait_and_record(8)
	
	# 4. Stop smoothly and dismount into designated bay
	boy_scooter.dismount()
	await wait_and_record(12)
	
	check(not boy_scooter.is_mounted, "Player dismounted motorcycle")
	check(boy_scooter.kickstand.visible, "Kickstand put down upon parking")
	check(boy_scooter.global_position.distance_to(boy_scooter.work_parking_pos) < 0.2, "Motorcycle neatly parked in garage bay")
	check(player.global_position.distance_to(boy_scooter.work_parking_pos) < 2.0, "Player arrived at garage workplace without teleporting")
	
	notes = "Verified walking to bike, mounting, driving entire road path to garage, parking, and dismounting cleanly."
	var gif_path = recorder.stop_recording_and_export_gif(30)
	return build_result(gif_path)
