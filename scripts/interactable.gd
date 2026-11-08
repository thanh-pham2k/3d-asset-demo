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

func _ready() -> void:
 add_to_group("interactables")
 match kind:
  "sofa":
   display_name = "Sofa"
   interaction_type = "rest"
  "bed":
   display_name = "Giường"
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
 if kind == "sofa": return "Đứng dậy" if user == player else "Ngồi sofa"
 if kind == "bed": return "Thức dậy" if user == player else "Nằm nghỉ"
 if kind == "lamp": return "Tắt đèn" if toggle else "Bật đèn"
 if kind == "door": return "Đóng cửa" if toggle else "Mở cửa"
 return "Tương tác"

func interact(player: Node3D) -> void:
 if not available(player): return
 match kind:
  "sofa", "bed":
   if user == player:
    if player.leave_rest(stand_point):
     user = null
   elif user == null:
    user = player
    player.enter_rest(self, seat_point, kind == "bed")
  "lamp":
   toggle = not toggle
   if light: light.visible = toggle
  "door":
   toggle = not toggle
   if moving_part:
    var tween = create_tween()
    tween.tween_property(moving_part, "rotation:y", -1.35 if toggle else 0.0, 0.3)
