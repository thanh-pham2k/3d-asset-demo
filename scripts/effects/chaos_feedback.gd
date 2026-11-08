class_name ChaosFeedback
extends Node3D
## Call play_event(name, world_position) from the owning gameplay system.
## Repeated events such as running_dust / knockback_trail / throw_trail
## should be rate-limited by the caller. All effects clean themselves up.

signal event_played(event_name: String, world_position: Vector3)

const EVENT_SPECS := {
 "pickup": {"color": Color("fff1ad"), "count": 8, "velocity": 1.5, "frequency": 660.0, "duration": 0.10},
 "drop": {"color": Color("e9d9c3"), "count": 5, "velocity": 0.9, "frequency": 190.0, "duration": 0.07},
 "throw": {"color": Color("fff2c9"), "count": 6, "velocity": 1.4, "frequency": 480.0, "duration": 0.12},
 "pillow_impact": {"color": Color("f6c1ca"), "count": 10, "velocity": 1.5, "frequency": 155.0, "duration": 0.11},
 "bonk": {"color": Color("ffd960"), "count": 14, "velocity": 2.2, "frequency": 270.0, "duration": 0.15},
 "hit": {"color": Color("ffe270"), "count": 12, "velocity": 1.8, "frequency": 220.0, "duration": 0.13},
 "hit_stars": {"color": Color("ffe270"), "count": 10, "velocity": 1.6, "frequency": 0.0, "duration": 0.0},
 "dizzy": {"color": Color("ffeeb5"), "count": 5, "velocity": 0.6, "frequency": 0.0, "duration": 0.0},
 "knockback_trail": {"color": Color("ffe2b5"), "count": 5, "velocity": 0.6, "frequency": 0.0, "duration": 0.0},
 "running_dust": {"color": Color("e6d2b9"), "count": 5, "velocity": 0.5, "frequency": 0.0, "duration": 0.0},
 "throw_trail": {"color": Color("fff1cb"), "count": 4, "velocity": 0.4, "frequency": 0.0, "duration": 0.0},
 "landing": {"color": Color("ead7ba"), "count": 8, "velocity": 1.2, "frequency": 180.0, "duration": 0.08},
 "collision": {"color": Color("efd3ab"), "count": 8, "velocity": 1.3, "frequency": 235.0, "duration": 0.07},
 "footstep": {"color": Color("e7d5bd"), "count": 3, "velocity": 0.35, "frequency": 145.0, "duration": 0.045},
}

const AUDIO_FILES := {
 "pickup": "res://assets/audio/kenney_rpg/cloth1.ogg",
 "throw": "res://assets/audio/kenney_rpg/cloth3.ogg",
 "drop": "res://assets/audio/kenney_rpg/dropLeather.ogg",
 "pillow_impact": "res://assets/audio/kenney_impact/impactSoft_medium_000.ogg",
 "bonk": "res://assets/audio/kenney_impact/impactSoft_heavy_000.ogg",
 "hit": "res://assets/audio/kenney_impact/impactPunch_medium_000.ogg",
 "landing": "res://assets/audio/kenney_impact/impactWood_light_000.ogg",
 "collision": "res://assets/audio/kenney_impact/impactWood_medium_000.ogg",
 "footstep": "res://assets/audio/kenney_impact/footstep_wood_000.ogg",
}

var _sounds: Dictionary = {}
var _particle_mesh: SphereMesh
var _star_mesh: ArrayMesh

func _ready() -> void:
 _particle_mesh = SphereMesh.new()
 _particle_mesh.radius = 0.045
 _particle_mesh.height = 0.09
 _particle_mesh.radial_segments = 6
 _particle_mesh.rings = 3
 var material := StandardMaterial3D.new()
 material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 material.vertex_color_use_as_albedo = true
 material.cull_mode = BaseMaterial3D.CULL_DISABLED
 _particle_mesh.material = material
 _star_mesh = _make_star_mesh(material)

func play_event(event_name: String, world_position: Vector3) -> void:
 if not EVENT_SPECS.has(event_name):
  push_warning("Unknown feedback event: " + event_name)
  return
 var spec: Dictionary = EVENT_SPECS[event_name]
 event_played.emit(event_name, world_position)
 _spawn_particles(world_position, spec, event_name)
 if spec.frequency > 0.0:
  _play_sound(event_name, world_position, spec)

