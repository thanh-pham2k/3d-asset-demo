@tool
extends Node3D
## Reusable local-origin modules. Visual meshes and optional static collisions are separate.
@export_enum("house", "townhouse", "school_gate", "sofa", "bed", "refrigerator", "television", "coffee_table", "kitchen_counter", "grocery_shelf", "grocery_counter", "paved_court", "yard_fence", "utility_pole", "clothesline", "garage", "noodle", "market_stall", "fruit_stall", "meat_stall", "ingredient_stall", "cafe", "banh_mi", "juice", "grocery", "furniture", "school", "tree", "bench", "table", "chair", "pot", "tire", "scooter_parking", "planter", "lamp", "playground", "air_pump", "workbench", "scooter", "produce_crate", "road_segment", "sidewalk_segment", "crossing", "trash_bin", "pond", "slide", "market_basket", "umbrella", "flower_bed", "banana_tree", "gazebo") var kind := "house"
@export var tint := Color("f3d59a")
## Disable for a nonblocking decorative instance. Visual and physics nodes stay separate.
@export var collision_enabled := true
var cutaway_meshes: Array[MeshInstance3D] = []
var side_cutaway_meshes: Array[MeshInstance3D] = []
var interior_half_size := Vector2.ZERO
var visual_occlusion_bounds := AABB()
var tracked_player: Node3D

func _ready() -> void:
 if get_child_count() == 0: build()

func mat(c: Color) -> StandardMaterial3D:
 var m := StandardMaterial3D.new()
 m.albedo_color = c.lerp(c.srgb_to_linear(), 0.5)
 m.roughness = 1.0
 return m

func box(pos: Vector3, size: Vector3, color: Color, solid := false) -> MeshInstance3D:
 var mesh := MeshInstance3D.new()
 var shape := BoxMesh.new()
 shape.size = size
 mesh.mesh = shape
 mesh.material_override = mat(color)
 mesh.position = pos
 add_child(mesh)
 if solid and collision_enabled:
  var body := StaticBody3D.new()
  var col := CollisionShape3D.new()
  var b := BoxShape3D.new()
  b.size = size
  col.shape = b
  body.position = pos
  body.add_child(col)
  add_child(body)
 return mesh

func round_shape(pos: Vector3, radius: float, height: float, color: Color) -> void:
 var mesh := MeshInstance3D.new()
 var shape := CylinderMesh.new()
 shape.top_radius = radius
 shape.bottom_radius = radius
 shape.height = height
 shape.radial_segments = 8
 mesh.mesh = shape
 mesh.material_override = mat(color)
 mesh.position = pos
 add_child(mesh)

func cylinder_collision(pos: Vector3, radius: float, height: float) -> void:
 if not collision_enabled: return
 var body := StaticBody3D.new()
 body.name = "CollisionBody"
 body.position = pos
 var collider := CollisionShape3D.new()
 var shape := CylinderShape3D.new()
 shape.radius = radius
 shape.height = height
 collider.shape = shape
 body.add_child(collider)
 add_child(body)

func building(w: float, d: float, h: float, open_front := false) -> void:
 var cream := Color("fff0d6")
 interior_half_size = Vector2(w / 2.0 - 0.25, d / 2.0 - 0.25)
 # Conservative roof-and-wall volume for the orthographic camera line of sight.
 visual_occlusion_bounds = AABB(Vector3(-w/2-0.4,0,-d/2-0.4),Vector3(w+0.8,h+0.8+w*0.1,d+0.8))
 cutaway_meshes.append(box(Vector3(0, h/2, d/2 - 0.2), Vector3(w, h, 0.4), tint, true))
 side_cutaway_meshes.append(box(Vector3(-w/2+0.2,h/2,0),Vector3(0.4,h,d),tint,true))
 side_cutaway_meshes.append(box(Vector3(w/2-0.2,h/2,0),Vector3(0.4,h,d),tint,true))
 if not open_front:
  cutaway_meshes.append(box(Vector3(-w*0.35,h/2,-d/2),Vector3(w*0.30,h,0.4),tint,true))
  cutaway_meshes.append(box(Vector3(w*0.35,h/2,-d/2),Vector3(w*0.30,h,0.4),tint,true))
  cutaway_meshes.append(box(Vector3(0,h-0.45,-d/2),Vector3(w*0.4,0.9,0.4),tint))
 # Low pitched roof: two separately editable visual panels, no roof collision.
 var roof_angle := 0.18
 for side in [-1.0,1.0]:
  var panel := box(Vector3(side*w*0.25,h+0.28+w*0.045,0),Vector3(w*0.52+0.45,0.3,d+0.8),Color("bd7155"))
  panel.rotation.z = -side * roof_angle
  cutaway_meshes.append(panel)
 box(Vector3(0,0.08,0),Vector3(w,0.16,d),cream)
 # Awning and posts frame an open, accessible storefront.
 cutaway_meshes.append(box(Vector3(0,h*0.72,-d/2-1.0),Vector3(w+0.3,0.18,2.0),Color("e7ece1")))
 for x in [-w/2+0.25,w/2-0.25]:
  cutaway_meshes.append(box(Vector3(x,h*0.36,-d/2-1.8),Vector3(0.15,h*0.72,0.15),Color("98785b")))

