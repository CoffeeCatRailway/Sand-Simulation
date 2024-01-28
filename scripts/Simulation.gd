class_name Simulation
extends Node2D

@onready var colorRect: ColorRect = $CanvasLayer/Control/ColorRect
@export var cellSize: int = 10

@export var brushRadius: int = 3
@export var squareBrush: bool = true
var selectedElement := Cell.Type.SAND

var width: int = 1
var height: int = 1

var cells: Array[Array] = []
var cellsOld: Array[Array] = []
var xIndicies: Array[int] = []

var markPassShader := false

func _ready() -> void:
	print("Brush radius: ", brushRadius)
	print("Brush type: ", ("Square" if squareBrush else "Circle"))
	
	# Calculate width/height
	var control := Vector2i($CanvasLayer/Control.size)
	width = control.x / cellSize
	height = control.y / cellSize
	print("Sim Resolution: %s/%s" % [width, height])
	# Pass width/height to sahder
	colorRect.material.set_shader_parameter("size", Vector2(width, height))
	
	# Fill array(s)
	for x in width:
		cells.append([])
		cellsOld.append([])
		xIndicies.append(x)
		for y in height:
			var emptyCell: Cell = Cell.new()
			emptyCell.type = Cell.Type.EMPTY
			cells[x].append(emptyCell)
			cellsOld[x].append(emptyCell)
			#if x == 0 || y == 0 || x == width - 1 || y == height - 1:
				#setCell(x, y, 4)
	xIndicies.shuffle()
	
	# Initialze screen
	passToShader()

var mousePos := Vector2i.ZERO
var isAdding := false
var isRemoveing := false

func _input(event) -> void:
	if event is InputEventKey:
		if event.is_action_pressed("num1"):
			selectedElement = Cell.Type.SAND
		if event.is_action_pressed("num2"):
			selectedElement = Cell.Type.GAS
		if event.is_action_pressed("num3"):
			selectedElement = Cell.Type.WATER
	
	if event is InputEventMouseMotion:
		if event.velocity != Vector2.ZERO:
			mousePos = Vector2i(event.position) / cellSize
	
	if event is InputEventMouseButton:
		isAdding = event.is_action_pressed("mouse_left")
		isRemoveing = event.is_action_pressed("mouse_right")

#func _process(delta) -> void:
	#handleMouse()
	#mousePos = Vector2i(get_local_mouse_position()) / cellSize

func handleMouse() -> void:
	if isAdding || isRemoveing:
		var pos := Vector2i.ZERO
		for x in range(-brushRadius, brushRadius + 1):
			for y in range(-brushRadius, brushRadius + 1):
				pos.x = mousePos.x + x
				pos.y = mousePos.y + y
				if vec2iDist(mousePos, pos) <= brushRadius || squareBrush:
					if isRemoveing:
						setCellv(pos, Cell.Type.EMPTY)
						markCellVisitedv(pos)
					if isAdding:
						if getCellv(pos).type == Cell.Type.EMPTY:
							setCellv(pos, selectedElement)
							markCellVisitedv(pos)
		markPassShader = true

func _physics_process(delta) -> void:
	handleMouse()
	simulate()
	
	if markPassShader:
		passToShader()
		xIndicies.shuffle()
		markPassShader = false

func simulate() -> void:
	# Copy old cell states
	for x in width:
		for y in height:
			markCellVisited(x, y, false)
			cellsOld[x][y].type = cells[x][y].type
			cellsOld[x][y].visited = cells[x][y].visited
	
	for y in height:
		y = height - 1 - y # Need for gravity to not be instant
		for x in xIndicies:
			var cell: Cell = getOldCell(x, y)
			match cell.type:
				Cell.Type.SAND when !cell.visited:
					updateSand(x, y)
				Cell.Type.GAS when !cell.visited:
					updateGas(x, y)
				Cell.Type.WATER when !cell.visited:
					updateWater(x, y)
				_:
					pass
	
	#for x in width:
		#for y in height:
			#markCellVisited(x, y, false)

func updateSand(x: int, y: int) -> void:
	if y != height - 1:
		var dx: int = x + (1 if randf() > .5 else -1)
		
		if getCell(x, y + 1).type == Cell.Type.EMPTY:
			setCell(x, y, Cell.Type.EMPTY)
			markOldCellVisited(x, y)
			setCell(x, y + 1, Cell.Type.SAND)
			markPassShader = true
		elif getCell(dx, y + 1).type == Cell.Type.EMPTY:
			setCell(x, y, Cell.Type.EMPTY)
			markOldCellVisited(x, y)
			setCell(dx, y + 1, Cell.Type.SAND)
			markPassShader = true

