extends Node2D

@onready var colorRect: ColorRect = $CanvasLayer/Control/ColorRect
@export var cellSize: int = 10
@export var brushRadius: int = 3
@export var squareBrush: bool = true

var width: int
var height: int

var data: Array[int] = []
var markUpdate := false

func _ready() -> void:
	var control := Vector2i($CanvasLayer/Control.size)
	width = control.x / cellSize
	height = control.y / cellSize
	print("Sim Resolution: %s/%s" % [width, height])
	colorRect.material.set_shader_parameter("size", Vector2(width, height))
	
	data.resize(width * height)
	data.fill(0)
	#data[(height / 2) * height + (width / 2)] = 1 	# sand
	#data[0 * height + 0] = 2						# gas
	#data[0 * height + (width - 1)] = 3				# green
	#data[(height - 2) * height + 0] = 4				# blue
	
	for x in range(0, width):
		for y in range(0, height):
			var i = y * height + x
			if x == 0 || y == 0 || x == width - 1 || y == height - 1:
				data[i] = 4
			#elif x % 2 == 0 && y % 2 == 0:
				#data[i] = 2
			#else:
				#data[i] = 3
	
	passToShader()

func _process(delta) -> void:
	var tempPos := Vector2i.ZERO
	if Input.is_action_pressed("mouse_left"):
		var element := 1
		if Input.is_action_pressed("ui_home"):
			element = 2
		
		var mPos := Vector2i(get_local_mouse_position()) / cellSize
		for x in range(-brushRadius, brushRadius + 1):
			for y in range(-brushRadius, brushRadius + 1):
				tempPos.x = mPos.x + x
				tempPos.y = mPos.y + y
				if vec2iDist(mPos, tempPos) <= brushRadius || squareBrush:
					var i = tempPos.y * height + tempPos.x
					if data[i] == 0:
						data[i] = element
						markUpdate = true
	if Input.is_action_pressed("mouse_right"):
		var mPos := Vector2i(get_local_mouse_position()) / cellSize
		for x in range(-brushRadius, brushRadius + 1):
			for y in range(-brushRadius, brushRadius + 1):
				tempPos.x = mPos.x + x
				tempPos.y = mPos.y + y
				if vec2iDist(mPos, tempPos) <= brushRadius || squareBrush:
					var i = tempPos.y * height + tempPos.x
					if data[i] != 0:
						data[i] = 0
						markUpdate = true

func vec2iDist(a: Vector2i, b: Vector2i) -> float:
	return sqrt(pow(a.x - b.x, 2.) + pow(a.y - b.y, 2.))

func _physics_process(delta) -> void:
	simulate()
	if markUpdate:
		passToShader()

func simulate() -> void:
	for x in range(0, width):
		for y in range(0, height):
			var i = y * height + x
			
			if data[i] == 1: # Sand
				if y != 0:
					var dx: int = clamp(x + (1 if randf() > .5 else -1), 0, width - 1)
					var dy: int = clamp(y - 1, 0, height - 1)
					
					if data[dy * height + x] == 0:
						data[i] = 0
						data[dy * height + x] = 1
						markUpdate = true
					elif data[dy * height + dx] == 0:
						data[i] = 0
						data[dy * height + dx] = 1
						markUpdate = true
			elif data[i] == 2:
				var dx: int = clamp(x + (1 if randf() > .5 else -1), 0, width - 1)
				var dy: int = clamp(y + (1 if randf() > .5 else -1), 0, height - 1)
				if data[dy * height + dx] == 0:
					data[i] = 0
					data[dy * height + dx] = 2
					markUpdate = true

func passToShader() -> void:
	var image := Image.create(width, height, false, Image.FORMAT_RGB8)
	for x in range(0, width):
		for y in range(0, height):
			var i = y * height + x
			if data[i] == 1:
				image.set_pixel(x, y, Color.SANDY_BROWN)
			elif data[i] == 2:
				image.set_pixel(x, y, Color.LIGHT_GRAY)
			elif data[i] == 3:
				image.set_pixel(x, y, Color.GREEN)
			elif data[i] == 4:
				image.set_pixel(x, y, Color.BLUE)
			else:
				image.set_pixel(x, y, Color.BLACK)
	
	var texture = ImageTexture.create_from_image(image)
	colorRect.material.set_shader_parameter("tex", texture)
