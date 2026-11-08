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
 var root_node := Node3D.new()
 root.add_child(root_node)
 var boy = load("res://scenes/characters/boy_visual.tscn").instantiate()
 var girl = load("res://scenes/characters/girl_visual.tscn").instantiate()
 root_node.add_child(boy)
 root_node.add_child(girl)
 check(boy.variant_override == 1 and girl.variant_override == 2, "both visual variants instantiate")
 check(boy.skeleton is Skeleton3D and boy.skeleton.get_bone_count() == 6 and girl.skeleton.get_bone_count() == 6, "both models have reusable six-bone Skeleton3D rigs")
 check(boy.right_arm.get_node_or_null("HandAttachment") != null and girl.left_arm.get_node_or_null("HandAttachment") != null, "both models have hand markers")
 check(boy.get_hand_anchor() == boy.right_arm.get_node("HandAttachment") and girl.get_hand_anchor() == girl.right_arm.get_node("HandAttachment"), "both visual adapters expose right hand anchor")
 for face in ["happy", "angry", "surprised", "dizzy", "hurt"]:
  boy.set_expression(face)
  check(boy.expression == face, "expression " + face)
 var adapter = load("res://scripts/animation_controller.gd").new()
 adapter.model = boy
 root_node.add_child(adapter)
 adapter.apply_state(0.0,false,false,false,false,false,false,1.0)
 check(adapter.state == "idle", "idle state")
 adapter.apply_state(1.0,false,false,false,false,false,false,2.0)
 check(adapter.state == "walk", "walk state")
 adapter.apply_state(1.0,true,false,false,false,false,false,3.0)
 check(adapter.state == "run", "run state")
 adapter.apply_state(0.0,false,true,false,false,false,false,4.0)
 check(adapter.state == "pickup", "pickup state")
 adapter.apply_state(0.0,false,true,false,false,false,false,4.3)
 check(adapter.state == "hold", "hold state")
 check(absf(boy.skeleton.get_bone_pose_rotation(boy.skeleton.find_bone("right_arm")).get_euler().x) > 0.8, "hold pose drives arm bone")
 adapter.apply_state(1.0,false,true,false,false,false,false,4.4)
 check(adapter.state == "carry", "carry state")
 adapter.apply_state(0.0,false,false,true,false,false,false,5.0)
 check(adapter.state == "throw" and boy.expression == "surprised", "throw state and expression")
 adapter.apply_state(0.0,false,false,false,false,false,true,6.0)
 check(adapter.state == "hit" and boy.expression == "hurt", "hit state and expression")
 adapter.apply_state(0.0,false,false,false,false,false,true,6.2)
 check(adapter.state == "knockback", "knockback state")
 adapter.apply_state(0.0,false,false,false,false,false,true,6.35)
 check(adapter.state == "fall" and boy.expression == "dizzy", "fall and dizzy state")
 adapter.apply_state(0.0,false,false,false,false,false,false,6.5)
 check(adapter.state == "get_up", "recovery state")
 adapter.trigger_action("hammer", 6.9)
 adapter.apply_state(0.0,false,true,false,false,false,false,7.0)
 check(adapter.state == "hammer_swing", "hammer animation state")
 adapter.apply_state(0.0,false,false,false,true,false,false,8.0)
 check(adapter.state == "sit", "sit state")
 adapter.apply_state(0.0,false,false,false,true,true,false,9.0)
 check(adapter.state == "lie", "lie state")
 adapter.apply_state(0.0,false,false,false,false,false,false,9.0)
 await process_frame
 await process_frame
 var hand: Marker3D = boy.get_hand_anchor()
 var idle_hand := hand.global_position
 adapter.apply_state(0.0,false,true,false,false,false,false,10.0)
 adapter.apply_state(0.0,false,true,false,false,false,false,10.5)
 await process_frame
 await process_frame
 check(hand.global_position.distance_to(idle_hand) > 0.1, "hand marker follows animated bone")
 print("CHARACTER_RESULT failures=", failures)
 quit(0 if failures == 0 else 1)
