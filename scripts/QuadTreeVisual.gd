extends Node2D

@export var sim: Simulation
var size: Vector2

func _process(_delta) -> void:
	if Input.is_action_just_released("num0"):
		visible = !visible
		
	if size.x != sim.width || size.y != sim.height:
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

func resizeVec2(pos: Vector2) -> Vector2:
	return pos / size * get_viewport_rect().size

func resizeRect(rect: Rect2) -> Rect2:
	return Rect2(resizeVec2(rect.position), resizeVec2(rect.size))
