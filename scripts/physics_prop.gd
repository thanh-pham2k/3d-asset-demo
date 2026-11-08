extends RigidBody3D

@export_enum("chair", "vase", "cup", "bottle", "slipper", "toy", "container", "stack_box", "pillow") var prop_kind := "cup"
var held := false
var holder: Node3D
var pickup_delay := 0.0
var broken := false
var last_velocity := Vector3.ZERO
var trail_timer := 0.0
var feedback: Node
var chain_level := 0
var last_impulse_source: Node
var display_name := "Đồ"
var item_category := "prop"
var interaction_type := "pickup"
var valid_destinations: Array = []

func _ready() -> void:
 add_to_group("interactables")
 collision_layer = 4
 collision_mask = 7
 contact_monitor = true
 max_contacts_reported = 4
 body_entered.connect(_on_body_entered)
 match prop_kind:
  "bottle":
   display_name = "Chai nước"
   item_category = "trash"
   valid_destinations = ["trash"]
  "cup":
   display_name = "Cốc nước"
   item_category = "trash"
   valid_destinations = ["trash"]
  "pillow":
   display_name = "Gối"
   item_category = "cushion"
   valid_destinations = ["sofa"]
  "toy":
   display_name = "Đồ chơi"
   item_category = "toy"
   valid_destinations = ["basket"]
  "slipper":
   display_name = "Dép"
   item_category = "toy"
   valid_destinations = ["basket"]
  "container":
   display_name = "Hộp nhựa"
   item_category = "toy"
   valid_destinations = ["basket"]
  "stack_box":
   display_name = "Thùng các-tông"
   item_category = "toy"
   valid_destinations = ["basket"]
  "chair":
   display_name = "Ghế"
   item_category = "furniture"
   valid_destinations = []
  "vase":
   display_name = "Bình hoa"
   item_category = "decor"
   valid_destinations = []
 var col := CollisionShape3D.new()
 var shape := BoxShape3D.new()
 shape.size = Vector3(0.24,0.24,0.24)
 match prop_kind:
  "chair": shape.size = Vector3(0.48,0.7,0.48)
  "bottle": shape.size = Vector3(0.16,0.38,0.16)
  "cup": shape.size = Vector3(0.16,0.20,0.16)
  "vase": shape.size = Vector3(0.20,0.32,0.20)
  "toy": shape.size = Vector3(0.22,0.24,0.22)
  "container": shape.size = Vector3(0.28,0.22,0.28)
  "slipper": shape.size = Vector3(0.18,0.10,0.30)
  "stack_box": shape.size = Vector3(0.40,0.40,0.40)
  "pillow": shape.size = Vector3(0.44,0.16,0.34)
 col.shape = shape
 add_child(col)
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
  "pillow":
   var pivot := Node3D.new()
   pivot.rotation.x = -PI / 2.0
   add_child(pivot)
   var model = load("res://assets/kenney_props/pillowBlue.glb").instantiate()
   model.scale = Vector3.ONE * 2.0
   model.position = -Vector3(0.115,0.064256,-0.031695) * 2.0
   pivot.add_child(model)
   for mesh in model.find_children("*", "MeshInstance3D", true, false):
    mesh.material_override = Art.material(Color("efabb7"))

func add_model(path: String, center: Vector3, factor: float) -> void:
 var model = load(path).instantiate()
 model.scale = Vector3.ONE * factor
 model.position = -center * factor
 add_child(model)
 if path.begins_with("res://assets/kenney_food/"):
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
 return "Nhặt " + display_name

func interact(player: Node3D) -> void:
 if not available(player): return
 held = true
 holder = player
 player.held_pillow = self
 freeze = true
 collision_layer = 0
 collision_mask = 0
 add_collision_exception_with(player)
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
 chain_level = 1
 last_impulse_source = player
 linear_velocity = player.facing * (3.5 if prop_kind == "chair" else 5.2) + Vector3.UP * 2.4
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
 chain_level = 0
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
  # Out of bounds safety: keep within room bounds
  if global_position.y < -1.0:
   global_position = Vector3(clampf(global_position.x, -3.5, 3.5), 0.5, clampf(global_position.z, -2.5, 2.5))
   linear_velocity = Vector3.ZERO
   angular_velocity = Vector3.ZERO
  
  last_velocity = linear_velocity
  if pickup_delay > 0.0 and linear_velocity.length() > 1.5:
   trail_timer -= delta
   if trail_timer <= 0.0:
    emit_feedback("throw_trail")
    trail_timer = 0.12

