class_name FurnitureData
extends RefCounted

## Metadata and factory for all placeable furniture items.

const CREAM = Color("efd0bf")
const WOOD = Color("c98256")
const DARK = Color("9b6040")
const WHITE = Color("fff0df")
const GREEN = Color("879447")
const SAGE = Color("8b9e59")
const RED_BRICK = Color("b4533c")

static func get_definition(id: String) -> Dictionary:
	var defs := get_all_definitions()
	if defs.has(id):
		return defs[id]
	# Fallback default
	return {
		"id": id,
		"name": "Nội thất",
		"category": "decoration",
		"footprint": Vector3(1.0, 0.8, 1.0),
		"interact_kind": "",
		"stand_offset": Vector3(0, 0, 0.8),
		"seat_offset": Vector3(0, 0.4, 0),
		"solid": true
	}

static func get_all_definitions() -> Dictionary:
	return {
		"furn_sleeping_mat": {
			"id": "furn_sleeping_mat",
			"name": "Chiếu ngủ truyền thống",
			"category": "bed",
			"footprint": Vector3(1.6, 0.2, 2.2),
			"interact_kind": "bed",
			"stand_offset": Vector3(0.9, 0, 0),
			"seat_offset": Vector3(0, 0.15, 0),
			"solid": false
		},
		"furn_wooden_bed": {
			"id": "furn_wooden_bed",
			"name": "Giường đôi gỗ sồi",
			"category": "bed",
			"footprint": Vector3(1.8, 0.8, 2.2),
			"interact_kind": "bed",
			"stand_offset": Vector3(1.0, 0, 0),
			"seat_offset": Vector3(0, 0.45, 0),
			"solid": true
		},
		"furn_deluxe_sofa": {
			"id": "furn_deluxe_sofa",
			"name": "Sofa nệm xanh vintage",
			"category": "sofa",
			"footprint": Vector3(2.2, 0.9, 0.9),
			"interact_kind": "sofa",
			"stand_offset": Vector3(0, 0, 0.75),
			"seat_offset": Vector3(0, 0.45, 0),
			"solid": true
		},
		"furn_basic_sofa": {
			"id": "furn_basic_sofa",
			"name": "Ghế sofa nhỏ gọn",
			"category": "sofa",
			"footprint": Vector3(1.5, 0.75, 0.8),
			"interact_kind": "sofa",
			"stand_offset": Vector3(0, 0, 0.65),
			"seat_offset": Vector3(0, 0.4, 0),
			"solid": true
		},
		"furn_oak_table": {
			"id": "furn_oak_table",
			"name": "Bàn ăn tròn gia đình",
			"category": "table",
			"footprint": Vector3(1.4, 0.8, 1.4),
			"interact_kind": "",
			"stand_offset": Vector3.ZERO,
			"seat_offset": Vector3.ZERO,
			"solid": true
		},
		"furn_chair": {
			"id": "furn_chair",
			"name": "Ghế tựa đệm êm",
			"category": "chair",
			"footprint": Vector3(0.65, 0.85, 0.65),
			"interact_kind": "chair",
			"stand_offset": Vector3(0, 0, 0.55),
			"seat_offset": Vector3(0, 0.45, 0),
			"solid": true
		},
		"furn_coffee_table": {
			"id": "furn_coffee_table",
			"name": "Bàn trà phòng khách",
			"category": "table",
			"footprint": Vector3(1.3, 0.5, 0.7),
			"interact_kind": "",
			"stand_offset": Vector3.ZERO,
			"seat_offset": Vector3.ZERO,
			"solid": true
		},
		"furn_wardrobe": {
			"id": "furn_wardrobe",
			"name": "Tủ quần áo gỗ 2 cánh",
			"category": "storage",
			"footprint": Vector3(1.2, 1.9, 0.8),
			"interact_kind": "",
			"stand_offset": Vector3.ZERO,
			"seat_offset": Vector3.ZERO,
			"solid": true
		},
		"furn_smart_tv": {
			"id": "furn_smart_tv",
			"name": "Tivi LED 55 inch & kệ",
			"category": "electronics",
			"footprint": Vector3(1.8, 1.2, 0.7),
			"interact_kind": "",
			"stand_offset": Vector3.ZERO,
			"seat_offset": Vector3.ZERO,
			"solid": true
		},
		"furn_inverter_fridge": {
			"id": "furn_inverter_fridge",
			"name": "Tủ lạnh Inverter 2 cánh",
			"category": "appliance",
			"footprint": Vector3(0.9, 1.85, 0.85),
			"interact_kind": "",
			"stand_offset": Vector3.ZERO,
			"seat_offset": Vector3.ZERO,
			"solid": true
		},
		"furn_floor_lamp": {
			"id": "furn_floor_lamp",
			"name": "Đèn cây phòng khách",
			"category": "lamp",
			"footprint": Vector3(0.5, 1.6, 0.5),
			"interact_kind": "lamp",
			"stand_offset": Vector3(0, 0, 0.6),
			"seat_offset": Vector3.ZERO,
			"solid": true
		},
		"furn_bookshelf": {
			"id": "furn_bookshelf",
			"name": "Kệ sách đứng hiện đại",
			"category": "storage",
			"footprint": Vector3(1.2, 1.7, 0.7),
			"interact_kind": "",
			"stand_offset": Vector3.ZERO,
			"seat_offset": Vector3.ZERO,
			"solid": true
		},
		"furn_potted_plant": {
			"id": "furn_potted_plant",
			"name": "Chậu cây cảnh phong thủy",
			"category": "decoration",
			"footprint": Vector3(0.6, 0.8, 0.6),
			"interact_kind": "",
			"stand_offset": Vector3.ZERO,
			"seat_offset": Vector3.ZERO,
			"solid": true
		}
	}

