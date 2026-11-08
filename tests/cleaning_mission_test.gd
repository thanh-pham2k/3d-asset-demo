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
 var MissionManagerScript = load("res://scripts/cleaning/mission_manager.gd")
 var PlacementZoneScript = load("res://scripts/cleaning/placement_zone.gd")
 var PhysicsPropScript = load("res://scripts/physics_prop.gd")
 var HazardBananaScript = load("res://scripts/cleaning/hazard_banana.gd")
 
 var mm = MissionManagerScript.new()
 root.add_child(mm)
 
 # 1. Check Configuration & Targets
 check(mm.time_remaining == 120.0, "mission starts with 120s duration")
 check(mm.targets["basket"] == 5, "target basket items = 5")
 check(mm.targets["trash"] == 4, "target trash items = 4")
 check(mm.targets["sofa"] == 3, "target sofa pillows = 3")
 check(mm.targets["banana"] == 2, "target banana peels = 2")
 
 # 2. Create Dummy Zones
 var basket = PlacementZoneScript.new()
 basket.zone_type = "basket"
 basket.capacity = 7
 root.add_child(basket)
 
 var trash = PlacementZoneScript.new()
 trash.zone_type = "trash"
 trash.capacity = 8
 root.add_child(trash)
 
 var sofa_slots := []
 for i in 3:
  var s = PlacementZoneScript.new()
  s.zone_type = "sofa_slot"
  s.capacity = 1
  root.add_child(s)
  sofa_slots.append(s)
 
 mm.setup_zones(basket, trash, sofa_slots)
 
 # 3. Start Mission
 mm.start_mission()
 check(mm.current_state == mm.State.RUNNING, "mission state transitions to RUNNING")
 
 # 4. Track objective updates
 var updates := {}
 mm.objective_updated.connect(func(id, cur, tgt, comp): updates[id] = {"current": cur, "target": tgt, "completed": comp})
 
 # Simulate 5 items placed in basket
 for i in 5:
  var p = PhysicsPropScript.new()
  p.prop_kind = "toy"
  basket.items_inside.append(p)
 basket.count_changed.emit(5, 7)
 
 check(mm.progress["basket"] == 5, "basket progress reaches 5")
 check(updates.has("basket") and updates["basket"]["completed"] == true, "basket objective marked completed")
 
 # Simulate removing 1 item from basket
 basket.items_inside.remove_at(0)
 basket.count_changed.emit(4, 7)
 check(mm.progress["basket"] == 4, "basket progress updates to 4 when item removed")
 check(updates["basket"]["completed"] == false, "basket objective unmarked completed when count drops")
 
 # Restore basket to 5
 var p_rest = PhysicsPropScript.new()
 p_rest.prop_kind = "toy"
 basket.items_inside.append(p_rest)
 basket.count_changed.emit(5, 7)
 
 # 5. Simulate Trash and Banana in trash bin
 for i in 4:
  var t = PhysicsPropScript.new()
  t.prop_kind = "bottle"
  trash.items_inside.append(t)
 
 for i in 2:
  var b = HazardBananaScript.new()
  trash.items_inside.append(b)
 
 trash.item_placed.emit(trash.items_inside[0], trash)
 check(mm.progress["trash"] == 4, "trash progress reaches 4")
 check(mm.progress["banana"] == 2, "banana progress reaches 2")
 
 # 6. Simulate 3 pillows on sofa
 for i in 3:
  var pil = PhysicsPropScript.new()
  pil.prop_kind = "pillow"
  sofa_slots[i].items_inside.append(pil)
  sofa_slots[i].count_changed.emit(1, 1)
 
 check(mm.progress["sofa"] == 3, "sofa pillows progress reaches 3")
 
 # 7. Verify Win Condition Triggered
 check(mm.current_state == mm.State.WON, "all 4 objectives met triggers WON state")
 check(mm.is_all_completed(), "is_all_completed() returns true")
 
 # 8. Test Lose Condition on Timeout
 var mm_lose = MissionManagerScript.new()
 root.add_child(mm_lose)
 mm_lose.start_mission()
 mm_lose.time_remaining = 0.05
 
 var lost_events := []
 mm_lose.mission_lost.connect(func(summary): lost_events.append(summary))
 
 await create_timer(0.15).timeout
 check(mm_lose.current_state == mm_lose.State.LOST, "timer expiration before completion triggers LOST state")
 check(lost_events.size() == 1, "mission_lost signal emitted on timeout")
 
 # Cleanup
 mm.queue_free()
 mm_lose.queue_free()
 basket.queue_free()
 trash.queue_free()
 for s in sofa_slots: s.queue_free()
 paused = false
 await process_frame
 
 print("CLEANING_MISSION_RESULT failures=", failures)
 quit(0 if failures == 0 else 1)
