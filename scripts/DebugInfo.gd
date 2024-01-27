extends Node

@export var sim: Simulation

func _process(delta) -> void:
	DebugDraw2D.set_text("Frames", Engine.get_frames_drawn())
	DebugDraw2D.set_text("FPS", Engine.get_frames_per_second())
	DebugDraw2D.set_text("Delta", delta)
	
	var cells := 0
	#var visitedCells := 0
	for x in sim.width:
		for y in sim.height:
			var cell := sim.getCell(x, y)
			if cell.type != Cell.Type.EMPTY:
				cells += 1
				#if cell.visited:
					#visitedCells += 1
	DebugDraw2D.set_text("Cells", cells)
	#DebugDraw2D.set_text("Cells (Visited)", visitedCells)
