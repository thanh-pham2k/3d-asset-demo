extends RigidBody3D

@export_enum("chair", "vase", "cup", "bottle", "slipper", "toy", "container", "stack_box") var prop_kind := "cup"
var held := false
var holder: Node3D
var pickup_delay := 0.0
var broken := false
var last_velocity := Vector3.ZERO
var trail_timer := 0.0
var feedback: Node

func _ready() -> void:
 add_to_group("interactables")
 collision_layer = 4
 collision_mask = 7
 contact_monitor = true
 max_contacts_reported = 4
 body_entered.connect(_on_body_entered)
 var col := CollisionShape3D.new()
 var shape := BoxShape3D.new()
 shape.size = Vector3(0.32,0.32,0.32)
 match prop_kind:
  "chair": shape.size = Vector3(0.48,0.7,0.48)
  "bottle": shape.size = Vector3(0.18,0.42,0.18)
  "slipper": shape.size = Vector3(0.18,0.10,0.34)
  "stack_box": shape.size = Vector3(0.42,0.42,0.42)
 col.shape = shape
 add_child(col)
 var brown := Color("bd8054")
 match prop_kind:
  "chair":
   Art.kenney(self, "chairCushion", Vector3(0,-0.35,0), 0.7)
  "vase":
   Art.ball(self,Vector3.ZERO,0.17,Color("e9b7a8"),Vector3(1,1.05,1))
   Art.box(self,Vector3(0,0.16,0),Vector3(0.13,0.12,0.13),Color("e9b7a8"))
  "cup":
   add_model("res://assets/kenney_food/mug.glb", Vector3(0.0483735,0.13668,0), 0.85)
  "bottle":
   add_model("res://assets/kenney_food/soda-bottle.glb", Vector3(0,0.290206,0), 0.70)
  "slipper":
   Art.box(self,Vector3.ZERO,Vector3(0.18,0.10,0.34),Color("e2a5ad"))
   Art.box(self,Vector3(0,0.06,-0.06),Vector3(0.18,0.08,0.15),Color("f1c0c2"))
  "toy":
   Art.ball(self,Vector3.ZERO,0.15,Color("e8c46e"))
   Art.ball(self,Vector3(0,0.15,0),0.10,Color("e8c46e"))
  "container":
   Art.box(self,Vector3.ZERO,Vector3(0.30,0.24,0.30),Color("9fb595"))
   Art.box(self,Vector3(0,0.13,0),Vector3(0.32,0.05,0.32),Color("dce0b6"))
  "stack_box":
   add_model("res://assets/kenney_props/cardboardBoxClosed.glb", Vector3(0.10625,0.1405,-0.10625), 1.48)

func add_model(path: String, center: Vector3, factor: float) -> void:
 var model = load(path).instantiate()
 model.scale = Vector3.ONE * factor
 model.position = -center * factor
 add_child(model)
 if path.begins_with("res://assets/kenney_food/"):
  # Godot's GLB import can omit external palette references; bind the CC0 atlas explicitly.
  var atlas: Texture2D = load("res://assets/kenney_food/Textures/colormap.png")
  for mesh in model.find_children("*", "MeshInstance3D", true, false):
   for i in mesh.mesh.get_surface_count():
    var source = mesh.get_active_material(i)
    var material: StandardMaterial3D = source.duplicate() if source is StandardMaterial3D else StandardMaterial3D.new()
    material.albedo_texture = atlas
    mesh.set_surface_override_material(i, material)

func available(player: Node3D) -> bool:
 return not held and not broken and pickup_delay <= 0 and player.held_pillow == null

func prompt(_player: Node3D) -> String:
 return "Nhặt " + {"chair":"ghế", "vase":"bình hoa", "cup":"cốc", "bottle":"chai", "slipper":"dép", "toy":"đồ chơi", "container":"hộp", "stack_box":"thùng"}.get(prop_kind,"đồ")

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

func emit_feedback(event: String) -> void:
 var fx = get_tree().get_first_node_in_group("chaos_feedback")
 if fx: fx.play_event(event, global_position)

func throw_from(player: Node3D) -> void:
 if not held or holder != player: return
 global_position = player.hold_anchor.global_position + player.facing * 0.5
 global_rotation = Vector3.ZERO
 held = false
 holder = null
 player.held_pillow = null
 emit_feedback("throw")
 pickup_delay = 0.6
 collision_layer = 4
 collision_mask = 7
 add_collision_exception_with(player)
 freeze = false
 sleeping = false
 linear_velocity = player.facing * (3.5 if prop_kind == "chair" else 5.0) + Vector3.UP * 2.4
 angular_velocity = Vector3(3,2,1)
 get_tree().create_timer(0.45).timeout.connect(func(): if is_instance_valid(player): remove_collision_exception_with(player))

func drop_from(player: Node3D) -> void:
 if not held or holder != player: return
 global_position = player.hold_anchor.global_position + player.facing * 0.45
 held = false
 holder = null
 player.held_pillow = null
 pickup_delay = 0.5
 collision_layer = 4
 collision_mask = 7
 add_collision_exception_with(player)
 freeze = false
 sleeping = false
 linear_velocity = player.facing * 0.4
 angular_velocity = Vector3.ZERO
 get_tree().create_timer(0.3).timeout.connect(func(): if is_instance_valid(player): remove_collision_exception_with(player))
 emit_feedback("drop")

func _physics_process(delta: float) -> void:
 pickup_delay = maxf(0.0,pickup_delay-delta)
 if held and is_instance_valid(holder):
  global_position = holder.hold_anchor.global_position
  global_rotation = Vector3(0,holder.visual.global_rotation.y,0)
 else:
  last_velocity = linear_velocity
  if pickup_delay > 0.0 and linear_velocity.length() > 1.5:
   trail_timer -= delta
   if trail_timer <= 0.0:
    emit_feedback("throw_trail")
    trail_timer = 0.12

func receive_impact(impulse: Vector3) -> void:
 if held or broken: return
 sleeping = false
 apply_central_impulse(impulse * mass)
 if prop_kind == "vase" and impulse.length() > 2.4:
  _break_apart()

func _on_body_entered(body: Node) -> void:
 if broken or held: return
 if last_velocity.length() > 1.5: emit_feedback("landing" if body is StaticBody3D and last_velocity.y < -absf(last_velocity.x) - absf(last_velocity.z) else "collision")
 if body.is_in_group("players") and last_velocity.length() > 1.5 and body.has_method("hit"):
  body.hit(last_velocity)
 if prop_kind == "vase" and last_velocity.length() > 2.4:
  _break_apart()

func _break_apart() -> void:
  if broken: return
  broken = true
  remove_from_group("interactables")
  for i in 5:
   var fragment := RigidBody3D.new()
   fragment.position = global_position + Vector3((i-2)*0.05,0.1,0)
   var col := CollisionShape3D.new()
   var shape := SphereShape3D.new()
   shape.radius = 0.05
   col.shape = shape
   fragment.add_child(col)
   Art.ball(fragment,Vector3.ZERO,0.05,Color("e9b7a8"))
   get_parent().add_child.call_deferred(fragment)
   fragment.linear_velocity = Vector3((i-2)*0.4,1.2,(i%2-0.5)*0.6)
   get_tree().create_timer(4.0).timeout.connect(func(): if is_instance_valid(fragment): fragment.queue_free())
  queue_free.call_deferred()
