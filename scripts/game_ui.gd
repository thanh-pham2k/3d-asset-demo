extends CanvasLayer

var player: Node
var menu: Control
var pause_panel: Control
var hud: Control
var dash_bar: ProgressBar
var item_label: Label

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 build_ui()
 show_main_menu()

func panel(title: String) -> VBoxContainer:
 var overlay := Control.new()
 overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 overlay.mouse_filter = Control.MOUSE_FILTER_STOP
 add_child(overlay)
 var shade := ColorRect.new()
 shade.color = Color(0.19,0.15,0.16,0.65)
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 overlay.add_child(shade)
 var center := CenterContainer.new()
 center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 overlay.add_child(center)
 var column := VBoxContainer.new()
 column.custom_minimum_size = Vector2(340,0)
 column.add_theme_constant_override("separation", 16)
 center.add_child(column)
 var heading := Label.new()
 heading.text = title
 heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 heading.add_theme_font_size_override("font_size", 40)
 column.add_child(heading)
 return column

func button(parent: Control, caption: String, callback: Callable) -> Button:
 var b := Button.new()
 b.text = caption
 b.custom_minimum_size = Vector2(250,48)
 b.pressed.connect(callback)
 parent.add_child(b)
 return b

func build_ui() -> void:
 hud = Control.new()
 hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(hud)
 var hints := Label.new()
 hints.text = "WASD di chuyển   Shift chạy   Space lướt   E nhặt/thả   F ném   Q đập   Esc tạm dừng"
 hints.position = Vector2(20,18)
 hints.add_theme_font_size_override("font_size",18)
 hints.add_theme_color_override("font_color",Color("543e3c"))
 hud.add_child(hints)
 item_label = Label.new()
 item_label.position = Vector2(22,48)
 item_label.add_theme_color_override("font_color",Color("543e3c"))
 hud.add_child(item_label)
 dash_bar = ProgressBar.new()
 dash_bar.position = Vector2(22,78)
 dash_bar.size = Vector2(150,14)
 dash_bar.show_percentage = false
 hud.add_child(dash_bar)
 var menu_column := panel("Couple Chaos")
 menu = menu_column.get_parent().get_parent()
 var sub := Label.new()
 sub.text = "Căn phòng nhỏ, niềm vui lớn!"
 sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 menu_column.add_child(sub)
 var choices := HBoxContainer.new()
 choices.alignment = BoxContainer.ALIGNMENT_CENTER
 menu_column.add_child(choices)
 var choice_group := ButtonGroup.new()
 var boy := Button.new()
 boy.toggle_mode = true
 boy.button_group = choice_group
 boy.button_pressed = true
 boy.text = "Boy"
 boy.custom_minimum_size = Vector2(140,42)
 boy.pressed.connect(func(): player.select_character("boy"))
 choices.add_child(boy)
 var girl := Button.new()
 girl.toggle_mode = true
 girl.button_group = choice_group
 girl.text = "Girl"
 girl.custom_minimum_size = Vector2(140,42)
 girl.pressed.connect(func(): player.select_character("girl"))
 choices.add_child(girl)
 button(menu_column, "Bắt đầu", start_game)
 var pause_column := panel("Tạm dừng")
 pause_panel = pause_column.get_parent().get_parent()
 button(pause_column, "Tiếp tục", resume_game)
 button(pause_column, "Chơi lại", restart_game)
 button(pause_column, "Về menu", show_main_menu)

func show_main_menu() -> void:
 menu.visible = true
 pause_panel.visible = false
 hud.visible = false
 get_tree().paused = true

func start_game() -> void:
 menu.visible = false
 pause_panel.visible = false
 hud.visible = true
 get_tree().paused = false

func resume_game() -> void:
 start_game()

func restart_game() -> void:
 get_tree().paused = false
 get_tree().reload_current_scene()

func _process(_delta: float) -> void:
 if not is_instance_valid(player): return
 dash_bar.value = 100.0 * (1.0 - clampf(player.dash_cooldown_remaining / player.config.dash_cooldown, 0.0, 1.0))
 var names := {"pillow":"gối", "hammer":"búa", "bear":"gấu", "box":"hộp", "book":"sách", "ball":"bóng", "chair":"ghế", "vase":"bình", "cup":"cốc", "bottle":"chai", "slipper":"dép", "toy":"đồ chơi", "container":"hộp", "stack_box":"thùng"}
 item_label.text = "Đang cầm: " + names.get(player.held_pillow.prop_kind, "đồ") if is_instance_valid(player.held_pillow) else "Lướt"

func _unhandled_key_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and not menu.visible:
  if pause_panel.visible: resume_game()
  else:
   pause_panel.visible = true
   get_tree().paused = true
  get_viewport().set_input_as_handled()
