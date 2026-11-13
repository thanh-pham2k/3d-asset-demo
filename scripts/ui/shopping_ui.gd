class_name ShoppingUI
extends CanvasLayer

## In-game Shopping UI for Couple Chaos 3D.
## Provides an interactive, polished shopping modal with category tabs,
## product list/grid, turntable 3D previews, dynamic wallet balance,
## mutual co-op purchase approval, and feedback notifications.

signal shop_opened(store_title: String)
signal shop_closed()
signal product_purchased(product: EconomyProduct)

var is_open: bool = false
var store_title: String = "Cửa Hàng"
var filter_category: String = ""
var filter_target: String = ""
var current_kiosk: Node = null
var current_player: Node = null

var economy_mgr: EconomyManager
var all_store_products: Array[EconomyProduct] = []
var filtered_products: Array[EconomyProduct] = []
var selected_index: int = 0
var active_category_id: String = "all"
var is_awaiting_confirm: bool = false
var pending_coop_product_id: String = ""

# UI Nodes
var backdrop: ColorRect
var main_window: PanelContainer
var title_label: Label
var wallet_label: Label
var category_container: HBoxContainer
var product_list_container: VBoxContainer
var product_scroll: ScrollContainer
var product_buttons: Array[Button] = []

# Details & Preview Nodes
var preview_viewport: SubViewport
var preview_pivot: Node3D
var item_title_label: Label
var item_badge_label: Label
var item_price_label: Label
var item_status_label: Label
var item_desc_label: Label
var feedback_panel: PanelContainer
var feedback_label: Label
var buy_button: Button
var sell_button: Button
var cancel_button: Button
var feedback_timer: float = 0.0
var refresh_pending := false

static func get_or_create(tree: SceneTree) -> ShoppingUI:
	var existing := tree.get_first_node_in_group("shopping_ui") as ShoppingUI
	if is_instance_valid(existing):
		return existing
	var new_ui := ShoppingUI.new()
	new_ui.name = "ShoppingUI"
	var owner := tree.current_scene if is_instance_valid(tree.current_scene) else tree.root
	owner.add_child(new_ui)
	return new_ui

func _init() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	add_to_group("shopping_ui")
	_build_ui()
	visible = false
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	
	call_deferred("_connect_dual_manager")

func _connect_dual_manager() -> void:
	var dual_mgr := get_tree().get_first_node_in_group("dual_confirmation_manager") as DualConfirmationManager
	if is_instance_valid(dual_mgr):
		if not dual_mgr.confirmation_approved.is_connected(_on_dual_approved):
			dual_mgr.confirmation_approved.connect(_on_dual_approved)
		if not dual_mgr.confirmation_declined.is_connected(_on_dual_declined):
			dual_mgr.confirmation_declined.connect(_on_dual_declined)

func _on_dual_approved(_initiator_id: int, _product_name: String, _cost: int) -> void:
	pending_coop_product_id = ""
	# The purchase callback already reports its actual result.

func _on_dual_declined(initiator_id: int, product_name: String, reason: String) -> void:
	if pending_coop_product_id == "": return
	pending_coop_product_id = ""
	if not is_open: return
	match reason:
		"DECLINED_BY_PARTNER":
			var other_id := 2 if initiator_id == 1 else 1
			show_feedback("❌ P%d đã từ chối mua '%s'!" % [other_id, product_name], "error")
		"TIMEOUT":
			show_feedback("⌛ Hết thời gian chờ xác nhận mua '%s'!" % product_name, "warning")
		"INSUFFICIENT_FUNDS":
			show_feedback("⚠️ Không đủ tiền trong ví gia đình!", "error")
		_:
			show_feedback("⚠️ Yêu cầu mua '%s' đã bị hủy!" % product_name, "warning")
	update_ui()

