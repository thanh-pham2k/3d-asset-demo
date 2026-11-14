extends Control
## ASCII Presentation layer for Phase 3 (Orders, Economy & Progression — Tabbed ASCII UI).
## Strictly reads WorldState and invokes WorldState methods.

enum Tab { FARM, ORDERS, PRODUCTION, RESTAURANT, AUTOMATION, HOME, PETS, GARAGE, NEIGHBORHOOD, GOALS, INVENTORY, UPGRADES }

var world: WorldState
var active_tab: Tab = Tab.FARM

var status_label: Label
var clock_label: Label
var next_goal_label: Label

var tab_buttons: Dictionary = {}
var tab_containers: Dictionary = {}

# Farm tab widgets
var crop_buttons: Dictionary = {}
var plot_buttons: Array[Button] = []

# Orders tab widgets
var order_slot_labels: Array[Label] = []
var order_deliver_buttons: Array[Button] = []
var order_skip_buttons: Array[Button] = []

# Production tab widgets
var prod_recipe_buttons: Dictionary = {} # recipe_id -> {"label": Label, "btn": Button}
var prod_queue_header: Label
var prod_queue_buttons: Array[Button] = []
var prod_upgrade_button: Button

# Restaurant tab widgets
var rest_lock_box: VBoxContainer
var rest_lock_label: Label
var rest_unlock_button: Button
var rest_active_box: HBoxContainer
var rest_dish_rows: Dictionary = {} # dish_id -> {"label": Label, "btn": Button}
var rest_kitchen_label: Label
var rest_cust_rows: Array[Dictionary] = []
var rest_kitchen_upg_btn: Button
var rest_table_upg_btn: Button

# Automation tab widgets
var auto_offline_label: Label
var auto_prep_label: Label
var auto_prep_hire_btn: Button
var auto_prep_toggle_btn: Button
var auto_prep_prio_btn: Button
var auto_prep_upg_btn: Button
var auto_chef_label: Label
var auto_chef_hire_btn: Button
var auto_chef_toggle_btn: Button
var auto_chef_prio_btn: Button
var auto_chef_upg_btn: Button

# Home tab widgets
var home_header_label: Label
var home_moment_label: Label
var home_room_buttons: Dictionary = {}
var home_room_unlock_btn: Button
var home_slot_buttons: Array[Button] = []
var home_shop_rows: Dictionary = {}

# Pets tab widgets
var pet_header_label: Label
var pet_portrait_label: Label
var pet_context_label: Label
var pet_reaction_label: Label
var pet_behaviors_label: Label
var pet_shop_rows: Dictionary = {}
var pet_milestone_rows: Dictionary = {}

# Garage tab widgets
var garage_lock_box: VBoxContainer
var garage_lock_label: Label
var garage_unlock_btn: Button
var garage_active_box: HBoxContainer
var garage_header_label: Label
var garage_vehicle_rows: Dictionary = {}
var garage_speed_btn: Button
var garage_cap_btn: Button
var garage_auto_btn: Button
var garage_route_rows: Dictionary = {}
var garage_queue_rows: Array[Dictionary] = []

# Neighborhood tab widgets
var neigh_story_label: Label
var neigh_area_buttons: Dictionary = {}
var neigh_area_ascii_label: Label
var neigh_area_unlock_btn: Button
var neigh_area_build_btn: Button
var neigh_npc_rows: Dictionary = {}

# Goals & Collections tab widgets
var goals_rec_label: Label
var goals_coll_label: Label
var goals_daily_rows: Dictionary = {}
var goals_weekly_rows: Dictionary = {}
var goals_lt_rows: Dictionary = {}

var _auto_accum: float = 0.0

# Inventory tab widgets
var inv_header_label: Label
var inv_item_rows: Dictionary = {} # crop_id -> {"label": Label, "sell1": Button, "sell_all": Button}

# Upgrades tab widgets
var plot_upgrade_label: Label
var plot_upgrade_button: Button
var inv_upgrade_label: Label
var inv_upgrade_button: Button
var milestone_label: Label

var log_label: RichTextLabel
var log_lines: Array[String] = []
var _refresh_accum: float = 0.0

func _ready() -> void:
	_apply_comfortable_window_size()
	world = WorldState.new()
	_build_ascii_ui()
	_load_initial_state()
	_switch_tab(Tab.FARM)

func _apply_comfortable_window_size() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var win := get_window()
	if win == null:
		return
	var usable := DisplayServer.screen_get_usable_rect(win.current_screen)
	if usable.size.x > 0 and usable.size.y > 0:
		var target_w := int(round(float(usable.size.x) * 0.90))
		var target_h := int(round(float(usable.size.y) * 0.88))
		win.mode = Window.MODE_WINDOWED
		win.size = Vector2i(target_w, target_h)
		win.position = usable.position + Vector2i((usable.size.x - target_w) / 2, (usable.size.y - target_h) / 2)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and world != null:
		world.save()

func _process(delta: float) -> void:
	if world == null:
		return
	var matured := world.farm.tick(world.clock)
	var crafted := world.production.tick(world.clock)
	var cooked := world.restaurant.tick(world.clock)
	var delivered := world.garage.tick(world.clock)
	if matured > 0:
		_add_log("🌱 %d ô cây đã chín! Click [ \\|/ ] hoặc 'Thu tất cả'." % matured)
	if crafted > 0:
		_add_log("⚙️ %d món chế biến đã hoàn tất! Vào tab [Chế biến] để thu." % crafted)
	if cooked > 0:
		_add_log("🍜 %d tô Hủ Tiếu đã nấu xong! Vào tab [Quán Hủ Tiếu] để phục vụ." % cooked)
	if delivered > 0:
		_add_log("🚚 %d chuyến giao hàng đã tới nơi! Vào tab [Ga-ra] để nhận." % delivered)
	if matured > 0 or crafted > 0 or cooked > 0 or delivered > 0:
		world.save()
	_auto_accum += delta
	if _auto_accum >= 1.0:
		_auto_accum = 0.0
		var auto_res := world.step_automation()
		if int(auto_res["crafted_collected"]) > 0 or int(auto_res["dishes_served"]) > 0:
			_add_log("🤖 Tự động: Thu %d chế biến | Phục vụ %d tô (+%dxu)." % [
				int(auto_res["crafted_collected"]),
				int(auto_res["dishes_served"]),
				int(auto_res["coins_earned"])
			])
			world.save()
	_refresh_accum += delta
	if _refresh_accum >= 0.25 or matured > 0 or crafted > 0 or cooked > 0:
		_refresh_accum = 0.0
		_refresh_ui()

func _load_initial_state() -> void:
	var res := world.load_state()
	if bool(res.get("loaded", false)):
		var mig := int(res.get("migrated_from", 0))
		var mig_txt := " (migrated v%d->v%d)" % [mig, SaveManager.SAVE_VERSION] if mig > 0 else ""
		_add_log("💾 Đã tải save v%d%s. Offline: %s | Cây chín thêm: %d." % [
			int(res.get("save_version", SaveManager.SAVE_VERSION)),
			mig_txt,
			GameClock.format_duration(int(res.get("offline_elapsed", 0))),
			int(res.get("matured_count", 0))
		])
		var off: Dictionary = res.get("offline_summary", {}) as Dictionary
		if int(off.get("crafted_collected", 0)) > 0 or int(off.get("dishes_served", 0)) > 0:
			_add_log("🌙 Offline Auto: Thu %d chế biến | Phục vụ %d tô (+%d xu, +%d XP)%s." % [
				int(off.get("crafted_collected", 0)),
				int(off.get("dishes_served", 0)),
				int(off.get("coins_earned", 0)),
				int(off.get("xp_earned", 0)),
				" [Đã giới hạn trần]" if bool(off.get("was_capped", false)) else ""
			])
	else:
		var err := String(res.get("error", "missing"))
		if err == "unsupported_version":
			_add_log("❌ Save không hỗ trợ (save_version: %d). Dùng trạng thái mặc định." % int(res.get("save_version", 0)))
		elif err == "corrupted":
			_add_log("❌ File save bị lỗi, đã chuyển sang .corrupt và khôi phục trạng thái mặc định.")
		_add_log("🌾 Chào mừng đến Couple Chaos — Phase 3 (Orders, Progression & Tabbed ASCII)!")

func _build_ascii_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color("171b22")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(root_vbox)

	# 1. Header
	var title := Label.new()
	title.text = "=== COUPLE CHAOS — PHASE 7: HOME & COUPLE LIFE (ASCII) ==="
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("ffd54f"))
	root_vbox.add_child(title)

	# 2. Persistent HUD Bar
	var hud_panel := PanelContainer.new()
	root_vbox.add_child(hud_panel)
	var hud_vbox := VBoxContainer.new()
	hud_vbox.add_theme_constant_override("separation", 4)
	hud_panel.add_child(hud_vbox)

	var hud_top := HBoxContainer.new()
	hud_top.add_theme_constant_override("separation", 16)
	hud_vbox.add_child(hud_top)

	status_label = Label.new()
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color("a5d6a7"))
	hud_top.add_child(status_label)

	clock_label = Label.new()
	clock_label.add_theme_font_size_override("font_size", 14)
	clock_label.add_theme_color_override("font_color", Color("80d8ff"))
	hud_top.add_child(clock_label)

	next_goal_label = Label.new()
	next_goal_label.add_theme_font_size_override("font_size", 13)
	next_goal_label.add_theme_color_override("font_color", Color("ffe082"))
	hud_vbox.add_child(next_goal_label)

	# 3. Debug Clock & Save Controls + Tab Bar
	var tools_hbox := HBoxContainer.new()
	tools_hbox.add_theme_constant_override("separation", 6)
	root_vbox.add_child(tools_hbox)

	for step in [
		{"label": "+10s", "sec": 10},
		{"label": "+1m", "sec": 60},
		{"label": "+5m", "sec": 300},
		{"label": "+1h", "sec": 3600}
	]:
		var btn := Button.new()
		btn.text = step["label"]
		btn.pressed.connect(_on_advance_clock.bind(int(step["sec"]), String(step["label"])))
		tools_hbox.add_child(btn)

	var reset_clock_btn := Button.new()
	reset_clock_btn.text = "Reset Clock"
	reset_clock_btn.pressed.connect(_on_reset_clock)
	tools_hbox.add_child(reset_clock_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools_hbox.add_child(spacer)

	var save_btn := Button.new()
	save_btn.text = "💾 Lưu"
	save_btn.pressed.connect(_on_manual_save)
	tools_hbox.add_child(save_btn)

	var reload_btn := Button.new()
	reload_btn.text = "🔄 Tải lại"
	reload_btn.pressed.connect(_on_manual_reload)
	tools_hbox.add_child(reload_btn)

	var reset_save_btn := Button.new()
	reset_save_btn.text = "🗑 Reset Game"
	reset_save_btn.pressed.connect(_on_reset_game)
	tools_hbox.add_child(reset_save_btn)

	# Tab Navigation Bar
	var tabs_hbox := HBoxContainer.new()
	tabs_hbox.add_theme_constant_override("separation", 4)
	root_vbox.add_child(tabs_hbox)
	for tab_def in [
		{"id": Tab.FARM, "label": "🌾 Trại"},
		{"id": Tab.ORDERS, "label": "📋 Đơn"},
		{"id": Tab.PRODUCTION, "label": "⚙️ Chế biến"},
		{"id": Tab.RESTAURANT, "label": "🍜 Hủ Tiếu"},
		{"id": Tab.AUTOMATION, "label": "🤖 Tự động"},
		{"id": Tab.HOME, "label": "🏠 Nhà"},
		{"id": Tab.PETS, "label": "🐱 Miu Miu"},
		{"id": Tab.GARAGE, "label": "🚚 Ga-ra"},
		{"id": Tab.NEIGHBORHOOD, "label": "🏘️ Khu phố"},
		{"id": Tab.GOALS, "label": "🏆 Mục tiêu"},
		{"id": Tab.INVENTORY, "label": "📦 Kho"},
		{"id": Tab.UPGRADES, "label": "🔓 Nâng cấp"}
	]:
		var t_btn := Button.new()
		t_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t_btn.custom_minimum_size = Vector2(0, 32)
		t_btn.clip_text = true
		t_btn.add_theme_font_size_override("font_size", 12)
		t_btn.text = String(tab_def["label"])
		var tid: Tab = tab_def["id"]
		t_btn.pressed.connect(_switch_tab.bind(tid))
		tabs_hbox.add_child(t_btn)
		tab_buttons[tid] = t_btn

	# Main Tab Content Area
	var content_panel := PanelContainer.new()
	content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(content_panel)

	var content_stack := MarginContainer.new()
	content_stack.add_theme_constant_override("margin_left", 8)
	content_stack.add_theme_constant_override("margin_right", 8)
	content_stack.add_theme_constant_override("margin_top", 8)
	content_stack.add_theme_constant_override("margin_bottom", 8)
	content_panel.add_child(content_stack)

	_build_farm_tab(content_stack)
	_build_orders_tab(content_stack)
	_build_production_tab(content_stack)
	_build_restaurant_tab(content_stack)
	_build_automation_tab(content_stack)
	_build_home_tab(content_stack)
	_build_pets_tab(content_stack)
	_build_garage_tab(content_stack)
	_build_neighborhood_tab(content_stack)
	_build_goals_tab(content_stack)
	_build_inventory_tab(content_stack)
	_build_upgrades_tab(content_stack)

	# Activity Log
	var log_panel := PanelContainer.new()
	log_panel.custom_minimum_size = Vector2(0, 96)
	root_vbox.add_child(log_panel)
	log_label = RichTextLabel.new()
	log_label.scroll_following = true
	log_label.fit_content = false
	log_label.add_theme_font_size_override("normal_font_size", 13)
	log_panel.add_child(log_label)

func _build_farm_tab(parent: Control) -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	parent.add_child(vbox)
	tab_containers[Tab.FARM] = vbox

	var crop_hbox := HBoxContainer.new()
	crop_hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(crop_hbox)

	crop_buttons.clear()
	for cid in world.crop_ids_sorted:
		var c_btn := Button.new()
		c_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c_btn.pressed.connect(_on_select_crop.bind(cid))
		crop_hbox.add_child(c_btn)
		crop_buttons[cid] = c_btn

	var plant_all_btn := Button.new()
	plant_all_btn.text = "🌱 Trồng tất cả"
	plant_all_btn.pressed.connect(_on_plant_all)
	crop_hbox.add_child(plant_all_btn)

	var harvest_all_btn := Button.new()
	harvest_all_btn.text = "🧺 Thu tất cả"
	harvest_all_btn.pressed.connect(_on_harvest_all)
	crop_hbox.add_child(harvest_all_btn)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(grid)

	plot_buttons.clear()
	for plot in world.farm.plots:
		var p_btn := Button.new()
		p_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		p_btn.pressed.connect(_on_plot_clicked.bind(plot.id))
		grid.add_child(p_btn)
		plot_buttons.append(p_btn)

func _build_orders_tab(parent: Control) -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	parent.add_child(vbox)
	tab_containers[Tab.ORDERS] = vbox

	order_slot_labels.clear()
	order_deliver_buttons.clear()
	order_skip_buttons.clear()

	for slot_idx in range(world.order_board.max_slots):
		var card := PanelContainer.new()
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(card)
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		card.add_child(hbox)

		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 15)
		hbox.add_child(lbl)
		order_slot_labels.append(lbl)

		var d_btn := Button.new()
		d_btn.custom_minimum_size = Vector2(140, 44)
		d_btn.text = "📦 Giao đơn"
		d_btn.pressed.connect(_on_deliver_slot.bind(slot_idx))
		hbox.add_child(d_btn)
		order_deliver_buttons.append(d_btn)

		var s_btn := Button.new()
		s_btn.custom_minimum_size = Vector2(140, 44)
		s_btn.text = "🔄 Đổi đơn"
		s_btn.pressed.connect(_on_skip_slot.bind(slot_idx))
		hbox.add_child(s_btn)
		order_skip_buttons.append(s_btn)

