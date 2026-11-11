class_name WorkplaceGuidance
extends CanvasLayer

## Advanced Camera-Relative Directional Arrow and Navigation Guidance System.
## Dynamically resolves objectives based on player gender and business state.
## Renders smooth camera-relative directional arrows, off-screen edge clamping,
## distance badges, 3D pulsing ground beacons, and interaction highlights.

const GARAGE_DEFAULT := Vector3(-63, 0, -11)
const NOODLE_DEFAULT := Vector3(-50, 0, -17)
const HOUSE_EXIT := Vector3(-45, 0, 68)

var player: CharacterBody3D
var camera: Camera3D

var hud_panel: PanelContainer
var objective_title: Label
var direction_label: Label
var hint_label: Label

var edge_pointer: PanelContainer
var arrow_label: Label
var pointer_text: Label

var ground_beacon: Node3D
var beacon_ring: MeshInstance3D

var current_destination: Vector3 = Vector3.ZERO
var current_title: String = ""
var current_hint: String = ""
var arrived: bool = false
var smoothed_angle: float = 0.0

func _ready() -> void:
	layer = 90
	_build_ui()
	_build_ground_beacon()

func _build_ui() -> void:
	# 1. Top-Right Guidance Card (Clean, compact, no overlap with clock/wallet on left)
	hud_panel = PanelContainer.new()
	hud_panel.name = "GuidancePanel"
	hud_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	hud_panel.offset_left = -380
	hud_panel.offset_right = -16
	hud_panel.offset_top = 16
	hud_panel.offset_bottom = 110
	add_child(hud_panel)
	
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	hud_panel.add_child(col)
	
	var header := Label.new()
	header.text = "🎯 HƯỚNG DẪN MỤC TIÊU"
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", Color("ffd54f"))
	col.add_child(header)
	
	direction_label = Label.new()
	direction_label.text = "🧭 Đang định vị..."
	direction_label.add_theme_font_size_override("font_size", 16)
	direction_label.add_theme_color_override("font_color", Color("fff9c4"))
	col.add_child(direction_label)
	
	hint_label = Label.new()
	hint_label.text = ""
	hint_label.add_theme_font_size_override("font_size", 13)
	hint_label.add_theme_color_override("font_color", Color("cfd8dc"))
	col.add_child(hint_label)
	
	# 2. Dynamic Floating Screen-Edge Pointer
	edge_pointer = PanelContainer.new()
	edge_pointer.name = "EdgePointer"
	edge_pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge_pointer.custom_minimum_size = Vector2(170, 36)
	add_child(edge_pointer)
	
	var ptr_row := HBoxContainer.new()
	ptr_row.alignment = BoxContainer.ALIGNMENT_CENTER
	ptr_row.add_theme_constant_override("separation", 6)
	edge_pointer.add_child(ptr_row)
	
	arrow_label = Label.new()
	arrow_label.text = "▲"
	arrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow_label.add_theme_font_size_override("font_size", 18)
	arrow_label.add_theme_color_override("font_color", Color("69f0ae"))
	arrow_label.pivot_offset = Vector2(9, 12)
	ptr_row.add_child(arrow_label)
	
	pointer_text = Label.new()
	pointer_text.text = "Mục tiêu"
	pointer_text.add_theme_font_size_override("font_size", 13)
	pointer_text.add_theme_color_override("font_color", Color("ffffff"))
	ptr_row.add_child(pointer_text)

func _build_ground_beacon() -> void:
	ground_beacon = Node3D.new()
	ground_beacon.name = "NavGroundBeacon"
	
	# Subtle glowing flat ring mesh
	beacon_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.15
	torus.rings = 24
	torus.ring_segments = 16
	beacon_ring.mesh = torus
	
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("69f0ae")
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.85
	beacon_ring.material_override = mat
	beacon_ring.position.y = 0.12
	ground_beacon.add_child(beacon_ring)
	
	# Overhead 3D pin label
	var pin := Label3D.new()
	pin.name = "BeaconPin"
	pin.text = "▼"
	pin.position = Vector3(0, 2.4, 0)
	pin.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pin.font_size = 36
	pin.outline_size = 8
	pin.modulate = Color("69f0ae")
	pin.outline_modulate = Color("1a1a1a")
	ground_beacon.add_child(pin)
	
	get_parent().add_child.call_deferred(ground_beacon)

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("players") as CharacterBody3D
	if not is_instance_valid(camera):
		camera = get_viewport().get_camera_3d()
	if not is_instance_valid(player) or not is_instance_valid(camera):
		return
	
	_resolve_current_destination()
	_update_beacon(delta)
	_update_navigation_arrow(delta)

