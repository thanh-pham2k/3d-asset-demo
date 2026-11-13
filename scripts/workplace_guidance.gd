class_name WorkplaceGuidance
extends CanvasLayer

## Advanced Camera-Relative Directional Arrow and Navigation Guidance System.
## Dynamically resolves objectives based on player gender, inventory, and business state.
## Renders smooth camera-relative directional arrows, 3D player directional arrow,
## off-screen edge clamping, distance badges, and 3D pulsing ground beacons.

const GARAGE_DEFAULT := Vector3(-63, 0, -11)
const TOOL_SHOP_POS := Vector3(-56.0, 0, -14.0)
const NOODLE_DEFAULT := Vector3(-50, 0, -17)
const HOUSE_EXIT := Vector3(-45, 0, 68)
const WAYPOINT_ARRIVAL_RADIUS := 4.0

signal waypoint_changed(active: bool, waypoint_id: String, title: String, pos: Vector3)
signal waypoint_arrived(waypoint_id: String, title: String)

var player: CharacterBody3D
var camera: Camera3D

var hud_panel: PanelContainer
var header_label: Label
var objective_title: Label
var direction_label: Label
var direction: Label:
	get: return direction_label
var hint_label: Label

var edge_pointer: PanelContainer
var arrow_icon: Control
var arrow_label: Label
var pointer_text: Label

var ground_beacon: Node3D
var beacon_ring: MeshInstance3D
var player_arrow: Node3D

var current_destination: Vector3 = Vector3.ZERO
var current_title: String = ""
var current_hint: String = ""
var has_navigation_target: bool = true
var arrived: bool = false
var smoothed_angle: float = 0.0
var smoothed_world_yaw: float = 0.0

# Priority 1: Mandatory story/tutorial objective
var has_mandatory_objective: bool = false
var mandatory_title: String = ""
var mandatory_pos: Vector3 = Vector3.ZERO
var mandatory_hint: String = ""

# Priority 2: Player-selected custom waypoint
var has_custom_waypoint: bool = false
var custom_waypoint_id: String = ""
var custom_waypoint_title: String = ""
var custom_waypoint_pos: Vector3 = Vector3.ZERO
var custom_waypoint_hint: String = ""

# Navigation path state
var current_route_points: PackedVector3Array = PackedVector3Array()
var is_walkable_route: bool = false
var _last_path_query_msec: int = 0
var _last_path_from: Vector3 = Vector3.ZERO
var _last_path_to: Vector3 = Vector3.ZERO
var _arrival_banner_timer: float = 0.0
var _arrival_banner_text: String = ""

func _ready() -> void:
	layer = 90
	add_to_group("workplace_guidance")
	_build_ui()
	_build_ground_beacon()
	_build_player_arrow()

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
	header_label = header
	
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
	edge_pointer.custom_minimum_size = Vector2(180, 36)
	add_child(edge_pointer)
	
	var ptr_row := HBoxContainer.new()
	ptr_row.alignment = BoxContainer.ALIGNMENT_CENTER
	ptr_row.add_theme_constant_override("separation", 6)
	edge_pointer.add_child(ptr_row)
	
	arrow_icon = Control.new()
	arrow_icon.name = "ArrowIcon"
	arrow_icon.custom_minimum_size = Vector2(22, 22)
	arrow_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow_icon.draw.connect(_draw_arrow_icon)
	ptr_row.add_child(arrow_icon)
	
	# Keep arrow_label for compatibility with any external inspection
	arrow_label = Label.new()
	arrow_label.text = "▲"
	arrow_label.visible = false
	ptr_row.add_child(arrow_label)
	
	pointer_text = Label.new()
	pointer_text.text = "Mục tiêu"
	pointer_text.add_theme_font_size_override("font_size", 13)
	pointer_text.add_theme_color_override("font_color", Color("ffffff"))
	ptr_row.add_child(pointer_text)

