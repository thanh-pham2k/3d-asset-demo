extends SceneTree

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var root_node := Node3D.new()
 root.add_child(root_node)
 var feedback = load("res://scripts/effects/chaos_feedback.gd").new()
 root_node.add_child(feedback)
 await process_frame
 for event_name in feedback.EVENT_SPECS:
  feedback.play_event(event_name, Vector3.ZERO)
 var expected = feedback.EVENT_SPECS.size()
 var particles := 0
 var sounds := 0
 for child in feedback.get_children():
  if child is CPUParticles3D: particles += 1
  if child is AudioStreamPlayer3D:
   sounds += 1
   assert(child.stream is AudioStream and child.stream.get_length() > 0.0)
 assert(particles == expected)
 assert(sounds == 9)
 for event_name in feedback.AUDIO_FILES:
  assert(feedback._sounds[event_name] is AudioStreamOggVorbis)
  assert(feedback._sounds[event_name].resource_path == feedback.AUDIO_FILES[event_name])
 print("PASS: %d feedback events created, %d Kenney audio streams loaded" % [particles, sounds])
 await create_timer(3.0).timeout
 assert(feedback.get_child_count() == 0)
 print("PASS: feedback nodes clean up")
 root_node.queue_free()
 quit()
