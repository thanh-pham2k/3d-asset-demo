class_name InteractiveMinimap
extends CanvasLayer

## Interactive Minimap for Couple Chaos.
## Provides a compact real-time HUD minimap (bottom-right) and an expanded full town map modal.
## Synchronized with 3D world coordinates, player facing, and WorkplaceGuidance objectives.
## Shortcut: Press [M] or click HUD minimap to open/close. [Esc] also closes.

var player: CharacterBody3D
var guidance: Node

var is_expanded: bool = false
var anim_pulse: float = 0.0

# HUD Minimap elements
var hud_container: PanelContainer
var hud_drawer: Control
var hud_title: Label

# Expanded Map Modal elements
var modal_backdrop: ColorRect
var modal_window: PanelContainer
var modal_drawer: Control
var modal_objective_label: Label
var modal_coords_label: Label
var close_btn: Button

# Town Landmark Data: [id, title, world_pos, color, icon]
var landmarks := [
	{
		"id": "house",
		"title": "Nhà Chung",
		"pos": Vector3(-45, 0, 84),
		"color": Color("ffb74d"), # Warm amber
		"icon": "🏠",
		"desc": "Nhà của Boy & Girl (Phòng khách, giường ngủ, bếp)"
	},
	{
		"id": "garage",
		"title": "Tiệm Sửa Xe Chú Ba",
		"pos": Vector3(-63, 0, -15),
		"color": Color("4fc3f7"), # Sky blue
		"icon": "🛵",
		"desc": "Chòi sửa xe máy chú Ba (Khoang sửa, bơm hơi, bàn thợ)"
	},
	{
		"id": "hutieu",
		"title": "Quán Hủ Tiếu Cô Bảy",
		"pos": Vector3(-50, 0, -20),
		"color": Color("81c784"), # Light green
		"icon": "🍜",
		"desc": "Quán ăn gia đình (Nồi trụng, nước lèo, bàn ghế)"
	},
	{
		"id": "food_street",
		"title": "Phố Ẩm Thực",
		"pos": Vector3(-101, 0, 21),
		"color": Color("ff8a65"), # Coral
		"icon": "🍱",
		"desc": "Quán cà phê, bánh mì, nước mía & tiệm tạp hóa"
	},
	{
		"id": "market",
		"title": "Chợ Dân Sinh",
		"pos": Vector3(42, 0, -28),
		"color": Color("ba68c8"), # Violet
		"icon": "🥬",
		"desc": "Khu sạp rau củ, trái cây, thịt cá tươi sống"
	},
	{
		"id": "school",
		"title": "Trường Học & Công Viên",
		"pos": Vector3(40, 0, 50),
		"color": Color("4dd0e1"), # Cyan
		"icon": "🏫",
		"desc": "Cổng trường, hoa viên & khu vui chơi ngoài trời"
	},
	{
		"id": "furniture",
		"title": "Tiệm Nội Thất",
		"pos": Vector3(105, 0, -18),
		"color": Color("dce775"), # Lime
		"icon": "🛋️",
		"desc": "Cửa hàng mua sắm đồ trang trí & nâng cấp nhà"
	}
]

func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hud_minimap()
	_build_expanded_map()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			toggle_expanded_map(!is_expanded)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and is_expanded:
			toggle_expanded_map(false)
			get_viewport().set_input_as_handled()

func toggle_expanded_map(enable: Variant = null) -> void:
	if enable == null:
		is_expanded = !is_expanded
	else:
		is_expanded = bool(enable)
	modal_backdrop.visible = is_expanded
	if is_instance_valid(modal_window):
		modal_window.visible = is_expanded
	if is_expanded:
		_update_expanded_labels()

func close_expanded_map() -> void:
	toggle_expanded_map(false)

