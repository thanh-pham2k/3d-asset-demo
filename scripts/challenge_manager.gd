class_name ChallengeManager
extends Node

signal challenge_updated(index: int, challenge: Dictionary)
signal challenge_completed(index: int, challenge: Dictionary)
signal all_challenges_completed()

var score_manager: Node
var active_challenges: Array[Dictionary] = []

const CHALLENGE_POOL := [
 {
  "id": "smash_items",
  "title": "Kẻ Đập Phá",
  "template": "Làm vỡ %d đồ vật dễ vỡ",
  "base_target": 3,
  "scale_per_round": 1,
  "reward": 800,
  "event_type": "prop_broken",
 },
 {
  "id": "reach_combo",
  "title": "Vua Combo",
  "template": "Đạt chuỗi Combo x%.1f",
  "base_target": 2.5,
  "scale_per_round": 0.5,
  "reward": 1000,
  "event_type": "combo",
 },
 {
  "id": "hammer_smash",
  "title": "Giờ Búa Tạ",
  "template": "Dùng búa đập trúng %d lần",
  "base_target": 5,
  "scale_per_round": 2,
  "reward": 750,
  "event_type": "hammer_hit",
 },
 {
  "id": "topple_props",
  "title": "Cơn Lốc Phòng Khách",
  "template": "Xô đổ hoặc va chạm %d món đồ",
  "base_target": 8,
  "scale_per_round": 3,
  "reward": 600,
  "event_type": "prop_hit",
 },
 {
  "id": "chain_domino",
  "title": "Hiệu Ứng Domino",
  "template": "Tạo %d phản ứng dây chuyền",
  "base_target": 2,
  "scale_per_round": 1,
  "reward": 1200,
  "event_type": "chain_reaction",
 },
 {
  "id": "dash_rampage",
  "title": "Cú Tông Sấm Sét",
  "template": "Dùng lướt tông trúng %d món đồ",
  "base_target": 3,
  "scale_per_round": 1,
  "reward": 700,
  "event_type": "dash_impact",
 }
]

func _ready() -> void:
 add_to_group("challenge_manager")

func setup(p_score_manager: Node) -> void:
 score_manager = p_score_manager
 if not score_manager.chaos_event.is_connected(_on_chaos_event):
  score_manager.chaos_event.connect(_on_chaos_event)
 if not score_manager.combo_changed.is_connected(_on_combo_changed):
  score_manager.combo_changed.connect(_on_combo_changed)

func generate_round_challenges(round_num: int = 1) -> void:
 active_challenges.clear()
 var pool := CHALLENGE_POOL.duplicate(true)
 pool.shuffle()
 
 for i in mini(3, pool.size()):
  var spec: Dictionary = pool[i]
  var target_val = spec["base_target"]
  if spec["id"] == "reach_combo":
   target_val = minf(4.5, spec["base_target"] + (round_num - 1) * spec["scale_per_round"])
  else:
   target_val = spec["base_target"] + (round_num - 1) * spec["scale_per_round"]
  
  var desc: String = spec["template"] % target_val
  var ch := {
   "id": spec["id"],
   "title": spec["title"],
   "description": desc,
   "target": target_val,
   "current": 0.0 if spec["id"] == "reach_combo" else 0,
   "completed": false,
   "reward": spec["reward"] + (round_num - 1) * 200,
   "event_type": spec["event_type"],
  }
  active_challenges.append(ch)
  challenge_updated.emit(i, ch)

func _on_chaos_event(event_type: String, data: Dictionary) -> void:
 for i in active_challenges.size():
  var ch: Dictionary = active_challenges[i]
  if ch["completed"]: continue
  
  var match_found := false
  if ch["event_type"] == "prop_broken" and event_type == "prop_broken":
   ch["current"] += 1
   match_found = true
  elif ch["event_type"] == "hammer_hit" and event_type == "prop_hit" and data.get("is_hammer", false):
   ch["current"] += 1
   match_found = true
  elif ch["event_type"] == "prop_hit" and event_type == "prop_hit":
   ch["current"] += 1
   match_found = true
  elif ch["event_type"] == "chain_reaction" and event_type == "chain_reaction":
   ch["current"] += 1
   match_found = true
  elif ch["event_type"] == "dash_impact" and event_type == "dash_impact":
   ch["current"] += 1
   match_found = true
  
  if match_found:
   if ch["current"] >= ch["target"]:
    _complete_challenge(i)
   else:
    challenge_updated.emit(i, ch)

func _on_combo_changed(multiplier: float, _time_left: float, _max_time: float) -> void:
 for i in active_challenges.size():
  var ch: Dictionary = active_challenges[i]
  if ch["completed"] or ch["event_type"] != "combo": continue
  ch["current"] = maxf(ch["current"], multiplier)
  if ch["current"] >= ch["target"]:
   _complete_challenge(i)
  else:
   challenge_updated.emit(i, ch)

func _complete_challenge(index: int) -> void:
 var ch: Dictionary = active_challenges[index]
 ch["completed"] = true
 ch["current"] = ch["target"]
 challenge_updated.emit(index, ch)
 challenge_completed.emit(index, ch)
 
 if is_instance_valid(score_manager):
  score_manager.register_challenge_bonus(ch["reward"], ch["title"])
 
 var all_done := true
 for c in active_challenges:
  if not c["completed"]:
   all_done = false
   break
 if all_done:
  all_challenges_completed.emit()

func get_completed_count() -> int:
 var count := 0
 for ch in active_challenges:
  if ch["completed"]: count += 1
 return count
