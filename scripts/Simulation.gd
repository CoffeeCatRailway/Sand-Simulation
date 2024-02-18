class_name Simulation
extends Node2D

@onready var colorRect: ColorRect = $CanvasLayer/Control/ColorRect
@export_range(16, 160, 1, "or_greater") var width: int = 160
@export_range(9, 90, 1, "or_greater") var height: int = 90

@export var brushRadius: int = 3
@export var squareBrush: bool = false
var selectedElement := Cell.Elements.SAND

#var matrix: CellularMatrix
var cells: Dictionary = {}
var quadTree: QuadTree

var image: Image
var markPassShader := false

var mousePos := Vector2i.ZERO
var isAdding := false
var isRemoveing := false

@export_range(1, 64) var threadCount: int = 2
var threads: Array[Thread] = []
var threadIndicies: Array[int] = []

## Emitted on thread(s) once cells are processed
signal threadProcessed(processedCells: Dictionary, index: int)

func _ready() -> void:
	# Calculate width/height
	print("Sim Resolution: %s/%s" % [width, height])
	
	# Pass width/height to sahder
	colorRect.material.set_shader_parameter("size", Vector2(width, height))
	image = Image.create(width, height, false, Image.FORMAT_RGB8)
	
	#matrix = CellularMatrix.new(width, height)
	quadTree = QuadTree.new(Rect2i(0, 0, width, height), 64)
	
	if threadCount == width || width / threadCount > 2:
		printerr("Thread count is equal to width!")
		get_tree().quit()
	
	for i in threadCount:
		threads.append(Thread.new())
		threadIndicies.append(i)
	threadIndicies.shuffle()
	
	#for x in width:
		#if x % 2 == 0:
			#cells[Vector2i(x, 1)] = Cell.new()
		#if x % 2 != 0:
			#cells[Vector2i(x, 3)] = Cell.new()
	
	threadProcessed.connect(onThreadProcessed)
	
	# Initialze screen
	passToShader()

func _exit_tree() -> void:
	for thread in threads:
		if thread.is_alive():
			thread.wait_to_finish()

