class_name ScenarioBase
extends RefCounted

## Base class for visual gameplay scenarios.
## Executes realistic gameplay actions (walking, interacting, driving)
## without teleporting, validates state assertions, and captures rendered GIF frames.

var scenario_id: String = ""
var scenario_title: String = ""
var scenario_description: String = ""
var expected_result: String = ""
var actual_result: String = ""
var game_manager: Node3D
var player: CharacterBody3D
var recorder: Node
var assertions: Array[Dictionary] = []
var reproduction_steps: Array[String] = []
var related_sources: Array[String] = []
var failed: bool = false
var blocked: bool = false
var blocked_reason: String = ""
var root_cause: String = ""
var notes: String = ""

func setup(p_id: String, p_title: String, p_gm: Node3D, p_rec: Node) -> void:
	scenario_id = p_id
	scenario_title = p_title
	scenario_description = ""
	expected_result = ""
	actual_result = ""
	game_manager = p_gm
	player = p_gm.p1
	recorder = p_rec
	assertions.clear()
	reproduction_steps.clear()
	related_sources.clear()
	failed = false
	blocked = false
	blocked_reason = ""
	root_cause = ""
	notes = ""

func check(condition: bool, description: String) -> void:
	var entry := {
		"description": description,
		"passed": condition
	}
	assertions.append(entry)
	if condition:
		print("  [PASS] %s" % description)
	else:
		failed = true
		print("  [FAIL] %s" % description)

func mark_blocked(reason: String) -> void:
	blocked = true
	blocked_reason = reason
	print("  [BLOCKED] %s" % reason)

func wait_and_record(frames: int = 6) -> void:
	for i in frames:
		await RenderingServer.frame_post_draw
		if i % 3 == 0 or i == frames - 1:
			recorder.capture_now()

func simulate_walk(target_world_pos: Vector3, max_seconds: float = 3.5, stop_dist: float = 0.4) -> void:
	var elapsed := 0.0
	var delta := 0.05
	var step_idx := 0
	
	while elapsed < max_seconds:
		var diff = target_world_pos - player.global_position
		diff.y = 0.0
		var dist = diff.length()
		
		if dist <= stop_dist:
			player.velocity = Vector3.ZERO
			player.update_animation(0.0, false)
			await RenderingServer.frame_post_draw
			recorder.capture_now()
			break
		
		var dir = diff.normalized()
		player.facing = dir
		player.rotation.y = atan2(dir.x, dir.z) + PI
		player.velocity = dir * 4.5
		player.move_and_slide()
		player.update_animation(4.5, false)
		
		elapsed += delta
		step_idx += 1
		await RenderingServer.frame_post_draw
		# Capture every 2nd frame to keep GIF pacing snappy (12-15 FPS effective)
		if step_idx % 2 == 0:
			recorder.capture_now()

func simulate_scooter_drive(scooter: Node, waypoints: Array[Vector3], cruise_speed: float = 11.0) -> void:
	var delta := 0.05
	var step_idx := 0
	for wp in waypoints:
		var target = wp
		var reached := false
		var timeout := 5.0
		var t := 0.0
		
		while not reached and t < timeout:
			var diff = target - player.global_position
			diff.y = 0.0
			var dist = diff.length()
			
			if dist <= cruise_speed * delta * 1.5:
				player.global_position.x = target.x
				player.global_position.z = target.z
				reached = true
			else:
				var dir = diff.normalized()
				player.velocity = dir * cruise_speed
				player.move_and_slide()
				scooter.update_riding(delta, dir, cruise_speed, true)
			
			t += delta
			step_idx += 1
			await RenderingServer.frame_post_draw
			if step_idx % 2 == 0:
				recorder.capture_now()

func build_result(p_gif_path: String) -> Dictionary:
	var status_str := "PASS"
	if blocked:
		status_str = "BLOCKED"
	elif failed:
		status_str = "FAIL"
	
	return {
		"id": scenario_id,
		"title": scenario_title,
		"description": scenario_description,
		"status": status_str,
		"expected_result": expected_result,
		"actual_result": actual_result if actual_result != "" else ("All assertions passed successfully." if status_str == "PASS" else "One or more assertions failed."),
		"gif_path": p_gif_path,
		"assertions": assertions,
		"reproduction_steps": reproduction_steps,
		"related_sources": related_sources,
		"root_cause": root_cause if root_cause != "" else (blocked_reason if blocked else ""),
		"notes": notes
	}

func run_scenario() -> Dictionary:
	# Override in subclass
	return {}
