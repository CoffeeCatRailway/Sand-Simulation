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
var cellsToProcess: Dictionary = {}
var cellsProcessed: Dictionary = {}
var quadTree: QuadTree
var sharedQuadTree: QuadTree

var image: Image
var texture: ImageTexture
var markPassShader := false

var mousePos := Vector2i.ZERO
var isAdding := false
var isRemoveing := false

@export_range(1, 64) var threadCount: int = 4
var threads: Array[Thread] = []
#var threadIndicies: Array[int] = []
var mutex: Mutex
var semaphoreEven: Semaphore
var semaphoreOdd: Semaphore
var exitThread := false

func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	Engine.max_fps = 60
	#Engine.max_physics_steps_per_frame = 120
	
	# Calculate width/height
	print("Sim Resolution: %s/%s" % [width, height])
	print("Thread count: ", threadCount)
	
	# Pass width/height to sahder
	colorRect.material.set_shader_parameter("size", Vector2(width, height))
	image = Image.create(width, height, false, Image.FORMAT_RGB8)
	image.fill(Color.BLACK)
	texture = ImageTexture.create_from_image(image)
	
	#matrix = CellularMatrix.new(width, height)
	quadTree = QuadTree.new(Rect2i(0, 0, width, height), 64)
	sharedQuadTree = quadTree
	
	if threadCount == width || width / threadCount < 2:
		printerr("Thread count is equal to width!")
		get_tree().quit()
	
	mutex = Mutex.new()
	semaphoreEven = Semaphore.new()
	semaphoreOdd = Semaphore.new()
	
	#for x in width:
		#if x % 2 == 0:
			#setCellv(Vector2i(x, 1), Cell.new())
		#if x % 2 != 0:
			#setCellv(Vector2i(x, 3), Cell.new())
	
	# Initialze screen
	passToShader()
	
	threads.resize(threadCount)
	for i in threadCount:
		threads[i] = Thread.new()
		if i % 2 == 0:
			threads[i].start(processThreadEven.bind(i))
		else:
			threads[i].start(processThreadOdd.bind(i))

func _exit_tree() -> void:
	# Set thread exit condition
	mutex.lock()
	exitThread = true
	mutex.unlock()
	
	# Unblock by posting
	semaphoreEven.post()
	semaphoreOdd.post()
	
	# Wait for threads to finish
	for i in threadCount:
		if threads[i].is_alive():
			threads[i].wait_to_finish()
			threads[i] = null
			print("Thread ", i, " stopped")

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

func setCellv(pos: Vector2i, cell: Cell, passShader: bool = true) -> void:
	cells[pos] = cell
	quadTree.insert(pos)
	image.set_pixelv(pos, cell.getColor())
	if passShader:
		markPassShader = true

func eraseCellv(pos: Vector2i, passShader: bool = true) -> bool:
	if !cells.has(pos):
		return false
	
	cells.erase(pos)
	quadTree.remove(pos)
	image.set_pixelv(pos, Color.BLACK)
	if passShader:
		markPassShader = true
	return true

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
						eraseCellv(pos)
					if isAdding:
						if !cells.has(pos):
							var cell := Cell.new(selectedElement)
							setCellv(pos, cell)

func vec2iDist(a: Vector2i, b: Vector2i) -> float:
	return sqrt(pow(a.x - b.x, 2.) + pow(a.y - b.y, 2.))

#func dictSubsetFromKeys(keys: Array, from: Dictionary) -> Dictionary:
	#var sub: Dictionary = {}
	#for key in keys:
		#if from.has(key):
			#sub[key] = from.get(key)
	#return sub

func getThreadBounds(index: int) -> Rect2:
	var threadWidth: int = width / threadCount
	return Rect2(threadWidth * index, 0., threadWidth, height)

func processThreadEven(index: int) -> void:
	Thread.set_thread_safety_checks_enabled(false)
	while true:
		semaphoreEven.wait()
		
		mutex.lock()
		var shouldExit = exitThread
		mutex.unlock()
		
		if shouldExit:
			print("Stopping even thread ", index)
			break
		
		## DO SHIT!
		if processThread(index):
			pass#semaphoreEven.post()

func processThreadOdd(index: int) -> void:
	Thread.set_thread_safety_checks_enabled(false)
	while true:
		semaphoreOdd.wait()
		
		mutex.lock()
		var shouldExit = exitThread
		mutex.unlock()
		
		if shouldExit:
			print("Stopping odd thread ", index)
			break
		
		## DO SHIT!
		if processThread(index):
			pass#semaphoreOdd.post()

