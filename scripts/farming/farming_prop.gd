class_name FarmingProp
extends Node3D

## Reusable wrapper script for low-poly farming assets in Couple Chaos 3D.
## Provides interaction prompts, collision references, visual models,
## and categorization for tools, environment objects, and collectibles.

signal prop_interacted(player_node: Node)

@export_enum("plot", "raised_bed", "soil", "fence", "pathway", "compost", "seed_box", "tool", "collectible", "seed_packet") var prop_category: String = "tool"
@export var item_id: String = "tool_watering_can"
@export var display_name: String = "Dụng cụ làm vườn"
@export var is_collectible: bool = false

var visual_node: Node3D
var collision_node: CollisionShape3D

func _ready() -> void:
	add_to_group("farming_props")
	if is_collectible:
		add_to_group("collectibles")
	# Asset wrappers are scenery; the actual FarmPlot owns garden actions.
	# Registering decorative paths or tools as interactables steals E from plots.
	
	visual_node = get_node_or_null("Visual") as Node3D
	collision_node = get_node_or_null("CollisionShape3D") as CollisionShape3D

# -----------------------------------------------------------------
# Interactable API
# -----------------------------------------------------------------
func available(_player: Node3D) -> bool:
	return true

func prompt(_player: Node3D) -> String:
	match prop_category:
		"tool":
			return "Cầm %s (Phím E)" % display_name
		"collectible":
			return "Thu hoạch %s (Phím E)" % display_name
		"seed_packet":
			return "Lấy %s (Phím E)" % display_name
		"compost":
			return "Bón phân hữu cơ (Phím E)"
		"seed_box":
			return "Mở rương chứa hạt giống (Phím E)"
		_:
			return "Kiểm tra %s" % display_name

func interact(player_node: Node3D) -> void:
	var fx = get_tree().get_first_node_in_group("chaos_feedback")
	if is_instance_valid(fx):
		if fx.has_method("play_event"):
			fx.play_event("pickup", global_position + Vector3(0, 0.3, 0))
		if fx.has_method("show_toast"):
			fx.show_toast("🌱 %s: Đã tương tác thành công!" % display_name)
			
	prop_interacted.emit(player_node)
