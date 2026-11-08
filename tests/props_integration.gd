extends SceneTree
var failures := 0
func check(value: bool, label: String) -> void:
 if value: print("PASS: ",label)
 else:
  failures += 1
  printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var scene = load("res://scenes/main.tscn").instantiate()
 root.add_child(scene)
 current_scene = scene
 scene.get_node("GameUI").start_game()
 await create_timer(0.3).timeout
 var player = get_first_node_in_group("players")
 var kinds = ["pillow","hammer","bear","box","book","ball"]
 for kind in kinds:
  var item = get_nodes_in_group("interactables").filter(func(n): return n is CharacterBody3D and n.get("prop_kind") == kind)[0]
  player.global_position = Vector3(0,0,1)
  player.facing = Vector3.RIGHT
  item.global_position = Vector3(0.3,0.3,1)
  item.interact(player)
  await create_timer(0.08).timeout
  check(item.holder == player and item.global_position.distance_to(player.hold_anchor.global_position) < 0.15, kind + " pickup and attachment")
  item.throw_from(player)
  check(item.state == item.State.THROWN and player.held_pillow == null, kind + " throw")
  await create_timer(1.5).timeout
  check(item.state == item.State.IDLE and item.available(player), kind + " landing and repick")
 var rigid = get_nodes_in_group("interactables").filter(func(n): return n is RigidBody3D and n.get("prop_kind") == "chair")[0]
 rigid.interact(player)
 check(rigid.held and rigid.freeze and player.held_pillow == rigid, "rigid chair pickup")
 rigid.throw_from(player)
 check(not rigid.freeze and player.held_pillow == null and rigid.linear_velocity.length() > 1, "rigid chair throw")
 await create_timer(1.5).timeout
 check(rigid.available(player), "rigid chair reusable")
 rigid.interact(player)
 rigid.drop_from(player)
 check(not rigid.freeze and player.held_pillow == null, "rigid chair drop")
 var dropped = get_nodes_in_group("interactables").filter(func(n): return n is CharacterBody3D and n.get("prop_kind") == "pillow")[0]
 dropped.interact(player)
 dropped.drop_from(player)
 check(dropped.state == dropped.State.THROWN and player.held_pillow == null, "pillow drop")
 var ui = scene.get_node("GameUI")
 ui.show_main_menu()
 check(paused and ui.menu.visible, "menu pause")
 ui.start_game()
 check(not paused and ui.hud.visible, "menu start")
 var feedback = get_first_node_in_group("chaos_feedback")
 feedback.play_event("pickup", Vector3.ZERO)
 check(feedback.get_node_or_null("FeedbackAudio") != null and feedback.get_node_or_null("FeedbackParticles") != null, "VFX and audio event creates nodes")
 await create_timer(2.0).timeout
 scene.queue_free()
 await process_frame
 print("PROPS_RESULT failures=",failures)
 quit(0 if failures == 0 else 1)
