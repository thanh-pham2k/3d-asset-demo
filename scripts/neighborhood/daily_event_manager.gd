class_name DailyEventManager
extends Node

## Lightweight data-driven Daily Event system for Couple Chaos 3D.
## Selects one neighborhood event per day, persists it across saves without rerolling,
## provides central gameplay modifiers, and displays a dismissible morning news panel.

signal event_changed(event_data: Dictionary)

const EVENT_CATALOG: Dictionary = {
	"normal_day": {
		"id": "normal_day",
		"title": "Ngày Bình Thường",
		"icon": "☀️",
		"description": "Mọi hoạt động khu phố diễn ra nhịp nhàng như thường lệ.",
		"effect_text": "Giá cả & lượng khách tiêu chuẩn.",
		"garage_arrival_mult": 1.0,
		"hutieu_arrival_mult": 1.0,
		"garage_tip_mult": 1.0,
		"hutieu_tip_mult": 1.0,
		"market_sell_mult": 1.0,
		"product_discounts": {},
		"vip_chance": 0.08
	},
	"beautiful_weather": {
		"id": "beautiful_weather",
		"title": "Trời Đẹp Nắng Ấm",
		"icon": "🌤️",
		"description": "Nắng nhẹ chan hòa, thực khách ghé quán hủ tiếu vui vẻ và hào phóng hơn.",
		"effect_text": "Tiền tip Quán Hủ Tiếu +20% · Thời tiết nắng đẹp.",
		"garage_arrival_mult": 1.0,
		"hutieu_arrival_mult": 1.0,
		"garage_tip_mult": 1.0,
		"hutieu_tip_mult": 1.20,
		"market_sell_mult": 1.0,
		"product_discounts": {},
		"vip_chance": 0.10
	},
	"motorcycle_rush": {
		"id": "motorcycle_rush",
		"title": "Hôm Nay Xe Hỏng Nhiều!",
		"icon": "🏍️",
		"description": "Đường phố đông đúc khiến tiệm sửa xe tấp nập từ sáng.",
		"effect_text": "Tiệm sửa xe đông khách (x2) · Repair Kit giảm giá 20%.",
		"garage_arrival_mult": 2.0,
		"hutieu_arrival_mult": 1.0,
		"garage_tip_mult": 1.0,
		"hutieu_tip_mult": 1.0,
		"market_sell_mult": 1.0,
		"product_discounts": { "tool_repair_kit": 0.20 },
		"vip_chance": 0.08
	},
	"weekend_market": {
		"id": "weekend_market",
		"title": "Phiên Chợ Cuối Tuần",
		"icon": "🧺",
		"description": "Chợ dân sinh nhộn nhịp, thương lái thu mua rau củ tươi với giá cao.",
		"effect_text": "Giá bán nông sản thu hoạch x1.5.",
		"garage_arrival_mult": 1.0,
		"hutieu_arrival_mult": 1.0,
		"garage_tip_mult": 1.0,
		"hutieu_tip_mult": 1.0,
		"market_sell_mult": 1.5,
		"product_discounts": {},
		"vip_chance": 0.10
	},
	"vip_visit": {
		"id": "vip_visit",
		"title": "Khách VIP Ghé Thăm",
		"icon": "🌟",
		"description": "Nhiều vị khách đặc biệt ghé khu phố trải nghiệm dịch vụ chất lượng.",
		"effect_text": "Tăng tỷ lệ xuất hiện khách VIP (+50% thưởng đơn VIP).",
		"garage_arrival_mult": 1.0,
		"hutieu_arrival_mult": 1.0,
		"garage_tip_mult": 1.0,
		"hutieu_tip_mult": 1.0,
		"market_sell_mult": 1.0,
		"product_discounts": {},
		"vip_chance": 0.45
	},
	"quiet_neighborhood": {
		"id": "quiet_neighborhood",
		"title": "Khu Phố Yên Bình",
		"icon": "🌿",
		"description": "Phố xá thưa khách hơn, rất hợp để chăm vườn, mua sắm và trang trí nhà.",
		"effect_text": "Khách ít hơn (x0.65) · Thoải mái làm vườn & thư giãn tại nhà.",
		"garage_arrival_mult": 0.65,
		"hutieu_arrival_mult": 0.65,
		"garage_tip_mult": 1.0,
		"hutieu_tip_mult": 1.0,
		"market_sell_mult": 1.0,
		"product_discounts": {},
		"vip_chance": 0.08
	}
}

var current_day: int = 1
var current_event_id: String = "normal_day"
var _initialized_from_save: bool = false

# UI elements: Morning announcement modal + subtle HUD status badge
var news_layer: CanvasLayer
var news_panel: PanelContainer
var news_header_label: Label
var news_title_label: Label
var news_desc_label: Label
var news_effect_label: Label
var news_close_btn: Button
var is_news_open: bool = false

var badge_layer: CanvasLayer
var badge_label: Label

func _ready() -> void:
	add_to_group("daily_event_manager")
	_build_ui()
	call_deferred("_discover_dependencies")

