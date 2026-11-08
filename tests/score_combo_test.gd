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
 root.add_child(sm)
 
 # 1. Initial State
 check(sm.score == 0 and sm.combo_multiplier == 1.0, "initial score is 0 and combo is 1.0")
 
 # 2. Register low velocity hit (anti-farm check)
 var dummy_prop = Node3D.new()
 root.add_child(dummy_prop)
 var pts_low = sm.register_prop_hit(dummy_prop, 0.5, false, Vector3.ZERO)
 check(pts_low == 0 and sm.score == 0, "low velocity bump (<1.2) awards 0 points (anti-farm)")
 
 # 3. Register valid hit
 var pts_valid = sm.register_prop_hit(dummy_prop, 2.5, false, Vector3.ZERO)
 check(pts_valid > 0 and sm.score == pts_valid, "valid velocity hit awards points")
 check(sm.combo_multiplier > 1.0, "valid hit increases combo multiplier")
 
 # 4. Cooldown prevents instant multi-hit spam on same object
 var pts_spam = sm.register_prop_hit(dummy_prop, 3.0, false, Vector3.ZERO)
 check(pts_spam == 0, "immediate subsequent hit on same object within cooldown awards 0 points")
 
 # 5. Different object scores immediately
 var dummy_prop2 = Node3D.new()
 root.add_child(dummy_prop2)
 var pts_prop2 = sm.register_prop_hit(dummy_prop2, 2.0, false, Vector3.ZERO)
 check(pts_prop2 > 0, "different prop hits score independently")
 
 # 6. Hammer hit scores higher
 var dummy_prop3 = Node3D.new()
 root.add_child(dummy_prop3)
 var score_before = sm.score
 var pts_hammer = sm.register_prop_hit(dummy_prop3, 1.0, true, Vector3.ZERO)
 check(pts_hammer > pts_valid, "hammer smash awards higher base points with combo")
 
 # 7. Prop broken event
 var pts_broken = sm.register_prop_broken(dummy_prop, "vase", Vector3.ZERO)
 check(pts_broken >= 350, "breaking object awards large points bonus")
 check(sm.props_broken == 1, "props broken counter incremented")
 
 # 8. Chain reaction event
 var pts_chain = sm.register_chain_reaction(dummy_prop, dummy_prop2, 2, Vector3.ZERO)
 check(pts_chain >= 250, "chain reaction awards combo chain bonus")
 check(sm.chain_hits == 1, "chain hits counter incremented")
 
 # 9. Dash impact
 var dummy_prop4 = Node3D.new()
 root.add_child(dummy_prop4)
 var pts_dash = sm.register_dash_impact(dummy_prop4, Vector3.ZERO)
 check(pts_dash > 0, "dash impact awards points")
 
 # 10. Combo decay after window
 sm.combo_timer = 0.05
 await create_timer(0.12).timeout
 check(sm.combo_multiplier == 1.0, "combo resets to 1.0 after combo timer expires")
 
 # 11. Rank calculation
 check(sm.get_rank() in ["S", "A", "B", "C", "D"], "rank correctly assigned")
 
 # Cleanup
 dummy_prop.queue_free()
 dummy_prop2.queue_free()
 dummy_prop3.queue_free()
 dummy_prop4.queue_free()
 sm.queue_free()
 await process_frame
 
 print("SCORE_COMBO_RESULT failures=", failures)
 quit(0 if failures == 0 else 1)
