extends Camera3D
var players: Array = []
var trauma := 0.0
var max_trauma_offset := 0.45
var max_trauma_roll := 0.06
var trauma_decay := 1.8
var base_position: Vector3

func _ready() -> void:
 projection = Camera3D.PROJECTION_ORTHOGONAL
 size = 11.5
 current = true
 position = Vector3(0, 12.5, 13.5)
 base_position = position
 look_at(get_parent().to_global(Vector3(0,0.2,-0.25)), Vector3.UP)

func add_trauma(amount: float) -> void:
 trauma = clampf(trauma + amount, 0.0, 1.0)

func _process(delta: float) -> void:
 if players.is_empty() or not is_instance_valid(players[0]): return
 var local_target: Vector3 = get_parent().to_local(players[0].global_position)
 base_position = Vector3(local_target.x, 12.5, local_target.z + 13.5)
 
 # Screen shake with quadratic trauma falloff
 if trauma > 0.0:
  trauma = maxf(0.0, trauma - trauma_decay * delta)
  var shake := trauma * trauma
  var offset_x := (randf() * 2.0 - 1.0) * max_trauma_offset * shake
  var offset_y := (randf() * 2.0 - 1.0) * max_trauma_offset * shake
  position = base_position + Vector3(offset_x, offset_y, 0)
  look_at(players[0].global_position + Vector3(0, 0.2, 0), Vector3.UP)
  rotate_object_local(Vector3.BACK, (randf() * 2.0 - 1.0) * max_trauma_roll * shake)
 else:
  position = base_position
  look_at(players[0].global_position + Vector3(0, 0.2, 0), Vector3.UP)