func build() -> void:
 var wood := Color("a87351")
 var dark := Color("424a49")
 var red := Color("d9775d")
 match kind:
  "house":
   building(9,8,4)
   # Simple blue shutters and cream surrounds frame the doorway.
   for x in [-3.1,3.1]:
    cutaway_meshes.append(box(Vector3(x,2.05,-4.23),Vector3(1.55,1.55,0.08),Color("f7ead3")))
    cutaway_meshes.append(box(Vector3(x,2.05,-4.29),Vector3(1.2,1.25,0.08),Color("8db6bc")))
    cutaway_meshes.append(box(Vector3(x,2.05,-4.35),Vector3(0.07,1.25,0.07),Color("f7ead3")))
    cutaway_meshes.append(box(Vector3(x,2.05,-4.35),Vector3(1.2,0.07,0.07),Color("f7ead3")))
  "townhouse":
   # Narrow two-storey residential shop-house proportions with a sheltered balcony.
   building(7.4,8.0,7.0)
   for x in [-2.2,0.0,2.2]:
    cutaway_meshes.append(box(Vector3(x,5.35,-4.23),Vector3(1.25,1.6,0.08),Color("f8ead3")))
    cutaway_meshes.append(box(Vector3(x,5.35,-4.29),Vector3(0.98,1.3,0.08),Color("8fb6bc")))
    cutaway_meshes.append(box(Vector3(x,5.35,-4.35),Vector3(0.07,1.3,0.07),Color("f8ead3")))
   cutaway_meshes.append(box(Vector3(0,4.15,-4.8),Vector3(7.2,0.2,1.6),Color("f0dfc4")))
   cutaway_meshes.append(box(Vector3(0,5.05,-5.48),Vector3(7.1,0.12,0.12),Color("9c7a62")))
   for x in [-3.3,-2.2,-1.1,0.0,1.1,2.2,3.3]:
    cutaway_meshes.append(box(Vector3(x,4.62,-5.48),Vector3(0.1,0.8,0.1),Color("9c7a62")))
  "school_gate":
   for x in [-6.0,6.0]:
    box(Vector3(x,1.9,0),Vector3(0.7,3.8,0.7),Color("f3e2c6"),true)
    box(Vector3(x,3.9,0),Vector3(1.0,0.25,1.0),Color("c98265"))
   box(Vector3(0,3.8,0),Vector3(12.7,0.55,0.7),Color("c98265"))
   box(Vector3(0,3.8,-0.37),Vector3(5.5,0.32,0.08),Color("e9d5ad"))
  "grocery_shelf":
   # Stocked, freestanding display; all goods are part of this prop, not the shop.
   box(Vector3(0,0.95,0.18),Vector3(2.0,1.9,0.1),Color("a77c5f"),true)
   for y in [0.28,0.78,1.28,1.78]: box(Vector3(0,y,0),Vector3(2.0,0.10,0.58),Color("c79b74"))
   for x in [-0.75,-0.25,0.25,0.75]:
    for row in range(3):
     var c: Color = [Color("ddaa72"),Color("a9c1a4"),Color("d68f7c"),Color("e8d19a")][(int((x+0.75)*2)+row)%4]
     box(Vector3(x,0.46+row*0.5,-0.08),Vector3(0.32,0.27,0.28),c)
  "grocery_counter":
   box(Vector3(0,0.46,0),Vector3(1.8,0.92,0.75),Color("bd8b68"),true)
   box(Vector3(0,0.95,0),Vector3(1.9,0.12,0.85),Color("e6d0ae"))
   box(Vector3(0.42,1.12,0),Vector3(0.38,0.24,0.3),Color("6d8580"))
   box(Vector3(-0.4,1.06,0),Vector3(0.5,0.1,0.36),Color("eee0c6"))
  "paved_court":
   # Flush decorative paving; ground collision remains independent.
   box(Vector3(0,0.025,0),Vector3(10,0.05,10),Color("ddc7a9"))
   for x in [-4.0,-2.0,0.0,2.0,4.0]:
    box(Vector3(x,0.054,0),Vector3(0.025,0.008,10),Color("cbb395"))
   for z in [-4.0,-2.0,0.0,2.0,4.0]:
    box(Vector3(0,0.055,z),Vector3(10,0.008,0.025),Color("cbb395"))
  "yard_fence":
   # A 4 m module, with a low separate collider matching the lower rail.
   for x in [-1.95,1.95]:
    box(Vector3(x,0.55,0),Vector3(0.18,1.1,0.18),Color("efe3c9"))
    box(Vector3(x,1.14,0),Vector3(0.25,0.1,0.25),Color("c58469"))
   box(Vector3(0,0.35,0),Vector3(4.0,0.16,0.12),Color("b89573"),true)
   box(Vector3(0,0.82,0),Vector3(4.0,0.14,0.12),Color("b89573"))
   for x in [-1.35,-0.45,0.45,1.35]: box(Vector3(x,0.57,0),Vector3(0.1,0.75,0.1),Color("e9d9be"))
  "utility_pole":
   round_shape(Vector3(0,2.6,0),0.16,5.2,Color("9a8168"))
   cylinder_collision(Vector3(0,1.0,0),0.16,2.0)
   box(Vector3(0,4.8,0),Vector3(2.2,0.12,0.14),Color("856d59"))
   for x in [-0.8,0.0,0.8]: round_shape(Vector3(x,4.92,0),0.12,0.18,Color("eee5d6"))
  "clothesline":
   for x in [-1.8,1.8]: box(Vector3(x,1.35,0),Vector3(0.09,2.7,0.09),Color("9d8266"))
   box(Vector3(0,2.4,0),Vector3(3.6,0.035,0.035),Color("e9d7bd"))
   for item in [[-1.05,Color("e8b1a1")],[-0.25,Color("f5e5cb")],[0.55,Color("9fbfba")],[1.22,Color("d9be8e")]]:
    box(Vector3(item[0],2.05,0),Vector3(0.55,0.65,0.05),item[1])
  "garage":
   # Compact cozy roadside repair shack ("Chòi sửa xe máy Chú Ba")
   var gw := 6.2
   var gd := 4.2
   var gh := 3.0
   interior_half_size = Vector2(gw * 0.5 + 2.2, gd * 0.5 + 5.8)
   visual_occlusion_bounds = AABB(Vector3(-gw * 0.5 - 1.5, 0.9, -gd * 0.5 - 3.5), Vector3(gw + 3.0, gh + 0.8, gd + 5.5))
   box(Vector3(0, 0.05, 0), Vector3(gw, 0.1, gd), Color("90a4ae"), true)
   for x in [-gw/2 + 0.15, gw/2 - 0.15]:
    for z in [-gd/2 + 0.15, gd/2 - 0.15]:
     var post := box(Vector3(x, gh/2, z), Vector3(0.16, gh, 0.16), wood)
     if z < 0.0:
      cutaway_meshes.append(post)
   # Low waist wall stays visible for grounding; upper wall + tool board cut away when inside
   box(Vector3(0, 0.55, gd/2 - 0.08), Vector3(gw - 0.2, 1.0, 0.14), wood, true)
   var upper_back_wall := box(Vector3(0, 1.9, gd/2 - 0.08), Vector3(gw - 0.2, 1.7, 0.14), wood)
   cutaway_meshes.append(upper_back_wall)
   var tool_board := box(Vector3(0, 1.7, gd/2 - 0.18), Vector3(4.0, 1.2, 0.06), Color("37474f"))
   cutaway_meshes.append(tool_board)
   for tx in [-1.5, -0.9, -0.3, 0.3, 0.9, 1.5]:
    cutaway_meshes.append(box(Vector3(tx, 1.8, gd/2 - 0.23), Vector3(0.18, 0.35, 0.05), Color("cfd8dc")))
    cutaway_meshes.append(box(Vector3(tx, 1.45, gd/2 - 0.23), Vector3(0.14, 0.22, 0.05), Color("d32f2f")))
   var roof := box(Vector3(0, gh + 0.1, -0.1), Vector3(gw + 0.6, 0.14, gd + 0.8), tint)
   roof.rotation.x = -0.06
   cutaway_meshes.append(roof)
   var fascia := box(Vector3(0, gh - 0.15, -gd/2 - 0.45), Vector3(gw + 0.7, 0.32, 0.08), Color("8d6e63"))
   cutaway_meshes.append(fascia)
   var signboard := box(Vector3(0, gh - 0.15, -gd/2 - 0.50), Vector3(4.5, 0.55, 0.06), Color("fff9c4"))
   cutaway_meshes.append(signboard)
   var red_stripe := box(Vector3(0, gh - 0.15, -gd/2 - 0.54), Vector3(4.2, 0.12, 0.02), Color("c62828"))
   cutaway_meshes.append(red_stripe)
   box(Vector3(gw/2 - 1.1, 0.45, 0.2), Vector3(1.8, 0.9, 0.8), wood, true)
   box(Vector3(gw/2 - 1.1, 0.98, 0.2), Vector3(0.5, 0.22, 0.35), red)
   box(Vector3(gw/2 - 0.5, 0.96, 0.2), Vector3(0.35, 0.18, 0.25), Color("fbc02d"))
   box(Vector3(gw/2 - 1.1, 0.24, -0.8), Vector3(0.4, 0.48, 0.4), wood)
   for y in [0.22, 0.62, 1.02]:
    round_shape(Vector3(-gw/2 + 0.9, y, 0.4), 0.46, 0.32, dark)
   round_shape(Vector3(-gw/2 + 0.9, 0.22, -0.6), 0.46, 0.32, dark)
   round_shape(Vector3(0.3, 0.38, 0.8), 0.26, 0.7, Color("e53935"))
  "noodle", "market_stall", "fruit_stall", "meat_stall", "ingredient_stall", "cafe", "banh_mi", "juice":
   interior_half_size = Vector2(2.4, 2.2)
   visual_occlusion_bounds = AABB(Vector3(-2.0, 1.2, -1.2), Vector3(4.0, 2.0, 2.4))
   box(Vector3(0,0.55,0),Vector3(3.2,1.1,1.3),wood,true)
   for x in [-1.4,1.4]:
    for z in [-0.55,0.55]: box(Vector3(x,1.4,z),Vector3(0.12,2.8,0.12),wood)
   cutaway_meshes.append(box(Vector3(0,2.8,0),Vector3(3.8,0.18,1.9),tint))
   for x in [-1.4,-0.6,0.2,1.0]:
    cutaway_meshes.append(box(Vector3(x,2.9,0),Vector3(0.36,0.03,1.85),Color("fff1dc")))
   match kind:
    "noodle":
     box(Vector3(0,1.16,0),Vector3(1.1,0.15,0.8),dark)
     round_shape(Vector3(0,1.45,0),0.45,0.5,Color("b9c3bf"))
     round_shape(Vector3(0,1.73,0),0.48,0.07,Color("d5ddda"))
    "banh_mi":
     box(Vector3(0,1.5,0),Vector3(2.3,0.7,0.08),Color("a8ceca"))
     for x in [-0.7,0.0,0.7]: box(Vector3(x,1.2,-0.15),Vector3(0.55,0.22,0.25),Color("d99e59"))
    "juice":
     box(Vector3(0.65,1.35,0),Vector3(0.6,0.5,0.5),Color("b9c3bf"))
     for x in [-1.0,-0.8,-0.6]: box(Vector3(x,1.55,0),Vector3(0.09,0.9,0.09),Color("a8bb78"))
    "cafe":
     for x in [-0.8,-0.4,0.0]: round_shape(Vector3(x,1.23,0),0.14,0.25,Color("e7dbc9"))
     box(Vector3(0.8,1.4,0),Vector3(0.5,0.55,0.45),Color("946f59"))
    "meat_stall":
     box(Vector3(0,1.16,0),Vector3(2.4,0.12,0.9),Color("e6dbcb"))
     for x in [-0.75,0.0,0.75]:
      box(Vector3(x,1.30,0),Vector3(0.56,0.2,0.4),Color("c97970"))
      box(Vector3(x,1.42,0),Vector3(0.5,0.04,0.08),Color("f0d1bc"))
    "ingredient_stall":
     for x in [-0.9,0.0,0.9]:
      box(Vector3(x,1.22,0),Vector3(0.65,0.24,0.6),Color("b4885f"))
      round_shape(Vector3(x,1.39,0),0.24,0.16,[Color("e3c184"),Color("8eaa73"),Color("d99c68")][int(round(x/0.9))+1])
    "fruit_stall":
     for x in [-0.9,0.0,0.9]:
      for z in [-0.18,0.18]: round_shape(Vector3(x,1.24,z),0.19,0.22,[Color("d9826e"),Color("e6c467"),Color("95b66f")][int(round(x/0.9))+1])
    _:
     for x in [-1.0,0.0,1.0]: round_shape(Vector3(x,1.2,0),0.3,0.25,[Color("d87955"),Color("e9c76b"),Color("80a768")][int(x)+1])
  "grocery": building(9,8,4,true)
  "furniture": building(15,10,5,true)
  "sofa":
   box(Vector3(0,0.38,0),Vector3(2.1,0.6,0.95),tint,true)
   box(Vector3(0,0.85,0.36),Vector3(2.1,0.7,0.22),tint)
   for x in [-0.95,0.95]: box(Vector3(x,0.7,0),Vector3(0.2,0.4,0.95),tint)
   for x in [-0.48,0.48]: box(Vector3(x,0.72,-0.1),Vector3(0.88,0.12,0.65),Color("a3bca0"))
  "bed":
   box(Vector3(0,0.3,0),Vector3(1.65,0.6,2.05),Color("a97d5d"),true)
   box(Vector3(0,0.67,0),Vector3(1.55,0.2,1.95),Color("f1e1c9"))
   box(Vector3(0,0.84,0.77),Vector3(1.65,1.0,0.16),Color("a97d5d"))
   for x in [-0.38,0.38]: box(Vector3(x,0.84,0.52),Vector3(0.58,0.16,0.38),Color("fff6e4"))
   box(Vector3(0,0.81,-0.38),Vector3(1.56,0.1,1.1),Color("a8c8c0"))
  "refrigerator":
   box(Vector3(0,0.9,0),Vector3(0.9,1.8,0.78),Color("dae6df"),true)
   box(Vector3(0,1.15,-0.4),Vector3(0.87,0.04,0.03),Color("a7b8b2"))
   box(Vector3(0.29,0.8,-0.43),Vector3(0.06,0.38,0.08),Color("8eaaa3"))
   box(Vector3(0.29,1.53,-0.43),Vector3(0.06,0.26,0.08),Color("8eaaa3"))
  "television":
   box(Vector3(0,0.35,0),Vector3(1.55,0.7,0.5),wood,true)
   box(Vector3(0,1.14,0),Vector3(1.42,0.8,0.1),dark)
   box(Vector3(0,1.14,-0.06),Vector3(1.25,0.63,0.025),Color("8caaa8"))
   box(Vector3(0,0.75,0),Vector3(0.16,0.15,0.25),dark)
  "coffee_table":
   box(Vector3(0,0.42,0),Vector3(1.3,0.12,0.72),wood,true)
   for x in [-0.52,0.52]:
    for z in [-0.25,0.25]: box(Vector3(x,0.2,z),Vector3(0.1,0.4,0.1),wood)
  "kitchen_counter":
   box(Vector3(0,0.44,0),Vector3(1.55,0.88,0.75),Color("e9d7bc"),true)
   box(Vector3(0,0.92,0),Vector3(1.6,0.1,0.8),Color("a9bdb5"))
   box(Vector3(0.35,0.98,0),Vector3(0.52,0.03,0.45),Color("d8ded5"))
  "school":
   building(24,10,7)
   for x in [-8.0,-4.0,4.0,8.0]:
    cutaway_meshes.append(box(Vector3(x,4,-5.23),Vector3(2,2,0.1),Color("99c5c6")))
  "tree":
   round_shape(Vector3(0,1.7,0),0.32,3.4,wood)
   cylinder_collision(Vector3(0,1.0,0),0.32,2.0)
   for p in [Vector3(0,4,0),Vector3(-1.0,3.6,0),Vector3(1,3.7,0.4),Vector3(0,3.7,-1)]:
    var m := MeshInstance3D.new()
    var s := SphereMesh.new()
    s.radius = 1.35
    s.height = 2.7
    s.radial_segments = 7
    s.rings = 4
    m.mesh = s
    m.material_override = mat(tint)
    m.position = p
    add_child(m)
    cutaway_meshes.append(m)
   visual_occlusion_bounds = AABB(Vector3(-2.4, 2.0, -2.4), Vector3(4.8, 3.8, 4.8))
   interior_half_size = Vector2(2.4, 2.4)
  "bench":
   box(Vector3(0,0.55,0),Vector3(2,0.18,0.65),wood)
   box(Vector3(0,1,0.25),Vector3(2,0.8,0.12),wood)
   for x in [-0.7,0.7]: box(Vector3(x,0.25,0),Vector3(0.15,0.5,0.5),dark)
  "table":
   box(Vector3(0,0.75,0),Vector3(1.2,0.12,1.2),tint)
   box(Vector3(0,0.37,0),Vector3(0.12,0.74,0.12),dark)
  "chair":
   box(Vector3(0,0.45,0),Vector3(0.55,0.12,0.55),tint)
   box(Vector3(0,0.75,0.23),Vector3(0.55,0.6,0.1),tint)
   for x in [-0.2,0.2]:
    for z in [-0.2,0.2]: box(Vector3(x,0.2,z),Vector3(0.07,0.4,0.07),tint)
  "pot": round_shape(Vector3(0,0.35,0),0.45,0.7,Color("b9c3bf"))
  "tire": round_shape(Vector3(0,0.18,0),0.5,0.35,dark)
  "scooter_parking":
   for x in [-1.5,0.0,1.5]: box(Vector3(x,0.03,0),Vector3(0.08,0.03,2.5),Color("f5eee0"))
  "planter":
   box(Vector3(0,0.35,0),Vector3(0.9,0.7,0.9),red,true)
   round_shape(Vector3(0,0.95,0),0.45,0.7,Color("739967"))
  "lamp":
   round_shape(Vector3(0,2.2,0),0.1,4.4,dark)
   box(Vector3(0,4.45,0),Vector3(0.55,0.35,0.55),Color("fff1b5"))
  "air_pump":
   box(Vector3(0,0.32,0),Vector3(0.45,0.64,0.45),Color("cf6656"))
   box(Vector3(0,0.95,0),Vector3(0.12,0.7,0.12),dark)
   box(Vector3(0,1.31,0),Vector3(0.55,0.1,0.1),dark)
  "workbench":
   box(Vector3(0,0.9,0),Vector3(2.2,0.16,0.8),wood)
   for x in [-0.9,0.9]: box(Vector3(x,0.42,0),Vector3(0.12,0.84,0.7),dark)
   box(Vector3(-0.5,1.05,0),Vector3(0.35,0.12,0.22),red)
   box(Vector3(0.35,1.03,0),Vector3(0.6,0.06,0.09),Color("b9c3bf"))
  "scooter":
   # Visual-only entity; proportioned so low-poly characters sit naturally on seat with hands on grips and feet on footboard.
   for z in [-0.58,0.58]:
    var wheel := CylinderMesh.new()
    wheel.top_radius = 0.26
    wheel.bottom_radius = 0.26
    wheel.height = 0.16
    wheel.radial_segments = 12
    var wheel_node := MeshInstance3D.new()
    wheel_node.mesh = wheel
    wheel_node.material_override = mat(dark)
    wheel_node.position = Vector3(0,0.28,z)
    wheel_node.rotation.z = PI / 2
    add_child(wheel_node)
   # Low step-through footboard & footrests
   box(Vector3(0,0.44,-0.08),Vector3(0.44,0.12,0.58),dark)
   # Rear under-seat fairing
   box(Vector3(0,0.66,0.26),Vector3(0.40,0.36,0.60),tint)
   # Seat cushion aligned with rider pelvis (top at y = 0.94, z = 0.22)
   box(Vector3(0,0.88,0.22),Vector3(0.36,0.12,0.54),dark)
   # Steering stem & front shield angled toward rider
   var stem := box(Vector3(0,0.82,-0.42),Vector3(0.24,0.76,0.20),tint)
   stem.rotation.x = 0.22
   # Handlebar & grips aligned with rider hands (y = 1.20, z = -0.24)
   box(Vector3(0,1.20,-0.24),Vector3(0.66,0.07,0.08),dark)
  "produce_crate":
   box(Vector3(0,0.2,0),Vector3(1,0.4,0.7),wood)
   for x in [-0.3,0.0,0.3]:
    for z in [-0.16,0.16]: round_shape(Vector3(x,0.46,z),0.14,0.2,tint)
  "road_segment":
   box(Vector3(0,0.02,0),Vector3(10,0.04,8),Color("777b73"))
   box(Vector3(0,0.05,0),Vector3(3,0.02,0.15),Color("f4df9b"))
  "sidewalk_segment":
   box(Vector3(0,0.05,0),Vector3(10,0.1,3),Color("e0d3b9"))
   for x in [-4.0,-2.0,0.0,2.0,4.0]: box(Vector3(x,0.105,0),Vector3(0.035,0.01,3),Color("c9bda9"))
  "crossing":
   for x in [-3.0,-2.0,-1.0,0.0,1.0,2.0,3.0]: box(Vector3(x,0.02,0),Vector3(0.5,0.04,3),Color("fff7df"))
  "trash_bin":
   box(Vector3(0,0.45,0),Vector3(0.65,0.9,0.65),Color("7a9e85"))
   box(Vector3(0,0.95,0),Vector3(0.75,0.12,0.75),Color("546f61"))
  "pond":
   # Layered shoreline; a separate cylinder keeps players out of the water.
   round_shape(Vector3(0,0.06,0),6.3,0.12,Color("c3ae91"))
   round_shape(Vector3(0,0.13,0),5.8,0.08,Color("83b9b7"))
   cylinder_collision(Vector3(0,0.6,0),5.65,1.2)
   for p in [Vector3(-2,0.19,1.3),Vector3(1.5,0.19,-1.6),Vector3(3,0.19,2.0)]:
    round_shape(p,0.42,0.035,Color("7eaa77"))
    round_shape(p + Vector3(0,0.04,0),0.10,0.05,Color("f0c0b5"))
  "slide":
   for x in [-0.65,0.65]:
    for z in [-0.55,0.55]: box(Vector3(x,1.05,z),Vector3(0.13,2.1,0.13),Color("e9bd63"))
   box(Vector3(0,2.1,0),Vector3(1.5,0.15,1.4),Color("d5a071"))
   var ramp := box(Vector3(0,1.05,1.85),Vector3(1.1,0.15,3.3),Color("d77760"))
   ramp.rotation.x = -0.6
   for y in [0.4,0.8,1.2,1.6]: box(Vector3(0,y,-0.78),Vector3(1.1,0.10,0.1),Color("83aab0"))
  "market_basket":
   round_shape(Vector3(0,0.18,0),0.48,0.36,Color("b88a62"))
   for p in [Vector3(-0.22,0.44,0),Vector3(0.22,0.44,0),Vector3(0,0.44,-0.2),Vector3(0,0.44,0.2)]:
    round_shape(p,0.18,0.22,tint)
  "umbrella":
   round_shape(Vector3(0,1.4,0),0.07,2.8,Color("8a765f"))
   var canopy := CylinderMesh.new()
   canopy.top_radius = 0.12
   canopy.bottom_radius = 1.8
   canopy.height = 0.65
   canopy.radial_segments = 8
   var cover := MeshInstance3D.new()
   cover.mesh = canopy
   cover.material_override = mat(tint)
   cover.position.y = 2.8
   add_child(cover)
   round_shape(Vector3(0,3.17,0),0.10,0.1,Color("fff0da"))
  "flower_bed":
   box(Vector3(0,0.14,0),Vector3(2.4,0.28,1.1),Color("bb896c"))
   box(Vector3(0,0.31,0),Vector3(2.15,0.1,0.85),Color("6f8d5f"))
   for x in [-0.8,-0.4,0.0,0.4,0.8]:
    round_shape(Vector3(x,0.46,0),0.13,0.2,Color("e9a6a0" if int((x+0.8)*10)%8 == 0 else "f0ce7c"))
  "banana_tree":
   round_shape(Vector3(0,1.5,0),0.24,3.0,Color("9b9970"))
   cylinder_collision(Vector3(0,1.0,0),0.24,2.0)
   for i in range(6):
    var holder := Node3D.new()
    holder.rotation.y = i * TAU / 6.0
    holder.position = Vector3(0,3.0,0)
    add_child(holder)
    var leaf := MeshInstance3D.new()
    var leaf_shape := BoxMesh.new()
    leaf_shape.size = Vector3(0.7,0.12,2.2)
    leaf.mesh = leaf_shape
    leaf.material_override = mat(tint)
    leaf.position = Vector3(0,0.18,1.0)
    leaf.rotation.x = -0.28
    holder.add_child(leaf)
    cutaway_meshes.append(leaf)
   visual_occlusion_bounds = AABB(Vector3(-2.2, 1.8, -2.2), Vector3(4.4, 3.0, 4.4))
   interior_half_size = Vector2(2.2, 2.2)
  "gazebo":
   for x in [-2.0,2.0]:
    for z in [-2.0,2.0]: box(Vector3(x,1.6,z),Vector3(0.2,3.2,0.2),Color("9b7657"),true)
   var roof := CylinderMesh.new()
   roof.top_radius = 0.25
   roof.bottom_radius = 3.3
   roof.height = 1.2
   roof.radial_segments = 6
   var roof_node := MeshInstance3D.new()
   roof_node.mesh = roof
   roof_node.material_override = mat(Color("c58266"))
   roof_node.position.y = 3.65
   add_child(roof_node)
  "playground":
   for x in [-2.0,2.0]: box(Vector3(x,1.5,0),Vector3(0.2,3,0.2),Color("e6b652"))
   box(Vector3(0,3,0),Vector3(4.2,0.2,0.2),Color("d77960"))
   for x in [-0.8,0.8]:
    box(Vector3(x,1.6,0),Vector3(0.05,2.5,0.05),dark)
    box(Vector3(x,0.4,0),Vector3(0.7,0.12,0.5),Color("78aab2"))