func _build_production_tab(parent: Control) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	parent.add_child(hbox)
	tab_containers[Tab.PRODUCTION] = hbox

	# Left: Recipes
	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_stretch_ratio = 1.4
	left_vbox.add_theme_constant_override("separation", 6)
	hbox.add_child(left_vbox)

	var rec_title := Label.new()
	rec_title.text = "⚙️ CÔNG THỨC CHẾ BIẾN (Chọn để đưa vào hàng đợi)"
	rec_title.add_theme_color_override("font_color", Color("ffe082"))
	left_vbox.add_child(rec_title)

	prod_recipe_buttons.clear()
	for rid in world.production.recipe_ids_sorted:
		var card := PanelContainer.new()
		left_vbox.add_child(card)
		var r_hbox := HBoxContainer.new()
		r_hbox.add_theme_constant_override("separation", 8)
		card.add_child(r_hbox)

		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 13)
		r_hbox.add_child(lbl)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(120, 36)
		btn.text = "⚙️ Chế biến"
		btn.pressed.connect(_on_start_recipe.bind(rid))
		r_hbox.add_child(btn)
		prod_recipe_buttons[rid] = {"label": lbl, "btn": btn}

	# Right: Queue & Station Upgrade
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 8)
	hbox.add_child(right_vbox)

	prod_queue_header = Label.new()
	prod_queue_header.add_theme_color_override("font_color", Color("80d8ff"))
	right_vbox.add_child(prod_queue_header)

	prod_queue_buttons.clear()
	for idx in range(world.production.max_slots_cap):
		var q_btn := Button.new()
		q_btn.custom_minimum_size = Vector2(0, 44)
		q_btn.pressed.connect(_on_collect_prod_slot.bind(idx))
		right_vbox.add_child(q_btn)
		prod_queue_buttons.append(q_btn)

	var q_actions := HBoxContainer.new()
	q_actions.add_theme_constant_override("separation", 8)
	right_vbox.add_child(q_actions)

	var collect_all_btn := Button.new()
	collect_all_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	collect_all_btn.text = "🧺 Thu tất cả xong"
	collect_all_btn.pressed.connect(_on_collect_all_prod)
	q_actions.add_child(collect_all_btn)

	prod_upgrade_button = Button.new()
	prod_upgrade_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prod_upgrade_button.pressed.connect(_on_upgrade_prod_slot)
	q_actions.add_child(prod_upgrade_button)

func _build_restaurant_tab(parent: Control) -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	parent.add_child(root)
	tab_containers[Tab.RESTAURANT] = root

	rest_lock_box = VBoxContainer.new()
	rest_lock_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rest_lock_box.alignment = BoxContainer.ALIGNMENT_CENTER
	rest_lock_box.add_theme_constant_override("separation", 12)
	root.add_child(rest_lock_box)

	rest_lock_label = Label.new()
	rest_lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rest_lock_label.add_theme_font_size_override("font_size", 16)
	rest_lock_box.add_child(rest_lock_label)

	rest_unlock_button = Button.new()
	rest_unlock_button.custom_minimum_size = Vector2(260, 44)
	rest_unlock_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rest_unlock_button.pressed.connect(_on_unlock_restaurant)
	rest_lock_box.add_child(rest_unlock_button)

	rest_active_box = HBoxContainer.new()
	rest_active_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rest_active_box.add_theme_constant_override("separation", 12)
	root.add_child(rest_active_box)

	# Left: Menu & Kitchen
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.2
	left.add_theme_constant_override("separation", 6)
	rest_active_box.add_child(left)

	var m_title := Label.new()
	m_title.text = "🍜 THỰC ĐƠN HỦ TIẾU & BẾP"
	m_title.add_theme_color_override("font_color", Color("ffe082"))
	left.add_child(m_title)

	rest_dish_rows.clear()
	for did in world.restaurant.dish_ids_sorted:
		var card := PanelContainer.new()
		left.add_child(card)
		var r_hbox := HBoxContainer.new()
		r_hbox.add_theme_constant_override("separation", 6)
		card.add_child(r_hbox)
		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 12)
		r_hbox.add_child(lbl)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(90, 32)
		btn.text = "🍳 Nấu"
		btn.pressed.connect(_on_cook_dish.bind(did))
		r_hbox.add_child(btn)
		rest_dish_rows[did] = {"label": lbl, "btn": btn}

	rest_kitchen_label = Label.new()
	rest_kitchen_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rest_kitchen_label.add_theme_font_size_override("font_size", 12)
	rest_kitchen_label.add_theme_color_override("font_color", Color("80d8ff"))
	left.add_child(rest_kitchen_label)

	var upg_hbox := HBoxContainer.new()
	upg_hbox.add_theme_constant_override("separation", 6)
	left.add_child(upg_hbox)
	rest_kitchen_upg_btn = Button.new()
	rest_kitchen_upg_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rest_kitchen_upg_btn.pressed.connect(_on_upgrade_rest_kitchen)
	upg_hbox.add_child(rest_kitchen_upg_btn)
	rest_table_upg_btn = Button.new()
	rest_table_upg_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rest_table_upg_btn.pressed.connect(_on_upgrade_rest_tables)
	upg_hbox.add_child(rest_table_upg_btn)

	# Right: Customers
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	rest_active_box.add_child(right)

	var c_title := Label.new()
	c_title.text = "🪑 KHÁCH HÀNG ĐANG CHỜ"
	c_title.add_theme_color_override("font_color", Color("a5d6a7"))
	right.add_child(c_title)

	rest_cust_rows.clear()
	for idx in range(world.restaurant.max_table_slots):
		var card := PanelContainer.new()
		right.add_child(card)
		var c_hbox := HBoxContainer.new()
		c_hbox.add_theme_constant_override("separation", 6)
		card.add_child(c_hbox)
		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 12)
		c_hbox.add_child(lbl)
		var s_btn := Button.new()
		s_btn.custom_minimum_size = Vector2(95, 32)
		s_btn.text = "🍜 Phục vụ"
		s_btn.pressed.connect(_on_serve_customer.bind(idx))
		c_hbox.add_child(s_btn)
		var d_btn := Button.new()
		d_btn.custom_minimum_size = Vector2(70, 32)
		d_btn.text = "👋 Đổi"
		d_btn.pressed.connect(_on_dismiss_customer.bind(idx))
		c_hbox.add_child(d_btn)
		rest_cust_rows.append({"card": card, "label": lbl, "serve": s_btn, "dismiss": d_btn})

func _build_automation_tab(parent: Control) -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	parent.add_child(vbox)
	tab_containers[Tab.AUTOMATION] = vbox

	auto_offline_label = Label.new()
	auto_offline_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	auto_offline_label.add_theme_color_override("font_color", Color("80d8ff"))
	vbox.add_child(auto_offline_label)

	# Card 1: Prep Helper
	var prep_panel := PanelContainer.new()
	vbox.add_child(prep_panel)
	var prep_vbox := VBoxContainer.new()
	prep_vbox.add_theme_constant_override("separation", 6)
	prep_panel.add_child(prep_vbox)
	auto_prep_label = Label.new()
	auto_prep_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prep_vbox.add_child(auto_prep_label)
	var prep_btns := HBoxContainer.new()
	prep_btns.add_theme_constant_override("separation", 8)
	prep_vbox.add_child(prep_btns)
	auto_prep_hire_btn = Button.new()
	auto_prep_hire_btn.pressed.connect(_on_hire_prep)
	prep_btns.add_child(auto_prep_hire_btn)
	auto_prep_toggle_btn = Button.new()
	auto_prep_toggle_btn.pressed.connect(_on_toggle_prep)
	prep_btns.add_child(auto_prep_toggle_btn)
	auto_prep_prio_btn = Button.new()
	auto_prep_prio_btn.pressed.connect(_on_cycle_prep_prio)
	prep_btns.add_child(auto_prep_prio_btn)
	auto_prep_upg_btn = Button.new()
	auto_prep_upg_btn.pressed.connect(_on_upgrade_prep)
	prep_btns.add_child(auto_prep_upg_btn)

	# Card 2: Hu Tieu Chef
	var chef_panel := PanelContainer.new()
	vbox.add_child(chef_panel)
	var chef_vbox := VBoxContainer.new()
	chef_vbox.add_theme_constant_override("separation", 6)
	chef_panel.add_child(chef_vbox)
	auto_chef_label = Label.new()
	auto_chef_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chef_vbox.add_child(auto_chef_label)
	var chef_btns := HBoxContainer.new()
	chef_btns.add_theme_constant_override("separation", 8)
	chef_vbox.add_child(chef_btns)
	auto_chef_hire_btn = Button.new()
	auto_chef_hire_btn.pressed.connect(_on_hire_chef)
	chef_btns.add_child(auto_chef_hire_btn)
	auto_chef_toggle_btn = Button.new()
	auto_chef_toggle_btn.pressed.connect(_on_toggle_chef)
	chef_btns.add_child(auto_chef_toggle_btn)
	auto_chef_prio_btn = Button.new()
	auto_chef_prio_btn.pressed.connect(_on_toggle_chef_prio)
	chef_btns.add_child(auto_chef_prio_btn)
	auto_chef_upg_btn = Button.new()
	auto_chef_upg_btn.pressed.connect(_on_upgrade_chef)
	chef_btns.add_child(auto_chef_upg_btn)

func _build_home_tab(parent: Control) -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	parent.add_child(root)
	tab_containers[Tab.HOME] = root

	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 10)
	root.add_child(top_bar)

	home_header_label = Label.new()
	home_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home_header_label.add_theme_color_override("font_color", Color("ffe082"))
	top_bar.add_child(home_header_label)

	var sw_btn := Button.new()
	sw_btn.text = "🔄 Đổi Boy/Girl"
	sw_btn.pressed.connect(_on_switch_character)
	top_bar.add_child(sw_btn)

	var mom_btn := Button.new()
	mom_btn.text = "💞 Khoảnh khắc đôi"
	mom_btn.pressed.connect(_on_couple_moment)
	top_bar.add_child(mom_btn)

	home_moment_label = Label.new()
	home_moment_label.add_theme_color_override("font_color", Color("f48fb1"))
	root.add_child(home_moment_label)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	root.add_child(body)

	# Left: Rooms & ASCII Placement Grid
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	body.add_child(left)

	var r_hbox := HBoxContainer.new()
	r_hbox.add_theme_constant_override("separation", 6)
	left.add_child(r_hbox)
	home_room_buttons.clear()
	for rid in world.home.room_ids_sorted:
		var r_btn := Button.new()
		r_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r_btn.pressed.connect(_on_select_room.bind(rid))
		r_hbox.add_child(r_btn)
		home_room_buttons[rid] = r_btn

	home_room_unlock_btn = Button.new()
	home_room_unlock_btn.pressed.connect(_on_unlock_active_room)
	left.add_child(home_room_unlock_btn)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	left.add_child(grid)

	home_slot_buttons.clear()
	for s_idx in range(4):
		var s_btn := Button.new()
		s_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		s_btn.pressed.connect(_on_home_slot_clicked.bind(s_idx))
		grid.add_child(s_btn)
		home_slot_buttons.append(s_btn)

	# Right: Furniture Shop & Collection
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	body.add_child(right)

	var shop_title := Label.new()
	shop_title.text = "🛋️ CỬA HÀNG & BỘ SƯU TẬP NỘI THẤT"
	shop_title.add_theme_color_override("font_color", Color("80d8ff"))
	right.add_child(shop_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)

	var shop_list := VBoxContainer.new()
	shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_list.add_theme_constant_override("separation", 4)
	scroll.add_child(shop_list)

	home_shop_rows.clear()
	for fid in world.home.item_ids_sorted:
		var card := PanelContainer.new()
		shop_list.add_child(card)
		var f_hbox := HBoxContainer.new()
		f_hbox.add_theme_constant_override("separation", 6)
		card.add_child(f_hbox)
		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 12)
		f_hbox.add_child(lbl)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(105, 28)
		btn.pressed.connect(_on_furniture_action.bind(fid))
		f_hbox.add_child(btn)
		home_shop_rows[fid] = {"label": lbl, "btn": btn}