# -----------------------------------------------------------------
# UI Building & Styling
# -----------------------------------------------------------------
func _build_ui() -> void:
	# 1. Darkened Dim Backdrop
	backdrop = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.08, 0.06, 0.10, 0.78)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)
	
	# Click backdrop to close
	backdrop.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			close_shop()
	)
	
	# 2. Centered Window Modal
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	backdrop.add_child(center)
	
	main_window = PanelContainer.new()
	main_window.custom_minimum_size = Vector2(940, 580)
	var win_style := StyleBoxFlat.new()
	win_style.bg_color = Color("231c28") # Warm plum/dark cozy tone
	win_style.border_color = Color("533f5e")
	win_style.set_border_width_all(3)
	win_style.set_corner_radius_all(16)
	win_style.content_margin_left = 22
	win_style.content_margin_right = 22
	win_style.content_margin_top = 18
	win_style.content_margin_bottom = 18
	win_style.shadow_color = Color(0, 0, 0, 0.55)
	win_style.shadow_size = 24
	main_window.add_theme_stylebox_override("panel", win_style)
	center.add_child(main_window)
	
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	main_window.add_child(main_vbox)
	
	# Header Row: Store Name, Wallet Badge, Close Button
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	main_vbox.add_child(header)
	
	title_label = Label.new()
	title_label.text = "Cửa Hàng"
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", Color("fff3cf"))
	header.add_child(title_label)
	
	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)
	
	# Wallet Badge
	var wallet_panel := PanelContainer.new()
	var w_style := StyleBoxFlat.new()
	w_style.bg_color = Color("322338")
	w_style.border_color = Color("ffd54f")
	w_style.set_border_width_all(2)
	w_style.set_corner_radius_all(10)
	w_style.content_margin_left = 12
	w_style.content_margin_right = 14
	w_style.content_margin_top = 4
	w_style.content_margin_bottom = 4
	wallet_panel.add_theme_stylebox_override("panel", w_style)
	header.add_child(wallet_panel)
	
	wallet_label = Label.new()
	wallet_label.text = "💰 Ví: 0 đ"
	wallet_label.add_theme_font_size_override("font_size", 16)
	wallet_label.add_theme_color_override("font_color", Color("ffe082"))
	wallet_panel.add_child(wallet_label)
	
	# Close Button
	var close_btn := Button.new()
	close_btn.text = "  ✕ Đóng  "
	close_btn.custom_minimum_size = Vector2(85, 36)
	var cb_style := StyleBoxFlat.new()
	cb_style.bg_color = Color("432b35")
	cb_style.border_color = Color("e57373")
	cb_style.set_border_width_all(1)
	cb_style.set_corner_radius_all(8)
	close_btn.add_theme_stylebox_override("normal", cb_style)
	close_btn.pressed.connect(close_shop)
	header.add_child(close_btn)
	
	# Category Tabs Row
	var cat_scroll := ScrollContainer.new()
	cat_scroll.custom_minimum_size = Vector2(0, 42)
	cat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	cat_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(cat_scroll)
	
	category_container = HBoxContainer.new()
	category_container.add_theme_constant_override("separation", 8)
	cat_scroll.add_child(category_container)
	
	# Divider
	var h_sep := HSeparator.new()
	var sep_style := StyleBoxLine.new()
	sep_style.color = Color("44354c")
	sep_style.thickness = 1
	h_sep.add_theme_stylebox_override("separator", sep_style)
	main_vbox.add_child(h_sep)
	
	# Content Body: Left List + Right Preview/Details
	var body_hbox := HBoxContainer.new()
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_theme_constant_override("separation", 18)
	main_vbox.add_child(body_hbox)
	
	# LEFT COLUMN: Product List
	var left_vbox := VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(460, 0)
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_hbox.add_child(left_vbox)
	
	product_scroll = ScrollContainer.new()
	product_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	product_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_vbox.add_child(product_scroll)
	
	product_list_container = VBoxContainer.new()
	product_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	product_list_container.add_theme_constant_override("separation", 6)
	product_scroll.add_child(product_list_container)
	
	# RIGHT COLUMN: Preview & Details
	var right_panel := PanelContainer.new()
	right_panel.custom_minimum_size = Vector2(380, 0)
	var rp_style := StyleBoxFlat.new()
	rp_style.bg_color = Color("1a1420")
	rp_style.border_color = Color("3d3146")
	rp_style.set_border_width_all(2)
	rp_style.set_corner_radius_all(12)
	rp_style.content_margin_left = 14
	rp_style.content_margin_right = 14
	rp_style.content_margin_top = 12
	rp_style.content_margin_bottom = 12
	right_panel.add_theme_stylebox_override("panel", rp_style)
	body_hbox.add_child(right_panel)
	
	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 10)
	right_panel.add_child(right_vbox)
	
	# 3D Preview SubViewport
	var view_container := SubViewportContainer.new()
	view_container.custom_minimum_size = Vector2(350, 175)
	view_container.stretch = true
	right_vbox.add_child(view_container)
	
	preview_viewport = SubViewport.new()
	preview_viewport.size = Vector2i(350, 175)
	preview_viewport.own_world_3d = true
	preview_viewport.transparent_bg = true
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view_container.add_child(preview_viewport)
	
	_setup_preview_world()
	
	# Item Name
	item_title_label = Label.new()
	item_title_label.text = "Tên Sản Phẩm"
	item_title_label.add_theme_font_size_override("font_size", 20)
	item_title_label.add_theme_color_override("font_color", Color("fff3cf"))
	item_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_vbox.add_child(item_title_label)
	
	# Meta badges row (Category + Target)
	item_badge_label = Label.new()
	item_badge_label.text = "🏷️ Nội thất · Dành cho Ngôi nhà"
	item_badge_label.add_theme_font_size_override("font_size", 13)
	item_badge_label.add_theme_color_override("font_color", Color("b0bec5"))
	right_vbox.add_child(item_badge_label)
	
	# Price & Status Row
	var price_row := HBoxContainer.new()
	right_vbox.add_child(price_row)
	
	item_price_label = Label.new()
	item_price_label.text = "150,000 đ"
	item_price_label.add_theme_font_size_override("font_size", 20)
	item_price_label.add_theme_color_override("font_color", Color("69f0ae"))
	price_row.add_child(item_price_label)
	
	var pr_spacer := Control.new()
	pr_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	price_row.add_child(pr_spacer)
	
	item_status_label = Label.new()
	item_status_label.text = "Sở hữu: 0"
	item_status_label.add_theme_font_size_override("font_size", 14)
	item_status_label.add_theme_color_override("font_color", Color("ffd54f"))
	price_row.add_child(item_status_label)
	
	# Description
	item_desc_label = Label.new()
	item_desc_label.text = "Mô tả sản phẩm"
	item_desc_label.add_theme_font_size_override("font_size", 14)
	item_desc_label.add_theme_color_override("font_color", Color("d7ccc8"))
	item_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_desc_label.custom_minimum_size = Vector2(0, 48)
	right_vbox.add_child(item_desc_label)
	
	# Feedback Notification Panel
	feedback_panel = PanelContainer.new()
	var fb_style := StyleBoxFlat.new()
	fb_style.bg_color = Color("2d3748")
	fb_style.set_corner_radius_all(8)
	fb_style.content_margin_left = 10
	fb_style.content_margin_right = 10
	fb_style.content_margin_top = 6
	fb_style.content_margin_bottom = 6
	feedback_panel.add_theme_stylebox_override("panel", fb_style)
	feedback_panel.visible = false
	right_vbox.add_child(feedback_panel)
	
	feedback_label = Label.new()
	feedback_label.text = "Thông báo"
	feedback_label.add_theme_font_size_override("font_size", 13)
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_panel.add_child(feedback_label)
	
	# Action Buttons
	var action_box := HBoxContainer.new()
	action_box.add_theme_constant_override("separation", 8)
	right_vbox.add_child(action_box)
	
	buy_button = Button.new()
	buy_button.text = "MUA HÀNG"
	buy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_button.custom_minimum_size = Vector2(0, 44)
	buy_button.pressed.connect(_on_buy_button_pressed)
	action_box.add_child(buy_button)
	
	sell_button = Button.new()
	sell_button.text = "BÁN"
	sell_button.custom_minimum_size = Vector2(110, 44)
	sell_button.visible = false
	sell_button.pressed.connect(_on_sell_button_pressed)
	action_box.add_child(sell_button)
	
	cancel_button = Button.new()
	cancel_button.text = "Hủy"
	cancel_button.custom_minimum_size = Vector2(70, 44)
	cancel_button.visible = false
	cancel_button.pressed.connect(cancel_purchase_confirmation)
	action_box.add_child(cancel_button)
	
	# Footer Bar: Keyboard shortcuts hint
	var footer := HBoxContainer.new()
	main_vbox.add_child(footer)
	
	var hint_label := Label.new()
	hint_label.text = "💡 [W/S / ↑↓] Chọn  ·  [A/D / Tab] Danh mục  ·  [Enter] Mua  ·  [B] Bán  ·  [Esc] Đóng"
	hint_label.add_theme_font_size_override("font_size", 13)
	hint_label.add_theme_color_override("font_color", Color("9e9e9e"))
	footer.add_child(hint_label)

func _setup_preview_world() -> void:
	# Camera
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.8, 2.3)
	preview_viewport.add_child(cam)
	cam.look_at(Vector3(0, 0.35, 0))
	
	# Directional key light
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 45, 0)
	light.light_energy = 1.3
	light.light_color = Color("fff5ea")
	preview_viewport.add_child(light)
	
	# Fill light
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(25, -135, 0)
	fill.light_energy = 0.6
	fill.light_color = Color("dbeafe")
	preview_viewport.add_child(fill)
	
	# Ambient Environment
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.09, 0.15, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e0d6eb")
	env.ambient_light_energy = 0.8
	env_node.environment = env
	preview_viewport.add_child(env_node)
	
	# Turntable Pivot
	preview_pivot = Node3D.new()
	preview_pivot.set_meta("is_furniture_preview", true)
	preview_viewport.add_child(preview_pivot)

