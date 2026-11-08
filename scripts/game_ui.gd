class_name GameUI
extends CanvasLayer

var player: Node
var menu: Control
var pause_panel: Control
var results_panel: Control
var hud: Control
var dash_bar: ProgressBar
var item_label: Label
var timer_label: Label
var score_label: Label
var combo_badge: Label
var combo_bar: ProgressBar
var challenge_container: VBoxContainer
var challenge_header: Label
var challenge_labels: Array[Label] = []
var popup_container: Control

var results_title: Label
var results_rank: Label
var results_score: Label
var results_breakdown: Label

var round_manager: Node
var score_manager: Node
var challenge_manager: Node
var mission_manager: Node

var game_mode: String = "cleaning"

var cleaning_labels := {
 "basket": null,
 "trash": null,
 "sofa": null,
 "banana": null,
}

func _ready() -> void:
 add_to_group("game_ui")
 process_mode = Node.PROCESS_MODE_ALWAYS
 build_ui()
 show_main_menu()

func setup(p_round: Node, p_score: Node, p_challenge: Node) -> void:
 round_manager = p_round
 score_manager = p_score
 challenge_manager = p_challenge
 
 if is_instance_valid(round_manager):
  round_manager.time_tick.connect(_on_time_tick)
  round_manager.round_ended.connect(_on_round_ended)
 
 if is_instance_valid(score_manager):
  score_manager.score_added.connect(_on_score_added)
  score_manager.combo_changed.connect(_on_combo_changed)
 
 if is_instance_valid(challenge_manager):
  challenge_manager.challenge_updated.connect(_on_challenge_updated)
  challenge_manager.challenge_completed.connect(_on_challenge_completed)

func setup_cleaning(p_mission: Node) -> void:
 mission_manager = p_mission
 if is_instance_valid(mission_manager):
  mission_manager.time_tick.connect(_on_cleaning_time_tick)
  mission_manager.objective_updated.connect(_on_cleaning_objective_updated)
  mission_manager.mission_won.connect(_on_mission_won)
  mission_manager.mission_lost.connect(_on_mission_lost)

func panel(title: String) -> VBoxContainer:
 var overlay := Control.new()
 overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 overlay.mouse_filter = Control.MOUSE_FILTER_STOP
 add_child(overlay)
 var shade := ColorRect.new()
 shade.color = Color(0.12, 0.10, 0.12, 0.72)
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 overlay.add_child(shade)
 var center := CenterContainer.new()
 center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 overlay.add_child(center)
 var column := VBoxContainer.new()
 column.custom_minimum_size = Vector2(380, 0)
 column.add_theme_constant_override("separation", 14)
 center.add_child(column)
 var heading := Label.new()
 heading.text = title
 heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 heading.add_theme_font_size_override("font_size", 34)
 heading.add_theme_color_override("font_color", Color("fff3cf"))
 column.add_child(heading)
 return column

func button(parent: Control, caption: String, callback: Callable) -> Button:
 var b := Button.new()
 b.text = caption
 b.custom_minimum_size = Vector2(260, 46)
 b.pressed.connect(callback)
 parent.add_child(b)
 return b

