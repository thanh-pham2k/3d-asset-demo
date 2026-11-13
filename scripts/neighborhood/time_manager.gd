class_name NeighborhoodTimeManager
extends Node

## In-game clock managing day-night cycle, schedule progression, and time periods
## for the living neighborhood simulation.

signal time_updated(current_hour: float)
signal period_changed(new_period: String)
signal hour_ticked(hour: int)
# Only emitted for real clock progression, not manual clock changes or sleep.
signal hour_elapsed(hour: int)
signal sleep_time_advanced(hours_before_midnight: float)
signal day_advanced(new_day: int)

@export var current_day: int = 1
# In-game hour: 0.0 to 24.0 (starts at 8:00 AM)
@export var current_hour: float = 8.0

# 1 real-world second = time_scale in-game minutes
# default: 1 real second = 2 in-game minutes -> 1 in-game hour = 30 real seconds -> 24h = 12 minutes
@export var time_scale: float = 2.0 # minutes per real second
@export var is_paused: bool = false

var current_period: String = "morning"
var _last_int_hour: int = 8

var directional_light: DirectionalLight3D
var world_environment: WorldEnvironment

func _ready() -> void:
	add_to_group("time_manager")
	current_period = get_period_name(current_hour)
	_last_int_hour = int(current_hour)

func _process(delta: float) -> void:
	if is_paused: return
	
	# Advance time: (time_scale minutes / 60) hours per second
	var hours_passed := maxf(0.0, (time_scale / 60.0) * delta)
	var previous_hour := current_hour
	var end_hour := previous_hour + hours_passed
	var crossed_hours := int(floor(end_hour)) - int(floor(previous_hour))
	for step in range(1, crossed_hours + 1):
		var tick := (int(floor(previous_hour)) + step) % 24
		current_hour = float(tick)
		_last_int_hour = tick
		if tick == 0:
			# Finish the last watered hour before the new day dries the plots.
			hour_elapsed.emit(tick)
			current_day += 1
			day_advanced.emit(current_day)
			hour_ticked.emit(tick)
		else:
			hour_ticked.emit(tick)
			hour_elapsed.emit(tick)
	current_hour = fposmod(end_hour, 24.0)
	
	var period := get_period_name(current_hour)
	if period != current_period:
		current_period = period
		period_changed.emit(current_period)
	
	time_updated.emit(current_hour)
	_update_lighting()

func advance_to_next_day(wake_hour: float = 7.0) -> void:
	# Crops receive only the remaining watered time before the day changes.
	sleep_time_advanced.emit(maxf(0.0, 24.0 - current_hour))
	current_day += 1
	current_hour = fposmod(wake_hour, 24.0)
	_last_int_hour = int(current_hour)
	current_period = get_period_name(current_hour)
	period_changed.emit(current_period)
	hour_ticked.emit(_last_int_hour)
	time_updated.emit(current_hour)
	_update_lighting()
	day_advanced.emit(current_day)

func set_hour(hour: float) -> void:
	current_hour = fposmod(hour, 24.0)
	_last_int_hour = int(current_hour)
	var period := get_period_name(current_hour)
	if period != current_period:
		current_period = period
		period_changed.emit(current_period)
	hour_ticked.emit(_last_int_hour)
	time_updated.emit(current_hour)
	_update_lighting()

func get_period_name(hour: float) -> String:
	var h := fposmod(hour, 24.0)
	if h >= 6.0 and h < 11.5:
		return "morning"
	elif h >= 11.5 and h < 14.0:
		return "noon"
	elif h >= 14.0 and h < 19.0:
		return "evening"
	else:
		return "night"

func get_time_formatted() -> String:
	var hours := int(current_hour)
	var minutes := int((current_hour - hours) * 60.0)
	var period_str := "sáng"
	if hours >= 11 and hours < 14:
		period_str = "trưa"
	elif hours >= 14 and hours < 18:
		period_str = "chiều"
	elif hours >= 18 or hours < 5:
		period_str = "tối"
	
	return "Ngày %d · %02d:%02d (%s)" % [current_day, hours, minutes, period_str]

func _update_lighting() -> void:
	if not is_instance_valid(directional_light): return
	
	# Sun rotation and energy smoothly adjusted based on in-game time
	# Daytime: 6:00 to 18:00
	var h := current_hour
	if h >= 5.5 and h <= 18.5:
		var day_progress := (h - 5.5) / 13.0 # 0.0 at dawn, 0.5 at noon, 1.0 at dusk
		var pitch := -20.0 - sin(day_progress * PI) * 45.0 # -20 to -65 deg
		var yaw := -75.0 + day_progress * 80.0
		directional_light.rotation_degrees = Vector3(pitch, yaw, 0)
		var peak := sin(day_progress * PI)
		directional_light.light_energy = lerpf(0.25, 0.65, peak)
		directional_light.light_color = Color("fff3e0").lerp(Color("ffeed1"), peak)
	else:
		# Night lighting: soft moonlight
		directional_light.rotation_degrees = Vector3(-45, 120, 0)
		directional_light.light_energy = 0.15
		directional_light.light_color = Color("a8c2d8")
