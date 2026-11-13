class_name Interactable
extends Node3D

var kind := ""
var user: Node3D
var enabled := true
var toggle := false
var moving_part: Node3D
var moving_part_2: Node3D
var light: OmniLight3D
var screen_mesh: MeshInstance3D
var soil_mesh: MeshInstance3D
var is_watered := false
var interaction_radius := 1.45
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
  "tv":
   display_name = "Tivi thông minh"
   interaction_type = "toggle"
  "fridge":
   display_name = "Tủ lạnh Inverter"
   interaction_type = "toggle"
  "wardrobe":
   display_name = "Tủ quần áo gỗ"
   interaction_type = "toggle"
  "bookshelf":
   display_name = "Kệ sách gia đình"
   interaction_type = "read"
  "kitchen_counter":
   display_name = "Bếp nấu ăn gia đình"
   interaction_type = "cook"
  "plant":
   display_name = "Chậu cây cảnh"
   interaction_type = "water"

func available(player: Node3D) -> bool:
 if not enabled: return false
 if user != null:
  return user == player
 if is_inside_tree() and is_instance_valid(player):
  var space_state := get_world_3d().direct_space_state
  if space_state:
   var query := PhysicsRayQueryParameters3D.new()
   query.from = player.global_position + Vector3(0, 0.75, 0)
   query.to = global_position + Vector3(0, 0.40, 0)
   query.collision_mask = 1
   var excludes: Array[RID] = []
   if player is CollisionObject3D: excludes.append(player.get_rid())
   for c in player.get_children():
    if c is CollisionObject3D: excludes.append(c.get_rid())
   var p := get_parent()
   if is_instance_valid(p):
    if p is CollisionObject3D: excludes.append(p.get_rid())
    for c in p.get_children():
     if c is CollisionObject3D: excludes.append(c.get_rid())
   for c in get_children():
    if c is CollisionObject3D: excludes.append(c.get_rid())
   query.exclude = excludes
   var hit := space_state.intersect_ray(query)
   if not hit.is_empty():
    return false
 return true

func prompt(player: Node3D) -> String:
 match kind:
  "sofa":
   return "Đứng dậy" if (user != null and user == player) else "Ngồi sofa"
  "bed":
   if user != null and user == player: return "Thức dậy"
   var daily_loop = get_tree().get_first_node_in_group("daily_loop_manager")
   if is_instance_valid(daily_loop) and daily_loop.has_method("is_ready_to_sleep") and not daily_loop.is_ready_to_sleep():
    return "Nằm nghỉ (Chưa đến giờ ngủ)"
   return "Đi ngủ (kết thúc ngày)"
  "chair":
   return "Đứng dậy" if (user != null and user == player) else "Ngồi ghế"
  "lamp":
   return "Tắt đèn" if toggle else "Bật đèn"
  "door":
   return "Đóng cửa" if toggle else "Mở cửa"
  "tv":
   return "Tắt Tivi" if toggle else "Bật Tivi"
  "fridge":
   return "Đóng tủ lạnh" if toggle else "Mở tủ lạnh & Xem thực phẩm"
  "wardrobe":
   return "Đóng tủ quần áo" if toggle else "Mở tủ quần áo"
  "bookshelf":
   return "Đọc sách thư giãn"
  "kitchen_counter":
   return "Nấu món ăn gia đình"
  "plant":
   return "Ngắm cây xanh tươi 🌿" if is_watered else "Tưới nước cho cây 💧"
  _:
   return "Tương tác với %s" % display_name

