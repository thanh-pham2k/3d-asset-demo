extends Node3D

const MODULE = preload("res://scripts/neighborhood/module.gd")
const WorkplaceGuidance = preload("res://scripts/workplace_guidance.gd")
const PlayerScooter = preload("res://scripts/neighborhood/player_scooter.gd")
const DailyLoopManager = preload("res://scripts/neighborhood/daily_loop_manager.gd")
const EconomyManager = preload("res://scripts/economy/economy_manager.gd")
const EconomySaveSystem = preload("res://scripts/economy/economy_save_system.gd")
const CoopManager = preload("res://scripts/coop/coop_manager.gd")
@export var integrated := false
@export var economy_save_path := EconomySaveSystem.DEFAULT_SAVE_PATH
var camera: Camera3D
var player: CharacterBody3D
var player_2: CharacterBody3D
var coop_manager: CoopManager
var is_coop: bool = false
var coop_obstacle: Node3D
var coop_bench: Node3D
var guidance: WorkplaceGuidance
var boy_scooter: PlayerScooter
var girl_scooter: PlayerScooter
var overview := false
var time_manager: NeighborhoodTimeManager
var npc_manager: NPCManager
var nav_region: NavigationRegion3D
var clock_label: Label
var economy_manager: EconomyManager
var daily_loop_manager: Node
var wallet_label: Label
var goal_label: Label
var street_lights: Array[OmniLight3D] = []

func slab(parent: Node, pos: Vector3, size: Vector3, color: Color, collision := false) -> void:
 var mesh := MeshInstance3D.new()
 var geometry := BoxMesh.new()
 geometry.size = size
 mesh.mesh = geometry
 var material := StandardMaterial3D.new()
 material.albedo_color = color.lerp(color.srgb_to_linear(), 0.5)
 material.roughness = 1.0
 mesh.material_override = material
 mesh.position = pos
 parent.add_child(mesh)
 if collision:
  var body := StaticBody3D.new()
  var shape := CollisionShape3D.new()
  var cube := BoxShape3D.new()
  cube.size = size
  shape.shape = cube
  body.position = pos
  body.add_child(shape)
  parent.add_child(body)

func _add_street_lamp(parent: Node3D, location: Vector3) -> void:
 var lamp := add_piece(parent, "lamp", location)
 var glow := OmniLight3D.new()
 glow.name = "NightGlow"
 glow.position = Vector3(0, 4.25, 0)
 glow.light_color = Color("ffd99c")
 glow.light_energy = 0.65
 glow.omni_range = 7.0
 glow.shadow_enabled = false
 glow.visible = false
 lamp.add_child(glow)
 street_lights.append(glow)

func _on_street_light_period_changed(period: String) -> void:
 for glow in street_lights:
  if is_instance_valid(glow): glow.visible = period == "night"

func _create_parking_bay(p_parent: Node, p_pos: Vector3, p_rot_y: float, p_title: String, p_color: Color) -> Node3D:
 var bay := Node3D.new()
 bay.position = p_pos
 bay.rotation.y = p_rot_y
 for offset_x in [-1.1, 1.1]:
  var line := MeshInstance3D.new()
  var b := BoxMesh.new()
  b.size = Vector3(0.08, 0.04, 2.4)
  line.mesh = b
  var m := StandardMaterial3D.new()
  m.albedo_color = Color("fff8e1")
  line.material_override = m
  line.position = Vector3(offset_x, 0.02, 0)
  bay.add_child(line)
 var pole := MeshInstance3D.new()
 var cyl := CylinderMesh.new()
 cyl.top_radius = 0.04
 cyl.bottom_radius = 0.04
 cyl.height = 1.6
 pole.mesh = cyl
 var pole_m := StandardMaterial3D.new()
 pole_m.albedo_color = Color("455a64")
 pole.material_override = pole_m
 pole.position = Vector3(1.3, 0.8, -1.0)
 bay.add_child(pole)
 var sign_label := Label3D.new()
 sign_label.position = Vector3(1.3, 1.75, -1.0)
 sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
 sign_label.font_size = 22
 sign_label.pixel_size = 0.004
 sign_label.outline_size = 6
 sign_label.modulate = p_color
 sign_label.outline_modulate = Color("1a1a1a")
 sign_label.text = "🅿️ %s" % p_title
 bay.add_child(sign_label)
 p_parent.add_child(bay)
 return bay

func add_piece(parent: Node, kind: String, pos: Vector3, color := Color.WHITE, rot := 0.0) -> Node3D:
 var piece: Node3D = load("res://scenes/neighborhood/%s.tscn" % kind).instantiate()
 piece.position = pos
 piece.rotation.y = rot
 if color != Color.WHITE: piece.tint = color
 parent.add_child(piece)
 piece.batch_visuals()
 return piece

func zone(label: String) -> Node3D:
 var n := Node3D.new()
 n.name = label
 add_child(n)
 return n

