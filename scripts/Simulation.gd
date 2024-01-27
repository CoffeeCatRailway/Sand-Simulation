extends Node2D

@onready var colorRect: ColorRect = $CanvasLayer/Control/ColorRect
@export var cellSize: int = 10
@export var brushRadius: int = 3
@export var squareBrush: bool = true

var width: int
var height: int

var data: Array[Array] = []
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
	var yarr: Array[int] = []
	#yarr.resize(height)
	#yarr.fill(0)
	#data.resize(width)
	#data.fill(yarr)
	for x in width:
		data.append([])
		for y in height:
			data[x].append(0)
			if x == 0 || y == 0 || x == width - 1 || y == height - 1:
				setCell(x, y, 4)
	#print(data.size(), "/", yarr.size())
	
	#data[width / 2][height / 2] = 1 	# sand
	#data[0][0] = 2						# gas
	#data[width - 1][0] = 3				# green
	#data[0][height - 2] = 4				# blue
	
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
						var element := 1
						if Input.is_action_pressed("ui_home"):
							element = 2
						if getCellv(tempPos) == 0:
							setCell(tempPos.x, tempPos.y, element)
							markUpdate = true
					if mouseRight:
						setCell(tempPos.x, tempPos.y, 0)
						markUpdate = true

func getCell(x: int, y: int) -> int:
	return getCellv(Vector2i(x, y))

func getCellv(pos: Vector2i) -> int:
	var x := clampi(pos.x, 0, width - 1)
	var y := clampi(pos.y, 0, height - 1)
	return data[x][y]

func setCell(x: int, y: int, cell: int) -> int:
	return setCellv(Vector2i(x, y), cell)

func setCellv(pos: Vector2i, cell: int) -> int:
	var x := clampi(pos.x, 0, width - 1)
	var y := clampi(pos.y, 0, height - 1)
	
	var old := getCell(x, y)
	data[x][y] = cell
	return old

func vec2iDist(a: Vector2i, b: Vector2i) -> float:
	return sqrt(pow(a.x - b.x, 2.) + pow(a.y - b.y, 2.))

func _physics_process(delta) -> void:
	simulate()
	
	if markUpdate:
		passToShader()
		markUpdate = false

func simulate() -> void:
	for y in height:
		for x in width: # TODO: Shuffle x indecies & loop y,x
			var cell := getCell(x, y)
			if cell == 0 && cell == 4:
				continue
			
			if cell == 1: # sand
				if y != 0:
					var dx: int = clamp(x + (1 if randf() > .5 else -1), 0, width - 1)
					var dy: int = clamp(y - 1, 0, height - 1)
					
					if getCell(x, dy) == 0:
						setCell(x, y, 0)
						setCell(x, dy, 1)
						markUpdate = true
					elif getCell(dx, dy) == 0:
						setCell(x, y, 0)
						setCell(dx, dy, 1)
						markUpdate = true
			elif cell == 2: # gas
				var dx: int = clamp(x + (1 if randf() > .5 else -1), 0, width - 1)
				var dy: int = clamp(y + (1 if randf() > .5 else -1), 0, height - 1)
				
				if getCell(dx, dy) == 0:
					setCell(x, y, 0)
					setCell(dx, dy, 2)
					markUpdate = true

func passToShader() -> void:
	var image := Image.create(width, height, false, Image.FORMAT_RGB8)
	image.fill(Color.BLACK)
	for x in width:
		for y in height:
			var cell := getCell(x, y)
			if cell == 1:
				image.set_pixel(x, y, Color.SANDY_BROWN)
			elif cell == 2:
				image.set_pixel(x, y, Color.LIGHT_GRAY)
			elif cell == 3:
				image.set_pixel(x, y, Color.GREEN)
			elif cell == 4:
				image.set_pixel(x, y, Color.BLUE)
	
	var texture = ImageTexture.create_from_image(image)
	colorRect.material.set_shader_parameter("tex", texture)