func _build_pets_tab(parent: Control) -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	parent.add_child(root)
	tab_containers[Tab.PETS] = root

	pet_header_label = Label.new()
	pet_header_label.add_theme_color_override("font_color", Color("ffe082"))
	root.add_child(pet_header_label)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	root.add_child(body)

	# Left: Miu Miu ASCII Portrait, Home Context, Interactions & Behaviors
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	body.add_child(left)

	var portrait_panel := PanelContainer.new()
	left.add_child(portrait_panel)
	var p_vbox := VBoxContainer.new()
	p_vbox.add_theme_constant_override("separation", 4)
	portrait_panel.add_child(p_vbox)

	pet_portrait_label = Label.new()
	pet_portrait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pet_portrait_label.add_theme_font_size_override("font_size", 15)
	pet_portrait_label.add_theme_color_override("font_color", Color("ffd54f"))
	p_vbox.add_child(pet_portrait_label)

	pet_context_label = Label.new()
	pet_context_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pet_context_label.add_theme_color_override("font_color", Color("a5d6a7"))
	p_vbox.add_child(pet_context_label)

	pet_reaction_label = Label.new()
	pet_reaction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pet_reaction_label.add_theme_color_override("font_color", Color("f48fb1"))
	p_vbox.add_child(pet_reaction_label)

	var act_hbox := HBoxContainer.new()
	act_hbox.add_theme_constant_override("separation", 6)
	left.add_child(act_hbox)

	var pet_btn := Button.new()
	pet_btn.text = "🐾 Vuốt ve"
	pet_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pet_btn.pressed.connect(_on_pet_miu_miu)
	act_hbox.add_child(pet_btn)

	var play_btn := Button.new()
	play_btn.text = "🧶 Chơi cùng"
	play_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_btn.pressed.connect(_on_play_miu_miu)
	act_hbox.add_child(play_btn)

	var feed_btn := Button.new()
	feed_btn.text = "🥕 Cho ăn cà rốt"
	feed_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feed_btn.pressed.connect(_on_feed_miu_miu)
	act_hbox.add_child(feed_btn)

	pet_behaviors_label = Label.new()
	pet_behaviors_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pet_behaviors_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(pet_behaviors_label)

	# Right: Pet Shop & Cozy Collection Milestones
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	body.add_child(right)

	var shop_title := Label.new()
	shop_title.text = "🧸 ĐỒ CHƠI, Ổ NỆM & PHỤ KIỆN MIU MIU"
	shop_title.add_theme_color_override("font_color", Color("80d8ff"))
	right.add_child(shop_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)

	var list_vbox := VBoxContainer.new()
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(list_vbox)

	pet_shop_rows.clear()
	for iid: String in world.pets.item_ids_sorted:
		var card := PanelContainer.new()
		list_vbox.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		card.add_child(row)
		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 12)
		row.add_child(lbl)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(110, 28)
		btn.pressed.connect(_on_pet_item_action.bind(iid))
		row.add_child(btn)
		pet_shop_rows[iid] = {"label": lbl, "btn": btn}

	var ms_title := Label.new()
	ms_title.text = "🏆 BỘ SƯU TẬP & PHẦN THƯỞNG NHẸ NHÀNG"
	ms_title.add_theme_color_override("font_color", Color("ffe082"))
	right.add_child(ms_title)

	pet_milestone_rows.clear()
	for mid: String in world.pets.milestone_ids_sorted:
		var m_card := PanelContainer.new()
		right.add_child(m_card)
		var m_row := HBoxContainer.new()
		m_row.add_theme_constant_override("separation", 6)
		m_card.add_child(m_row)
		var m_lbl := Label.new()
		m_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		m_lbl.add_theme_font_size_override("font_size", 12)
		m_row.add_child(m_lbl)
		var m_btn := Button.new()
		m_btn.custom_minimum_size = Vector2(110, 28)
		m_btn.pressed.connect(_on_claim_pet_milestone.bind(mid))
		m_row.add_child(m_btn)
		pet_milestone_rows[mid] = {"label": m_lbl, "btn": m_btn}

func _build_garage_tab(parent: Control) -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	parent.add_child(root)
	tab_containers[Tab.GARAGE] = root

	garage_lock_box = VBoxContainer.new()
	garage_lock_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	garage_lock_box.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(garage_lock_box)

	garage_lock_label = Label.new()
	garage_lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	garage_lock_label.add_theme_color_override("font_color", Color("ffe082"))
	garage_lock_box.add_child(garage_lock_label)

	garage_unlock_btn = Button.new()
	garage_unlock_btn.custom_minimum_size = Vector2(260, 40)
	garage_unlock_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	garage_unlock_btn.pressed.connect(_on_unlock_garage)
	garage_lock_box.add_child(garage_unlock_btn)

	garage_active_box = HBoxContainer.new()
	garage_active_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	garage_active_box.add_theme_constant_override("separation", 12)
	root.add_child(garage_active_box)

	# Left: Vehicles, Upgrades & Optional Auto
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	garage_active_box.add_child(left)

	garage_header_label = Label.new()
	garage_header_label.add_theme_color_override("font_color", Color("ffe082"))
	left.add_child(garage_header_label)

	garage_vehicle_rows.clear()
	for vid: String in world.garage.vehicle_ids_sorted:
		var v_card := PanelContainer.new()
		left.add_child(v_card)
		var v_row := HBoxContainer.new()
		v_row.add_theme_constant_override("separation", 6)
		v_card.add_child(v_row)
		var v_lbl := Label.new()
		v_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v_lbl.add_theme_font_size_override("font_size", 12)
		v_row.add_child(v_lbl)
		var v_btn := Button.new()
		v_btn.custom_minimum_size = Vector2(120, 28)
		v_btn.pressed.connect(_on_repair_vehicle.bind(vid))
		v_row.add_child(v_btn)
		garage_vehicle_rows[vid] = {"label": v_lbl, "btn": v_btn}

	var upg_hbox := HBoxContainer.new()
	upg_hbox.add_theme_constant_override("separation", 6)
	left.add_child(upg_hbox)

	garage_speed_btn = Button.new()
	garage_speed_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	garage_speed_btn.pressed.connect(_on_upgrade_garage_speed)
	upg_hbox.add_child(garage_speed_btn)

	garage_cap_btn = Button.new()
	garage_cap_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	garage_cap_btn.pressed.connect(_on_upgrade_garage_capacity)
	upg_hbox.add_child(garage_cap_btn)

	garage_auto_btn = Button.new()
	garage_auto_btn.pressed.connect(_on_toggle_garage_auto)
	left.add_child(garage_auto_btn)

	var q_title := Label.new()
	q_title.text = "📦 CHUYẾN ĐANG GIAO:"
	q_title.add_theme_color_override("font_color", Color("a5d6a7"))
	left.add_child(q_title)

	garage_queue_rows.clear()
	for i in range(3):
		var q_card := PanelContainer.new()
		left.add_child(q_card)
		var q_row := HBoxContainer.new()
		q_row.add_theme_constant_override("separation", 6)
		q_card.add_child(q_row)
		var q_lbl := Label.new()
		q_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		q_lbl.add_theme_font_size_override("font_size", 12)
		q_row.add_child(q_lbl)
		var q_btn := Button.new()
		q_btn.custom_minimum_size = Vector2(105, 28)
		q_btn.pressed.connect(_on_claim_delivery.bind(i))
		q_row.add_child(q_btn)
		garage_queue_rows.append({"card": q_card, "label": q_lbl, "btn": q_btn})

	# Right: Delivery Routes
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	garage_active_box.add_child(right)

	var r_title := Label.new()
	r_title.text = "🗺️ TUYẾN GIAO HÀNG & THƯỞNG MỞ TUYẾN"
	r_title.add_theme_color_override("font_color", Color("80d8ff"))
	right.add_child(r_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)

	var r_list := VBoxContainer.new()
	r_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r_list.add_theme_constant_override("separation", 6)
	scroll.add_child(r_list)

	garage_route_rows.clear()
	for rid: String in world.garage.route_ids_sorted:
		var r_card := PanelContainer.new()
		r_list.add_child(r_card)
		var r_row := HBoxContainer.new()
		r_row.add_theme_constant_override("separation", 6)
		r_card.add_child(r_row)
		var r_lbl := Label.new()
		r_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r_lbl.add_theme_font_size_override("font_size", 12)
		r_row.add_child(r_lbl)
		var r_btn := Button.new()
		r_btn.custom_minimum_size = Vector2(105, 32)
		r_btn.pressed.connect(_on_start_delivery.bind(rid))
		r_row.add_child(r_btn)
		garage_route_rows[rid] = {"label": r_lbl, "btn": r_btn}

func _build_neighborhood_tab(parent: Control) -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	parent.add_child(root)
	tab_containers[Tab.NEIGHBORHOOD] = root

	neigh_story_label = Label.new()
	neigh_story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	neigh_story_label.add_theme_color_override("font_color", Color("f48fb1"))
	root.add_child(neigh_story_label)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	root.add_child(body)

	# Left: Areas & Construction Unlocks
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	body.add_child(left)

	var a_title := Label.new()
	a_title.text = "🗺️ KHU VỰC & CÔNG TRÌNH KHU PHỐ"
	a_title.add_theme_color_override("font_color", Color("ffe082"))
	left.add_child(a_title)

	var a_hbox := HBoxContainer.new()
	a_hbox.add_theme_constant_override("separation", 6)
	left.add_child(a_hbox)
	neigh_area_buttons.clear()
	for aid: String in world.neighborhood.area_ids_sorted:
		var a_btn := Button.new()
		a_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		a_btn.pressed.connect(_on_select_area.bind(aid))
		a_hbox.add_child(a_btn)
		neigh_area_buttons[aid] = a_btn

	var art_panel := PanelContainer.new()
	art_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(art_panel)
	neigh_area_ascii_label = Label.new()
	neigh_area_ascii_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	neigh_area_ascii_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	neigh_area_ascii_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	neigh_area_ascii_label.add_theme_color_override("font_color", Color("a5d6a7"))
	art_panel.add_child(neigh_area_ascii_label)

	neigh_area_unlock_btn = Button.new()
	neigh_area_unlock_btn.pressed.connect(_on_unlock_active_area)
	left.add_child(neigh_area_unlock_btn)

	neigh_area_build_btn = Button.new()
	neigh_area_build_btn.pressed.connect(_on_build_active_area)
	left.add_child(neigh_area_build_btn)

	# Right: NPCs, Requests & Story Milestones
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	body.add_child(right)

	var n_title := Label.new()
	n_title.text = "👥 HÀNG XÓM, YÊU CẦU & CÂU CHUYỆN"
	n_title.add_theme_color_override("font_color", Color("80d8ff"))
	right.add_child(n_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)

	var n_list := VBoxContainer.new()
	n_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n_list.add_theme_constant_override("separation", 6)
	scroll.add_child(n_list)

	neigh_npc_rows.clear()
	for nid: String in world.neighborhood.npc_ids_sorted:
		var card := PanelContainer.new()
		n_list.add_child(card)
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		card.add_child(vbox)
		var lbl := Label.new()
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 12)
		vbox.add_child(lbl)
		var btns := HBoxContainer.new()
		btns.add_theme_constant_override("separation", 6)
		vbox.add_child(btns)
		var chat_btn := Button.new()
		chat_btn.text = "💬 Trò chuyện"
		chat_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chat_btn.pressed.connect(_on_chat_npc.bind(nid))
		btns.add_child(chat_btn)
		var help_btn := Button.new()
		help_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		help_btn.pressed.connect(_on_help_npc.bind(nid))
		btns.add_child(help_btn)
		var story_btn := Button.new()
		story_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		story_btn.pressed.connect(_on_claim_npc_story.bind(nid))
		btns.add_child(story_btn)
		neigh_npc_rows[nid] = {"label": lbl, "chat": chat_btn, "help": help_btn, "story": story_btn}

func _build_goals_tab(parent: Control) -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	parent.add_child(root)
	tab_containers[Tab.GOALS] = root

	goals_rec_label = Label.new()
	goals_rec_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goals_rec_label.add_theme_color_override("font_color", Color("ffe082"))
	root.add_child(goals_rec_label)

	goals_coll_label = Label.new()
	goals_coll_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goals_coll_label.add_theme_color_override("font_color", Color("a5d6a7"))
	root.add_child(goals_coll_label)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	root.add_child(body)

	# Left: Optional Daily Objectives + Weekly Multi-System Goals
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	body.add_child(left)

	var d_hbox := HBoxContainer.new()
	d_hbox.add_theme_constant_override("separation", 6)
	left.add_child(d_hbox)
	var d_title := Label.new()
	d_title.text = "☀️ MỤC TIÊU NGÀY (TÙY CHỌN)"
	d_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d_title.add_theme_color_override("font_color", Color("80d8ff"))
	d_hbox.add_child(d_title)
	var d_ref_btn := Button.new()
	d_ref_btn.text = "🔄 Làm mới ngày"
	d_ref_btn.pressed.connect(_on_refresh_daily)
	d_hbox.add_child(d_ref_btn)

	goals_daily_rows.clear()
	for obj in world.goals.daily_cfg:
		var oid := String(obj.get("id", ""))
		var card := PanelContainer.new()
		left.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		card.add_child(row)
		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 12)
		row.add_child(lbl)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(105, 28)
		btn.pressed.connect(_on_claim_daily.bind(oid))
		row.add_child(btn)
		goals_daily_rows[oid] = {"label": lbl, "btn": btn}

	var w_title := Label.new()
	w_title.text = "📅 MỤC TIÊU TUẦN (LIÊN HỆ THỐNG)"
	w_title.add_theme_color_override("font_color", Color("80d8ff"))
	left.add_child(w_title)

	goals_weekly_rows.clear()
	for w in world.goals.weekly_cfg:
		var wid := String(w.get("id", ""))
		var card := PanelContainer.new()
		left.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		card.add_child(row)
		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 12)
		row.add_child(lbl)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(105, 28)
		btn.pressed.connect(_on_claim_weekly.bind(wid))
		row.add_child(btn)
		goals_weekly_rows[wid] = {"label": lbl, "btn": btn}

	# Right: Long-Term Milestones
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	body.add_child(right)

	var lt_title := Label.new()
	lt_title.text = "🏆 CỘT MỐC DÀI HẠN & BỘ SƯU TẬP"
	lt_title.add_theme_color_override("font_color", Color("ffe082"))
	right.add_child(lt_title)

	goals_lt_rows.clear()
	for m in world.goals.milestones_cfg:
		var mid := String(m.get("id", ""))
		var card := PanelContainer.new()
		right.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		card.add_child(row)
		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 12)
		row.add_child(lbl)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(105, 28)
		btn.pressed.connect(_on_claim_lt_milestone.bind(mid))
		row.add_child(btn)
		goals_lt_rows[mid] = {"label": lbl, "btn": btn}

func _build_inventory_tab(parent: Control) -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	parent.add_child(vbox)
	tab_containers[Tab.INVENTORY] = vbox

	inv_header_label = Label.new()
	inv_header_label.add_theme_font_size_override("font_size", 16)
	inv_header_label.add_theme_color_override("font_color", Color("ffe082"))
	vbox.add_child(inv_header_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var list_vbox := VBoxContainer.new()
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 5)
	scroll.add_child(list_vbox)

	inv_item_rows.clear()
	for cid in world.get_all_known_item_ids():
		var row_panel := PanelContainer.new()
		list_vbox.add_child(row_panel)
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		row_panel.add_child(hbox)

		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 13)
		hbox.add_child(lbl)

		var b1 := Button.new()
		b1.custom_minimum_size = Vector2(115, 28)
		b1.pressed.connect(_on_sell_item.bind(cid, false))
		hbox.add_child(b1)

		var ball := Button.new()
		ball.custom_minimum_size = Vector2(115, 28)
		ball.pressed.connect(_on_sell_item.bind(cid, true))
		hbox.add_child(ball)

		inv_item_rows[cid] = {"label": lbl, "sell1": b1, "sell_all": ball}

