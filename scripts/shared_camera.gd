extends Camera3D
var players: Array = []
func _ready() -> void:
 projection = Camera3D.PROJECTION_ORTHOGONAL
 size = 8.8
 current = true
 position = Vector3(0, 12.5, 13.5)
 look_at(Vector3(0,0.2,-0.25), Vector3.UP)

func _process(delta: float) -> void:
 if players.is_empty() or not is_instance_valid(players[0]): return
 # Keep the same apparent scale while following the player into the wider ends.
 var target_x: float = clampf(players[0].global_position.x, -1.8, 1.8)
 position.x = lerpf(position.x, target_x, 1.0 - exp(-4.0 * delta))
