class_name PlacementZone
extends Node3D

signal item_placed(item: Node3D, zone: Node3D)
signal item_removed(item: Node3D, zone: Node3D)
signal count_changed(current_count: int, capacity: int)
signal invalid_item_entered(item: Node3D, reason: String)

@export var zone_type: String = "basket"
@export var accepted_prop_kinds: Array = []
@export var capacity: int = 5
@export var snap_items: bool = false
@export var snap_position: Vector3 = Vector3.ZERO
@export var snap_rotation: Vector3 = Vector3.ZERO

var items_inside: Array[Node3D] = []
var trigger_area: Area3D
var visual: Node3D
var highlight_mesh: MeshInstance3D

var _candidates: Dictionary = {}
var _rejected_cooldowns: Dictionary = {}

func _ready() -> void:
 add_to_group("placement_zones")
 
 visual = Node3D.new()
 visual.name = "ZoneVisual"
 add_child(visual)
 
 trigger_area = Area3D.new()
 trigger_area.name = "TriggerArea"
 trigger_area.collision_layer = 0
 trigger_area.collision_mask = 4 # detects interactable props (layer 4)
 add_child(trigger_area)
 
 var col := CollisionShape3D.new()
 var box := BoxShape3D.new()
 match zone_type:
  "basket":
   box.size = Vector3(0.68, 0.48, 0.68)
   col.position.y = 0.24
   _build_basket_visual()
   _build_basket_colliders()
  "trash":
   box.size = Vector3(0.52, 0.68, 0.52)
   col.position.y = 0.34
   _build_trash_visual()
   _build_trash_colliders()
  "sofa_slot":
   box.size = Vector3(0.50, 0.40, 0.45)
   col.position.y = 0.18
   _build_sofa_slot_visual()
  _:
   box.size = Vector3(0.6, 0.4, 0.6)
 col.shape = box
 trigger_area.add_child(col)
 trigger_area.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
 if not is_instance_valid(body): return
 var kind: String = body.get("prop_kind") if "prop_kind" in body else ""
 if not accepted_prop_kinds.has(kind) and zone_type == "trash":
  if not _rejected_cooldowns.has(body.get_instance_id()):
   _rejected_cooldowns[body.get_instance_id()] = 1.0
   invalid_item_entered.emit(body, "wrong_item")
   _bounce_out_rejected_item(body)
   var ui = get_tree().get_first_node_in_group("game_ui")
   if ui and ui.has_method("_spawn_floating_text"):
    ui._spawn_floating_text("Không phải rác! (Chỉ bỏ chai, cốc, vỏ chuối)")

func _build_basket_visual() -> void:
 var wicker := Color("c99763")
 var wicker_dark := Color("9c6b3e")
 var rim := Color("dfb180")
 
 Art.box(visual, Vector3(0, 0.03, 0), Vector3(0.70, 0.04, 0.70), wicker_dark)
 Art.box(visual, Vector3(0, 0.22, 0.33), Vector3(0.70, 0.36, 0.06), wicker)
 Art.box(visual, Vector3(0, 0.22, -0.33), Vector3(0.70, 0.36, 0.06), wicker)
 Art.box(visual, Vector3(0.33, 0.22, 0), Vector3(0.06, 0.36, 0.60), wicker)
 Art.box(visual, Vector3(-0.33, 0.22, 0), Vector3(0.06, 0.36, 0.60), wicker)
 Art.box(visual, Vector3(0, 0.41, 0.33), Vector3(0.74, 0.05, 0.08), rim)
 Art.box(visual, Vector3(0, 0.41, -0.33), Vector3(0.74, 0.05, 0.08), rim)
 Art.box(visual, Vector3(0.33, 0.41, 0), Vector3(0.08, 0.05, 0.66), rim)
 Art.box(visual, Vector3(-0.33, 0.41, 0), Vector3(0.08, 0.05, 0.66), rim)
 
 highlight_mesh = Art.box(visual, Vector3(0, 0.42, 0), Vector3(0.78, 0.02, 0.78), Color("ffe082"))
 highlight_mesh.visible = false

func _build_basket_colliders() -> void:
 # Solid physical side walls so thrown items stay in basket
 Art.solid(self, Vector3(0, 0.02, 0), Vector3(0.70, 0.04, 0.70))
 Art.solid(self, Vector3(0, 0.20, 0.34), Vector3(0.70, 0.36, 0.06))
 Art.solid(self, Vector3(0, 0.20, -0.34), Vector3(0.70, 0.36, 0.06))
 Art.solid(self, Vector3(0.34, 0.20, 0), Vector3(0.06, 0.36, 0.62))
 Art.solid(self, Vector3(-0.34, 0.20, 0), Vector3(0.06, 0.36, 0.62))