func build_ui() -> void:
 hud = Control.new()
 hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(hud)
 
 # Top-Left: Score / Mode
 var score_box := VBoxContainer.new()
 score_box.position = Vector2(24, 18)
 hud.add_child(score_box)
 
 score_label = Label.new()
 score_label.text = "NHIỆM VỤ DỌN NHÀ"
 score_label.add_theme_font_size_override("font_size", 24)
 score_label.add_theme_color_override("font_color", Color("ffd659"))
 score_box.add_child(score_label)
 
 # Top-Center: Timer & Combo
 var center_hud := VBoxContainer.new()
 center_hud.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
 center_hud.position = Vector2(360, 14)
 center_hud.custom_minimum_size = Vector2(240, 0)
 center_hud.alignment = BoxContainer.ALIGNMENT_CENTER
 hud.add_child(center_hud)
 
 timer_label = Label.new()
 timer_label.text = "⏱ 120s"
 timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 timer_label.add_theme_font_size_override("font_size", 34)
 timer_label.add_theme_color_override("font_color", Color("fff8e7"))
 center_hud.add_child(timer_label)
 
 combo_badge = Label.new()
 combo_badge.text = "COMBO x1.0"
 combo_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 combo_badge.add_theme_font_size_override("font_size", 20)
 combo_badge.add_theme_color_override("font_color", Color("ff9e59"))
 combo_badge.visible = false
 center_hud.add_child(combo_badge)
 
 combo_bar = ProgressBar.new()
 combo_bar.custom_minimum_size = Vector2(160, 8)
 combo_bar.show_percentage = false
 combo_bar.visible = false
 center_hud.add_child(combo_bar)
 
 # Top-Right: Challenges / Mission Checklist
 var chal_panel := PanelContainer.new()
 chal_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
 chal_panel.position = Vector2(660, 16)
 chal_panel.custom_minimum_size = Vector2(300, 120)
 hud.add_child(chal_panel)
 
 challenge_container = VBoxContainer.new()
 challenge_container.add_theme_constant_override("separation", 6)
 chal_panel.add_child(challenge_container)
 
 challenge_header = Label.new()
 challenge_header.text = "★ MỤC TIÊU DỌN DẸP"
 challenge_header.add_theme_font_size_override("font_size", 16)
 challenge_header.add_theme_color_override("font_color", Color("e0c279"))
 challenge_container.add_child(challenge_header)
 
 # Labels for Cleaning mode
 cleaning_labels["basket"] = Label.new()
 cleaning_labels["basket"].text = "[ ] Giỏ đồ chơi: 0 / 5"
 cleaning_labels["basket"].add_theme_font_size_override("font_size", 13)
 cleaning_labels["basket"].add_theme_color_override("font_color", Color("fff0d4"))
 challenge_container.add_child(cleaning_labels["basket"])
 
 cleaning_labels["trash"] = Label.new()
 cleaning_labels["trash"].text = "[ ] Bỏ rác vào thùng: 0 / 4"
 cleaning_labels["trash"].add_theme_font_size_override("font_size", 13)
 cleaning_labels["trash"].add_theme_color_override("font_color", Color("fff0d4"))
 challenge_container.add_child(cleaning_labels["trash"])
 
 cleaning_labels["sofa"] = Label.new()
 cleaning_labels["sofa"].text = "[ ] Xếp 3 gối lên sofa: 0 / 3"
 cleaning_labels["sofa"].add_theme_font_size_override("font_size", 13)
 cleaning_labels["sofa"].add_theme_color_override("font_color", Color("fff0d4"))
 challenge_container.add_child(cleaning_labels["sofa"])
 
 cleaning_labels["banana"] = Label.new()
 cleaning_labels["banana"].text = "[ ] Thu gom vỏ chuối: 0 / 2"
 cleaning_labels["banana"].add_theme_font_size_override("font_size", 13)
 cleaning_labels["banana"].add_theme_color_override("font_color", Color("fff0d4"))
 challenge_container.add_child(cleaning_labels["banana"])
 
 # 3 Labels for Chaos mode
 challenge_labels.clear()
 for i in 3:
  var l := Label.new()
  l.text = "[ ] Đang tải..."
  l.add_theme_font_size_override("font_size", 13)
  l.add_theme_color_override("font_color", Color("fff0d4"))
  l.visible = false
  challenge_container.add_child(l)
  challenge_labels.append(l)
 
 # Floating popups container
 popup_container = Control.new()
 popup_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 popup_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
 hud.add_child(popup_container)
 
 # Bottom-Left: Held item, Dash meter, Hints
 item_label = Label.new()
 item_label.position = Vector2(24, 520)
 item_label.add_theme_font_size_override("font_size", 16)
 item_label.add_theme_color_override("font_color", Color("fff0db"))
 hud.add_child(item_label)
 
 dash_bar = ProgressBar.new()
 dash_bar.position = Vector2(24, 545)
 dash_bar.size = Vector2(160, 12)
 dash_bar.show_percentage = false
 hud.add_child(dash_bar)
 
 var hints := Label.new()
 hints.text = "WASD di chuyển | Shift chạy | Space lướt | E nhặt/thả | F ném | Q đập | Esc tạm dừng"
 hints.position = Vector2(24, 565)
 hints.add_theme_font_size_override("font_size", 13)
 hints.add_theme_color_override("font_color", Color("cfc0af"))
 hud.add_child(hints)
 
 # Main Menu Panel
 var menu_column := panel("Couple Chaos: Dọn Nhà Hỗn Loạn")
 menu = menu_column.get_parent().get_parent()
 var sub := Label.new()
 sub.text = "Căn phòng đang bừa bộn! Dọn dẹp trước khi khách đến trong 120s!\nCẩn thận trượt vỏ chuối hoặc làm vỡ đồ!"
 sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 sub.add_theme_font_size_override("font_size", 14)
 sub.add_theme_color_override("font_color", Color("eed8c0"))
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
 boy.custom_minimum_size = Vector2(130, 40)
 boy.pressed.connect(func(): if is_instance_valid(player): player.select_character("boy"))
 choices.add_child(boy)
 
 var girl := Button.new()
 girl.toggle_mode = true
 girl.button_group = choice_group
 girl.text = "Girl"
 girl.custom_minimum_size = Vector2(130, 40)
 girl.pressed.connect(func(): if is_instance_valid(player): player.select_character("girl"))
 choices.add_child(girl)
 
 button(menu_column, "★ CHƠI: DỌN NHÀ (120s)", start_cleaning_mode)
 button(menu_column, "⚡ QUẬY PHÁ: CHAOS (60s)", start_chaos_mode)
 
 # Pause Panel
 var pause_column := panel("Tạm dừng")
 pause_panel = pause_column.get_parent().get_parent()
 button(pause_column, "Tiếp tục", resume_game)
 button(pause_column, "Chơi lại vòng này", restart_round)
 button(pause_column, "Về Menu chính", show_main_menu)
 
 # Results Panel
 var results_col := panel("KẾT QUẢ")
 results_panel = results_col.get_parent().get_parent()
 
 results_title = results_col.get_child(0) as Label
 results_title.text = "KẾT QUẢ"
 
 results_rank = Label.new()
 results_rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 results_rank.add_theme_font_size_override("font_size", 42)
 results_rank.add_theme_color_override("font_color", Color("ffd740"))
 results_col.add_child(results_rank)
 
 results_score = Label.new()
 results_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 results_score.add_theme_font_size_override("font_size", 22)
 results_score.add_theme_color_override("font_color", Color("ffffff"))
 results_col.add_child(results_score)
 
 results_breakdown = Label.new()
 results_breakdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 results_breakdown.add_theme_font_size_override("font_size", 14)
 results_breakdown.add_theme_color_override("font_color", Color("dcd0c2"))
 results_col.add_child(results_breakdown)
 
 button(results_col, "Chơi lại ngay", restart_round)
 button(results_col, "Về Menu chính", show_main_menu)