func _process(delta: float) -> void:
	anim_pulse += delta * 4.0
	
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("players") as CharacterBody3D
	if not is_instance_valid(guidance):
		guidance = get_tree().root.find_child("WorkplaceGuidance", true, false)
	
	if is_instance_valid(hud_drawer):
		hud_drawer.queue_redraw()
	if is_expanded and is_instance_valid(modal_drawer):
		modal_drawer.queue_redraw()
		_update_expanded_labels()

func _build_hud_minimap() -> void:
	# Bottom-Right compact circular/rounded HUD Minimap
	hud_container = PanelContainer.new()
	hud_container.name = "HUDMinimap"
	hud_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hud_container.offset_left = -210
	hud_container.offset_right = -14
	hud_container.offset_top = -210
	hud_container.offset_bottom = -14
	hud_container.mouse_filter = Control.MOUSE_FILTER_STOP
	hud_container.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hud_container.gui_input.connect(_on_hud_minimap_gui_input)
	add_child(hud_container)
	
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("14181f", 0.90)
	sb.set_corner_radius_all(18)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_color = Color("69f0ae", 0.85)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 8
	hud_container.add_theme_stylebox_override("panel", sb)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	hud_container.add_child(vbox)
	
	# Header title & click hint
	hud_title = Label.new()
	hud_title.text = "🗺️ BẢN ĐỒ [M]"
	hud_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_title.add_theme_font_size_override("font_size", 12)
	hud_title.add_theme_color_override("font_color", Color("ffd54f"))
	vbox.add_child(hud_title)
	
	# Custom Draw Canvas
	hud_drawer = Control.new()
	hud_drawer.custom_minimum_size = Vector2(180, 160)
	hud_drawer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hud_drawer.clip_contents = true
	hud_drawer.draw.connect(_draw_hud_minimap)
	vbox.add_child(hud_drawer)

func _on_hud_minimap_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toggle_expanded_map(true)