# World instances batch only their own static visual parts by material and
# cutaway visibility. The reusable scene and GLB exporter keep source parts.
func batch_visuals() -> void:
 var groups := {}
 collect_visuals(self, Transform3D.IDENTITY, groups)
 var new_cutaway: Array[MeshInstance3D] = []
 var new_sides: Array[MeshInstance3D] = []
 var old_visuals: Array[MeshInstance3D] = []
 for group in groups.values():
  var surface := SurfaceTool.new()
  surface.begin(Mesh.PRIMITIVE_TRIANGLES)
  for item in group.items:
   surface.append_from(item.node.mesh, 0, item.transform)
   old_visuals.append(item.node)
  var mesh := surface.commit()
  var combined := MeshInstance3D.new()
  combined.name = "VisualBatch"
  combined.mesh = mesh
  combined.material_override = group.material
  add_child(combined)
  if group.cutaway: new_cutaway.append(combined)
  if group.side: new_sides.append(combined)
 for visual in old_visuals: visual.free()
 cutaway_meshes = new_cutaway
 side_cutaway_meshes = new_sides

func collect_visuals(node: Node, parent_transform: Transform3D, groups: Dictionary) -> void:
 for child in node.get_children():
  if child is not Node3D: continue
  var transform: Transform3D = parent_transform * child.transform
  if child is MeshInstance3D and child.mesh != null:
   var material: StandardMaterial3D = child.material_override as StandardMaterial3D
   if material == null: continue
   var cutaway := cutaway_meshes.has(child)
   var side := side_cutaway_meshes.has(child)
   var key := material.albedo_color.to_html() + ("_cut" if cutaway else ("_side" if side else "_fixed"))
   if not groups.has(key): groups[key] = {"material":material,"cutaway":cutaway,"side":side,"items":[]}
   groups[key].items.append({"node":child,"transform":transform})
  collect_visuals(child, transform, groups)

