class_name Cell
extends Resource

var element: Elements = Elements.EMPTY
var visited: bool = false
var color: Color

func _init(element: Elements):
	self.element = element
	color = getColor()

enum Elements
{
	EMPTY,
	SAND,
	STEAM,
	WATER,
	STONE,
	RAINBOW_DUST,
	LAVA
}

func getColor() -> Color:
	if !color:
		var vary := false
		match element:
			Elements.SAND:
				vary = true
				color = Color.SANDY_BROWN
			Elements.STEAM:
				vary = true
				color = Color.LIGHT_GRAY
			Elements.WATER:
				vary = true
				color = Color.CORNFLOWER_BLUE
			Elements.STONE:
				vary = true
				color = Color.DIM_GRAY
			Elements.RAINBOW_DUST:
				var hue := fmod(Time.get_unix_time_from_system(), 10.)
				color = Color.from_hsv(hue / 10., 1., .8)
			Elements.LAVA:
				color = Color.from_hsv(randf_range(.04, .125), 1., .8)
			_:
				color = Color.BLACK
		if vary:
			color.v -= randf_range(0., .1)
	return color

func getDensity() -> int: #0-100  0 being nothing
	match element:
		Elements.SAND:
			return 20
		Elements.STEAM:
			return 5
		Elements.WATER:
			return 10
		Elements.STONE:
			return 50
		Elements.RAINBOW_DUST:
			return 20
		Elements.LAVA:
			return 50
		_:
			return 0

func isMovible() -> bool:
	match element:
		Elements.EMPTY:
			return false
		Elements.STONE:
			return false
		_:
			return true

## Element update methods ##

static func updateSand(x: int, y: int, element: Elements, matrix: CellularMatrix) -> bool:
	var dx: int = x + (1 if randf() > .5 else -1)
	var down: bool = matrix.checkBounds(x, y + 1) && (matrix.getOldCell(x, y + 1).element == Elements.EMPTY) && !matrix.getOldCell(x, y + 1).visited
	var side: bool = matrix.checkBounds(dx, y) && (matrix.getOldCell(dx, y).element == Elements.EMPTY) && !matrix.getOldCell(dx, y).visited
	var sided: bool = side && matrix.checkBounds(dx, y + 1) && (matrix.getOldCell(dx, y + 1).element == Elements.EMPTY) && !matrix.getOldCell(dx, y + 1).visited
	
	if down:
		matrix.setCell(x, y + 1, element)
		matrix.markOldCellVisited(x, y + 1)
	elif sided:
		matrix.setCell(dx, y + 1, element)
		matrix.markOldCellVisited(dx, y + 1)
	
	if down || sided:
		matrix.setCell(x, y, Elements.EMPTY)
		#markPassShader = true
		return true
	return false

static func updateGas(x: int, y: int, element: Elements, matrix: CellularMatrix) -> bool:
	if matrix.compareDensityAbove(x, y):
		return true
	
	var dx: int = x + (1 if randf() > .5 else -1)
	var dy: int = y + (1 if randf() > .5 else -1)
	var vert: bool = matrix.checkBounds(x, dy) && (matrix.getOldCell(x, dy).element == Elements.EMPTY) && !matrix.getOldCell(x, dy).visited
	var side: bool = matrix.checkBounds(dx, y) && (matrix.getOldCell(dx, y).element == Elements.EMPTY) && !matrix.getOldCell(dx, y).visited
	var diag: bool = side && matrix.checkBounds(dx, dy) && (matrix.getOldCell(dx, dy).element == Elements.EMPTY) && !matrix.getOldCell(dx, dy).visited
	
	if diag:
		matrix.setCell(dx, dy, element)
		matrix.markOldCellVisited(dx, dy)
	elif vert:
		matrix.setCell(x, dy, element)
		matrix.markOldCellVisited(x, dy)
	elif side:
		matrix.setCell(dx, y, element)
		matrix.markOldCellVisited(dx, y)
	
	if vert || side || diag:
		matrix.setCell(x, y, Elements.EMPTY)
		#markPassShader = true
		return true
	return false

static func updateSteam(x: int, y: int, element: Elements, matrix: CellularMatrix) -> bool:
	if randf() < .01:
		matrix.setCell(x, y, Elements.WATER)
		matrix.markOldCellVisited(x, y)
		return true
	return updateGas(x, y, element, matrix)

# https://stackoverflow.com/questions/66522958/water-in-a-falling-sand-simulation
static func updateLiquid(x: int, y: int, element: Elements, matrix: CellularMatrix) -> bool:
	if matrix.compareDensityAbove(x, y):
		return true
	
	var dx: int = x + (1 if randf() > .5 else -1)
	var down: bool = matrix.checkBounds(x, y + 1) && (matrix.getOldCell(x, y + 1).element == Elements.EMPTY) && !matrix.getOldCell(x, y + 1).visited
	var side: bool = matrix.checkBounds(dx, y) && (matrix.getOldCell(dx, y).element == Elements.EMPTY) && !matrix.getOldCell(dx, y).visited
	var sided: bool = side && matrix.checkBounds(dx, y + 1) && (matrix.getOldCell(dx, y + 1).element == Elements.EMPTY) && !matrix.getOldCell(dx, y + 1).visited
	
	if down:
		matrix.setCell(x, y + 1, element)
		matrix.markOldCellVisited(x, y + 1)
	elif sided:
		matrix.setCell(dx, y + 1, element)
		matrix.markOldCellVisited(dx, y + 1)
	elif side:
		matrix.setCell(dx, y, element)
		matrix.markOldCellVisited(dx, y)
	
	if down || sided || side:
		matrix.setCell(x, y, Elements.EMPTY)
		#markPassShader = true
		return true
	return false

static func updateLava(x: int, y: int, element: Elements, matrix: CellularMatrix) -> bool:
	var up: bool = matrix.checkBounds(x, y - 1) && (matrix.getOldCell(x, y - 1).element == Elements.WATER)
	var down: bool = matrix.checkBounds(x, y + 1) && (matrix.getOldCell(x, y + 1).element == Elements.WATER)
	var left: bool = matrix.checkBounds(x - 1, y) && (matrix.getOldCell(x - 1, y).element == Elements.WATER)
	var right: bool = matrix.checkBounds(x + 1, y) && (matrix.getOldCell(x + 1, y).element == Elements.WATER)
	
	if up:
		matrix.setCell(x, y - 1, Elements.STEAM)
		matrix.markOldCellVisited(x, y - 1)
	elif down:
		matrix.setCell(x, y + 1, Elements.STEAM)
		matrix.markOldCellVisited(x, y + 1)
	elif left:
		matrix.setCell(x - 1, y, Elements.STEAM)
		matrix.markOldCellVisited(x - 1, y)
	elif right:
		matrix.setCell(x + 1, y, Elements.STEAM)
		matrix.markOldCellVisited(x + 1, y)
	
	if up || down || left || right:
		matrix.setCell(x, y, Elements.STONE)
		return true
	return randf() < .4 && updateLiquid(x, y, element, matrix)
