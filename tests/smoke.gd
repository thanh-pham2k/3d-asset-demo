extends SceneTree
var failures := 0
func check(value: bool, label: String) -> void:
 if value: print("PASS: ", label)
 else:
  failures += 1
  printerr("FAIL: ", label)
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var scene = load("res://scenes/main.tscn").instantiate()
 root.add_child(scene)
 current_scene = scene
 await create_timer(0.15).timeout
 var players = get_nodes_in_group("players")
 var items = get_nodes_in_group("interactables")
 check(players.size() == 1, "one player")
 var p1 = players[0]
 var pillow = null
 var sofa = null
 var bed = null
 var lamp = null
 var door = null
 for item in items:
  if item is CharacterBody3D: pillow = item
  elif item.kind == "sofa": sofa = item
  elif item.kind == "bed": bed = item
  elif item.kind == "lamp": lamp = item
  elif item.kind == "door": door = item
 check(pillow != null and sofa != null and bed != null and lamp != null and door != null, "all interactables present")
 var old1 = p1.position
 Input.action_press("p1_left")
 await create_timer(0.3).timeout
 Input.action_release("p1_left")
 check(p1.position.distance_to(old1)>0.15, "player moves through InputMap")
 var dash_start = p1.global_position
 Input.action_press("p1_dash")
 await create_timer(0.12).timeout
 Input.action_release("p1_dash")
 check(p1.global_position.distance_to(dash_start) > 0.5 and p1.dash_cooldown_remaining > 0.0, "dash moves player and starts cooldown")
 var interact_key = InputEventKey.new()
 interact_key.physical_keycode = KEY_E
 var throw_key = InputEventKey.new()
 throw_key.physical_keycode = KEY_F
 check(InputMap.action_has_event("p1_throw", throw_key), "F throw binding")
 var dash_key = InputEventKey.new()
 dash_key.physical_keycode = KEY_SPACE
 check(InputMap.action_has_event("p1_interact", interact_key) and InputMap.action_has_event("p1_dash", dash_key), "E and Space bindings")
 p1.global_position = Vector3(-8.5,0,-3.8)
 await create_timer(0.1).timeout
 Input.action_press("p1_left")
 Input.action_press("p1_up")
 await create_timer(1.0).timeout
 Input.action_release("p1_left")
 Input.action_release("p1_up")
 check(p1.global_position.x >= -8.74 and p1.global_position.z >= -4.24, "wall collision keeps player in room")
 p1.global_position = Vector3(-0.6,0,0)
 p1.facing = Vector3.RIGHT
 pillow.global_position = Vector3(-0.4,0.2,0)
 pillow.interact(p1)
 check(pillow.holder == p1, "pillow pickup")
 await process_frame
 Input.action_press("p1_throw")
 await physics_frame
 await physics_frame
 Input.action_release("p1_throw")
 check(pillow.state == pillow.State.THROWN and p1.held_pillow == null, "throw transitions")
 await create_timer(1.2).timeout
 check(pillow.state == pillow.State.IDLE, "thrown pillow lands")
 pillow.interact(p1)
 check(p1.held_pillow == pillow, "pillow can be picked up again")
 pillow.throw_from(p1)
 sofa.interact(p1)
 check(p1.resting == sofa, "sofa rest")
 sofa.interact(p1)
 check(p1.resting == null and p1.collision_layer == 2, "sofa stand restores collision")
 bed.interact(p1)
 check(p1.resting == bed, "bed rest")
 bed.interact(p1)
 check(p1.resting == null, "bed wake")
 p1.global_position = lamp.global_position + Vector3(0,0,0.6)
 p1.interaction_cooldown = 0
 var old_lamp = lamp.toggle
 Input.action_press("p1_interact")
 await physics_frame
 await physics_frame
 Input.action_release("p1_interact")
 check(lamp.toggle != old_lamp and lamp.light.visible == lamp.toggle, "lamp toggles through player input")
 door.interact(p1)
 check(door.toggle, "door toggles")
 var swapped = load("res://scenes/player.tscn").instantiate()
 swapped.config = PlayerConfig.new()
 swapped.config.visual_scene = load("res://tests/swap_visual.tscn")
 swapped.position = Vector3(0,0,1)
 scene.add_child(swapped)
 await physics_frame
 await physics_frame
 check(swapped.visual.get_child(0).last_state == "updated", "alternate visual receives animation state")
 check(swapped.hold_anchor != null and swapped.collision_layer == 2, "alternate visual preserves gameplay components")
 swapped.queue_free()
 print("SMOKE_RESULT failures=", failures)
 quit(0 if failures == 0 else 1)