func _discover_dependencies() -> void:
	var econ := get_tree().get_first_node_in_group("economy_manager") as EconomyManager
	if is_instance_valid(econ):
		var saved := EconomySaveSystem.load_daily_event_data(econ.save_file_path)
		if not saved.is_empty():
			apply_save_data(saved)

	var daily_loop := get_tree().get_first_node_in_group("daily_loop_manager") as DailyLoopManager
	if is_instance_valid(daily_loop):
		if not daily_loop.day_started.is_connected(_on_day_started):
			daily_loop.day_started.connect(_on_day_started)
		if not daily_loop.day_advanced.is_connected(_on_day_started):
			daily_loop.day_advanced.connect(_on_day_started)
		var target_day := daily_loop.current_day
		if not _initialized_from_save or current_day != target_day:
			select_event_for_day(target_day, false)

	var time_mgr := get_tree().get_first_node_in_group("time_manager") as NeighborhoodTimeManager
	if is_instance_valid(time_mgr):
		if not time_mgr.hour_ticked.is_connected(_on_hour_ticked):
			time_mgr.hour_ticked.connect(_on_hour_ticked)

	_refresh_badge()

func select_event_for_day(day: int, show_panel: bool = true) -> Dictionary:
	var target_day := maxi(1, day)
	if _initialized_from_save and current_day == target_day and EVENT_CATALOG.has(current_event_id):
		_refresh_badge()
		return get_current_event()

	var keys := EVENT_CATALOG.keys()
	var prev_id := current_event_id
	if target_day == 1 and not _initialized_from_save:
		current_event_id = "normal_day"
	else:
		var candidates: Array[String] = []
		for k in keys:
			if String(k) != prev_id:
				candidates.append(String(k))
		if candidates.is_empty():
			current_event_id = "normal_day"
		else:
			current_event_id = candidates[randi() % candidates.size()]

	current_day = target_day
	_initialized_from_save = true
	var ev := get_current_event()
	event_changed.emit(ev)
	_refresh_badge()
	if show_panel:
		show_morning_news()
	return ev

func _on_day_started(new_day: int) -> void:
	if new_day == current_day and _initialized_from_save:
		return
	_initialized_from_save = false
	select_event_for_day(new_day, true)

func _on_hour_ticked(_hour: int) -> void:
	_refresh_badge()

func get_current_event() -> Dictionary:
	return EVENT_CATALOG.get(current_event_id, EVENT_CATALOG["normal_day"])

# -----------------------------------------------------------------
# Central Event Modifiers (single source of truth, non-stacking)
# -----------------------------------------------------------------
func get_arrival_multiplier(shop_id: String) -> float:
	var ev := get_current_event()
	if shop_id == "garage":
		return float(ev.get("garage_arrival_mult", 1.0))
	elif shop_id == "hutieu":
		return float(ev.get("hutieu_arrival_mult", 1.0))
	return 1.0

func get_tips_multiplier(shop_id: String) -> float:
	var ev := get_current_event()
	if shop_id == "garage":
		return float(ev.get("garage_tip_mult", 1.0))
	elif shop_id == "hutieu":
		return float(ev.get("hutieu_tip_mult", 1.0))
	return 1.0

func get_market_sell_multiplier() -> float:
	return float(get_current_event().get("market_sell_mult", 1.0))

func get_discount_percent(product_id: String) -> int:
	var discounts: Dictionary = get_current_event().get("product_discounts", {})
	if discounts.has(product_id):
		return int(round(float(discounts[product_id]) * 100.0))
	return 0

func get_discounted_price(product_id: String, base_price: int) -> int:
	var discounts: Dictionary = get_current_event().get("product_discounts", {})
	if discounts.has(product_id):
		var rate := clampf(float(discounts[product_id]), 0.0, 0.9)
		return maxi(1, int(round(float(base_price) * (1.0 - rate))))
	return base_price

func get_vip_chance() -> float:
	return float(get_current_event().get("vip_chance", 0.08))

# -----------------------------------------------------------------
# Persistence
# -----------------------------------------------------------------
func get_save_data() -> Dictionary:
	return {
		"day": current_day,
		"event_id": current_event_id
	}

func apply_save_data(data: Dictionary) -> void:
	if data.is_empty():
		return
	var saved_day := int(data.get("day", 0))
	var saved_id := String(data.get("event_id", ""))
	if saved_day >= 1 and EVENT_CATALOG.has(saved_id):
		current_day = saved_day
		current_event_id = saved_id
		_initialized_from_save = true
		event_changed.emit(get_current_event())
		_refresh_badge()

