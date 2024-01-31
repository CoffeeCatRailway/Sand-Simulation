class_name Cell
extends Resource

var element: Elements = Elements.EMPTY
var visited: bool = false

enum Elements
{
	EMPTY,
	SAND,
	GAS,
	WATER,
	STONE,
	RAINBOW_DUST
}

func getColor() -> Color:
	var res: Color
	match element:
		Elements.SAND:
			res = Color.SANDY_BROWN
		Elements.GAS:
			res = Color.LIGHT_GRAY
		Elements.WATER:
			res = Color.CORNFLOWER_BLUE
		Elements.STONE:
			res = Color.DIM_GRAY
		Elements.RAINBOW_DUST:
			var hue = fmod(Time.get_unix_time_from_system(), 10.)
			return Color.from_hsv(hue / 10., 1., .8)
		_:
			return Color.BLACK
	res.v -= randf_range(0., .1)
	return res

func getDensity() -> int: #0-100  0 being nothing
	match element:
		Elements.SAND:
			return 20
		Elements.GAS:
			return 5
		Elements.WATER:
			return 10
		Elements.STONE:
			return 50
		Elements.RAINBOW_DUST:
			return 20
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

static func updateSand(x: int, y: int, element: Cell.Elements, matrix: CellularMatrix) -> bool:
	var dx: int = x + (1 if randf() > .5 else -1)
	var down: bool = (matrix.getOldCell(x, y + 1).element == Cell.Elements.EMPTY) && matrix.checkBounds(x, y + 1) && !matrix.getOldCell(x, y + 1).visited
	var side: bool = (matrix.getOldCell(dx, y).element == Cell.Elements.EMPTY) && matrix.checkBounds(dx, y) && !matrix.getOldCell(dx, y).visited
	var sided: bool = side && (matrix.getOldCell(dx, y + 1).element == Cell.Elements.EMPTY) && matrix.checkBounds(dx, y + 1) && !matrix.getOldCell(dx, y + 1).visited
	
	if down:
		matrix.setCell(x, y + 1, element)
		matrix.markOldCellVisited(x, y + 1)
	elif sided:
		matrix.setCell(dx, y + 1, element)
		matrix.markOldCellVisited(dx, y + 1)
	
	if down || sided:
		matrix.setCell(x, y, Cell.Elements.EMPTY)
		#markPassShader = true
		return true
	return false

static func updateGas(x: int, y: int, element: Cell.Elements, matrix: CellularMatrix) -> bool:
	if !matrix.compareDensityAbove(x, y):
		var dx: int = x + (1 if randf() > .5 else -1)
		var dy: int = y + (1 if randf() > .5 else -1)
		var vert: bool = (matrix.getOldCell(x, dy).element == Cell.Elements.EMPTY) && matrix.checkBounds(x, dy) && !matrix.getOldCell(x, dy).visited
		var side: bool = (matrix.getOldCell(dx, y).element == Cell.Elements.EMPTY) && matrix.checkBounds(dx, y) && !matrix.getOldCell(dx, y).visited
		var diag: bool = side && (matrix.getOldCell(dx, dy).element == Cell.Elements.EMPTY) && matrix.checkBounds(dx, dy) && !matrix.getOldCell(dx, dy).visited
		
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
			matrix.setCell(x, y, Cell.Elements.EMPTY)
			#markPassShader = true
			return true
	return false

# https://stackoverflow.com/questions/66522958/water-in-a-falling-sand-simulation
static func updateLiquid(x: int, y: int, element: Cell.Elements, matrix: CellularMatrix) -> bool:
	if !matrix.compareDensityAbove(x, y):
		var dx: int = x + (1 if randf() > .5 else -1)
		var down: bool = (matrix.getOldCell(x, y + 1).element == Cell.Elements.EMPTY) && matrix.checkBounds(x, y + 1) && !matrix.getOldCell(x, y + 1).visited
		var side: bool = (matrix.getOldCell(dx, y).element == Cell.Elements.EMPTY) && matrix.checkBounds(dx, y) && !matrix.getOldCell(dx, y).visited
		var sided: bool = side && (matrix.getOldCell(dx, y + 1).element == Cell.Elements.EMPTY) && matrix.checkBounds(dx, y + 1) && !matrix.getOldCell(dx, y + 1).visited
		
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
			matrix.setCell(x, y, Cell.Elements.EMPTY)
			#markPassShader = true
			return true
	return false
