extends Camera3D
var players: Array = []
var trauma := 0.0
var max_trauma_offset := 0.45
var max_trauma_roll := 0.06
var trauma_decay := 1.8
var base_position: Vector3

func _ready() -> void:
 projection = Camera3D.PROJECTION_ORTHOGONAL
 size = 8.8
 current = true
 position = Vector3(0, 12.5, 13.5)
 base_position = position
 look_at(Vector3(0,0.2,-0.25), Vector3.UP)

func add_trauma(amount: float) -> void:
 trauma = clampf(trauma + amount, 0.0, 1.0)

func _process(delta: float) -> void:
 if players.is_empty() or not is_instance_valid(players[0]): return
 # Keep the same apparent scale while following the player into the wider ends.
 var target_x: float = clampf(players[0].global_position.x, -1.8, 1.8)
 base_position.x = lerpf(base_position.x, target_x, 1.0 - exp(-4.0 * delta))
 
 # Screen shake with quadratic trauma falloff
 if trauma > 0.0:
  trauma = maxf(0.0, trauma - trauma_decay * delta)
  var shake := trauma * trauma
  var offset_x := (randf() * 2.0 - 1.0) * max_trauma_offset * shake
  var offset_y := (randf() * 2.0 - 1.0) * max_trauma_offset * shake
  position = base_position + Vector3(offset_x, offset_y, 0)
  rotation.z = (randf() * 2.0 - 1.0) * max_trauma_roll * shake
 else:
  position = base_position
  rotation.z = 0.0

