class_name CellularMatrix
extends Resource

var width: int = 1
var height: int = 1

var idleRowSums: Array[int] = [] # Keeps track of how many tiles are in each row

var cells: Array[Cell] = []
var cellsOld: Array[Cell] = []
var colorArray: PackedColorArray = PackedColorArray()

var quadTree: QuadTree

func _init(width: int, height: int):
	self.width = width
	self.height = height
	
	quadTree = QuadTree.new(Rect2i(0, 0, width, height), 32)
	
	initializeArrays()

func initializeArrays() -> void:
	cells.resize(width * height)
	cellsOld.resize(width * height)
	colorArray.resize(width * height)
	for x in width:
		for y in height:
			var i := y * width + x
			var cell := Cell.new(Cell.Elements.EMPTY)
			cells[i] = cell
			cellsOld[i] = cell
			colorArray[i] = cell.getColor()
	
	idleRowSums.resize(height)
	idleRowSums.fill(0)

func postSimulate() -> void:
	# Re-populate quad tree
	quadTree.clear()
	for y in height:
		if idleRowSums[y] == 0: # Skip empty rows (x axis)
			continue
		for x in width:
			var cell := getOldCell(x, y)
			if cell.isMovible():
				quadTree.insert(Vector2i(x, y))
	
	#var points := quadTree.queryRange(Rect2i(0, 0, width, height))
	#quadTree.clear()
	#for p in points:
		#if getOldCellv(p).isMovible():
			#quadTree.insert(p)

func copyOldStates(quad: QuadTree) -> void:
	for p in quad.points:
		markCellVisitedv(p, false)
		var i := p.y * width + p.x
		cellsOld[i].element = cells[i].element
		cellsOld[i].visited = cells[i].visited
	
	if !quad.northWest:
		return
	
	copyOldStates(quad.northWest)
	copyOldStates(quad.northEast)
	copyOldStates(quad.southWest)
	copyOldStates(quad.southEast)

func updateCells(quad: QuadTree) -> bool:
	var updated := false
	if quad.points.size() != 0:# && quad.points.size() != quad.capacity:
		for p in quad.points:
			var cell := getOldCellv(p)
			match cell.element:
				Cell.Elements.SAND when !cell.visited:
					if Cell.updateSand(p.x, p.y, Cell.Elements.SAND, self):
						updated = true # I wish we had |=
				Cell.Elements.STEAM when !cell.visited:
					if Cell.updateSteam(p.x, p.y, Cell.Elements.STEAM, self):
						updated = true
				Cell.Elements.WATER when !cell.visited:
					if Cell.updateLiquid(p.x, p.y, Cell.Elements.WATER, self):
						updated = true
				Cell.Elements.RAINBOW_DUST when !cell.visited:
					if Cell.updateSand(p.x, p.y, Cell.Elements.RAINBOW_DUST, self):
						updated = true
				Cell.Elements.LAVA when !cell.visited:
					if Cell.updateLava(p.x, p.y, Cell.Elements.LAVA, self):
						updated = true
				_:
					continue
	
	if !quad.northWest:
		return updated
	
	if updateCells(quad.northWest): updated = true
	if updateCells(quad.northEast): updated = true
	if updateCells(quad.southWest): updated = true
	if updateCells(quad.southEast): updated = true
	
	return updated

func simulate() -> bool:
	copyOldStates(quadTree)
	return updateCells(quadTree)

func post() -> void:
	postSimulate()
	#print("Y (%s) idle row sum: %s" % [(height - 1), dec2bin(idleRowSums[height-1], width - 1)])

## https://godotforums.org/d/18970-how-can-i-work-with-binary-numbers
func dec2bin(dec, len: int = 31) -> String: # Checking up to 32 bits by default
	var bin = ""
	while(len >= 0):
		if(dec >> len & 1):
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
	if !checkBounds(x, y - 1):
		return 0
	var cellUp := getCell(x, y - 1)
	var cell := getCell(x, y)
	var cellTypeUp := cellUp.element
	var cellType := cell.element
	if cellUp.isMovible() && cell.getDensity() < cellUp.getDensity():
		if !_simulate:
			setCell(x, y - 1, cellType)
			setCell(x, y, cellTypeUp)
			markOldCellVisited(x, y - 1)
			return 2
		return 1
	return 0

func getOldCellv(pos: Vector2i) -> Cell:
	return getOldCell(pos.x, pos.y)

func getOldCell(x: int, y: int) -> Cell:
	if checkBounds(x, y):
		return cellsOld[y * width + x]
	return null

func markOldCellVisitedv(pos: Vector2i, visited: bool = true):
	return markOldCellVisited(pos.x, pos.y, visited)

func markOldCellVisited(x: int, y: int, visited: bool = true):
	if checkBounds(x, y):
		cellsOld[y * width + x].visited = visited

func getCellv(pos: Vector2i) -> Cell:
	return getCell(pos.x, pos.y)

func getCell(x: int, y: int) -> Cell:
	if checkBounds(x, y):
		return cells[y * width + x]
	return null

func markCellVisitedv(pos: Vector2i, visited: bool = true):
	return markCellVisited(pos.x, pos.y, visited)

func markCellVisited(x: int, y: int, visited: bool = true):
	if checkBounds(x, y):
		cells[y * width + x].visited = visited

func setCellv(pos: Vector2i, element: Cell.Elements) -> void:
	setCell(pos.x, pos.y, element)

func setCell(x: int, y: int, element: Cell.Elements) -> void:
	if checkBounds(x, y):
		cells[y * width + x].element = element
		colorArray[y * width + x] = cells[y * width + x].getColor()
		
		if cells[y * width + x].isMovible():
			#quadTree.insert(pos)
			if element == Cell.Elements.EMPTY:
				idleRowSums[y] = disableBit(idleRowSums[y], x)
			else:
				idleRowSums[y] = enableBit(idleRowSums[y], x)

# Returns true if inside simulation bounds
func checkBounds(x: int, y: int) -> bool:
	return x >= 0 && x < width && y >= 0 && y < height
