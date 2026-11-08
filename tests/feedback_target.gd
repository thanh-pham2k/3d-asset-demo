extends CharacterBody3D
var was_hit := false
func _ready() -> void:
 collision_layer = 2
 collision_mask = 1
 add_to_group("players")
 var collider := CollisionShape3D.new()
 var shape := CapsuleShape3D.new()
 shape.radius = 0.3
 shape.height = 1.5
 collider.shape = shape
 collider.position.y = 0.75
 add_child(collider)
func hit(_direction: Vector3) -> void:
 was_hit = true
