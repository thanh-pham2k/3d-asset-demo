class_name PetProp
extends Node3D

## Reusable script for interactive pet props and accessories.
## Handles food bowls, water bowls, pet beds, toy balls, scratching posts,
## toy wands, food packages, and collars.

signal prop_interacted(prop_type: String, user: Node)

@export_enum("food_bowl", "water_bowl", "pet_bed", "toy_ball", "scratching_post", "cat_toy_wand", "food_package", "collar") var prop_type: String = "food_bowl"
@export var display_name: String = "Vật dụng thú cưng"
@export var fill_amount: float = 1.0 # 0.0 = empty, 1.0 = full

var content_mesh: MeshInstance3D
var interaction_marker: Marker3D

func _ready() -> void:
	var ancestor := get_parent()
	while is_instance_valid(ancestor):
		if ancestor.has_meta("is_furniture_preview"):
			return
		ancestor = ancestor.get_parent()
	add_to_group("interactables")
	add_to_group("pet_props")
	
	interaction_marker = get_node_or_null("InteractionMarker") as Marker3D
	content_mesh = get_node_or_null("ContentMesh") as MeshInstance3D
	
	_update_visual_state()

func _update_visual_state() -> void:
	if is_instance_valid(content_mesh):
		content_mesh.visible = fill_amount > 0.05
		content_mesh.scale.y = clampf(fill_amount, 0.1, 1.0)

# -----------------------------------------------------------------
# Public Pet API
# -----------------------------------------------------------------
func get_interaction_position() -> Vector3:
	if is_instance_valid(interaction_marker):
		return interaction_marker.global_position
	return global_position + Vector3(0, 0, 0.3)

func use_by_pet(pet_node: Node) -> bool:
	match prop_type:
		"food_bowl":
			if fill_amount <= 0.05: return false
			fill_amount = maxf(0.0, fill_amount - 0.25)
			_update_visual_state()
			if pet_node.has_method("play_animation"):
				pet_node.play_animation("eat")
			prop_interacted.emit(prop_type, pet_node)
			call_deferred("_save_after_pet_use")
			return true
		"water_bowl":
			if fill_amount <= 0.05: return false
			fill_amount = maxf(0.0, fill_amount - 0.15)
			_update_visual_state()
			if pet_node.has_method("play_animation"):
				pet_node.play_animation("drink")
			prop_interacted.emit(prop_type, pet_node)
			call_deferred("_save_after_pet_use")
			return true
		"pet_bed":
			if pet_node.has_method("play_animation"):
				pet_node.play_animation("sleep")
			prop_interacted.emit(prop_type, pet_node)
			call_deferred("_save_after_pet_use")
			return true
		"scratching_post", "toy_ball", "cat_toy_wand":
			if pet_node.has_method("play_animation"):
				pet_node.play_animation("play")
			prop_interacted.emit(prop_type, pet_node)
			call_deferred("_save_after_pet_use")
			return true
	return false

# -----------------------------------------------------------------
# Interactable API (Player interaction)
# -----------------------------------------------------------------
func available(player: Node3D) -> bool:
	if not is_inside_tree() or not is_instance_valid(player):
		return false
	var excludes: Array[RID] = []
	for child in get_children():
		if child is CollisionObject3D:
			excludes.append(child.get_rid())
	var parent := get_parent()
	if is_instance_valid(parent):
		for sibling in parent.get_children():
			if sibling is CollisionObject3D:
				excludes.append(sibling.get_rid())
	var query := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP * 0.5, global_position + Vector3.UP * 0.1, 1, excludes)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func prompt(_player: Node3D) -> String:
	match prop_type:
		"food_bowl":
			if fill_amount < 0.9:
				var econ := get_tree().get_first_node_in_group("economy_manager") as EconomyManager
				if is_instance_valid(econ) and econ.inventory:
					if not econ.inventory.has_item("pet_food_salmon"):
						return "Bát thức ăn (Hết hạt — Cần mua tại Tiệm Thú Cưng!)"
					var count: int = econ.inventory.get_item_count("pet_food_salmon")
					return "Đổ thêm hạt cá hồi vào bát (-1 gói hạt) [Có: %d]" % count
				return "Đổ thêm hạt vào bát thức ăn"
			else:
				return "Bát thức ăn (Đầy ắp hạt 🐟)"
		"water_bowl":
			return "Thay nước mát cho thú cưng 💧" if fill_amount < 0.9 else "Bát nước sạch (Trong lành 💧)"
		"pet_bed":
			return "Vuốt êm nệm ngủ thú cưng 🛏️"
		"toy_ball":
			return "Lăn bóng len đồ chơi 🧶"
		"scratching_post":
			return "Rắc cỏ mèo vào trụ cào móng 🌿"
		"cat_toy_wand":
			return "Cầm cần câu mèo vẫy đồ chơi 🪶"
		"food_package":
			return "Mở gói thức ăn hạt cá hồi 🐟"
		"collar":
			return "Xem vòng cổ chuông vàng 🔔"
		_:
			return "Tương tác với %s" % display_name

