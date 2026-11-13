extends Node3D

## Small visual-only park wildlife. No bodies, triggers, or gameplay navigation.
var creatures: Array[Node3D] = []
var centers: Array[Vector3] = []
var elapsed: float = 0.0
var player: Node3D
var clock: NeighborhoodTimeManager

func _ready() -> void:
	player = get_tree().get_first_node_in_group("players") as Node3D
	clock = get_tree().get_first_node_in_group("time_manager") as NeighborhoodTimeManager
	var wing_mat := StandardMaterial3D.new()
	wing_mat.albedo_color = Color("f4d18a")
	wing_mat.roughness = 1.0
	var bird_mat := StandardMaterial3D.new()
	bird_mat.albedo_color = Color("eee6d4")
	bird_mat.roughness = 1.0
	var wing_mesh := BoxMesh.new()
	wing_mesh.size = Vector3(0.22, 0.035, 0.12)
	var bird_mesh := BoxMesh.new()
	bird_mesh.size = Vector3(0.32, 0.06, 0.16)
	for i in range(6):
		var butterfly := i < 3
		var creature := Node3D.new()
		creature.name = ("Butterfly" if butterfly else "Bird") + str(i)
		var mesh: Mesh = wing_mesh if butterfly else bird_mesh
		var material: Material = wing_mat if butterfly else bird_mat
		for side in [-1.0, 1.0]:
			var wing := MeshInstance3D.new()
			wing.name = "WingLeft" if side < 0.0 else "WingRight"
			wing.mesh = mesh
			wing.material_override = material
			wing.position.x = side * (0.11 if butterfly else 0.16)
			creature.add_child(wing)
		add_child(creature)
		creatures.append(creature)
		centers.append(Vector3(20.0 + float(i) * 7.0, 1.15 if butterfly else 5.0, 42.0 + float(i % 3) * 8.0))

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("players") as Node3D
	if not is_instance_valid(clock):
		clock = get_tree().get_first_node_in_group("time_manager") as NeighborhoodTimeManager
	var daytime := not is_instance_valid(clock) or clock.current_hour >= 6.0 and clock.current_hour < 19.0
	var nearby := is_instance_valid(player) and player.global_position.distance_to(to_global(Vector3(42, 0, 53))) < 70.0
	visible = daytime and nearby
	if not visible:
		return
	elapsed += delta
	for i in range(creatures.size()):
		var phase := elapsed * (1.3 if i < 3 else 0.4) + float(i) * 2.1
		var radius := 0.8 if i < 3 else 4.0
		var creature := creatures[i]
		creature.position = centers[i] + Vector3(cos(phase) * radius, sin(phase * 2.0) * 0.22, sin(phase) * radius)
		creature.rotation.y = -phase
		var left := creature.get_node("WingLeft") as Node3D
		var right := creature.get_node("WingRight") as Node3D
		var flap := sin(elapsed * (11.0 if i < 3 else 5.0) + float(i)) * 0.65
		left.rotation.z = flap
		right.rotation.z = -flap