# -----------------------------------------------------------------
# Shop Open / Close Lifecycle
# -----------------------------------------------------------------
func open_shop(
	title: String,
	category: String = "",
	target_sys: String = "",
	kiosk: Node = null,
	player_node: Node = null
) -> void:
	# Release the previous initiator and its pending approval before reusing
	# this shared modal for another kiosk or player.
	if is_open:
		close_shop()
	store_title = title
	filter_category = category
	filter_target = target_sys
	current_kiosk = kiosk
	current_player = player_node
	
	economy_mgr = get_tree().get_first_node_in_group("economy_manager") as EconomyManager
	if not is_instance_valid(economy_mgr):
		printerr("ShoppingUI: EconomyManager not found!")
		return
	_connect_economy_signals()
	
	is_open = true
	visible = true
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	is_awaiting_confirm = false
	cancel_button.visible = false
	feedback_panel.visible = false
	
	# Disable player movement
	if is_instance_valid(current_player):
		current_player.set_meta("shopping_open", true)
		current_player.velocity = Vector3.ZERO
	
	title_label.text = "🏪 %s" % store_title
	wallet_label.text = "💰 Ví: %s" % HouseholdWallet.format_money(economy_mgr.wallet.balance)
	
	# Collect store products
	_collect_store_products()
	_setup_category_tabs()
	select_category("all")
	
	shop_opened.emit(store_title)

func close_shop() -> void:
	if not is_open: return
	_cancel_own_coop_request()
	_disconnect_economy_signals()
	is_open = false
	visible = false
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	is_awaiting_confirm = false
	
	# Re-enable player movement
	if is_instance_valid(current_player):
		current_player.remove_meta("shopping_open")
		current_player.set_meta("ui_input_block_until_msec", Time.get_ticks_msec() + 200)
			
	shop_closed.emit()

func _cancel_own_coop_request() -> void:
	if pending_coop_product_id == "" or not is_inside_tree():
		return
	var manager := get_tree().get_first_node_in_group("dual_confirmation_manager") as DualConfirmationManager
	if is_instance_valid(manager) and manager.has_pending_request():
		var callback: Callable = manager.active_request.get("callback", Callable())
		if callback.is_valid() and callback.get_object() == self:
			manager.cancel_request("SHOP_CLOSED")
	pending_coop_product_id = ""

func _exit_tree() -> void:
	_cancel_own_coop_request()
	_disconnect_economy_signals()
	if is_instance_valid(current_player) and current_player.has_meta("shopping_open"):
		current_player.remove_meta("shopping_open")

func _connect_economy_signals() -> void:
	if not economy_mgr.wallet.balance_changed.is_connected(_on_wallet_changed):
		economy_mgr.wallet.balance_changed.connect(_on_wallet_changed)
	if not economy_mgr.inventory.item_count_changed.is_connected(_on_inventory_changed):
		economy_mgr.inventory.item_count_changed.connect(_on_inventory_changed)
	if not economy_mgr.inventory.upgrade_unlocked.is_connected(_on_ownership_changed):
		economy_mgr.inventory.upgrade_unlocked.connect(_on_ownership_changed)
	if not economy_mgr.inventory.furniture_unlocked.is_connected(_on_ownership_changed):
		economy_mgr.inventory.furniture_unlocked.connect(_on_ownership_changed)

func _disconnect_economy_signals() -> void:
	if not is_instance_valid(economy_mgr): return
	if economy_mgr.wallet.balance_changed.is_connected(_on_wallet_changed):
		economy_mgr.wallet.balance_changed.disconnect(_on_wallet_changed)
	if economy_mgr.inventory.item_count_changed.is_connected(_on_inventory_changed):
		economy_mgr.inventory.item_count_changed.disconnect(_on_inventory_changed)
	if economy_mgr.inventory.upgrade_unlocked.is_connected(_on_ownership_changed):
		economy_mgr.inventory.upgrade_unlocked.disconnect(_on_ownership_changed)
	if economy_mgr.inventory.furniture_unlocked.is_connected(_on_ownership_changed):
		economy_mgr.inventory.furniture_unlocked.disconnect(_on_ownership_changed)

func _on_wallet_changed(_balance: int, _delta: int) -> void:
	_schedule_refresh()

func _on_inventory_changed(_product_id: String, _count: int) -> void:
	_schedule_refresh()

func _on_ownership_changed(_product_id: String) -> void:
	_schedule_refresh()

func _schedule_refresh() -> void:
	if not refresh_pending:
		refresh_pending = true
		call_deferred("_refresh_from_economy")

func _refresh_from_economy() -> void:
	refresh_pending = false
	if is_inside_tree() and is_open:
		update_ui()

func _collect_store_products() -> void:
	all_store_products.clear()
	if not is_instance_valid(economy_mgr): return
	
	var catalog_prods: Array = economy_mgr.catalog.values() if filter_category == "" or filter_category == "all" else economy_mgr.get_products_by_category(filter_category)
	for prod in catalog_prods:
		if not prod is EconomyProduct: continue
		
		# Target system filtering
		if filter_target != "" and prod.target_system != filter_target and prod.target_system != "general":
			continue
			
		all_store_products.append(prod)

func _setup_category_tabs() -> void:
	# Clear existing tab buttons
	for child in category_container.get_children():
		category_container.remove_child(child)
		child.queue_free()
		
	var cat_map := {"all": "Tất cả (%d)" % all_store_products.size()}
	
	# Detect subcategories
	for prod in all_store_products:
		var cat_name := _get_category_display_name(prod)
		cat_map[prod.category] = cat_name
		
	for cat_id in cat_map.keys():
		var btn := Button.new()
		btn.text = cat_map[cat_id]
		btn.set_meta("cat_id", cat_id)
		btn.custom_minimum_size = Vector2(100, 34)
		_apply_tab_style(btn, cat_id == active_category_id)
		btn.pressed.connect(select_category.bind(cat_id))
		category_container.add_child(btn)

func _get_category_display_name(prod: EconomyProduct) -> String:
	match prod.category:
		"furniture": return "Nội thất"
		"food_ingredient": return "Nguyên liệu"
		"farming_seed": return "Hạt giống"
		"produce": return "Nông sản"
		"farming": return "Nông trại"
		"repair_tool": return "Phụ tùng"
		"pet": return "Thú cưng"
		"business_upgrade":
			return "Sửa xe" if prod.target_system == "garage" else "Hủ tiếu"
		"house_upgrade": return "Nâng cấp nhà"
		_: return "Khác"