static func create_visual_model(id: String) -> Node3D:
	var root := Node3D.new()
	var def := get_definition(id)
	
	match id:
		"furn_sleeping_mat":
			# Stylized Vietnamese woven bamboo/straw sleeping mat
			var mat_mesh := MeshInstance3D.new()
			var mat_geom := BoxMesh.new()
			mat_geom.size = Vector3(1.5, 0.04, 2.1)
			mat_mesh.mesh = mat_geom
			var mat_mat := StandardMaterial3D.new()
			mat_mat.albedo_color = Color("dfcf9c") # Straw yellow
			mat_mat.roughness = 0.95
			mat_mesh.material_override = mat_mat
			mat_mesh.position = Vector3(0, 0.02, 0)
			root.add_child(mat_mesh)
			
			# Red fabric border
			var border := MeshInstance3D.new()
			var border_geom := BoxMesh.new()
			border_geom.size = Vector3(1.54, 0.045, 0.12)
			border.mesh = border_geom
			var b_mat := StandardMaterial3D.new()
			b_mat.albedo_color = Color("a83232")
			border.material_override = b_mat
			border.position = Vector3(0, 0.025, -0.98)
			root.add_child(border)
			
			# Traditional bolster pillow
			var pillow := MeshInstance3D.new()
			var pillow_geom := CylinderMesh.new()
			pillow_geom.top_radius = 0.12
			pillow_geom.bottom_radius = 0.12
			pillow_geom.height = 0.7
			pillow_geom.radial_segments = 16
			pillow.mesh = pillow_geom
			pillow.rotation.z = PI / 2.0
			pillow.position = Vector3(0, 0.12, -0.75)
			var p_mat := StandardMaterial3D.new()
			p_mat.albedo_color = Color("f3eae0")
			pillow.material_override = p_mat
			root.add_child(pillow)
			
		"furn_wooden_bed":
			var bed_inst: Node3D = null
			if ResourceLoader.exists("res://scenes/neighborhood/bed.tscn"):
				bed_inst = load("res://scenes/neighborhood/bed.tscn").instantiate()
			if not bed_inst:
				var m := MeshInstance3D.new()
				var b := BoxMesh.new()
				b.size = def["footprint"]
				m.mesh = b
				root.add_child(m)
			else:
				bed_inst.scale = Vector3(0.85, 1.0, 0.95)
				root.add_child(bed_inst)
				
		"furn_deluxe_sofa":
			var sofa_inst: Node3D = null
			if ResourceLoader.exists("res://scenes/neighborhood/sofa.tscn"):
				sofa_inst = load("res://scenes/neighborhood/sofa.tscn").instantiate()
			if not sofa_inst:
				var m := MeshInstance3D.new()
				var b := BoxMesh.new()
				b.size = def["footprint"]
				m.mesh = b
				root.add_child(m)
			else:
				sofa_inst.scale = Vector3(1.1, 1.0, 1.0)
				root.add_child(sofa_inst)
				
		"furn_basic_sofa":
			var sofa_base := MeshInstance3D.new()
			var s_geom := BoxMesh.new()
			s_geom.size = Vector3(1.4, 0.45, 0.75)
			sofa_base.mesh = s_geom
			var s_mat := StandardMaterial3D.new()
			s_mat.albedo_color = Color("769062")
			sofa_base.material_override = s_mat
			sofa_base.position = Vector3(0, 0.225, 0)
			root.add_child(sofa_base)
			
			var back := MeshInstance3D.new()
			var back_geom := BoxMesh.new()
			back_geom.size = Vector3(1.4, 0.45, 0.2)
			back.mesh = back_geom
			back.material_override = s_mat
			back.position = Vector3(0, 0.55, -0.28)
			root.add_child(back)
			
		"furn_oak_table":
			var table_inst: Node3D = null
			if ResourceLoader.exists("res://scenes/neighborhood/table.tscn"):
				table_inst = load("res://scenes/neighborhood/table.tscn").instantiate()
			if not table_inst:
				var m := MeshInstance3D.new()
				var b := BoxMesh.new()
				b.size = def["footprint"]
				m.mesh = b
				root.add_child(m)
			else:
				root.add_child(table_inst)
				
		"furn_chair":
			var chair_inst: Node3D = null
			if ResourceLoader.exists("res://scenes/neighborhood/chair.tscn"):
				chair_inst = load("res://scenes/neighborhood/chair.tscn").instantiate()
			if not chair_inst:
				var m := MeshInstance3D.new()
				var b := BoxMesh.new()
				b.size = def["footprint"]
				m.mesh = b
				root.add_child(m)
			else:
				chair_inst.scale = Vector3(0.9, 0.9, 0.9)
				root.add_child(chair_inst)
				
		"furn_coffee_table":
			var ct_inst: Node3D = null
			if ResourceLoader.exists("res://scenes/neighborhood/coffee_table.tscn"):
				ct_inst = load("res://scenes/neighborhood/coffee_table.tscn").instantiate()
			if not ct_inst:
				var m := MeshInstance3D.new()
				var b := BoxMesh.new()
				b.size = def["footprint"]
				m.mesh = b
				root.add_child(m)
			else:
				root.add_child(ct_inst)
				
		"furn_wardrobe":
			var m := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = def["footprint"]
			m.mesh = b
			var w_mat := StandardMaterial3D.new()
			w_mat.albedo_color = Color("9b6040")
			m.material_override = w_mat
			m.position = Vector3(0, def["footprint"].y * 0.5, 0)
			root.add_child(m)
			
			# Brass handles
			for x in [-0.15, 0.15]:
				var h := MeshInstance3D.new()
				var hb := SphereMesh.new()
				hb.radius = 0.04
				hb.height = 0.08
				h.mesh = hb
				var hm := StandardMaterial3D.new()
				hm.albedo_color = Color("ffd700")
				h.material_override = hm
				h.position = Vector3(x, 0.95, 0.42)
				root.add_child(h)
				
		"furn_smart_tv":
			var tv_inst: Node3D = null
			if ResourceLoader.exists("res://scenes/neighborhood/television.tscn"):
				tv_inst = load("res://scenes/neighborhood/television.tscn").instantiate()
			if not tv_inst:
				var m := MeshInstance3D.new()
				var b := BoxMesh.new()
				b.size = def["footprint"]
				m.mesh = b
				root.add_child(m)
			else:
				root.add_child(tv_inst)
				
		"furn_inverter_fridge":
			var fr_inst: Node3D = null
			if ResourceLoader.exists("res://scenes/neighborhood/refrigerator.tscn"):
				fr_inst = load("res://scenes/neighborhood/refrigerator.tscn").instantiate()
			if not fr_inst:
				var m := MeshInstance3D.new()
				var b := BoxMesh.new()
				b.size = def["footprint"]
				m.mesh = b
				root.add_child(m)
			else:
				root.add_child(fr_inst)
				
		"furn_floor_lamp":
			var lamp_inst: Node3D = null
			if ResourceLoader.exists("res://scenes/neighborhood/lamp.tscn"):
				lamp_inst = load("res://scenes/neighborhood/lamp.tscn").instantiate()
			if not lamp_inst:
				var m := MeshInstance3D.new()
				var b := BoxMesh.new()
				b.size = def["footprint"]
				m.mesh = b
				root.add_child(m)
			else:
				root.add_child(lamp_inst)
				
		"furn_bookshelf":
			var m := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = def["footprint"]
			m.mesh = b
			var bm := StandardMaterial3D.new()
			bm.albedo_color = Color("c98256")
			m.material_override = bm
			m.position = Vector3(0, def["footprint"].y * 0.5, 0)
			root.add_child(m)
			
		"furn_potted_plant":
			var plant_inst: Node3D = null
			if ResourceLoader.exists("res://scenes/neighborhood/flower_bed.tscn"):
				plant_inst = load("res://scenes/neighborhood/flower_bed.tscn").instantiate()
			if not plant_inst:
				var m := MeshInstance3D.new()
				var b := CylinderMesh.new()
				b.top_radius = 0.3
				b.bottom_radius = 0.2
				b.height = 0.6
				m.mesh = b
				root.add_child(m)
			else:
				plant_inst.scale = Vector3(0.5, 0.5, 0.5)
				root.add_child(plant_inst)
				
		_:
			var m := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = def["footprint"]
			m.mesh = b
			m.position = Vector3(0, def["footprint"].y * 0.5, 0)
			root.add_child(m)
			
	return root