func interact(player: Node3D) -> void:
 if not available(player): return
 var fx = get_tree().get_first_node_in_group("chaos_feedback")
 var econ: EconomyManager = get_tree().get_first_node_in_group("economy_manager") as EconomyManager
 var parent_3d := get_parent() as Node3D
 var has_parent: bool = is_instance_valid(parent_3d) and parent_3d != get_tree().root

 match kind:
  "sofa", "bed", "chair":
   if user == player:
    var stand_pos: Vector3 = parent_3d.to_global(stand_point) if has_parent else to_global(stand_point)
    if player.leave_rest(stand_pos):
     user = null
   elif user == null:
    user = player
    var seat_pos: Vector3 = parent_3d.to_global(seat_point) if has_parent else to_global(seat_point)
    var seat_yaw: float = parent_3d.global_rotation.y if has_parent else global_rotation.y
    if has_meta("seat_rotation_y"):
     seat_yaw = float(get_meta("seat_rotation_y"))
    player.enter_rest(self, seat_pos, kind == "bed", seat_yaw)
    if kind == "bed":
     var daily_loop = get_tree().get_first_node_in_group("daily_loop_manager")
     var slept: bool = false
     if is_instance_valid(daily_loop) and daily_loop.has_method("on_player_sleep"):
      if not daily_loop.has_method("is_ready_to_sleep") or daily_loop.is_ready_to_sleep():
       slept = daily_loop.on_player_sleep(player)
     if slept:
      if is_instance_valid(econ) and econ.has_method("save_economy_state"):
       econ.save_economy_state()
      if is_instance_valid(fx) and fx.has_method("play_event"):
       fx.play_event("pickup", global_position + Vector3(0, 1.2, 0))
     else:
      if is_instance_valid(fx) and fx.has_method("show_toast"):
       fx.show_toast("Nằm nghỉ ngơi thư giãn 🌙 (Chưa đến giờ ngủ)")
    elif kind == "sofa":
     if is_instance_valid(fx) and fx.has_method("show_toast"):
      fx.show_toast("🛋️ Ngồi nghỉ ngơi trên sofa êm ái")
    elif kind == "chair":
     if is_instance_valid(fx) and fx.has_method("show_toast"):
      fx.show_toast("🪑 Ngồi vào bàn ăn")
  "lamp":
   toggle = not toggle
   _update_lamp_visual()
   if is_instance_valid(fx) and fx.has_method("show_toast"):
    fx.show_toast("💡 " + ("Đã bật đèn phòng ấm cúng." if toggle else "Đã tắt đèn phòng."))
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
  "tv":
   toggle = not toggle
   _update_tv_visual()
   if toggle:
    var shows := [
     "📺 [VTV Sa Đéc] 'Khám phá Làng hoa Sa Đéc trăm tuổi rực rỡ sắc màu'",
     "📺 [HTV Ẩm Thực] 'Bí quyết ninh nước dùng Hủ Tiếu trong vắt ngọt thanh'",
     "📺 [Kênh Phim] 'Cặp đôi siêu quậy phiêu lưu ký'",
     "📺 [Xe & Đời Sống] 'Chiêm ngưỡng dàn xe máy cổ cực đẹp tại Miền Tây'"
    ]
    var show_text: String = shows[randi() % shows.size()]
    if is_instance_valid(fx) and fx.has_method("show_toast"):
     fx.show_toast(show_text)
    if is_instance_valid(fx) and fx.has_method("play_event"):
     fx.play_event("pickup", global_position + Vector3(0, 0.8, 0))
   else:
    if is_instance_valid(fx) and fx.has_method("show_toast"):
     fx.show_toast("📺 Đã tắt Tivi. Căn phòng yên tĩnh trở lại.")
  "fridge":
   toggle = not toggle
   if moving_part:
    var tween := create_tween()
    tween.tween_property(moving_part, "rotation:y", -1.45 if toggle else 0.0, 0.35)
   if light: light.visible = toggle
   if toggle:
    var counts := ""
    if is_instance_valid(econ) and is_instance_valid(econ.inventory):
     var noodles := econ.inventory.get_item_count("ing_rice_noodle")
     var ribs := econ.inventory.get_item_count("ing_pork_ribs")
     var shrimp := econ.inventory.get_item_count("ing_fresh_shrimp")
     var greens := econ.inventory.get_item_count("produce_lettuce")
     counts = " (%d Hủ tiếu, %d Sườn, %d Tôm, %d Rau cải)" % [noodles, ribs, shrimp, greens]
    if is_instance_valid(fx) and fx.has_method("show_toast"):
     fx.show_toast("🧊 Tủ lạnh đang trữ thực phẩm tươi ngon%s" % counts)
    if is_instance_valid(fx) and fx.has_method("play_event"):
     fx.play_event("pickup", global_position + Vector3(0, 1.0, 0))
   else:
    if is_instance_valid(fx) and fx.has_method("show_toast"):
     fx.show_toast("🧊 Đã đóng cửa tủ lạnh")
  "wardrobe":
   toggle = not toggle
   if moving_part:
    var tween := create_tween().set_parallel(true)
    tween.tween_property(moving_part, "rotation:y", -1.55 if toggle else 0.0, 0.35)
    if is_instance_valid(moving_part_2):
     tween.tween_property(moving_part_2, "rotation:y", 1.55 if toggle else 0.0, 0.35)
   if light: light.visible = toggle
   if toggle:
    if is_instance_valid(fx) and fx.has_method("show_toast"):
     fx.show_toast("🚪 Tủ quần áo: Quần áo gia đình thơm tho, sạch sẽ.")
    if is_instance_valid(fx) and fx.has_method("play_event"):
     fx.play_event("pickup", global_position + Vector3(0, 1.2, 0))
   else:
    if is_instance_valid(fx) and fx.has_method("show_toast"):
     fx.show_toast("🚪 Đã đóng tủ quần áo")
  "bookshelf":
   var book_lore := [
    "📖 [Cẩm Nang Sa Đéc] 'Nước dùng hủ tiếu ngọt thanh nhất khi hầm xương ống cùng mực nướng và củ cải trắng.'",
    "📖 [Sổ Tay Gia Đình] 'Tổ ấm ngập tràn niềm vui bắt đầu từ sự chia sẻ công việc nhỏ mỗi ngày.' 💖",
    "📖 [Bảo Dưỡng Xe] 'Vệ sinh lọc gió và thay dầu nhớt đúng định kỳ giúp xe tay ga bền bỉ và bốc hơn.' 🏍️",
    "📖 [Chăm Cây Cảnh] 'Tưới nước đều đặn vào buổi sớm mai để lá cây giữ được màu xanh mơn mởn.' 🌿"
   ]
   var snippet: String = book_lore[randi() % book_lore.size()]
   if is_instance_valid(fx) and fx.has_method("show_toast"):
    fx.show_toast(snippet)
   if is_instance_valid(fx) and fx.has_method("play_event"):
    fx.play_event("pickup", global_position + Vector3(0, 1.2, 0))
  "kitchen_counter":
   var cooked_dish := "⚠️ Cần bánh hủ tiếu và rau cải, sườn hoặc tôm trong kho để nấu ăn."
   if is_instance_valid(econ) and is_instance_valid(econ.inventory):
    var ingredient := ""
    for candidate in ["produce_lettuce", "ing_pork_ribs", "ing_fresh_shrimp"]:
     if econ.inventory.has_item(candidate):
      ingredient = candidate
      break
    if ingredient != "" and econ.inventory.has_item("ing_rice_noodle"):
     econ.inventory.remove_item("ing_rice_noodle", 1)
     econ.inventory.remove_item(ingredient, 1)
     cooked_dish = "🍲 Đã nấu bữa hủ tiếu ấm cúng từ nguyên liệu trong kho!"
   if is_instance_valid(fx) and fx.has_method("show_toast"):
    fx.show_toast(cooked_dish)
   if is_instance_valid(fx) and fx.has_method("play_event"):
    fx.play_event("pickup", global_position + Vector3(0, 1.0, 0))
  "plant":
   if not is_watered:
    is_watered = true
    _update_plant_visual()
    if is_instance_valid(fx) and fx.has_method("show_toast"):
     fx.show_toast("💧 Đã tưới nước mát! Đất ẩm mịn, chậu cây vươn lá xanh tươi rạng rỡ 🌿💚")
    if is_instance_valid(fx) and fx.has_method("play_event"):
     fx.play_event("pickup", global_position + Vector3(0, 0.8, 0))
   else:
    if is_instance_valid(fx) and fx.has_method("show_toast"):
     fx.show_toast("🌿 Cây đang phát triển rất xanh tốt, đất vẫn còn đủ độ ẩm mát!")

 # Save state changes and consumed cooking ingredients after the action.
 if is_instance_valid(econ) and econ.auto_save_on_change and (is_furniture or kind == "kitchen_counter"):
  econ.save_economy_state()

