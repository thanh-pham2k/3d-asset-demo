class_name ScenarioBase
extends RefCounted

## Base class for visual gameplay scenarios.
## Executes realistic gameplay actions (walking, interacting, driving)
## without teleporting, validates state assertions, and captures rendered GIF frames.

var scenario_id: String = ""
var scenario_title: String = ""
var game_manager: Node3D
var player: CharacterBody3D
var recorder: Node
var assertions: Array[Dictionary] = []
var failed: bool = false
var notes: String = ""

func setup(p_id: String, p_title: String, p_gm: Node3D, p_rec: Node) -> void:
	scenario_id = p_id
	scenario_title = p_title
	game_manager = p_gm
	player = p_gm.p1
	recorder = p_rec
	assertions.clear()
	failed = false
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

func wait_and_record(frames: int = 5) -> void:
	for i in frames:
		await RenderingServer.frame_post_draw
		recorder.capture_now()

func simulate_walk(target_world_pos: Vector3, max_seconds: float = 4.0, stop_dist: float = 0.4) -> void:
	var elapsed := 0.0
	var delta := 0.05
	
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
		await RenderingServer.frame_post_draw
		# Capture every 2nd frame to keep GIF pacing snappy and within 12-15 FPS
		recorder.capture_now()

func simulate_scooter_drive(scooter: Node, waypoints: Array[Vector3], cruise_speed: float = 10.0) -> void:
	var delta := 0.05
	for wp in waypoints:
		var target = wp
		var reached := false
		var timeout := 6.0
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
			await RenderingServer.frame_post_draw
			recorder.capture_now()

func run_scenario() -> Dictionary:
	# Override in subclass
	return {}