func _build_expanded_map() -> void:
	# Fullscreen translucent dark veil
	modal_backdrop = ColorRect.new()
	modal_backdrop.name = "ExpandedMapBackdrop"
	modal_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_backdrop.color = Color(0.05, 0.07, 0.10, 0.85)
	modal_backdrop.visible = false
	modal_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_backdrop.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			# Click outside modal closes it
			var m_pos = ev.position
			if not modal_window.get_global_rect().has_point(m_pos):
				toggle_expanded_map(false)
	)
	add_child(modal_backdrop)
	
	# Centered Modal Window
	modal_window = PanelContainer.new()
	modal_window.name = "ModalWindow"
	modal_window.set_anchors_preset(Control.PRESET_CENTER)
	modal_window.offset_left = -440
	modal_window.offset_right = 440
	modal_window.offset_top = -300
	modal_window.offset_bottom = 300
	modal_backdrop.add_child(modal_window)
	
	var sb_win := StyleBoxFlat.new()
	sb_win.bg_color = Color("1a202c", 0.98)
	sb_win.set_corner_radius_all(14)
	sb_win.border_width_left = 2
	sb_win.border_width_right = 2
	sb_win.border_width_top = 2
	sb_win.border_width_bottom = 2
	sb_win.border_color = Color("80d8ff", 0.9)
	sb_win.shadow_color = Color(0, 0, 0, 0.6)
	sb_win.shadow_size = 16
	modal_window.add_theme_stylebox_override("panel", sb_win)
	
	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 10)
	modal_window.add_child(outer_vbox)
	
	# Header bar: Title, Objective, and Close Button
	var header := HBoxContainer.new()
	outer_vbox.add_child(header)
	
	var title_lbl := Label.new()
	title_lbl.text = "🗺️ BẢN ĐỒ TOÀN THÀNH PHỐ — COUPLE CHAOS"
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", Color("ffd54f"))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_lbl)
	
	modal_coords_label = Label.new()
	modal_coords_label.text = "Vị trí: (-45, 84)"
	modal_coords_label.add_theme_font_size_override("font_size", 13)
	modal_coords_label.add_theme_color_override("font_color", Color("80deea"))
	header.add_child(modal_coords_label)
	
	close_btn = Button.new()
	close_btn.text = " ✕ Đóng [Esc] "
	close_btn.pressed.connect(func(): toggle_expanded_map(false))
	header.add_child(close_btn)
	
	# Middle layout: Map Canvas (Left 600px) + Legend Panel (Right 240px)
	var content_hbox := HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 14)
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(content_hbox)
	
	# Map Canvas
	var map_frame := PanelContainer.new()
	map_frame.custom_minimum_size = Vector2(580, 500)
	map_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb_frame := StyleBoxFlat.new()
	sb_frame.bg_color = Color("232c38")
	sb_frame.set_corner_radius_all(10)
	sb_frame.border_width_left = 1
	sb_frame.border_width_right = 1
	sb_frame.border_width_top = 1
	sb_frame.border_width_bottom = 1
	sb_frame.border_color = Color("37474f")
	map_frame.add_theme_stylebox_override("panel", sb_frame)
	content_hbox.add_child(map_frame)
	
	modal_drawer = Control.new()
	modal_drawer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_drawer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	modal_drawer.draw.connect(_draw_expanded_map)
	map_frame.add_child(modal_drawer)
	
	# Right Sidebar: Objective status + Landmark Legend
	var legend_vbox := VBoxContainer.new()
	legend_vbox.custom_minimum_size = Vector2(250, 0)
	legend_vbox.add_theme_constant_override("separation", 8)
	content_hbox.add_child(legend_vbox)
	
	var obj_hdr := Label.new()
	obj_hdr.text = "🎯 MỤC TIÊU HIỆN TẠI"
	obj_hdr.add_theme_font_size_override("font_size", 13)
	obj_hdr.add_theme_color_override("font_color", Color("ffd54f"))
	legend_vbox.add_child(obj_hdr)
	
	modal_objective_label = Label.new()
	modal_objective_label.text = "Đang xác định mục tiêu..."
	modal_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_objective_label.add_theme_font_size_override("font_size", 12)
	modal_objective_label.add_theme_color_override("font_color", Color("b9f6ca"))
	legend_vbox.add_child(modal_objective_label)
	
	var sep := HSeparator.new()
	legend_vbox.add_child(sep)
	
	var leg_hdr := Label.new()
	leg_hdr.text = "📍 ĐỊA ĐIỂM QUAN TRỌNG"
	leg_hdr.add_theme_font_size_override("font_size", 13)
	leg_hdr.add_theme_color_override("font_color", Color("e0e0e0"))
	legend_vbox.add_child(leg_hdr)
	
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	legend_vbox.add_child(scroll)
	
	var list_box := VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 6)
	scroll.add_child(list_box)
	
	for lm in landmarks:
		var item_hbox := HBoxContainer.new()
		item_hbox.add_theme_constant_override("separation", 8)
		
		var icon_lbl := Label.new()
		icon_lbl.text = lm["icon"]
		item_hbox.add_child(icon_lbl)
		
		var info_vbox := VBoxContainer.new()
		info_vbox.add_theme_constant_override("separation", 1)
		
		var name_lbl := Label.new()
		name_lbl.text = lm["title"]
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", lm["color"])
		info_vbox.add_child(name_lbl)
		
		var desc_lbl := Label.new()
		desc_lbl.text = lm["desc"]
		desc_lbl.add_theme_font_size_override("font_size", 10)
		desc_lbl.add_theme_color_override("font_color", Color("90a4ae"))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_vbox.add_child(desc_lbl)
		
		item_hbox.add_child(info_vbox)
		list_box.add_child(item_hbox)

