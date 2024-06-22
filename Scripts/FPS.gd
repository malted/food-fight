extends Label

func _process(delta):
	text = "%s FPS" % Engine.get_frames_per_second()