func receive_impact(impulse: Vector3, source: Node = null) -> void:
 if held or broken: return
 sleeping = false
 apply_central_impulse(impulse * mass)
 
 var prev_chain := 0
 if is_instance_valid(source) and "chain_level" in source:
  prev_chain = source.chain_level
 elif is_instance_valid(source) and source.is_in_group("players"):
  prev_chain = 1
 
 if prev_chain > 0:
  chain_level = prev_chain + 1
 else:
  chain_level = 1
 
 last_impulse_source = source
 
 var is_hammer: bool = (is_instance_valid(source) and source.is_in_group("players") and source.held_pillow and source.held_pillow.prop_kind == "hammer")
 var score_mgr = get_tree().get_first_node_in_group("score_manager")
 if score_mgr:
  if chain_level >= 2:
   score_mgr.register_chain_reaction(source, self, chain_level, global_position)
  score_mgr.register_prop_hit(self, impulse.length(), is_hammer, global_position)
 
 var camera = get_viewport().get_camera_3d()
 if camera and camera.has_method("add_trauma"):
  camera.add_trauma(0.2 if not is_hammer else 0.35)
 
 if prop_kind in ["vase", "bottle", "cup"] and impulse.length() > 2.0:
  _break_apart()

func _on_body_entered(body: Node) -> void:
 if broken or held: return
 var speed := last_velocity.length()
 if speed > 1.2:
  emit_feedback("landing" if body is StaticBody3D and last_velocity.y < -absf(last_velocity.x) - absf(last_velocity.z) else "collision")
  
  var score_mgr = get_tree().get_first_node_in_group("score_manager")
  if score_mgr:
   score_mgr.register_prop_hit(self, speed, false, global_position)
   if body is RigidBody3D and chain_level > 0:
    score_mgr.register_chain_reaction(self, body, chain_level + 1, global_position)
  
  if body is RigidBody3D and not body.freeze:
   var impact_force: Vector3 = last_velocity.normalized() * minf(speed * 0.8, 4.0)
   body.apply_central_impulse(impact_force * body.mass)
   if body.has_method("receive_impact"):
    body.receive_impact(impact_force, self)
 
 if body.is_in_group("players") and speed > 1.5 and body.has_method("hit"):
  body.hit(last_velocity)
 
 if prop_kind in ["vase", "bottle", "cup"] and speed > 2.0:
  _break_apart()

func _break_apart() -> void:
 if broken: return
 broken = true
 remove_from_group("interactables")
 
 var score_mgr = get_tree().get_first_node_in_group("score_manager")
 if score_mgr:
  score_mgr.register_prop_broken(self, prop_kind, global_position)
 
 emit_feedback("bonk")
 var camera = get_viewport().get_camera_3d()
 if camera and camera.has_method("add_trauma"):
  camera.add_trauma(0.35)
 
 var frag_color := Color("e9b7a8")
 if prop_kind == "bottle": frag_color = Color("68aa76")
 elif prop_kind == "cup": frag_color = Color("e0e2e5")
 
 var frag_count := 6 if prop_kind == "vase" else 4
 for i in frag_count:
  var fragment := RigidBody3D.new()
  fragment.position = global_position + Vector3((i - frag_count * 0.5) * 0.05, 0.1, (i % 2 - 0.5) * 0.05)
  fragment.collision_layer = 4
  fragment.collision_mask = 3
  var col := CollisionShape3D.new()
  var shape := SphereShape3D.new()
  shape.radius = 0.045
  col.shape = shape
  fragment.add_child(col)
  Art.ball(fragment, Vector3.ZERO, 0.045, frag_color)
  get_parent().add_child.call_deferred(fragment)
  fragment.linear_velocity = Vector3((i - frag_count * 0.5) * 0.5, randf_range(1.0, 2.0), (i % 2 - 0.5) * 0.8)
  get_tree().create_timer(2.5).timeout.connect(func(): if is_instance_valid(fragment): fragment.queue_free())
 
 queue_free.call_deferred()
