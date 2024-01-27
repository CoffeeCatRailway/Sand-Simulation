extends Node2D

@onready var colorRect: ColorRect = $CanvasLayer/Control/ColorRect
@export var cellSize: int = 10
@export var brushRadius: int = 3
@export var squareBrush: bool = true

var width: int
var height: int

var cells: Array[Array] = []
var xIndicies: Array[int] = []
var markUpdate := false

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
		xIndicies.append(x)
		for y in height:
			var emptyCell: Cell = Cell.new()
			emptyCell.type = Cell.Type.EMPTY
			cells[x].append(emptyCell)
			#if x == 0 || y == 0 || x == width - 1 || y == height - 1:
				#setCell(x, y, 4)
	xIndicies.shuffle()
	
	#data[width / 2][height / 2] = 1 	# sand
	#data[0][0] = 2						# gas
	#data[width - 1][0] = 3				# water
	#data[0][height - 1] = 4				# red
	
	#for x in width:
		#for y in height:
			#if x == 0 || y == 0 || x == width - 1 || y == height - 1:
				#setCell(x, y, 4)
	
	# Initialze screen
	passToShader()

func _process(delta) -> void:
	var mouseLeft := Input.is_action_pressed("mouse_left")
	var mouseRight := Input.is_action_pressed("mouse_right")
	
	if mouseLeft || mouseRight:
		var tempPos := Vector2i.ZERO
		var mPos := Vector2i(get_local_mouse_position()) / cellSize
		#print("Mouse pos: ", mPos)
		for x in range(-brushRadius, brushRadius + 1):
			for y in range(-brushRadius, brushRadius + 1):
				tempPos.x = mPos.x + x
				tempPos.y = mPos.y + y
				if vec2iDist(mPos, tempPos) <= brushRadius || squareBrush:
					if mouseLeft:
						var element := Cell.Type.SAND
						if Input.is_action_pressed("ui_home"):
							element = Cell.Type.GAS
						if getCellv(tempPos).type == Cell.Type.EMPTY:
							setCell(tempPos.x, tempPos.y, element)
							markUpdate = true
					if mouseRight:
						setCell(tempPos.x, tempPos.y, Cell.Type.EMPTY)
						markUpdate = true

func getCell(x: int, y: int) -> Cell:
	return getCellv(Vector2i(x, y))

func getCellv(pos: Vector2i) -> Cell:
	var x := clampi(pos.x, 0, width - 1)
	var y := clampi(pos.y, 0, height - 1)
	return cells[x][y]

func setCell(x: int, y: int, cellType: Cell.Type, visited: bool = false) -> void:
	setCellv(Vector2i(x, y), cellType)

func setCellv(pos: Vector2i, cellType: Cell.Type, visited: bool = false) -> void:
	var x := clampi(pos.x, 0, width - 1)
	var y := clampi(pos.y, 0, height - 1)
	
	cells[x][y].type = cellType
	cells[x][y].visited = visited

func vec2iDist(a: Vector2i, b: Vector2i) -> float:
	return sqrt(pow(a.x - b.x, 2.) + pow(a.y - b.y, 2.))

func _physics_process(delta) -> void:
	simulate()
	
	if markUpdate:
		passToShader()
		xIndicies.shuffle()
		markUpdate = false

func simulate() -> void:
	for y in height:
		y = height - 1 - y # Need for gravity to not be instant
		for x in xIndicies:
			var cell: Cell = getCell(x, y)
			match cell.type:
				Cell.Type.SAND:
					updateSand(x, y)
				Cell.Type.GAS:
					updateGas(x, y)
				Cell.Type.WATER:
					updateWater(x, y)
				_:
					pass

func updateSand(x: int, y: int) -> void:
	if y != height - 1:
		var dx: int = clamp(x + (1 if randf() > .5 else -1), 0, width - 1)
		var dy: int = clamp(y + 1, 0, height - 1)
		
		if getCell(x, dy).type == Cell.Type.EMPTY:
			setCell(x, y, Cell.Type.EMPTY)
			setCell(x, dy, Cell.Type.SAND)
			markUpdate = true
		elif getCell(dx, dy).type == Cell.Type.EMPTY:
			setCell(x, y, Cell.Type.EMPTY)
			setCell(dx, dy, Cell.Type.SAND)
			markUpdate = true

func updateGas(x: int, y: int) -> void:
	var dx: int = clamp(x + (1 if randf() > .5 else -1), 0, width - 1)
	var dy: int = clamp(y + (1 if randf() > .5 else -1), 0, height - 1)
	
	if getCell(dx, dy).type == Cell.Type.EMPTY:
		setCell(x, y, Cell.Type.EMPTY)
		setCell(dx, dy, Cell.Type.GAS)
		markUpdate = true

func updateWater(x: int, y: int) -> void:
	pass

func passToShader() -> void:
	var image := Image.create(width, height, false, Image.FORMAT_RGB8)
	image.fill(Color.BLACK)
	for x in width:
		for y in height:
			var cell: Cell = getCell(x, y)
			match cell.type:
				Cell.Type.SAND:
					image.set_pixel(x, y, Color.SANDY_BROWN)
				Cell.Type.GAS:
					image.set_pixel(x, y, Color.LIGHT_GRAY)
				Cell.Type.WATER:
					image.set_pixel(x, y, Color.BLUE)
				_:
					pass
	
	var texture = ImageTexture.create_from_image(image)
	colorRect.material.set_shader_parameter("tex", texture)