func _draw_arrow_icon() -> void:
	if not is_instance_valid(arrow_icon):
		return
	var center := arrow_icon.size * 0.5
	var dir := Vector2(cos(smoothed_angle), sin(smoothed_angle))
	if arrow_label.text == "▼" and arrow_label.rotation == 0.0:
		dir = Vector2(0, 1)
	var perp := Vector2(-dir.y, dir.x)
	var tip := center + dir * 9.0
	var tail_l := center - dir * 6.5 + perp * 6.0
	var tail_m := center - dir * 3.5
	var tail_r := center - dir * 6.5 - perp * 6.0
	arrow_icon.draw_colored_polygon(
		PackedVector2Array([tip, tail_l, tail_m, tail_r]),
		Color("69f0ae")
	)

func _build_ground_beacon() -> void:
	ground_beacon = Node3D.new()
	ground_beacon.name = "NavGroundBeacon"
	
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

func _build_player_arrow() -> void:
	player_arrow = Node3D.new()
	player_arrow.name = "PlayerNavArrow3D"
	
	var arrow_mat := StandardMaterial3D.new()
	arrow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arrow_mat.albedo_color = Color(0.41, 0.94, 0.68, 0.92)
	arrow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	# Arrow shaft & chevron pointing toward local +Z (so atan2(dx, dz) aligns +Z with target)
	var shaft := MeshInstance3D.new()
	var shaft_mesh := BoxMesh.new()
	shaft_mesh.size = Vector3(0.18, 0.04, 0.42)
	shaft.mesh = shaft_mesh
	shaft.material_override = arrow_mat
	shaft.position = Vector3(0, 0.14, 1.15)
	player_arrow.add_child(shaft)
	
	var wing_l := MeshInstance3D.new()
	var wing_mesh := BoxMesh.new()
	wing_mesh.size = Vector3(0.14, 0.04, 0.36)
	wing_l.mesh = wing_mesh
	wing_l.material_override = arrow_mat
	wing_l.position = Vector3(0.11, 0.14, 1.38)
	wing_l.rotation.y = -0.65
	player_arrow.add_child(wing_l)
	
	var wing_r := MeshInstance3D.new()
	wing_r.mesh = wing_mesh
	wing_r.material_override = arrow_mat
	wing_r.position = Vector3(-0.11, 0.14, 1.38)
	wing_r.rotation.y = 0.65
	player_arrow.add_child(wing_r)
	
	get_parent().add_child.call_deferred(player_arrow)

func set_mandatory_objective(title: String, pos: Vector3, hint: String = "") -> void:
	has_mandatory_objective = true
	mandatory_title = title
	mandatory_pos = pos
	mandatory_hint = hint
	_invalidate_path_cache()

func clear_mandatory_objective() -> void:
	has_mandatory_objective = false
	mandatory_title = ""
	mandatory_pos = Vector3.ZERO
	mandatory_hint = ""
	_invalidate_path_cache()

func set_custom_waypoint(waypoint_id: String, title: String, pos: Vector3, hint: String = "") -> void:
	has_custom_waypoint = true
	custom_waypoint_id = waypoint_id
	custom_waypoint_title = title
	custom_waypoint_pos = pos
	custom_waypoint_hint = hint if hint != "" else "Điểm đến đã chọn trên bản đồ"
	_arrival_banner_timer = 0.0
	_invalidate_path_cache()
	waypoint_changed.emit(true, custom_waypoint_id, custom_waypoint_title, custom_waypoint_pos)

func clear_custom_waypoint(notify: bool = false) -> void:
	if not has_custom_waypoint:
		return
	var old_title := custom_waypoint_title
	has_custom_waypoint = false
	custom_waypoint_id = ""
	custom_waypoint_title = ""
	custom_waypoint_pos = Vector3.ZERO
	custom_waypoint_hint = ""
	_invalidate_path_cache()
	waypoint_changed.emit(false, "", "", Vector3.ZERO)
	if notify and is_inside_tree():
		var fx := get_tree().get_first_node_in_group("chaos_feedback")
		if is_instance_valid(fx) and fx.has_method("show_toast"):
			fx.show_toast("🗺️ Đã xóa điểm đến '%s' · Quay lại mục tiêu hàng ngày" % old_title)