func _update_expanded_labels() -> void:
	if not is_instance_valid(player): return
	var p_pos = player.global_position
	modal_coords_label.text = "Tọa độ: (%.1f, %.1f)" % [p_pos.x, p_pos.z]
	
	if is_instance_valid(guidance):
		var target_title: String = guidance.get("current_title") if "current_title" in guidance else "Khám phá thành phố"
		var target_hint: String = guidance.get("current_hint") if "current_hint" in guidance else ""
		var target_dest: Vector3 = guidance.get("current_destination") if "current_destination" in guidance else Vector3.ZERO
		var dist := int(p_pos.distance_to(target_dest))
		modal_objective_label.text = "⭐ %s\nKhoảng cách: %dm\n%s" % [target_title, dist, target_hint]
	else:
		modal_objective_label.text = "Tự do khám phá khu phố"

# ==============================================================================
# DRAWING LOGIC (COORDINATE TRANSFORMATION)
# ==============================================================================

# World terrain bounds: 250m x 250m (X: [-125, +125], Z: [-125, +125])
func _world_to_normalized(world_pos: Vector3) -> Vector2:
	var nx := clampf((world_pos.x + 125.0) / 250.0, 0.0, 1.0)
	var nz := clampf((world_pos.z + 125.0) / 250.0, 0.0, 1.0)
	return Vector2(nx, nz)

func _world_to_canvas(world_pos: Vector3, canvas_size: Vector2) -> Vector2:
	var n := _world_to_normalized(world_pos)
	var margin := 16.0
	var usable := canvas_size - Vector2(margin * 2.0, margin * 2.0)
	return Vector2(margin + n.x * usable.x, margin + n.y * usable.y)

func _draw_hud_minimap() -> void:
	var sz := hud_drawer.size
	var center := sz * 0.5
	var radius := minf(sz.x, sz.y) * 0.46
	
	# Dark terrain circle
	hud_drawer.draw_circle(center, radius, Color("1f2732"))
	
	var p_pos := player.global_position if is_instance_valid(player) else Vector3(-45, 0, 84)
	var p_rot_y := player.rotation.y if is_instance_valid(player) else 0.0
	
	# Scale factor: 1 meter in world = scale_px in minimap (view radius ~65m)
	var scale_px: float = radius / 65.0
	
	# Helper to project world coordinate relative to player in HUD minimap
	var to_hud_point = func(pos: Vector3) -> Vector2:
		var delta_x := (pos.x - p_pos.x) * scale_px
		var delta_z := (pos.z - p_pos.z) * scale_px
		return center + Vector2(delta_x, delta_z)
	
	# Draw major roads within radar
	var road_color := Color("455a64", 0.8)
	# East-West Boulevard (Z=0, width 12m)
	var b_y: float = to_hud_point.call(Vector3(p_pos.x, 0, 0)).y
	hud_drawer.draw_rect(Rect2(0, b_y - 6.0 * scale_px, sz.x, 12.0 * scale_px), road_color)
	# North-South Streets (X=-80, 0, 80, width 8m)
	for x_street in [-80.0, 0.0, 80.0]:
		var s_x: float = to_hud_point.call(Vector3(x_street, 0, p_pos.z)).x
		hud_drawer.draw_rect(Rect2(s_x - 4.0 * scale_px, 0, 8.0 * scale_px, sz.y), road_color)
	
	# Residential road (Z=50)
	var res_y: float = to_hud_point.call(Vector3(p_pos.x, 0, 50)).y
	hud_drawer.draw_rect(Rect2(0, res_y - 3.5 * scale_px, sz.x, 7.0 * scale_px), road_color)
	
	# Draw landmarks
	for lm in landmarks:
		var pt: Vector2 = to_hud_point.call(lm["pos"])
		var to_pt := pt - center
		var dist := to_pt.length()
		
		if dist <= radius - 8.0:
			# Within circular radar: draw dot & label
			hud_drawer.draw_circle(pt, 5.0, lm["color"])
			hud_drawer.draw_string(ThemeDB.fallback_font, pt + Vector2(7, 4), lm["title"].left(6), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("e0e0e0"))
		else:
			# Clamped along rim
			var rim_pt := center + to_pt.normalized() * (radius - 7.0)
			hud_drawer.draw_circle(rim_pt, 3.5, lm["color"])
	
	# Draw Workplace Guidance Objective (if available)
	if is_instance_valid(guidance):
		var target_dest: Vector3 = guidance.get("current_destination") if "current_destination" in guidance else Vector3.ZERO
		var target_pt: Vector2 = to_hud_point.call(target_dest)
		var to_target := target_pt - center
		var t_dist := to_target.length()
		
		var pulse := 1.0 + 0.25 * sin(anim_pulse)
		if t_dist <= radius - 10.0:
			hud_drawer.draw_circle(target_pt, 7.0 * pulse, Color("ffd54f", 0.5))
			hud_drawer.draw_circle(target_pt, 4.0, Color("ffd54f"))
		else:
			var rim_target := center + to_target.normalized() * (radius - 8.0)
			hud_drawer.draw_circle(rim_target, 5.0 * pulse, Color("ffd54f"))
	
	# Draw Player Arrow in Center
	# Note: in Godot 3D, facing -Z is forward. Screen Y is downwards.
	var heading_angle := p_rot_y + PI / 2.0
	var fwd := Vector2(cos(heading_angle), sin(heading_angle))
	var right := Vector2(-fwd.y, fwd.x)
	
	var p_tip := center + fwd * 8.0
	var p_left := center - fwd * 6.0 + right * 5.0
	var p_right := center - fwd * 6.0 - right * 5.0
	
	hud_drawer.draw_colored_polygon(PackedVector2Array([p_tip, p_left, center, p_right]), Color("00e5ff"))
	hud_drawer.draw_circle(center, 2.0, Color.WHITE)
	
	# Outer border ring
	hud_drawer.draw_arc(center, radius - 1, 0, TAU, 36, Color("69f0ae", 0.9), 2.0)