func _build_upgrades_tab(parent: Control) -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	parent.add_child(vbox)
	tab_containers[Tab.UPGRADES] = vbox

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)

	var p_panel := PanelContainer.new()
	p_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(p_panel)
	var p_vbox := VBoxContainer.new()
	p_panel.add_child(p_vbox)
	plot_upgrade_label = Label.new()
	plot_upgrade_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p_vbox.add_child(plot_upgrade_label)
	plot_upgrade_button = Button.new()
	plot_upgrade_button.custom_minimum_size = Vector2(0, 40)
	plot_upgrade_button.text = "🔓 Mở khóa ô đất tiếp theo"
	plot_upgrade_button.pressed.connect(_on_unlock_next_plot)
	p_vbox.add_child(plot_upgrade_button)

	var i_panel := PanelContainer.new()
	i_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(i_panel)
	var i_vbox := VBoxContainer.new()
	i_panel.add_child(i_vbox)
	inv_upgrade_label = Label.new()
	inv_upgrade_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	i_vbox.add_child(inv_upgrade_label)
	inv_upgrade_button = Button.new()
	inv_upgrade_button.custom_minimum_size = Vector2(0, 40)
	inv_upgrade_button.pressed.connect(_on_upgrade_inventory)
	i_vbox.add_child(inv_upgrade_button)

	var m_panel := PanelContainer.new()
	m_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(m_panel)
	milestone_label = Label.new()
	milestone_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	milestone_label.add_theme_font_size_override("font_size", 14)
	m_panel.add_child(milestone_label)

func _switch_tab(tab: Tab) -> void:
	active_tab = tab
	for t in tab_containers.keys():
		(tab_containers[t] as Control).visible = (t == active_tab)
	_refresh_ui()

func _on_select_crop(crop_id: String) -> void:
	var res := world.select_crop(crop_id)
	if bool(res.get("ok", false)):
		var cfg := world.get_selected_crop_cfg()
		_add_log("🌿 Đã chọn giống: %s." % String(cfg.get("display_name", crop_id)))
		world.save()
	else:
		_add_log("🔒 %s" % String(res.get("reason", "Chưa mở khóa.")))
	_refresh_ui()

func _on_plot_clicked(plot_id: int) -> void:
	var plot := world.farm.get_plot(plot_id)
	if plot == null:
		return
	match plot.state:
		FarmPlot.State.EMPTY:
			var res := world.plant_plot(plot_id)
			var rec := int(res.get("recovered_coins", 0))
			if rec > 0:
				_add_log("🆘 Hỗ trợ khẩn cấp: Tặng +%d xu mua hạt giống!" % rec)
			if bool(res.get("ok", false)):
				var cfg := world.get_crop_cfg(String(res.get("crop_id", "carrot")))
				_add_log("🌱 Trồng %s tại Ô #%d (-%d xu)." % [String(cfg.get("display_name", "Cây")), plot_id + 1, int(res.get("cost", 0))])
				world.save()
			else:
				_add_log("⚠️ %s" % String(res.get("reason", "Không thể trồng.")))
		FarmPlot.State.GROWING:
			var cfg := world.get_crop_cfg(plot.crop_id)
			_add_log("⏳ Ô #%d (%s) còn %s." % [plot_id + 1, String(cfg.get("display_name", plot.crop_id)), GameClock.format_duration(plot.timer.get_remaining_seconds(world.clock.now()))])
		FarmPlot.State.READY:
			var res := world.harvest_plot(plot_id)
			if bool(res.get("ok", false)):
				var cfg := world.get_crop_cfg(String(res.get("crop_id", "carrot")))
				_add_log("🧺 Thu hoạch Ô #%d: +%d %s!" % [plot_id + 1, int(res.get("yield", 1)), String(cfg.get("display_name", "Cây"))])
				world.save()
			else:
				_add_log("⚠️ %s" % String(res.get("reason", "Không thể thu hoạch.")))
		FarmPlot.State.LOCKED:
			var res := world.unlock_plot(plot_id)
			if bool(res.get("ok", false)):
				_add_log("🔓 Đã mở khóa Ô #%d (-%d xu)!" % [plot_id + 1, int(res.get("cost", 120))])
				world.save()
			else:
				_add_log("⚠️ %s" % String(res.get("reason", "Không thể mở khóa.")))
	_refresh_ui()

func _on_plant_all() -> void:
	var res := world.plant_all_empty()
	var rec := int(res.get("recovered_coins", 0))
	if rec > 0:
		_add_log("🆘 Hỗ trợ khẩn cấp: Tặng +%d xu!" % rec)
	if bool(res.get("ok", false)):
		_add_log("🌱 Đã trồng %d ô (-%d xu)." % [int(res.get("planted", 0)), int(res.get("cost", 0))])
		world.save()
	else:
		_add_log("⚠️ %s" % String(res.get("reason", "Không thể trồng.")))
	_refresh_ui()

func _on_harvest_all() -> void:
	var res := world.harvest_all_ready()
	if bool(res.get("ok", false)):
		_add_log("🧺 Thu hoạch hàng loạt %d ô thành công!" % int(res.get("harvested", 0)))
		if bool(res.get("stopped_full", false)):
			_add_log("⚠️ %s" % String(res.get("reason", "Kho đầy.")))
		world.save()
	else:
		_add_log("⚠️ %s" % String(res.get("reason", "Chưa có ô nào chín.")))
	_refresh_ui()

func _on_deliver_slot(slot_idx: int) -> void:
	var res := world.deliver_order_slot(slot_idx)
	if bool(res.get("ok", false)):
		_add_log("📦 Giao '%s' → +%d xu | +%d XP!" % [
			String(res.get("title", "Đơn")),
			int(res.get("reward_coins", 0)),
			int(res.get("reward_xp", 0))
		])
		if bool(res.get("leveled_up", false)):
			var unlocks: Array = res.get("new_unlocks", [])
			_add_log("🎉 LÊN LEVEL %d! Mở khóa: %s" % [int(res.get("new_level", 1)), ", ".join(unlocks)])
		world.save()
	else:
		_add_log("⚠️ %s" % String(res.get("reason", "Không thể giao đơn.")))
	_refresh_ui()

func _on_skip_slot(slot_idx: int) -> void:
	var res := world.skip_order_slot(slot_idx)
	if bool(res.get("ok", false)):
		_add_log("🔄 Đã đổi đơn #%d sang '%s'." % [slot_idx + 1, String(res.get("new_title", ""))])
		world.save()
	else:
		_add_log("⚠️ %s" % String(res.get("reason", "Đang hồi làm mới.")))
	_refresh_ui()

func _on_sell_item(cid: String, sell_all: bool) -> void:
	var owned := world.inventory.get_count(cid)
	var amt := owned if sell_all else 1
	var res := world.sell_crop(cid, amt)
	if bool(res.get("ok", false)):
		_add_log("💰 Đã bán %d %s → +%d xu!" % [int(res.get("sold", 0)), String(res.get("display_name", cid)), int(res.get("earned", 0))])
		world.save()
	else:
		_add_log("⚠️ %s" % String(res.get("reason", "Không thể bán.")))
	_refresh_ui()

func _on_upgrade_inventory() -> void:
	var res := world.upgrade_inventory()
	if bool(res.get("ok", false)):
		_add_log("📦 Nâng kho lên %d (-%d xu)!" % [int(res.get("new_capacity", 20)), int(res.get("cost", 0))])
		world.save()
	else:
		_add_log("⚠️ %s" % String(res.get("reason", "Không thể nâng cấp.")))
	_refresh_ui()

func _on_unlock_next_plot() -> void:
	var res := world.unlock_next_plot()
	if bool(res.get("ok", false)):
		_add_log("🔓 Đã mở khóa Ô #%d (-%d xu)!" % [int(res.get("plot_id", 0)) + 1, int(res.get("cost", 120))])
		world.save()
	else:
		_add_log("⚠️ %s" % String(res.get("reason", "Không thể mở khóa.")))
	_refresh_ui()

func _on_start_recipe(recipe_id: String) -> void:
	var res := world.start_production(recipe_id)
	if bool(res.get("ok", false)):
		var job := res.get("job", {}) as Dictionary
		_add_log("⚙️ Đã đưa '%s' vào hàng đợi chế biến." % String(job.get("display_name", recipe_id)))
		world.save()
	else:
		_add_log("⚠️ %s" % String(res.get("reason", "Không thể chế biến.")))
	_refresh_ui()

func _on_collect_prod_slot(slot_idx: int) -> void:
	var res := world.collect_production(slot_idx)
	if bool(res.get("ok", false)):
		_add_log("🧺 Đã thu %d %s vào kho!" % [int(res.get("yield", 1)), String(res.get("display_name", ""))])
		world.save()
	else:
		_add_log("⚠️ %s" % String(res.get("reason", "Chưa xong.")))
	_refresh_ui()

func _on_collect_all_prod() -> void:
	var res := world.collect_all_production()
	if bool(res.get("ok", false)):
		_add_log("🧺 Đã thu %d món chế biến vào kho!" % int(res.get("collected", 0)))
		if bool(res.get("stopped_full", false)):
			_add_log("⚠️ %s" % String(res.get("reason", "Kho đầy.")))
		world.save()
	else:
		_add_log("⚠️ %s" % String(res.get("reason", "Chưa có món nào xong.")))
	_refresh_ui()

func _on_upgrade_prod_slot() -> void:
	var res := world.upgrade_production_slot()
	if bool(res.get("ok", false)):
		_add_log("🔓 Mở rộng hàng đợi chế biến lên %d slot (-%d xu)!" % [int(res.get("new_max_slots", 2)), int(res.get("cost", 0))])
		world.save()
	else:
		_add_log("⚠️ %s" % String(res.get("reason", "Không thể nâng cấp.")))
	_refresh_ui()

func _on_unlock_restaurant() -> void:
	var res := world.unlock_restaurant()
	if bool(res.get("ok", false)):
		_add_log("🍜 Đã khai trương Quán Hủ Tiếu (-%d xu)!" % int(res.get("cost", 100)))
		world.save()
	else:
		_add_log("⚠️ %s" % String(res.get("reason", "Chưa đủ điều kiện mở quán.")))
	_refresh_ui()

func _on_cook_dish(dish_id: String) -> void:
	var res := world.cook_dish(dish_id)
	if bool(res.get("ok", false)):
		var job := res.get("job", {}) as Dictionary
		_add_log("🍳 Đang nấu '%s'..." % String(job.get("display_name", dish_id)))
		world.save()
	else:
		_add_log("⚠️ %s" % String(res.get("reason", "Không thể nấu.")))
	_refresh_ui()

func _on_serve_customer(cust_idx: int) -> void:
	var res := world.serve_restaurant_customer(cust_idx)
	if bool(res.get("ok", false)):
		_add_log("🍜 Phục vụ %s (%s) → +%d xu | +%d XP!" % [
			String(res.get("customer_name", "Khách")),
			String(res.get("dish_name", "")),
			int(res.get("reward_coins", 0)),
			int(res.get("reward_xp", 0))
		])
		var new_dish := String(res.get("unlocked_dish", ""))
		if new_dish != "":
			_add_log("🌟 Mở khóa công thức mới: %s!" % String(world.restaurant.get_dish(new_dish).get("display_name", new_dish)))
		if bool(res.get("leveled_up", false)):
			_add_log("🎉 LÊN LEVEL %d!" % int(res.get("new_level", 1)))
		world.save()
	else:
		_add_log("⚠️ %s" % String(res.get("reason", "Chưa nấu xong món.")))
	_refresh_ui()

func _on_dismiss_customer(cust_idx: int) -> void:
	var res := world.dismiss_restaurant_customer(cust_idx)
	if bool(res.get("ok", false)):
		_add_log("👋 Đã mời khách mới vào bàn #%d." % (cust_idx + 1))
		world.save()
	_refresh_ui()

func _on_upgrade_rest_kitchen() -> void:
	var res := world.upgrade_restaurant_kitchen()
	if bool(res.get("ok", false)):
		_add_log("🔥 Nâng cấp bếp Hủ Tiếu lên %d nồi (-%d xu)!" % [int(res.get("new_kitchen_slots", 1)), int(res.get("cost", 0))])
		world.save()
	else:
		_add_log("⚠️ %s" % String(res.get("reason", "Không thể nâng cấp.")))
	_refresh_ui()

func _on_upgrade_rest_tables() -> void:
	var res := world.upgrade_restaurant_tables()
	if bool(res.get("ok", false)):
		_add_log("🪑 Mở rộng quán lên %d bàn (-%d xu)!" % [int(res.get("new_table_slots", 2)), int(res.get("cost", 0))])
		world.save()
	else:
		_add_log("⚠️ %s" % String(res.get("reason", "Không thể mở rộng.")))
	_refresh_ui()

func _on_hire_prep() -> void:
	var res := world.automation.hire_prep(world.wallet, world.progression.level)
	if bool(res.get("ok", false)):
		_add_log("🤖 Đã thuê Phụ bếp Chế biến (-%d xu)!" % int(res.get("cost", 90)))
		world.save()
	else:
		_add_log("⚠️ %s" % String(res.get("reason", "Không thể thuê.")))
	_refresh_ui()

func _on_toggle_prep() -> void:
	world.automation.prep_enabled = not world.automation.prep_enabled
	world.save()
	_refresh_ui()

func _on_cycle_prep_prio() -> void:
	var choices: Array[String] = ["auto"]
	for rid in world.production.recipe_ids_sorted:
		choices.append(rid)
	var idx := choices.find(world.automation.prep_priority_recipe)
	world.automation.prep_priority_recipe = choices[(idx + 1) % choices.size()]
	world.save()
	_refresh_ui()

func _on_upgrade_prep() -> void:
	var res := world.automation.upgrade_prep(world.wallet)
	if bool(res.get("ok", false)):
		_add_log("⬆️ Nâng cấp Phụ bếp lên Lv.%d (-%d xu)!" % [int(res.get("new_level", 2)), int(res.get("cost", 0))])
		world.save()
	else:
		_add_log("⚠️ %s" % String(res.get("reason", "Không thể nâng cấp.")))
	_refresh_ui()

func _on_hire_chef() -> void:
	var res := world.automation.hire_chef(world.wallet, world.progression.level, world.restaurant.is_unlocked)
	if bool(res.get("ok", false)):
		_add_log("🤖 Đã thuê Đầu bếp Hủ Tiếu (-%d xu)!" % int(res.get("cost", 160)))
		world.save()
	else:
		_add_log("⚠️ %s" % String(res.get("reason", "Không thể thuê.")))
	_refresh_ui()

func _on_toggle_chef() -> void:
	world.automation.chef_enabled = not world.automation.chef_enabled
	world.save()
	_refresh_ui()

func _on_toggle_chef_prio() -> void:
	world.automation.chef_priority = "first_waiting" if world.automation.chef_priority == "special_first" else "special_first"
	world.save()
	_refresh_ui()

func _on_upgrade_chef() -> void:
	var res := world.automation.upgrade_chef(world.wallet)
	if bool(res.get("ok", false)):
		_add_log("⬆️ Nâng cấp Đầu bếp lên Lv.%d (-%d xu)!" % [int(res.get("new_level", 2)), int(res.get("cost", 0))])
		world.save()
	else:
		_add_log("⚠️ %s" % String(res.get("reason", "Không thể nâng cấp.")))
	_refresh_ui()

func _on_switch_character() -> void:
	var new_char := world.home.switch_character()
	_add_log("👤 Đã chuyển sang điều khiển %s." % world.home.get_character_label())
	world.save()
	_refresh_ui()