func _invalidate_path_cache() -> void:
	_last_path_query_msec = 0
	current_route_points = PackedVector3Array()
	is_walkable_route = false

func _process(delta: float) -> void:
	var active_p := get_tree().get_first_node_in_group("active_player") as CharacterBody3D
	if is_instance_valid(active_p):
		player = active_p
	elif not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("players") as CharacterBody3D
	if not is_instance_valid(camera):
		camera = get_viewport().get_camera_3d()
	if not is_instance_valid(player) or not is_instance_valid(camera):
		return
	
	if _arrival_banner_timer > 0.0:
		_arrival_banner_timer = maxf(0.0, _arrival_banner_timer - delta)
	
	_resolve_current_destination()
	_check_custom_waypoint_arrival()
	_update_header_label()
	_update_navigation_path()
	_update_beacon(delta)
	_update_navigation_arrow(delta)

func _update_header_label() -> void:
	if not is_instance_valid(header_label):
		return
	if has_mandatory_objective:
		header_label.text = "⚠️ NHIỆM VỤ BẮT BUỘC"
		header_label.add_theme_color_override("font_color", Color("ffab40"))
	elif has_custom_waypoint:
		header_label.text = "📍 ĐIỂM ĐẾN TỰ CHỌN"
		header_label.add_theme_color_override("font_color", Color("40c4ff"))
	else:
		var daily_loop = get_tree().get_first_node_in_group("daily_loop_manager")
		if is_instance_valid(daily_loop):
			header_label.text = "🎯 MỤC TIÊU — NGÀY %d" % daily_loop.current_day
		else:
			header_label.text = "🎯 HƯỚNG DẪN MỤC TIÊU"
		header_label.add_theme_color_override("font_color", Color("ffd54f"))

func _check_custom_waypoint_arrival() -> void:
	if has_mandatory_objective or not has_custom_waypoint or not is_instance_valid(player):
		return
	var p_xz := Vector2(player.global_position.x, player.global_position.z)
	var d_xz := Vector2(custom_waypoint_pos.x, custom_waypoint_pos.z)
	if p_xz.distance_to(d_xz) <= WAYPOINT_ARRIVAL_RADIUS:
		var arrived_id := custom_waypoint_id
		var arrived_title := custom_waypoint_title
		_arrival_banner_text = "✅ Đã đến %s!" % arrived_title
		_arrival_banner_timer = 3.0
		var fx := get_tree().get_first_node_in_group("chaos_feedback")
		if is_instance_valid(fx) and fx.has_method("show_toast"):
			fx.show_toast("📍 Đã đến %s!" % arrived_title)
		waypoint_arrived.emit(arrived_id, arrived_title)
		clear_custom_waypoint(false)
		_resolve_current_destination()

func _resolve_current_destination() -> void:
	has_navigation_target = true
	
	# Priority 1: Mandatory story/tutorial instruction
	if has_mandatory_objective:
		current_destination = mandatory_pos
		current_title = mandatory_title
		current_hint = mandatory_hint
		return
	
	# Priority 2: Player-selected custom waypoint
	if has_custom_waypoint:
		current_destination = custom_waypoint_pos
		current_title = custom_waypoint_title
		current_hint = custom_waypoint_hint
		return
	
	# Priority 3: Suggested daily objective
	_resolve_daily_destination()