func _resolve_current_destination() -> void:
	var char_val = player.get("selected_character")
	if char_val == null and player.has_meta("selected_character"):
		char_val = player.get_meta("selected_character")
	var char_name: String = str(char_val) if char_val != null and str(char_val) != "" else "boy"
	var girl := char_name == "girl"
	var p_pos := player.global_position
	var in_house := p_pos.z > 65.0
	
	var is_riding: bool = player.has_meta("riding_scooter") and is_instance_valid(player.get_meta("riding_scooter"))
	
	if in_house:
		current_destination = HOUSE_EXIT
		current_title = "Cổng Sân Nhà"
		current_hint = "Ra sân lấy xe máy đi làm"
		return
	
	if not girl:
		# -------------------------------------------------------------
		# Boy Flow: Home -> Scooter -> Garage Parking -> Repair Bay
		# -------------------------------------------------------------
		if is_riding:
			current_destination = Vector3(-58.0, 0, -13.0)
			current_title = "🅿️ Bãi Đậu Xe Tiệm Sửa Xe"
			current_hint = "Lái xe đến bãi đậu của tiệm [E để đỗ xe]"
			return
		elif p_pos.z > 60.0:
			current_destination = Vector3(-48.0, 0, 72.0)
			current_title = "🛵 Xe Máy Của Boy"
			current_hint = "Lên xe máy [E] để di chuyển đến tiệm"
			return
		
		var garage := get_tree().get_first_node_in_group("garage_business") as GarageBusiness
		if not garage:
			garage = get_node_or_null("../GarageBusiness") as GarageBusiness
		
		if not is_instance_valid(garage) or p_pos.distance_to(GARAGE_DEFAULT) > 16.0:
			current_destination = GARAGE_DEFAULT
			current_title = "🛵 Tiệm Sửa Xe Chú Ba"
			current_hint = "Đến tiệm sửa xe máy"
			return
		
		# At garage: check for arriving/active orders needing repair
		var active_bay := -1
		var active_order: BusinessOrder = null
		for bay_idx in garage.bay_orders:
			var ord: BusinessOrder = garage.bay_orders[bay_idx]
			if ord.status == BusinessOrder.Status.PENDING or ord.status == BusinessOrder.Status.IN_PROGRESS:
				active_bay = bay_idx
				active_order = ord
				break
		
		if active_bay != -1 and active_order != null:
			# Guide to bay or tool station
			var step := active_order.get_current_required_step()
			var holding := garage.get_holding_tool(player)
			
			if step == "patch_kit" and holding != "patch_kit":
				current_destination = garage.global_position + Vector3(-101, 0, -20)
				current_title = "Bàn Thợ (Lấy Miếng Vá)"
				current_hint = "Lấy miếng vá lốp tại bàn làm việc"
			elif step == "mount_tire" and holding != "new_tire":
				current_destination = garage.global_position + Vector3(-112, 0, -12)
				current_title = "Kệ Lốp Mới (Lấy Lốp)"
				current_hint = "Lấy lốp xe mới từ kệ để thay"
			elif step == "pump_air":
				current_destination = garage.global_position + garage.bay_positions[active_bay]
				current_title = "Khoang %d: Bơm Căng Lốp Xe" % (active_bay + 1)
				current_hint = "Nhấn [E] để bơm lốp hoàn thành đơn"
			else:
				current_destination = garage.global_position + garage.bay_positions[active_bay]
				current_title = "Khoang %d: %s" % [active_bay + 1, active_order.service_title]
				current_hint = "Khách %s đang chờ sửa xe" % active_order.customer_name
		else:
			current_destination = GARAGE_DEFAULT
			current_title = "🛵 Tiệm Sửa Xe Chú Ba"
			current_hint = "Sẵn sàng đón khách vào tiệm sửa xe"
	else:
		# -------------------------------------------------------------
		# Girl Flow: Home -> Scooter -> Hu Tieu Parking -> Prep -> Tables
		# -------------------------------------------------------------
		if is_riding:
			current_destination = Vector3(-44.0, 0, -15.0)
			current_title = "🅿️ Bãi Đậu Xe Quán Hủ Tiếu"
			current_hint = "Lái xe đến bãi đậu của quán [E để đỗ xe]"
			return
		elif p_pos.z > 60.0:
			current_destination = Vector3(-42.0, 0, 72.0)
			current_title = "🛵 Xe Máy Của Girl"
			current_hint = "Lên xe máy [E] để di chuyển đến quán"
			return
		
		var hutieu := get_tree().get_first_node_in_group("hutieu_business") as HuTieuBusiness
		if not hutieu:
			hutieu = get_node_or_null("../HuTieuBusiness") as HuTieuBusiness
		
		if not is_instance_valid(hutieu) or p_pos.distance_to(NOODLE_DEFAULT) > 16.0:
			current_destination = NOODLE_DEFAULT
			current_title = "🍜 Quán Hủ Tiếu Cô Bảy"
			current_hint = "Đến quán hủ tiếu đầu ngõ"
			return
		
		# Check prep state
		if hutieu.prep_state == HuTieuBusiness.PrepState.CLOSED:
			current_destination = hutieu.global_position + Vector3(-50.0, 0, -17.0)
			current_title = "Bếp: Chuẩn Bị Mở Quán"
			current_hint = "Nhấn [E] để chuẩn bị nước lèo & nguyên liệu"
		elif hutieu.prep_state == HuTieuBusiness.PrepState.PREPARING:
			current_destination = hutieu.global_position + Vector3(-50.0, 0, -17.0)
			current_title = "Đang Chuẩn Bị Quán... %d%%" % int(hutieu.prep_progress)
			current_hint = "Nồi nước lèo đang sôi sùng sục..."
		elif hutieu.prep_state == HuTieuBusiness.PrepState.READY:
			current_destination = hutieu.global_position + Vector3(-50.0, 0, -17.0)
			current_title = "Bếp: Sẵn Sàng Bán!"
			current_hint = "Nhấn [E] để chính thức mở cửa đón khách"
		else:
			# Shop is OPEN: check orders
			var waiting_table := -1
			var waiting_order: BusinessOrder = null
			for tbl_idx in hutieu.table_orders:
				var ord: BusinessOrder = hutieu.table_orders[tbl_idx]
				if ord.status == BusinessOrder.Status.PENDING or ord.status == BusinessOrder.Status.IN_PROGRESS:
					waiting_table = tbl_idx
					waiting_order = ord
					break
			
			if waiting_table != -1 and waiting_order != null:
				if hutieu.current_bowl_state == HuTieuBusiness.BowlState.EMPTY:
					current_destination = hutieu.global_position + Vector3(-51.8, 0, -17.2)
					current_title = "Nồi Trụng: Lấy Sợi Hủ Tiếu"
					current_hint = "Nhấn [E] để trụng bánh hủ tiếu vào nước sôi"
				elif hutieu.current_bowl_state == HuTieuBusiness.BowlState.BLANCHING:
					current_destination = hutieu.global_position + Vector3(-51.8, 0, -17.2)
					current_title = "Đang Trụng Sợi Hủ Tiếu..."
					current_hint = "Chờ vài giây cho sợi chín dai ngon"
				elif hutieu.current_bowl_state == HuTieuBusiness.BowlState.NOODLES_DONE:
					current_destination = hutieu.global_position + Vector3(-50.0, 0, -17.2)
					current_title = "Nồi Hầm: Chan Nước Lèo"
					current_hint = "Nhấn [E] để chan nước lèo nóng hổi"
				elif hutieu.current_bowl_state == HuTieuBusiness.BowlState.BROTH_ADDED:
					current_destination = hutieu.global_position + Vector3(-48.2, 0, -17.2)
					current_title = "Quầy Topping: Thêm Thịt & Tôm"
					current_hint = "Nhấn [E] để rắc tôm thịt, tóp mỡ, hành phi"
				elif hutieu.current_bowl_state == HuTieuBusiness.BowlState.FULLY_PREPARED:
					current_destination = hutieu.global_position + hutieu.table_positions[waiting_table]
					current_title = "Phục Vụ Bàn %d" % (waiting_table + 1)
					current_hint = "Bưng %s cho %s [E]" % [waiting_order.service_title, waiting_order.customer_name]
			else:
				current_destination = NOODLE_DEFAULT
				current_title = "🍜 Quán Hủ Tiếu Cô Bảy"
				current_hint = "Quán đang mở, chờ khách vào bàn"