func _build_trash_visual() -> void:
 var body_color := Color("4a705b")
 var lid_color := Color("334d3f")
 var liner_color := Color("eae6df")
 
 Art.box(visual, Vector3(0, 0.03, 0), Vector3(0.50, 0.04, 0.50), lid_color)
 Art.box(visual, Vector3(0, 0.32, 0.23), Vector3(0.50, 0.56, 0.05), body_color)
 Art.box(visual, Vector3(0, 0.32, -0.23), Vector3(0.50, 0.56, 0.05), body_color)
 Art.box(visual, Vector3(0.23, 0.32, 0), Vector3(0.05, 0.56, 0.42), body_color)
 Art.box(visual, Vector3(-0.23, 0.32, 0), Vector3(0.05, 0.56, 0.42), body_color)
 Art.box(visual, Vector3(0, 0.58, 0.24), Vector3(0.52, 0.05, 0.04), liner_color)
 Art.box(visual, Vector3(0, 0.58, -0.24), Vector3(0.52, 0.05, 0.04), liner_color)
 Art.box(visual, Vector3(0.24, 0.58, 0), Vector3(0.04, 0.05, 0.46), liner_color)
 Art.box(visual, Vector3(-0.24, 0.58, 0), Vector3(0.04, 0.05, 0.46), liner_color)
 
 highlight_mesh = Art.box(visual, Vector3(0, 0.60, 0), Vector3(0.56, 0.02, 0.56), Color("a7f3d0"))
 highlight_mesh.visible = false

func _build_trash_colliders() -> void:
 # Solid physical side walls so thrown items stay in trash can
 Art.solid(self, Vector3(0, 0.02, 0), Vector3(0.50, 0.04, 0.50))
 Art.solid(self, Vector3(0, 0.30, 0.24), Vector3(0.50, 0.56, 0.05))
 Art.solid(self, Vector3(0, 0.30, -0.24), Vector3(0.50, 0.56, 0.05))
 Art.solid(self, Vector3(0.24, 0.30, 0), Vector3(0.05, 0.56, 0.44))
 Art.solid(self, Vector3(-0.24, 0.30, 0), Vector3(0.05, 0.56, 0.44))

func _build_sofa_slot_visual() -> void:
 Art.box(visual, Vector3(0, 0.015, 0), Vector3(0.42, 0.03, 0.35), Color(0.95, 0.88, 0.78, 0.45))
 highlight_mesh = Art.box(visual, Vector3(0, 0.025, 0), Vector3(0.46, 0.015, 0.39), Color("fde68a"))
 highlight_mesh.visible = false

func highlight(active: bool) -> void:
 if is_instance_valid(highlight_mesh):
  highlight_mesh.visible = active

func deposit_held_item(item: Node3D, player: Node3D) -> bool:
 if not is_instance_valid(item): return false
 var kind: String = item.get("prop_kind") if "prop_kind" in item else ""
 
 if not accepted_prop_kinds.has(kind):
  var fx = get_tree().get_first_node_in_group("chaos_feedback")
  if fx: fx.play_event("bonk", global_position)
  var ui = get_tree().get_first_node_in_group("game_ui")
  if ui and ui.has_method("_spawn_floating_text"):
   if zone_type == "trash":
    ui._spawn_floating_text("Không phải rác! (Chỉ bỏ chai, cốc, vỏ chuối)")
   else:
    ui._spawn_floating_text("Không thể đặt vật này vào đây!")
  return false
 
 if is_full():
  var ui = get_tree().get_first_node_in_group("game_ui")
  if ui and ui.has_method("_spawn_floating_text"):
   ui._spawn_floating_text("Nơi này đã đầy!")
  return false
 
 # Calculate deposit target position
 var target_pos := global_position
 match zone_type:
  "basket":
   var rx := randf_range(-0.10, 0.10)
   var rz := randf_range(-0.10, 0.10)
   target_pos = global_position + Vector3(rx, 0.12 + items_inside.size() * 0.06, rz)
  "trash":
   var rx := randf_range(-0.06, 0.06)
   var rz := randf_range(-0.06, 0.06)
   target_pos = global_position + Vector3(rx, 0.20 + items_inside.size() * 0.06, rz)
  "sofa_slot":
   target_pos = global_position + snap_position
 
 # Release from player and place
 if item is CharacterBody3D:
  item.state = item.State.IDLE if "State" in item else 0
  item.holder = null
  item.collision_layer = 4
  item.collision_mask = 7
  item.velocity = Vector3.ZERO
  item.global_position = target_pos
  if "visual" in item and is_instance_valid(item.visual) and snap_items:
   item.visual.rotation = snap_rotation
 elif item is RigidBody3D:
  item.held = false
  item.holder = null
  item.collision_layer = 4
  item.collision_mask = 7
  item.linear_velocity = Vector3.ZERO
  item.angular_velocity = Vector3.ZERO
  item.global_position = target_pos
  item.freeze = snap_items
 
 player.held_pillow = null
 
 if not items_inside.has(item):
  items_inside.append(item)
  item_placed.emit(item, self)
  count_changed.emit(items_inside.size(), capacity)
 
 _play_placement_feedback(item)
 
 var msg := ""
 match zone_type:
  "basket": msg = "Đã bỏ vào giỏ!"
  "trash": msg = "Đã bỏ rác!"
  "sofa_slot": msg = "Đã xếp gối lên sofa!"
 
 var ui = get_tree().get_first_node_in_group("game_ui")
 if ui and ui.has_method("_spawn_floating_text"):
  ui._spawn_floating_text(msg)
 
 return true