func _ready() -> void:
 # The indoor game manager normally installs these bindings at startup.
 for action in {"p1_left":KEY_A,"p1_right":KEY_D,"p1_up":KEY_W,"p1_down":KEY_S,"p1_interact":KEY_E,"p1_throw":KEY_F,"p1_dash":KEY_SPACE,"p1_swing":KEY_Q,"p1_run":KEY_SHIFT}:
  if not InputMap.has_action(action):
   InputMap.add_action(action)
   var key := InputEventKey.new()
   key.physical_keycode = {"p1_left":KEY_A,"p1_right":KEY_D,"p1_up":KEY_W,"p1_down":KEY_S,"p1_interact":KEY_E,"p1_throw":KEY_F,"p1_dash":KEY_SPACE,"p1_swing":KEY_Q,"p1_run":KEY_SHIFT}[action]
   if action == "p1_run":
    key.physical_keycode = 0
    key.keycode = KEY_SHIFT
    key.location = KEY_LOCATION_LEFT
   InputMap.action_add_event(action,key)
 var ground := zone("GroundAndRoads")
 slab(ground,Vector3(0,-0.45,0),Vector3(250,0.7,250),Color("a9c893"))
 # Keep the walkable collision flush with the house floor while the visual
 # ground sits below it, avoiding overlapping surfaces inside the house.
 var ground_body := StaticBody3D.new()
 var ground_shape := CollisionShape3D.new()
 var ground_box := BoxShape3D.new()
 ground_box.size = Vector3(250, 0.7, 250)
 ground_shape.shape = ground_box
 ground_body.position = Vector3(0, -0.35, 0)
 ground_body.add_child(ground_shape)
 ground.add_child(ground_body)
 # Invisible perimeter prevents falling from the terrain, including during a dash.
 var boundaries := zone("MapBoundaries")
 for spec in [[Vector3(-125.5,2,0),Vector3(1,4,252)],[Vector3(125.5,2,0),Vector3(1,4,252)],[Vector3(0,2,-125.5),Vector3(250,4,1)],[Vector3(0,2,125.5),Vector3(250,4,1)]]:
  var boundary := StaticBody3D.new()
  var collider := CollisionShape3D.new()
  var boundary_shape := BoxShape3D.new()
  boundary_shape.size = spec[1]
  collider.shape = boundary_shape
  boundary.position = spec[0]
  boundary.add_child(collider)
  boundaries.add_child(boundary)
 # Main east-west boulevard and three connected north-south streets.
 slab(ground,Vector3(0,0.01,0),Vector3(250,0.04,12),Color("777b73"))
 for x in [-80.0,0.0,80.0]:
  slab(ground,Vector3(x,0.015,0),Vector3(8,0.05,250),Color("858781"))
  for z in [-100.0,-60.0,-20.0,20.0,60.0,100.0]: slab(ground,Vector3(x,0.05,z),Vector3(0.15,0.02,4),Color("f4df9b"))
 # Leave gaps at cross streets rather than painting curb slabs over asphalt.
 for z in [-8.0,8.0]:
  for span in [[-125.0,-84.0],[-76.0,-4.0],[4.0,76.0],[84.0,125.0]]:
   slab(ground,Vector3((span[0]+span[1])/2.0,0.03,z),Vector3(span[1]-span[0],0.1,4),Color("e0d3b9"))
 for x in range(-120,121,10): slab(ground,Vector3(x,0.06,0),Vector3(4,0.02,0.17),Color("f6df99"))
 # Local streets connect the residential blocks to all three side streets.
 slab(ground,Vector3(0,0.025,-54),Vector3(250,0.06,6),Color("92938a"))
 slab(ground,Vector3(-40,0.025,50),Vector3(80,0.06,6),Color("92938a"))
 # Crossings span road widths at sidewalk continuations. The source module
 # is visual-only; scaling changes marking dimensions without adding collision.
 var crossings := zone("Crossings")
 for x in [-80.0,0.0,80.0]:
  for side in [-1.0,1.0]:
   var boulevard_crossing := add_piece(crossings,"crossing",Vector3(x+side*6,0.08,0),Color.WHITE,PI/2)
   boulevard_crossing.scale.x = 12.0 / 6.5
   var side_crossing := add_piece(crossings,"crossing",Vector3(x,0.08,side*8),Color.WHITE)
   side_crossing.scale.x = 8.0 / 6.5
   var north_crossing := add_piece(crossings,"crossing",Vector3(x+side*6,0.08,-54),Color.WHITE,PI/2)
   north_crossing.scale.x = 6.0 / 6.5
   var north_side := add_piece(crossings,"crossing",Vector3(x,0.08,-54+side*4),Color.WHITE)
   north_side.scale.x = 8.0 / 6.5
 for x in [-80.0,0.0]:
  for side in [-1.0,1.0]:
   # The southern local street only exists between the two side roads.
   if (x == -80.0 and side < 0.0) or (x == 0.0 and side > 0.0): continue
   var local_crossing := add_piece(crossings,"crossing",Vector3(x+side*6,0.08,50),Color.WHITE,PI/2)
   local_crossing.scale.x = 6.0 / 6.5
  for side in [-1.0,1.0]:
   var street_crossing := add_piece(crossings,"crossing",Vector3(x,0.08,50+side*4),Color.WHITE)
   street_crossing.scale.x = 8.0 / 6.5
 # Sidewalks along side streets; interruptions at the main crossing.
 for x in [-86.0,-74.0,-6.0,6.0,74.0,86.0]:
  for span in [[-123.0,-59.0],[-49.0,-11.0],[11.0,45.0],[55.0,123.0]]:
   slab(ground,Vector3(x,0.03,(span[0]+span[1])/2.0),Vector3(3,0.1,span[1]-span[0]),Color("e0d3b9"))
 for z in [-58.0,-50.0]:
  for span in [[-125.0,-84.0],[-76.0,-4.0],[4.0,76.0],[84.0,125.0]]:
   slab(ground,Vector3((span[0]+span[1])/2.0,0.03,z),Vector3(span[1]-span[0],0.1,2),Color("e0d3b9"))
 for z in [46.0,54.0]: slab(ground,Vector3(-40,0.03,z),Vector3(72,0.1,2),Color("e0d3b9"))
 var house := zone("01_StarterHouse")
 slab(house,Vector3(-43,-0.06,85),Vector3(46,0.08,45),Color("c4d6a6"))
 if not integrated: add_piece(house,"house",Vector3(-45,0,88),Color("f3dfaa"))
 # Starter-home floor and simple furnishings leave the central doorway clear.
 if not integrated: slab(house,Vector3(-45,0.17,88),Vector3(8.4,0.04,7.4),Color("bd8c69"))
 # The kitchen floor is a separate decorative surface, above the wooden floor.
 if not integrated: slab(house,Vector3(-42.4,0.205,89.8),Vector3(2.5,0.035,2.7),Color("e6e0c9"))
 for x in [-43.4,-42.6,-41.8]:
  for z in [89.0,89.8,90.6]:
   if not integrated: slab(house,Vector3(x,0.23,z),Vector3(0.74,0.02,0.74),Color("c5d4c6"))
 if not integrated: add_piece(house,"sofa",Vector3(-47.5,0.2,90),Color("799c7b"))
 if not integrated: add_piece(house,"kitchen_counter",Vector3(-42.4,0.2,90))
 for p in [Vector3(-56,0,76),Vector3(-35,0,78),Vector3(-54,0,97)]: add_piece(house,"planter",p)
 slab(house,Vector3(-45,0.06,76),Vector3(3,0.1,15),Color("d7b999"))
 # Front and side openings keep the yard connected to the surrounding streets.
 for x in [-64.0,-60.0,-56.0,-52.0,-38.0,-34.0,-30.0,-26.0,-22.0]:
  add_piece(house,"yard_fence",Vector3(x,0,63))
 for x in range(-64,-21,4): add_piece(house,"yard_fence",Vector3(x,0,107))
 for z in [67.0,71.0,75.0,79.0,91.0,95.0,99.0,103.0]:
  add_piece(house,"yard_fence",Vector3(-66,0,z),Color.WHITE,PI/2)
 for z in [67.0,71.0,75.0,79.0,83.0,87.0,91.0,95.0,99.0,103.0]:
  add_piece(house,"yard_fence",Vector3(-20,0,z),Color.WHITE,PI/2)
 add_piece(house,"clothesline",Vector3(-56,0,100),Color.WHITE,PI/2)
 for p in [Vector3(-59,0,68),Vector3(-26,0,69),Vector3(-27,0,100)]: add_piece(house,"flower_bed",p)
 var garage := zone("02_MotorcycleRepair")
 var garage_paving := add_piece(garage, "paved_court", Vector3(-105, 0, -14))
 garage_paving.scale = Vector3(2.2, 1.0, 1.8)
 add_piece(garage,"garage",Vector3(-105,0,-18),Color("a3bbab"),PI)
 add_piece(garage,"scooter_parking",Vector3(-104,0,-11))
 add_piece(garage,"scooter_parking",Vector3(-108,0,-11))
 add_piece(garage,"tire",Vector3(-111.5,0,-16.5))
 add_piece(garage,"air_pump",Vector3(-110.5,0,-18.5))
 add_piece(garage,"workbench",Vector3(-100.5,0,-18.5))
 # Dedicated Tool Shop stall east of the repair bays (World X = -56, Z = -16)
 add_piece(garage,"market_stall",Vector3(-98,0,-16.5),Color("ffd54f"))
 garage.position.x = 42.0
 var noodle := zone("03_HuTieu")
 var noodle_paving := add_piece(noodle,"paved_court",Vector3(-50,0,-20.5))
 noodle_paving.scale = Vector3(2.0,1.0,2.1)
 add_piece(noodle,"noodle",Vector3(-50,0,-17),Color("83b8bf"))
 for x in [-55.0,-50.0,-45.0]:
  add_piece(noodle,"table",Vector3(x,0,-23),Color("eaa187"))
  add_piece(noodle,"chair",Vector3(x-1,0,-23),Color("dc7666"))
  add_piece(noodle,"chair",Vector3(x+1,0,-23),Color("84acb5"))
 var market := zone("04_WetMarket")
 slab(market,Vector3(38,0.04,-28),Vector3(49,0.08,32),Color("e6cdb2"))
 var market_kinds := ["market_stall","fruit_stall","meat_stall","ingredient_stall"]
 for z in [-38.0,-29.0,-20.0]:
  for i in range(4):
   var x: float = [20.0,31.0,42.0,53.0][i]
   var kind: String = market_kinds[(i + int((z+38.0)/9.0)) % 4]
   add_piece(market,kind,Vector3(x,0,z),[Color("e89b7b"),Color("f0d08b"),Color("9ebda1")][int((x+z+100)/10)%3])
 for item in [[Vector3(20,0,-35),Color("83aa6e")],[Vector3(31,0,-35),Color("e8ba60")],[Vector3(42,0,-35),Color("d58176")],[Vector3(53,0,-35),Color("8fb77a")]]:
  add_piece(market,"produce_crate",item[0],item[1])
 for entry in [[Vector3(21.5,0,-36),Color("dc8b79")],[Vector3(32.5,0,-36),Color("e9c267")],[Vector3(43.5,0,-36),Color("9bb67c")],[Vector3(54.5,0,-36),Color("c77e72")],
               [Vector3(20,0,-26),Color("e1b96f")],[Vector3(31,0,-26),Color("8aad75")],[Vector3(42,0,-26),Color("d98978")],[Vector3(53,0,-26),Color("eacb7c")]]:
  add_piece(market,"market_basket",entry[0],entry[1])
 for entry in [[Vector3(15,0,-44),Color("e4ad83")],[Vector3(60,0,-44),Color("9cbdb0")]]: add_piece(market,"umbrella",entry[0],entry[1])
 var food := zone("05_FoodStreet")
 var food_paving := add_piece(food,"paved_court",Vector3(-101,0,21))
 food_paving.scale = Vector3(3.0,1.0,2.2)
 for entry in [["cafe",-110.0],["banh_mi",-102.0],["juice",-94.0]]: add_piece(food,entry[0],Vector3(entry[1],0,18),Color("e7ac81"))
 add_piece(food,"grocery",Vector3(-105,0,35),Color("d1dfb2"),PI)
 # Shelves sit against the back and side walls, leaving the entrance aisle open.
 add_piece(food,"grocery_shelf",Vector3(-107.7,0,32.0),Color.WHITE,PI)
 add_piece(food,"grocery_shelf",Vector3(-102.3,0,32.0),Color.WHITE,PI)
 add_piece(food,"grocery_counter",Vector3(-108,0,35.0),Color.WHITE,PI/2)
 for x in [-110.0,-100.0,-90.0]:
  add_piece(food,"table",Vector3(x,0,24),Color("96b9b0"))
  add_piece(food,"chair",Vector3(x-1,0,24),Color("d4816a"))
  add_piece(food,"chair",Vector3(x+1,0,24),Color("7ba7a3"))
  add_piece(food,"umbrella",Vector3(x,0,24),Color("e9b48e"))
 var store := zone("06_FurnitureStore")
 add_piece(store,"furniture",Vector3(105,0,-20),Color("b8d2ce"),PI)
 # Individually replaceable, collidable display pieces leave the centre aisle open.
 add_piece(store,"sofa",Vector3(110,0,-23),Color("87a98c"),PI)
 add_piece(store,"bed",Vector3(106.5,0,-23),Color.WHITE,PI)
 add_piece(store,"refrigerator",Vector3(99.7,0,-23.3),Color.WHITE,PI)
 add_piece(store,"television",Vector3(102,0,-23.3),Color.WHITE,PI)
 add_piece(store,"coffee_table",Vector3(110,0,-20))
 var park := zone("07_PublicPark")
 slab(park,Vector3(42,0.04,53),Vector3(54,0.08,58),Color("b9d49f"))
 # Connect the boulevard sidewalk to the park's north-south promenade.
 slab(park,Vector3(42,0.08,17),Vector3(2.4,0.09,18),Color("e6d2b3"))
 for p in [Vector3(34,0,15),Vector3(50,0,15),Vector3(34,0,22),Vector3(50,0,22)]:
  add_piece(park,"tree",p,Color("8bb17e"))
 for p in [Vector3(38,0,20),Vector3(46,0,20)]: add_piece(park,"flower_bed",p)
 slab(park,Vector3(42,0.08,53),Vector3(3,0.09,55),Color("e6d2b3"))
 slab(park,Vector3(42,0.09,53),Vector3(50,0.09,3),Color("e6d2b3"))
 add_piece(park,"pond",Vector3(54,0,66))
 add_piece(park,"playground",Vector3(28,0,63))
 add_piece(park,"slide",Vector3(22,0,67))
 add_piece(park,"gazebo",Vector3(27,0,40))
 for p in [Vector3(19,0,47),Vector3(62,0,55),Vector3(35,0,76)]: add_piece(park,"flower_bed",p)
 for p in [Vector3(21,0,32),Vector3(58,0,34),Vector3(21,0,76),Vector3(64,0,78),Vector3(53,0,46)]: add_piece(park,"tree",p,Color("81ae77"))
 for p in [Vector3(37,0,38),Vector3(47,0,57)]:
  var bench := add_piece(park,"bench",p)
  var seat := Interactable.new()
  seat.name = "ParkSeat"
  seat.add_to_group("park_seats")
  seat.kind = "chair"
  seat.display_name = "Ghế công viên"
  seat.seat_point = Vector3(0, 0.64, 0)
  seat.stand_point = Vector3(0, 0, -1.0)
  seat.interaction_radius = 1.8
  bench.add_child(seat)
 var wildlife := preload("res://scripts/neighborhood/park_wildlife.gd").new()
 wildlife.name = "ParkWildlife"
 park.add_child(wildlife)
 var school := zone("08_School")
 slab(school,Vector3(105,0.04,-75),Vector3(35,0.08,60),Color("e8cbb4"))
 add_piece(school,"school",Vector3(105,0,-95),Color("f4daa5"),PI)
 add_piece(school,"school_gate",Vector3(105,0,-50))
 slab(school,Vector3(105,0.09,-71),Vector3(4,0.08,38),Color("f0ddc3"))
 for p in [Vector3(94,0,-48),Vector3(116,0,-48)]: add_piece(school,"planter",p)
 for p in [Vector3(96,0,-76),Vector3(114,0,-76)]: add_piece(school,"bench",p)
 # Courtyard plantings sit clear of the 11 m gate opening and approach.
 for p in [Vector3(94,0,-62),Vector3(116,0,-62)]: add_piece(school,"flower_bed",p)
 var homes := zone("09_ResidentialAlleys")
 var residential_x := [-58.0,-39.0,-20.0,20.0,39.0,58.0]
 for i in range(residential_x.size()):
  var x: float = residential_x[i]
  for z in [-100.0,-72.0]:
   var variant := "townhouse" if (i + (0 if z == -100.0 else 1)) % 3 == 0 else "house"
   add_piece(homes,variant,Vector3(x,0,z),[Color("f2d6a1"),Color("bad4c2"),Color("b8d5dc")][i%3],PI)
   add_piece(homes,"planter",Vector3(x+5,0,z+5))
 # A separate alley joins the northern residential doorways to local streets.
 slab(homes,Vector3(0,0.04,-84),Vector3(145,0.08,2.5),Color("d9c5a7"))
 # Smaller homes face the added local streets and fill the western blocks.
 var additional_homes := [
  [Vector3(-109,0,-110),-PI/2,Color("f1d5a0")], [Vector3(-109,0,-87),-PI/2,Color("bcd9d4")],
  [Vector3(-109,0,-70),-PI/2,Color("f0c9b4")], [Vector3(-109,0,-40),PI,Color("d3dfb6")],
  [Vector3(-64,0,-40),0.0,Color("c5dad3")], [Vector3(-45,0,-40),0.0,Color("f1d29e")],
  [Vector3(-26,0,-40),0.0,Color("eecabc")],
  [Vector3(-65,0,36),PI,Color("f2d6a1")], [Vector3(-47,0,36),PI,Color("c4dacf")],
  [Vector3(-29,0,36),PI,Color("eac2ae")], [Vector3(-13,0,36),PI,Color("c4d9df")],
  [Vector3(-109,0,61),-PI/2,Color("ead2aa")], [Vector3(-109,0,82),-PI/2,Color("c4d9c7")],
  [Vector3(-109,0,103),-PI/2,Color("d5d8df")]
 ]
 for entry in additional_homes:
  add_piece(homes,"house",entry[0],entry[2],entry[1])
  var door_direction := Vector3(0,0,-1).rotated(Vector3.UP,entry[1])
  var path_position: Vector3 = entry[0] + door_direction * 7.5
  var path := Vector3(2.2,0.08,7)
  if absf(door_direction.x) > 0.5: path = Vector3(7,0.08,2.2)
  slab(homes,path_position + Vector3(0,0.05,0),path,Color("ddc5a7"))
  var pot_position: Vector3 = entry[0] + door_direction * 5.5 + Vector3(2.9,0,0).rotated(Vector3.UP,entry[1])
  add_piece(homes,"planter",pot_position)
 for p in [Vector3(-118,0,-118),Vector3(-94,0,-105),Vector3(-118,0,-60),Vector3(-94,0,-34),
           Vector3(-70,0,-29),Vector3(-34,0,-31),Vector3(-18,0,-23),Vector3(12,0,-48),
           Vector3(63,0,-48),Vector3(-118,0,52),Vector3(-95,0,72),Vector3(-118,0,94),
           Vector3(-95,0,115),Vector3(-70,0,22),Vector3(-37,0,20),Vector3(-20,0,24),
           Vector3(-68,0,108),Vector3(-20,0,110)]:
  add_piece(homes,"tree",p,Color("88ad7b"))
 for p in [Vector3(-59,0,76),Vector3(-30,0,101),Vector3(-118,0,72),Vector3(-60,0,-115),Vector3(55,0,-112),Vector3(15,0,74)]:
  add_piece(homes,"banana_tree",p,Color("86ad72"))
 for p in [Vector3(-55,0,-91),Vector3(-17,0,-91),Vector3(42,0,-91),Vector3(-111,0,74)]:
  add_piece(homes,"clothesline",p,Color.WHITE,PI/2)
 var lot := zone("10_ExpansionLot")
 slab(lot,Vector3(105,0.04,65),Vector3(36,0.08,64),Color("d4c99e"))
 for z in [40.0,52.0,64.0,76.0,88.0]: add_piece(lot,"planter",Vector3(89,0,z))
 var street := zone("StreetFurniture")
 for x in [-115.0,-65.0,-15.0,15.0,65.0,115.0]:
  for z in [-10.0,10.0]:
   if x == -65.0 and z == -10.0:
    add_piece(street,"tree",Vector3(-78,0,z),Color("86ae7c"))
    _add_street_lamp(street, Vector3(-74,0,z))
    continue
   add_piece(street,"tree",Vector3(x,0,z),Color("86ae7c"))
   _add_street_lamp(street, Vector3(x+4,0,z))
 for p in [Vector3(-70,0,-10),Vector3(10,0,10),Vector3(70,0,-10),Vector3(35,0,28)]: add_piece(street,"trash_bin",p)
 for p in [Vector3(-20,0,-15),Vector3(20,0,-15),Vector3(70,0,-15),Vector3(-70,0,15),Vector3(70,0,15)]:
  add_piece(street,"utility_pole",p)
 var routes := zone("NPCWalkingRoutes")
 # Named guide paths follow sidewalk centres, crossing the roads at intersections.
 # Their shared coordinates are connection points for a future route graph.
 var route_specs := [
  ["BoulevardNorth",Vector3(-120,0,-8),Vector3(120,0,-8)],
  ["BoulevardSouth",Vector3(-120,0,8),Vector3(120,0,8)],
  ["WestSidewalk",Vector3(-74,0,-120),Vector3(-74,0,120)],
  ["CentreSidewalk",Vector3(6,0,-120),Vector3(6,0,120)],
  ["EastInnerSidewalk",Vector3(74,0,-120),Vector3(74,0,120)],
  ["EastOuterSidewalk",Vector3(86,0,-120),Vector3(86,0,120)],
  ["NorthLocalSidewalk",Vector3(-120,0,-58),Vector3(120,0,-58)],
  ["SouthLocalNorth",Vector3(-74,0,46),Vector3(6,0,46)],
  ["SouthLocalSouth",Vector3(-74,0,54),Vector3(6,0,54)],
  ["ResidentialAlley",Vector3(-74,0,-84),Vector3(74,0,-84)],
  ["ParkPromenade",Vector3(42,0,8),Vector3(42,0,78)]
 ]
 for spec in route_specs:
  var path := Path3D.new()
  path.name = spec[0]
  path.curve = Curve3D.new()
  var start: Vector3 = spec[1]
  var end: Vector3 = spec[2]
  var delta: Vector3 = end-start
  var points: Array[Vector3] = [start,end]
  # Split axis-aligned guides at every crossing so shared coordinates are
  # explicit curve points instead of merely intersecting line interiors.
  for other in route_specs:
   var a: Vector3 = other[1]
   var b: Vector3 = other[2]
   var other_delta: Vector3 = b-a
   var hit := Vector3.ZERO
   if absf(delta.x) > 0.01 and absf(other_delta.z) > 0.01:
    hit = Vector3(a.x,0,start.z)
   elif absf(delta.z) > 0.01 and absf(other_delta.x) > 0.01:
    hit = Vector3(start.x,0,a.z)
   else: continue
   if hit.x < minf(start.x,end.x)-0.01 or hit.x > maxf(start.x,end.x)+0.01: continue
   if hit.z < minf(start.z,end.z)-0.01 or hit.z > maxf(start.z,end.z)+0.01: continue
   if hit.x < minf(a.x,b.x)-0.01 or hit.x > maxf(a.x,b.x)+0.01: continue
   if hit.z < minf(a.z,b.z)-0.01 or hit.z > maxf(a.z,b.z)+0.01: continue
   if not points.has(hit): points.append(hit)
  points.sort_custom(func(a: Vector3,b: Vector3) -> bool: return (a-start).dot(delta) < (b-start).dot(delta))
  for point in points: path.curve.add_point(point)
  routes.add_child(path)
 var spawns := zone("NPCSpawnPoints")
 for spec in [["StarterHouse",Vector3(-45,0,70)],["Garage",Vector3(-63,0,-10)],["Noodle",Vector3(-50,0,-12)],["Market",Vector3(37,0,-14)],["FoodStreet",Vector3(-100,0,12)],["Furniture",Vector3(105,0,-12)],["Park",Vector3(42,0,26)],["School",Vector3(105,0,-50)],["Residential",Vector3(10,0,-58)],["Expansion",Vector3(105,0,30)]]:
  var marker := Marker3D.new()
  marker.name = spec[0]
  marker.position = spec[1]
  spawns.add_child(marker)
 if not integrated:
  player = preload("res://scenes/player.tscn").instantiate()
  player.position = Vector3(-45,0.2,70)
  add_child(player)
 var light := DirectionalLight3D.new()
 light.rotation_degrees = Vector3(-55,-35,0)
 light.light_energy = 0.55
 light.shadow_enabled = true
 add_child(light)
 var env := WorldEnvironment.new()
 var e := Environment.new()
 e.background_mode = Environment.BG_COLOR
 e.background_color = Color("d6e8dc")
 e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 e.ambient_light_color = Color("fff1db")
 e.ambient_light_energy = 0.3
 env.environment = e
 add_child(env)
 nav_region = NavigationRegion3D.new()
 nav_region.name = "NavigationRegion3D"
 if ResourceLoader.exists("res://assets/neighborhood/neighborhood_navmesh.tres"):
  nav_region.navigation_mesh = load("res://assets/neighborhood/neighborhood_navmesh.tres")
 add_child(nav_region)
 time_manager = NeighborhoodTimeManager.new()
 time_manager.name = "TimeManager"
 time_manager.directional_light = light
 time_manager.world_environment = env
 add_child(time_manager)
 time_manager.period_changed.connect(_on_street_light_period_changed)
 _on_street_light_period_changed(time_manager.current_period)
 npc_manager = NPCManager.new()
 npc_manager.name = "NPCManager"
 npc_manager.time_manager = time_manager
 add_child(npc_manager)
 var garage_business := GarageBusiness.new()
 garage_business.name = "GarageBusiness"
 garage_business.position.x = 42.0
 add_child(garage_business)
 var hutieu_business := HuTieuBusiness.new()
 hutieu_business.name = "HuTieuBusiness"
 add_child(hutieu_business)
 economy_manager = EconomyManager.new()
 economy_manager.name = "EconomyManager"
 economy_manager.save_file_path = economy_save_path
 economy_manager.garage_business = garage_business
 economy_manager.hutieu_business = hutieu_business
 add_child(economy_manager)
 daily_loop_manager = DailyLoopManager.new()
 daily_loop_manager.name = "DailyLoopManager"
 daily_loop_manager.time_manager = time_manager
 daily_loop_manager.economy_manager = economy_manager
 daily_loop_manager.garage_business = garage_business
 daily_loop_manager.hutieu_business = hutieu_business
 add_child(daily_loop_manager)
 var objective_manager := DailyObjectiveManager.new()
 objective_manager.name = "DailyObjectiveManager"
 add_child(objective_manager)
 var furn_kiosk := ShopKiosk.new()
 furn_kiosk.name = "Kiosk_Furniture"
 furn_kiosk.kiosk_title = "Tiệm Nội Thất"
 furn_kiosk.product_category = "furniture"
 furn_kiosk.position = Vector3(105, 0, -18)
 add_child(furn_kiosk)
 var pet_kiosk := ShopKiosk.new()
 pet_kiosk.name = "Kiosk_PetShop"
 pet_kiosk.kiosk_title = "Tiệm Thú Cưng Miu Miu"
 pet_kiosk.product_category = "pet"
 pet_kiosk.position = Vector3(88, 0, -18)
 add_child(pet_kiosk)
 var market_kiosk := ShopKiosk.new()
 market_kiosk.name = "Kiosk_Market"
 market_kiosk.kiosk_title = "Chợ & Tạp Hóa"
 market_kiosk.product_category = "food_ingredient"
 market_kiosk.position = Vector3(-105, 0, 32)
 add_child(market_kiosk)
 var tool_kiosk := ShopKiosk.new()
 tool_kiosk.name = "Kiosk_Tools"
 tool_kiosk.kiosk_title = "Cửa Hàng Dụng Cụ Sửa Xe"
 tool_kiosk.product_category = "repair_tool"
 tool_kiosk.position = Vector3(-56, 0, -14)
 add_child(tool_kiosk)
 var house_kiosk := ShopKiosk.new()
 house_kiosk.name = "Kiosk_House"
 house_kiosk.kiosk_title = "Nâng Cấp Nhà Cửa"
 house_kiosk.product_category = "house_upgrade"
 house_kiosk.position = Vector3(-47, 0, 84)
 add_child(house_kiosk)
 var garage_upg_kiosk := ShopKiosk.new()
 garage_upg_kiosk.name = "Kiosk_GarageUpgrades"
 garage_upg_kiosk.kiosk_title = "Nâng Cấp Tiệm Sửa Xe"
 garage_upg_kiosk.product_category = "business_upgrade"
 garage_upg_kiosk.target_system = "garage"
 garage_upg_kiosk.position = Vector3(-65, 0, -18)
 add_child(garage_upg_kiosk)
 var hutieu_upg_kiosk := ShopKiosk.new()
 hutieu_upg_kiosk.name = "Kiosk_HuTieuUpgrades"
 hutieu_upg_kiosk.kiosk_title = "Nâng Cấp Quán Hủ Tiếu"
 hutieu_upg_kiosk.product_category = "business_upgrade"
 hutieu_upg_kiosk.target_system = "hutieu"
 hutieu_upg_kiosk.position = Vector3(-43, 0, -18)
 add_child(hutieu_upg_kiosk)
 coop_obstacle = CoopHeavyObstacle.new()
 coop_obstacle.name = "CoopHeavyObstacle"
 coop_obstacle.position = Vector3(15, 0, -54)
 add_child(coop_obstacle)
 coop_bench = CoopAssemblyBench.new()
 coop_bench.name = "CoopAssemblyBench"
 coop_bench.position = Vector3(95, 0, -18)
 add_child(coop_bench)
 # Dedicated parking bays with painted lines and 3D signposts
 _create_parking_bay(self, Vector3(-48.0, 0, 72.0), PI, "Bãi Đậu Xe Boy", Color("80cbc4"))
 _create_parking_bay(self, Vector3(-42.0, 0, 72.0), PI, "Bãi Đậu Xe Girl", Color("ffab91"))
 _create_parking_bay(self, Vector3(-58.0, 0, -13.0), PI / 2.0, "Bãi Đậu Xe Boy\n(Tiệm Sửa Xe)", Color("80cbc4"))
 _create_parking_bay(self, Vector3(-44.0, 0, -15.0), 0.0, "Bãi Đậu Xe Girl\n(Quán Hủ Tiếu)", Color("ffab91"))
 # Personal commuter scooters for Boy and Girl
 boy_scooter = PlayerScooter.new()
 boy_scooter.name = "BoyScooter"
 boy_scooter.owner_character = "boy"
 boy_scooter.scooter_color = Color("00897b")
 boy_scooter.destination_name = "Tiệm Sửa Xe Máy"
 boy_scooter.home_parking_pos = Vector3(-48.0, 0, 72.0)
 boy_scooter.work_parking_pos = Vector3(-58.0, 0, -13.0)
 boy_scooter.position = Vector3(-48.0, 0, 72.0)
 boy_scooter.rotation.y = PI
 add_child(boy_scooter)
 girl_scooter = PlayerScooter.new()
 girl_scooter.name = "GirlScooter"
 girl_scooter.owner_character = "girl"
 girl_scooter.scooter_color = Color("ff7043")
 girl_scooter.destination_name = "Quán Hủ Tiếu Cô Bảy"
 girl_scooter.home_parking_pos = Vector3(-42.0, 0, 72.0)
 girl_scooter.work_parking_pos = Vector3(-44.0, 0, -15.0)
 girl_scooter.position = Vector3(-42.0, 0, 72.0)
 girl_scooter.rotation.y = PI
 add_child(girl_scooter)
 if integrated:
  add_help()
  return
 camera = Camera3D.new()
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 20
 camera.position = player.position + Vector3(0,25,22)
 add_child(camera)
 camera.look_at(player.position)
 camera.current = true
 guidance = WorkplaceGuidance.new()
 guidance.name = "WorkplaceGuidance"
 guidance.player = player
 guidance.camera = camera
 add_child(guidance)
 var minimap = preload("res://scripts/ui/interactive_minimap.gd").new()
 minimap.name = "InteractiveMinimap"
 minimap.player = player
 minimap.guidance = guidance
 add_child(minimap)
 add_help()

