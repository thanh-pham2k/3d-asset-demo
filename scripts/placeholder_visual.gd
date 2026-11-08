extends Node3D

var player_id := 1
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
const SKIN = Color("f4c9ab")
const HAIR = Color("594339")

func _ready() -> void:
 var shirt = Color("f8f5e9") if player_id == 1 else Color("f4d278")
 var pants = Color("394d68")
 Art.box(self, Vector3(0,0.70,0), Vector3(0.47,0.5,0.28), shirt)
 Art.ball(self, Vector3(0,1.28,0), 0.32, SKIN, Vector3(1,0.95,0.94))
 Art.ball(self, Vector3(0,1.45,-0.025), 0.325, HAIR, Vector3(1,0.53,0.98))
 if player_id == 1:
  for x in [-0.20,0.0,0.20]: Art.box(self, Vector3(x,1.46,0.19), Vector3(0.16,0.17,0.17), HAIR, Vector3(0,0,x))
 else:
  Art.box(self, Vector3(0,1.27,-0.21), Vector3(0.58,0.42,0.15), HAIR)
  Art.box(self, Vector3(-0.24,1.54,0.01), Vector3(0.16,0.12,0.09), Color("ef8fa5"), Vector3(0,0,0.35))
  Art.box(self, Vector3(-0.36,1.54,0.01), Vector3(0.16,0.12,0.09), Color("ef8fa5"), Vector3(0,0,-0.35))
 for x in [-0.12,0.12]:
  Art.ball(self, Vector3(x,1.31,0.288), 0.035, Color("47382f"), Vector3(0.7,1.2,0.4))
 Art.box(self, Vector3(0,1.20,0.30), Vector3(0.09,0.022,0.015), Color("9c5b58"))
 left_arm = limb(Vector3(-0.31,0.87,0), Vector3(0.15,0.42,0.16), shirt)
 right_arm = limb(Vector3(0.31,0.87,0), Vector3(0.15,0.42,0.16), shirt)
 left_leg = limb(Vector3(-0.13,0.48,0), Vector3(0.20,0.46,0.22), pants)
 right_leg = limb(Vector3(0.13,0.48,0), Vector3(0.20,0.46,0.22), pants)

func limb(pos: Vector3, size: Vector3, color: Color) -> Node3D:
 var pivot = Node3D.new()
 pivot.position = pos
 add_child(pivot)
 Art.box(pivot, Vector3(0,-size.y/2,0), size, color)
 return pivot