func _input(event) -> void:
	## Brush
	if event is InputEventKey:
		if event.is_action_released("brush_shape"):
			squareBrush = !squareBrush
		
		for i in Cell.Elements.size():
			if i == 0: # Ignore empty
				continue
			if event.is_action_pressed("num%s" % i):
				selectedElement = Cell.Elements.values()[i]
	
	## Mouse Position
	if event is InputEventMouseMotion:
		if event.velocity != Vector2.ZERO:
			#mousePos = Vector2i(event.position / Vector2(get_viewport().size) * Vector2(width, height))
			#mousePos = Vector2i(event.position) / cellSize # Works when Project/Settings/Display/Window/Stretch/Mode is 'viewport'
			var mp: Vector2 = event.position
			mp -= colorRect.position
			mp /= colorRect.size
			mp.x *= width
			mp.y *= height
			mousePos.x = roundi(mp.x)
			mousePos.y = roundi(mp.y)
	
	## Mouse Buttons
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP && event.pressed:
			brushRadius = min(99, brushRadius + 1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN && event.pressed:
			brushRadius = max(0, brushRadius - 1)
		
		isAdding = event.is_action_pressed("mouse_left")
		isRemoveing = event.is_action_pressed("mouse_right")

func checkBounds(x: int, y: int) -> bool:
	return x >= 0 && x < width && y >= 0 && y < height

func handleMouse() -> void:
	if isAdding || isRemoveing:
		var pos := Vector2i.ZERO
		for x in range(-brushRadius, brushRadius + 1):
			for y in range(-brushRadius, brushRadius + 1):
				pos.x = mousePos.x + x
				pos.y = mousePos.y + y
				if !checkBounds(pos.x, pos.y):
					continue
				if vec2iDist(mousePos, pos) <= brushRadius || squareBrush:
					if isRemoveing:
						if cells.has(pos):
							cells.erase(pos)
							quadTree.remove(pos)
							markPassShader = true
					if isAdding:
						if !cells.has(pos):
							var cell := Cell.new(selectedElement)
							cells[pos] = cell
							quadTree.insert(pos)
							markPassShader = true

func vec2iDist(a: Vector2i, b: Vector2i) -> float:
	return sqrt(pow(a.x - b.x, 2.) + pow(a.y - b.y, 2.))

func dictSubsetFromKeys(keys: Array, from: Dictionary) -> Dictionary:
	var sub: Dictionary = {}
	for key in keys:
		if from.has(key):
			sub[key] = from.get(key)
	return sub

func onThreadProcessed(processedCells: Dictionary, index: int) -> void:
	var time := Time.get_ticks_msec()
	for pos in processedCells.keys():
		if !checkBounds(pos.x, pos.y):
			continue
		
		var cell: Cell = processedCells.get(pos)
		#if cell.visited:
		if cell == null:
			cells.erase(pos)
			quadTree.remove(pos)
		else:
			cells[pos] = cell
			quadTree.insert(pos)
		#cells[pos].visited = false
		markPassShader = true
	threads[index].wait_to_finish()
	print("Processing thread %s took %s miliseconds" % [index, Time.get_ticks_msec() - time])

func startThread(index: int) -> void:
	var thread := threads[index]
	if thread.is_started():
		#thread.wait_to_finish()
		return
	
	var threadWidth: int = width / threadCount
	var keys := quadTree.queryRange(Rect2(threadWidth * index, 0., threadWidth, height))
	if !keys.is_empty():
		var threadCells := dictSubsetFromKeys(keys, cells)
		thread.start(processThread.bind(threadCells, index))
		print("Starting thread", index)

func processThread(threadCells: Dictionary, index: int) -> void:
	for pos in threadCells.keys():
		if !checkBounds(pos.x, pos.y):
			continue
		var cell: Cell = threadCells.get(pos)
		if !cell.isMovible():
			continue
		
		if cell.element == Cell.Elements.SAND || cell.element == Cell.Elements.RAINBOW_DUST:
			var dx: int = pos.x + (1 if randf() > .5 else -1)
			#var up: bool = checkBounds(pos.x, pos.y - 1) && !threadCells.has(Vector2i(pos.x, pos.y - 1))
			var down: bool = checkBounds(pos.x, pos.y + 1) && !threadCells.has(Vector2i(pos.x, pos.y + 1))
			var side: bool = checkBounds(dx, pos.y) && !threadCells.has(Vector2i(dx, pos.y))
			var sided: bool = side && checkBounds(dx, pos.y + 1) && !threadCells.has(Vector2i(dx, pos.y + 1))
			
			if down:
				#cell.visited = true
				threadCells[Vector2i(pos.x, pos.y + 1)] = cell
				#threadCells.erase(pos)
				threadCells[pos] = null
				#markPassShader = true
			elif sided:
				#cell.visited = true
				threadCells[Vector2i(dx, pos.y + 1)] = cell
				#threadCells.erase(pos)
				threadCells[pos] = null
				#markPassShader = true
	#threadProcessed.emit(threadCells, index)
	#emit_signal("threadProcessed", threadCells, index)
	call_deferred("emit_signal", "threadProcessed", threadCells, index)

func _physics_process(delta) -> void:
	handleMouse()
	
	#for pos in cells.keys():
		#if !checkBounds(pos.x, pos.y):
			#continue
		#var cell: Cell = cells.get(pos)
		#if !cell.isMovible():
			#continue
		#
		#if cell.element == Cell.Elements.SAND || cell.element == Cell.Elements.RAINBOW_DUST:
			#var dx: int = pos.x + (1 if randf() > .5 else -1)
			#var up: bool = checkBounds(pos.x, pos.y - 1) && !cells.has(Vector2i(pos.x, pos.y - 1))
			#var down: bool = checkBounds(pos.x, pos.y + 1) && !cells.has(Vector2i(pos.x, pos.y + 1))
			#var side: bool = checkBounds(dx, pos.y) && !cells.has(Vector2i(dx, pos.y))
			#var sided: bool = side && checkBounds(dx, pos.y + 1) && !cells.has(Vector2i(dx, pos.y + 1))
			#
			#if down:
				#cells[Vector2i(pos.x, pos.y + 1)] = cell
				#cells.erase(pos)
				#quadTree.insert(Vector2i(pos.x, pos.y + 1))
				#quadTree.remove(pos)
				#markPassShader = true
			#elif sided:
				#cells[Vector2i(dx, pos.y + 1)] = cell
				#cells.erase(pos)
				#quadTree.insert(Vector2i(dx, pos.y + 1))
				#quadTree.remove(pos)
				#markPassShader = true
			#elif !up && side: # Push cell to side if another is on top
				#cells[Vector2i(dx, pos.y)] = cell
				#cells.erase(pos)
				#markPassShader = true
			#elif pos.y == height - 1: # 'Fall' through bottom & appear up top
				#var top := Vector2i(pos.x, 0)
				#if !cells.has(top):
					#cells[top] = cell
					#cells.erase(pos)
					#markPassShader = true
	
	for i in threadIndicies:
		if Engine.get_frames_drawn() % 2 == 0: # Even threads
			startThread(i)
		else:
			startThread(i)
	threadIndicies.shuffle()
	
	if markPassShader:
		passToShader()
		markPassShader = false

func passToShader() -> void:
	var time := Time.get_ticks_msec()
	#var image := Image.create(width, height, false, Image.FORMAT_RGB8)
	image.fill(Color.BLACK)
	for pos in cells.keys():
		if !checkBounds(pos.x, pos.y):
			continue
		var color = cells.get(pos).getColor()
		image.set_pixelv(pos, color)
	
	var texture = ImageTexture.create_from_image(image)
	colorRect.material.set_shader_parameter("tex", texture)
	print("Passing to shader took %s miliseconds" % [Time.get_ticks_msec() - time])
