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
		"furn_bath_sink": {
			"id": "furn_bath_sink", "name": "Chậu rửa phòng tắm", "category": "decoration",
			"footprint": Vector3(0.72, 1.12, 0.5), "interact_kind": "",
			"stand_offset": Vector3(0, 0, 0.8), "seat_offset": Vector3.ZERO, "solid": true
		},
		"furn_bath_mirror": {
			"id": "furn_bath_mirror", "name": "Gương phòng tắm", "category": "decoration",
			"footprint": Vector3(0.72, 1.55, 0.12), "interact_kind": "",
			"stand_offset": Vector3(0, 0, 0.8), "seat_offset": Vector3.ZERO, "solid": true
		},
		"furn_shower": {
			"id": "furn_shower", "name": "Vòi sen", "category": "decoration",
			"footprint": Vector3(0.8, 2.1, 0.8), "interact_kind": "",
			"stand_offset": Vector3(0, 0, 0.8), "seat_offset": Vector3.ZERO, "solid": true
		},
		"furn_toilet": {
			"id": "furn_toilet", "name": "Bồn cầu", "category": "decoration",
			"footprint": Vector3(0.55, 0.95, 0.65), "interact_kind": "",
			"stand_offset": Vector3(0, 0, 0.8), "seat_offset": Vector3.ZERO, "solid": true
		},
		"furn_towel_rack": {
			"id": "furn_towel_rack", "name": "Giá treo khăn", "category": "decoration",
			"footprint": Vector3(0.65, 1.4, 0.2), "interact_kind": "",
			"stand_offset": Vector3(0, 0, 0.8), "seat_offset": Vector3.ZERO, "solid": true
		},
		"furn_washing_machine": {
			"id": "furn_washing_machine", "name": "Máy giặt", "category": "decoration",
			"footprint": Vector3(0.7, 1.0, 0.7), "interact_kind": "",
			"stand_offset": Vector3(0, 0, 0.8), "seat_offset": Vector3.ZERO, "solid": true
		},
		"furn_laundry_basket": {
			"id": "furn_laundry_basket", "name": "Giỏ đồ giặt", "category": "decoration",
			"footprint": Vector3(0.6, 0.55, 0.6), "interact_kind": "",
			"stand_offset": Vector3(0, 0, 0.8), "seat_offset": Vector3.ZERO, "solid": true
		},
		"furn_clothes_hanger": {
			"id": "furn_clothes_hanger", "name": "Giá treo quần áo", "category": "decoration",
			"footprint": Vector3(0.8, 1.75, 0.45), "interact_kind": "",
			"stand_offset": Vector3(0, 0, 0.8), "seat_offset": Vector3.ZERO, "solid": true
		},
		"furn_broom": {
			"id": "furn_broom", "name": "Chổi quét nhà", "category": "decoration",
			"footprint": Vector3(0.4, 1.5, 0.25), "interact_kind": "",
			"stand_offset": Vector3(0, 0, 0.8), "seat_offset": Vector3.ZERO, "solid": true
		},
		"furn_mop": {
			"id": "furn_mop", "name": "Cây lau nhà", "category": "decoration",
			"footprint": Vector3(0.4, 1.5, 0.25), "interact_kind": "",
			"stand_offset": Vector3(0, 0, 0.8), "seat_offset": Vector3.ZERO, "solid": true
		},
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
			"interact_kind": "wardrobe",
			"stand_offset": Vector3(0, 0, 0.85),
			"seat_offset": Vector3.ZERO,
			"solid": true
		},
		"furn_smart_tv": {
			"id": "furn_smart_tv",
			"name": "Tivi LED 55 inch & kệ",
			"category": "electronics",
			"footprint": Vector3(1.8, 1.2, 0.7),
			"interact_kind": "tv",
			"stand_offset": Vector3(0, 0, 1.05),
			"seat_offset": Vector3.ZERO,
			"solid": true
		},
		"furn_inverter_fridge": {
			"id": "furn_inverter_fridge",
			"name": "Tủ lạnh Inverter 2 cánh",
			"category": "appliance",
			"footprint": Vector3(0.9, 1.85, 0.85),
			"interact_kind": "fridge",
			"stand_offset": Vector3(0, 0, 0.85),
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
			"interact_kind": "bookshelf",
			"stand_offset": Vector3(0, 0, 0.75),
			"seat_offset": Vector3.ZERO,
			"solid": true
		},
		"furn_potted_plant": {
			"id": "furn_potted_plant",
			"name": "Chậu cây cảnh phong thủy",
			"category": "decoration",
			"footprint": Vector3(0.6, 0.8, 0.6),
			"interact_kind": "plant",
			"stand_offset": Vector3(0, 0, 0.65),
			"seat_offset": Vector3.ZERO,
			"solid": true
		},
		"furn_kitchen_counter": {
			"id": "furn_kitchen_counter",
			"name": "Quầy bếp nấu ăn gia đình",
			"category": "appliance",
			"footprint": Vector3(1.6, 0.9, 0.8),
			"interact_kind": "kitchen_counter",
			"stand_offset": Vector3(0, 0, 0.75),
			"seat_offset": Vector3.ZERO,
			"solid": true
		},
		"furn_pet_food_bowl": {
			"id": "furn_pet_food_bowl",
			"name": "Bát ăn gốm sứ cho mèo",
			"category": "pet",
			"footprint": Vector3(0.3, 0.1, 0.3),
			"interact_kind": "",
			"stand_offset": Vector3(0, 0, 0.3),
			"seat_offset": Vector3.ZERO,
			"solid": false
		},
		"furn_pet_water_bowl": {
			"id": "furn_pet_water_bowl",
			"name": "Bát nước mát gốm sứ",
			"category": "pet",
			"footprint": Vector3(0.3, 0.1, 0.3),
			"interact_kind": "",
			"stand_offset": Vector3(0, 0, 0.3),
			"seat_offset": Vector3.ZERO,
			"solid": false
		},
		"furn_pet_bed": {
			"id": "furn_pet_bed",
			"name": "Nệm ngủ thú cưng êm ái",
			"category": "pet",
			"footprint": Vector3(0.6, 0.2, 0.6),
			"interact_kind": "",
			"stand_offset": Vector3(0, 0, 0.4),
			"seat_offset": Vector3.ZERO,
			"solid": false
		},
		"furn_pet_scratching_post": {
			"id": "furn_pet_scratching_post",
			"name": "Trụ cào móng dây thừng",
			"category": "pet",
			"footprint": Vector3(0.5, 0.65, 0.5),
			"interact_kind": "",
			"stand_offset": Vector3(0, 0, 0.4),
			"seat_offset": Vector3.ZERO,
			"solid": false
		},
		"furn_pet_toy_wand": {
			"id": "furn_pet_toy_wand",
			"name": "Cần câu lông vũ đùa mèo",
			"category": "pet",
			"footprint": Vector3(0.4, 0.4, 0.2),
			"interact_kind": "",
			"stand_offset": Vector3(0, 0, 0.3),
			"seat_offset": Vector3.ZERO,
			"solid": false
		},
		"furn_pet_toy_ball": {
			"id": "furn_pet_toy_ball",
			"name": "Quả bóng len lục lạc",
			"category": "pet",
			"footprint": Vector3(0.2, 0.2, 0.2),
			"interact_kind": "",
			"stand_offset": Vector3(0, 0, 0.2),
			"seat_offset": Vector3.ZERO,
			"solid": false
		}
	}