func _resolve_daily_destination() -> void:
	var char_val = player.get("selected_character")
	if char_val == null and player.has_meta("selected_character"):
		char_val = player.get_meta("selected_character")
	var char_name: String = str(char_val) if char_val != null and str(char_val) != "" else "boy"
	var girl := char_name == "girl"
	var p_pos := player.global_position
	var in_house := p_pos.z > 83.0
	
	var is_riding: bool = player.has_meta("riding_scooter") and is_instance_valid(player.get_meta("riding_scooter"))
	var sc = player.get_meta("riding_scooter") if player.has_meta("riding_scooter") else null
	var heading_home := false
	if is_instance_valid(sc):
		if sc.auto_cruising:
			heading_home = not sc.cruise_target_is_work
		else:
			heading_home = p_pos.distance_to(sc.home_parking_pos) > p_pos.distance_to(sc.work_parking_pos)
	
	if in_house:
		var daily_loop_node = get_tree().get_first_node_in_group("daily_loop_manager")
		var time_mgr := get_tree().get_first_node_in_group("time_manager") as NeighborhoodTimeManager
		var is_evening: bool = is_instance_valid(time_mgr) and (time_mgr.current_hour >= 18.0 or time_mgr.current_hour < 6.0)
		var suggest_sleep: bool = is_evening or (is_instance_valid(daily_loop_node) and daily_loop_node.has_worked_today())
		
		if suggest_sleep and p_pos.distance_to(Vector3(-45, 0, 88)) < 6.0:
			current_destination = Vector3(-50.5, 0, 90.75)
			current_title = "🛏️ Giường Ngủ (Lưu Tiến Trình)"
			current_hint = "Nằm nghỉ trên giường [E] để ngủ và sang ngày mới"
			return
		else:
			current_destination = HOUSE_EXIT
			current_title = "Cổng Sân Nhà"
			current_hint = "Ra sân chăm vườn, đi chợ hoặc mở Bản đồ [M] chọn nơi đến"
			return
	
	if not girl:
		# -------------------------------------------------------------
		# Boy Flow: Home -> Scooter -> Garage / Tool Shop / Repair Station -> Return
		# -------------------------------------------------------------
		if is_riding:
			if heading_home:
				current_destination = sc.home_parking_pos if is_instance_valid(sc) else Vector3(-48.0, 0, 72.0)
				current_title = "🏡 Bãi Đỗ Xe Tại Nhà"
				current_hint = "Lái xe về nhà [E để đỗ xe]"
			else:
				current_destination = Vector3(-58.0, 0, -13.0)
				current_title = "🅿️ Bãi Đậu Xe Tiệm Sửa Xe"
				current_hint = "Lái xe đến bãi đậu của tiệm [E để đỗ xe]"
			return
		elif p_pos.z > 60.0:
			var at_home_bay := p_pos.distance_to(Vector3(-48.0, 0, 72.0)) < 4.0
			var dl = get_tree().get_first_node_in_group("daily_loop_manager")
			var has_worked: bool = false
			if is_instance_valid(dl):
				has_worked = dl.has_worked_today()
			else:
				var econ = get_tree().get_first_node_in_group("economy_manager")
				has_worked = is_instance_valid(econ) and (econ.wallet.total_earned > 0)
			if at_home_bay and has_worked:
				current_destination = Vector3(-45.0, 0, 84.0)
				current_title = "🏠 Cửa Chính Vào Nhà"
				current_hint = "Vào nhà nghỉ ngơi & lưu tiến trình"
				return
			
			current_destination = Vector3(-48.0, 0, 72.0)
			current_title = "🛵 Xe Máy Của Boy"
			current_hint = "Lên xe máy [E] để di chuyển đến tiệm"
			return
		
		var garage := get_tree().get_first_node_in_group("garage_business") as GarageBusiness
		if not garage:
			garage = get_node_or_null("../GarageBusiness") as GarageBusiness
		
		var dl_boy = get_tree().get_first_node_in_group("daily_loop_manager")
		if is_instance_valid(garage) and not garage.is_open and is_instance_valid(dl_boy) and dl_boy.has_worked_today():
			current_destination = Vector3(-58.0, 0, -13.0)
			current_title = "🛵 Lên Xe Máy Về Nhà"
			current_hint = "Tiệm đã đóng cửa, lên xe máy [E] để về nhà nghỉ ngơi"
			return
		
		# Check if player needs Repair Kits from the Tool Shop
		if is_instance_valid(garage) and (garage.get_repair_kit_count() <= 0 or garage.needs_tool_shop_guidance):
			current_destination = TOOL_SHOP_POS
			current_title = "🧰 Cửa Hàng Dụng Cụ Sửa Xe"
			current_hint = "Mua thêm Bộ dụng cụ sửa xe [E]"
			return
		
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
			current_destination = garage.to_global(garage.bay_positions[active_bay])
			if garage.is_repairing and garage.active_repair_bay == active_bay:
				var pct := clampi(int(round((garage.repair_elapsed / maxf(0.1, garage.repair_duration)) * 100.0)), 0, 100)
				current_title = "🔧 Đang sửa xe... %d%%" % pct
				current_hint = "Giữ vị trí cạnh xe để hoàn tất sửa chữa"
			else:
				current_title = "🏍️ Khoang %d: %s" % [active_bay + 1, active_order.service_title]
				current_hint = "Nhấn E để sửa xe cho %s" % active_order.customer_name
		else:
			var obj_mgr := get_tree().get_first_node_in_group("daily_objective_manager") as DailyObjectiveManager
			var work_done := false
			if is_instance_valid(obj_mgr):
				for obj in obj_mgr.objectives:
					if obj.get("id", "") == "obj_serve_customers" and bool(obj.get("is_completed", false)):
						work_done = true
						break
			current_destination = GARAGE_DEFAULT
			if work_done:
				current_title = "✓ Hoàn Thành Mục Tiêu Sửa Xe"
				current_hint = "Có thể tiếp tục sửa xe hoặc đóng cửa tiệm về nhà"
				has_navigation_target = false
			else:
				current_title = "🛵 Tiệm Sửa Xe Chú Ba"
				current_hint = "Đang chờ khách mang xe vào khoang sửa"
				has_navigation_target = false
	else:
		# -------------------------------------------------------------
		# Girl Flow: Home -> Scooter -> Hu Tieu Parking -> Prep -> Tables -> Return
		# -------------------------------------------------------------
		if is_riding:
			if heading_home:
				current_destination = sc.home_parking_pos if is_instance_valid(sc) else Vector3(-42.0, 0, 72.0)
				current_title = "🏡 Bãi Đỗ Xe Tại Nhà"
				current_hint = "Lái xe về nhà [E để đỗ xe]"
			else:
				current_destination = Vector3(-44.0, 0, -15.0)
				current_title = "🅿️ Bãi Đậu Xe Quán Hủ Tiếu"
				current_hint = "Lái xe đến bãi đậu của quán [E để đỗ xe]"
			return
		elif p_pos.z > 60.0:
			var at_home_bay := p_pos.distance_to(Vector3(-42.0, 0, 72.0)) < 4.0
			var dl = get_tree().get_first_node_in_group("daily_loop_manager")
			var has_worked: bool = false
			if is_instance_valid(dl):
				has_worked = dl.has_worked_today()
			else:
				var econ = get_tree().get_first_node_in_group("economy_manager")
				has_worked = is_instance_valid(econ) and (econ.wallet.total_earned > 0)
			if at_home_bay and has_worked:
				current_destination = Vector3(-45.0, 0, 84.0)
				current_title = "🏠 Cửa Chính Vào Nhà"
				current_hint = "Vào nhà nghỉ ngơi & lưu tiến trình"
				return
			
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
		
		if hutieu.prep_state == HuTieuBusiness.PrepState.CLOSED:
			var dl_girl = get_tree().get_first_node_in_group("daily_loop_manager")
			if is_instance_valid(dl_girl) and dl_girl.has_worked_today():
				current_destination = Vector3(-44.0, 0, -15.0)
				current_title = "🛵 Lên Xe Máy Về Nhà"
				current_hint = "Quán đã đóng cửa, lên xe máy [E] để về nhà nghỉ ngơi"
				return
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
				has_navigation_target = false

