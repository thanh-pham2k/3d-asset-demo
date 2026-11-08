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
 var PlacementZoneScript = load("res://scripts/cleaning/placement_zone.gd")
 var PhysicsPropScript = load("res://scripts/physics_prop.gd")
 
 # Create a static floor to support rigid bodies
 var floor_body := StaticBody3D.new()
 floor_body.collision_layer = 1
 floor_body.collision_mask = 7
 var floor_col := CollisionShape3D.new()
 var floor_box := BoxShape3D.new()
 floor_box.size = Vector3(100, 0.1, 100)
 floor_col.shape = floor_box
 floor_col.position.y = -0.05
 floor_body.add_child(floor_col)
 root.add_child(floor_body)
 
 # 1. Test Basket Zone
 var basket = PlacementZoneScript.new()
 basket.zone_type = "basket"
 basket.accepted_prop_kinds = ["toy", "bear", "book"]
 basket.capacity = 3
 root.add_child(basket)
 basket.global_position = Vector3(0, 0, 0)
 
 var toy = PhysicsPropScript.new()
 toy.prop_kind = "toy"
 root.add_child(toy)
 toy.global_position = Vector3(0, 0.2, 0) # inside basket
 
 await create_timer(0.4).timeout
 check(basket.items_inside.has(toy), "valid toy settled inside basket is registered")
 check(basket.get_item_count() == 1, "basket count is 1")
 
 # 2. Test removing item from basket
 toy.global_position = Vector3(5, 0.2, 5) # moved out
 await create_timer(0.3).timeout
 check(not basket.items_inside.has(toy), "item moved out of basket is unregistered")
 check(basket.get_item_count() == 0, "basket count updates to 0 after removal")
 
 # 3. Test Invalid item in Trash Zone gets rejected
 var trash = PlacementZoneScript.new()
 trash.zone_type = "trash"
 trash.accepted_prop_kinds = ["bottle", "cup", "banana"]
 trash.capacity = 4
 root.add_child(trash)
 trash.global_position = Vector3(10, 0, 0)
 
 var rejections := []
 trash.invalid_item_entered.connect(func(_item, _reason): rejections.append(1))
 
 var non_trash = PhysicsPropScript.new()
 non_trash.prop_kind = "toy" # not accepted in trash
 root.add_child(non_trash)
 non_trash.global_position = Vector3(10, 0.2, 0)
 
 await create_timer(0.4).timeout
 check(not trash.items_inside.has(non_trash), "non-trash item is not accepted in trash bin")
 check(rejections.size() >= 1, "invalid_item_entered signal emitted for wrong item in trash")
 
 # 4. Test Valid trash item accepted
 var bottle = PhysicsPropScript.new()
 bottle.prop_kind = "bottle"
 root.add_child(bottle)
 bottle.global_position = Vector3(10, 0.2, 0)
 await create_timer(0.4).timeout
 check(trash.items_inside.has(bottle), "valid bottle is accepted in trash bin")
 
 # 5. Test Sofa Slot Snapping
 var sofa_slot = PlacementZoneScript.new()
 sofa_slot.zone_type = "sofa_slot"
 sofa_slot.accepted_prop_kinds = ["pillow"]
 sofa_slot.capacity = 1
 sofa_slot.snap_items = true
 sofa_slot.snap_position = Vector3(0, 0.1, 0)
 root.add_child(sofa_slot)
 sofa_slot.global_position = Vector3(20, 0, 0)
 
 var pillow = PhysicsPropScript.new()
 pillow.prop_kind = "pillow"
 root.add_child(pillow)
 pillow.global_position = Vector3(20.05, 0.15, 0.05)
 await create_timer(0.4).timeout
 check(sofa_slot.items_inside.has(pillow), "pillow registered in sofa slot")
 check(sofa_slot.is_full(), "sofa slot marked full with 1 pillow")
 check(pillow.global_position.distance_to(sofa_slot.global_position + sofa_slot.snap_position) < 0.05, "pillow snapped to designated slot position")
 
 # Cleanup
 basket.queue_free()
 trash.queue_free()
 sofa_slot.queue_free()
 toy.queue_free()
 non_trash.queue_free()
 bottle.queue_free()
 pillow.queue_free()
 floor_body.queue_free()
 await process_frame
 
 print("PLACEMENT_ZONE_RESULT failures=", failures)
 quit(0 if failures == 0 else 1)