func _draw_expanded_map() -> void:
	var sz := modal_drawer.size
	
	# 1. Background Grass/City terrain
	modal_drawer.draw_rect(Rect2(Vector2.ZERO, sz), Color("223026"))
	
	# 2. Draw major street network
	var road_paint := Color("37474f")
	var line_paint := Color("ffd54f", 0.7)
	
	# East-West Boulevard (Z = 0, width = 12m)
	var b_top := _world_to_canvas(Vector3(-125, 0, -6), sz).y
	var b_bot := _world_to_canvas(Vector3(-125, 0, 6), sz).y
	modal_drawer.draw_rect(Rect2(0, b_top, sz.x, b_bot - b_top), road_paint)
	# Boulevard yellow center dashed line
	var b_mid := _world_to_canvas(Vector3(-125, 0, 0), sz).y
	modal_drawer.draw_line(Vector2(0, b_mid), Vector2(sz.x, b_mid), line_paint, 2.0)
	
	# North-South Streets (X = -80, 0, 80, width = 8m)
	for x_pos in [-80.0, 0.0, 80.0]:
		var s_left := _world_to_canvas(Vector3(x_pos - 4, 0, -125), sz).x
		var s_right := _world_to_canvas(Vector3(x_pos + 4, 0, -125), sz).x
		modal_drawer.draw_rect(Rect2(s_left, 0, s_right - s_left, sz.y), road_paint)
		var s_mid := _world_to_canvas(Vector3(x_pos, 0, -125), sz).x
		modal_drawer.draw_line(Vector2(s_mid, 0), Vector2(s_mid, sz.y), line_paint, 1.5)
	
	# Residential local road (Z = 50, connects house to X = -80)
	var res_top := _world_to_canvas(Vector3(-80, 0, 47), sz).y
	var res_bot := _world_to_canvas(Vector3(-80, 0, 53), sz).y
	var res_x_start := _world_to_canvas(Vector3(-80, 0, 50), sz).x
	var res_x_end := _world_to_canvas(Vector3(-40, 0, 50), sz).x
	modal_drawer.draw_rect(Rect2(res_x_start, res_top, res_x_end - res_x_start, res_bot - res_top), road_paint)
	
	# House driveway (X = -45, Z = 50 to Z = 84)
	var d_left := _world_to_canvas(Vector3(-47.5, 0, 50), sz).x
	var d_right := _world_to_canvas(Vector3(-42.5, 0, 50), sz).x
	var d_y_start := _world_to_canvas(Vector3(-45, 0, 50), sz).y
	var d_y_end := _world_to_canvas(Vector3(-45, 0, 84), sz).y
	modal_drawer.draw_rect(Rect2(d_left, d_y_start, d_right - d_left, d_y_end - d_y_start), road_paint)
	
	# Garage driveway (X = -63, Z = 0 to Z = -15)
	var g_left := _world_to_canvas(Vector3(-65.5, 0, 0), sz).x
	var g_right := _world_to_canvas(Vector3(-60.5, 0, 0), sz).x
	var g_y_start := _world_to_canvas(Vector3(-63, 0, -15), sz).y
	var g_y_end := _world_to_canvas(Vector3(-63, 0, 0), sz).y
	modal_drawer.draw_rect(Rect2(g_left, g_y_start, g_right - g_left, g_y_end - g_y_start), road_paint)
	
	# 3. Draw All Landmark Icons & Badges
	for lm in landmarks:
		var pt := _world_to_canvas(lm["pos"], sz)
		
		# Pill badge
		modal_drawer.draw_circle(pt, 9.0, lm["color"])
		modal_drawer.draw_circle(pt, 6.0, Color("1a1a1a"))
		modal_drawer.draw_circle(pt, 3.5, lm["color"])
		
		# Text label with subtle dark shadow
		var label_text: String = "%s %s" % [lm["icon"], lm["title"]]
		var text_pos := pt + Vector2(-30, -14)
		modal_drawer.draw_string(ThemeDB.fallback_font, text_pos + Vector2(1, 1), label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color("000000", 0.9))
		modal_drawer.draw_string(ThemeDB.fallback_font, text_pos, label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color("ffffff"))
	
	# 4. Highlight Active Objective Target
	if is_instance_valid(guidance):
		var target_dest: Vector3 = guidance.get("current_destination") if "current_destination" in guidance else Vector3.ZERO
		var target_title: String = guidance.get("current_title") if "current_title" in guidance else "Mục tiêu"
		var t_pt := _world_to_canvas(target_dest, sz)
		
		var pulse := 1.0 + 0.3 * sin(anim_pulse)
		modal_drawer.draw_arc(t_pt, 18.0 * pulse, 0, TAU, 32, Color("ffd54f", 0.85), 3.0)
		modal_drawer.draw_circle(t_pt, 6.0, Color("ffd54f"))
		
		var obj_text := "★ " + target_title
		modal_drawer.draw_string(ThemeDB.fallback_font, t_pt + Vector2(-40, 24), obj_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color("ffd54f"))
	
	# 5. Draw Player Marker
	if is_instance_valid(player):
		var p_pos := player.global_position
		var p_pt := _world_to_canvas(p_pos, sz)
		var p_rot_y := player.rotation.y
		
		# Pulsing glow
		modal_drawer.draw_circle(p_pt, 10.0, Color("00e5ff", 0.35))
		
		var heading_angle := p_rot_y + PI / 2.0
		var fwd := Vector2(cos(heading_angle), sin(heading_angle))
		var right := Vector2(-fwd.y, fwd.x)
		
		var p_tip := p_pt + fwd * 12.0
		var p_left := p_pt - fwd * 8.0 + right * 7.0
		var p_right := p_pt - fwd * 8.0 - right * 7.0
		
		modal_drawer.draw_colored_polygon(PackedVector2Array([p_tip, p_left, p_pt, p_right]), Color("00e5ff"))
		modal_drawer.draw_circle(p_pt, 3.0, Color.WHITE)
		modal_drawer.draw_string(ThemeDB.fallback_font, p_pt + Vector2(-20, 20), "Bạn ở đây", HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color("00e5ff"))