func processThread(index: int) -> bool:
	var time := Time.get_ticks_msec()
	mutex.lock()
	var cellsLocal := cellsToProcess
	var quadTreeLocal := sharedQuadTree
	mutex.unlock()
	
	if !quadTreeLocal || !quadTreeLocal.northWest && quadTreeLocal.points.is_empty():
		return false
	
	var cellsProcessedLocal: Dictionary = {}
	var threadCellKeys: Array[Vector2i] = quadTreeLocal.queryRange(getThreadBounds(index))
	#threadCellKeys.shuffle()
	threadCellKeys.sort_custom(func(a: Vector2i, b: Vector2i): return a.y < b.y) # bottom to top
	
	for pos in threadCellKeys:
		if !checkBounds(pos.x, pos.y):
			continue
		var cell: Cell = cellsLocal.get(pos)
		if !cell:
			push_warning("Thread ", index, ": Cell at ", pos, " is null!")
			continue
		
		if !cell.isMovible():
			continue
		
		if cell.element == Cell.Elements.SAND || cell.element == Cell.Elements.RAINBOW_DUST:
			var dx: int = pos.x + (1 if randf() > .5 else -1)
			#var up: bool = checkBounds(pos.x, pos.y - 1) && !cellsLocal.has(Vector2i(pos.x, pos.y - 1))
			var down: bool = checkBounds(pos.x, pos.y + 1) && !cellsLocal.has(Vector2i(pos.x, pos.y + 1))
			var side: bool = checkBounds(dx, pos.y) && !cellsLocal.has(Vector2i(dx, pos.y))
			var sided: bool = side && checkBounds(dx, pos.y + 1) && !cellsLocal.has(Vector2i(dx, pos.y + 1))
			
			if down:
				#cell.visited = true
				cellsProcessedLocal[Vector2i(pos.x, pos.y + 1)] = cell
				cellsProcessedLocal[pos] = null
				#markPassShader = true
			elif sided:
				#cell.visited = true
				cellsProcessedLocal[Vector2i(dx, pos.y + 1)] = cell
				cellsProcessedLocal[pos] = null
				#markPassShader = true
			#elif !up && side: # Push cell to side if another is on top
				#cellsProcessedLocal[Vector2i(dx, pos.y)] = cell
				#cellsProcessedLocal[pos] = null
			#elif pos.y == height - 1: # 'Fall' through bottom & appear up top
				#var top := Vector2i(pos.x, 0)
				#if !cellsLocal.has(top):
					#cellsProcessedLocal[top] = cell
					#cellsProcessedLocal[pos] = null
	
	mutex.lock()
	## changed cells = what ever the fuck
	cellsProcessed.merge(cellsProcessedLocal)
	mutex.unlock()
	print("Updating thread %s took %s miliseconds" % [index, Time.get_ticks_msec() - time])
	return !cellsProcessedLocal.is_empty()

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
				##cell.visited = true
				#setCellv(Vector2i(pos.x, pos.y + 1), cell)
				#eraseCellv(pos)
			##elif sided:
				###cell.visited = true
				##setCellv(Vector2i(dx, pos.y + 1), cell)
				##eraseCellv(pos)
			#elif !up && side: # Push cell to side if another is on top
				#setCellv(Vector2i(dx, pos.y), cell)
				#eraseCellv(pos)
			##elif pos.y == height - 1: # 'Fall' through bottom & appear up top
				##var top := Vector2i(pos.x, 0)
				##if !cells.has(top):
					##setCellv(top, cell)
					##eraseCellv(pos)
	
	## Some logic to notify threads
	mutex.lock()
	cellsToProcess = cells.duplicate()
	sharedQuadTree = quadTree
	var cellsProcessedLocal := cellsProcessed.duplicate()
	mutex.unlock()
	
	if Engine.get_physics_frames() % 2 == 0:
		semaphoreEven.post()
	else:
		semaphoreOdd.post()
	
	if !cellsProcessedLocal.is_empty():
		var updated: Array[Vector2i] = []
		for pos in cellsProcessedLocal.keys():
			var cell: Cell = cellsProcessedLocal.get(pos)
			if cell:
				setCellv(pos, cell)
			else:
				eraseCellv(pos)
			updated.append(pos)
		
		mutex.lock()
		for pos in updated:
			cellsProcessed.erase(pos)
		mutex.unlock()
	
	if markPassShader:
		passToShader()
		#matrix.post()
		markPassShader = false

func passToShader() -> void:
	#var time := Time.get_ticks_msec()
	#var image := Image.create(width, height, false, Image.FORMAT_RGB8)
	#image.fill(Color.BLACK)
	#for pos in cells.keys():
		#if !checkBounds(pos.x, pos.y):
			#continue
		#var color = cells.get(pos).getColor()
		#image.set_pixelv(pos, color)
	
	#var texture = ImageTexture.create_from_image(image)
	texture.set_image(image)
	colorRect.material.set_shader_parameter("tex", texture)
	#print("Passing to shader took %s miliseconds" % [Time.get_ticks_msec() - time])
