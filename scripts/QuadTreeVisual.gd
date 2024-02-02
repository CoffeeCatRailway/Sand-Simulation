extends Node2D

@export var sim: Simulation
var size: Vector2

func _process(_delta) -> void:
	if !size:
		size = Vector2(sim.width, sim.height)
	queue_redraw()

func _draw() -> void:
	drawQuadTree(sim.matrix.quadTree)

func drawQuadTree(quad: QuadTree) -> void:
	draw_rect(resizeRect(quad.boundary), Color.RED, false, 2.)
	
	if quad.northWest == null:
		return
	
	drawQuadTree(quad.northWest)
	drawQuadTree(quad.northEast)
	drawQuadTree(quad.southWest)
	drawQuadTree(quad.southEast)

func resizeRect(rect: Rect2) -> Rect2:
	return Rect2(rect.position / size * get_viewport_rect().size, rect.size / size * get_viewport_rect().size)
