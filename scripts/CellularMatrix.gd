class_name CellularMatrix
extends Resource

var width: int = 1
var height: int = 1

var xIndicies: Array[int] = []
var rowSums: Array[int] = [] # Keeps track of how many tiles are in each row

var cells: Array[Array] = []
var cellsOld: Array[Array] = []
var colorArray: PackedColorArray = PackedColorArray()

func _init(width: int, height: int):
	self.width = width
	self.height = height
	
	initializeArrays()

func initializeArrays() -> void:
	colorArray.resize(width * height)
	for x in width:
		cells.append([])
		cellsOld.append([])
		xIndicies.append(x)
		for y in height:
			var emptyCell: Cell = Cell.new()
			colorArray[y * width + x] = emptyCell.getColor()
			cells[x].append(emptyCell)
			cellsOld[x].append(emptyCell)
	
	xIndicies.shuffle()
	rowSums.resize(height)
	rowSums.fill(0)

func calculateRowSum(y: int) -> void:
	var sum: int = 0
	for x in width:
		if getCell(x, y).isMovible():
			#sum += getCell(x, y).element
			sum += 1
			sum << 1
	rowSums[y] = sum

# if simulate is true cells won't be swapped
func compareDensityAbove(x: int, y: int, _simulate: bool = false) -> int:
	var cellTypeUp := getCell(x, y - 1).element
	var cellType := getCell(x, y).element
	if getCell(x, y - 1).isMovible() && getCell(x, y).getDensity() < getCell(x, y - 1).getDensity():
		if !_simulate:
			setCell(x, y - 1, cellType)
			setCell(x, y, cellTypeUp)
			markOldCellVisited(x, y - 1)
			#markPassShader = true
			return 2
		return 1
	return 0

func getOldCell(x: int, y: int) -> Cell:
	return getOldCellv(Vector2i(x, y))

func getOldCellv(pos: Vector2i) -> Cell:
	var x := clampi(pos.x, 0, width - 1)
	var y := clampi(pos.y, 0, height - 1)
	return cellsOld[x][y]

func markOldCellVisited(x: int, y: int, visited: bool = true):
	return markOldCellVisitedv(Vector2i(x, y), visited)

func markOldCellVisitedv(pos: Vector2i, visited: bool = true):
	var x := clampi(pos.x, 0, width - 1)
	var y := clampi(pos.y, 0, height - 1)
	cellsOld[x][y].visited = visited

func getCell(x: int, y: int) -> Cell:
	return getCellv(Vector2i(x, y))

func getCellv(pos: Vector2i) -> Cell:
	var x := clampi(pos.x, 0, width - 1)
	var y := clampi(pos.y, 0, height - 1)
	return cells[x][y]

func markCellVisited(x: int, y: int, visited: bool = true):
	return markCellVisitedv(Vector2i(x, y), visited)

func markCellVisitedv(pos: Vector2i, visited: bool = true):
	var x := clampi(pos.x, 0, width - 1)
	var y := clampi(pos.y, 0, height - 1)
	cells[x][y].visited = visited

func setCell(x: int, y: int, element: Cell.Elements) -> void:
	setCellv(Vector2i(x, y), element)

func setCellv(pos: Vector2i, element: Cell.Elements) -> void:
	var x := clampi(pos.x, 0, width - 1)
	var y := clampi(pos.y, 0, height - 1)
	cells[x][y].element = element
	#calculateRowSum(y)
	colorArray[y * width + x] = cells[x][y].getColor()

# Returns true if inside simulation bounds
func checkBounds(x: int, y: int) -> bool:
	return x >= 0 && x < width && y >= 0 && y < height