func _spawn_particles(world_position: Vector3, spec: Dictionary, event_name: String) -> void:
 var particles := CPUParticles3D.new()
 particles.name = "FeedbackParticles"
 particles.amount = spec.count
 particles.lifetime = 0.48
 particles.one_shot = true
 particles.explosiveness = 1.0
 particles.emitting = false
 particles.direction = Vector3.UP
 particles.spread = 75.0
 particles.initial_velocity_min = spec.velocity * 0.45
 particles.initial_velocity_max = spec.velocity
 particles.gravity = Vector3(0, -3.0, 0)
 particles.scale_amount_min = 0.6
 particles.scale_amount_max = 1.25
 particles.color = spec.color
 particles.mesh = _star_mesh if event_name in ["hit_stars", "bonk", "dizzy"] else _particle_mesh
 add_child(particles)
 particles.global_position = world_position
 particles.emitting = true
 get_tree().create_timer(0.8).timeout.connect(particles.queue_free)

func _play_sound(event_name: String, world_position: Vector3, spec: Dictionary) -> void:
 if not _sounds.has(event_name):
  var path: String = AUDIO_FILES.get(event_name, "")
  var asset: Resource = load(path) if not path.is_empty() and ResourceLoader.exists(path) else null
  _sounds[event_name] = asset if asset is AudioStream else _make_sound(event_name, spec.frequency, spec.duration)
 var player := AudioStreamPlayer3D.new()
 player.name = "FeedbackAudio"
 player.stream = _sounds[event_name]
 player.volume_db = -14.0
 player.max_distance = 20.0
 add_child(player)
 player.global_position = world_position
 player.finished.connect(player.queue_free)
 player.play()
 # In headless or muted configurations, do not leak if no finished signal arrives.
 var player_ref: WeakRef = weakref(player)
 get_tree().create_timer(maxf(spec.duration, player.stream.get_length()) + 1.0).timeout.connect(func():
  var remaining = player_ref.get_ref()
  if remaining: remaining.queue_free()
 )

func _make_sound(event_name: String, frequency: float, duration: float) -> AudioStreamWAV:
 const RATE := 22050
 var sample_count := maxi(1, int(RATE * duration))
 var data := PackedByteArray()
 data.resize(sample_count * 2)
 var phase := 0.0
 var filtered_noise := 0.0
 # A fixed seed makes generated assets reproducible across sessions.
 var noise := RandomNumberGenerator.new()
 noise.seed = hash(event_name)
 for i in sample_count:
  var progress := float(i) / sample_count
  var envelope := pow(maxf(0.0, 1.0 - progress), 2.0)
  var sweep := 1.0 - 0.40 * progress
  if event_name == "pickup": sweep = 0.75 + 0.8 * progress
  if event_name == "throw": sweep = 1.6 - 0.9 * progress
  phase += TAU * frequency * sweep / RATE
  filtered_noise = lerpf(filtered_noise, noise.randf_range(-1.0, 1.0), 0.12)
  var tone := sin(phase)
  var value := 0.0
  match event_name:
   "pickup":
    # Rising two-harmonic chime.
    value = (tone * 0.72 + sin(phase * 2.0) * 0.28) * envelope
   "throw":
    # Brief breathy sweep, distinct from the impact sounds.
    value = (filtered_noise * 1.4 + tone * 0.18) * sin(PI * progress)
   "bonk":
    # Hollow, slightly inharmonic toy-hammer resonance.
    value = (tone * 0.6 + sin(phase * 2.73) * 0.25 + filtered_noise * 0.15) * envelope
   "pillow_impact":
    # Soft fabric thud with an attenuated high end.
    value = (tone * 0.35 + filtered_noise * 1.2) * envelope
   "footstep":
    value = (tone * 0.22 + filtered_noise * 0.9) * envelope
   "collision":
    value = (tone * 0.35 + sin(phase * 3.1) * 0.30 + filtered_noise * 0.4) * envelope
   "landing", "drop":
    value = (tone * 0.65 + filtered_noise * 0.6) * envelope
   "hit":
    value = (tone * 0.5 + sin(phase * 1.5) * 0.25 + filtered_noise * 0.55) * envelope
   _:
    value = tone * envelope
  # Tiny attack suppresses a click at the start of each sound.
  value *= minf(1.0, float(i) / 35.0) * 0.35
  data.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
 var stream := AudioStreamWAV.new()
 stream.format = AudioStreamWAV.FORMAT_16_BITS
 stream.mix_rate = RATE
 stream.stereo = false
 stream.data = data
 return stream

func _make_star_mesh(material: Material) -> ArrayMesh:
 var vertices := PackedVector3Array()
 for i in range(10):
  var a0 := TAU * float(i) / 10.0
  var a1 := TAU * float(i + 1) / 10.0
  var r0 := 0.10 if i % 2 == 0 else 0.045
  var r1 := 0.10 if (i + 1) % 2 == 0 else 0.045
  vertices.append(Vector3.ZERO)
  vertices.append(Vector3(cos(a0) * r0, sin(a0) * r0, 0))
  vertices.append(Vector3(cos(a1) * r1, sin(a1) * r1, 0))
 var arrays := []
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX] = vertices
 var mesh := ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
 mesh.surface_set_material(0, material)
 return mesh
