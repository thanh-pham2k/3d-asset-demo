class_name FarmPlot
extends RefCounted
## Pure state model for a single farm plot (EMPTY / GROWING / READY / LOCKED).

enum State { EMPTY, GROWING, READY, LOCKED }

var id: int = 0
var state: State = State.EMPTY
var crop_id: String = ""
var timer: CropTimer = CropTimer.new()

func _init(plot_id: int = 0, initial_state: State = State.EMPTY) -> void:
	id = plot_id
	state = initial_state

func plant(new_crop_id: String, now_unix: int, duration_sec: int) -> bool:
	if state != State.EMPTY:
		return false
	crop_id = new_crop_id
	state = State.GROWING
	timer.start(now_unix, duration_sec)
	return true

func update_growth(now_unix: int) -> bool:
	if state != State.GROWING:
		return false
	if timer.is_mature(now_unix):
		state = State.READY
		return true
	return false

func harvest() -> bool:
	if state != State.READY:
		return false
	crop_id = ""
	state = State.EMPTY
	timer.clear()
	return true

func unlock() -> bool:
	if state != State.LOCKED:
		return false
	state = State.EMPTY
	return true

func state_name() -> String:
	match state:
		State.EMPTY: return "EMPTY"
		State.GROWING: return "GROWING"
		State.READY: return "READY"
		State.LOCKED: return "LOCKED"
	return "EMPTY"

static func parse_state(raw: String) -> State:
	match raw:
		"GROWING": return State.GROWING
		"READY": return State.READY
		"LOCKED": return State.LOCKED
		_: return State.EMPTY
