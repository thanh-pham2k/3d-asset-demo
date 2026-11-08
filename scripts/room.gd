extends Node3D
const CREAM = Color("efd0bf")
const WOOD = Color("c98256")
const DARK = Color("9b6040")
const WHITE = Color("fff0df")
const GREEN = Color("879447")
const PINK = Color("e69da9")

func _ready() -> void:
 # A wide cutaway room, with the kitchen occupying the right-hand end.
 box(Vector3(0,-0.12,0), Vector3(18,0.24,9), WOOD, true)
 for z in range(-8,9):
  box(Vector3(0,0.006,z*0.5), Vector3(18,0.01,0.015), Color("b9754d"))
 for row in range(-8,9):
  for col in range(-4,5):
   box(Vector3(col*2.0 + (1.0 if row % 2 else 0.0),0.008,row*0.5+0.25), Vector3(0.012,0.012,0.5), Color("bb7850"))
 wall(Vector3(0,1.35,-4.48), Vector3(18,2.7,0.16))
 wall(Vector3(-8.98,1.35,0), Vector3(0.16,2.7,9))
 wall(Vector3(8.98,1.35,0), Vector3(0.16,2.7,9))
 Art.solid(self, Vector3(0,1,4.48), Vector3(18,2,0.16))
 box(Vector3(0,0.14,-4.36),Vector3(18,0.28,0.1),DARK)
 # Tiled kitchen strip, counter and fridge along the far right wall.
 box(Vector3(5.15,0.014,-0.8),Vector3(3.65,0.025,7.1),Color("e9d8d0"))
 for x in range(7,15): box(Vector3(x*0.5-0.1,0.03,-0.8),Vector3(0.014,0.012,7.1),Color("cbbab5"))
 for z in range(-8,6): box(Vector3(5.15,0.03,z*0.5),Vector3(3.65,0.012,0.014),Color("cbbab5"))
 box(Vector3(4.55,0.45,-4.02),Vector3(1.9,0.9,0.75),GREEN,true)
 box(Vector3(4.55,0.93,-4.02),Vector3(2.0,0.1,0.84),WHITE)
 # Sink rim, basin inset and simple tap silhouette.
 box(Vector3(4.65,0.99,-3.98),Vector3(0.65,0.025,0.48),Color("85848a"))
 box(Vector3(4.65,1.01,-3.98),Vector3(0.49,0.018,0.33),Color("656b6c"))
 box(Vector3(4.65,1.15,-4.25),Vector3(0.055,0.33,0.055),Color("8a9091"))
 box(Vector3(4.65,1.31,-4.16),Vector3(0.055,0.055,0.20),Color("8a9091"))
 for x in [3.95,4.35,5.0,5.35]: box(Vector3(x,0.46,-3.63),Vector3(0.025,0.66,0.03),Color("c0c28b"))
 var fridge_root := Node3D.new()
 fridge_root.position = Vector3(6.20,0,-4.00)
 fridge_root.rotation.y = PI
 add_child(fridge_root)
 Art.kenney(fridge_root, "kitchenFridge", Vector3.ZERO, 1.84)
 Art.solid(self,Vector3(6.20,0.92,-4.00),Vector3(0.85,1.84,0.8))
 plant(Vector3(6.2,1.85,-4.0))
 # Dining table and two chairs.
 # Kenney table and chairs retain the previous physical footprints.
 var table_root := Node3D.new()
 table_root.position = Vector3(5.0,0,0.25)
 table_root.scale = Vector3(0.94,1,0.82)
 add_child(table_root)
 Art.kenney(table_root, "tableRound", Vector3.ZERO, 0.80)
 Art.solid(self,Vector3(5,0.35,0.25),Vector3(0.16,0.7,0.16))
 for x in [4.0,6.0]:
  var chair_root := Node3D.new()
  chair_root.position = Vector3(x,0,0.25)
  chair_root.rotation.y = PI / 2.0 if x < 5.0 else -PI / 2.0
  add_child(chair_root)
  Art.kenney(chair_root, "chairCushion", Vector3.ZERO, 0.9)
  Art.solid(self,Vector3(x,0.46,0.25),Vector3(0.55,0.14,0.55))
 plant(Vector3(5,0.8,0.25))
 # A cabinet and bookshelf on the expanded wall leave the middle open.
 # Their colliders match the footprint, rather than blocking the aisle.
 box(Vector3(-7.75,0.93,-4.0),Vector3(1.12,1.86,0.76),Color("c89464"),true)
 for x in [-8.02,-7.48]:
  box(Vector3(x,1.0,-3.59),Vector3(0.48,1.53,0.04),Color("dfb888"))
  Art.ball(self,Vector3(x+0.15,1.0,-3.54),0.035,Color("80624c"))
 Art.kenney(self, "bookcaseOpen", Vector3(7.75,0,-4.02), 1.66)
 Art.solid(self,Vector3(7.75,0.83,-4.02),Vector3(1.16,1.66,0.70))
 # Rear wall: window and work desk.
 box(Vector3(-5.25,1.75,-4.37),Vector3(1.55,1.05,0.05),WHITE)
 box(Vector3(-5.25,1.75,-4.33),Vector3(1.38,0.90,0.04),Color("8dc5d7"))
 box(Vector3(-5.25,1.75,-4.29),Vector3(0.06,0.95,0.05),WHITE)
 box(Vector3(-5.25,1.75,-4.28),Vector3(1.4,0.06,0.05),WHITE)
 # Curtain folds frame the window rather than covering it.
 box(Vector3(-5.25,2.37,-4.25),Vector3(1.95,0.07,0.08),DARK)
 for x in [-6.07,-5.98,-5.89,-4.61,-4.52,-4.43]:
  box(Vector3(x,1.86,-4.23),Vector3(0.11,1.08,0.09),Color("e8b9b0"))
 for x in [-5.99,-4.51]:
  box(Vector3(x,1.55,-4.16),Vector3(0.31,0.07,0.08),Color("f8dfc0"))
 var desk_root := Node3D.new()
 desk_root.position = Vector3(-5.2,0,-3.9)
 desk_root.scale = Vector3(1.25,1,1)
 add_child(desk_root)
 Art.kenney(desk_root, "desk", Vector3.ZERO, 0.78)
 Art.solid(self,Vector3(-5.2,0.72,-3.9),Vector3(1.75,0.12,0.85))
 Art.kenney(self, "laptop", Vector3(-5.2,0.79,-3.87), 0.39)
 Art.kenney(self, "books", Vector3(-5.85,0.79,-3.85), 0.16)
 Art.kenney(self, "chairDesk", Vector3(-5.2,0,-2.95), 0.75)
 # TV console, coffee table and circular rug.
 Art.kenney(self, "cabinetTelevision", Vector3(-2.55,0,-4.03), 0.65)
 Art.solid(self,Vector3(-2.55,0.34,-4.03),Vector3(1.8,0.65,0.65))
 Art.kenney(self, "televisionModern", Vector3(-2.55,0.65,-4.04), 0.75)
 cylinder(Vector3(-2.35,0.035,-0.6),1.38,0.035,Color("f1d1b1"))
 cylinder(Vector3(-2.35,0.058,-0.6),1.15,0.016,Color("e9ad8e"))
 var sofa_root := Node3D.new()
 sofa_root.position = Vector3(-2.35,0,-0.40)
 sofa_root.rotation.y = PI
 add_child(sofa_root)
 var sofa := Art.kenney(sofa_root, "loungeSofa", Vector3.ZERO, 0.95)
 # Recolor the upholstery only; retain Kenney's natural wood legs.
 for surface in range(sofa.mesh.get_surface_count()):
  var mat := sofa.mesh.surface_get_material(surface)
  if mat and "carpet" in mat.resource_name.to_lower():
   var sage := mat.duplicate() as StandardMaterial3D
   sage.albedo_color = Color("8b9e59")
   sofa.set_surface_override_material(surface,sage)
 Art.solid(self,Vector3(-2.35,0.29,-0.40),Vector3(2.15,0.58,0.78))
 # Loose cushions and blanket create soft silhouettes without affecting collision.
 box(Vector3(-3.02,0.88,-0.49),Vector3(0.40,0.38,0.16),Color("e8bbab"))
 box(Vector3(-1.72,0.88,-0.49),Vector3(0.40,0.38,0.16),Color("f0d9b2"))
 box(Vector3(-3.1,0.68,-0.25),Vector3(0.28,0.04,0.62),Color("e9ddbf"))
 make_interaction("sofa",Vector3(-2.35,0,0.25),Vector3(-2.35,0,0.48),Vector3(-2.35,0.75,-0.38))
 Art.kenney(self, "tableCoffee", Vector3(-2.35,0,-1.75), 0.56)
 Art.solid(self,Vector3(-2.35,0.32,-1.75),Vector3(1.25,0.64,0.58))
 # Bed in the left foreground.
 var bed_root := Node3D.new()
 bed_root.position = Vector3(-5.5,0,2.75)
 bed_root.rotation.y = PI
 bed_root.scale = Vector3(0.76,1.0,0.92)
 add_child(bed_root)
 Art.kenney(bed_root, "bedDouble", Vector3.ZERO, 0.8)
 Art.solid(self,Vector3(-5.5,0.27,2.75),Vector3(1.55,0.54,2.2))
 # Bedside table at the side wall and blanket seams.
 Art.kenney(self, "cabinetBedDrawer", Vector3(-7.02,0,1.95), 0.70)
 Art.solid(self,Vector3(-7.02,0.35,1.95),Vector3(0.72,0.70,0.72))
 make_interaction("bed",Vector3(-4.55,0,2.7),Vector3(-4.4,0,2.7),Vector3(-5.5,0.82,2.7))
 # Wall picture and clock are mounted high to avoid gameplay occlusion.
 picture(Vector3(1.5,1.85,-4.35), Vector2(0.78,0.65), Color("9fbba9"))
 picture(Vector3(2.48,1.85,-4.35), Vector2(0.62,0.72), Color("e3b395"))
 var clock = Node3D.new()
 clock.position = Vector3(3.23,2.05,-4.30)
 clock.rotation.x = PI / 2.0
 add_child(clock)
 var clock_face := MeshInstance3D.new()
 var clock_mesh := CylinderMesh.new()
 clock_mesh.top_radius = 0.26
 clock_mesh.bottom_radius = 0.26
 clock_mesh.height = 0.06
 clock_mesh.radial_segments = 24
 clock_face.mesh = clock_mesh
 clock_face.material_override = Art.material(WHITE)
 clock.add_child(clock_face)
 box(Vector3(3.23,2.10,-4.25),Vector3(0.025,0.17,0.03),DARK)
 box(Vector3(3.28,2.04,-4.25),Vector3(0.10,0.025,0.03),DARK)
 # Door and lamp at the back, with room boundary intentionally closed.
 var hinge = Node3D.new()
 hinge.position = Vector3(-0.55,0,-4.35)
 add_child(hinge)
 Art.box(hinge,Vector3(0.5,1.05,0),Vector3(1.0,2.1,0.12),Color("995332"))
 Art.ball(hinge,Vector3(0.83,1.0,0.10),0.08,Color("e8b354"))
 for y in [0.62,1.52]:
  Art.box(hinge,Vector3(0.47,y,0.075),Vector3(0.62,0.62,0.035),Color("ad6742"))
  Art.box(hinge,Vector3(0.47,y,0.10),Vector3(0.50,0.50,0.02),Color("995332"))
 var door = make_interaction("door",Vector3(0,0,-3.73),Vector3.ZERO,Vector3.ZERO)
 door.moving_part = hinge
 box(Vector3(-4.4,1.02,-4.0),Vector3(0.08,0.5,0.08),DARK)
 Art.ball(self,Vector3(-4.4,1.3,-4.0),0.18,Color("f8d28b"))
 var lamp = make_interaction("lamp",Vector3(-4.35,0,-3.5),Vector3.ZERO,Vector3.ZERO)
 lamp.toggle = true
 lamp.light = OmniLight3D.new()
 lamp.light.position = Vector3(0,1.4,0)
 lamp.light.light_color = Color("ffd49a")
 lamp.light.light_energy = 0.6
 lamp.light.omni_range = 3.0
 lamp.add_child(lamp.light)

