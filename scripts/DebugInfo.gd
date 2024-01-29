extends Node

@export var sim: Simulation
var elementString: String = ""

func _ready() -> void:
	var graphFps := DebugDraw2D.create_graph("graph_fps")
	graphFps.show_title = true
	
	for i in Cell.Elements.size():
		if i == 0: # Ignore empty
			continue
		elementString += "%s (%s)  " % [Cell.Elements.keys()[i], i]

func _process(delta) -> void:
	DebugDraw2D.set_text(elementString, null, -10)
	DebugDraw2D.set_text("Selected", sim.selectedElement, -9)
	DebugDraw2D.set_text("Brush size (scroll)", sim.brushRadius + 1, -8)
	DebugDraw2D.set_text("Square brush", sim.squareBrush, -7)
	DebugDraw2D.set_text("---Stats---", null, -1)
	
	DebugDraw2D.set_text("Frames", Engine.get_frames_drawn())
	#DebugDraw2D.set_text("FPS", Engine.get_frames_per_second())
	DebugDraw2D.graph_update_data("graph_fps", Engine.get_frames_per_second())
	DebugDraw2D.set_text("Delta", delta)
	
	var cells := 0
	#var visitedCells := 0
	for x in sim.width:
		for y in sim.height:
			var cell := sim.getCell(x, y)
			if cell.element != Cell.Elements.EMPTY:
				cells += 1
				#if cell.visited:
					#visitedCells += 1
	DebugDraw2D.set_text("Cells", cells)
	#DebugDraw2D.set_text("Cells (Visited)", visitedCells)