func _update_navigation_path() -> void:
	if not has_navigation_target or not is_instance_valid(player):
		current_route_points = PackedVector3Array()
		is_walkable_route = false
		return
	var now := Time.get_ticks_msec()
	var p_pos := player.global_position
	var dest := current_destination
	if now - _last_path_query_msec < 200 and p_pos.distance_to(_last_path_from) < 1.5 and dest.distance_to(_last_path_to) < 0.5:
		return
	_last_path_query_msec = now
	_last_path_from = p_pos
	_last_path_to = dest
	
	var world_3d := player.get_world_3d()
	if not world_3d:
		current_route_points = PackedVector3Array()
		is_walkable_route = false
		return
	var nav_map := world_3d.navigation_map
	if not nav_map.is_valid() or NavigationServer3D.map_get_iteration_id(nav_map) <= 0:
		current_route_points = PackedVector3Array()
		is_walkable_route = false
		return
	
	var path := NavigationServer3D.map_get_path(nav_map, p_pos, dest, true)
	if path.size() >= 2:
		var end_xz := Vector2(path[path.size() - 1].x, path[path.size() - 1].z)
		var dest_xz := Vector2(dest.x, dest.z)
		if end_xz.distance_to(dest_xz) <= 8.0:
			current_route_points = path
			is_walkable_route = true
			return
	current_route_points = PackedVector3Array()
	is_walkable_route = false

