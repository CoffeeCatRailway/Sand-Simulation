class_name Simulation
extends Node2D

@onready var colorRect: ColorRect = $CanvasLayer/Control/ColorRect
@export var cellSize: int = 10

@export var brushRadius: int = 3
@export var squareBrush: bool = false
var selectedElement := Cell.Elements.SAND

var width: int = 64 # (1152/10)/6 # 6 vertical threads, 19
var height: int = 36 # (648/10) # 64
var matrix: CellularMatrix

var image: Image
var markPassShader := false

var mousePos := Vector2i.ZERO
var isAdding := false
var isRemoveing := false

func _ready() -> void:
	# Calculate width/height
	var control: Vector2 = $CanvasLayer/Control.size / cellSize
	width = control.x
	height = control.y
	print("Sim Resolution: %s/%s" % [width, height])
	# Pass width/height to sahder
	colorRect.material.set_shader_parameter("size", Vector2(width, height))
	image = Image.create(width, height, false, Image.FORMAT_RGB8)
	
	matrix = CellularMatrix.new(width, height)
	
	# Initialze screen
	passToShader()

func _input(event) -> void:
	if event is InputEventKey:
		if event.is_action_released("brush_shape"):
			squareBrush = !squareBrush
		
		for i in Cell.Elements.size():
			if i == 0: # Ignore empty
				continue
			if event.is_action_pressed("num%s" % i):
				selectedElement = Cell.Elements.values()[i]
	
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

func handleMouse() -> void:
	if isAdding || isRemoveing:
		var pos := Vector2i.ZERO
		for x in range(-brushRadius, brushRadius + 1):
			for y in range(-brushRadius, brushRadius + 1):
				pos.x = mousePos.x + x
				pos.y = mousePos.y + y
				if !matrix.checkBounds(pos.x, pos.y):
					continue
				if vec2iDist(mousePos, pos) <= brushRadius || squareBrush:
					if isRemoveing:
						matrix.setCellv(pos, Cell.Elements.EMPTY)
						#matrix.markCellVisitedv(pos)
						markPassShader = true
					if isAdding:
						if matrix.getCellv(pos).element == Cell.Elements.EMPTY:
							matrix.setCellv(pos, selectedElement)
							#matrix.markCellVisitedv(pos)
							markPassShader = true

func vec2iDist(a: Vector2i, b: Vector2i) -> float:
	return sqrt(pow(a.x - b.x, 2.) + pow(a.y - b.y, 2.))

func _physics_process(delta) -> void:
	handleMouse()
	if matrix.simulate():
		markPassShader = true
	
	if markPassShader:
		passToShader()
		matrix.post()
		markPassShader = false

func passToShader() -> void:
	#var image := Image.create(width, height, false, Image.FORMAT_RGB8)
	image.fill(Color.BLACK)
	for x in width:
		for y in height:
			var cell: Cell = matrix.getCell(x, y)
			if cell.element != Cell.Elements.EMPTY:
				image.set_pixel(x, y, matrix.colorArray[y * width + x])
	
	var texture = ImageTexture.create_from_image(image)
	colorRect.material.set_shader_parameter("tex", texture)
