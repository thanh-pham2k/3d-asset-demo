class_name DailySummaryDialog
extends CanvasLayer

## End-of-Day Summary Dialog for Couple Chaos.
## Displays key business metrics at the conclusion of each workday:
## - Customers served
## - Revenue earned
## - Expenses incurred
## - Net daily profit
## - Household family wallet balance

signal dismissed()

var panel: PanelContainer
var title_label: Label
var subtitle_label: Label
var customers_label: Label
var revenue_label: Label
var expenses_label: Label
var profit_label: Label
var wallet_label: Label
var continue_button: Button

var is_showing: bool = false

func _init() -> void:
	layer = 100

func _ready() -> void:
	_build_ui()
	visible = false

func _build_ui() -> void:
	var shade := ColorRect.new()
	shade.name = "BackgroundShade"
	shade.color = Color(0.08, 0.1, 0.12, 0.75)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 360)
	center.add_child(panel)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color("232c33")
	style.border_color = Color("ffd54f")
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	title_label = Label.new()
	title_label.text = "📋 TỔNG KẾT NGÀY LÀM VIỆC"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color("ffd54f"))
	vbox.add_child(title_label)
	
	subtitle_label = Label.new()
	subtitle_label.text = "Hoàn thành ca làm việc hôm nay"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 13)
	subtitle_label.add_theme_color_override("font_color", Color("b0bec5"))
	vbox.add_child(subtitle_label)
	
	var sep1 := HSeparator.new()
	vbox.add_child(sep1)
	
	# Metric Rows
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(grid)
	
	# 1. Customers served
	var c_title := Label.new()
	c_title.text = "👥 Khách đã phục vụ:"
	c_title.add_theme_font_size_override("font_size", 14)
	grid.add_child(c_title)
	customers_label = Label.new()
	customers_label.text = "0 khách"
	customers_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	customers_label.add_theme_font_size_override("font_size", 15)
	customers_label.add_theme_color_override("font_color", Color("ffffff"))
	grid.add_child(customers_label)
	
	# 2. Revenue earned
	var r_title := Label.new()
	r_title.text = "💰 Doanh thu hôm nay:"
	r_title.add_theme_font_size_override("font_size", 14)
	grid.add_child(r_title)
	revenue_label = Label.new()
	revenue_label.text = "+0 đ"
	revenue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	revenue_label.add_theme_font_size_override("font_size", 15)
	revenue_label.add_theme_color_override("font_color", Color("69f0ae"))
	grid.add_child(revenue_label)
	
	# 3. Expenses
	var e_title := Label.new()
	e_title.text = "💸 Chi phí hôm nay:"
	e_title.add_theme_font_size_override("font_size", 14)
	grid.add_child(e_title)
	expenses_label = Label.new()
	expenses_label.text = "-0 đ"
	expenses_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	expenses_label.add_theme_font_size_override("font_size", 15)
	expenses_label.add_theme_color_override("font_color", Color("ff8a80"))
	grid.add_child(expenses_label)
	
	# 4. Daily profit
	var p_title := Label.new()
	p_title.text = "📈 Lợi nhuận ròng:"
	p_title.add_theme_font_size_override("font_size", 15)
	p_title.add_theme_color_override("font_color", Color("ffd54f"))
	grid.add_child(p_title)
	profit_label = Label.new()
	profit_label.text = "+0 đ"
	profit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	profit_label.add_theme_font_size_override("font_size", 16)
	profit_label.add_theme_color_override("font_color", Color("ffd54f"))
	grid.add_child(profit_label)
	
	var sep2 := HSeparator.new()
	vbox.add_child(sep2)
	
	# Wallet balance row
	var w_box := HBoxContainer.new()
	vbox.add_child(w_box)
	var w_title := Label.new()
	w_title.text = "🏦 Số dư ví gia đình:"
	w_title.add_theme_font_size_override("font_size", 13)
	w_title.add_theme_color_override("font_color", Color("b2dfdb"))
	w_box.add_child(w_title)
	wallet_label = Label.new()
	wallet_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wallet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wallet_label.text = "100,000 đ"
	wallet_label.add_theme_font_size_override("font_size", 14)
	wallet_label.add_theme_color_override("font_color", Color("a7ffeb"))
	w_box.add_child(wallet_label)
	
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	vbox.add_child(spacer)
	
	continue_button = Button.new()
	continue_button.text = "Tiếp Tục — Về Nhà Nghỉ Ngơi (Phím E)"
	continue_button.custom_minimum_size = Vector2(0, 42)
	continue_button.pressed.connect(hide_summary)
	vbox.add_child(continue_button)

func show_summary(data: Dictionary) -> void:
	var day: int = data.get("day", 1)
	var served: int = data.get("customers_served", 0)
	var revenue: int = data.get("revenue", 0)
	var expenses: int = data.get("expenses", 0)
	var profit: int = data.get("profit", revenue - expenses)
	var wallet_bal: int = data.get("wallet_balance", 0)
	var shop: String = data.get("shop_name", "Cửa hàng")
	
	title_label.text = "📋 TỔNG KẾT NGÀY LÀM VIỆC — NGÀY %d" % day
	subtitle_label.text = "Ca làm việc tại: %s" % shop
	customers_label.text = "%d khách" % served
	revenue_label.text = "+%s đ" % HouseholdWallet.format_money(revenue)
	expenses_label.text = "-%s đ" % HouseholdWallet.format_money(expenses)
	
	var sign_str := "+" if profit >= 0 else "-"
	profit_label.text = "%s%s đ" % [sign_str, HouseholdWallet.format_money(absi(profit))]
	if profit > 0:
		profit_label.add_theme_color_override("font_color", Color("69f0ae"))
	elif profit < 0:
		profit_label.add_theme_color_override("font_color", Color("ff5252"))
	else:
		profit_label.add_theme_color_override("font_color", Color("ffd54f"))
	
	wallet_label.text = "%s đ" % HouseholdWallet.format_money(wallet_bal)
	
	visible = true
	is_showing = true
	if is_instance_valid(continue_button):
		continue_button.grab_focus()

func hide_summary() -> void:
	if not visible: return
	visible = false
	is_showing = false
	dismissed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			hide_summary()
