class_name CropData
extends Resource

## Data Definition and Registry for Crops in Couple Chaos 3D Farming System.
## Contains crop specifications, growth durations, water requirements,
## seed and produce mappings, harvest yields, and sell prices.

@export var crop_id: String = "crop_lettuce"
@export var display_name: String = "Rau cải xanh"
@export var seed_item_id: String = "seed_lettuce"
@export var produce_item_id: String = "produce_lettuce"
@export var growth_duration: float = 8.0 # In-game hours required per stage
@export var growth_stages_count: int = 4 # Stage 0: Seeded, 1: Sprout, 2: Growing, 3: Mature
@export var water_requirement: bool = true
@export var harvest_quantity: int = 3
@export var sell_price: int = 12000
@export var scene_path: String = "res://scenes/farming/crop_lettuce.tscn"

# Shared definitions are read-only at runtime; avoid recreating resources for each prompt.
static var _catalog: Dictionary = {}

func _init(
	p_id := "crop_lettuce",
	p_name := "Rau cải xanh",
	p_seed := "seed_lettuce",
	p_produce := "produce_lettuce",
	p_duration := 8.0,
	p_harvest_qty := 3,
	p_price := 12000,
	p_scene := "res://scenes/farming/crop_lettuce.tscn"
) -> void:
	crop_id = p_id
	display_name = p_name
	seed_item_id = p_seed
	produce_item_id = p_produce
	growth_duration = p_duration
	harvest_quantity = p_harvest_qty
	sell_price = p_price
	scene_path = p_scene

static func get_crop_definition(id: String) -> CropData:
	var catalog := get_all_crops()
	return catalog.get(id, null)

static func get_crop_by_seed(seed_id: String) -> CropData:
	for c in get_all_crops().values():
		if c.seed_item_id == seed_id:
			return c
	return null

static func get_all_crops() -> Dictionary:
	if not _catalog.is_empty():
		return _catalog
	_catalog = {
		"crop_lettuce": CropData.new(
			"crop_lettuce",
			"Rau cải xanh",
			"seed_lettuce",
			"produce_lettuce",
			6.0, # Fast growing leafy greens (6 in-game hours per stage)
			3,   # 3 harvested heads
			12000,
			"res://scenes/farming/crop_lettuce.tscn"
		),
		"crop_tomato": CropData.new(
			"crop_tomato",
			"Cà chua bi",
			"seed_tomato",
			"produce_tomato",
			8.0, # 8 in-game hours per stage
			4,   # 4 harvested tomatoes
			18000,
			"res://scenes/farming/crop_tomato.tscn"
		),
		"crop_carrot": CropData.new(
			"crop_carrot",
			"Cà rốt ngọt",
			"seed_carrot",
			"produce_carrot",
			10.0, # 10 in-game hours per stage
			3,    # 3 harvested carrots
			15000,
			"res://scenes/farming/crop_carrot.tscn"
		)
	}
	return _catalog
