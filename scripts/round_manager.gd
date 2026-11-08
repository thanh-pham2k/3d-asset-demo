class_name RoundManager
extends Node

signal state_changed(old_state: String, new_state: String)
signal round_started(round_number: int, duration: float)
signal time_tick(time_remaining: float, total_duration: float)
signal round_ended(summary: Dictionary)

enum State { MENU, PLAYING, PAUSED, RESULTS }

@export var round_duration: float = 60.0

var current_state: State = State.MENU
var round_number: int = 1
var time_remaining: float = 60.0

var score_manager: Node
var challenge_manager: Node

func _ready() -> void:
 add_to_group("round_manager")
 process_mode = Node.PROCESS_MODE_ALWAYS

func setup(p_score: Node, p_challenge: Node) -> void:
 score_manager = p_score
 challenge_manager = p_challenge
 if is_instance_valid(challenge_manager) and is_instance_valid(score_manager):
  challenge_manager.setup(score_manager)

func _process(delta: float) -> void:
 if current_state != State.PLAYING: return
 if get_tree().paused: return
 
 time_remaining -= delta
 time_tick.emit(maxf(0.0, time_remaining), round_duration)
 
 if time_remaining <= 0.0:
  end_round()

func set_state(new_state: State) -> void:
 var old := current_state
 current_state = new_state
 state_changed.emit(_state_name(old), _state_name(new_state))

func _state_name(s: State) -> String:
 match s:
  State.MENU: return "menu"
  State.PLAYING: return "playing"
  State.PAUSED: return "paused"
  State.RESULTS: return "results"
 return "unknown"

func start_round() -> void:
 time_remaining = round_duration
 if is_instance_valid(score_manager):
  score_manager.reset()
 if is_instance_valid(challenge_manager):
  challenge_manager.generate_round_challenges(round_number)
 
 set_state(State.PLAYING)
 get_tree().paused = false
 round_started.emit(round_number, round_duration)

func pause_round() -> void:
 if current_state == State.PLAYING:
  set_state(State.PAUSED)
  get_tree().paused = true

func resume_round() -> void:
 if current_state == State.PAUSED:
  set_state(State.PLAYING)
  get_tree().paused = false

func end_round() -> void:
 time_remaining = 0.0
 set_state(State.RESULTS)
 get_tree().paused = true
 
 var summary := {}
 if is_instance_valid(score_manager):
  summary = score_manager.get_summary()
 if is_instance_valid(challenge_manager):
  summary["challenges_completed"] = challenge_manager.get_completed_count()
  summary["total_challenges"] = challenge_manager.active_challenges.size()
 summary["round_number"] = round_number
 
 round_ended.emit(summary)

func retry_round() -> void:
 get_tree().paused = false
 start_round()

func next_round() -> void:
 round_number += 1
 get_tree().paused = false
 start_round()