func _on_couple_moment() -> void:
	var res := world.home.trigger_couple_moment()
	world.goals.record_cozy_action(1)
	_add_log("💞 %s (Khoảnh khắc #%d)" % [String(res.get("text", "")), int(res.get("count", 0))])
	world.save()
	_refresh_ui()

func _on_select_room(rid: String) -> void:
	world.home.select_room(rid)
	_refresh_ui()

func _on_unlock_active_room() -> void:
	var res := world.home.unlock_room(world.home.active_room_id, world.wallet)
	if bool(res.get("ok", false)):
		var r_cfg := world.home.rooms_by_id.get(world.home.active_room_id, {}) as Dictionary
		_add_log("🏠 Đã mở khóa %s (-%d xu)!" % [String(r_cfg.get("display_name", world.home.active_room_id)), int(res.get("cost", 0))])
		world.save()
	else:
		_add_log("⚠️ %s" % String(res.get("reason", "Không thể mở phòng.")))
	_refresh_ui()

func _on_home_slot_clicked(s_idx: int) -> void:
	var rid := world.home.active_room_id
	if not world.home.is_room_unlocked(rid):
		_add_log("⚠️ Hãy mở khóa phòng trước khi đặt đồ.")
		return
	var slots := world.home.get_room_slots(rid)
	var current_fid := String(slots[s_idx]) if s_idx >= 0 and s_idx < slots.size() else ""
	var target_fid := world.home.selected_furniture_id
	if target_fid == "" and current_fid == "":
		_add_log("ℹ️ Hãy mua & chọn một món nội thất bên phải trước khi đặt.")
		return
	# Clicking an occupied slot with the same selected furniture (or no selection) clears it; otherwise places selected furniture.
	var place_id := "" if (current_fid != "" and (target_fid == "" or target_fid == current_fid)) else target_fid
	var res := world.home.place_furniture(rid, s_idx, place_id)
	if bool(res.get("ok", false)):
		if place_id == "":
			_add_log("🧹 Đã dọn ô #%d." % (s_idx + 1))
		else:
			var f_cfg := world.home.items_by_id.get(place_id, {}) as Dictionary
			_add_log("🪑 Đã đặt %s vào ô #%d!" % [String(f_cfg.get("display_name", place_id)), s_idx + 1])
		world.save()
	else:
		_add_log("⚠️ %s" % String(res.get("reason", "Không thể đặt đồ.")))
	_refresh_ui()

func _on_furniture_action(fid: String) -> void:
	if world.home.is_furniture_owned(fid):
		world.home.select_furniture(fid)
		_refresh_ui()
		return
	var res := world.home.buy_furniture(fid, world.wallet)
	if bool(res.get("ok", false)):
		var f_cfg := world.home.items_by_id.get(fid, {}) as Dictionary
		_add_log("🛋️ Đã mua %s (-%d xu)!" % [String(f_cfg.get("display_name", fid)), int(res.get("cost", 0))])
		world.save()
	else:
		_add_log("⚠️ %s" % String(res.get("reason", "Không thể mua nội thất.")))
	_refresh_ui()

func _on_pet_miu_miu() -> void:
	var res := world.pets.pet_miu_miu(world.home)
	world.goals.record_cozy_action(1)
	_add_log("🐾 %s" % String(res.get("text", "")))
	world.save()
	_refresh_ui()

func _on_play_miu_miu() -> void:
	var res := world.pets.play_with_miu_miu(world.home)
	world.goals.record_cozy_action(1)
	_add_log("🧶 %s" % String(res.get("text", "")))
	world.save()
	_refresh_ui()

func _on_feed_miu_miu() -> void:
	var res := world.pets.feed_miu_miu(world.inventory, "carrot")
	if bool(res.get("ok", false)):
		world.goals.record_cozy_action(1)
		_add_log("🥕 %s" % String(res.get("text", "")))
		world.save()
	else:
		_add_log("ℹ️ %s" % String(res.get("reason", "")))
	_refresh_ui()

func _on_pet_item_action(iid: String) -> void:
	if world.pets.is_item_owned(iid):
		world.pets.equip_item(iid)
		world.save()
		_refresh_ui()
		return
	var res := world.pets.buy_item(iid, world.wallet)
	if bool(res.get("ok", false)):
		var cfg := world.pets.items_by_id.get(iid, {}) as Dictionary
		_add_log("🧸 Đã mua %s cho Miu Miu (-%d xu)!" % [String(cfg.get("display_name", iid)), int(res.get("cost", 0))])
		world.save()
	else:
		_add_log("⚠️ %s" % String(res.get("reason", "Không thể mua.")))
	_refresh_ui()

func _on_claim_pet_milestone(mid: String) -> void:
	var res := world.pets.claim_milestone(mid, world.wallet, world.progression)
	if bool(res.get("ok", false)):
		_add_log("🏆 Nhận thưởng bộ sưu tập Miu Miu: +%d xu, +%d XP!" % [int(res.get("coins", 0)), int(res.get("xp", 0))])
		if bool(res.get("leveled_up", false)):
			_add_log("⭐ Lên cấp Lv.%d!" % int(res.get("new_level", 1)))
		world.save()
	else:
		_add_log("⚠️ %s" % String(res.get("reason", "Chưa thể nhận thưởng.")))
	_refresh_ui()

func _on_unlock_garage() -> void:
	var res := world.garage.unlock(world.progression.level, world.wallet)
	if bool(res.get("ok", false)):
		_add_log("🚚 Đã mở khóa Ga-ra Giao Hàng (-%d xu)!" % int(res.get("cost", 0)))
		world.save()
	else:
		_add_log("⚠️ %s" % String(res.get("reason", "Không thể mở khóa Ga-ra.")))
	_refresh_ui()

func _on_repair_vehicle(vid: String) -> void:
	var res := world.garage.repair_vehicle(vid, world.progression.level, world.wallet, world.inventory)
	if bool(res.get("ok", false)):
		var v_cfg := world.garage.vehicles_by_id.get(vid, {}) as Dictionary
		_add_log("🔧 Đã sửa xong %s (-%d xu)!" % [String(v_cfg.get("display_name", vid)), int(res.get("cost", 0))])
		world.save()
	else:
		_add_log("⚠️ %s" % String(res.get("reason", "Không thể sửa xe.")))
	_refresh_ui()

func _on_upgrade_garage_speed() -> void:
	var res := world.garage.upgrade_speed(world.wallet)
	if bool(res.get("ok", false)):
		_add_log("⚡ Nâng tốc độ Ga-ra lên Lv.%d (-%d xu)!" % [int(res.get("new_level", 2)), int(res.get("cost", 0))])
		world.save()
	else:
		_add_log("⚠️ %s" % String(res.get("reason", "Không thể nâng cấp.")))
	_refresh_ui()

func _on_upgrade_garage_capacity() -> void:
	var res := world.garage.upgrade_capacity(world.wallet)
	if bool(res.get("ok", false)):
		_add_log("📦 Nâng sức chứa đội xe lên Lv.%d (-%d xu)!" % [int(res.get("new_level", 2)), int(res.get("cost", 0))])
		world.save()
	else:
		_add_log("⚠️ %s" % String(res.get("reason", "Không thể nâng cấp.")))
	_refresh_ui()

func _on_toggle_garage_auto() -> void:
	world.garage.auto_dispatch_enabled = not world.garage.auto_dispatch_enabled
	_add_log("🤖 Tự động Ga-ra: %s" % ("BẬT" if world.garage.auto_dispatch_enabled else "TẮT"))
	world.save()
	_refresh_ui()

func _on_start_delivery(rid: String) -> void:
	var res := world.garage.start_delivery(rid, world.progression.level, world.inventory, world.clock)
	if bool(res.get("ok", false)):
		world.garage.auto_route_id = rid
		var r_cfg := world.garage.routes_by_id.get(rid, {}) as Dictionary
		_add_log("🚚 Đã xuất phát giao tuyến '%s'!" % String(r_cfg.get("display_name", rid)))
		world.save()
	else:
		_add_log("⚠️ %s" % String(res.get("reason", "Không thể giao hàng.")))
	_refresh_ui()

func _on_claim_delivery(idx: int) -> void:
	var res := world.garage.claim_delivery(idx, world.wallet, world.progression, world.home, world.pets)
	if bool(res.get("ok", false)):
		world.goals.record_delivery(1)
		var msg := "✅ Hoàn thành giao hàng: +%d xu, +%d XP!" % [int(res.get("coins", 0)), int(res.get("xp", 0))]
		var spec := String(res.get("special", ""))
		if spec != "":
			msg += " 🎁 Quà đặc biệt: %s!" % spec
		_add_log(msg)
		if bool(res.get("leveled_up", false)):
			_add_log("⭐ Lên cấp Lv.%d!" % int(res.get("new_level", 1)))
		world.save()
	else:
		_add_log("⚠️ %s" % String(res.get("reason", "Chưa thể nhận.")))
	_refresh_ui()

func _on_select_area(aid: String) -> void:
	world.neighborhood.select_area(aid)
	_refresh_ui()

func _on_unlock_active_area() -> void:
	var aid := world.neighborhood.active_area_id
	var res := world.neighborhood.unlock_area(aid, world.progression.level, world.wallet)
	if bool(res.get("ok", false)):
		var a_cfg := world.neighborhood.areas_by_id.get(aid, {}) as Dictionary
		_add_log("🏘️ Đã mở khóa %s (-%d xu)!" % [String(a_cfg.get("display_name", aid)), int(res.get("cost", 0))])
		world.save()
	else:
		_add_log("⚠️ %s" % String(res.get("reason", "Không thể mở khu vực.")))
	_refresh_ui()

func _on_build_active_area() -> void:
	var aid := world.neighborhood.active_area_id
	var res := world.neighborhood.build_area_project(aid, world.wallet, world.inventory)
	if bool(res.get("ok", false)):
		_add_log("🔨 Hoàn thành công trình '%s' (-%d xu)!" % [String(res.get("build_name", "")), int(res.get("cost", 0))])
		world.save()
	else:
		_add_log("⚠️ %s" % String(res.get("reason", "Không thể xây công trình.")))
	_refresh_ui()

func _on_chat_npc(nid: String) -> void:
	var res := world.neighborhood.chat_with_npc(nid)
	if bool(res.get("ok", false)):
		world.goals.record_cozy_action(1)
		_add_log("💬 %s" % String(res.get("text", "")))
		world.save()
	else:
		_add_log("⚠️ %s" % String(res.get("reason", "")))
	_refresh_ui()

func _on_help_npc(nid: String) -> void:
	var res := world.neighborhood.fulfill_npc_request(nid, world.inventory, world.wallet, world.progression)
	if bool(res.get("ok", false)):
		world.goals.record_npc_help(1)
		_add_log("🤝 Giúp hàng xóm thành công: +%d xu, +%d XP!" % [int(res.get("coins", 0)), int(res.get("xp", 0))])
		if bool(res.get("leveled_up", false)):
			_add_log("⭐ Lên cấp Lv.%d!" % int(res.get("new_level", 1)))
		world.save()
	else:
		_add_log("⚠️ %s" % String(res.get("reason", "Chưa đủ vật phẩm.")))
	_refresh_ui()

func _on_claim_npc_story(nid: String) -> void:
	var res := world.neighborhood.claim_story_milestone(nid, world.wallet, world.progression, world.home, world.pets)
	if bool(res.get("ok", false)):
		var msg := "📖 Mở khóa câu chuyện '%s': +%d xu, +%d XP!" % [String(res.get("title", "")), int(res.get("coins", 0)), int(res.get("xp", 0))]
		var spec := String(res.get("special", ""))
		if spec != "":
			msg += " 🎁 Quà: %s!" % spec
		_add_log(msg)
		if bool(res.get("leveled_up", false)):
			_add_log("⭐ Lên cấp Lv.%d!" % int(res.get("new_level", 1)))
		world.save()
	else:
		_add_log("⚠️ %s" % String(res.get("reason", "Chưa thể nhận câu chuyện.")))
	_refresh_ui()

func _on_refresh_daily() -> void:
	world.goals.refresh_daily_optional()
	_add_log("🔄 Đã làm mới mục tiêu ngày (tùy chọn).")
	world.save()
	_refresh_ui()

func _on_claim_daily(oid: String) -> void:
	var res := world.goals.claim_daily(oid, world.wallet, world.progression)
	if bool(res.get("ok", false)):
		_add_log("☀️ Hoàn thành mục tiêu ngày: +%d xu, +%d XP!" % [int(res.get("coins", 0)), int(res.get("xp", 0))])
		if bool(res.get("leveled_up", false)):
			_add_log("⭐ Lên cấp Lv.%d!" % int(res.get("new_level", 1)))
		world.save()
	else:
		_add_log("⚠️ %s" % String(res.get("reason", "")))
	_refresh_ui()

func _on_claim_weekly(wid: String) -> void:
	var res := world.goals.claim_weekly(wid, world.wallet, world.progression)
	if bool(res.get("ok", false)):
		_add_log("📅 Hoàn thành mục tiêu tuần: +%d xu, +%d XP!" % [int(res.get("coins", 0)), int(res.get("xp", 0))])
		if bool(res.get("leveled_up", false)):
			_add_log("⭐ Lên cấp Lv.%d!" % int(res.get("new_level", 1)))
		world.save()
	else:
		_add_log("⚠️ %s" % String(res.get("reason", "")))
	_refresh_ui()

func _on_claim_lt_milestone(mid: String) -> void:
	var c_score := world.goals.get_collection_score(world.home, world.pets, world.neighborhood)
	var res := world.goals.claim_milestone(mid, c_score, world.wallet, world.progression, world.home)
	if bool(res.get("ok", false)):
		var msg := "🏆 Hoàn thành cột mốc dài hạn: +%d xu, +%d XP!" % [int(res.get("coins", 0)), int(res.get("xp", 0))]
		var spec := String(res.get("special", ""))
		if spec != "":
			msg += " 🎁 Quà: %s!" % spec
		_add_log(msg)
		if bool(res.get("leveled_up", false)):
			_add_log("⭐ Lên cấp Lv.%d!" % int(res.get("new_level", 1)))
		world.save()
	else:
		_add_log("⚠️ %s" % String(res.get("reason", "")))
	_refresh_ui()

func _on_advance_clock(seconds: int, label_text: String) -> void:
	world.clock.advance(seconds)
	var matured := world.farm.tick(world.clock)
	var crafted := world.production.tick(world.clock)
	var cooked := world.restaurant.tick(world.clock)
	var delivered := world.garage.tick(world.clock)
	var auto_res := world.step_automation()
	_add_log("⏩ Tua %s (+%s). Chín: %d | Chế biến: %d | Hủ tiếu: %d | Auto phục vụ: %d." % [
		label_text,
		GameClock.format_duration(world.clock.get_offset()),
		matured, crafted, cooked,
		int(auto_res["dishes_served"])
	])
	world.save()
	_refresh_ui()

