extends SceneTree

const FrameRecorderScript = preload("res://tests/visual/capture/frame_recorder.gd")
const ScenarioBaseScript = preload("res://tests/visual/scenarios/scenario_base.gd")

var results: Array[Dictionary] = []

func _initialize() -> void:
	OS.low_processor_usage_mode = false
	Engine.max_fps = 60
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
	for i in 8:
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
	
	# Load All 13 Scenario Classes
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
		preload("res://tests/visual/scenarios/tc10_return_home_persistence.gd").new(),
		preload("res://tests/visual/scenarios/tc11_customer_timeout.gd").new(),
		preload("res://tests/visual/scenarios/tc12_house_business_upgrades.gd").new(),
		preload("res://tests/visual/scenarios/tc13_visual_regression.gd").new()
	]
	
	var titles := [
		["TC01", "Character Selection"],
		["TC02", "House Entry & Exit"],
		["TC03", "Motorcycle Riding & Parking"],
		["TC04", "Motorcycle Customer Arrival & Repair"],
		["TC05", "Hu Tieu Preparation & Opening"],
		["TC06", "Hu Tieu Customer Service"],
		["TC07", "Incorrect Order Rejection & Discard"],
		["TC08", "Multiple Concurrent Customers"],
		["TC09", "Navigation & Camera Tracking"],
		["TC10", "Return Home & Persistence"],
		["TC11", "Customer Timeout & Departure"],
		["TC12", "House & Business Upgrades Progression"],
		["TC13", "Visual Regression & System Integrity"]
	]
	
	var total_scenarios := scenarios.size()
	var total_passed := 0
	var total_failed := 0
	var total_blocked := 0
	
	for idx in range(total_scenarios):
		var sc_id: String = titles[idx][0]
		var sc_title: String = titles[idx][1]
		
		if target_scenario != "" and target_scenario != sc_id:
			continue
		
		var scenario = scenarios[idx]
		scenario.setup(sc_id, sc_title, game_manager, recorder)
		
		var t_start := Time.get_ticks_msec()
		print("RUNNING SCENARIO: ", sc_id)
		var res: Dictionary = await scenario.run_scenario()
		print("FINISHED SCENARIO: ", sc_id)
		var duration := (Time.get_ticks_msec() - t_start) / 1000.0
		res["duration"] = duration
		results.append(res)
		
		if res["status"] == "PASS":
			total_passed += 1
			print(">>> RESULT: %s [%s] PASS (%.1fs) -> %s\n" % [sc_id, sc_title, duration, res["gif_path"]])
		elif res["status"] == "BLOCKED":
			total_blocked += 1
			print(">>> RESULT: %s [%s] BLOCKED (%.1fs) -> %s\n" % [sc_id, sc_title, duration, res["gif_path"]])
		else:
			total_failed += 1
			print(">>> RESULT: %s [%s] FAIL (%.1fs) -> %s\n" % [sc_id, sc_title, duration, res["gif_path"]])
		
		# Brief pause between scenarios
		for i in 6:
			await RenderingServer.frame_post_draw
	
	# Generate Test Report Markdown and HTML Dashboard
	_generate_report(results, total_passed, total_failed, total_blocked)
	_generate_html_dashboard(results, total_passed, total_failed, total_blocked)
	
	print("\n=======================================================")
	print("   ALL SCENARIOS COMPLETED: %d PASSED, %d FAILED, %d BLOCKED" % [total_passed, total_failed, total_blocked])
	print("=======================================================\n")
	
	quit(1 if total_failed > 0 else 0)