func _get_steering_target() -> Vector3:
	if is_walkable_route and current_route_points.size() >= 2 and is_instance_valid(player):
		var p_xz := Vector2(player.global_position.x, player.global_position.z)
		for i in range(1, current_route_points.size()):
			var pt := current_route_points[i]
			var pt_xz := Vector2(pt.x, pt.z)
			if p_xz.distance_to(pt_xz) > 2.2 or i == current_route_points.size() - 1:
				return pt
	return current_destination

func _update_beacon(_delta: float) -> void:
	if not is_instance_valid(ground_beacon) or not ground_beacon.is_inside_tree(): return
	ground_beacon.global_position = current_destination
	var col := Color("ffab40") if has_mandatory_objective else (Color("40c4ff") if has_custom_waypoint else Color("69f0ae"))
	if is_instance_valid(beacon_ring) and beacon_ring.material_override is StandardMaterial3D:
		var mat := beacon_ring.material_override as StandardMaterial3D
		mat.albedo_color = Color(col.r, col.g, col.b, 0.85)
	var pin := ground_beacon.get_node_or_null("BeaconPin") as Label3D
	if is_instance_valid(pin):
		pin.modulate = col
	
	var t := Time.get_ticks_msec() / 1000.0
	beacon_ring.scale = Vector3.ONE * (1.0 + 0.12 * sin(t * 4.0))
	ground_beacon.visible = has_navigation_target and not arrived

