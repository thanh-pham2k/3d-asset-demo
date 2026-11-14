extends Control
## ASCII Presentation layer for Phase 1 VERY MVP.
## Only reads Game Core state and invokes Game Core methods.

var clock: GameClock
var wallet: Wallet
var inventory: Inventory
var farm: FarmSystem
var order_board: OrderBoard
var farm_upgrade: FarmUpgrade

var crop_cfg: Dictionary = {}
var order_cfg: Dictionary = {}
var upgrade_cfg: Dictionary = {}

var status_label: Label
var clock_label: Label
var order_label: Label
var order_button: Button
var upgrade_label: Label
var upgrade_button: Button
var plot_buttons: Array[Button] = []
var log_label: RichTextLabel
var log_lines: Array[String] = []

var _refresh_accum: float = 0.0

func _ready() -> void:
	_init_game_core()
	_build_ascii_ui()
	_load_initial_state()
	_refresh_ui()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and clock != null:
		SaveManager.save_game(clock, wallet, inventory, farm)

func _process(delta: float) -> void:
	if farm == null or clock == null:
		return
	var matured := farm.tick(clock)
	if matured > 0:
		_add_log("🌱 %d ô cà rốt đã chín! Click [ \\|/ ] để thu hoạch." % matured)
		SaveManager.save_game(clock, wallet, inventory, farm)
	_refresh_accum += delta
	if _refresh_accum >= 0.25 or matured > 0:
		_refresh_accum = 0.0
		_refresh_ui()

func _init_game_core() -> void:
	crop_cfg = BalanceLoader.load_crop_carrot()
	order_cfg = BalanceLoader.load_order_carrot()
	upgrade_cfg = BalanceLoader.load_farm_upgrade()

	clock = GameClock.new()
	wallet = Wallet.new(int(upgrade_cfg.get("starting_coins", 100)))
	inventory = Inventory.new()
	farm = FarmSystem.new(
		int(upgrade_cfg.get("total_plots", 6)),
		int(upgrade_cfg.get("initial_unlocked_plots", 4))
	)
	order_board = OrderBoard.new(order_cfg)
	farm_upgrade = FarmUpgrade.new(upgrade_cfg)

func _load_initial_state() -> void:
	var res := SaveManager.load_game(clock, wallet, inventory, farm)
	if bool(res.get("loaded", false)):
		var offline_sec := int(res.get("offline_elapsed", 0))
		var matured := int(res.get("matured_count", 0))
		_add_log("💾 Đã tải save (v%d). Thời gian offline: %s | Cây chín thêm: %d." % [
			int(res.get("save_version", 1)),
			GameClock.format_duration(offline_sec),
			matured
		])
	else:
		_add_log("🌾 Chào mừng đến Couple Chaos 3D (ASCII VERY MVP)!")
		_add_log("👉 Click ô [ . ] để trồng cà rốt (-%d xu)." % int(crop_cfg.get("seed_cost", 5)))