# Hide visual shell when it covers the player, leaving all collisions active.
func _process(_delta: float) -> void:
 if Engine.is_editor_hint() or cutaway_meshes.is_empty(): return
 if not is_instance_valid(tracked_player):
  tracked_player = get_tree().get_first_node_in_group("players") as Node3D
 if not is_instance_valid(tracked_player): return
 var camera := get_viewport().get_camera_3d()
 var show_map := camera != null and camera.projection == Camera3D.PROJECTION_ORTHOGONAL and camera.size > 100.0
 var local_player := to_local(tracked_player.global_position)
 var inside := absf(local_player.x) < interior_half_size.x and absf(local_player.z) < interior_half_size.y and local_player.y < 3.0
 var blocks_view := false
 if camera != null and not show_map and not inside:
  var eye := tracked_player.global_position + Vector3.UP * 0.9
  # Orthographic viewing rays are parallel, regardless of camera position.
  var toward_camera := camera.global_basis.z.normalized() * 40.0
  blocks_view = visual_occlusion_bounds.intersects_segment(to_local(eye),to_local(eye+toward_camera)) != null
 var clear_shell := show_map or not (inside or blocks_view)
 for visual in cutaway_meshes: visual.visible = clear_shell
 # Keep side walls for depth unless they face the camera and can obscure the player.
 var side_faces_camera := false
 if camera != null:
  var local_view := global_basis.inverse() * camera.global_basis.z
  side_faces_camera = absf(local_view.x) > absf(local_view.z)
 for visual in side_cutaway_meshes: visual.visible = clear_shell or not side_faces_camera
