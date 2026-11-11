extends SceneTree

const FrameRecorderScript = preload("res://tests/visual/capture/frame_recorder.gd")

var results: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	print("\n=======================================================")
	print("   COUPLE CHAOS — VALIDATION TEST RUNNER (TC01 - TC04)")
	print("=======================================================\n")
	
	# Instantiate live game from main scene
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var game_manager: Node3D = main_scene.instantiate()
	root.add_child(game_manager)
	
	for i in 6:
		await RenderingServer.frame_post_draw
	
	var recorder := FrameRecorderScript.new()
	recorder.name = "ValidationFrameRecorder"
	root.add_child(recorder)
	recorder.setup(root)
	
	var scenarios := [
		preload("res://tests/visual/scenarios/val01_repair_messages.gd").new(),
		preload("res://tests/visual/scenarios/val02_minimap_expanded_map.gd").new(),
		preload("res://tests/visual/scenarios/val03_riding_poses.gd").new(),
		preload("res://tests/visual/scenarios/val04_customer_sitting_eating.gd").new()
	]
	
	var titles := [
		["TC01", "Motorcycle Repair Messages"],
		["TC02", "Minimap and Expanded Map"],
		["TC03", "Boy/Girl Motorcycle Riding Poses"],
		["TC04", "Hu Tieu Customer Sitting and Eating"]
	]
	
	var total_passed := 0
	var total_failed := 0
	
	for idx in range(scenarios.size()):
		var sc_id: String = titles[idx][0]
		var sc_title: String = titles[idx][1]
		var scenario = scenarios[idx]
		
		scenario.setup(sc_id, sc_title, game_manager, recorder)
		
		var t_start := Time.get_ticks_msec()
		var res_variant = await scenario.run_scenario()
		var res: Dictionary = res_variant if res_variant is Dictionary else {
			"id": sc_id,
			"title": sc_title,
			"status": "FAIL",
			"gif_path": "",
			"assertions": scenario.assertions,
			"notes": "Scenario error or null return"
		}
		var duration := (Time.get_ticks_msec() - t_start) / 1000.0
		res["duration"] = duration
		results.append(res)
		
		if res["status"] == "PASS":
			total_passed += 1
			print(">>> RESULT: %s [%s] PASS (%.1fs) -> %s\n" % [sc_id, sc_title, duration, res["gif_path"]])
		else:
			total_failed += 1
			print(">>> RESULT: %s [%s] FAIL (%.1fs) -> %s\n" % [sc_id, sc_title, duration, res["gif_path"]])
		
		for i in 6:
			await RenderingServer.frame_post_draw
	
	_write_report(total_passed, total_failed)
	
	print("\n=======================================================")
	print("   VALIDATION RUN COMPLETE: %d/%d PASSED" % [total_passed, scenarios.size()])
	print("=======================================================\n")
	
	quit(0 if total_failed == 0 else 1)

func _write_report(passed: int, failed: int) -> void:
	var md := "# Couple Chaos — Visual Validation Report\n\n"
	md += "**Generated:** %s\n\n" % Time.get_datetime_string_from_system()
	md += "## Summary Table\n\n"
	md += "| Test ID | Title | Status | Duration | Evidence GIF |\n"
	md += "|---|---|---|---|---|\n"
	
	for r in results:
		var status_badge := "🟢 **PASS**" if r["status"] == "PASS" else "🔴 **FAIL**"
		md += "| %s | %s | %s | %.1fs | [%s](%s) |\n" % [
			r["id"],
			r["title"],
			status_badge,
			r.get("duration", 0.0),
			r["gif_path"].get_file(),
			r["gif_path"]
		]
	
	md += "\n## Detailed Test Cases\n\n"
	for r in results:
		md += "### %s — %s\n" % [r["id"], r["title"]]
		md += "- **Status:** %s\n" % r["status"]
		md += "- **Evidence GIF:** `%s`\n" % r["gif_path"]
		md += "- **Notes:** %s\n" % r.get("notes", "")
		md += "- **Assertions (%d executed):**\n" % r.get("assertions", []).size()
		for a in r.get("assertions", []):
			var icon := "✅" if a["passed"] else "❌"
			md += "  - %s %s\n" % [icon, a["description"]]
		md += "\n"
	
	var file = FileAccess.open("artifacts/gameplay-tests/validation_report.md", FileAccess.WRITE)
	if file:
		file.store_string(md)
		file.close()
		print("Wrote validation report to artifacts/gameplay-tests/validation_report.md")
