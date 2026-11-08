extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
 if ok: print("PASS: ", message)
 else:
  failures += 1
  printerr("FAIL: ", message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 OS.set_environment("COUPLE_VISUAL", "kenney")
 var scene = load("res://scenes/main.tscn").instantiate()
 root.add_child(scene)
 current_scene = scene
 scene.get_node("GameUI").start_game()
 await create_timer(0.3).timeout
 var player = get_first_node_in_group("players")
 var hammer = get_nodes_in_group("interactables").filter(func(item): return item is CharacterBody3D and item.get("prop_kind") == "hammer")[0]
 var model = player.visual.get_child(0)
 hammer.interact(player)
 await create_timer(0.35).timeout
 Input.action_press("p1_swing")
 await create_timer(0.06).timeout
 Input.action_release("p1_swing")
 check(model.animation.current_animation == "attack-melee-right", "Q input selects Kenney melee clip")
 check(player.held_pillow == hammer and hammer.holder == player, "Q swing keeps hammer held")
 var marker = model.get_hand_anchor()
 check(marker != null and player.hold_anchor.global_position.distance_to(marker.global_position + player.facing * 0.1) < 0.15, "player hold point follows Kenney hand marker")
 var anchor_before: Vector3 = marker.global_position
 player.visual.rotation.y += PI/2
 await process_frame
 await process_frame
 check(marker.global_position.distance_to(anchor_before) > 0.03, "hand marker follows player yaw")
 await create_timer(0.45).timeout
 check(model.animation.current_animation == "holding-both" and player.held_pillow == hammer, "swing returns to hold")
 OS.unset_environment("COUPLE_VISUAL")
 scene.queue_free()
 await process_frame
 print("KENNEY_HAMMER_RESULT failures=", failures)
 quit(0 if failures == 0 else 1)