# -----------------------------------------------------------------
# UI: Morning Neighborhood News + Subtle Event/Peak Badge
# -----------------------------------------------------------------
func _build_ui() -> void:
	badge_layer = CanvasLayer.new()
	badge_layer.name = "DailyEventBadgeHUD"
	badge_layer.layer = 6
	add_child(badge_layer)

	var top_center := CenterContainer.new()
	top_center.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_center.offset_top = 10
	top_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_layer.add_child(top_center)

	var badge_panel := PanelContainer.new()
	badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb_b := StyleBoxFlat.new()
	sb_b.bg_color = Color("161c24", 0.78)
	sb_b.set_corner_radius_all(12)
	sb_b.border_width_left = 1
	sb_b.border_width_right = 1
	sb_b.border_width_top = 1
	sb_b.border_width_bottom = 1
	sb_b.border_color = Color("80d8ff", 0.65)
	sb_b.content_margin_left = 12
	sb_b.content_margin_right = 12
	sb_b.content_margin_top = 5
	sb_b.content_margin_bottom = 5
	badge_panel.add_theme_stylebox_override("panel", sb_b)
	top_center.add_child(badge_panel)

	badge_label = Label.new()
	badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_label.add_theme_font_size_override("font_size", 12)
	badge_label.add_theme_color_override("font_color", Color("e1f5fe"))
	badge_panel.add_child(badge_label)

	# Morning Announcement Modal
	news_layer = CanvasLayer.new()
	news_layer.name = "MorningNewsLayer"
	news_layer.layer = 98
	news_layer.visible = false
	add_child(news_layer)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.06, 0.08, 0.11, 0.65)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	news_layer.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	news_layer.add_child(center)

	news_panel = PanelContainer.new()
	news_panel.custom_minimum_size = Vector2(440, 220)
	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = Color("1e262f", 0.98)
	sb_n.set_corner_radius_all(14)
	sb_n.set_border_width_all(2)
	sb_n.border_color = Color("ffd54f")
	sb_n.content_margin_left = 24
	sb_n.content_margin_right = 24
	sb_n.content_margin_top = 18
	sb_n.content_margin_bottom = 18
	news_panel.add_theme_stylebox_override("panel", sb_n)
	center.add_child(news_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	news_panel.add_child(vbox)

	news_header_label = Label.new()
	news_header_label.text = "📰 Tin khu phố — Ngày 1"
	news_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	news_header_label.add_theme_font_size_override("font_size", 15)
	news_header_label.add_theme_color_override("font_color", Color("ffd54f"))
	vbox.add_child(news_header_label)

	news_title_label = Label.new()
	news_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	news_title_label.add_theme_font_size_override("font_size", 20)
	news_title_label.add_theme_color_override("font_color", Color("ffffff"))
	vbox.add_child(news_title_label)

	news_desc_label = Label.new()
	news_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	news_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	news_desc_label.add_theme_font_size_override("font_size", 13)
	news_desc_label.add_theme_color_override("font_color", Color("cfd8dc"))
	vbox.add_child(news_desc_label)

	news_effect_label = Label.new()
	news_effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	news_effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	news_effect_label.add_theme_font_size_override("font_size", 13)
	news_effect_label.add_theme_color_override("font_color", Color("69f0ae"))
	vbox.add_child(news_effect_label)

	news_close_btn = Button.new()
	news_close_btn.text = "Đã hiểu [E / Esc]"
	news_close_btn.custom_minimum_size = Vector2(0, 38)
	news_close_btn.pressed.connect(dismiss_morning_news)
	vbox.add_child(news_close_btn)

func show_morning_news() -> void:
	if not is_instance_valid(news_layer):
		return
	var ev := get_current_event()
	news_header_label.text = "📰 Tin khu phố — Ngày %d" % current_day
	news_title_label.text = "%s %s" % [ev.get("icon", "☀️"), ev.get("title", "Ngày Bình Thường")]
	news_desc_label.text = String(ev.get("description", ""))
	news_effect_label.text = "✨ Hiệu ứng: %s" % String(ev.get("effect_text", ""))
	news_layer.visible = true
	is_news_open = true
	if is_instance_valid(news_close_btn):
		news_close_btn.grab_focus()

func dismiss_morning_news() -> void:
	if not is_instance_valid(news_layer):
		return
	news_layer.visible = false
	is_news_open = false

func _unhandled_input(event: InputEvent) -> void:
	if not is_news_open:
		return
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_E or event.keycode == KEY_ESCAPE or event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			dismiss_morning_news()
			get_viewport().set_input_as_handled()

func _refresh_badge() -> void:
	if not is_instance_valid(badge_label):
		return
	var ev := get_current_event()
	var peak_tag := ""
	var time_mgr := get_tree().get_first_node_in_group("time_manager") as NeighborhoodTimeManager if is_inside_tree() else null
	if is_instance_valid(time_mgr):
		var h := time_mgr.current_hour
		if (h >= 7.0 and h < 9.0) or (h >= 17.0 and h < 19.0):
			peak_tag = " · ⚡ Giờ cao điểm"
		elif h >= 14.0 and h < 16.0:
			peak_tag = " · ☕ Chiều thư thả"
	badge_label.text = "%s Ngày %d: %s%s" % [ev.get("icon", "☀️"), current_day, ev.get("title", "Ngày Bình Thường"), peak_tag]
