extends Node

func _process(delta) -> void:
	DebugDraw2D.set_text("Frames", Engine.get_frames_drawn())
	DebugDraw2D.set_text("FPS", Engine.get_frames_per_second())
	DebugDraw2D.set_text("Delta", delta)
