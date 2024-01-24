extends Node2D

@export var cellSize: int = 10

var width: int
var height: int

var data: Array[int] = []
var markUpdate := false

func _ready() -> void:
	var control := Vector2i($Control.size)
	width = control.x / cellSize
	height = control.y / cellSize
	print("Sim Resolution: %s/%s" % [width, height])
	
	data.resize(width * height)
	data.fill(0)
	data[(height / 2) * height + (width / 2)] = 1
	data[0 * height + 0] = 2
	data[0 * height + (width - 1)] = 3
	data[(height - 2) * height + 0] = 4
	
	passToShader()

func _process(delta) -> void:
	if Input.is_action_pressed("mouse_left"):
		for x in range(-1, 2):
			for y in range(-1, 2):
				var mpos := Vector2i(get_global_mouse_position())
				var i = (mpos.y / cellSize + y) * height + (mpos.x / cellSize + x)
				if data[i] == 0:
					data[i] = 1
	if Input.is_action_pressed("mouse_right"):
		for x in range(-1, 2):
			for y in range(-1, 2):
				var mpos := Vector2i(get_global_mouse_position())
				var i = (mpos.y / cellSize + y) * height + (mpos.x / cellSize + x)
				if data[i] != 0:
					data[i] = 0

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

func passToShader() -> void:
	var image := Image.create(width, height, false, Image.FORMAT_RGB8)
	for x in range(0, width):
		for y in range(0, height):
			var i = y * height + x
			if data[i] == 1:
				image.set_pixel(x, y, Color.SANDY_BROWN)
			elif data[i] == 2:
				image.set_pixel(x, y, Color.RED)
			elif data[i] == 3:
				image.set_pixel(x, y, Color.GREEN)
			elif data[i] == 4:
				image.set_pixel(x, y, Color.BLUE)
			else:
				image.set_pixel(x, y, Color.BLACK)
	
	var texture = ImageTexture.create_from_image(image)
	($Control/ColorRect.material as ShaderMaterial).set_shader_parameter("tex", texture)
