extends SceneTree

var failures := 0
func check(value: bool, label: String) -> void:
 if value:
  print("PASS: ", label)
 else:
  failures += 1
  printerr("FAIL: ", label)

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var sm = load("res://scripts/score_manager.gd").new()
 var cm = load("res://scripts/challenge_manager.gd").new()
 var rm = load("res://scripts/round_manager.gd").new()
 root.add_child(sm)
 root.add_child(cm)
 root.add_child(rm)
 
 rm.setup(sm, cm)
 
 # 1. Initial State
 check(rm.current_state == rm.State.MENU, "round manager starts in MENU state")
 check(rm.round_number == 1, "starts at round 1")
 
 # 2. Start Round
 rm.round_duration = 2.0 # short duration for test
 rm.start_round()
 check(rm.current_state == rm.State.PLAYING, "start_round transitions to PLAYING state")
 check(rm.time_remaining == 2.0, "round timer initialized to round_duration")
 check(cm.active_challenges.size() == 3, "3 challenges generated on round start")
 
 # 3. Pause and Resume
 rm.pause_round()
 check(rm.current_state == rm.State.PAUSED, "pause_round transitions to PAUSED")
 check(paused, "scene tree is paused")
 
 rm.resume_round()
 check(rm.current_state == rm.State.PLAYING, "resume_round transitions back to PLAYING")
 check(not paused, "scene tree is unpaused")
 
 # 4. Round Completion via timer
 var ended_summary := {}
 rm.round_ended.connect(func(summary): ended_summary.merge(summary))
 
 # Simulate time passing
 rm.time_remaining = 0.05
 await create_timer(0.15).timeout
 
 check(rm.current_state == rm.State.RESULTS, "timer expiration transitions to RESULTS state")
 check(ended_summary.has("score") and ended_summary.has("rank") and ended_summary.has("round_number"), "round_ended signal emits complete summary")
 check(ended_summary["round_number"] == 1, "summary reports correct round number")
 
 # 5. Next Round
 rm.next_round()
 check(rm.round_number == 2, "next_round increments round_number to 2")
 check(rm.current_state == rm.State.PLAYING, "next_round transitions back to PLAYING")
 check(rm.time_remaining == 2.0, "next_round resets round timer")
 
 # 6. Retry Round
 rm.round_number = 5
 rm.retry_round()
 check(rm.round_number == 5, "retry_round preserves current round number")
 check(rm.current_state == rm.State.PLAYING, "retry_round sets state to PLAYING")
 
 # Cleanup
 rm.queue_free()
 cm.queue_free()
 sm.queue_free()
 paused = false
 await process_frame
 
 print("ROUND_LOOP_RESULT failures=", failures)
 quit(0 if failures == 0 else 1)
