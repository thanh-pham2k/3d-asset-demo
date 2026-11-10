class_name CoopAssemblyBench
extends Interactable

## Interactive flatpack assembly station.
## Assembling alone takes 8 seconds; assembling together with your partner
## receives a 3.2x synergy speedup (2.5 seconds) with duo teamwork effects!

signal assembly_completed(furniture_id: String, assembled_node: Node3D)
signal assembly_progress_updated(progress_pct: float)

@export var bench_furniture_id: String = "furn_deluxe_sofa"
@export var furniture_name: String = "Sofa vintage nệm xanh"

var assembly_progress: float = 0.0 # 0 to 100
var is_assembled: bool = false
var active_workers: Array[CharacterBody3D] = []

var progress_label: Label3D
var box_mesh: MeshInstance3D

func _ready() -> void:
	furniture_id = bench_furniture_id
	kind = "assembly_bench"
	display_name = "Thùng Lắp Ráp: " + furniture_name
	add_to_group("interactables")
	_build_visual()

func _build_visual() -> void:
	box_mesh = MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(1.4, 0.4, 0.9)
	box_mesh.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("c49a6c") # Cardboard
	box_mesh.material_override = mat
	box_mesh.position = Vector3(0, 0.2, 0)
	add_child(box_mesh)
	
	progress_label = Label3D.new()
	progress_label.position = Vector3(0, 1.2, 0)
	progress_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	progress_label.font_size = 28
	progress_label.modulate = Color("ffd54f")
	progress_label.text = "📦 Lắp ráp: 0%"
	add_child(progress_label)
	
	# Solid collision
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.4, 0.4, 0.9)
	col.shape = shape
	col.position = Vector3(0, 0.2, 0)
	body.add_child(col)
	add_child(body)

func prompt(player_node: Node3D) -> String:
	if is_assembled: return "Đã hoàn tất lắp ráp!"
	var p := player_node as CharacterBody3D
	if active_workers.has(p):
		return "Đang lắp ráp... (%d%%) · Nhấn để dừng" % int(assembly_progress)
	elif active_workers.size() > 0:
		return "🤝 Cùng P%d lắp ráp (Tăng tốc độ 3x!)" % active_workers[0].player_id
	else:
		return "Bắt đầu lắp ráp %s (%d%%)" % [furniture_name, int(assembly_progress)]

func interact(player_node: Node3D) -> void:
	if is_assembled: return
	var p := player_node as CharacterBody3D
	if not is_instance_valid(p): return
	
	if active_workers.has(p):
		active_workers.erase(p)
	else:
		active_workers.append(p)

func get_current_assembly_speed() -> float:
	return 40.0 if active_workers.size() >= 2 else 12.5

func _process(delta: float) -> void:
	if is_assembled: return
	
	# Remove any worker that walked away (> 2.5m)
	for i in range(active_workers.size() - 1, -1, -1):
		var w := active_workers[i]
		if not is_instance_valid(w) or global_position.distance_to(w.global_position) > 2.5:
			active_workers.remove_at(i)
	
	if active_workers.is_empty(): return
	
	# Rate: 1 worker = 12.5%/s (8s). 2 workers = 40.0%/s (2.5s)
	var speed := 40.0 if active_workers.size() >= 2 else 12.5
	assembly_progress = minf(100.0, assembly_progress + speed * delta)
	
	progress_label.text = "📦 Lắp ráp: %d%%%s" % [
		int(assembly_progress),
		" ⚡ TỐC ĐỘ ĐÔI!" if active_workers.size() >= 2 else ""
	]
	assembly_progress_updated.emit(assembly_progress)
	
	if assembly_progress >= 100.0:
		_complete_assembly()

func _complete_assembly() -> void:
	is_assembled = true
	active_workers.clear()
	progress_label.text = "✨ ĐÃ HOÀN TẤT LẮP RÁP!"
	progress_label.modulate = Color("69f0ae")
	
	# Hide cardboard box
	box_mesh.visible = false
	
	# Spawn assembled furniture
	var assembled := FurnitureData.create_placed_instance(furniture_id, global_position, rotation.y)
	get_parent().add_child(assembled)
	
	assembly_completed.emit(furniture_id, assembled)