func show_main_menu() -> void:
 menu.visible = true
 pause_panel.visible = false
 results_panel.visible = false
 hud.visible = false
 get_tree().paused = true

func start_game(mode: String = "chaos") -> void:
 if mode == "cleaning":
  start_cleaning_mode()
 else:
  start_chaos_mode()

func start_cleaning_mode() -> void:
 game_mode = "cleaning"
 menu.visible = false
 pause_panel.visible = false
 results_panel.visible = false
 hud.visible = true
 get_tree().paused = false
 
 score_label.text = "DỌN NHÀ TRƯỚC KHI KHÁCH ĐẾN"
 challenge_header.text = "★ MỤC TIÊU DỌN DẸP"
 
 for k in cleaning_labels:
  cleaning_labels[k].visible = true
 for l in challenge_labels:
  l.visible = false
 
 combo_badge.visible = false
 combo_bar.visible = false
 
 if is_instance_valid(mission_manager):
  mission_manager.start_mission()

func start_chaos_mode() -> void:
 game_mode = "chaos"
 menu.visible = false
 pause_panel.visible = false
 results_panel.visible = false
 hud.visible = true
 get_tree().paused = false
 
 score_label.text = "ĐIỂM: 0"
 challenge_header.text = "★ NHIỆM VỤ ROUND"
 
 for k in cleaning_labels:
  cleaning_labels[k].visible = false
 for l in challenge_labels:
  l.visible = true
 
 if is_instance_valid(round_manager):
  round_manager.start_round()

func resume_game() -> void:
 menu.visible = false
 pause_panel.visible = false
 results_panel.visible = false
 hud.visible = true
 get_tree().paused = false

func restart_round() -> void:
 get_tree().paused = false
 get_tree().reload_current_scene()

func _on_cleaning_time_tick(time_remaining: float, _total: float) -> void:
 if game_mode != "cleaning": return
 var secs := int(ceilf(time_remaining))
 timer_label.text = "⏱ %ds" % secs
 if secs <= 15:
  timer_label.add_theme_color_override("font_color", Color("ff4c4c"))
  var pulse := 1.0 + 0.12 * sin(time_remaining * 8.0)
  timer_label.scale = Vector2.ONE * pulse
 else:
  timer_label.add_theme_color_override("font_color", Color("fff8e7"))
  timer_label.scale = Vector2.ONE

