class_name MissionManager
extends Node

signal mission_started(duration: float)
signal time_tick(time_remaining: float, total_duration: float)
signal objective_updated(id: String, current: int, target: int, completed: bool)
signal mission_won(summary: Dictionary)
signal mission_lost(summary: Dictionary)
signal state_changed(new_state: String)

enum State { WAITING, RUNNING, PAUSED, WON, LOST }

var current_state: State = State.WAITING
var config: Resource
var time_remaining: float = 120.0

var basket_zone: Node3D
var trash_zone: Node3D
var sofa_zones: Array[Node3D] = []

var progress := {
 "basket": 0,
 "trash": 0,
 "sofa": 0,
 "banana": 0,
}

var targets := {
 "basket": 5,
 "trash": 4,
 "sofa": 3,
 "banana": 2,
}

func _ready() -> void:
 add_to_group("mission_manager")
 process_mode = Node.PROCESS_MODE_ALWAYS
 if not config:
  config = preload("res://scripts/cleaning/mission_config.gd").new()
 _apply_config()

func _apply_config() -> void:
 if config:
  time_remaining = config.get("mission_duration") if "mission_duration" in config else 120.0
  targets["basket"] = config.get("target_basket_items") if "target_basket_items" in config else 5
  targets["trash"] = config.get("target_trash_items") if "target_trash_items" in config else 4
  targets["sofa"] = config.get("target_sofa_pillows") if "target_sofa_pillows" in config else 3
  targets["banana"] = config.get("target_banana_peels") if "target_banana_peels" in config else 2

func setup_zones(basket: Node3D, trash: Node3D, sofa_slots: Array) -> void:
 basket_zone = basket
 trash_zone = trash
 sofa_zones.clear()
 for s in sofa_slots:
  if s is Node3D: sofa_zones.append(s)
 
 if is_instance_valid(basket_zone):
  if not basket_zone.count_changed.is_connected(_on_basket_count_changed):
   basket_zone.count_changed.connect(_on_basket_count_changed)
 
 if is_instance_valid(trash_zone):
  if not trash_zone.item_placed.is_connected(_on_trash_item_placed):
   trash_zone.item_placed.connect(_on_trash_item_placed)
  if not trash_zone.item_removed.is_connected(_on_trash_item_removed):
   trash_zone.item_removed.connect(_on_trash_item_removed)
 
 for slot in sofa_zones:
  if not slot.count_changed.is_connected(_on_sofa_slot_count_changed):
   slot.count_changed.connect(_on_sofa_slot_count_changed)

func start_mission() -> void:
 _apply_config()
 progress["basket"] = basket_zone.get_item_count() if is_instance_valid(basket_zone) else 0
 _refresh_trash_and_banana_counts()
 _refresh_sofa_count()
 
 current_state = State.RUNNING
 get_tree().paused = false
 state_changed.emit("running")
 mission_started.emit(time_remaining)
 
 _emit_all_objectives()

func _process(delta: float) -> void:
 if current_state != State.RUNNING: return
 if get_tree().paused: return
 
 time_remaining -= delta
 time_tick.emit(maxf(0.0, time_remaining), config.mission_duration if config else 120.0)
 
 if time_remaining <= 0.0:
  time_remaining = 0.0
  _fail_mission()

func _on_basket_count_changed(current: int, _capacity: int) -> void:
 progress["basket"] = current
 objective_updated.emit("basket", progress["basket"], targets["basket"], progress["basket"] >= targets["basket"])
 _check_victory()

func _on_trash_item_placed(item: Node3D, _zone: Node3D) -> void:
 _refresh_trash_and_banana_counts()
 _check_victory()

func _on_trash_item_removed(item: Node3D, _zone: Node3D) -> void:
 _refresh_trash_and_banana_counts()
 _check_victory()

func _refresh_trash_and_banana_counts() -> void:
 if not is_instance_valid(trash_zone): return
 var trash_count := 0
 var banana_count := 0
 for it in trash_zone.items_inside:
  if not is_instance_valid(it): continue
  var kind: String = it.get("prop_kind") if "prop_kind" in it else ""
  if kind == "banana":
   banana_count += 1
  else:
   trash_count += 1
 progress["trash"] = trash_count
 progress["banana"] = banana_count
 objective_updated.emit("trash", progress["trash"], targets["trash"], progress["trash"] >= targets["trash"])
 objective_updated.emit("banana", progress["banana"], targets["banana"], progress["banana"] >= targets["banana"])

func _on_sofa_slot_count_changed(_c: int, _cap: int) -> void:
 _refresh_sofa_count()
 _check_victory()

func _refresh_sofa_count() -> void:
 var total_pillows := 0
 for slot in sofa_zones:
  if is_instance_valid(slot):
   total_pillows += slot.get_item_count()
 progress["sofa"] = total_pillows
 objective_updated.emit("sofa", progress["sofa"], targets["sofa"], progress["sofa"] >= targets["sofa"])

func _check_victory() -> void:
 if current_state != State.RUNNING: return
 if is_all_completed():
  _win_mission()

func is_all_completed() -> bool:
 return (
  progress["basket"] >= targets["basket"] and
  progress["trash"] >= targets["trash"] and
  progress["sofa"] >= targets["sofa"] and
  progress["banana"] >= targets["banana"]
 )

func _win_mission() -> void:
 current_state = State.WON
 get_tree().paused = true
 state_changed.emit("won")
 
 var summary := {
  "result": "win",
  "time_left": time_remaining,
  "total_time": config.mission_duration if config else 120.0,
  "progress": progress.duplicate(),
  "targets": targets.duplicate(),
 }
 mission_won.emit(summary)

func _fail_mission() -> void:
 current_state = State.LOST
 get_tree().paused = true
 state_changed.emit("lost")
 
 var summary := {
  "result": "lost",
  "time_left": 0.0,
  "total_time": config.mission_duration if config else 120.0,
  "progress": progress.duplicate(),
  "targets": targets.duplicate(),
 }
 mission_lost.emit(summary)

func _emit_all_objectives() -> void:
 for id in ["basket", "trash", "sofa", "banana"]:
  objective_updated.emit(id, progress[id], targets[id], progress[id] >= targets[id])

func get_progress_dict() -> Dictionary:
 return {
  "progress": progress.duplicate(),
  "targets": targets.duplicate(),
  "time_remaining": time_remaining,
  "is_won": current_state == State.WON,
  "is_lost": current_state == State.LOST,
 }
