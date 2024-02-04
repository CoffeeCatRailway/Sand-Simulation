extends Node2D

@export var sim: Simulation
var size: Vector2

var font = ThemeDB.fallback_font
var fontSize: int = 0

func _process(_delta) -> void:
	if Input.is_action_just_released("num0"):
		visible = !visible
		
	if size.x != sim.width || size.y != sim.height:
		size = Vector2(sim.width, sim.height)
	if fontSize == 0:
		fontSize = get_viewport_rect().size.y / sim.cellSize - 5
	
	queue_redraw()

func _draw() -> void:
	drawQuadTree(sim.matrix.quadTree)

func drawQuadTree(quad: QuadTree) -> void:
	draw_rect(resizeRect(quad.boundary), Color.RED, false, 2.)
	
	for p in quad.points:
		var pressure := sim.matrix.pressureArray[p.y * sim.width + p.x]
		draw_string(font, resizeVec2(p + Vector2i(0, 1)), str(pressure), 0, -1., fontSize / str(pressure).length(), getPressureColor(pressure))
	
	if quad.northWest == null:
		return
	
	drawQuadTree(quad.northWest)
	drawQuadTree(quad.northEast)
	drawQuadTree(quad.southWest)
	drawQuadTree(quad.southEast)

func getPressureColor(pressure: int) -> Color:
	var pf: float = float(pressure) / float(sim.height)#(float(sim.height) * 100.)
	return Color.from_hsv(0., 0., max(.05, pf))
	#return Color.YELLOW.lerp(Color.RED, pf) # col1 * val + col2 * (1. - val)

func resizeVec2(pos: Vector2) -> Vector2:
	return pos / size * get_viewport_rect().size

func resizeRect(rect: Rect2) -> Rect2:
	return Rect2(resizeVec2(rect.position), resizeVec2(rect.size))