func _apply_tab_style(btn: Button, is_active: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("5c3f6e") if is_active else Color("2c2233")
	style.border_color = Color("69f0ae") if is_active else Color("44354c")
	style.set_border_width_all(2 if is_active else 1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_color_override("font_color", Color("fff3cf") if is_active else Color("b0bec5"))

func select_category(cat_id: String) -> void:
	if cat_id != active_category_id:
		_cancel_own_coop_request()
	active_category_id = cat_id
	filtered_products.clear()
	
	for prod in all_store_products:
		if active_category_id == "all" or prod.category == active_category_id:
			filtered_products.append(prod)
			
	# Update tab visual highlights
	for child in category_container.get_children():
		if child is Button:
			_apply_tab_style(child, child.get_meta("cat_id", "") == active_category_id)
			
	_rebuild_product_list()
	select_product(0)

func _get_category_name_for_id(id: String) -> String:
	match id:
		"furniture": return "Nội thất"
		"food_ingredient": return "Nguyên liệu"
		"repair_tool": return "Phụ tùng"
		"business_upgrade": return "Nâng cấp"
		"house_upgrade": return "Nâng cấp nhà"
		"pet": return "Thú cưng"
		_: return "Tất cả"

# -----------------------------------------------------------------
# Product List & Selection
# -----------------------------------------------------------------
func _rebuild_product_list() -> void:
	for child in product_list_container.get_children():
		product_list_container.remove_child(child)
		child.queue_free()
	product_buttons.clear()
	
	if filtered_products.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Không có sản phẩm nào trong danh mục này!"
		empty_lbl.add_theme_color_override("font_color", Color("9e9e9e"))
		product_list_container.add_child(empty_lbl)
		return
		
	for i in range(filtered_products.size()):
		var prod: EconomyProduct = filtered_products[i]
		var card_btn := Button.new()
		card_btn.custom_minimum_size = Vector2(0, 52)
		card_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_btn.text = "" # Custom styled inside
		
		var card_hbox := HBoxContainer.new()
		card_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_hbox.add_theme_constant_override("separation", 10)
		card_btn.add_child(card_hbox)
		
		# Left icon
		var icon_lbl := Label.new()
		icon_lbl.text = " " + _get_product_icon(prod)
		icon_lbl.add_theme_font_size_override("font_size", 18)
		card_hbox.add_child(icon_lbl)
		
		# Product name
		var name_lbl := Label.new()
		name_lbl.text = prod.name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.add_theme_color_override("font_color", Color("fff3cf"))
		card_hbox.add_child(name_lbl)
		
		# Owned badge if applicable
		var owned_badge := Label.new()
		owned_badge.add_theme_font_size_override("font_size", 12)
		if prod.is_unique and _is_product_owned(prod):
			owned_badge.text = "[ĐÃ SỞ HỮU] "
			owned_badge.add_theme_color_override("font_color", Color("81c784"))
		elif not prod.is_unique:
			var count := _get_owned_count(prod)
			if count > 0:
				owned_badge.text = "[Có: %d] " % count
				owned_badge.add_theme_color_override("font_color", Color("4fc3f7"))
		card_hbox.add_child(owned_badge)
		
		# Price tag
		var price_lbl := Label.new()
		price_lbl.text = HouseholdWallet.format_money(prod.price) + " "
		price_lbl.add_theme_font_size_override("font_size", 14)
		var can_afford := is_instance_valid(economy_mgr) and economy_mgr.wallet.can_afford(prod.price)
		price_lbl.add_theme_color_override("font_color", Color("69f0ae") if can_afford else Color("ef9a9a"))
		card_hbox.add_child(price_lbl)
		
		var final_idx := i
		card_btn.pressed.connect(func(): select_product(final_idx))
		_apply_card_style(card_btn, i == selected_index)
		
		product_list_container.add_child(card_btn)
		product_buttons.append(card_btn)

func _get_product_icon(prod: EconomyProduct) -> String:
	match prod.category:
		"furniture":
			if "sofa" in prod.id: return "🛋️"
			if "bed" in prod.id: return "🛏️"
			if "tv" in prod.id: return "📺"
			if "fridge" in prod.id: return "🧊"
			if "table" in prod.id: return "🪵"
			if "chair" in prod.id: return "🪑"
			if "lamp" in prod.id: return "💡"
			if "plant" in prod.id: return "🪴"
			return "📦"
		"food_ingredient": return "🍲"
		"farming_seed": return "🌱"
		"produce":
			if "lettuce" in prod.id: return "🥬"
			if "tomato" in prod.id: return "🍅"
			if "carrot" in prod.id: return "🥕"
			return "🧺"
		"farming":
			if "seed" in prod.id: return "🌱"
			if "lettuce" in prod.id: return "🥬"
			if "tomato" in prod.id: return "🍅"
			if "carrot" in prod.id: return "🥕"
			return "🌾"
		"repair_tool": return "🔧"
		"business_upgrade": return "⚡"
		"house_upgrade": return "🏡"
		"pet":
			if "cat" in prod.id: return "🐱"
			if "food" in prod.id: return "🐟"
			if "bowl" in prod.id: return "🥣"
			if "bed" in prod.id: return "🛏️"
			if "toy" in prod.id or "wand" in prod.id or "post" in prod.id: return "🧶"
			return "🐾"
		_: return "✨"

func _apply_card_style(btn: Button, is_selected: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("382842") if is_selected else Color("281f2f")
	style.border_color = Color("69f0ae") if is_selected else Color("3d3146")
	style.set_border_width_all(2 if is_selected else 1)
	style.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)

func select_product(index: int) -> void:
	if filtered_products.is_empty():
		_clear_details()
		return
	var next_index := clampi(index, 0, filtered_products.size() - 1)
	if next_index != selected_index:
		_cancel_own_coop_request()
	selected_index = next_index
	
	for i in range(product_buttons.size()):
		_apply_card_style(product_buttons[i], i == selected_index)
		
	# Clear the previous product's confirmation before drawing this one.
	is_awaiting_confirm = false
	cancel_button.visible = false
	var prod: EconomyProduct = filtered_products[selected_index]
	_display_product_details(prod)
	_update_preview_model(prod)

func _clear_details() -> void:
	is_awaiting_confirm = false
	cancel_button.visible = false
	for child in preview_pivot.get_children():
		child.queue_free()
	item_title_label.text = "Không có sản phẩm"
	item_badge_label.text = ""
	item_price_label.text = "0 đ"
	item_status_label.text = ""
	item_desc_label.text = ""
	buy_button.disabled = true
	buy_button.text = "MUA HÀNG"
	sell_button.visible = false

func _display_product_details(prod: EconomyProduct) -> void:
	var is_produce := (prod.category == "produce" or prod.id.begins_with("produce_"))
	var effective_price := economy_mgr.get_effective_product_price(prod) if is_instance_valid(economy_mgr) and economy_mgr.has_method("get_effective_product_price") else prod.price
	var discount_pct := economy_mgr.get_product_discount_percent(prod) if is_instance_valid(economy_mgr) and economy_mgr.has_method("get_product_discount_percent") else 0
	item_title_label.text = prod.name
	item_badge_label.text = "🏷️ %s · Dành cho: %s" % [_get_category_display_name(prod), _get_target_system_label(prod.target_system)]
	if is_produce:
		var bonus_tag := " (🔥 Sự kiện chợ!)" if effective_price > prod.price else ""
		item_price_label.text = "Giá bán: %s%s" % [HouseholdWallet.format_money(effective_price), bonus_tag]
	elif discount_pct > 0:
		item_price_label.text = "%s (Giảm %d%% · Gốc: %s)" % [HouseholdWallet.format_money(effective_price), discount_pct, HouseholdWallet.format_money(prod.price)]
	else:
		item_price_label.text = HouseholdWallet.format_money(effective_price)
	item_desc_label.text = prod.description
	
	# Owned status
	var is_owned := _is_product_owned(prod)
	var count := _get_owned_count(prod)
	if prod.is_unique:
		item_status_label.text = "Trạng thái: ✅ ĐÃ SỞ HỮU" if is_owned else "Trạng thái: Chưa sở hữu"
		item_status_label.add_theme_color_override("font_color", Color("81c784") if is_owned else Color("ffd54f"))
	else:
		item_status_label.text = "Số lượng trong kho: %d cái" % count
		item_status_label.add_theme_color_override("font_color", Color("4fc3f7"))
		
	# Check Co-op condition
	var dual_mgr := get_tree().get_first_node_in_group("dual_confirmation_manager") as DualConfirmationManager
	var needs_coop: bool = is_instance_valid(dual_mgr) and dual_mgr.is_coop_active and effective_price >= 50000
	
	# Buy button state (hidden for harvested produce, which is sold instead of bought)
	buy_button.visible = not is_produce
	var can_afford := is_instance_valid(economy_mgr) and economy_mgr.wallet.can_afford(effective_price)
	var prerequisite := economy_mgr.purchase_prerequisite_message(prod) if is_instance_valid(economy_mgr) else ""
	
	if prod.is_unique and is_owned:
		buy_button.disabled = true
		buy_button.text = "ĐÃ SỞ HỮU"
		_set_button_color(buy_button, Color("455a64"))
	elif prerequisite != "":
		buy_button.disabled = true
		buy_button.text = "CẦN NHÀ CẤP 2"
		item_status_label.text = prerequisite
		item_status_label.add_theme_color_override("font_color", Color("ffb74d"))
		_set_button_color(buy_button, Color("5c2c2c"))
	elif not can_afford:
		buy_button.disabled = true
		buy_button.text = "KHÔNG ĐỦ TIỀN"
		_set_button_color(buy_button, Color("5c2c2c"))
	elif is_awaiting_confirm:
		buy_button.disabled = false
		buy_button.text = "XÁC NHẬN MUA NGAY"
		_set_button_color(buy_button, Color("e65100"))
		cancel_button.visible = true
	elif needs_coop:
		buy_button.disabled = false
		buy_button.text = "🤝 YÊU CẦU ĐỒNG THUẬN"
		_set_button_color(buy_button, Color("0277bd"))
	else:
		buy_button.disabled = false
		buy_button.text = "MUA HÀNG — %s" % HouseholdWallet.format_money(effective_price)
		_set_button_color(buy_button, Color("2e7d32"))
		
	# Produce Sell button
	if is_produce:
		sell_button.visible = true
		if count > 0:
			sell_button.disabled = false
			sell_button.text = "BÁN 1 (+%s)" % HouseholdWallet.format_money(effective_price)
			_set_button_color(sell_button, Color("e67e22"))
		else:
			sell_button.disabled = true
			sell_button.text = "HẾT NÔNG SẢN ĐỂ BÁN"
			_set_button_color(sell_button, Color("455a64"))
	else:
		sell_button.visible = false

func _get_target_system_label(ts: String) -> String:
	match ts:
		"garage": return "Tiệm Sửa Xe máy"
		"hutieu": return "Quán Hủ Tiếu Sa Đéc"
		"house": return "Ngôi nhà chung"
		_: return "Gia đình"

func _set_button_color(btn: Button, col: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = col
	style.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("disabled", style)

# -----------------------------------------------------------------
# 3D Turntable Preview Generation
# -----------------------------------------------------------------
func _update_preview_model(prod: EconomyProduct) -> void:
	for child in preview_pivot.get_children():
		child.queue_free()
		
	var model := _create_preview_model(prod)
	if is_instance_valid(model):
		preview_pivot.add_child(model)

func _create_preview_model(product: EconomyProduct) -> Node3D:
	if product.category == "furniture":
		var furn_model := FurnitureData.create_visual_model(product.id)
		furn_model.scale = Vector3(0.55, 0.55, 0.55)
		return furn_model
		
	var root := Node3D.new()
	
	match product.id:
		# --- House Upgrades ---
		"upg_house_level_2", "upg_house_level_3":
			Art.box(root, Vector3(0, 0.35, 0), Vector3(1.2, 0.7, 0.9), Color("efd0bf"))
			Art.box(root, Vector3(0, 0.85, 0), Vector3(1.35, 0.35, 1.05), Color("b4533c"))
			Art.box(root, Vector3(0, 0.22, 0.46), Vector3(0.28, 0.44, 0.04), Color("8c5432"))
			Art.box(root, Vector3(0.35, 0.45, 0.46), Vector3(0.24, 0.24, 0.04), Color("8dc5d7"))
			root.scale = Vector3(0.7, 0.7, 0.7)
			return root
		"upg_house_tile_yard":
			Art.box(root, Vector3(0, 0.08, 0), Vector3(1.4, 0.16, 1.2), Color("9e785d"))
			for x in [-0.4, 0.0, 0.4]:
				for z in [-0.3, 0.3]:
					Art.box(root, Vector3(x, 0.17, z), Vector3(0.32, 0.02, 0.26), Color("b4533c") if (x+z) > 0 else Color("f5e6d3"))
			Art.box(root, Vector3(-0.5, 0.3, 0), Vector3(0.18, 0.28, 0.18), Color("805b43"))
			Art.box(root, Vector3(0.5, 0.3, 0), Vector3(0.18, 0.28, 0.18), Color("805b43"))
			return root
		"upg_house_flower_garden":
			Art.box(root, Vector3(0, 0.15, 0), Vector3(1.4, 0.3, 0.75), Color("795548"))
			Art.box(root, Vector3(0, 0.31, 0), Vector3(1.3, 0.05, 0.65), Color("3e2723"))
			for x in [-0.4, 0.0, 0.4]:
				Art.ball(root, Vector3(x, 0.45, 0), 0.22, Color("4caf50"))
				Art.ball(root, Vector3(x, 0.6, 0.05), 0.09, Color("e91e63") if x < 0 else (Color("ffeb3b") if x == 0 else Color("ff7043")))
			return root
		"upg_house_modern_kitchen":
			Art.box(root, Vector3(0, 0.32, 0), Vector3(1.3, 0.64, 0.6), Color("343a40"))
			Art.box(root, Vector3(0, 0.68, 0), Vector3(1.36, 0.08, 0.65), Color("2d3134"))
			Art.box(root, Vector3(-0.3, 0.73, 0), Vector3(0.42, 0.02, 0.38), Color("1a1a1c"))
			Art.box(root, Vector3(-0.3, 1.15, 0), Vector3(0.48, 0.22, 0.32), Color("a0a4a8"))
			root.scale = Vector3(0.75, 0.75, 0.75)
			return root
			
		# --- Garage Upgrades & Tools ---
		"upg_garage_second_bay":
			Art.box(root, Vector3(0, 0.1, 0), Vector3(1.3, 0.18, 1.6), Color("212121"))
			Art.box(root, Vector3(0, 0.2, 0), Vector3(0.9, 0.06, 1.4), Color("fbc02d"))
			return root
		"upg_garage_tools":
			Art.box(root, Vector3(0, 0.35, 0), Vector3(0.7, 0.7, 0.5), Color("c62828"))
			Art.box(root, Vector3(0, 0.45, 0.26), Vector3(0.5, 0.05, 0.04), Color("e0e0e0"))
			return root
		"upg_garage_compressor":
			var tank := CylinderMesh.new()
			tank.top_radius = 0.26
			tank.bottom_radius = 0.26
			tank.height = 0.8
			var m := MeshInstance3D.new()
			m.mesh = tank
			m.rotation.z = PI / 2.0
			m.position = Vector3(0, 0.35, 0)
			m.material_override = Art.material(Color("1976d2"))
			root.add_child(m)
			return root
		"tool_repair_kit", "tool_patch_strip":
			Art.box(root, Vector3(0, 0.22, 0), Vector3(0.68, 0.36, 0.42), Color("d32f2f"))
			Art.box(root, Vector3(0, 0.41, 0), Vector3(0.70, 0.04, 0.44), Color("b71c1c"))
			Art.box(root, Vector3(0, 0.46, 0), Vector3(0.28, 0.06, 0.06), Color("cfd8dc"))
			Art.box(root, Vector3(0, 0.24, 0.22), Vector3(0.16, 0.08, 0.03), Color("ffd54f"))
			return root
		"tool_spare_tire":
			var tire := TorusMesh.new()
			tire.inner_radius = 0.25
			tire.outer_radius = 0.48
			var tm := MeshInstance3D.new()
			tm.mesh = tire
			tm.rotation.x = PI / 2.0
			tm.position = Vector3(0, 0.48, 0)
			tm.material_override = Art.material(Color("263238"))
			root.add_child(tm)
			return root
		"tool_air_wrench":
			Art.box(root, Vector3(0, 0.3, 0), Vector3(0.2, 0.45, 0.2), Color("37474f"))
			Art.box(root, Vector3(0, 0.45, 0.18), Vector3(0.18, 0.18, 0.35), Color("90a4ae"))
			return root
			
		# --- Hu Tieu Upgrades & Food Ingredients ---
		"upg_hutieu_extra_table":
			Art.box(root, Vector3(0, 0.38, 0), Vector3(0.8, 0.06, 0.8), Color("8d6e63"))
			Art.box(root, Vector3(0, 0.18, 0), Vector3(0.12, 0.36, 0.12), Color("5d4037"))
			Art.box(root, Vector3(0, 0.85, 0), Vector3(1.1, 0.25, 1.1), Color("e53935"))
			return root
		"upg_hutieu_quick_stove":
			Art.box(root, Vector3(0, 0.3, 0), Vector3(0.8, 0.6, 0.7), Color("78909c"))
			Art.ball(root, Vector3(0, 0.65, 0), 0.26, Color("37474f"))
			Art.ball(root, Vector3(0, 0.1, 0), 0.15, Color("00e5ff"))
			return root
		"upg_hutieu_kitchen_capacity":
			Art.box(root, Vector3(0, 0.35, 0), Vector3(0.9, 0.7, 0.6), Color("b0bec5"))
			Art.box(root, Vector3(0, 0.8, 0), Vector3(0.35, 0.35, 0.35), Color("ffb74d"))
			return root
		"ing_rice_noodle":
			Art.ball(root, Vector3(0, 0.25, 0), 0.38, Color("cfd8dc"))
			Art.ball(root, Vector3(0, 0.35, 0), 0.32, Color("ffffff"))
			return root
		"ing_fresh_shrimp":
			Art.box(root, Vector3(0, 0.15, 0), Vector3(0.7, 0.3, 0.5), Color("8d6e63"))
			Art.ball(root, Vector3(0, 0.28, 0), 0.22, Color("ff7043"))
			return root
		"ing_pork_ribs":
			Art.box(root, Vector3(0, 0.15, 0), Vector3(0.7, 0.3, 0.5), Color("8d6e63"))
			Art.box(root, Vector3(0, 0.25, 0), Vector3(0.45, 0.15, 0.3), Color("c2185b"))
			return root
		"ing_cracklings":
			Art.ball(root, Vector3(0, 0.22, 0), 0.32, Color("cfd8dc"))
			Art.ball(root, Vector3(0, 0.3, 0), 0.26, Color("fbc02d"))
			return root
			
		# --- Pet System Items ---
		"pet_cat_adoption":
			# A preview must not spawn the gameplay cat or register global groups.
			var cat_visual := CatVisual.new()
			cat_visual.scale = Vector3(1.2, 1.2, 1.2)
			root.add_child(cat_visual)
			return root
		"pet_food_salmon":
			var pkg_sc := load("res://scenes/pets/prop_pet_food_package.tscn")
			if pkg_sc:
				var pkg = pkg_sc.instantiate()
				root.add_child(pkg)
				return root
			Art.box(root, Vector3(0, 0.25, 0), Vector3(0.3, 0.45, 0.2), Color("ffd54f"))
			return root
		"furn_pet_food_bowl":
			var bowl_sc := load("res://scenes/pets/prop_food_bowl.tscn")
			if bowl_sc:
				var bowl = bowl_sc.instantiate()
				bowl.scale = Vector3(1.8, 1.8, 1.8)
				root.add_child(bowl)
				return root
			Art.cylinder(root, Vector3(0, 0.1, 0), 0.3, 0.12, Color("9ee0c7"))
			return root
		"furn_pet_water_bowl":
			var wbowl_sc := load("res://scenes/pets/prop_water_bowl.tscn")
			if wbowl_sc:
				var wbowl = wbowl_sc.instantiate()
				wbowl.scale = Vector3(1.8, 1.8, 1.8)
				root.add_child(wbowl)
				return root
			Art.cylinder(root, Vector3(0, 0.1, 0), 0.3, 0.12, Color("a3d9f7"))
			return root
		"furn_pet_bed":
			var bed_sc := load("res://scenes/pets/prop_pet_bed.tscn")
			if bed_sc:
				var bed = bed_sc.instantiate()
				bed.scale = Vector3(1.2, 1.2, 1.2)
				root.add_child(bed)
				return root
			Art.cylinder(root, Vector3(0, 0.12, 0), 0.45, 0.18, Color("f48fb1"))
			return root
		"furn_pet_scratching_post":
			var post_sc := load("res://scenes/pets/prop_scratching_post.tscn")
			if post_sc:
				var post = post_sc.instantiate()
				root.add_child(post)
				return root
			Art.box(root, Vector3(0, 0.05, 0), Vector3(0.5, 0.08, 0.5), Color("d7ccc8"))
			Art.cylinder(root, Vector3(0, 0.45, 0), 0.12, 0.8, Color("d7ccc8"))
			return root
		"furn_pet_toy_wand":
			var wand_sc := load("res://scenes/pets/prop_cat_toy_wand.tscn")
			if wand_sc:
				var wand = wand_sc.instantiate()
				root.add_child(wand)
				return root
			Art.cylinder(root, Vector3(0, 0.3, 0), 0.03, 0.7, Color("ffb74d"))
			return root
		"furn_pet_toy_ball":
			var ball_sc := load("res://scenes/pets/prop_toy_ball.tscn")
			if ball_sc:
				var ball = ball_sc.instantiate()
				ball.scale = Vector3(1.5, 1.5, 1.5)
				root.add_child(ball)
				return root
			Art.ball(root, Vector3(0, 0.2, 0), 0.2, Color("ba68c8"))
			return root
			
		# --- Farming System Items ---
		"seed_lettuce":
			var sc := load("res://scenes/farming/seed_packet_lettuce.tscn")
			if sc:
				var inst: Node3D = sc.instantiate()
				inst.scale = Vector3(2.0, 2.0, 2.0)
				root.add_child(inst)
				return root
			Art.box(root, Vector3(0, 0.25, 0), Vector3(0.25, 0.4, 0.1), Color("81c784"))
			return root
		"seed_tomato":
			var sc := load("res://scenes/farming/seed_packet_tomato.tscn")
			if sc:
				var inst: Node3D = sc.instantiate()
				inst.scale = Vector3(2.0, 2.0, 2.0)
				root.add_child(inst)
				return root
			Art.box(root, Vector3(0, 0.25, 0), Vector3(0.25, 0.4, 0.1), Color("e57373"))
			return root
		"seed_carrot":
			var sc := load("res://scenes/farming/seed_packet_carrot.tscn")
			if sc:
				var inst: Node3D = sc.instantiate()
				inst.scale = Vector3(2.0, 2.0, 2.0)
				root.add_child(inst)
				return root
			Art.box(root, Vector3(0, 0.25, 0), Vector3(0.25, 0.4, 0.1), Color("ffb74d"))
			return root
		"produce_lettuce":
			var sc := load("res://scenes/farming/collectible_lettuce.tscn")
			if sc:
				var inst: Node3D = sc.instantiate()
				inst.scale = Vector3(1.5, 1.5, 1.5)
				root.add_child(inst)
				return root
			Art.ball(root, Vector3(0, 0.25, 0), 0.3, Color("66bb6a"))
			return root
		"produce_tomato":
			var sc := load("res://scenes/farming/collectible_tomato.tscn")
			if sc:
				var inst: Node3D = sc.instantiate()
				inst.scale = Vector3(1.8, 1.8, 1.8)
				root.add_child(inst)
				return root
			Art.ball(root, Vector3(0, 0.25, 0), 0.28, Color("e53935"))
			return root
		"produce_carrot":
			var sc := load("res://scenes/farming/collectible_carrot.tscn")
			if sc:
				var inst: Node3D = sc.instantiate()
				inst.scale = Vector3(1.6, 1.6, 1.6)
				root.add_child(inst)
				return root
			Art.box(root, Vector3(0, 0.3, 0), Vector3(0.2, 0.5, 0.2), Color("fb8c00"))
			return root
			
		_:
			Art.box(root, Vector3(0, 0.3, 0), Vector3(0.5, 0.5, 0.5), Color("9575cd"))
			return root

func _process(delta: float) -> void:
	if is_open and is_instance_valid(preview_pivot):
		preview_pivot.rotation.y += delta * 0.75
		
	if feedback_timer > 0.0:
		feedback_timer -= delta
		if feedback_timer <= 0.0:
			feedback_panel.visible = false

# -----------------------------------------------------------------
# Purchase Execution & Feedback
# -----------------------------------------------------------------
func _on_buy_button_pressed() -> void:
	if filtered_products.is_empty(): return
	var prod: EconomyProduct = filtered_products[selected_index]
	var prerequisite := economy_mgr.purchase_prerequisite_message(prod)
	if prerequisite != "":
		show_feedback("⚠️ " + prerequisite, "warning")
		return
	
	# Block already owned unique items
	if prod.is_unique and _is_product_owned(prod):
		show_feedback("⚠️ Bạn đã sở hữu món đồ này!", "warning")
		return
		
	# Block insufficient funds
	if not economy_mgr.wallet.can_afford(prod.price):
		var needed := prod.price - economy_mgr.wallet.balance
		show_feedback("⚠️ Không đủ tiền trong ví! Cần thêm %s" % HouseholdWallet.format_money(needed), "error")
		return
		
	# Check Co-op mutual confirmation (>= 50,000 đ in active co-op)
	var dual_mgr := get_tree().get_first_node_in_group("dual_confirmation_manager") as DualConfirmationManager
	if is_instance_valid(dual_mgr) and dual_mgr.is_coop_active and prod.price >= 50000:
		if dual_mgr.has_pending_request():
			show_feedback("⌛ Đang chờ xác nhận giao dịch trước.", "warning")
			return
		var p_id := 1
		if is_instance_valid(current_player) and "player_id" in current_player:
			p_id = current_player.player_id
		var other_id := 2 if p_id == 1 else 1
		show_feedback("⏳ Chờ người chơi P%d xác nhận mua '%s'!" % [other_id, prod.name], "info")
		
		pending_coop_product_id = prod.id
		dual_mgr.request_purchase(
			p_id,
			prod.name,
			prod.price,
			Callable(self, "_on_coop_purchase_approved").bind(prod)
		)
		return
		
	# Single player purchase confirmation step
	if not is_awaiting_confirm:
		is_awaiting_confirm = true
		cancel_button.visible = true
		_display_product_details(prod)
		show_feedback("Nhấn 'XÁC NHẬN MUA NGAY' để hoàn tất giao dịch.", "info")
		return
		
	# Confirmed purchase
	is_awaiting_confirm = false
	cancel_button.visible = false
	_execute_purchase(prod)

func _on_coop_purchase_approved(product: EconomyProduct) -> void:
	if not is_open or not product or product.id != pending_coop_product_id:
		return
	_execute_purchase(product)

func _on_sell_button_pressed() -> void:
	if filtered_products.is_empty(): return
	var prod: EconomyProduct = filtered_products[selected_index]
	if not is_instance_valid(economy_mgr): return
	var res := economy_mgr.sell_produce(prod.id, 1)
	if res.get("success", false):
		var remaining := economy_mgr.inventory.get_item_count(prod.id)
		show_feedback("✅ %s (Còn trong kho: %d)" % [res.get("message", "Đã bán nông sản!"), remaining], "success")
		update_ui()
	else:
		show_feedback("⚠️ %s" % res.get("message", "Không thể bán!"), "error")

func cancel_purchase_confirmation() -> void:
	is_awaiting_confirm = false
	cancel_button.visible = false
	if not filtered_products.is_empty():
		_display_product_details(filtered_products[selected_index])
	feedback_panel.visible = false

func _execute_purchase(product: EconomyProduct) -> void:
	if not is_instance_valid(economy_mgr): return
	
	var res := economy_mgr.purchase_product(product.id, 1)
	if res["success"]:
		var extra_note := ""
		if product.id == "pet_cat_adoption":
			extra_note = " 🐱 Miu Miu đã về đến nhà bạn!"
		elif product.id == "pet_food_salmon":
			extra_note = " 🐟 Đã cất vào túi đồ gia đình!"
		elif product.category == "farming_seed":
			extra_note = " 🌱 Đã cất hạt giống vào túi đồ gia đình!"
		elif product.category == "furniture" or product.id.begins_with("furn_"):
			extra_note = " 📦 Đã giao đến Thùng Giao Hàng tại nhà!"
		elif product.category == "house_upgrade":
			extra_note = " 🏡 Ngôi nhà đã được nâng cấp!"
		elif product.category == "business_upgrade":
			extra_note = " ⚡ Tiệm kinh doanh đã được nâng cấp!"
			
		var stock_note := ""
		if not product.is_unique and economy_mgr.inventory:
			stock_note = " · Trong kho: %d" % economy_mgr.inventory.get_item_count(product.id)
		show_feedback("✅ %s (-%s%s)%s" % [
			res["message"],
			HouseholdWallet.format_money(res["total_cost"]),
			stock_note,
			extra_note
		], "success")
		
		product_purchased.emit(product)
		update_ui()
	else:
		show_feedback("⚠️ %s" % res["message"], "error")
		update_ui()

func update_ui() -> void:
	if not is_instance_valid(economy_mgr): return
	wallet_label.text = "💰 Ví: %s" % HouseholdWallet.format_money(economy_mgr.wallet.balance)
	if not filtered_products.is_empty():
		selected_index = clampi(selected_index, 0, filtered_products.size() - 1)
		var product := filtered_products[selected_index]
		if is_awaiting_confirm and (_is_product_owned(product) or not economy_mgr.wallet.can_afford(product.price) or economy_mgr.purchase_prerequisite_message(product) != ""):
			is_awaiting_confirm = false
			cancel_button.visible = false
	_rebuild_product_list()
	if not filtered_products.is_empty():
		_display_product_details(filtered_products[selected_index])
	else:
		_clear_details()

func show_feedback(text: String, type: String = "info") -> void:
	feedback_label.text = text
	feedback_panel.visible = true
	feedback_timer = 4.0
	
	var fb_style := feedback_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if fb_style:
		match type:
			"success": fb_style.bg_color = Color("1b5e20") # Dark green
			"error": fb_style.bg_color = Color("b71c1c") # Dark red
			"warning": fb_style.bg_color = Color("e65100") # Dark orange
			_: fb_style.bg_color = Color("283593") # Deep indigo

func _is_product_owned(prod: EconomyProduct) -> bool:
	return is_instance_valid(economy_mgr) and economy_mgr.is_product_owned(prod)

func _get_owned_count(prod: EconomyProduct) -> int:
	if not is_instance_valid(economy_mgr) or not prod: return 0
	if prod.category == "furniture" or prod.id.begins_with("furn_"):
		return economy_mgr.inventory.get_furniture_count(prod.id)
	elif prod.category == "business_upgrade" or prod.category == "house_upgrade" or prod.id == "pet_cat_adoption":
		return 1 if _is_product_owned(prod) else 0
	return economy_mgr.inventory.get_item_count(prod.id)

# -----------------------------------------------------------------
# Keyboard & Navigation Controls
# -----------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if not is_open: return
	if not (event is InputEventKey and event.pressed and not event.echo): return
	
	if event.keycode == KEY_ESCAPE:
		if is_awaiting_confirm:
			cancel_purchase_confirmation()
		else:
			close_shop()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_UP or event.is_action_pressed("p1_up"):
		select_product(selected_index - 1)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_DOWN or event.is_action_pressed("p1_down"):
		select_product(selected_index + 1)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_TAB or event.is_action_pressed("p1_right"):
		_cycle_category_tab(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("p1_left"):
		_cycle_category_tab(-1)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_B and sell_button.visible and not sell_button.disabled:
		_on_sell_button_pressed()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ENTER or event.keycode == KEY_SPACE or event.is_action_pressed("p1_interact"):
		if not buy_button.disabled:
			_on_buy_button_pressed()
			get_viewport().set_input_as_handled()

func _cycle_category_tab(direction: int) -> void:
	var tabs := category_container.get_children()
	if tabs.is_empty(): return
	var cur_idx := 0
	for i in range(tabs.size()):
		if tabs[i] is Button and tabs[i].get_meta("cat_id", "") == active_category_id:
			cur_idx = i
			break
	var next_idx := (cur_idx + direction + tabs.size()) % tabs.size()
	var next_btn := tabs[next_idx] as Button
	if next_btn and next_btn.has_meta("cat_id"):
		select_category(next_btn.get_meta("cat_id"))
