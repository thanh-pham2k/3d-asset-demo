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
 root.add_child(sm)
 root.add_child(cm)
 cm.setup(sm)
 
 # 1. Generation of 3 challenges
 cm.generate_round_challenges(1)
 check(cm.active_challenges.size() == 3, "generates exactly 3 challenges per round")
 
 # Verify unique IDs
 var ids := []
 for ch in cm.active_challenges:
  if not ch["id"] in ids:
   ids.append(ch["id"])
 check(ids.size() == 3, "all 3 generated challenges are distinct")
 
 # 2. Force a specific known challenge for deterministic testing
 var test_ch := {
  "id": "smash_items",
  "title": "Kẻ Đập Phá",
  "description": "Làm vỡ 2 đồ vật dễ vỡ",
  "target": 2,
  "current": 0,
  "completed": false,
  "reward": 500,
  "event_type": "prop_broken",
 }
 var arr: Array[Dictionary] = [test_ch]
 cm.active_challenges = arr
 
 var completed_events := []
 cm.challenge_completed.connect(func(idx, ch): completed_events.append(ch))
 
 # 3. Trigger 1st event
 sm.chaos_event.emit("prop_broken", {"prop_kind": "vase", "points": 350})
 check(test_ch["current"] == 1 and not test_ch["completed"], "challenge progress increments on matching event")
 check(completed_events.is_empty(), "not completed before reaching target")
 
 # 4. Trigger 2nd event (reaches target)
 var score_before = sm.score
 sm.chaos_event.emit("prop_broken", {"prop_kind": "bottle", "points": 350})
 check(test_ch["current"] == 2 and test_ch["completed"], "challenge marks completed on reaching target")
 check(completed_events.size() == 1, "challenge_completed signal emitted")
 check(sm.score == score_before + 500, "challenge reward bonus added to ScoreManager")
 check(cm.get_completed_count() == 1, "get_completed_count returns 1")
 
 # 5. Scaling targets for round 2
 cm.generate_round_challenges(2)
 check(cm.active_challenges.size() == 3, "round 2 generates 3 challenges with scaled rewards")
 
 # Cleanup
 cm.queue_free()
 sm.queue_free()
 await process_frame
 
 print("CHALLENGE_RESULT failures=", failures)
 quit(0 if failures == 0 else 1)