static func create_visual_model(id: String) -> Node3D:
	var root := Node3D.new()
	var def := get_definition(id)
	
	match id:
		"furn_bath_sink", "furn_bath_mirror", "furn_shower", "furn_toilet", "furn_towel_rack", "furn_washing_machine", "furn_laundry_basket", "furn_clothes_hanger", "furn_broom", "furn_mop":
			var visual := preload("res://scenes/house/utility_furniture_visual.tscn").instantiate() as Node3D
			visual.set("kind", id.trim_prefix("furn_"))
			return visual
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
			# Cabinet Frame
			var frame := MeshInstance3D.new()
			var f_box := BoxMesh.new()
			f_box.size = Vector3(1.2, 1.9, 0.78)
			frame.mesh = f_box
			var w_mat := StandardMaterial3D.new()
			w_mat.albedo_color = Color("8c5432")
			frame.material_override = w_mat
			frame.position = Vector3(0, 0.95, 0)
			root.add_child(frame)

			# Top molding
			var molding := MeshInstance3D.new()
			var m_box := BoxMesh.new()
			m_box.size = Vector3(1.26, 0.08, 0.84)
			molding.mesh = m_box
			var m_mat := StandardMaterial3D.new()
			m_mat.albedo_color = Color("6d4024")
			molding.material_override = m_mat
			molding.position = Vector3(0, 1.92, 0)
			root.add_child(molding)

			# Left Door Hinge
			var hinge_l := Node3D.new()
			hinge_l.name = "DoorLeft"
			hinge_l.position = Vector3(-0.58, 0.95, 0.40)
			root.add_child(hinge_l)
			var door_l := MeshInstance3D.new()
			var dl_box := BoxMesh.new()
			dl_box.size = Vector3(0.57, 1.76, 0.04)
			door_l.mesh = dl_box
			var d_mat := StandardMaterial3D.new()
			d_mat.albedo_color = Color("9c623b")
			door_l.material_override = d_mat
			door_l.position = Vector3(0.285, 0, 0)
			hinge_l.add_child(door_l)

			# Right Door Hinge
			var hinge_r := Node3D.new()
			hinge_r.name = "DoorRight"
			hinge_r.position = Vector3(0.58, 0.95, 0.40)
			root.add_child(hinge_r)
			var door_r := MeshInstance3D.new()
			var dr_box := BoxMesh.new()
			dr_box.size = Vector3(0.57, 1.76, 0.04)
			door_r.mesh = dr_box
			door_r.material_override = d_mat
			door_r.position = Vector3(-0.285, 0, 0)
			hinge_r.add_child(door_r)
			
			# Brass Handles
			var hl := MeshInstance3D.new()
			var hr := MeshInstance3D.new()
			var hb := SphereMesh.new()
			hb.radius = 0.035
			hb.height = 0.07
			hl.mesh = hb
			hr.mesh = hb
			var hm := StandardMaterial3D.new()
			hm.albedo_color = Color("ffd700")
			hl.material_override = hm
			hr.material_override = hm
			hl.position = Vector3(0.51, 0, 0.035)
			hr.position = Vector3(-0.51, 0, 0.035)
			hinge_l.add_child(hl)
			hinge_r.add_child(hr)
				
		"furn_smart_tv":
			# Modern wood TV console
			var console := MeshInstance3D.new()
			var c_box := BoxMesh.new()
			c_box.size = Vector3(1.6, 0.45, 0.5)
			console.mesh = c_box
			var c_mat := StandardMaterial3D.new()
			c_mat.albedo_color = Color("8c5432")
			console.material_override = c_mat
			console.position = Vector3(0, 0.225, 0)
			root.add_child(console)

			# TV stand neck & base
			var stand_base := MeshInstance3D.new()
			var sb_box := BoxMesh.new()
			sb_box.size = Vector3(0.35, 0.04, 0.25)
			stand_base.mesh = sb_box
			stand_base.position = Vector3(0, 0.47, 0)
			root.add_child(stand_base)

			# TV Frame
			var frame := MeshInstance3D.new()
			var f_box := BoxMesh.new()
			f_box.size = Vector3(1.4, 0.82, 0.06)
			frame.mesh = f_box
			var f_mat := StandardMaterial3D.new()
			f_mat.albedo_color = Color("1e1e22")
			frame.material_override = f_mat
			frame.position = Vector3(0, 0.92, 0)
			root.add_child(frame)

			# TV Screen Mesh
			var screen := MeshInstance3D.new()
			screen.name = "TVScreen"
			var s_box := BoxMesh.new()
			s_box.size = Vector3(1.32, 0.74, 0.02)
			screen.mesh = s_box
			var s_mat := StandardMaterial3D.new()
			s_mat.albedo_color = Color("141416")
			screen.material_override = s_mat
			screen.position = Vector3(0, 0.92, 0.035)
			root.add_child(screen)
				
		"furn_inverter_fridge":
			# Main Body Cabinet
			var body_mesh := MeshInstance3D.new()
			var b_box := BoxMesh.new()
			b_box.size = Vector3(0.88, 1.82, 0.8)
			body_mesh.mesh = b_box
			var b_mat := StandardMaterial3D.new()
			b_mat.albedo_color = Color("dce5e0")
			body_mesh.material_override = b_mat
			body_mesh.position = Vector3(0, 0.91, 0)
			root.add_child(body_mesh)

			# Upper Freezer Door
			var freezer := MeshInstance3D.new()
			var fz_box := BoxMesh.new()
			fz_box.size = Vector3(0.86, 0.65, 0.06)
			freezer.mesh = fz_box
			freezer.material_override = b_mat
			freezer.position = Vector3(0, 1.48, 0.42)
			root.add_child(freezer)

			# Lower Fridge Door Hinge
			var hinge := Node3D.new()
			hinge.name = "FridgeDoor"
			hinge.position = Vector3(-0.43, 0.55, 0.41)
			root.add_child(hinge)

			var door_panel := MeshInstance3D.new()
			var dp_box := BoxMesh.new()
			dp_box.size = Vector3(0.86, 1.05, 0.06)
			door_panel.mesh = dp_box
			door_panel.material_override = b_mat
			door_panel.position = Vector3(0.43, 0, 0)
			hinge.add_child(door_panel)

			# Handle
			var handle := MeshInstance3D.new()
			var h_box := BoxMesh.new()
			h_box.size = Vector3(0.04, 0.4, 0.04)
			handle.mesh = h_box
			var h_mat := StandardMaterial3D.new()
			h_mat.albedo_color = Color("90a4ae")
			handle.material_override = h_mat
			handle.position = Vector3(0.80, 0.1, 0.04)
			hinge.add_child(handle)
				
		"furn_floor_lamp":
			# Base
			var base := MeshInstance3D.new()
			var b_mesh := CylinderMesh.new()
			b_mesh.top_radius = 0.22
			b_mesh.bottom_radius = 0.24
			b_mesh.height = 0.04
			base.mesh = b_mesh
			var metal_mat := StandardMaterial3D.new()
			metal_mat.albedo_color = Color("37474f")
			base.material_override = metal_mat
			base.position = Vector3(0, 0.02, 0)
			root.add_child(base)

			# Pole
			var pole := MeshInstance3D.new()
			var p_mesh := CylinderMesh.new()
			p_mesh.top_radius = 0.025
			p_mesh.bottom_radius = 0.025
			p_mesh.height = 1.45
			pole.mesh = p_mesh
			pole.material_override = metal_mat
			pole.position = Vector3(0, 0.74, 0)
			root.add_child(pole)

			# Lamp Shade (Named LampShade)
			var shade := MeshInstance3D.new()
			shade.name = "LampShade"
			var s_mesh := CylinderMesh.new()
			s_mesh.top_radius = 0.18
			s_mesh.bottom_radius = 0.28
			s_mesh.height = 0.32
			shade.mesh = s_mesh
			var s_mat := StandardMaterial3D.new()
			s_mat.albedo_color = Color("fff8e7")
			s_mat.emission_enabled = true
			s_mat.emission = Color("ffd54f")
			s_mat.emission_energy_multiplier = 0.8
			shade.material_override = s_mat
			shade.position = Vector3(0, 1.48, 0)
			root.add_child(shade)
				
		"furn_bookshelf":
			var frame := MeshInstance3D.new()
			var f_box := BoxMesh.new()
			f_box.size = Vector3(1.2, 1.7, 0.5)
			frame.mesh = f_box
			var bm := StandardMaterial3D.new()
			bm.albedo_color = Color("a1683d")
			frame.material_override = bm
			frame.position = Vector3(0, 0.85, 0)
			root.add_child(frame)

			# Shelves with books
			var book_colors := [Color("c62828"), Color("2e7d32"), Color("1565c0"), Color("f57f17"), Color("d84315"), Color("6a1b9a")]
			for y_idx in range(3):
				var shelf_y := 0.35 + y_idx * 0.45
				for b_idx in range(6):
					var bk := MeshInstance3D.new()
					var b_mesh := BoxMesh.new()
					b_mesh.size = Vector3(0.08, 0.3, 0.32)
					bk.mesh = b_mesh
					var b_mat := StandardMaterial3D.new()
					b_mat.albedo_color = book_colors[(y_idx * 3 + b_idx) % book_colors.size()]
					bk.material_override = b_mat
					bk.position = Vector3(-0.42 + b_idx * 0.16, shelf_y, 0.08)
					root.add_child(bk)
			
		"furn_potted_plant":
			# Ceramic Pot
			var pot := MeshInstance3D.new()
			var p_mesh := CylinderMesh.new()
			p_mesh.top_radius = 0.28
			p_mesh.bottom_radius = 0.20
			p_mesh.height = 0.45
			p_mesh.radial_segments = 16
			pot.mesh = p_mesh
			var pot_mat := StandardMaterial3D.new()
			pot_mat.albedo_color = Color("f5f5f5") # White ceramic
			pot.material_override = pot_mat
			pot.position = Vector3(0, 0.225, 0)
			root.add_child(pot)

			# Soil Mesh (Named PlantSoil)
			var soil := MeshInstance3D.new()
			soil.name = "PlantSoil"
			var s_mesh := CylinderMesh.new()
			s_mesh.top_radius = 0.26
			s_mesh.bottom_radius = 0.24
			s_mesh.height = 0.04
			s_mesh.radial_segments = 16
			soil.mesh = s_mesh
			var s_mat := StandardMaterial3D.new()
			s_mat.albedo_color = Color("8d6e63")
			soil.material_override = s_mat
			soil.position = Vector3(0, 0.43, 0)
			root.add_child(soil)

			# Lush Plant Leaves
			for angle_idx in range(5):
				var leaf := MeshInstance3D.new()
				var l_mesh := SphereMesh.new()
				l_mesh.radius = 0.16
				l_mesh.height = 0.32
				leaf.mesh = l_mesh
				var l_mat := StandardMaterial3D.new()
				l_mat.albedo_color = Color("4caf50")
				leaf.material_override = l_mat
				var rad: float = angle_idx * TAU / 5.0
				leaf.position = Vector3(cos(rad) * 0.15, 0.58 + (angle_idx % 2) * 0.08, sin(rad) * 0.15)
				leaf.rotation = Vector3(sin(rad) * 0.4, rad, cos(rad) * 0.4)
				root.add_child(leaf)

		"furn_kitchen_counter":
			# Wood Base Cabinet
			var cab := MeshInstance3D.new()
			var c_box := BoxMesh.new()
			c_box.size = Vector3(1.6, 0.88, 0.76)
			cab.mesh = c_box
			var cab_mat := StandardMaterial3D.new()
			cab_mat.albedo_color = Color("a8764a")
			cab.material_override = cab_mat
			cab.position = Vector3(0, 0.44, 0)
			root.add_child(cab)

			# White Ceramic Countertop
			var top := MeshInstance3D.new()
			var t_box := BoxMesh.new()
			t_box.size = Vector3(1.64, 0.08, 0.82)
			top.mesh = t_box
			var top_mat := StandardMaterial3D.new()
			top_mat.albedo_color = Color("f5f5f5")
			top.material_override = top_mat
			top.position = Vector3(0, 0.92, 0)
			root.add_child(top)

			# Cooking pot
			var pot := MeshInstance3D.new()
			var pot_mesh := CylinderMesh.new()
			pot_mesh.top_radius = 0.18
			pot_mesh.bottom_radius = 0.18
			pot_mesh.height = 0.22
			pot.mesh = pot_mesh
			var pot_mat := StandardMaterial3D.new()
			pot_mat.albedo_color = Color("bdc3c7")
			pot.material_override = pot_mat
			pot.position = Vector3(-0.35, 1.07, 0)
			root.add_child(pot)
				
		"furn_pet_food_bowl":
			var sc := load("res://scenes/pets/prop_food_bowl.tscn")
			if sc: return sc.instantiate()
		"furn_pet_water_bowl":
			var sc := load("res://scenes/pets/prop_water_bowl.tscn")
			if sc: return sc.instantiate()
		"furn_pet_bed":
			var sc := load("res://scenes/pets/prop_pet_bed.tscn")
			if sc: return sc.instantiate()
		"furn_pet_scratching_post":
			var sc := load("res://scenes/pets/prop_scratching_post.tscn")
			if sc: return sc.instantiate()
		"furn_pet_toy_wand":
			var sc := load("res://scenes/pets/prop_cat_toy_wand.tscn")
			if sc: return sc.instantiate()
		"furn_pet_toy_ball":
			var sc := load("res://scenes/pets/prop_toy_ball.tscn")
			if sc: return sc.instantiate()

		_:
			var m := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = def["footprint"]
			m.mesh = b
			m.position = Vector3(0, def["footprint"].y * 0.5, 0)
			root.add_child(m)
			
	return root