func _on_cleaning_objective_updated(id: String, current: int, target: int, completed: bool) -> void:
 if not cleaning_labels.has(id): return
 var l: Label = cleaning_labels[id]
 var names := {
  "basket": "Giỏ đồ chơi",
  "trash": "Bỏ rác vào thùng",
  "sofa": "Xếp 3 gối lên sofa",
  "banana": "Thu gom vỏ chuối",
 }
 var title: String = names.get(id, id)
 if completed:
  l.text = "[✔] %s: %d / %d (XONG!)" % [title, current, target]
  l.add_theme_color_override("font_color", Color("81c784"))
 else:
  l.text = "[ ] %s: %d / %d" % [title, current, target]
  l.add_theme_color_override("font_color", Color("fff0d4"))

func _on_mission_won(summary: Dictionary) -> void:
 hud.visible = false
 pause_panel.visible = false
 menu.visible = false
 results_panel.visible = true
 
 results_title.text = "CHIẾN THẮNG!"
 results_rank.text = "★ NHÀ CỬA SẠCH BÓNG! ★"
 results_rank.add_theme_color_override("font_color", Color("ffd700"))
 
 var time_left: float = summary.get("time_left", 0.0)
 results_score.text = "Khách đến đúng lúc và căn phòng thật ngăn nắp!\nThời gian còn lại: %d giây" % int(time_left)
 
 var p: Dictionary = summary.get("progress", {})
 results_breakdown.text = "Giỏ đồ: %d/5  |  Thùng rác: %d/4\nGối sofa: %d/3  |  Vỏ chuối: %d/2" % [
  p.get("basket", 5), p.get("trash", 4), p.get("sofa", 3), p.get("banana", 2)
 ]

func _on_mission_lost(summary: Dictionary) -> void:
 hud.visible = false
 pause_panel.visible = false
 menu.visible = false
 results_panel.visible = true
 
 results_title.text = "THẤT BẠI!"
 results_rank.text = "HẾT GIỜ!"
 results_rank.add_theme_color_override("font_color", Color("ef5350"))
 
 results_score.text = "Khách đã đến trước khi bạn kịp dọn xong!\nCăn phòng vẫn còn bừa bộn!"
 
 var p: Dictionary = summary.get("progress", {})
 results_breakdown.text = "Tiến độ đạt được:\nGiỏ đồ: %d/5  |  Thùng rác: %d/4\nGối sofa: %d/3  |  Vỏ chuối: %d/2" % [
  p.get("basket", 0), p.get("trash", 0), p.get("sofa", 0), p.get("banana", 0)
 ]

func _on_time_tick(time_remaining: float, _total: float) -> void:
 if game_mode != "chaos": return
 var secs := int(ceilf(time_remaining))
 timer_label.text = "⏱ %ds" % secs
 if secs <= 10:
  timer_label.add_theme_color_override("font_color", Color("ff4c4c"))
  var pulse := 1.0 + 0.12 * sin(time_remaining * 8.0)
  timer_label.scale = Vector2.ONE * pulse
 else:
  timer_label.add_theme_color_override("font_color", Color("fff8e7"))
  timer_label.scale = Vector2.ONE

func _on_score_added(points: int, total_score: int, reason: String, _world_pos: Vector3) -> void:
 if game_mode == "chaos":
  score_label.text = "ĐIỂM: %s" % _format_number(total_score)
 _spawn_floating_text("+%d  %s" % [points, reason])

func _spawn_floating_text(text: String) -> void:
 if not is_instance_valid(popup_container): return
 var pop := Label.new()
 pop.text = text
 pop.add_theme_font_size_override("font_size", 16)
 pop.add_theme_color_override("font_color", Color("ffe082"))
 pop.position = Vector2(randf_range(24, 180), randf_range(55, 95))
 popup_container.add_child(pop)
 
 var tween := create_tween()
 tween.tween_property(pop, "position:y", pop.position.y - 30.0, 0.75)
 tween.parallel().tween_property(pop, "modulate:a", 0.0, 0.75)
 tween.tween_callback(pop.queue_free)

func _on_combo_changed(multiplier: float, time_left: float, max_time: float) -> void:
 if game_mode != "chaos": return
 if multiplier > 1.0:
  combo_badge.visible = true
  combo_bar.visible = true
  combo_badge.text = "COMBO x%.1f!" % multiplier
  combo_bar.value = 100.0 * (time_left / max_time)
 else:
  combo_badge.visible = false
  combo_bar.visible = false

