extends Node2D

@export var sim: Simulation
var elementString: String = ""
var size: Vector2
var showQuadTree: bool = false
var showThreadBounds: bool = false

func _ready() -> void:
	var graphFps := DebugDraw2D.create_graph("graph_fps")
	graphFps.show_title = true
	
	for i in Cell.Elements.size():
		if i == 0: # Ignore empty
			continue
		elementString += "%s (%s)  " % [Cell.Elements.keys()[i], i]

func debugInfo(delta) -> void:
	DebugDraw2D.set_text(elementString, null, -10)
	DebugDraw2D.set_text("Selected", Cell.Elements.keys()[sim.selectedElement], -9)
	DebugDraw2D.set_text("Brush size (scroll)", sim.brushRadius + 1, -8)
	DebugDraw2D.set_text("Square brush", sim.squareBrush, -7)
	DebugDraw2D.set_text("---Stats---", null, -1)
	
	DebugDraw2D.set_text("Frames", Engine.get_frames_drawn())
	DebugDraw2D.set_text("Physics Frames", Engine.get_physics_frames())
	#DebugDraw2D.set_text("FPS", Engine.get_frames_per_second())
	DebugDraw2D.graph_update_data("graph_fps", Engine.get_frames_per_second())
	DebugDraw2D.set_text("Delta", delta)
	
	sim.mutex.lock()
	DebugDraw2D.set_text("Cells", sim.cells.filter(func(cell): return cell != null && cell.element != Cell.Elements.EMPTY).size()) # TODO: Check why cell is null
	sim.mutex.unlock()
	#DebugDraw2D.set_text("Cells (Visited)", visitedCells)
	var active: int = 0
	for t in sim.threads:
		if t.is_alive():
			active += 1
	DebugDraw2D.set_text("Threads", "%s/%s" % [active, sim.threadCount])

func _process(delta) -> void:
	if Input.is_action_just_released("debug1"):
		showQuadTree = !showQuadTree
	if Input.is_action_just_released("debug2"):
		showThreadBounds = !showThreadBounds
	
	debugInfo(delta)
	
	if size.x != sim.width || size.y != sim.height:
		size = Vector2(sim.width, sim.height)
	
	queue_redraw()

func _draw() -> void:
	if showQuadTree:
		drawQuadTree(sim.quadTree)
	
	if showThreadBounds:
		# Draw thread bounds
		for i in sim.threadCount:
			var threadWidth: int = sim.width / sim.threadCount
			draw_rect(resizeRect(Rect2(threadWidth * i, 0., threadWidth, sim.height)), Color.GREEN, false, 1.)

func drawQuadTree(quad: QuadTree) -> void:
	draw_rect(resizeRect(quad.boundary), Color.RED, false, 2.)
	
	if quad.northWest == null:
		return
	
	drawQuadTree(quad.northWest)
	drawQuadTree(quad.northEast)
	drawQuadTree(quad.southWest)
	drawQuadTree(quad.southEast)

func resizeVec2(pos: Vector2) -> Vector2:
	return pos / size * sim.colorRect.size# * get_viewport_rect().size

func resizeRect(rect: Rect2) -> Rect2:
	return Rect2(resizeVec2(rect.position) + sim.colorRect.position, resizeVec2(rect.size))
