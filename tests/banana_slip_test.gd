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
 
 var p1 = get_first_node_in_group("players")
 var ui = scene.get_node("GameUI")
 ui.start_game()
 await create_timer(0.15).timeout
 
 var HazardBananaScript = load("res://scripts/cleaning/hazard_banana.gd")
 var banana = HazardBananaScript.new()
 scene.add_child(banana)
 banana.global_position = Vector3(0, 0.05, 0)
 
 # 1. Test Player Stepping on Banana -> Slip
 p1.global_position = Vector3(0, 0, -1.0)
 p1.facing = Vector3(0, 0, 1) # facing banana
 p1.velocity = Vector3(0, 0, 2.0)
 
 # Move onto banana
 p1.global_position = Vector3(0, 0, 0)
 await create_timer(0.2).timeout
 
 check(p1.slip_timer > 0.0 or p1.reaction > 0.0, "stepping on banana peel triggers slip state")
 check(p1.velocity.length() > 0.5, "slip creates forward momentum slide")
 
 # 2. Test comic drop of held item on slip
 var PillowScript = load("res://scripts/pillow.gd")
 var dummy_pillow = PillowScript.new()
 dummy_pillow.prop_kind = "pillow"
 scene.add_child(dummy_pillow)
 dummy_pillow.global_position = Vector3(5, 0.2, 5)
 dummy_pillow.interact(p1)
 check(p1.held_pillow == dummy_pillow, "player holds item before slip")
 
 # Trigger slip while holding
 p1.slip_cooldown = 0.0
 p1.slip_timer = 0.0
 var slipped = p1.slip(Vector3.FORWARD)
 check(slipped, "slip successfully triggered")
 check(p1.held_pillow == null, "player comically drops/flings held item on slip")
 
 # 3. Test Recovery after slip ends
 await create_timer(0.8).timeout
 check(p1.slip_timer == 0.0, "player slip timer expires and controls recover")
 check(p1.visual.rotation.x > -0.1, "player uprights visual orientation after recovery")
 
 # 4. Test Banana Peel Pickup & Throw
 var banana2 = HazardBananaScript.new()
 scene.add_child(banana2)
 banana2.global_position = Vector3(2, 0.05, 2)
 p1.global_position = Vector3(2, 0, 2)
 await create_timer(0.1).timeout
 
 banana2.interact(p1)
 check(p1.held_pillow == banana2, "player can pick up banana peel")
 check(banana2.held, "banana peel marks held = true")
 
 banana2.throw_from(p1)
 check(p1.held_pillow == null and not banana2.held, "player can throw banana peel")
 check(banana2.linear_velocity.length() > 1.0, "thrown banana peel has arc velocity")
 
 # Cleanup
 scene.queue_free()
 await process_frame
 
 print("BANANA_SLIP_RESULT failures=", failures)
 quit(0 if failures == 0 else 1)
