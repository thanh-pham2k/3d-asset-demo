extends SceneTree

const FrameRecorderScript = preload("res://tests/visual/capture/frame_recorder.gd")
const ScenarioBaseScript = preload("res://tests/visual/scenarios/scenario_base.gd")

var results: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	print("\n=======================================================")
	print("   COUPLE CHAOS — AUTOMATED VISUAL GAMEPLAY TEST RUNNER")
	print("=======================================================\n")
	
	# Isolate test environment from previous persistent run state
	var default_save := "user://couple_chaos_economy.json"
	if FileAccess.file_exists(default_save):
		DirAccess.remove_absolute(default_save)
	
	# Instantiate live game from main scene
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var game_manager: Node3D = main_scene.instantiate()
	root.add_child(game_manager)
	
	# Wait a couple of frames for full scene initialization
	for i in 6:
		await RenderingServer.frame_post_draw
	
	# Setup FrameRecorder
	var recorder := FrameRecorderScript.new()
	recorder.name = "VisualFrameRecorder"
	root.add_child(recorder)
	recorder.setup(root)
	
	# Parse command line argument if specific scenario is requested
	var target_scenario := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="):
			target_scenario = arg.trim_prefix("--scenario=").to_upper()
	
	# Load Scenario Classes
	var scenarios := [
		preload("res://tests/visual/scenarios/tc01_character_selection.gd").new(),
		preload("res://tests/visual/scenarios/tc02_house_exit.gd").new(),
		preload("res://tests/visual/scenarios/tc03_motorcycle_commute.gd").new(),
		preload("res://tests/visual/scenarios/tc04_motorcycle_repair.gd").new(),
		preload("res://tests/visual/scenarios/tc05_hutieu_preparation.gd").new(),
		preload("res://tests/visual/scenarios/tc06_hutieu_customer_service.gd").new(),
		preload("res://tests/visual/scenarios/tc07_incorrect_order.gd").new(),
		preload("res://tests/visual/scenarios/tc08_multiple_customers.gd").new(),
		preload("res://tests/visual/scenarios/tc09_navigation_camera.gd").new(),
		preload("res://tests/visual/scenarios/tc10_return_home_persistence.gd").new()
	]
	
	var titles := [
		["TC01", "Character Selection"],
		["TC02", "House Exit"],
		["TC03", "Motorcycle Commute"],
		["TC04", "Motorcycle Repair"],
		["TC05", "Hu Tieu Preparation"],
		["TC06", "Hu Tieu Customer Service"],
		["TC07", "Incorrect Order"],
		["TC08", "Multiple Customers"],
		["TC09", "Navigation & Camera"],
		["TC10", "Return Home & Persistence"]
	]
	
	var total_scenarios := scenarios.size()
	var total_passed := 0
	var total_failed := 0
	
	for idx in range(total_scenarios):
		var sc_id: String = titles[idx][0]
		var sc_title: String = titles[idx][1]
		
		if target_scenario != "" and target_scenario != sc_id:
			continue
		
		var scenario = scenarios[idx]
		scenario.setup(sc_id, sc_title, game_manager, recorder)
		
		var t_start := Time.get_ticks_msec()
		var res: Dictionary = await scenario.run_scenario()
		var duration := (Time.get_ticks_msec() - t_start) / 1000.0
		res["duration"] = duration
		results.append(res)
		
		if res["status"] == "PASS":
			total_passed += 1
			print(">>> RESULT: %s [%s] PASS (%.1fs) -> %s\n" % [sc_id, sc_title, duration, res["gif_path"]])
		else:
			total_failed += 1
			print(">>> RESULT: %s [%s] FAIL (%.1fs) -> %s\n" % [sc_id, sc_title, duration, res["gif_path"]])
		
		# Brief pause between scenarios
		for i in 6:
			await RenderingServer.frame_post_draw
	
	# Generate Test Report Markdown
	_generate_report(results, total_passed, total_failed)
	
	print("\n=======================================================")
	print("   ALL SCENARIOS COMPLETED: %d PASSED, %d FAILED" % [total_passed, total_failed])
	print("=======================================================\n")
	
	quit(1 if total_failed > 0 else 0)

func _generate_report(p_results: Array[Dictionary], passed: int, failed: int) -> void:
	var md := "# Automated Visual Gameplay Test Report\n\n"
	md += "**Project**: Couple Chaos (Godot 4.7.2 3D Low-Poly Life Simulation)\n"
	md += "**Date**: %s\n" % Time.get_datetime_string_from_system()
	md += "**Summary**: %d Scenarios Executed — **%d PASS**, **%d FAIL**\n\n" % [passed + failed, passed, failed]
	
	md += "## Executive Summary Table\n\n"
	md += "| Test ID | Scenario Description | Status | Duration | GIF Evidence |\n"
	md += "|---|---|---|---|---|\n"
	for r in p_results:
		var status_badge := "🟢 PASS" if r["status"] == "PASS" else "🔴 FAIL"
		var gif_name: String = r["gif_path"].get_file()
		md += "| `%s` | %s | %s | %.1fs | [%s](./%s) |\n" % [
			r["id"],
			r["title"],
			status_badge,
			r.get("duration", 0.0),
			gif_name,
			gif_name
		]
	
	md += "\n---\n\n## Detailed Test Case Results\n\n"
	for r in p_results:
		var status_badge := "🟢 PASS" if r["status"] == "PASS" else "🔴 FAIL"
		md += "### %s — %s (%s)\n\n" % [r["id"], r["title"], status_badge]
		md += "- **Status**: %s\n" % status_badge
		md += "- **Duration**: %.1fs\n" % r.get("duration", 0.0)
		md += "- **GIF Evidence**: `%s`\n\n" % r["gif_path"]
		md += "#### Assertions Executed:\n"
		for a in r.get("assertions", []):
			var mark := "✅" if a["passed"] else "❌"
			md += "- %s %s\n" % [mark, a["description"]]
		
		md += "\n**Notes**: %s\n\n" % r.get("notes", "")
	
	var report_path := "artifacts/gameplay-tests/test_report.md"
	var f := FileAccess.open(report_path, FileAccess.WRITE)
	if f:
		f.store_string(md)
		f.close()
		print("[VisualTestRunner] Generated detailed report at %s" % report_path)