func _generate_report(p_results: Array[Dictionary], passed: int, failed: int, blocked: int) -> void:
	var total := passed + failed + blocked
	var md := "# Automated Visual Gameplay Test Report\n\n"
	md += "**Project**: Couple Chaos (Godot 4.7.2 3D Low-Poly Life Simulation)\n"
	md += "**Date**: %s\n" % Time.get_datetime_string_from_system()
	md += "**Execution Summary**: %d Scenarios Executed — **%d PASS**, **%d FAIL**, **%d BLOCKED**\n\n" % [total, passed, failed, blocked]
	
	md += "## Executive Summary Table\n\n"
	md += "| Test ID | Scenario Description | Status | Duration | GIF Evidence |\n"
	md += "|---|---|---|---|---|\n"
	for r in p_results:
		var status_badge := "🟢 PASS"
		if r["status"] == "FAIL":
			status_badge = "🔴 FAIL"
		elif r["status"] == "BLOCKED":
			status_badge = "🟡 BLOCKED"
		
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
		var status_badge := "🟢 PASS"
		if r["status"] == "FAIL":
			status_badge = "🔴 FAIL"
		elif r["status"] == "BLOCKED":
			status_badge = "🟡 BLOCKED"
		
		md += "### %s — %s (%s)\n\n" % [r["id"], r["title"], status_badge]
		md += "- **Description**: %s\n" % r.get("description", "")
		md += "- **Status**: %s\n" % status_badge
		md += "- **Duration**: %.1fs\n" % r.get("duration", 0.0)
		md += "- **GIF Evidence**: `artifacts/gameplay-tests/%s`\n" % r["gif_path"].get_file()
		md += "- **Expected Result**: %s\n" % r.get("expected_result", "")
		md += "- **Actual Result**: %s\n\n" % r.get("actual_result", "")
		
		md += "#### Assertions Executed:\n"
		for a in r.get("assertions", []):
			var mark := "✅" if a["passed"] else "❌"
			md += "- %s %s\n" % [mark, a["description"]]
		
		if r.get("root_cause", "") != "":
			md += "\n#### Root Cause:\n%s\n" % r["root_cause"]
		
		if r.get("reproduction_steps", []).size() > 0:
			md += "\n#### Reproduction Steps:\n"
			for step in r["reproduction_steps"]:
				md += "%s\n" % step
		
		if r.get("related_sources", []).size() > 0:
			md += "\n#### Related Source Files:\n"
			for src in r["related_sources"]:
				md += "- `%s`\n" % src
		
		if r.get("notes", "") != "":
			md += "\n**Notes**: %s\n" % r["notes"]
		
		md += "\n---\n\n"
	
	var report_path := "artifacts/gameplay-tests/test_report.md"
	var f := FileAccess.open(report_path, FileAccess.WRITE)
	if f:
		f.store_string(md)
		f.close()
		print("[VisualTestRunner] Generated detailed Markdown report at %s" % report_path)