func _update_beacon(delta: float) -> void:
	if not is_instance_valid(ground_beacon) or not ground_beacon.is_inside_tree(): return
	ground_beacon.global_position = current_destination
	
	# Gentle floating pulse
	var t := Time.get_ticks_msec() / 1000.0
	beacon_ring.scale = Vector3.ONE * (1.0 + 0.12 * sin(t * 4.0))
	ground_beacon.visible = not arrived

func _update_navigation_arrow(delta: float) -> void:
	var dist: float = player.global_position.distance_to(current_destination)
	arrived = dist < 2.5
	
	# -------------------------------------------------------------
	# 1. Exact Camera-Relative Ground Projection
	# -------------------------------------------------------------
	var cam_fwd := -camera.global_basis.z
	cam_fwd.y = 0.0
	cam_fwd = cam_fwd.normalized()
	
	var cam_right := camera.global_basis.x
	cam_right.y = 0.0
	cam_right = cam_right.normalized()
	
	var delta_pos := current_destination - player.global_position
	delta_pos.y = 0.0
	
	var right_dot := delta_pos.dot(cam_right)
	var fwd_dot := delta_pos.dot(cam_fwd)
	
	# Screen direction vector: X is screen right, Y is screen up (negative Y in 2D UI)
	var screen_dir := Vector2(right_dot, -fwd_dot).normalized()
	var target_angle := screen_dir.angle()
	smoothed_angle = lerp_angle(smoothed_angle, target_angle, 1.0 - exp(-12.0 * delta))
	
	# Direction glyph for Top-Right HUD Card
	var glyphs := ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"]
	var glyph_idx := posmod(int(round(smoothed_angle / (PI / 4.0))), 8)
	var arrow_char: String = glyphs[glyph_idx]
	
	if arrived:
		direction_label.text = "✅ ĐÃ ĐẾN NƠI"
		direction_label.add_theme_color_override("font_color", Color("69f0ae"))
		hint_label.text = current_title + " · Tương tác [E]"
	else:
		direction_label.text = "%s  %s  ·  %d m" % [arrow_char, current_title, int(round(dist))]
		direction_label.add_theme_color_override("font_color", Color("fff9c4"))
		hint_label.text = current_hint
	
	# -------------------------------------------------------------
	# 2. Dynamic Floating Screen-Edge Pointer
	# -------------------------------------------------------------
	var vp_size := get_viewport().get_visible_rect().size
	var screen_center := vp_size * 0.5
	var target_screen_pos := camera.unproject_position(current_destination + Vector3(0, 1.2, 0))
	var is_behind := camera.is_position_behind(current_destination)
	
	var margin := 70.0
	var bounds_min := Vector2(margin, margin)
	var bounds_max := vp_size - Vector2(margin + 120, margin + 40)
	
	var is_on_screen := not is_behind and target_screen_pos.x >= bounds_min.x and target_screen_pos.x <= bounds_max.x and target_screen_pos.y >= bounds_min.y and target_screen_pos.y <= bounds_max.y
	
	if arrived:
		edge_pointer.visible = false
	else:
		edge_pointer.visible = true
		pointer_text.text = "%s (%dm)" % [current_title, int(round(dist))]
		
		if is_on_screen:
			# Anchor smoothly above the on-screen 3D object
			edge_pointer.position = edge_pointer.position.lerp(target_screen_pos - Vector2(85, 45), 1.0 - exp(-15.0 * delta))
			arrow_label.text = "▼"
			arrow_label.rotation = 0.0
		else:
			# Clamp to screen border pointing towards the off-screen destination
			var pointer_pos := screen_center + screen_dir * (minf(vp_size.x, vp_size.y) * 0.42)
			pointer_pos.x = clampf(pointer_pos.x, bounds_min.x, bounds_max.x)
			pointer_pos.y = clampf(pointer_pos.y, bounds_min.y, bounds_max.y)
			
			edge_pointer.position = edge_pointer.position.lerp(pointer_pos, 1.0 - exp(-15.0 * delta))
			arrow_label.text = "▲"
			arrow_label.rotation = smoothed_angle + PI / 2.0
