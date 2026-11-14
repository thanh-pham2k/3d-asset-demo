class_name CropTimer
extends RefCounted
## Tracks deterministic crop growth using GameClock timestamps.

var planted_at_unix: int = 0
var grow_duration_sec: int = 300

func start(now_unix: int, duration_sec: int) -> void:
	planted_at_unix = now_unix
	grow_duration_sec = maxi(1, duration_sec)

func clear() -> void:
	planted_at_unix = 0

func get_elapsed_seconds(now_unix: int) -> int:
	if planted_at_unix <= 0:
		return 0
	return maxi(0, now_unix - planted_at_unix)

func get_remaining_seconds(now_unix: int) -> int:
	if planted_at_unix <= 0:
		return 0
	return maxi(0, grow_duration_sec - get_elapsed_seconds(now_unix))

func get_progress(now_unix: int) -> float:
	if planted_at_unix <= 0 or grow_duration_sec <= 0:
		return 0.0
	return clampf(float(get_elapsed_seconds(now_unix)) / float(grow_duration_sec), 0.0, 1.0)

func is_mature(now_unix: int) -> bool:
	return planted_at_unix > 0 and get_elapsed_seconds(now_unix) >= grow_duration_sec