func _physics_process(delta: float) -> void:
 var to_erase := []
 for k in _rejected_cooldowns:
  _rejected_cooldowns[k] -= delta
  if _rejected_cooldowns[k] <= 0.0:
   to_erase.append(k)
 for k in to_erase:
  _rejected_cooldowns.erase(k)
 
 var overlapping = trigger_area.get_overlapping_bodies()
 
 # 1. Check all candidates inside trigger
 for body in overlapping:
  if not is_instance_valid(body) or not (body is Node3D): continue
  
  var is_held: bool = body.get("held") == true or body.get("state") == 1
  if is_held:
   if items_inside.has(body):
    items_inside.erase(body)
    item_removed.emit(body, self)
    count_changed.emit(items_inside.size(), capacity)
   _candidates.erase(body)
   continue
  
  var kind: String = body.get("prop_kind") if "prop_kind" in body else ""
  
  if not accepted_prop_kinds.has(kind):
   if zone_type == "trash" and not _rejected_cooldowns.has(body.get_instance_id()):
    _rejected_cooldowns[body.get_instance_id()] = 1.0
    invalid_item_entered.emit(body, "wrong_item")
    _bounce_out_rejected_item(body)
    var ui = get_tree().get_first_node_in_group("game_ui")
    if ui and ui.has_method("_spawn_floating_text"):
     ui._spawn_floating_text("Không phải rác! (Chỉ bỏ chai, cốc, vỏ chuối)")
   continue
  
  var speed := 0.0
  if body is RigidBody3D: speed = body.linear_velocity.length()
  elif body is CharacterBody3D and "velocity" in body: speed = body.velocity.length()
  
  if speed < 1.8:
   _candidates[body] = _candidates.get(body, 0.0) + delta
   if _candidates[body] >= 0.08:
    if not items_inside.has(body) and items_inside.size() < capacity:
     items_inside.append(body)
     item_placed.emit(body, self)
     count_changed.emit(items_inside.size(), capacity)
     _play_placement_feedback(body)
     if snap_items:
      _snap_item(body)
     var msg := ""
     match zone_type:
      "basket": msg = "Đã bỏ vào giỏ!"
      "trash": msg = "Đã bỏ rác!"
      "sofa_slot": msg = "Đã xếp gối lên sofa!"
     var ui = get_tree().get_first_node_in_group("game_ui")
     if ui and ui.has_method("_spawn_floating_text"):
      ui._spawn_floating_text(msg)
  else:
   _candidates[body] = 0.0
 
 # 2. Check existing items inside: did any leave or get picked up?
 var i := items_inside.size() - 1
 while i >= 0:
  var it = items_inside[i]
  if not is_instance_valid(it) or not trigger_area.overlaps_body(it) or it.get("held") == true or it.get("state") == 1:
   items_inside.remove_at(i)
   item_removed.emit(it, self)
   count_changed.emit(items_inside.size(), capacity)
  i -= 1

func _snap_item(item: Node3D) -> void:
 if item is CharacterBody3D:
  item.global_position = global_position + snap_position
  item.velocity = Vector3.ZERO
  if "visual" in item and is_instance_valid(item.visual):
   item.visual.rotation = snap_rotation
 elif item is RigidBody3D:
  item.freeze = true
  item.global_position = global_position + snap_position
  item.linear_velocity = Vector3.ZERO
  item.angular_velocity = Vector3.ZERO

func _bounce_out_rejected_item(body: Node3D) -> void:
 var fx = get_tree().get_first_node_in_group("chaos_feedback")
 if fx: fx.play_event("bonk", body.global_position)
 
 var impulse := Vector3(randf_range(-1.0, 1.0), 3.8, randf_range(1.0, 2.2))
 if body is RigidBody3D:
  body.apply_central_impulse(impulse * body.mass)
 elif body is CharacterBody3D and "velocity" in body:
  body.velocity = impulse * 1.5

func _play_placement_feedback(body: Node3D) -> void:
 var fx = get_tree().get_first_node_in_group("chaos_feedback")
 if fx:
  fx.play_event("pickup", body.global_position)
  fx.play_event("hit_stars", body.global_position + Vector3.UP * 0.3)

func get_item_count() -> int:
 return items_inside.size()

func is_full() -> bool:
 return items_inside.size() >= capacity

func accepts_prop(kind: String) -> bool:
 return accepted_prop_kinds.has(kind)
