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
 box(Vector3(4.65,0.99,-3.98),Vector3(0.65,0.025,0.48),Color("85848a"))
 for x in [3.95,4.35,5.0,5.35]: box(Vector3(x,0.46,-3.63),Vector3(0.025,0.66,0.03),Color("c0c28b"))
 box(Vector3(6.20,0.92,-4.00),Vector3(0.85,1.84,0.8),Color("f5e5c9"),true)
 box(Vector3(6.20,1.03,-3.58),Vector3(0.84,0.035,0.03),DARK)
 plant(Vector3(6.2,1.85,-4.0))
 # Dining table and two chairs.
 cylinder(Vector3(5.0,0.73,0.25),0.68,0.12,Color("d7954f"))
 box(Vector3(5,0.35,0.25),Vector3(0.16,0.7,0.16),DARK,true)
 for x in [4.0,6.0]:
  box(Vector3(x,0.46,0.25),Vector3(0.55,0.14,0.55),Color("d99856"),true)
  box(Vector3(x,0.80,-0.02),Vector3(0.55,0.62,0.1),Color("d99856"))
 plant(Vector3(5,0.8,0.25))
 # Rear wall: window and work desk.
 box(Vector3(-5.25,1.75,-4.37),Vector3(1.55,1.05,0.05),WHITE)
 box(Vector3(-5.25,1.75,-4.33),Vector3(1.38,0.90,0.04),Color("8dc5d7"))
 box(Vector3(-5.25,1.75,-4.29),Vector3(0.06,0.95,0.05),WHITE)
 box(Vector3(-5.25,1.75,-4.28),Vector3(1.4,0.06,0.05),WHITE)
 box(Vector3(-5.2,0.72,-3.9),Vector3(1.75,0.12,0.85),Color("d99a59"),true)
 for x in [-5.9,-4.5]: box(Vector3(x,0.35,-3.9),Vector3(0.12,0.7,0.7),DARK)
 box(Vector3(-5.2,0.81,-3.83),Vector3(0.58,0.06,0.37),Color("4f4e58"))
 box(Vector3(-5.2,1.05,-4.0),Vector3(0.58,0.48,0.05),Color("4f4e58"))
 # TV console, coffee table and circular rug.
 box(Vector3(-2.55,0.34,-4.03),Vector3(1.8,0.65,0.65),Color("cd8b52"),true)
 box(Vector3(-2.55,1.03,-4.15),Vector3(1.22,0.75,0.10),Color("3d3b4b"))
 box(Vector3(-2.55,1.03,-4.08),Vector3(1.10,0.63,0.02),Color("666479"))
 cylinder(Vector3(-2.35,0.035,-0.6),1.38,0.035,Color("f1d1b1"))
 cylinder(Vector3(-2.35,0.058,-0.6),1.15,0.016,Color("e9ad8e"))
 box(Vector3(-2.35,0.29,-0.40),Vector3(2.15,0.58,0.78),GREEN,true)
 box(Vector3(-2.35,0.70,-0.72),Vector3(2.15,0.7,0.18),GREEN)
 for x in [-3.30,-1.4]: box(Vector3(x,0.58,-0.40),Vector3(0.24,0.48,0.8),Color("788b42"))
 for x in [-2.98,-2.35,-1.72]: box(Vector3(x,0.62,-0.35),Vector3(0.60,0.12,0.6),Color("a1ad60"))
 make_interaction("sofa",Vector3(-2.35,0,0.25),Vector3(-2.35,0,0.48),Vector3(-2.35,0.75,-0.38))
 box(Vector3(-2.35,0.5,-1.75),Vector3(1.25,0.12,0.58),Color("dfa560"),true)
 # Bed in the left foreground.
 box(Vector3(-5.5,0.27,2.75),Vector3(1.55,0.54,2.2),DARK,true)
 box(Vector3(-5.5,0.59,2.75),Vector3(1.45,0.16,2.08),WHITE)
 box(Vector3(-5.5,0.70,3.05),Vector3(1.42,0.12,1.35),PINK)
 box(Vector3(-5.5,0.82,1.7),Vector3(1.6,0.85,0.12),Color("d6934f"))
 box(Vector3(-5.5,0.73,2.0),Vector3(0.85,0.14,0.4),WHITE)
 make_interaction("bed",Vector3(-4.55,0,2.7),Vector3(-4.4,0,2.7),Vector3(-5.5,0.82,2.7))
 # Door and lamp at the back, with room boundary intentionally closed.
 var hinge = Node3D.new()
 hinge.position = Vector3(-0.55,0,-4.35)
 add_child(hinge)
 Art.box(hinge,Vector3(0.5,1.05,0),Vector3(1.0,2.1,0.12),Color("995332"))
 Art.ball(hinge,Vector3(0.83,1.0,0.10),0.08,Color("e8b354"))
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

func plant(pos: Vector3) -> void:
 Art.box(self,pos+Vector3(0,0.1,0),Vector3(0.2,0.2,0.2),Color("c89259"))
 for offset in [Vector3(0,0.31,0),Vector3(0.13,0.27,0),Vector3(-0.13,0.27,0)]:
  Art.ball(self,pos+offset,0.14,Color("78964e"))

func make_interaction(type: String, pos: Vector3, stand: Vector3, seat: Vector3) -> Interactable:
 var item = Interactable.new()
 item.kind = type
 item.position = pos
 item.stand_point = stand
 item.seat_point = seat
 add_child(item)
 return item
