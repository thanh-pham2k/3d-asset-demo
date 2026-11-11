class_name FrameRecorder
extends Node

## Captures rendered viewport frames and compiles them into animated GIFs.
## Coordinates with tests/visual/capture/make_gif.py using Pillow.

@export var viewport: Viewport
var recording: bool = false
var current_scenario: String = ""
var frame_index: int = 0
var frames_dir: String = ""
var output_gif_path: String = ""

func setup(p_viewport: Viewport = null) -> void:
	viewport = p_viewport if p_viewport else get_viewport()

func start_recording(scenario_name: String) -> void:
	current_scenario = scenario_name
	recording = true
	frame_index = 0
	frames_dir = "/tmp/cc_frames/%s" % scenario_name
	output_gif_path = "artifacts/gameplay-tests/%s.gif" % scenario_name
	
	if DirAccess.dir_exists_absolute(frames_dir):
		# Clean old frames
		var d = DirAccess.open(frames_dir)
		if d:
			d.list_dir_begin()
			var fn = d.get_next()
			while fn != "":
				if fn.ends_with(".png"):
					DirAccess.remove_absolute(frames_dir + "/" + fn)
				fn = d.get_next()
	else:
		DirAccess.make_dir_recursive_absolute(frames_dir)
	
	print("[FrameRecorder] Started recording '%s' into %s" % [scenario_name, frames_dir])

func capture_now() -> void:
	if not recording or not is_instance_valid(viewport): return
	
	var img: Image = viewport.get_texture().get_image()
	if not img:
		push_warning("[FrameRecorder] Viewport image is null!")
		return
	
	var frame_path := "%s/frame_%04d.png" % [frames_dir, frame_index]
	img.save_png(frame_path)
	frame_index += 1

func step_and_capture(frames: int = 1) -> void:
	for i in frames:
		await RenderingServer.frame_post_draw
		capture_now()

func stop_recording_and_export_gif(fps: int = 12) -> String:
	recording = false
	print("[FrameRecorder] Finished capturing %d frames for '%s'. Assembling GIF..." % [frame_index, current_scenario])
	
	if frame_index == 0:
		printerr("[FrameRecorder] No frames captured for '%s'!" % current_scenario)
		return ""
	
	var script_path = ProjectSettings.globalize_path("res://tests/visual/capture/make_gif.py")
	var gif_abs_path = ProjectSettings.globalize_path("res://" + output_gif_path)
	
	var output: Array = []
	var args := [
		script_path,
		frames_dir,
		gif_abs_path,
		str(fps),
		"960",
		"540"
	]
	
	var exit_code = OS.execute("python3", args, output, true)
	if exit_code != 0:
		printerr("[FrameRecorder] make_gif.py failed with code %d:\n%s" % [exit_code, "\n".join(output)])
		return ""
	
	print("[FrameRecorder] %s" % "\n".join(output))
	
	# Clean up temporary PNG frames
	var d = DirAccess.open(frames_dir)
	if d:
		d.list_dir_begin()
		var fn = d.get_next()
		while fn != "":
			if fn.ends_with(".png"):
				DirAccess.remove_absolute(frames_dir + "/" + fn)
			fn = d.get_next()
		DirAccess.remove_absolute(frames_dir)
	
	return output_gif_path
