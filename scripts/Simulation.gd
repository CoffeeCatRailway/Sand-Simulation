class_name Simulation
extends Node2D

@onready var colorRect: ColorRect = $CanvasLayer/Control/ColorRect
@export var cellSize: int = 10

@export var brushRadius: int = 3
@export var squareBrush: bool = false
var selectedElement := Cell.Elements.SAND

var width: int = 1
var height: int = 1

var cells: Array[Array] = []
var cellsOld: Array[Array] = []
var xIndicies: Array[int] = []
var colorArray: PackedColorArray = PackedColorArray()

var markPassShader := false

func _ready() -> void:
	# Calculate width/height
	var control := Vector2i($CanvasLayer/Control.size)
	width = control.x / cellSize
	height = control.y / cellSize
	print("Sim Resolution: %s/%s" % [width, height])
	# Pass width/height to sahder
	colorRect.material.set_shader_parameter("size", Vector2(width, height))
	
	# Fill array(s)
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
		if event.is_action_released("brush_shape"):
			squareBrush = !squareBrush
		
		if event.is_action_pressed("num1"):
			selectedElement = Cell.Elements.SAND
		if event.is_action_pressed("num2"):
			selectedElement = Cell.Elements.GAS
		if event.is_action_pressed("num3"):
			selectedElement = Cell.Elements.WATER
		if event.is_action_pressed("num4"):
			selectedElement = Cell.Elements.STONE
		if event.is_action_pressed("num5"):
			selectedElement = Cell.Elements.RAINBOW_DUST
	
	if event is InputEventMouseMotion:
		if event.velocity != Vector2.ZERO:
			#mousePos = Vector2i(event.position / Vector2(get_viewport().size) * Vector2(width, height))
			mousePos = Vector2i(event.position) / cellSize # Works when Project/Settings/Display/Window/Stretch/Mode is 'viewport'
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP && event.pressed:
			brushRadius = min(99, brushRadius + 1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN && event.pressed:
			brushRadius = max(0, brushRadius - 1)
		
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
						setCellv(pos, Cell.Elements.EMPTY)
						markCellVisitedv(pos)
					if isAdding:
						if getCellv(pos).element == Cell.Elements.EMPTY:
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
			cellsOld[x][y].element = cells[x][y].element
			cellsOld[x][y].visited = cells[x][y].visited
	
	for y in height:
		y = height - 1 - y # Need for gravity to not be instant
		for x in xIndicies:
			var cell: Cell = getOldCell(x, y)
			match cell.element:
				Cell.Elements.SAND when !cell.visited:
					updateSand(x, y, Cell.Elements.SAND)
				Cell.Elements.GAS when !cell.visited:
					updateGas(x, y, Cell.Elements.GAS)
				Cell.Elements.WATER when !cell.visited:
					updateLiquid(x, y, Cell.Elements.WATER)
				Cell.Elements.RAINBOW_DUST when !cell.visited:
					updateSand(x, y, Cell.Elements.RAINBOW_DUST)
				_:
					continue
	
	#for x in width:
		#for y in height:
			#markCellVisited(x, y, false)

func updateSand(x: int, y: int, element: Cell.Elements) -> void:
	var dx: int = x + (1 if randf() > .5 else -1)
	var down: bool = (getOldCell(x, y + 1).element == Cell.Elements.EMPTY) && checkBounds(x, y + 1) && !getOldCell(x, y + 1).visited
	var side: bool = (getOldCell(dx, y).element == Cell.Elements.EMPTY) && checkBounds(dx, y) && !getOldCell(dx, y).visited
	var sided: bool = side && (getOldCell(dx, y + 1).element == Cell.Elements.EMPTY) && checkBounds(dx, y + 1) && !getOldCell(dx, y + 1).visited
	
	if down:
		setCell(x, y + 1, element)
		markOldCellVisited(x, y + 1)
	elif sided:
		setCell(dx, y + 1, element)
		markOldCellVisited(dx, y + 1)
	
	if down || sided:
		setCell(x, y, Cell.Elements.EMPTY)
		markPassShader = true

func updateGas(x: int, y: int, element: Cell.Elements) -> void:
	if !compareDensity(x, y, false):
		var dx: int = x + (1 if randf() > .5 else -1)
		var dy: int = y + (1 if randf() > .5 else -1)
		var vert: bool = (getOldCell(x, dy).element == Cell.Elements.EMPTY) && checkBounds(x, dy) && !getOldCell(x, dy).visited
		var side: bool = (getOldCell(dx, y).element == Cell.Elements.EMPTY) && checkBounds(dx, y) && !getOldCell(dx, y).visited
		var diag: bool = side && (getOldCell(dx, dy).element == Cell.Elements.EMPTY) && checkBounds(dx, dy) && !getOldCell(dx, dy).visited
		
		if diag:
			setCell(dx, dy, element)
			markOldCellVisited(dx, dy)
		elif vert:
			setCell(x, dy, element)
			markOldCellVisited(x, dy)
		elif side:
			setCell(dx, y, element)
			markOldCellVisited(dx, y)
		
		if vert || side || diag:
			setCell(x, y, Cell.Elements.EMPTY)
			markPassShader = true

# https://stackoverflow.com/questions/66522958/water-in-a-falling-sand-simulation
func updateLiquid(x: int, y: int, element: Cell.Elements) -> void:
	if !compareDensity(x, y, false):
		var dx: int = x + (1 if randf() > .5 else -1)
		var down: bool = (getOldCell(x, y + 1).element == Cell.Elements.EMPTY) && checkBounds(x, y + 1) && !getOldCell(x, y + 1).visited
		var side: bool = (getOldCell(dx, y).element == Cell.Elements.EMPTY) && checkBounds(dx, y) && !getOldCell(dx, y).visited
		var sided: bool = side && (getOldCell(dx, y + 1).element == Cell.Elements.EMPTY) && checkBounds(dx, y + 1) && !getOldCell(dx, y + 1).visited
		
		if down:
			setCell(x, y + 1, element)
			markOldCellVisited(x, y + 1)
		elif sided:
			setCell(dx, y + 1, element)
			markOldCellVisited(dx, y + 1)
		elif side:
			setCell(dx, y, element)
			markOldCellVisited(dx, y)
		
		if down || sided || side:
			setCell(x, y, Cell.Elements.EMPTY)
			markPassShader = true

# if simulate is true cells won't be swapped
func compareDensity(x: int, y: int, _simulate: bool) -> bool:
	var cellTypeUp := getCell(x, y - 1).element
	var cellType := getCell(x, y).element
	if getCell(x, y - 1).isMovible() && getCell(x, y).getDensity() < getCell(x, y - 1).getDensity():
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
			if cell.element != Cell.Elements.EMPTY:
				image.set_pixel(x, y, colorArray[y * width + x])
				#image.set_pixel(x, y, cell.getColor())
	
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

func setCell(x: int, y: int, element: Cell.Elements) -> void:
	setCellv(Vector2i(x, y), element)

func setCellv(pos: Vector2i, element: Cell.Elements) -> void:
	var x := clampi(pos.x, 0, width - 1)
	var y := clampi(pos.y, 0, height - 1)
	cells[x][y].element = element
	colorArray[y * width + x] = cells[x][y].getColor()

func vec2iDist(a: Vector2i, b: Vector2i) -> float:
	return sqrt(pow(a.x - b.x, 2.) + pow(a.y - b.y, 2.))

# Returns true if inside simulation bounds
func checkBounds(x: int, y: int) -> bool:
	return x >= 0 && x < width && y >= 0 && y < height