static func create_placed_instance(id: String, pos: Vector3, rot_y: float) -> Node3D:
	var def := get_definition(id)
	var container := Node3D.new()
	container.name = "Placed_" + id + "_" + str(Time.get_ticks_msec())
	container.position = pos
	container.rotation.y = rot_y
	container.set_meta("furniture_id", id)
	container.set_meta("is_placed_furniture", true)
	
	# Visual model
	var visual := create_visual_model(id)
	container.add_child(visual)
	
	# Collision body
	if def.get("solid", true):
		var body := StaticBody3D.new()
		body.name = "Collider"
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var fp: Vector3 = def["footprint"]
		box.size = fp
		shape.shape = box
		shape.position = Vector3(0, fp.y * 0.5, 0)
		body.add_child(shape)
		container.add_child(body)
	
	# Interactable component
	var interact_kind: String = def.get("interact_kind", "")
	if interact_kind != "":
		var item := Interactable.new()
		item.name = "Interactable"
		item.kind = interact_kind
		item.display_name = def["name"]
		item.furniture_id = id
		item.is_furniture = true
		
		# Stand and seat offsets are relative to the furniture container.
		var stand_local: Vector3 = def.get("stand_offset", Vector3(0, 0, 0.8))
		var seat_local: Vector3 = def.get("seat_offset", Vector3(0, 0.4, 0))
		item.stand_point = stand_local
		item.seat_point = seat_local
		
		if interact_kind == "lamp":
			item.toggle = true
			var lamp_light := OmniLight3D.new()
			lamp_light.position = Vector3(0, def["footprint"].y, 0)
			lamp_light.light_color = Color("fff0dd")
			lamp_light.light_energy = 0.8
			lamp_light.omni_range = 4.0
			item.light = lamp_light
			item.add_child(lamp_light)
			
		container.add_child(item)
	
	return container
