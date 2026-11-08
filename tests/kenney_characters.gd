extends SceneTree
var failures := 0
func check(value: bool, label: String) -> void:
 if value: print("PASS: ", label)
 else:
  failures += 1
  printerr("FAIL: ", label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 for variant in ["boy", "girl"]:
  var visual = load("res://scenes/characters/kenney_%s_visual.tscn" % variant).instantiate()
  root.add_child(visual)
  await process_frame
  check(visual.skeleton is Skeleton3D and visual.skeleton.get_bone_count() >= 7, variant + " skinned skeleton")
  check(visual.get_hand_anchor() != null and visual.animation != null, variant + " hand anchor and AnimationPlayer")
  check(is_equal_approx(visual.model.scale.x, 1.9) and is_zero_approx(visual.model.rotation.y), variant + " scale and forward orientation")
  var mesh = visual.model.find_child("body-mesh", true, false) as MeshInstance3D
  check(mesh != null and mesh.skin != null and mesh.mesh.surface_get_material(0) != null, variant + " skinned mesh and material")
  if variant == "boy":
   var image = (mesh.get_active_material(0) as StandardMaterial3D).albedo_texture.get_image()
   var shirt_color = image.get_pixel(112,300)
   check(shirt_color.r > 0.75 and shirt_color.g > 0.7 and absf(shirt_color.r-shirt_color.g) < 0.1, "boy cream shirt palette")
  visual.update_pose(1.0,false,false,false,false,false,false,1.0)
  check(visual.animation.current_animation == "walk", variant + " walk animation selected")
  var before: float = visual.animation.current_animation_position
  var hand_before: Vector3 = visual.get_hand_anchor().global_position
  var advanced := false
  for frame in 30:
   await process_frame
   if not is_equal_approx(visual.animation.current_animation_position, before): advanced = true
  check(advanced, variant + " animation advances")
  check(visual.get_hand_anchor().global_position.distance_to(hand_before) > 0.005, variant + " hand marker follows animated skeleton")
  visual.update_pose(0.0,false,true,false,false,false,false,2.0)
  check(visual.animation.current_animation == "pick-up", variant + " pickup animation selected")
  visual.update_pose(0.0,false,true,false,false,false,false,2.5)
  check(visual.animation.current_animation == "holding-both", variant + " hold animation selected")
  var adapter = load("res://scripts/animation_controller.gd").new()
  adapter.model = visual
  root.add_child(adapter)
  adapter.trigger_action("hammer", 2.6)
  adapter.apply_state(0.0,false,true,false,false,false,false,2.7)
  check(visual.animation.current_animation == "attack-melee-right" and visual.was_holding, variant + " hammer action selects melee and preserves hold")
  adapter.apply_state(0.0,false,true,false,false,false,false,3.0)
  check(visual.animation.current_animation == "holding-both", variant + " returns to holding after hammer")
  adapter.queue_free()
  visual.update_pose(0.0,false,false,true,false,false,false,3.5)
  check(visual.animation.current_animation == "attack-melee-right", variant + " throw proxy selected")
  visual.queue_free()
 print("KENNEY_RESULT failures=", failures)
 quit(0 if failures == 0 else 1)
