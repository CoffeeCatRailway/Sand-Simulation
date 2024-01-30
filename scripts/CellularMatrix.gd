class_name CellularMatrix
extends Resource

var width: int = 1
var height: int = 1

var xIndicies: Array[int] = []
var idleRowSums: Array[int] = [] # Keeps track of how many tiles are in each row

var cells: Array[Cell] = []
var cellsOld: Array[Cell] = []
var colorArray: PackedColorArray = PackedColorArray()

func _init(width: int, height: int):
	self.width = width
	self.height = height
	
	initializeArrays()

func initializeArrays() -> void:
	cells.resize(width * height)
	cellsOld.resize(width * height)
	colorArray.resize(width * height)
	for x in width:
		xIndicies.append(x)
		for y in height:
			var i := y * width + x
			var cell := Cell.new()
			cells[i] = cell
			cellsOld[i] = cell
			colorArray[i] = cell.getColor()
	
	xIndicies.shuffle()
	idleRowSums.resize(height)
	idleRowSums.fill(0)

func simulate() -> bool:
	var updated := false
	# Copy old cell states
	for x in width:
		for y in height:
			markCellVisited(x, y, false)
			var i := y * width + x
			cellsOld[i].element = cells[i].element
			cellsOld[i].visited = cells[i].visited
	
	for y in height:
		y = height - 1 - y # Need for gravity to not be instant
		if idleRowSums[y] == 0: # Skip empty rows (x axis)
			continue
		for x in xIndicies:
			var cell: Cell = getOldCell(x, y)
			match cell.element: # have update methods in Cell?
				Cell.Elements.SAND when !cell.visited:
					if Cell.updateSand(x, y, Cell.Elements.SAND, self):
						updated = true # I wish we had |=
				Cell.Elements.GAS when !cell.visited:
					if Cell.updateGas(x, y, Cell.Elements.GAS, self):
						updated = true
				Cell.Elements.WATER when !cell.visited:
					if Cell.updateLiquid(x, y, Cell.Elements.WATER, self):
						updated = true
				Cell.Elements.RAINBOW_DUST when !cell.visited:
					if Cell.updateSand(x, y, Cell.Elements.RAINBOW_DUST, self):
						updated = true
				_:
					continue
	return updated

func post() -> void:
	xIndicies.shuffle()
	#print(dec2bin(idleRowSums[height-1], width - 1))

## https://godotforums.org/d/18970-how-can-i-work-with-binary-numbers
func dec2bin(dec, len: int = 31) -> String: # Checking up to 32 bits 
	var bin = "" 
	var temp
	
	while(len >= 0):
		temp = dec >> len 
		if(temp & 1):
			bin += "1"
		else:
			bin += "0"
		len -= 1
	
	return bin

## https://www.reddit.com/r/godot/comments/10lvy18/comment/j5zdo60/?utm_source=share&utm_medium=web2x&context=3
func enableBit(mask: int, i: int) -> int:
	return mask | (1 << i)

func disableBit(mask: int, i: int) -> int:
	return mask & ~(1 << i)

# if simulate is true cells won't be swapped
func compareDensityAbove(x: int, y: int, _simulate: bool = false) -> int:
	var cellTypeUp := getCell(x, y - 1).element
	var cellType := getCell(x, y).element
	if getCell(x, y - 1).isMovible() && getCell(x, y).getDensity() < getCell(x, y - 1).getDensity():
		if !_simulate:
			setCell(x, y - 1, cellType)
			setCell(x, y, cellTypeUp)
			markOldCellVisited(x, y - 1)
			return 2
		return 1
	return 0

func getOldCell(x: int, y: int) -> Cell:
	return getOldCellv(Vector2i(x, y))

func getOldCellv(pos: Vector2i) -> Cell:
	var x := clampi(pos.x, 0, width - 1)
	var y := clampi(pos.y, 0, height - 1)
	return cellsOld[y * width + x]

func markOldCellVisited(x: int, y: int, visited: bool = true):
	return markOldCellVisitedv(Vector2i(x, y), visited)

func markOldCellVisitedv(pos: Vector2i, visited: bool = true):
	var x := clampi(pos.x, 0, width - 1)
	var y := clampi(pos.y, 0, height - 1)
	cellsOld[y * width + x].visited = visited

func getCell(x: int, y: int) -> Cell:
	return getCellv(Vector2i(x, y))

func getCellv(pos: Vector2i) -> Cell:
	var x := clampi(pos.x, 0, width - 1)
	var y := clampi(pos.y, 0, height - 1)
	return cells[y * width + x]

func markCellVisited(x: int, y: int, visited: bool = true):
	return markCellVisitedv(Vector2i(x, y), visited)

func markCellVisitedv(pos: Vector2i, visited: bool = true):
	var x := clampi(pos.x, 0, width - 1)
	var y := clampi(pos.y, 0, height - 1)
	cells[y * width + x].visited = visited

func setCell(x: int, y: int, element: Cell.Elements) -> void:
	setCellv(Vector2i(x, y), element)

func setCellv(pos: Vector2i, element: Cell.Elements) -> void:
	var x := clampi(pos.x, 0, width - 1)
	var y := clampi(pos.y, 0, height - 1)
	cells[y * width + x].element = element
	colorArray[y * width + x] = cells[y * width + x].getColor()
	
	if cells[y * width + x].isMovible():
		if element == Cell.Elements.EMPTY:
			idleRowSums[y] = disableBit(idleRowSums[y], x)
		else:
			idleRowSums[y] = enableBit(idleRowSums[y], x)

# Returns true if inside simulation bounds
func checkBounds(x: int, y: int) -> bool:
	return x >= 0 && x < width && y >= 0 && y < height