func _generate_html_dashboard(p_results: Array[Dictionary], passed: int, failed: int, blocked: int) -> void:
	var total := passed + failed + blocked
	var timestamp := Time.get_datetime_string_from_system()
	
	var html := """<!DOCTYPE html>
<html lang="en">
<head>
	<meta charset="UTF-8">
	<meta name="viewport" content="width=device-width, initial-scale=1.0">
	<title>Couple Chaos — Gameplay & Visual Regression Dashboard</title>
	<style>
		:root {
			--bg-main: #121417;
			--bg-card: #1c2026;
			--bg-card-hover: #232932;
			--text-main: #e2e8f0;
			--text-muted: #94a3b8;
			--accent: #38bdf8;
			--pass: #22c55e;
			--pass-bg: rgba(34, 197, 94, 0.15);
			--fail: #ef4444;
			--fail-bg: rgba(239, 68, 68, 0.15);
			--blocked: #f59e0b;
			--blocked-bg: rgba(245, 158, 11, 0.15);
			--border: #334155;
		}
		* { box-sizing: border-box; margin: 0; padding: 0; }
		body {
			background: var(--bg-main);
			color: var(--text-main);
			font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
			line-height: 1.5;
			padding: 24px;
		}
		.container { max-width: 1360px; margin: 0 auto; }
		header {
			display: flex;
			flex-wrap: wrap;
			justify-content: space-between;
			align-items: center;
			padding-bottom: 24px;
			border-bottom: 1px solid var(--border);
			margin-bottom: 24px;
		}
		h1 { font-size: 26px; font-weight: 700; color: #fff; display: flex; align-items: center; gap: 10px; }
		.subtitle { font-size: 14px; color: var(--text-muted); margin-top: 4px; }
		.stats-bar {
			display: flex;
			gap: 16px;
			margin-bottom: 24px;
			flex-wrap: wrap;
		}
		.stat-pill {
			background: var(--bg-card);
			border: 1px solid var(--border);
			border-radius: 8px;
			padding: 12px 20px;
			flex: 1;
			min-width: 140px;
		}
		.stat-label { font-size: 12px; text-transform: uppercase; color: var(--text-muted); font-weight: 600; }
		.stat-val { font-size: 24px; font-weight: 700; margin-top: 4px; }
		.stat-pass { color: var(--pass); }
		.stat-fail { color: var(--fail); }
		.stat-blocked { color: var(--blocked); }
		
		.test-grid {
			display: grid;
			grid-template-columns: repeat(auto-fill, minmax(420px, 1fr));
			gap: 20px;
		}
		.test-card {
			background: var(--bg-card);
			border: 1px solid var(--border);
			border-radius: 10px;
			overflow: hidden;
			display: flex;
			flex-direction: column;
			transition: transform 0.15s ease, border-color 0.15s ease;
		}
		.test-card:hover {
			border-color: #475569;
			transform: translateY(-2px);
		}
		.card-header {
			padding: 14px 18px;
			display: flex;
			justify-content: space-between;
			align-items: center;
			background: rgba(255, 255, 255, 0.02);
			border-bottom: 1px solid var(--border);
		}
		.test-title-group { display: flex; align-items: center; gap: 10px; }
		.test-id {
			font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
			font-size: 13px;
			font-weight: 700;
			background: #0f172a;
			padding: 3px 8px;
			border-radius: 4px;
			color: #38bdf8;
			border: 1px solid #1e293b;
		}
		.test-title { font-size: 15px; font-weight: 600; color: #f8fafc; }
		.badge {
			padding: 4px 10px;
			border-radius: 9999px;
			font-size: 11px;
			font-weight: 700;
			text-transform: uppercase;
			letter-spacing: 0.5px;
		}
		.badge-pass { background: var(--pass-bg); color: var(--pass); border: 1px solid rgba(34, 197, 94, 0.4); }
		.badge-fail { background: var(--fail-bg); color: var(--fail); border: 1px solid rgba(239, 68, 68, 0.4); }
		.badge-blocked { background: var(--blocked-bg); color: var(--blocked); border: 1px solid rgba(245, 158, 11, 0.4); }
		
		.card-media {
			background: #000;
			width: 100%;
			aspect-ratio: 16 / 9;
			position: relative;
			display: flex;
			align-items: center;
			justify-content: center;
		}
		.card-media img {
			width: 100%;
			height: 100%;
			object-fit: cover;
			display: block;
		}
		.card-body {
			padding: 16px 18px;
			display: flex;
			flex-direction: column;
			gap: 12px;
			flex: 1;
		}
		.desc-text { font-size: 13px; color: var(--text-muted); }
		.section-box {
			background: #0f172a;
			border: 1px solid #1e293b;
			border-radius: 6px;
			padding: 10px 12px;
			font-size: 12px;
		}
		.section-label {
			font-weight: 700;
			text-transform: uppercase;
			font-size: 10px;
			color: #64748b;
			margin-bottom: 4px;
			letter-spacing: 0.5px;
		}
		.assertion-list { list-style: none; display: flex; flex-direction: column; gap: 4px; }
		.assertion-item { display: flex; gap: 6px; font-size: 12px; }
		.mark-pass { color: var(--pass); font-weight: bold; }
		.mark-fail { color: var(--fail); font-weight: bold; }
		
		.error-box {
			background: rgba(239, 68, 68, 0.1);
			border: 1px solid rgba(239, 68, 68, 0.3);
			border-radius: 6px;
			padding: 8px 12px;
			font-size: 12px;
			color: #fca5a5;
		}
		.sources-list { display: flex; flex-wrap: wrap; gap: 6px; }
		.source-tag {
			font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
			font-size: 11px;
			background: #1e293b;
			padding: 2px 6px;
			border-radius: 4px;
			color: #cbd5e1;
		}
		.duration-tag {
			font-size: 11px;
			color: var(--text-muted);
			margin-left: auto;
		}
		footer {
			margin-top: 36px;
			padding-top: 20px;
			border-top: 1px solid var(--border);
			text-align: center;
			font-size: 13px;
			color: var(--text-muted);
		}
	</style>
</head>
<body>
<div class="container">
	<header>
		<div>
			<h1>🎮 Couple Chaos — Visual Gameplay & Regression Dashboard</h1>
			<div class="subtitle">Godot 4.7.2 Stylized Low-Poly Life Simulation • Rendered Frame Captures (960x540, 30 FPS)</div>
		</div>
		<div style="text-align: right;">
			<div class="subtitle">Generated: """ + timestamp + """</div>
		</div>
	</header>

	<div class="stats-bar">
		<div class="stat-pill">
			<div class="stat-label">Total Scenarios</div>
			<div class="stat-val">""" + str(total) + """</div>
		</div>
		<div class="stat-pill">
			<div class="stat-label">Passed</div>
			<div class="stat-val stat-pass">""" + str(passed) + """</div>
		</div>
		<div class="stat-pill">
			<div class="stat-label">Failed</div>
			<div class="stat-val stat-fail">""" + str(failed) + """</div>
		</div>
		<div class="stat-pill">
			<div class="stat-label">Blocked</div>
			<div class="stat-val stat-blocked">""" + str(blocked) + """</div>
		</div>
	</div>

	<div class="test-grid">
"""
	
	for r in p_results:
		var status_str: String = r.get("status", "PASS")
		var badge_class := "badge-pass"
		if status_str == "FAIL":
			badge_class = "badge-fail"
		elif status_str == "BLOCKED":
			badge_class = "badge-blocked"
		
		var gif_filename: String = r["gif_path"].get_file()
		
		html += """
		<div class="test-card">
			<div class="card-header">
				<div class="test-title-group">
					<span class="test-id">""" + r["id"] + """</span>
					<span class="test-title">""" + r["title"] + """</span>
				</div>
				<div style="display: flex; align-items: center; gap: 8px;">
					<span class="duration-tag">""" + ("%.1fs" % r.get("duration", 0.0)) + """</span>
					<span class="badge """ + badge_class + """">""" + status_str + """</span>
				</div>
			</div>
			<div class="card-media">
				<img src="./""" + gif_filename + """" alt=\"""" + r["title"] + """" loading="lazy" />
			</div>
			<div class="card-body">
				<div class="desc-text">""" + r.get("description", "") + """</div>
				
				<div class="section-box">
					<div class="section-label">Assertions Validated (""" + str(r.get("assertions", []).size()) + """)</div>
					<ul class="assertion-list">
"""
		for a in r.get("assertions", []):
			var mark_cls := "mark-pass" if a["passed"] else "mark-fail"
			var mark_sym := "✓" if a["passed"] else "✗"
			html += "						<li class=\"assertion-item\"><span class=\"" + mark_cls + "\">" + mark_sym + "</span><span>" + a["description"] + "</span></li>\n"
		
		html += """					</ul>
				</div>
"""
		if r.get("root_cause", "") != "":
			html += """
				<div class="error-box">
					<strong>Root Cause / Issue:</strong> """ + r["root_cause"] + """
				</div>
"""
		
		if r.get("related_sources", []).size() > 0:
			html += """
				<div>
					<div class="section-label">Related Sources</div>
					<div class="sources-list">
"""
			for src in r["related_sources"]:
				html += "						<span class=\"source-tag\">" + src + "</span>\n"
			html += """					</div>
				</div>
"""
		
		html += """
			</div>
		</div>
"""
	
	html += """
	</div>

	<footer>
		Couple Chaos Godot 4.7.2 QA Automated Visual Testing Suite • Branch: <code>qa/gameplay-test-coverage</code>
	</footer>
</div>
</body>
</html>
"""
	
	var html_path := "artifacts/gameplay-tests/index.html"
	var f := FileAccess.open(html_path, FileAccess.WRITE)
	if f:
		f.store_string(html)
		f.close()
		print("[VisualTestRunner] Generated visual dashboard at %s" % html_path)