func _update_navigation_arrow(delta: float) -> void:
	var dest_delta := current_destination - player.global_position
	dest_delta.y = 0.0
	var dist: float = dest_delta.length()
	var arrival_threshold := WAYPOINT_ARRIVAL_RADIUS if (has_custom_waypoint and not has_mandatory_objective) else 2.4
	arrived = (not has_navigation_target) or (dist < arrival_threshold)
	
	var steer_target := _get_steering_target()
	var delta_3d := steer_target - player.global_position
	delta_3d.y = 0.0
	if delta_3d.length_squared() < 0.01:
		delta_3d = dest_delta
	
	# -------------------------------------------------------------
	# 1. 3D Ground Directional Arrow around Player
	# -------------------------------------------------------------
	if is_instance_valid(player_arrow) and player_arrow.is_inside_tree():
		if has_navigation_target and not arrived and dist > 0.1:
			player_arrow.visible = true
			player_arrow.global_position = Vector3(player.global_position.x, 0.05, player.global_position.z)
			var target_yaw := atan2(delta_3d.x, delta_3d.z)
			smoothed_world_yaw = lerp_angle(smoothed_world_yaw, target_yaw, 1.0 - exp(-16.0 * delta))
			player_arrow.global_rotation = Vector3(0.0, smoothed_world_yaw, 0.0)
		else:
			player_arrow.visible = false
	
	# -------------------------------------------------------------
	# 2. Exact Camera-Relative Screen-Space Direction Calculation
	# -------------------------------------------------------------
	var cam_fwd := -camera.global_basis.z
	cam_fwd.y = 0.0
	if cam_fwd.length_squared() < 0.0001:
		cam_fwd = Vector3.FORWARD
	else:
		cam_fwd = cam_fwd.normalized()
	
	var cam_right := camera.global_basis.x
	cam_right.y = 0.0
	if cam_right.length_squared() < 0.0001:
		cam_right = Vector3.RIGHT
	else:
		cam_right = cam_right.normalized()
	
	var right_dot := delta_3d.dot(cam_right)
	var fwd_dot := delta_3d.dot(cam_fwd)
	
	# Screen direction vector: +X is screen right, +Y is screen down (so forward is -Y)
	var screen_dir := Vector2(right_dot, -fwd_dot)
	if screen_dir.length_squared() > 0.0001:
		screen_dir = screen_dir.normalized()
	else:
		screen_dir = Vector2.UP
	
	var target_angle := screen_dir.angle()
	smoothed_angle = lerp_angle(smoothed_angle, target_angle, 1.0 - exp(-15.0 * delta))
	
	# Direction glyph for Top-Right HUD Card
	var glyphs := ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"]
	var glyph_idx := posmod(int(round(smoothed_angle / (PI / 4.0))), 8)
	var arrow_char: String = glyphs[glyph_idx]
	
	if _arrival_banner_timer > 0.0 and not has_custom_waypoint:
		direction_label.text = _arrival_banner_text
		direction_label.add_theme_color_override("font_color", Color("69f0ae"))
		hint_label.text = "Đang tiếp tục: %s" % current_title
	elif not has_navigation_target:
		direction_label.text = current_title
		direction_label.add_theme_color_override("font_color", Color("69f0ae"))
		hint_label.text = current_hint
	elif arrived:
		direction_label.text = "✅ ĐÃ ĐẾN NƠI"
		direction_label.add_theme_color_override("font_color", Color("69f0ae"))
		hint_label.text = current_title + " · Tương tác [E]"
	else:
		direction_label.text = "%s  %s  ·  %d m" % [arrow_char, current_title, int(round(dist))]
		direction_label.add_theme_color_override("font_color", Color("80d8ff") if has_custom_waypoint else Color("fff9c4"))
		var route_tag := "🛤️ Theo lối đi" if is_walkable_route else "🧭 Hướng chim bay"
		hint_label.text = "%s · %s" % [route_tag, current_hint] if has_custom_waypoint else current_hint
	
	# -------------------------------------------------------------
	# 3. Dynamic Floating Screen-Edge Pointer
	# -------------------------------------------------------------
	if not has_navigation_target or arrived:
		edge_pointer.visible = false
		return
	
	var vp_size := get_viewport().get_visible_rect().size
	var screen_center := vp_size * 0.5
	var target_screen_pos := camera.unproject_position(current_destination + Vector3(0, 1.2, 0))
	var is_behind := camera.is_position_behind(current_destination)
	
	var margin := 70.0
	var bounds_min := Vector2(margin, margin)
	var bounds_max := vp_size - Vector2(margin + 180, margin + 40)
	
	var is_on_screen := (
		not is_behind
		and target_screen_pos.x >= bounds_min.x
		and target_screen_pos.x <= bounds_max.x
		and target_screen_pos.y >= bounds_min.y
		and target_screen_pos.y <= bounds_max.y
	)
	
	edge_pointer.visible = true
	pointer_text.text = "%s (%dm)" % [current_title, int(round(dist))]
	
	if is_on_screen:
		edge_pointer.position = edge_pointer.position.lerp(target_screen_pos - Vector2(90, 48), 1.0 - exp(-15.0 * delta))
		arrow_label.text = "▼"
		arrow_label.rotation = 0.0
	else:
		var pointer_pos := screen_center + screen_dir * (minf(vp_size.x, vp_size.y) * 0.40)
		pointer_pos.x = clampf(pointer_pos.x, bounds_min.x, bounds_max.x)
		pointer_pos.y = clampf(pointer_pos.y, bounds_min.y, bounds_max.y)
		edge_pointer.position = edge_pointer.position.lerp(pointer_pos, 1.0 - exp(-15.0 * delta))
		arrow_label.text = "▲"
		arrow_label.rotation = smoothed_angle + PI / 2.0
	
	if is_instance_valid(arrow_icon):
		arrow_icon.queue_redraw()
