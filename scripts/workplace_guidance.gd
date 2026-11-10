extends CanvasLayer

const GARAGE := Vector3(-63, 0, -11)
const NOODLE := Vector3(-50, 0, -12)
var player: CharacterBody3D
var camera: Camera3D
var objective: Label
var direction: Label
var marker: Label3D
var arrived := false

func _ready() -> void:
 var panel := PanelContainer.new()
 panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
 panel.offset_left = -350
 panel.offset_right = -16
 panel.offset_top = 16
 panel.offset_bottom = 104
 add_child(panel)
 var column := VBoxContainer.new()
 panel.add_child(column)
 objective = Label.new()
 objective.text = "Ra khỏi nhà và đến nơi làm việc"
 objective.add_theme_font_size_override("font_size", 16)
 column.add_child(objective)
 direction = Label.new()
 direction.add_theme_font_size_override("font_size", 18)
 direction.add_theme_color_override("font_color", Color("ffe6a3"))
 column.add_child(direction)
 marker = Label3D.new()
 marker.name = "WorkplaceMarker"
 marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
 marker.font_size = 48
 marker.pixel_size = 0.008
 marker.outline_size = 10
 marker.modulate = Color("fff0aa")
 marker.outline_modulate = Color("332716")
 get_parent().add_child.call_deferred(marker)

func _process(_delta: float) -> void:
 if not is_instance_valid(player) or not is_instance_valid(camera) or not is_instance_valid(marker): return
 var girl: bool = player.selected_character == "girl"
 var destination := NOODLE if girl else GARAGE
 var title := "🍜 Quán hủ tiếu" if girl else "🛵 Tiệm sửa xe"
 var distance := Vector2(player.global_position.x - destination.x, player.global_position.z - destination.z).length()
 arrived = distance < 7.0
 var indoors := player.global_position.z > 83.5 and absf(player.global_position.x + 45.0) < 9.0
 objective.text = "Ra khỏi nhà và đến nơi làm việc" if indoors else ("Đã đến nơi · E để phục vụ khách" if arrived else "Đi đến nơi làm việc")
 marker.global_position = destination + Vector3(0, 4.0, 0)
 marker.text = title
 marker.visible = not arrived
 if arrived:
  direction.text = title + " · Tương tác [E]"
 else:
  var delta := destination - player.global_position
  var screen_direction := Vector2(delta.dot(camera.global_basis.x), -delta.dot(camera.global_basis.y))
  var angle := atan2(screen_direction.y, screen_direction.x)
  var arrows := ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"]
  var index := posmod(int(round(angle / (PI / 4.0))), 8)
  direction.text = "%s  %s · %d m" % [arrows[index], title, int(round(distance))]
