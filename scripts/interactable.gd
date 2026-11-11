class_name Interactable
extends Node3D

var kind := ""
var user: Node3D
var enabled := true
var toggle := false
var moving_part: Node3D
var light: OmniLight3D
var stand_point := Vector3.ZERO
var seat_point := Vector3.ZERO
var display_name := "Nội thất"
var item_category := "furniture"
var interaction_type := "interact"
var valid_destinations: Array = []
var furniture_id := ""
var is_furniture := false

func _ready() -> void:
 add_to_group("interactables")
 match kind:
  "sofa":
   display_name = "Sofa"
   interaction_type = "rest"
  "bed":
   display_name = "Giường"
   interaction_type = "rest"
  "chair":
   display_name = "Ghế ngồi"
   interaction_type = "rest"
  "lamp":
   display_name = "Đèn phòng"
   interaction_type = "toggle"
  "door":
   display_name = "Cửa phòng"
   interaction_type = "toggle"

func available(player: Node3D) -> bool:
 return enabled and (user == null or user == player)

func prompt(player: Node3D) -> String:
 if kind == "sofa": return "Đứng dậy" if (user != null and user == player) else "Ngồi sofa"
 if kind == "bed":
  if user != null and user == player: return "Thức dậy"
  var daily_loop = get_tree().get_first_node_in_group("daily_loop_manager")
  if is_instance_valid(daily_loop) and daily_loop.has_method("is_ready_to_sleep") and not daily_loop.is_ready_to_sleep():
   return "Nằm nghỉ (Chưa đến giờ ngủ)"
  return "Đi ngủ (kết thúc ngày)"
 if kind == "chair": return "Đứng dậy" if (user != null and user == player) else "Ngồi ghế"
 if kind == "lamp": return "Tắt đèn" if toggle else "Bật đèn"
 if kind == "door": return "Đóng cửa" if toggle else "Mở cửa"
 return "Tương tác"

func interact(player: Node3D) -> void:
 if not available(player): return
 match kind:
  "sofa", "bed", "chair":
   if user == player:
    if player.leave_rest((get_parent() as Node3D).to_global(stand_point)):
     user = null
   elif user == null:
    user = player
    player.enter_rest(self, (get_parent() as Node3D).to_global(seat_point), kind == "bed")
    if kind == "bed":
     var daily_loop = get_tree().get_first_node_in_group("daily_loop_manager")
     var slept: bool = false
     if is_instance_valid(daily_loop) and daily_loop.has_method("on_player_sleep"):
      if not daily_loop.has_method("is_ready_to_sleep") or daily_loop.is_ready_to_sleep():
       slept = daily_loop.on_player_sleep(player)
     if slept:
      var econ = get_tree().get_first_node_in_group("economy_manager")
      if is_instance_valid(econ) and econ.has_method("save_economy_state"):
       econ.save_economy_state()
      var fx = get_tree().get_first_node_in_group("chaos_feedback")
      if is_instance_valid(fx) and fx.has_method("play_event"):
       fx.play_event("pickup", global_position + Vector3(0, 1.2, 0))
     else:
      var fx = get_tree().get_first_node_in_group("chaos_feedback")
      if is_instance_valid(fx) and fx.has_method("show_toast"):
       fx.show_toast("Chưa đến giờ ngủ! Hãy hoàn thành công việc trước 🌙")
  "lamp":
   toggle = not toggle
   if light: light.visible = toggle
  "door":
   toggle = not toggle
   var hint := get_node_or_null("DoorHint") as Label3D
   if hint: hint.text = "E — Đóng cửa" if toggle else "E — Mở cửa"
   if has_meta("door_body"):
    var body = get_meta("door_body")
    if is_instance_valid(body):
     body.collision_layer = 0 if toggle else 1
     body.set_deferred("collision_layer", 0 if toggle else 1)
   if moving_part:
    var tween = create_tween()
    tween.tween_property(moving_part, "rotation:y", -1.35 if toggle else 0.0, 0.3)