func box(pos: Vector3, size: Vector3, color: Color, solid := false) -> void:
 Art.box(self,pos,size,color)
 if solid: Art.solid(self,pos,size)

func wall(pos: Vector3, size: Vector3) -> void:
 box(pos,size,CREAM,true)

func cylinder(pos: Vector3, radius: float, height: float, color: Color) -> void:
 var mesh := MeshInstance3D.new()
 var shape := CylinderMesh.new()
 shape.top_radius = radius
 shape.bottom_radius = radius
 shape.height = height
 shape.radial_segments = 32
 mesh.mesh = shape
 mesh.material_override = Art.material(color)
 mesh.position = pos
 add_child(mesh)

func picture(pos: Vector3, dimensions: Vector2, color: Color) -> void:
 box(pos,Vector3(dimensions.x,dimensions.y,0.08),Color("aa7454"))
 box(pos+Vector3(0,0,0.05),Vector3(dimensions.x-0.10,dimensions.y-0.10,0.025),color)
 box(pos+Vector3(0,-0.12,0.07),Vector3(dimensions.x-0.18,0.12,0.02),Color("e8d2ad"))

func plant(pos: Vector3) -> void:
 Art.kenney(self, "plantSmall1", pos, 0.42)

func make_interaction(type: String, pos: Vector3, stand: Vector3, seat: Vector3) -> Interactable:
 var item = Interactable.new()
 item.kind = type
 item.position = pos
 item.stand_point = stand
 item.seat_point = seat
 add_child(item)
 return item
