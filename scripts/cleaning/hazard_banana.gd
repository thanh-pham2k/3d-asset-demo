class_name HazardBanana
extends RigidBody3D

@export var prop_kind: String = "banana"
var held := false
var holder: Node3D
var pickup_delay := 0.0
var visual: Node3D
var trigger_area: Area3D
var slip_cooldown := 0.0

func _ready() -> void:
 add_to_group("interactables")
 add_to_group("hazards")
 collision_layer = 4
 collision_mask = 7
 contact_monitor = true
 max_contacts_reported = 4
 
 var col := CollisionShape3D.new()
 var box := BoxShape3D.new()
 box.size = Vector3(0.36, 0.10, 0.36)
 col.shape = box
 col.position.y = 0.05
 add_child(col)
 
 visual = Node3D.new()
 visual.name = "Visual"
 add_child(visual)
 _build_banana_visual()
 
 trigger_area = Area3D.new()
 trigger_area.name = "TriggerArea"
 trigger_area.collision_layer = 0
 trigger_area.collision_mask = 2 # detects player
 var trig_col := CollisionShape3D.new()
 var cylinder := CylinderShape3D.new()
 cylinder.radius = 0.35
 cylinder.height = 0.35
 trig_col.shape = cylinder
 trig_col.position.y = 0.15
 trigger_area.add_child(trig_col)
 add_child(trigger_area)
 trigger_area.body_entered.connect(_on_trigger_body_entered)

func _build_banana_visual() -> void:
 var yellow := Color("f59e0b")
 var light_yellow := Color("fbbf24")
 var brown := Color("78350f")
 
 for i in 3:
  var angle := i * TAU / 3.0
  var peel_pivot := Node3D.new()
  peel_pivot.rotation.y = angle
  visual.add_child(peel_pivot)
  Art.box(peel_pivot, Vector3(0.12, 0.02, 0), Vector3(0.18, 0.02, 0.08), yellow)
  Art.box(peel_pivot, Vector3(0.20, 0.04, 0), Vector3(0.08, 0.03, 0.06), light_yellow)
 Art.box(visual, Vector3(0, 0.04, 0), Vector3(0.06, 0.07, 0.06), brown)

func _on_trigger_body_entered(body: Node3D) -> void:
 if held or slip_cooldown > 0.0: return
 if not body.is_in_group("players"): return
 if body.has_method("slip"):
  var move_dir: Vector3 = body.velocity.normalized() if body.velocity.length() > 0.35 else body.facing
  var did_slip: bool = body.slip(move_dir)
  if did_slip:
   slip_cooldown = 1.2
   apply_central_impulse(move_dir * 1.5 + Vector3.UP * 1.8)
   apply_torque_impulse(Vector3(randf_range(-1,1), 2.0, randf_range(-1,1)))

func available(player: Node3D) -> bool:
 return not held and pickup_delay <= 0.0 and player.held_pillow == null

func prompt(_player: Node3D) -> String:
 return "Nhặt vỏ chuối"

func interact(player: Node3D) -> void:
 if not available(player): return
 held = true
 holder = player
 player.held_pillow = self
 freeze = true
 collision_layer = 0
 collision_mask = 0
 emit_feedback("pickup")
 linear_velocity = Vector3.ZERO
 angular_velocity = Vector3.ZERO

func throw_from(player: Node3D) -> void:
 if not held or holder != player: return
 global_position = player.hold_anchor.global_position + player.facing * 0.45
 global_rotation = Vector3.ZERO
 held = false
 holder = null
 player.held_pillow = null
 emit_feedback("throw")
 pickup_delay = 0.5
 collision_layer = 4
 collision_mask = 7
 add_collision_exception_with(player)
 freeze = false
 sleeping = false
 linear_velocity = player.facing * 4.5 + Vector3.UP * 2.2
 angular_velocity = Vector3(2, 4, 1)
 get_tree().create_timer(0.3).timeout.connect(func(): if is_instance_valid(player): remove_collision_exception_with(player))

func drop_from(player: Node3D) -> void:
 if not held or holder != player: return
 global_position = player.hold_anchor.global_position + player.facing * 0.35
 held = false
 holder = null
 player.held_pillow = null
 pickup_delay = 0.4
 collision_layer = 4
 collision_mask = 7
 add_collision_exception_with(player)
 freeze = false
 sleeping = false
 linear_velocity = player.facing * 0.4
 angular_velocity = Vector3.ZERO
 get_tree().create_timer(0.3).timeout.connect(func(): if is_instance_valid(player): remove_collision_exception_with(player))
 emit_feedback("drop")

func emit_feedback(event: String) -> void:
 var fx = get_tree().get_first_node_in_group("chaos_feedback")
 if fx: fx.play_event(event, global_position)

func _physics_process(delta: float) -> void:
 pickup_delay = maxf(0.0, pickup_delay - delta)
 slip_cooldown = maxf(0.0, slip_cooldown - delta)
 
 if held and is_instance_valid(holder):
  global_position = holder.hold_anchor.global_position
  global_rotation = Vector3(0, holder.visual.global_rotation.y, 0)
 else:
  if global_position.y < -1.0:
   global_position = Vector3(0, 0.2, 0)
   linear_velocity = Vector3.ZERO
   angular_velocity = Vector3.ZERO