func _build_ascii_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color("171b22")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(root_vbox)

	# 1. Header Banner
	var title := Label.new()
	title.text = "=== COUPLE CHAOS 3D — PHASE 1: ASCII VERY MVP (HAY DAY LOOP) ==="
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("ffd54f"))
	root_vbox.add_child(title)

	# 2. HUD Status & Clock Bar
	var hud_panel := PanelContainer.new()
	root_vbox.add_child(hud_panel)
	var hud_hbox := HBoxContainer.new()
	hud_hbox.add_theme_constant_override("separation", 20)
	hud_panel.add_child(hud_hbox)

	status_label = Label.new()
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color("a5d6a7"))
	hud_hbox.add_child(status_label)

	clock_label = Label.new()
	clock_label.add_theme_font_size_override("font_size", 15)
	clock_label.add_theme_color_override("font_color", Color("80d8ff"))
	hud_hbox.add_child(clock_label)

	# 3. Debug Time Travel & Save Controls
	var tools_hbox := HBoxContainer.new()
	tools_hbox.add_theme_constant_override("separation", 8)
	root_vbox.add_child(tools_hbox)

	var debug_title := Label.new()
	debug_title.text = "⏱ Tua thời gian:"
	debug_title.add_theme_color_override("font_color", Color("b0bec5"))
	tools_hbox.add_child(debug_title)

	for step in [
		{"label": "+1 phút", "sec": 60},
		{"label": "+5 phút", "sec": 300},
		{"label": "+1 giờ", "sec": 3600}
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

	# 4. ASCII Farm Grid
	var grid_panel := PanelContainer.new()
	grid_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(grid_panel)

	var grid_vbox := VBoxContainer.new()
	grid_vbox.add_theme_constant_override("separation", 10)
	grid_panel.add_child(grid_vbox)

	var grid_header := Label.new()
	grid_header.text = "VƯỜN CÀ RỐT (Click ô để Trồng / Thu hoạch / Mở khóa)"
	grid_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grid_header.add_theme_font_size_override("font_size", 15)
	grid_header.add_theme_color_override("font_color", Color("ffe082"))
	grid_vbox.add_child(grid_header)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid_vbox.add_child(grid)

	plot_buttons.clear()
	for plot in farm.plots:
		var p_btn := Button.new()
		p_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		p_btn.custom_minimum_size = Vector2(220, 110)
		p_btn.pressed.connect(_on_plot_clicked.bind(plot.id))
		grid.add_child(p_btn)
		plot_buttons.append(p_btn)

	# 5. Order Board & Farm Upgrade Row
	var actions_hbox := HBoxContainer.new()
	actions_hbox.add_theme_constant_override("separation", 16)
	root_vbox.add_child(actions_hbox)

	var order_panel := PanelContainer.new()
	order_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_hbox.add_child(order_panel)
	var order_vbox := VBoxContainer.new()
	order_vbox.add_theme_constant_override("separation", 6)
	order_panel.add_child(order_vbox)

	order_label = Label.new()
	order_label.add_theme_font_size_override("font_size", 15)
	order_vbox.add_child(order_label)

	order_button = Button.new()
	order_button.text = "📦 Giao Đơn Hàng"
	order_button.custom_minimum_size = Vector2(0, 40)
	order_button.pressed.connect(_on_deliver_order)
	order_vbox.add_child(order_button)

	var upgrade_panel := PanelContainer.new()
	upgrade_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_hbox.add_child(upgrade_panel)
	var upgrade_vbox := VBoxContainer.new()
	upgrade_vbox.add_theme_constant_override("separation", 6)
	upgrade_panel.add_child(upgrade_vbox)

	upgrade_label = Label.new()
	upgrade_label.add_theme_font_size_override("font_size", 15)
	upgrade_vbox.add_child(upgrade_label)

	upgrade_button = Button.new()
	upgrade_button.text = "🔓 Mở Khóa Ô Đất Mới"
	upgrade_button.custom_minimum_size = Vector2(0, 40)
	upgrade_button.pressed.connect(_on_unlock_next_plot)
	upgrade_vbox.add_child(upgrade_button)

	# 6. Activity Log
	var log_panel := PanelContainer.new()
	log_panel.custom_minimum_size = Vector2(0, 120)
	root_vbox.add_child(log_panel)

	log_label = RichTextLabel.new()
	log_label.scroll_following = true
	log_label.fit_content = false
	log_label.add_theme_font_size_override("normal_font_size", 14)
	log_panel.add_child(log_label)

func _on_plot_clicked(plot_id: int) -> void:
	var plot := farm.get_plot(plot_id)
	if plot == null:
		return

	match plot.state:
		FarmPlot.State.EMPTY:
			var res := farm.plant_plot(plot_id, crop_cfg, wallet, clock)
			if bool(res.get("ok", false)):
				_add_log("🌱 Đã trồng %s tại Ô #%d (-%d xu)." % [
					String(crop_cfg.get("display_name", "Cà rốt")),
					plot_id + 1,
					int(res.get("cost", 5))
				])
				SaveManager.save_game(clock, wallet, inventory, farm)
			else:
				_add_log("⚠️ %s" % String(res.get("reason", "Không thể trồng.")))
		FarmPlot.State.GROWING:
			var rem := plot.timer.get_remaining_seconds(clock.now())
			_add_log("⏳ Ô #%d đang lớn — còn %s." % [plot_id + 1, GameClock.format_duration(rem)])
		FarmPlot.State.READY:
			var res := farm.harvest_plot(plot_id, crop_cfg, inventory)
			if bool(res.get("ok", false)):
				_add_log("🥕 Thu hoạch Ô #%d: +%d cà rốt vào kho!" % [
					plot_id + 1,
					int(res.get("yield", 2))
				])
				SaveManager.save_game(clock, wallet, inventory, farm)
			else:
				_add_log("⚠️ %s" % String(res.get("reason", "Không thể thu hoạch.")))
		FarmPlot.State.LOCKED:
			var res := farm_upgrade.unlock_specific_plot(plot_id, farm, wallet)
			if bool(res.get("ok", false)):
				_add_log("🔓 Đã mở khóa Ô #%d (-%d xu)!" % [plot_id + 1, int(res.get("cost", 120))])
				SaveManager.save_game(clock, wallet, inventory, farm)
			else:
				_add_log("⚠️ %s" % String(res.get("reason", "Chưa đủ xu mở khóa.")))

	_refresh_ui()

func _on_deliver_order() -> void:
	var res := order_board.deliver(inventory, wallet)
	if bool(res.get("ok", false)):
		_add_log("📦 Giao đơn thành công (%d cà rốt) → Nhận +%d xu!" % [
			int(res.get("delivered", 4)),
			int(res.get("reward", 60))
		])
		SaveManager.save_game(clock, wallet, inventory, farm)
	else:
		_add_log("⚠️ %s" % String(res.get("reason", "Không thể giao đơn.")))
	_refresh_ui()

func _on_unlock_next_plot() -> void:
	var res := farm_upgrade.unlock_next_plot(farm, wallet)
	if bool(res.get("ok", false)):
		_add_log("🔓 Đã mở khóa Ô #%d (-%d xu)!" % [
			int(res.get("plot_id", 0)) + 1,
			int(res.get("cost", 120))
		])
		SaveManager.save_game(clock, wallet, inventory, farm)
	else:
		_add_log("⚠️ %s" % String(res.get("reason", "Không thể mở khóa.")))
	_refresh_ui()

func _on_advance_clock(seconds: int, label_text: String) -> void:
	clock.advance(seconds)
	var matured := farm.tick(clock)
	_add_log("⏩ Tua thời gian %s (Offset: +%s). Cây chín mới: %d." % [
		label_text,
		GameClock.format_duration(clock.get_offset()),
		matured
	])
	SaveManager.save_game(clock, wallet, inventory, farm)
	_refresh_ui()

func _on_reset_clock() -> void:
	clock.reset()
	_add_log("🕰 Đã đặt lại offset thời gian giả lập về +00:00.")
	SaveManager.save_game(clock, wallet, inventory, farm)
	_refresh_ui()

func _on_manual_save() -> void:
	if SaveManager.save_game(clock, wallet, inventory, farm):
		_add_log("💾 Đã lưu tiến trình (save_version: %d)." % SaveManager.SAVE_VERSION)
	else:
		_add_log("❌ Lưu game thất bại!")

func _on_manual_reload() -> void:
	var res := SaveManager.load_game(clock, wallet, inventory, farm)
	if bool(res.get("loaded", false)):
		_add_log("🔄 Đã tải lại save! Offline: %s | Cây chín thêm: %d." % [
			GameClock.format_duration(int(res.get("offline_elapsed", 0))),
			int(res.get("matured_count", 0))
		])
	else:
		_add_log("⚠️ Chưa có file save để tải.")
	_refresh_ui()

func _on_reset_game() -> void:
	SaveManager.reset_save()
	clock.reset()
	wallet.set_balance(int(upgrade_cfg.get("starting_coins", 100)))
	inventory.set_count("carrot", 0)
	farm.reset_plots(
		int(upgrade_cfg.get("total_plots", 6)),
		int(upgrade_cfg.get("initial_unlocked_plots", 4))
	)
	_add_log("🗑 Đã reset game về trạng thái ban đầu.")
	_refresh_ui()

func _refresh_ui() -> void:
	var carrot_count := inventory.get_count("carrot")
	status_label.text = "💰 Xu: %d   |   🥕 Kho Cà rốt: %d" % [wallet.balance, carrot_count]

	var dt := Time.get_datetime_dict_from_unix_time(clock.now())
	clock_label.text = "🕒 %02d:%02d:%02d (Offset: +%s)" % [
		int(dt["hour"]), int(dt["minute"]), int(dt["second"]),
		GameClock.format_duration(clock.get_offset())
	]

	var now_unix := clock.now()
	var seed_cost := int(crop_cfg.get("seed_cost", 5))
	var yield_amt := int(crop_cfg.get("harvest_yield", 2))

	for i in range(farm.plots.size()):
		if i >= plot_buttons.size():
			break
		var plot := farm.plots[i]
		var btn := plot_buttons[i]
		match plot.state:
			FarmPlot.State.EMPTY:
				btn.text = "[  .  ]\nÔ #%d — TRỐNG\nClick: Trồng (-%d xu)" % [i + 1, seed_cost]
				btn.modulate = Color("dcedc8")
			FarmPlot.State.GROWING:
				var rem := plot.timer.get_remaining_seconds(now_unix)
				var prog := plot.timer.get_progress(now_unix)
				var filled := clampi(int(round(prog * 8.0)), 0, 8)
				var bar := "#".repeat(filled) + "-".repeat(8 - filled)
				btn.text = "[ ~*~ ]\nÔ #%d — ĐANG LỚN\n[%s] %s" % [i + 1, bar, GameClock.format_duration(rem)]
				btn.modulate = Color("fff59d")
			FarmPlot.State.READY:
				btn.text = "[ \\|/ ]\nÔ #%d — CHÍN RỒI!\nClick: Thu hoạch (+%d 🥕)" % [i + 1, yield_amt]
				btn.modulate = Color("80e27e")
			FarmPlot.State.LOCKED:
				btn.text = "[ XXX ]\nÔ #%d — ĐÃ KHÓA\nClick: Mở (-%d xu)" % [i + 1, farm_upgrade.unlock_cost]
				btn.modulate = Color("b0bec5")

	order_label.text = "📋 %s: Cần %d/%d Cà rốt → +%d xu" % [
		order_board.title,
		carrot_count,
		order_board.required_count,
		order_board.reward_coins
	]
	order_button.disabled = not order_board.can_deliver(inventory)

	var locked_cnt := farm.get_locked_count()
	if locked_cnt > 0:
		upgrade_label.text = "🌾 Mở rộng vườn: Còn %d ô khóa | Giá: %d xu" % [locked_cnt, farm_upgrade.unlock_cost]
		upgrade_button.disabled = not farm_upgrade.can_unlock(farm, wallet)
	else:
		upgrade_label.text = "🌾 Đã mở khóa toàn bộ %d ô đất!" % farm.plots.size()
		upgrade_button.disabled = true

func _add_log(msg: String) -> void:
	log_lines.append(msg)
	if log_lines.size() > 30:
		log_lines.pop_front()
	if is_instance_valid(log_label):
		log_label.text = "\n".join(log_lines)