func _unhandled_key_input(event: InputEvent) -> void:
 if integrated or not (event is InputEventKey and event.pressed and not event.echo): return
 if event.keycode == KEY_ESCAPE:
  if is_instance_valid(economy_manager) and economy_manager.auto_save_on_change:
   economy_manager.save_economy_state()
  get_tree().paused = false
  get_tree().change_scene_to_file("res://scenes/main.tscn")
  get_viewport().set_input_as_handled()
 elif event.keycode == KEY_TAB:
  overview = not overview
  camera.size = 330 if overview else 20

func _process(_delta: float) -> void:
 if not overview and is_instance_valid(player) and is_instance_valid(camera):
  camera.position = player.position + Vector3(0,25,22)
  camera.look_at(player.position)
 elif overview and is_instance_valid(camera):
  camera.position = Vector3(185,230,185)
  camera.look_at(Vector3.ZERO)
 if is_instance_valid(clock_label) and is_instance_valid(time_manager):
  clock_label.text = "🕒 " + time_manager.get_time_formatted()
 if is_instance_valid(wallet_label) and is_instance_valid(economy_manager):
  wallet_label.text = "💰 Ví Gia Đình: " + HouseholdWallet.format_money(economy_manager.wallet.balance)
 if is_instance_valid(goal_label) and is_instance_valid(economy_manager):
  var goal := economy_manager.get_goal_info()
  if goal.get("is_ready_to_buy", false):
   goal_label.text = "🎯 Mục tiêu: %s [%s] — %s" % [goal["title"], HouseholdWallet.format_money(goal.get("next_upgrade_cost", 0)), goal["hint"]]
   goal_label.modulate = Color("b9f6ca")
  elif goal.get("id") == "goal_mastery":
   goal_label.text = "🌟 %s: %s" % [goal["title"], goal["hint"]]
   goal_label.modulate = Color("ffd54f")
  else:
   goal_label.text = "🎯 Mục tiêu: %s — %s (%s / %s)" % [
    goal["title"],
    goal["description"],
    HouseholdWallet.format_money(goal["current"]),
    HouseholdWallet.format_money(goal["target"])
   ]
   goal_label.modulate = Color("fff59d")

