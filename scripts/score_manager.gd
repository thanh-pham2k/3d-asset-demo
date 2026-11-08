class_name ScoreManager
extends Node

signal score_added(points_added: int, total_score: int, reason: String, world_pos: Vector3)
signal combo_changed(multiplier: float, time_left: float, max_time: float)
signal combo_ended(final_multiplier: float)
signal chaos_event(event_type: String, data: Dictionary)

const COMBO_WINDOW := 3.2
const COMBO_STEP := 0.25
const MAX_COMBO := 5.0

const POINTS := {
 "hit": 50,
 "hammer": 150,
 "break": 350,
 "chain": 250,
 "dash": 100,
}

var score: int = 0
var high_score: int = 0
var combo_multiplier: float = 1.0
var combo_timer: float = 0.0
var max_combo_reached: float = 1.0

var props_broken: int = 0
var props_hit: int = 0
var chain_hits: int = 0
var hammer_hits: int = 0
var dash_hits: int = 0

var _cooldowns: Dictionary = {}

func _ready() -> void:
 add_to_group("score_manager")

func _process(delta: float) -> void:
 # Update cooldowns
 var expired := []
 for id in _cooldowns:
  _cooldowns[id] -= delta
  if _cooldowns[id] <= 0.0:
   expired.append(id)
 for id in expired:
  _cooldowns.erase(id)
 
 # Update combo timer
 if combo_timer > 0.0:
  combo_timer = maxf(0.0, combo_timer - delta)
  combo_changed.emit(combo_multiplier, combo_timer, COMBO_WINDOW)
  if combo_timer <= 0.0 and combo_multiplier > 1.0:
   combo_ended.emit(combo_multiplier)
   combo_multiplier = 1.0
   combo_changed.emit(combo_multiplier, 0.0, COMBO_WINDOW)

func _is_on_cooldown(obj: Object) -> bool:
 var id := obj.get_instance_id() if is_instance_valid(obj) else 0
 return _cooldowns.has(id)

func _set_cooldown(obj: Object, duration: float = 0.35) -> void:
 if is_instance_valid(obj):
  _cooldowns[obj.get_instance_id()] = duration

func _apply_combo_and_score(base_points: int, reason: String, pos: Vector3) -> int:
 combo_multiplier = minf(MAX_COMBO, combo_multiplier + COMBO_STEP)
 max_combo_reached = maxf(max_combo_reached, combo_multiplier)
 combo_timer = COMBO_WINDOW
 combo_changed.emit(combo_multiplier, combo_timer, COMBO_WINDOW)
 
 var points := int(roundf(float(base_points) * combo_multiplier))
 score += points
 if score > high_score:
  high_score = score
 score_added.emit(points, score, reason, pos)
 return points

func register_prop_hit(prop: Object, impulse_magnitude: float, is_hammer: bool = false, source_pos: Vector3 = Vector3.ZERO) -> int:
 if not is_instance_valid(prop): return 0
 if not is_hammer and impulse_magnitude < 1.2:
  return 0
 if _is_on_cooldown(prop):
  return 0
 
 _set_cooldown(prop, 0.35)
 props_hit += 1
 
 var reason := "ĐẬP BÚA!" if is_hammer else "VA CHẠM!"
 var base := POINTS["hammer"] if is_hammer else POINTS["hit"]
 if is_hammer: hammer_hits += 1
 
 var pos: Vector3 = source_pos
 if prop is Node3D:
  pos = prop.global_position
 var pts := _apply_combo_and_score(base, reason, pos)
 chaos_event.emit("prop_hit", {"prop": prop, "is_hammer": is_hammer, "points": pts})
 return pts

func register_prop_broken(prop: Object, prop_kind: String, pos: Vector3) -> int:
 props_broken += 1
 var reason := "VỠ NÁT (%s)!" % prop_kind.to_upper()
 var pts := _apply_combo_and_score(POINTS["break"], reason, pos)
 chaos_event.emit("prop_broken", {"prop_kind": prop_kind, "points": pts, "position": pos})
 return pts

func register_chain_reaction(prop_a: Object, prop_b: Object, chain_level: int, pos: Vector3) -> int:
 if not is_instance_valid(prop_b):
  return 0
 _set_cooldown(prop_b, 0.35)
 chain_hits += 1
 var reason := "DÂY CHUYỀN x%d!" % chain_level
 var base := POINTS["chain"] * mini(chain_level, 3)
 var pts := _apply_combo_and_score(base, reason, pos)
 chaos_event.emit("chain_reaction", {"chain_level": chain_level, "points": pts})
 return pts

func register_dash_impact(prop: Object, pos: Vector3) -> int:
 if not is_instance_valid(prop) or _is_on_cooldown(prop): return 0
 _set_cooldown(prop, 0.4)
 dash_hits += 1
 var pts := _apply_combo_and_score(POINTS["dash"], "LƯỚT HÚC!", pos)
 chaos_event.emit("dash_impact", {"prop": prop, "points": pts})
 return pts

func register_challenge_bonus(bonus_points: int, challenge_title: String) -> void:
 score += bonus_points
 if score > high_score: high_score = score
 score_added.emit(bonus_points, score, "NHIỆM VỤ: " + challenge_title, Vector3.ZERO)
 chaos_event.emit("challenge_bonus", {"title": challenge_title, "points": bonus_points})

func get_rank() -> String:
 if score >= 14000: return "S"
 elif score >= 9000: return "A"
 elif score >= 5000: return "B"
 elif score >= 2000: return "C"
 else: return "D"

func get_summary() -> Dictionary:
 return {
  "score": score,
  "high_score": high_score,
  "rank": get_rank(),
  "max_combo": max_combo_reached,
  "props_broken": props_broken,
  "props_hit": props_hit,
  "chain_hits": chain_hits,
  "hammer_hits": hammer_hits,
  "dash_hits": dash_hits,
 }

func reset() -> void:
 score = 0
 combo_multiplier = 1.0
 combo_timer = 0.0
 max_combo_reached = 1.0
 props_broken = 0
 props_hit = 0
 chain_hits = 0
 hammer_hits = 0
 dash_hits = 0
 _cooldowns.clear()
 combo_changed.emit(1.0, 0.0, COMBO_WINDOW)