static func capture_state(container: Node3D) -> Dictionary:
	var result := {}
	if not is_instance_valid(container):
		return result
	var item := container.get_node_or_null("Interactable") as Interactable
	if is_instance_valid(item):
		result["toggle"] = item.toggle
		result["is_watered"] = item.is_watered
	for child in container.get_children():
		if child is PetProp:
			result["fill_amount"] = child.fill_amount
			break
	return result

static func create_placed_instance(id: String, pos: Vector3, rot_y: float, state: Dictionary = {}) -> Node3D:
	var def := get_definition(id)
	var container := Node3D.new()
	container.name = "Placed_" + id + "_" + str(Time.get_ticks_msec())
	container.position = pos
	container.rotation.y = rot_y
	container.set_meta("furniture_id", id)
	container.set_meta("is_placed_furniture", true)
	
	# Visual model
	var visual := create_visual_model(id)
	if visual is PetProp and state.has("fill_amount"):
		visual.fill_amount = clampf(float(state["fill_amount"]), 0.0, 1.0)
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
		
		match interact_kind:
			"lamp":
				item.toggle = state.get("toggle", true)
				var lamp_light := OmniLight3D.new()
				lamp_light.position = Vector3(0, def["footprint"].y, 0)
				lamp_light.light_color = Color("fff0dd")
				lamp_light.light_energy = 0.8
				lamp_light.omni_range = 4.0
				lamp_light.visible = item.toggle
				item.light = lamp_light
				item.add_child(lamp_light)
				item.moving_part = visual.find_child("LampShade", true, false)
				item._update_lamp_visual()
			"tv":
				item.toggle = state.get("toggle", false)
				var tv_light := OmniLight3D.new()
				tv_light.position = Vector3(0, 0.92, 0.35)
				tv_light.light_color = Color("80d8ff")
				tv_light.light_energy = 0.75
				tv_light.omni_range = 3.5
				tv_light.visible = item.toggle
				item.light = tv_light
				item.add_child(tv_light)
				item.screen_mesh = visual.find_child("TVScreen", true, false)
				item._update_tv_visual()
			"fridge":
				item.toggle = bool(state.get("toggle", false))
				var fr_door = visual.find_child("FridgeDoor", true, false)
				if fr_door:
					item.moving_part = fr_door
					fr_door.rotation.y = -1.45 if item.toggle else 0.0
				var fr_light := OmniLight3D.new()
				fr_light.position = Vector3(0, 1.0, 0.2)
				fr_light.light_color = Color("e0f7fa")
				fr_light.light_energy = 0.6
				fr_light.visible = item.toggle
				item.light = fr_light
				item.add_child(fr_light)
			"wardrobe":
				item.toggle = bool(state.get("toggle", false))
				var wl = visual.find_child("DoorLeft", true, false)
				var wr = visual.find_child("DoorRight", true, false)
				if wl:
					item.moving_part = wl
					wl.rotation.y = -1.55 if item.toggle else 0.0
				if wr:
					item.moving_part_2 = wr
					wr.rotation.y = 1.55 if item.toggle else 0.0
			"plant":
				item.is_watered = state.get("is_watered", false)
				item.soil_mesh = visual.find_child("PlantSoil", true, false)
				item._update_plant_visual()

		container.add_child(item)
	
	return container