func updateGas(x: int, y: int) -> void:
	if !compareDensity(x, y, false):
		var dx: int = x + (1 if randf() > .5 else -1)
		var dy: int = y + (1 if randf() > .5 else -1)
		
		if getCell(dx, dy).type == Cell.Type.EMPTY:
			setCell(x, y, Cell.Type.EMPTY)
			markOldCellVisited(x, y)
			setCell(dx, dy, Cell.Type.GAS)
			markPassShader = true

# https://stackoverflow.com/questions/66522958/water-in-a-falling-sand-simulation
func updateWater(x: int, y: int) -> void:
	if !compareDensity(x, y, false):
		var down: bool = (getOldCell(x, y + 1).type == Cell.Type.EMPTY) && checkBounds(x, y + 1) && !getOldCell(x, y + 1).visited
		var dLeft: bool = (getOldCell(x - 1, y + 1).type == Cell.Type.EMPTY) && checkBounds(x - 1, y + 1) && !getOldCell(x - 1, y + 1).visited
		var dRight: bool = (getOldCell(x + 1, y + 1).type == Cell.Type.EMPTY) && checkBounds(x + 1, y + 1) && !getOldCell(x + 1, y + 1).visited
		var left: bool = (getOldCell(x - 1, y).type == Cell.Type.EMPTY) && checkBounds(x - 1, y) && !getOldCell(x - 1, y).visited
		var right: bool = (getOldCell(x + 1, y).type == Cell.Type.EMPTY) && checkBounds(x + 1, y) && !getOldCell(x + 1, y).visited
		
		# Choose random direction if both left & right
		if dLeft && dRight:
			if randf() > .5:
				dLeft = false
			else:
				dRight = false
		if left && right:
			if randf() > .5:
				left = false
			else:
				right = false
		
		if down:
			setCell(x, y + 1, Cell.Type.WATER)
			markOldCellVisited(x, y + 1)
		elif dLeft:
			setCell(x - 1, y + 1, Cell.Type.WATER)
			markOldCellVisited(x - 1, y + 1)
		elif dRight:
			setCell(x + 1, y + 1, Cell.Type.WATER)
			markOldCellVisited(x + 1, y + 1)
		elif left:
			setCell(x - 1, y, Cell.Type.WATER)
			markOldCellVisited(x - 1, y)
		elif right:
			setCell(x + 1, y, Cell.Type.WATER)
			markOldCellVisited(x + 1, y)
		
		if down || dLeft || dRight || left || right:
			setCell(x, y, Cell.Type.EMPTY)
			markPassShader = true

# if simulate is true cells won't be swapped
func compareDensity(x: int, y: int, _simulate: bool) -> bool:
	var cellTypeUp := getCell(x, y - 1).type
	var cellType := getCell(x, y).type
	if getCell(x, y).getDensity() < getCell(x, y - 1).getDensity():
		if !_simulate:
			setCell(x, y - 1, cellType)
			setCell(x, y, cellTypeUp)
			markOldCellVisited(x, y - 1)
			markPassShader = true
		return true
	return false

func passToShader() -> void:
	var image := Image.create(width, height, false, Image.FORMAT_RGB8)
	image.fill(Color.BLACK)
	for x in width:
		for y in height:
			var cell: Cell = getCell(x, y)
			if cell.type != Cell.Type.EMPTY:
				image.set_pixel(x, y, cell.getColor())
	
	var texture = ImageTexture.create_from_image(image)
	colorRect.material.set_shader_parameter("tex", texture)

## Util methods ##

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

func setCell(x: int, y: int, cellType: Cell.Type) -> void:
	setCellv(Vector2i(x, y), cellType)

func setCellv(pos: Vector2i, cellType: Cell.Type) -> void:
	var x := clampi(pos.x, 0, width - 1)
	var y := clampi(pos.y, 0, height - 1)
	cells[x][y].type = cellType

func vec2iDist(a: Vector2i, b: Vector2i) -> float:
	return sqrt(pow(a.x - b.x, 2.) + pow(a.y - b.y, 2.))

# Returns true if inside simulation bounds
func checkBounds(x: int, y: int) -> bool:
	return x >= 0 && x < width && y >= 0 && y < height