func _update_tv_visual() -> void:
 if is_instance_valid(light): light.visible = toggle
 var screen := screen_mesh
 if not is_instance_valid(screen):
  screen = get_node_or_null("TVScreen") as MeshInstance3D
  if not is_instance_valid(screen) and is_instance_valid(get_parent()):
   screen = get_parent().find_child("TVScreen", true, false) as MeshInstance3D
 if is_instance_valid(screen):
  var mat := StandardMaterial3D.new()
  if toggle:
   mat.albedo_color = Color("cceeff")
   mat.emission_enabled = true
   mat.emission = Color("40c4ff")
   mat.emission_energy_multiplier = 1.2
  else:
   mat.albedo_color = Color("141416")
   mat.roughness = 0.6
  screen.material_override = mat

func _update_lamp_visual() -> void:
 if is_instance_valid(light): light.visible = toggle
 var shade := moving_part as MeshInstance3D
 if not is_instance_valid(shade) and is_instance_valid(get_parent()):
  shade = get_parent().find_child("LampShade", true, false) as MeshInstance3D
 if is_instance_valid(shade):
  var mat := StandardMaterial3D.new()
  if toggle:
   mat.albedo_color = Color("fff8e7")
   mat.emission_enabled = true
   mat.emission = Color("ffd54f")
   mat.emission_energy_multiplier = 0.8
  else:
   mat.albedo_color = Color("908575")
  shade.material_override = mat

func _update_plant_visual() -> void:
 var soil := soil_mesh
 if not is_instance_valid(soil) and is_instance_valid(get_parent()):
  soil = get_parent().find_child("PlantSoil", true, false) as MeshInstance3D
 if is_instance_valid(soil):
  var mat := StandardMaterial3D.new()
  mat.albedo_color = Color("3e2723") if is_watered else Color("8d6e63")
  mat.roughness = 0.7 if is_watered else 0.95
  soil.material_override = mat