func interact(player_node: Node3D) -> void:
	var fx = get_tree().get_first_node_in_group("chaos_feedback")
	var cat: OrangeTabbyCat = get_tree().get_first_node_in_group("pets") as OrangeTabbyCat
	var econ := get_tree().get_first_node_in_group("economy_manager") as EconomyManager
	
	match prop_type:
		"food_bowl":
			if fill_amount >= 0.95:
				if is_instance_valid(fx):
					fx.show_toast("🥣 Bát thức ăn đã đầy ắp hạt cá hồi rồi! 🐟")
				return
				
			if not is_instance_valid(econ) or not econ.inventory or not econ.inventory.remove_item("pet_food_salmon", 1):
				if is_instance_valid(fx):
					fx.show_toast("⚠️ Trong túi đồ không có thức ăn hạt! Hãy đến Tiệm Thú Cưng mua thêm.")
				return
				
			fill_amount = 1.0
			_update_visual_state()
			if is_instance_valid(fx):
				fx.play_event("pickup", global_position + Vector3(0, 0.2, 0))
				fx.show_toast("🥣 Đã đổ đầy hạt cá hồi thơm lừng vào bát cho Miu Miu! 🐟")
			if is_instance_valid(cat) and cat.has_method("notify_food_ready"):
				cat.notify_food_ready(global_position)
				
		"water_bowl":
			fill_amount = 1.0
			_update_visual_state()
			if is_instance_valid(fx):
				fx.play_event("pickup", global_position + Vector3(0, 0.2, 0))
				fx.show_toast("💧 Đã châm đầy nước mát trong lành cho bé cưng! 🚰")
			if is_instance_valid(cat) and cat.has_method("notify_water_ready"):
				cat.notify_water_ready(global_position)
				
		"pet_bed":
			if is_instance_valid(fx):
				fx.play_event("pickup", global_position + Vector3(0, 0.2, 0))
				fx.show_toast("🛏️ Đã vỗ êm đệm ngủ mềm mại, sẵn sàng cho giấc ngủ ngon.")
				
		"toy_ball":
			var rb := get_node_or_null("RigidBody3D") as RigidBody3D
			if is_instance_valid(rb):
				var impulse := Vector3(randf_range(-1.5, 1.5), 1.2, randf_range(-1.5, 1.5))
				rb.apply_central_impulse(impulse)
			if is_instance_valid(fx):
				fx.play_event("pickup", global_position + Vector3(0, 0.2, 0))
				fx.show_toast("🧶 Quả bóng len kêu leng keng lăn trên sàn nhà!")
			if is_instance_valid(cat) and cat.has_method("notify_toy_played"):
				cat.notify_toy_played(global_position)
				
		"scratching_post":
			if is_instance_valid(fx):
				fx.play_event("pickup", global_position + Vector3(0, 0.4, 0))
				fx.show_toast("🌿 Đã rắc một chút bạc hà mèo lên trụ cào móng! Miu Miu thích mê! 🐱")
			if is_instance_valid(cat) and cat.has_method("notify_toy_played"):
				cat.notify_toy_played(global_position)
				
		"cat_toy_wand":
			if is_instance_valid(fx):
				fx.play_event("pickup", global_position + Vector3(0, 0.5, 0))
				fx.show_toast("🪶 Cần câu lông vũ đung đưa vui mắt, chuông reo leng keng!")
			if is_instance_valid(cat) and cat.has_method("notify_toy_played"):
				cat.notify_toy_played(global_position)
				
		"food_package":
			if is_instance_valid(fx):
				fx.play_event("pickup", global_position + Vector3(0, 0.3, 0))
				fx.show_toast("📦 Gói thức ăn hạt dinh dưỡng cao cấp dành cho mèo cưng.")
		"collar":
			if is_instance_valid(fx):
				fx.play_event("pickup", global_position + Vector3(0, 0.1, 0))
				fx.show_toast("🔔 Vòng cổ vải đỏ đính chuông vàng leng keng xinh xắn.")
				
	prop_interacted.emit(prop_type, player_node)
	if prop_type == "food_bowl" or prop_type == "water_bowl":
		var manager := get_tree().get_first_node_in_group("pet_manager") as PetManager
		if is_instance_valid(manager):
			manager.record_care_action("refilled_" + prop_type)
	if is_instance_valid(econ) and econ.auto_save_on_change:
		econ.save_economy_state()

func _save_after_pet_use() -> void:
	if not is_inside_tree(): return
	var econ := get_tree().get_first_node_in_group("economy_manager") as EconomyManager
	if is_instance_valid(econ) and econ.auto_save_on_change:
		econ.save_economy_state()