func _on_reset_clock() -> void:
	var old_now := world.clock.now()
	world.clock.reset()
	world.farm.rebase_growing_timers(old_now, world.clock.now())
	_add_log("🕰 Đã đặt lại offset thời gian về +00:00 (giữ tiến độ cây).")
	world.save()
	_refresh_ui()

func _on_manual_save() -> void:
	if world.save():
		_add_log("💾 Đã lưu tiến trình (save_version: %d)." % SaveManager.SAVE_VERSION)
	else:
		_add_log("❌ Lưu game thất bại!")

func _on_manual_reload() -> void:
	var res := world.load_state()
	if bool(res.get("loaded", false)):
		_add_log("🔄 Đã tải lại save v%d!" % int(res.get("save_version", SaveManager.SAVE_VERSION)))
	else:
		_add_log("❌ Tải lại thất bại (%s)." % String(res.get("error", "unknown")))
	_refresh_ui()

func _on_reset_game() -> void:
	world.reset_game()
	_add_log("🗑 Đã reset game về trạng thái ban đầu.")
	_refresh_ui()

func _refresh_ui() -> void:
	var next_xp := world.progression.get_next_level_xp()
	status_label.text = "💰 Xu: %d  |  ⭐ Lv.%d (XP: %d/%d)  |  📦 Kho: %d/%d  |  📋 Hoàn thành: %d" % [
		world.wallet.balance,
		world.progression.level,
		world.progression.xp,
		next_xp,
		world.inventory.get_total_count(),
		world.inventory.capacity,
		world.progression.completed_orders
	]
	next_goal_label.text = "🎯 Mục tiêu tiếp theo: %s" % world.progression.get_next_goal_text()

	var dt := Time.get_datetime_dict_from_unix_time(world.clock.now())
	clock_label.text = "🕒 %02d:%02d:%02d (+%s)" % [
		int(dt["hour"]), int(dt["minute"]), int(dt["second"]),
		GameClock.format_duration(world.clock.get_offset())
	]

	for t in tab_buttons.keys():
		(tab_buttons[t] as Button).modulate = Color("ffd54f") if t == active_tab else Color("b0bec5")

	# Refresh Farm Tab
	for cid in crop_buttons.keys():
		var cfg := world.get_crop_cfg(String(cid))
		var c_btn := crop_buttons[cid] as Button
		var unlocked := world.is_crop_unlocked(String(cid))
		if unlocked:
			c_btn.text = "%s\n-%dxu | %s | +%d" % [
				String(cfg.get("display_name", cid)),
				int(cfg.get("seed_cost", 5)),
				GameClock.format_duration(int(cfg.get("grow_duration_sec", 5))),
				int(cfg.get("harvest_yield", 1))
			]
			c_btn.modulate = Color("ffd54f") if cid == world.selected_crop_id else Color("cfd8dc")
		else:
			var req_lv := UnlockRules.get_required_level_for_crop(String(cid), world.progression)
			c_btn.text = "🔒 %s\n(Cần Lv.%d)" % [String(cfg.get("display_name", cid)), req_lv]
			c_btn.modulate = Color("78909c")

	var sel_cfg := world.get_selected_crop_cfg()
	var sel_name := String(sel_cfg.get("display_name", world.selected_crop_id))
	var sel_cost := int(sel_cfg.get("seed_cost", 5))
	var now_unix := world.clock.now()
	for i in range(world.farm.plots.size()):
		if i >= plot_buttons.size():
			break
		var plot := world.farm.plots[i]
		var btn := plot_buttons[i]
		match plot.state:
			FarmPlot.State.EMPTY:
				btn.text = "[  .  ] #%d TRỐNG\nTrồng %s (-%dxu)" % [i + 1, sel_name, sel_cost]
				btn.modulate = Color("dcedc8")
			FarmPlot.State.GROWING:
				var p_cfg := world.get_crop_cfg(plot.crop_id)
				var rem := plot.timer.get_remaining_seconds(now_unix)
				var filled := clampi(int(round(plot.timer.get_progress(now_unix) * 8.0)), 0, 8)
				btn.text = "[~*~] #%d %s\n[%s] %s" % [i + 1, String(p_cfg.get("display_name", plot.crop_id)), "#".repeat(filled) + "-".repeat(8 - filled), GameClock.format_duration(rem)]
				btn.modulate = Color("fff59d")
			FarmPlot.State.READY:
				var p_cfg := world.get_crop_cfg(plot.crop_id)
				btn.text = "[\\|/] #%d %s CHÍN\nThu hoạch (+%d)" % [i + 1, String(p_cfg.get("display_name", plot.crop_id)), int(p_cfg.get("harvest_yield", 1))]
				btn.modulate = Color("80e27e")
			FarmPlot.State.LOCKED:
				var req_lv := UnlockRules.get_required_level_for_plot(i)
				if world.progression.level >= req_lv:
					btn.text = "[XXX] #%d KHÓA\nMở (-%d xu)" % [i + 1, world.farm_upgrade.unlock_cost]
				else:
					btn.text = "[XXX] #%d KHÓA\nCần Lv.%d" % [i + 1, req_lv]
				btn.modulate = Color("b0bec5")

	# Refresh Orders Tab
	for idx in range(order_slot_labels.size()):
		var slot := world.order_board.get_slot(idx)
		var lbl := order_slot_labels[idx]
		var d_btn := order_deliver_buttons[idx]
		var s_btn := order_skip_buttons[idx]
		if slot.is_empty():
			lbl.text = "Không có đơn."
			d_btn.disabled = true
			continue
		var tag := "[ĐẶC BIỆT]" if String(slot.get("type", "standard")) == "special" else "[THƯỜNG]"
		var reqs: Dictionary = slot.get("requirements", {}) as Dictionary
		var req_parts: Array[String] = []
		for r_id in reqs.keys():
			var r_cfg := world.get_item_cfg(String(r_id))
			var have := world.inventory.get_count(String(r_id))
			var need := int(reqs[r_id])
			req_parts.append("%s: %d/%d" % [String(r_cfg.get("display_name", r_id)), have, need])
		lbl.text = "%s %s\nYêu cầu: %s  →  Thưởng: +%d xu, +%d XP" % [
			tag,
			String(slot.get("title", "Đơn hàng")),
			" | ".join(req_parts),
			int(slot.get("reward_coins", 0)),
			int(slot.get("reward_xp", 0))
		]
		d_btn.disabled = not world.order_board.can_deliver_slot(idx, world.inventory)
		var cd := world.order_board.get_refresh_remaining_sec(idx, world.clock)
		s_btn.text = "🔄 Đổi (%s)" % GameClock.format_duration(cd) if cd > 0 else "🔄 Đổi đơn"
		s_btn.disabled = cd > 0

	# Refresh Production Tab
	for rid in prod_recipe_buttons.keys():
		var row := prod_recipe_buttons[rid] as Dictionary
		var r_cfg := world.production.get_recipe(String(rid))
		var inputs: Dictionary = r_cfg.get("inputs", {}) as Dictionary
		var in_parts: Array[String] = []
		for k in inputs.keys():
			var icfg := world.get_item_cfg(String(k))
			in_parts.append("%s %d/%d" % [String(icfg.get("display_name", k)), world.inventory.get_count(String(k)), int(inputs[k])])
		var req_lv := int(r_cfg.get("min_level", 1))
		var lv_tag := "" if world.progression.level >= req_lv else " [🔒 Lv.%d]" % req_lv
		(row["label"] as Label).text = "%s%s (+%d | %s | bán %dxu)\nCần: %s" % [
			String(r_cfg.get("display_name", rid)),
			lv_tag,
			int(r_cfg.get("output_yield", 1)),
			GameClock.format_duration(int(r_cfg.get("duration_sec", 10))),
			int(r_cfg.get("sell_price", 10)),
			", ".join(in_parts)
		]
		var can_make := world.production.can_start_recipe(String(rid), world.inventory, world.progression.level)
		(row["btn"] as Button).disabled = not bool(can_make.get("ok", false))

	prod_queue_header.text = "🏭 HÀNG ĐỢI CHẾ BIẾN (%d / %d slot)" % [world.production.queue.size(), world.production.max_slots]
	for idx in range(prod_queue_buttons.size()):
		var q_btn := prod_queue_buttons[idx]
		if idx >= world.production.max_slots:
			q_btn.visible = false
			continue
		q_btn.visible = true
		if idx < world.production.queue.size():
			var job := world.production.queue[idx]
			var st := String(job.get("status", "QUEUED"))
			var d_name := String(job.get("display_name", ""))
			var y_amt := int(job.get("output_yield", 1))
			if st == "READY":
				q_btn.text = "[\\|/] %s (+%d) — XONG! Click để thu" % [d_name, y_amt]
				q_btn.modulate = Color("80e27e")
				q_btn.disabled = false
			elif st == "PROCESSING":
				var started := int(job.get("started_at_unix", now_unix))
				var dur := maxi(1, int(job.get("duration_sec", 10)))
				var rem := maxi(0, (started + dur) - now_unix)
				var prog := clampf(float(now_unix - started) / float(dur), 0.0, 1.0)
				var filled := clampi(int(round(prog * 8.0)), 0, 8)
				q_btn.text = "[~*~] %s [%s] %s" % [d_name, "#".repeat(filled) + "-".repeat(8 - filled), GameClock.format_duration(rem)]
				q_btn.modulate = Color("fff59d")
				q_btn.disabled = true
			else:
				q_btn.text = "[...] %s — Đang chờ lượt" % d_name
				q_btn.modulate = Color("cfd8dc")
				q_btn.disabled = true
		else:
			q_btn.text = "[ . ] Slot #%d — Trống" % (idx + 1)
			q_btn.modulate = Color("90a4ae")
			q_btn.disabled = true

	if world.production.max_slots < world.production.max_slots_cap:
		var p_cost := world.production.get_next_slot_upgrade_cost()
		prod_upgrade_button.text = "🔓 Mở +1 slot (-%dxu)" % p_cost
		prod_upgrade_button.disabled = not world.production.can_upgrade_slot(world.wallet)
	else:
		prod_upgrade_button.text = "Slot tối đa (%d)" % world.production.max_slots_cap
		prod_upgrade_button.disabled = true

	# Refresh Restaurant Tab
	rest_lock_box.visible = not world.restaurant.is_unlocked
	rest_active_box.visible = world.restaurant.is_unlocked
	if not world.restaurant.is_unlocked:
		rest_lock_label.text = "🔒 QUÁN HỦ TIẾU CHƯA MỞ\nĐiều kiện: Đạt Level %d và %d xu" % [world.restaurant.unlock_level, world.restaurant.unlock_cost]
		rest_unlock_button.text = "🔓 Mở Quán Hủ Tiếu (-%d xu)" % world.restaurant.unlock_cost
		var u_chk := world.restaurant.can_unlock_restaurant(world.wallet, world.progression.level)
		rest_unlock_button.disabled = not bool(u_chk.get("ok", false))
	else:
		for did in rest_dish_rows.keys():
			var row := rest_dish_rows[did] as Dictionary
			var d_cfg := world.restaurant.get_dish(String(did))
			var unlocked := world.restaurant.unlocked_dishes.has(String(did))
			var lbl := row["label"] as Label
			var btn := row["btn"] as Button
			if not unlocked:
				lbl.text = "🔒 %s (Phục vụ khách đặc biệt để mở)" % String(d_cfg.get("display_name", did))
				btn.disabled = true
			else:
				var inputs: Dictionary = d_cfg.get("inputs", {}) as Dictionary
				var in_parts: Array[String] = []
				for k in inputs.keys():
					var icfg := world.get_item_cfg(String(k))
					in_parts.append("%s %d/%d" % [String(icfg.get("display_name", k)), world.inventory.get_count(String(k)), int(inputs[k])])
				lbl.text = "%s (%s | +%dxu +%dXP)\n%s" % [
					String(d_cfg.get("display_name", did)),
					GameClock.format_duration(int(d_cfg.get("cook_duration_sec", 8))),
					int(d_cfg.get("reward_coins", 50)),
					int(d_cfg.get("reward_xp", 25)),
					", ".join(in_parts)
				]
				btn.disabled = not bool(world.restaurant.can_cook(String(did), world.inventory).get("ok", false))

		var k_parts: Array[String] = []
		for job in world.restaurant.cooking_queue:
			var st := String(job.get("status", "COOKING"))
			if st == "READY":
				k_parts.append("[XONG: %s]" % String(job.get("display_name", "")))
			else:
				var rem := maxi(0, (int(job.get("started_at_unix", now_unix)) + int(job.get("duration_sec", 8))) - now_unix)
				k_parts.append("[%s %s]" % [String(job.get("display_name", "")), GameClock.format_duration(rem)])
		rest_kitchen_label.text = "🔥 Bếp (%d/%d): %s  |  Đã phục vụ: %d" % [
			world.restaurant.cooking_queue.size(),
			world.restaurant.kitchen_slots,
			" | ".join(k_parts) if not k_parts.is_empty() else "(Trống)",
			world.restaurant.served_count
		]

		if world.restaurant.kitchen_slots < world.restaurant.max_kitchen_slots:
			var kc := world.restaurant.get_next_kitchen_upgrade_cost()
			rest_kitchen_upg_btn.text = "+1 Nồi (-%dxu)" % kc
			rest_kitchen_upg_btn.disabled = not world.wallet.can_afford(kc)
		else:
			rest_kitchen_upg_btn.text = "Bếp tối đa"
			rest_kitchen_upg_btn.disabled = true

		if world.restaurant.table_slots < world.restaurant.max_table_slots:
			var tc := world.restaurant.get_next_table_upgrade_cost()
			rest_table_upg_btn.text = "+1 Bàn (-%dxu)" % tc
			rest_table_upg_btn.disabled = not world.wallet.can_afford(tc)
		else:
			rest_table_upg_btn.text = "Bàn tối đa"
			rest_table_upg_btn.disabled = true

		for idx in range(rest_cust_rows.size()):
			var r := rest_cust_rows[idx] as Dictionary
			var card := r["card"] as Control
			if idx >= world.restaurant.table_slots or idx >= world.restaurant.customers.size():
				card.visible = false
				continue
			card.visible = true
			var cust := world.restaurant.customers[idx]
			var dish_id := String(cust.get("dish_id", ""))
			var dish_name := String(world.restaurant.get_dish(dish_id).get("display_name", dish_id))
			var tag := "🌟 [ĐẶC BIỆT]" if String(cust.get("type", "normal")) == "special" else "🙂"
			(r["label"] as Label).text = "%s %s\nMuốn ăn: %s" % [tag, String(cust.get("name", "Khách")), dish_name]
			(r["serve"] as Button).disabled = (world.restaurant.find_ready_dish_idx(dish_id) == -1)

	# Refresh Automation Tab
	var off_sum := world.automation.last_offline_summary
	var off_txt := "Chưa có phiên offline nào."
	if not off_sum.is_empty() and int(off_sum.get("capped_offline_sec", 0)) > 0:
		off_txt = "Offline gần nhất: %s (tính %s) | Thu %d chế biến | Phục vụ %d tô (+%d xu, +%d XP)" % [
			GameClock.format_duration(int(off_sum.get("raw_offline_sec", 0))),
			GameClock.format_duration(int(off_sum.get("capped_offline_sec", 0))),
			int(off_sum.get("crafted_collected", 0)),
			int(off_sum.get("dishes_served", 0)),
			int(off_sum.get("coins_earned", 0)),
			int(off_sum.get("xp_earned", 0))
		]
	auto_offline_label.text = "🌙 TỰ ĐỘNG & OFFLINE (Trần tối đa: %s | Chỉ dùng nguyên liệu thật)\n%s" % [
		GameClock.format_duration(world.automation.max_offline_sec),
		off_txt
	]

	var prep_cost := int(world.automation.prep_cfg.get("hire_cost", 90))
	if not world.automation.prep_hired:
		auto_prep_label.text = "🤖 Phụ bếp Chế biến — Chưa thuê (Thuê giá %d xu)\nTự động thu thành phẩm & đưa công thức ưu tiên vào hàng đợi." % prep_cost
		auto_prep_hire_btn.text = "Thuê (-%d xu)" % prep_cost
		auto_prep_hire_btn.disabled = not world.wallet.can_afford(prep_cost)
		auto_prep_toggle_btn.visible = false
		auto_prep_prio_btn.visible = false
		auto_prep_upg_btn.visible = false
	else:
		var prio_name := "Tự động" if world.automation.prep_priority_recipe == "auto" else String(world.get_item_cfg(world.automation.prep_priority_recipe).get("display_name", world.automation.prep_priority_recipe))
		auto_prep_label.text = "🤖 Phụ bếp Chế biến — Lv.%d (%s) | Ưu tiên: %s" % [
			world.automation.prep_level,
			"ĐANG BẬT" if world.automation.prep_enabled else "TẠM DỪNG",
			prio_name
		]
		auto_prep_hire_btn.visible = false
		auto_prep_toggle_btn.visible = true
		auto_prep_toggle_btn.text = "Tạm dừng" if world.automation.prep_enabled else "Bật lại"
		auto_prep_prio_btn.visible = true
		auto_prep_prio_btn.text = "Ưu tiên: %s" % prio_name
		auto_prep_upg_btn.visible = true
		var p_upg := world.automation.get_prep_upgrade_cost()
		if p_upg > 0:
			auto_prep_upg_btn.text = "Nâng Lv.%d (-%d xu)" % [world.automation.prep_level + 1, p_upg]
			auto_prep_upg_btn.disabled = not world.wallet.can_afford(p_upg)
		else:
			auto_prep_upg_btn.text = "Cấp tối đa"
			auto_prep_upg_btn.disabled = true

	var chef_cost := int(world.automation.chef_cfg.get("hire_cost", 160))
	if not world.automation.chef_hired:
		auto_chef_label.text = "👨‍🍳 Đầu bếp Hủ Tiếu — Chưa thuê (Cần mở Quán Hủ Tiếu & %d xu)\nTự động nấu & phục vụ khách từ kho nguyên liệu thật." % chef_cost
		auto_chef_hire_btn.text = "Thuê (-%d xu)" % chef_cost
		auto_chef_hire_btn.disabled = (not world.restaurant.is_unlocked) or (not world.wallet.can_afford(chef_cost))
		auto_chef_toggle_btn.visible = false
		auto_chef_prio_btn.visible = false
		auto_chef_upg_btn.visible = false
	else:
		var c_prio_txt := "Khách Đặc Biệt trước" if world.automation.chef_priority == "special_first" else "Theo thứ tự bàn"
		auto_chef_label.text = "👨‍🍳 Đầu bếp Hủ Tiếu — Lv.%d (%s) | Ưu tiên: %s" % [
			world.automation.chef_level,
			"ĐANG BẬT" if world.automation.chef_enabled else "TẠM DỪNG",
			c_prio_txt
		]
		auto_chef_hire_btn.visible = false
		auto_chef_toggle_btn.visible = true
		auto_chef_toggle_btn.text = "Tạm dừng" if world.automation.chef_enabled else "Bật lại"
		auto_chef_prio_btn.visible = true
		auto_chef_prio_btn.text = "Ưu tiên: %s" % c_prio_txt
		auto_chef_upg_btn.visible = true
		var c_upg := world.automation.get_chef_upgrade_cost()
		if c_upg > 0:
			auto_chef_upg_btn.text = "Nâng Lv.%d (-%d xu)" % [world.automation.chef_level + 1, c_upg]
			auto_chef_upg_btn.disabled = not world.wallet.can_afford(c_upg)
		else:
			auto_chef_upg_btn.text = "Cấp tối đa"
			auto_chef_upg_btn.disabled = true

	# Refresh Home Tab
	var owned_cnt := world.home.get_owned_count()
	var total_f := world.home.item_ids_sorted.size()
	home_header_label.text = "🏠 Đang điều khiển: %s  |  Bộ sưu tập: %d/%d món  |  Khoảnh khắc: %d" % [
		world.home.get_character_label(),
		owned_cnt,
		total_f,
		world.home.cozy_moments_count
	]
	if world.home.last_moment != "":
		home_moment_label.text = "💞 %s" % world.home.last_moment
	else:
		home_moment_label.text = "💞 Nhấn 'Khoảnh khắc đôi' để xem Boy & Girl tương tác nhẹ nhàng trong nhà."

	for rid: String in home_room_buttons.keys():
		var r_btn := home_room_buttons[rid] as Button
		var r_cfg := world.home.rooms_by_id.get(rid, {}) as Dictionary
		var r_name := String(r_cfg.get("display_name", rid))
		var mark := "▶ " if rid == world.home.active_room_id else ""
		var lock_mark := "" if world.home.is_room_unlocked(rid) else " 🔒"
		r_btn.text = "%s%s%s" % [mark, r_name, lock_mark]

	var active_rid := world.home.active_room_id
	var active_unlocked := world.home.is_room_unlocked(active_rid)
	var active_rcfg := world.home.rooms_by_id.get(active_rid, {}) as Dictionary
	if active_unlocked:
		home_room_unlock_btn.visible = false
	else:
		var r_cost := int(active_rcfg.get("unlock_cost", 0))
		home_room_unlock_btn.visible = true
		home_room_unlock_btn.text = "🔓 Mở khóa %s (-%d xu)" % [String(active_rcfg.get("display_name", active_rid)), r_cost]
		home_room_unlock_btn.disabled = not world.wallet.can_afford(r_cost)

	var r_slots := world.home.get_room_slots(active_rid)
	for s_idx in range(home_slot_buttons.size()):
		var s_btn := home_slot_buttons[s_idx]
		if not active_unlocked:
			s_btn.text = "[🔒 Ô #%d]\n(Chưa mở khóa)" % (s_idx + 1)
			s_btn.disabled = true
			continue
		s_btn.disabled = false
		var placed_fid := String(r_slots[s_idx]) if s_idx < r_slots.size() else ""
		if placed_fid == "":
			if world.home.selected_furniture_id != "":
				var home_sel_cfg := world.home.items_by_id.get(world.home.selected_furniture_id, {}) as Dictionary
				s_btn.text = "[  Trống #%d  ]\n(Nhấn để đặt %s)" % [s_idx + 1, String(home_sel_cfg.get("display_name", ""))]
			else:
				s_btn.text = "[  Trống #%d  ]\n(Chọn đồ bên phải)" % (s_idx + 1)
		else:
			var p_cfg := world.home.items_by_id.get(placed_fid, {}) as Dictionary
			s_btn.text = "%s %s\n(Ô #%d — Nhấn để đổi/dọn)" % [
				String(p_cfg.get("ascii", "🪑")),
				String(p_cfg.get("display_name", placed_fid)),
				s_idx + 1
			]

	for fid: String in home_shop_rows.keys():
		var f_row := home_shop_rows[fid] as Dictionary
		var f_cfg := world.home.items_by_id.get(fid, {}) as Dictionary
		var f_lbl := f_row["label"] as Label
		var f_btn := f_row["btn"] as Button
		var f_cost := int(f_cfg.get("cost", 0))
		var owned := world.home.is_furniture_owned(fid)
		var selected := world.home.selected_furniture_id == fid
		f_lbl.text = "%s %s — %s" % [
			String(f_cfg.get("ascii", "🪑")),
			String(f_cfg.get("display_name", fid)),
			"Đã sở hữu" if owned else ("%d xu" % f_cost)
		]
		if owned:
			f_btn.text = "✓ Đang chọn" if selected else "Chọn đặt"
			f_btn.disabled = selected
		else:
			f_btn.text = "Mua (-%dxu)" % f_cost
			f_btn.disabled = not world.wallet.can_afford(f_cost)

	# Refresh Pets Tab
	var pet_owned_cnt := world.pets.get_owned_count()
	var pet_total_cnt := world.pets.item_ids_sorted.size()
	pet_header_label.text = "🐱 Miu Miu (Mèo tam thể)  |  Đồ sở hữu: %d/%d  |  Tương tác: %d" % [
		pet_owned_cnt, pet_total_cnt, world.pets.interactions_count
	]
	pet_portrait_label.text = world.pets.get_ascii_portrait()
	pet_context_label.text = "🏠 " + world.pets.get_home_context_text(world.home)
	pet_reaction_label.text = "💬 " + world.pets.last_reaction

	var beh_lines: Array[String] = ["✨ HÀNH VI & BIỂU CẢM ĐÃ MỞ:"]
	for bid: String in world.pets.behavior_ids_sorted:
		var b_cfg := world.pets.behaviors_by_id[bid] as Dictionary
		var unlocked := world.pets.is_behavior_unlocked(bid)
		var mark := "✅" if unlocked else "🔒"
		beh_lines.append("%s %s" % [mark, String(b_cfg.get("display_name", bid))])
	pet_behaviors_label.text = "\n".join(beh_lines)

	for iid: String in pet_shop_rows.keys():
		var row := pet_shop_rows[iid] as Dictionary
		var cfg := world.pets.items_by_id.get(iid, {}) as Dictionary
		var lbl := row["label"] as Label
		var btn := row["btn"] as Button
		var cost := int(cfg.get("cost", 0))
		var owned := world.pets.is_item_owned(iid)
		var cat := String(cfg.get("category", ""))
		lbl.text = "%s %s (%s) — %s" % [
			String(cfg.get("ascii", "🧸")),
			String(cfg.get("display_name", iid)),
			cat,
			"Đã có" if owned else ("%d xu" % cost)
		]
		if owned:
			if cat == "accessory" or cat == "bed":
				var is_eq := (world.pets.equipped_accessory == iid or world.pets.active_bed == iid)
				btn.text = "✓ Đang dùng" if is_eq else "Đeo / Đặt"
				btn.disabled = false
			else:
				btn.text = "Chơi ngay"
				btn.disabled = false
		else:
			btn.text = "Mua (-%dxu)" % cost
			btn.disabled = not world.wallet.can_afford(cost)

	for mid: String in pet_milestone_rows.keys():
		var m_row := pet_milestone_rows[mid] as Dictionary
		var m_cfg := world.pets.milestones_by_id.get(mid, {}) as Dictionary
		var m_lbl := m_row["label"] as Label
		var m_btn := m_row["btn"] as Button
		var req := int(m_cfg.get("required_items", 999))
		var claimed := world.pets.is_milestone_claimed(mid)
		m_lbl.text = "%s (%d/%d món) — +%d xu, +%d XP" % [
			String(m_cfg.get("display_name", mid)),
			mini(pet_owned_cnt, req),
			req,
			int(m_cfg.get("reward_coins", 0)),
			int(m_cfg.get("reward_xp", 0))
		]
		if claimed:
			m_btn.text = "✓ Đã nhận"
			m_btn.disabled = true
		elif world.pets.can_claim_milestone(mid):
			m_btn.text = "Nhận thưởng"
			m_btn.disabled = false
		else:
			m_btn.text = "Chưa đủ"
			m_btn.disabled = true

	# Refresh Garage Tab
	if not world.garage.is_unlocked:
		garage_lock_box.visible = true
		garage_active_box.visible = false
		garage_lock_label.text = "🔒 GA-RA GIAO HÀNG\nCần Lv.%d và %d xu để mở khóa." % [world.garage.unlock_level, world.garage.unlock_cost]
		garage_unlock_btn.text = "🔓 Mở khóa Ga-ra (-%d xu)" % world.garage.unlock_cost
		garage_unlock_btn.disabled = (world.progression.level < world.garage.unlock_level or not world.wallet.can_afford(world.garage.unlock_cost))
	else:
		garage_lock_box.visible = false
		garage_active_box.visible = true
		garage_header_label.text = "🚚 Chuyến đang chạy: %d/%d  |  Tổng đã giao: %d" % [
			world.garage.active_deliveries.size(), world.garage.get_max_slots(), world.garage.delivered_count
		]
		for vid: String in garage_vehicle_rows.keys():
			var v_row := garage_vehicle_rows[vid] as Dictionary
			var v_cfg := world.garage.vehicles_by_id.get(vid, {}) as Dictionary
			var v_lbl := v_row["label"] as Label
			var v_btn := v_row["btn"] as Button
			var repaired := world.garage.is_vehicle_repaired(vid)
			var req_items := v_cfg.get("repair_items", {}) as Dictionary
			var req_parts: Array[String] = []
			for iid: String in req_items.keys():
				req_parts.append("%s x%d" % [iid, int(req_items[iid])])
			var r_cost := int(v_cfg.get("repair_cost", 0))
			var cost_str := ("Sửa: %d xu" % r_cost) if req_parts.is_empty() else ("Sửa: %d xu + %s" % [r_cost, ", ".join(req_parts)])
			v_lbl.text = "%s %s (Lv.%d) — %s" % [
				String(v_cfg.get("ascii", "🚚")),
				String(v_cfg.get("display_name", vid)),
				int(v_cfg.get("min_level", 2)),
				"Đã sẵn sàng" if repaired else cost_str
			]
			v_btn.text = "✓ Sẵn sàng" if repaired else "🔧 Sửa xe"
			v_btn.disabled = repaired

		var sp_cost := world.garage.get_next_speed_upgrade_cost()
		if sp_cost < 0:
			garage_speed_btn.text = "⚡ Tốc độ tối đa"
			garage_speed_btn.disabled = true
		else:
			garage_speed_btn.text = "⚡ Tốc độ Lv.%d (-%dxu)" % [world.garage.speed_level + 1, sp_cost]
			garage_speed_btn.disabled = not world.wallet.can_afford(sp_cost)

		var cap_cost := world.garage.get_next_capacity_upgrade_cost()
		if cap_cost < 0:
			garage_cap_btn.text = "📦 Đội xe tối đa"
			garage_cap_btn.disabled = true
		else:
			garage_cap_btn.text = "📦 Đội xe Lv.%d (-%dxu)" % [world.garage.capacity_level + 1, cap_cost]
			garage_cap_btn.disabled = not world.wallet.can_afford(cap_cost)

		garage_auto_btn.text = "🤖 Tự động giao (%s): %s" % [
			world.garage.auto_route_id,
			"ĐANG BẬT" if world.garage.auto_dispatch_enabled else "ĐANG TẮT"
		]

		var now_u := world.clock.now()
		for i in range(garage_queue_rows.size()):
			var q_row := garage_queue_rows[i]
			var q_card := q_row["card"] as Control
			if i >= world.garage.active_deliveries.size():
				q_card.visible = false
				continue
			q_card.visible = true
			var job := world.garage.active_deliveries[i]
			var q_lbl := q_row["label"] as Label
			var q_btn := q_row["btn"] as Button
			var st := String(job.get("status", "IN_TRANSIT"))
			if st == "READY":
				q_lbl.text = "✅ %s — Đã tới nơi! (+%dxu, +%dXP)" % [String(job.get("display_name", "")), int(job.get("reward_coins", 0)), int(job.get("reward_xp", 0))]
				q_btn.text = "Nhận thưởng"
				q_btn.disabled = false
			else:
				var end_u := int(job.get("started_at_unix", 0)) + int(job.get("duration_sec", 15))
				var rem := maxi(0, end_u - now_u)
				q_lbl.text = "🚚 %s — Còn %ds" % [String(job.get("display_name", "")), rem]
				q_btn.text = "Đang chạy"
				q_btn.disabled = true

		for rid: String in garage_route_rows.keys():
			var r_row := garage_route_rows[rid] as Dictionary
			var r_cfg := world.garage.routes_by_id.get(rid, {}) as Dictionary
			var r_lbl := r_row["label"] as Label
			var r_btn := r_row["btn"] as Button
			var reqs := r_cfg.get("requirements", {}) as Dictionary
			var req_txt: Array[String] = []
			for iid: String in reqs.keys():
				req_txt.append("%s x%d" % [iid, int(reqs[iid])])
			var bonus := r_cfg.get("first_clear_bonus", {}) as Dictionary
			var spec_txt := ""
			if not bonus.is_empty():
				var claimed := world.garage.claimed_route_rewards.has(rid)
				spec_txt = " | 🎁 Lần đầu: +%dxu, +%dXP%s" % [int(bonus.get("coins", 0)), int(bonus.get("xp", 0)), " ✓" if claimed else ""]
			r_lbl.text = "%s (Lv.%d, %ds) — Cần: %s\nThưởng: +%d xu, +%d XP%s" % [
				String(r_cfg.get("display_name", rid)),
				int(r_cfg.get("min_level", 2)),
				int(round(float(int(r_cfg.get("duration_sec", 15))) * world.garage.get_speed_multiplier())),
				", ".join(req_txt),
				int(r_cfg.get("reward_coins", 0)),
				int(r_cfg.get("reward_xp", 0)),
				spec_txt
			]
			var can_go := world.garage.can_start_delivery(rid, world.progression.level, world.inventory)
			r_btn.text = "Xuất phát" if world.garage.is_route_unlocked(rid, world.progression.level) else "🔒 Khóa"
			r_btn.disabled = not can_go

	# Refresh Neighborhood Tab
	neigh_story_label.text = "📖 " + world.neighborhood.last_story_text
	for aid: String in neigh_area_buttons.keys():
		var a_btn := neigh_area_buttons[aid] as Button
		var a_cfg := world.neighborhood.areas_by_id.get(aid, {}) as Dictionary
		var mark := "▶ " if aid == world.neighborhood.active_area_id else ""
		var lock_m := "" if world.neighborhood.is_area_unlocked(aid) else " 🔒"
		a_btn.text = "%s%s%s" % [mark, String(a_cfg.get("display_name", aid)), lock_m]

	var act_aid := world.neighborhood.active_area_id
	var act_acfg := world.neighborhood.areas_by_id.get(act_aid, {}) as Dictionary
	var a_unlocked := world.neighborhood.is_area_unlocked(act_aid)
	var a_built := world.neighborhood.is_area_built(act_aid)
	neigh_area_ascii_label.text = "%s\n\n%s\n%s" % [
		String(act_acfg.get("ascii_art", "")),
		String(act_acfg.get("display_name", act_aid)),
		"✅ Công trình '%s' đã hoàn thành!" % String(act_acfg.get("build_name", "")) if a_built else ("🔒 Khu vực chưa mở (Lv.%d)" % int(act_acfg.get("min_level", 1)) if not a_unlocked else "✨ Khu vực đã mở — có thể xây công trình!")
	]
	if a_unlocked:
		neigh_area_unlock_btn.visible = false
	else:
		var u_cost := int(act_acfg.get("unlock_cost", 0))
		neigh_area_unlock_btn.visible = true
		neigh_area_unlock_btn.text = "🔓 Mở %s (Lv.%d, -%dxu)" % [String(act_acfg.get("display_name", act_aid)), int(act_acfg.get("min_level", 1)), u_cost]
		neigh_area_unlock_btn.disabled = (world.progression.level < int(act_acfg.get("min_level", 1)) or not world.wallet.can_afford(u_cost))

	if not a_unlocked or a_built:
		neigh_area_build_btn.visible = false
	else:
		neigh_area_build_btn.visible = true
		var b_items := act_acfg.get("build_items", {}) as Dictionary
		var b_parts: Array[String] = []
		for iid: String in b_items.keys():
			b_parts.append("%s x%d" % [iid, int(b_items[iid])])
		var b_cost := int(act_acfg.get("build_cost", 0))
		neigh_area_build_btn.text = "🔨 Xây %s (-%dxu, %s)" % [String(act_acfg.get("build_name", "")), b_cost, ", ".join(b_parts)]
		neigh_area_build_btn.disabled = not world.wallet.can_afford(b_cost)

	for nid: String in neigh_npc_rows.keys():
		var row := neigh_npc_rows[nid] as Dictionary
		var n_cfg := world.neighborhood.npcs_by_id.get(nid, {}) as Dictionary
		var lbl := row["label"] as Label
		var chat_b := row["chat"] as Button
		var help_b := row["help"] as Button
		var story_b := row["story"] as Button
		var reqs := n_cfg.get("request", {}) as Dictionary
		var req_parts: Array[String] = []
		for iid: String in reqs.keys():
			req_parts.append("%s x%d" % [iid, int(reqs[iid])])
		var helps := int(world.neighborhood.npc_helps.get(nid, 0))
		var aid_n := String(n_cfg.get("area_id", ""))
		var area_open := world.neighborhood.is_area_unlocked(aid_n)
		lbl.text = "%s %s | Thích: %s\nYêu cầu: %s (+%dxu, +%dXP) | Đã giúp: %d" % [
			String(n_cfg.get("ascii", "( ^_^ )")),
			String(n_cfg.get("display_name", nid)),
			String(n_cfg.get("preference", "")),
			", ".join(req_parts),
			int(n_cfg.get("reward_coins", 0)),
			int(n_cfg.get("reward_xp", 0)),
			helps
		]
		chat_b.disabled = not area_open
		help_b.text = "🤝 Giao đồ" if area_open else "🔒 Khu khóa"
		help_b.disabled = not area_open
		if world.neighborhood.is_story_claimed(nid):
			story_b.text = "✓ Đã đọc truyện"
			story_b.disabled = true
		elif world.neighborhood.can_claim_story(nid):
			story_b.text = "📖 Nhận truyện"
			story_b.disabled = false
		else:
			story_b.text = "📖 Khóa"
			story_b.disabled = true

	# Refresh Goals & Collections Tab
	var coll_score := world.goals.get_collection_score(world.home, world.pets, world.neighborhood)
	goals_rec_label.text = world.goals.get_next_recommendation(coll_score)
	goals_coll_label.text = "📚 Sưu tầm tổng hợp (%d điểm): 🌱 Nông sản %d/%d | ⚙️ Công thức %d/%d | 🍜 Món Hủ Tiếu %d/%d | 🏠 Nội thất %d/%d | 🐱 Đồ Miu Miu %d/%d | 🏘️ Khu phố %d/%d" % [
		coll_score,
		world.goals.discovered_crops.size(), world.crop_ids_sorted.size(),
		world.goals.discovered_recipes.size(), world.production.recipe_ids_sorted.size(),
		world.goals.discovered_dishes.size(), world.restaurant.dish_ids_sorted.size(),
		world.home.owned_furniture.size(), world.home.item_ids_sorted.size(),
		world.pets.owned_items.size(), world.pets.item_ids_sorted.size(),
		world.neighborhood.built_areas.size() + world.neighborhood.claimed_stories.size(),
		world.neighborhood.area_ids_sorted.size() + world.neighborhood.npc_ids_sorted.size()
	]

	for obj in world.goals.daily_cfg:
		var oid := String(obj.get("id", ""))
		var row := goals_daily_rows.get(oid, {}) as Dictionary
		if row.is_empty():
			continue
		var lbl := row["label"] as Label
		var btn := row["btn"] as Button
		var prog := world.goals.get_daily_progress(obj)
		var target := int(obj.get("target", 1))
		lbl.text = "%s (%d/%d) — +%dxu, +%dXP" % [
			String(obj.get("display_name", oid)), mini(prog, target), target,
			int(obj.get("reward_coins", 0)), int(obj.get("reward_xp", 0))
		]
		if world.goals.claimed_daily.has(oid):
			btn.text = "✓ Đã nhận"
			btn.disabled = true
		elif world.goals.can_claim_daily(oid):
			btn.text = "Nhận thưởng"
			btn.disabled = false
		else:
			btn.text = "Đang làm"
			btn.disabled = true

	for w in world.goals.weekly_cfg:
		var wid := String(w.get("id", ""))
		var row := goals_weekly_rows.get(wid, {}) as Dictionary
		if row.is_empty():
			continue
		var lbl := row["label"] as Label
		var btn := row["btn"] as Button
		var reqs := w.get("requirements", {}) as Dictionary
		var parts: Array[String] = []
		for k: String in reqs.keys():
			parts.append("%s %d/%d" % [k, mini(int(world.goals.weekly_metrics.get(k, 0)), int(reqs[k])), int(reqs[k])])
		lbl.text = "%s\n(%s) — +%dxu, +%dXP" % [
			String(w.get("display_name", wid)), ", ".join(parts),
			int(w.get("reward_coins", 0)), int(w.get("reward_xp", 0))
		]
		if world.goals.claimed_weekly.has(wid):
			btn.text = "✓ Đã nhận"
			btn.disabled = true
		elif world.goals.can_claim_weekly(wid):
			btn.text = "Nhận thưởng"
			btn.disabled = false
		else:
			btn.text = "Đang làm"
			btn.disabled = true

	for m in world.goals.milestones_cfg:
		var mid := String(m.get("id", ""))
		var row := goals_lt_rows.get(mid, {}) as Dictionary
		if row.is_empty():
			continue
		var lbl := row["label"] as Label
		var btn := row["btn"] as Button
		var prog := world.goals.get_milestone_progress(m, coll_score)
		var target := int(m.get("target", 1))
		lbl.text = "%s (%d/%d) — +%dxu, +%dXP" % [
			String(m.get("display_name", mid)), mini(prog, target), target,
			int(m.get("reward_coins", 0)), int(m.get("reward_xp", 0))
		]
		if world.goals.claimed_milestones.has(mid):
			btn.text = "✓ Đã nhận"
			btn.disabled = true
		elif world.goals.can_claim_milestone(mid, coll_score):
			btn.text = "Nhận thưởng"
			btn.disabled = false
		else:
			btn.text = "Chưa đạt"
			btn.disabled = true

	# Refresh Inventory Tab
	inv_header_label.text = "📦 Sức chứa kho: %d / %d (Trống: %d)" % [
		world.inventory.get_total_count(),
		world.inventory.capacity,
		world.inventory.get_free_space()
	]
	for cid in inv_item_rows.keys():
		var row := inv_item_rows[cid] as Dictionary
		var cfg := world.get_item_cfg(String(cid))
		var owned := world.inventory.get_count(String(cid))
		var price := int(cfg.get("sell_price", 5))
		(row["label"] as Label).text = "%s — Tồn kho: %d  (Giá bán: %d xu/cái)" % [String(cfg.get("display_name", cid)), owned, price]
		var b1 := row["sell1"] as Button
		b1.text = "Bán 1 (+%dxu)" % price
		b1.disabled = owned < 1
		var ball := row["sell_all"] as Button
		ball.text = "Bán hết (%d)" % owned
		ball.disabled = owned < 1

	# Refresh Upgrades Tab
	var locked_cnt := world.farm.get_locked_count()
	if locked_cnt > 0:
		var next_pid := world.farm.get_first_locked_plot_id()
		var req_lv := UnlockRules.get_required_level_for_plot(next_pid)
		plot_upgrade_label.text = "🌾 Mở rộng vườn: Còn %d ô khóa | Ô tiếp theo (#%d) cần Lv.%d & %d xu" % [locked_cnt, next_pid + 1, req_lv, world.farm_upgrade.unlock_cost]
		plot_upgrade_button.disabled = not world.can_unlock_next_plot()
	else:
		plot_upgrade_label.text = "🌾 Đã mở khóa toàn bộ %d ô đất!" % world.farm.plots.size()
		plot_upgrade_button.disabled = true

	var max_cap := int(world.inv_upgrade_cfg.get("max_capacity", 100))
	if world.inventory.capacity < max_cap:
		var u_cost := world.get_next_inventory_upgrade_cost()
		inv_upgrade_label.text = "📦 Nâng cấp kho: Hiện tại %d/%d | +%d sức chứa giá %d xu" % [world.inventory.capacity, max_cap, int(world.inv_upgrade_cfg.get("capacity_step", 10)), u_cost]
		inv_upgrade_button.text = "Nâng kho +%d (-%dxu)" % [int(world.inv_upgrade_cfg.get("capacity_step", 10)), u_cost]
		inv_upgrade_button.disabled = not world.can_upgrade_inventory()
	else:
		inv_upgrade_label.text = "📦 Kho đã đạt sức chứa tối đa (%d)." % max_cap
		inv_upgrade_button.text = "Đã tối đa"
		inv_upgrade_button.disabled = true

	var m_lines: Array[String] = ["⭐ CỘT MỐC CẤP ĐỘ & MỞ KHÓA:"]
	for row_lv in world.progression.levels_data:
		var lv := int(row_lv.get("level", 1))
		var mark := "✅" if world.progression.level >= lv else "🔒"
		m_lines.append("%s Lv.%d (%d XP): %s" % [mark, lv, int(row_lv.get("xp_required", 0)), String(row_lv.get("goal", ""))])
	milestone_label.text = "\n".join(m_lines)

func _add_log(msg: String) -> void:
	log_lines.append(msg)
	if log_lines.size() > 30:
		log_lines.pop_front()
	if is_instance_valid(log_label):
		log_label.text = "\n".join(log_lines)
