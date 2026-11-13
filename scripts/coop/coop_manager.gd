class_name CoopManager
extends Node

## Central coordinator for 2-Player Local Cooperative gameplay in Couple Chaos.
## Manages Player 1 (Boy) and Player 2 (Girl), dual split-screen viewports,
## mutual purchase confirmations, cooperative actions, and controller hot-plugging.

signal coop_mode_toggled(is_active: bool)
signal dual_confirmation_popup(message: String)

var is_coop_active: bool = false

var player_1: CharacterBody3D
var player_2: CharacterBody3D

var split_screen: SplitScreenManager
var dual_confirmation: DualConfirmationManager
var mission_manager: CoopMissionManager
var input_manager: CoopInputManager

var banner_hud: CanvasLayer
var status_label: Label

func _init() -> void:
	dual_confirmation = DualConfirmationManager.new()
	dual_confirmation.name = "DualConfirmationManager"
	add_child(dual_confirmation)
	
	mission_manager = CoopMissionManager.new()
	mission_manager.name = "CoopMissionManager"
	add_child(mission_manager)
	
	input_manager = CoopInputManager.new()
	input_manager.name = "CoopInputManager"
	add_child(input_manager)
	
	input_manager.gamepad_disconnected.connect(_on_gamepad_disconnected)
	input_manager.gamepad_connected.connect(_on_gamepad_connected)

func _ready() -> void:
	add_to_group("coop_manager")
	_setup_hud()
	if is_instance_valid(dual_confirmation):
		dual_confirmation.confirmation_approved.connect(_on_dual_confirmation_approved)
		dual_confirmation.confirmation_declined.connect(_on_dual_confirmation_declined)

func _on_dual_confirmation_approved(_initiator_id: int, product_name: String, cost: int) -> void:
	show_banner("✅ Đã đồng ý yêu cầu mua '%s' (%s)." % [product_name, HouseholdWallet.format_money(cost)], 3.0)

func _on_dual_confirmation_declined(initiator_id: int, product_name: String, reason: String) -> void:
	match reason:
		"DECLINED_BY_PARTNER":
			var other_id := 2 if initiator_id == 1 else 1
			show_banner("❌ P%d đã từ chối mua '%s'!" % [other_id, product_name], 3.0)
		"TIMEOUT":
			show_banner("⌛ Hết thời gian chờ xác nhận mua '%s'!" % product_name, 3.0)
		"INSUFFICIENT_FUNDS":
			show_banner("⚠️ Không đủ tiền trong ví gia đình để mua '%s'!" % product_name, 3.0)
		_:
			show_banner("⚠️ Yêu cầu mua '%s' đã bị hủy!" % product_name, 3.0)

func _setup_hud() -> void:
	banner_hud = CanvasLayer.new()
	banner_hud.name = "CoopBannerHUD"
	banner_hud.layer = 100
	add_child(banner_hud)
	
	var box := CenterContainer.new()
	box.anchor_left = 0.0
	box.anchor_right = 1.0
	box.anchor_top = 0.0
	box.offset_top = 18
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_hud.add_child(box)
	
	status_label = Label.new()
	status_label.text = ""
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_color_override("font_color", Color("fff59d"))
	box.add_child(status_label)

func initialize_coop(
	p1: CharacterBody3D,
	p2: CharacterBody3D,
	parent_node: Node,
	world_3d: World3D,
	is_room: bool = false
) -> void:
	player_1 = p1
	player_2 = p2
	is_coop_active = true
	
	# Configure player IDs and independent character visuals
	if is_instance_valid(player_1):
		player_1.player_id = 1
		player_1.select_character("boy")
		
	if is_instance_valid(player_2):
		player_2.player_id = 2
		player_2.select_character("girl")
	
	dual_confirmation.is_coop_active = true
	
	# Create Split-Screen Viewports
	if not is_instance_valid(split_screen):
		split_screen = SplitScreenManager.new()
		split_screen.name = "SplitScreenManager"
		parent_node.add_child(split_screen)
	
	split_screen.setup_coop(player_1, player_2, world_3d, is_room)
	coop_mode_toggled.emit(true)
	show_banner("👥 CHẾ ĐỘ CO-OP 2 NGƯỜI: P1 (Boy - Bàn phím) | P2 (Girl - Tay cầm / Phím mũi tên)", 5.0)

func show_banner(msg: String, duration: float = 4.0) -> void:
	if not is_instance_valid(status_label): return
	status_label.text = msg
	get_tree().create_timer(duration).timeout.connect(func():
		if is_instance_valid(status_label) and status_label.text == msg:
			status_label.text = ""
	)

func _on_gamepad_disconnected(device_id: int) -> void:
	if not is_coop_active: return
	show_banner("⚠️ Tay cầm P2 đã ngắt kết nối! Tự động chuyển sang phím: Mũi tên (di chuyển), K (tương tác), L (ném)", 6.0)

func _on_gamepad_connected(device_id: int) -> void:
	if not is_coop_active: return
	show_banner("🎮 Tay cầm P2 đã kết nối lại (Thiết bị %d)!" % device_id, 4.0)

func _process(_delta: float) -> void:
	if not is_coop_active: return
	if dual_confirmation.has_pending_request():
		status_label.text = dual_confirmation.get_prompt_text()
	elif status_label.text.begins_with("🤝"):
		status_label.text = ""
