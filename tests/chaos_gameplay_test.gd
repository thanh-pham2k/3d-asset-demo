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
 var scene = load("res://scenes/main.tscn").instantiate()
 root.add_child(scene)
 current_scene = scene
 
 var ui = scene.get_node("GameUI")
 var p1 = get_first_node_in_group("players")
 var camera = scene.find_children("*", "Camera3D", true, false)[0]
 var score_mgr = scene.get_node("ScoreManager")
 var round_mgr = scene.get_node("RoundManager")
 var challenge_mgr = scene.get_node("ChallengeManager")
 
 check(is_instance_valid(score_mgr), "ScoreManager present in scene")
 check(is_instance_valid(round_mgr), "RoundManager present in scene")
 check(is_instance_valid(challenge_mgr), "ChallengeManager present in scene")
 
 # 1. Start Round
 round_mgr.round_duration = 3.0
 ui.start_game()
 await create_timer(0.1).timeout
 check(round_mgr.current_state == round_mgr.State.PLAYING, "RoundManager is PLAYING after UI start")
 check(ui.hud.visible, "HUD is visible during gameplay")
 
 # 2. Test Dash Feel & Camera Shake
 var initial_trauma: float = camera.trauma
 p1.global_position = Vector3(0, 0, 0)
 p1.dash_cooldown_remaining = 0.0
 Input.action_press("p1_dash")
 await create_timer(0.05).timeout
 Input.action_release("p1_dash")
 check(p1.dash_remaining > 0.0, "dash activates on Space")
 check(camera.trauma > initial_trauma, "dash imparts screen shake trauma to camera")
 
 # 3. Test Hammer Smash on Breakable Vase
 var interactables = get_nodes_in_group("interactables")
 var hammer = interactables.filter(func(n): return n is CharacterBody3D and n.get("prop_kind") == "hammer")[0]
 var vase = interactables.filter(func(n): return n is RigidBody3D and n.get("prop_kind") == "vase")[0]
 
 p1.global_position = hammer.global_position
 hammer.interact(p1)
 check(p1.held_pillow == hammer, "player picked up toy hammer")
 
 # Position player facing vase
 vase.global_position = Vector3(1.0, 0.25, 0.0)
 p1.global_position = Vector3(0.5, 0.0, 0.0)
 p1.facing = Vector3.RIGHT
 
 var score_before: int = score_mgr.score
 Input.action_press("p1_swing")
 await create_timer(0.05).timeout
 Input.action_release("p1_swing")
 await create_timer(0.2).timeout
 
 check(score_mgr.score > score_before, "hammer hit on vase awards score")
 check(score_mgr.combo_multiplier > 1.0, "combo multiplier increased")
 check(not is_instance_valid(vase) or vase.broken, "vase breaks on strong hammer impact")
 
 # 4. Test Chain Reaction via Thrown Prop
 var boxes = get_nodes_in_group("interactables").filter(func(n): return is_instance_valid(n) and n is RigidBody3D and n.get("prop_kind") == "stack_box")
 var chair = get_nodes_in_group("interactables").filter(func(n): return is_instance_valid(n) and n is RigidBody3D and n.get("prop_kind") == "chair")[0]
 
 if boxes.size() >= 2:
  boxes[0].global_position = Vector3(0.0, 0.25, 2.0)
  boxes[1].global_position = Vector3(0.0, 0.70, 2.0)
  chair.global_position = Vector3(0.5, 0.40, 2.0)
  
  # Trigger chain impulse
  boxes[0].receive_impact(Vector3(3.5, 0.0, 0.0), p1)
  await create_timer(0.3).timeout
  check(boxes[0].linear_velocity.length() > 0.1 or score_mgr.props_hit > 0, "prop cascade physics responds to impact")
 
 # 5. Camera Trauma Decays
 await create_timer(0.5).timeout
 check(camera.trauma < 0.4, "camera shake trauma decays smoothly")
 
 # 6. Round Timer Expiration and Results Screen
 await create_timer(2.5).timeout # wait for 3.0s round duration to expire
 check(round_mgr.current_state == round_mgr.State.RESULTS, "round transitions to RESULTS on timeout")
 check(ui.results_panel.visible, "results panel is shown")
 check(not ui.results_rank.text.is_empty(), "rank is displayed on results screen")
 check(not ui.results_score.text.is_empty(), "total score is displayed on results screen")
 
 # Cleanup
 scene.queue_free()
 paused = false
 await process_frame
 
 print("CHAOS_GAMEPLAY_RESULT failures=", failures)
 quit(0 if failures == 0 else 1)