func add_help() -> void:
 var layer := CanvasLayer.new()
 layer.name = "NeighborhoodHelp"
 add_child(layer)
 var panel := PanelContainer.new()
 panel.position = Vector2(16,16)
 layer.add_child(panel)
 var box := VBoxContainer.new()
 panel.add_child(box)
 clock_label = Label.new()
 clock_label.text = "🕒 08:00 (sáng)"
 box.add_child(clock_label)
 wallet_label = Label.new()
 wallet_label.text = "💰 Ví Gia Đình: 100,000 đ"
 wallet_label.modulate = Color("a7ffeb")
 box.add_child(wallet_label)
 goal_label = Label.new()
 goal_label.text = "🎯 Mục tiêu: Đang tải..."
 goal_label.modulate = Color("fff59d")
 box.add_child(goal_label)
 var text := Label.new()
 text.text = "WASD: di chuyển · Shift: chạy · Space: lướt\nE: tương tác · F: ném · Esc: menu"
 box.add_child(text)

func enable_neighborhood_coop() -> void:
 if is_coop: return
 is_coop = true
 player_2 = preload("res://scenes/player.tscn").instantiate()
 player_2.name = "Player2"
 player_2.player_id = 2
 player_2.position = player.position + Vector3(2.0, 0, 0)
 add_child(player_2)
 player_2.select_character("girl")
 
 if is_instance_valid(camera):
  camera.current = false
  camera.visible = false
 
 coop_manager = CoopManager.new()
 coop_manager.name = "CoopManager"
 add_child(coop_manager)
 coop_manager.initialize_coop(player, player_2, self, get_viewport().world_3d, false)

func _input(event: InputEvent) -> void:
 if not integrated and event is InputEventKey and event.pressed and not event.echo:
  if event.keycode == KEY_F2:
   enable_neighborhood_coop()
  elif event.keycode == KEY_F11:
   var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
   DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