func _on_challenge_updated(index: int, ch: Dictionary) -> void:
 if game_mode != "chaos": return
 if index >= 0 and index < challenge_labels.size():
  var l := challenge_labels[index]
  if ch["completed"]:
   l.text = "[✔] %s (HOÀN THÀNH!)" % ch["description"]
   l.add_theme_color_override("font_color", Color("81c784"))
  else:
   if ch["id"] == "reach_combo":
    l.text = "[ ] %s (%.1f / %.1f)" % [ch["description"], ch["current"], ch["target"]]
   else:
    l.text = "[ ] %s (%d / %d)" % [ch["description"], int(ch["current"]), int(ch["target"])]
   l.add_theme_color_override("font_color", Color("fff0d4"))

func _on_challenge_completed(index: int, ch: Dictionary) -> void:
 if game_mode != "chaos": return
 _on_challenge_updated(index, ch)
 _spawn_floating_text("★ NHIỆM VỤ XONG! +%d" % ch["reward"])

func _on_round_ended(summary: Dictionary) -> void:
 if game_mode != "chaos": return
 hud.visible = false
 pause_panel.visible = false
 menu.visible = false
 results_panel.visible = true
 
 var rank: String = summary.get("rank", "C")
 results_title.text = "HẾT GIỜ (TIME'S UP!)"
 results_rank.text = "XẾP HẠNG: %s" % rank
 match rank:
  "S": results_rank.add_theme_color_override("font_color", Color("ffd700"))
  "A": results_rank.add_theme_color_override("font_color", Color("ff80ab"))
  "B": results_rank.add_theme_color_override("font_color", Color("64b5f6"))
  "C": results_rank.add_theme_color_override("font_color", Color("81c784"))
  _: results_rank.add_theme_color_override("font_color", Color("b0bec5"))
 
 var score_val: int = summary.get("score", 0)
 var high_val: int = summary.get("high_score", score_val)
 var is_new_high := (score_val >= high_val and score_val > 0)
 results_score.text = "TỔNG ĐIỂM: %s%s" % [_format_number(score_val), "  ★ KỶ LỤC MỚI! ★" if is_new_high else ""]
 
 var broken: int = summary.get("props_broken", 0)
 var max_c: float = summary.get("max_combo", 1.0)
 var chain: int = summary.get("chain_hits", 0)
 var hammer: int = summary.get("hammer_hits", 0)
 var ch_done: int = summary.get("challenges_completed", 0)
 var ch_tot: int = summary.get("total_challenges", 3)
 
 results_breakdown.text = "Đồ vỡ nát: %d  |  Combo cao nhất: x%.1f\nPhản ứng dây chuyền: %d  |  Đập búa: %d\nNhiệm vụ hoàn thành: %d / %d" % [
  broken, max_c, chain, hammer, ch_done, ch_tot
 ]

func _format_number(n: int) -> String:
 var s := str(n)
 var res := ""
 var cnt := 0
 for i in range(s.length() - 1, -1, -1):
  if cnt > 0 and cnt % 3 == 0:
   res = "," + res
  res = s[i] + res
  cnt += 1
 return res

func _process(_delta: float) -> void:
 if not is_instance_valid(player): return
 dash_bar.value = 100.0 * (1.0 - clampf(player.dash_cooldown_remaining / player.config.dash_cooldown, 0.0, 1.0))
 if is_instance_valid(player.held_pillow):
  var item_name: String = player.held_pillow.get("display_name") if "display_name" in player.held_pillow else "đồ"
  var dests: Array = player.held_pillow.get("valid_destinations") if "valid_destinations" in player.held_pillow else []
  var dest_name := ""
  if "basket" in dests: dest_name = "Giỏ đồ"
  elif "trash" in dests: dest_name = "Thùng rác"
  elif "sofa" in dests: dest_name = "Sofa"
  if dest_name != "":
   item_label.text = "Đang cầm: %s  ➜  Mang đến: %s" % [item_name, dest_name]
  else:
   item_label.text = "Đang cầm: " + item_name
 else:
  item_label.text = "Lướt (Space)"

func _unhandled_key_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and not menu.visible and not results_panel.visible:
  if pause_panel.visible:
   resume_game()
  else:
   pause_panel.visible = true
   get_tree().paused = true
  get_viewport().set_input_as_handled()
