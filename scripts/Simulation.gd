class_name Simulation
extends Node2D

@onready var colorRect: ColorRect = $CanvasLayer/Control/ColorRect
@export_range(16, 160, 1, "or_greater") var width: int = 160
@export_range(9, 90, 1, "or_greater") var height: int = 90

@export_range(1, 100) var brushRadius: int = 3
@export var squareBrush: bool = false
var selectedElement := Cell.Elements.SAND

#var matrix: CellularMatrix
var cells: Array[Cell] = []
#var idleRowSums: Array[int] = [] # Keeps track of how many tiles are in each row

var image: Image
var texture: ImageTexture
var markPassShader := false

var mousePos := Vector2i.ZERO
var isAdding := false
var isRemoveing := false

@export_range(1, 64) var threadCount: int = 4
var threads: Array[Thread] = []
var mutex: Mutex
#var semaphoreEven: Semaphore
#var semaphoreOdd: Semaphore
var exitThread := false
@export_range(30, 240, 15) var updatedFreq: int = 60

func _ready() -> void:
	# Checks for thread count
	#if threadCount > 4 && threadCount % 4 != 0:
		#threadCount -= threadCount % 4
	if threadCount == width || width / threadCount < 2 || width < threadCount:
		printerr("Thread count is equal to width!")
		get_tree().quit()
	
	# Vsync & fps
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
	cells.resize(width * height)
	cells.fill(Cell.new())
	
	#idleRowSums.resize(height)
	#idleRowSums.fill(0)
	
	mutex = Mutex.new()
	#semaphoreEven = Semaphore.new()
	#semaphoreOdd = Semaphore.new()
	
	#for x in width:
		#if x % 2 == 0:
			#setCellv(Vector2i(x, 1), Cell.new(Cell.Elements.STONE))
		#if x % 2 != 0:
			#setCellv(Vector2i(x, 3), Cell.new(Cell.Elements.STONE))
	
	# Initialze screen
	passToShader()
	
	threads.resize(threadCount)
	for i in threadCount:
		threads[i] = Thread.new()
		if i % 2 == 0:
			threads[i].start(processThreadEven.bind(i))
		else:
			threads[i].start(processThreadOdd.bind(i))
		print("Thread %s has id %s" % [i, threads[i].get_id()])

## https://www.reddit.com/r/godot/comments/10lvy18/comment/j5zdo60/?utm_source=share&utm_medium=web2x&context=3
func enableBit(mask: int, i: int) -> int:
	return mask | (1 << i)

func disableBit(mask: int, i: int) -> int:
	return mask & ~(1 << i)

func _exit_tree() -> void:
	# Set thread exit condition
	mutex.lock()
	exitThread = true
	mutex.unlock()
	
	# Unblock by posting
	#semaphoreEven.post()
	#semaphoreOdd.post()
	
	# Wait for threads to finish
	for i in threadCount:
		if threads[i].is_alive():
			print("Stopping thread ", threads[i].get_id())
			threads[i].wait_to_finish()

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

func getCellv(pos: Vector2i) -> Cell:
	if !checkBounds(pos.x, pos.y):
		return null
	if !cells[pos.y * width + pos.x]:
		print("WHY IS THIS NULL?! ", pos)
		cells[pos.y * width + pos.x] = Cell.new()
	return cells[pos.y * width + pos.x]

func setCellv(pos: Vector2i, cell: Cell, passShader: bool = true) -> void:
	cells[pos.y * width + pos.x] = cell
	
	image.set_pixelv(pos, cell.getColor())
	
	#if cell.isMovible():
		#if cell.element == Cell.Elements.EMPTY:
			#idleRowSums[pos.y] = disableBit(idleRowSums[pos.y], pos.x)
		#else:
			#idleRowSums[pos.y] = enableBit(idleRowSums[pos.y], pos.x)
	
	if passShader:
		markPassShader = true

func eraseCellv(pos: Vector2i, passShader: bool = true) -> bool:
	cells[pos.y * width + pos.x] = Cell.new()
	image.set_pixelv(pos, Color.BLACK)
	if passShader:
		markPassShader = true
	
	#idleRowSums[pos.y] = disableBit(idleRowSums[pos.y], pos.x)
	return true

func checkBounds(x: int, y: int) -> bool:
	return x >= 0 && x < width && y >= 0 && y < height

func handleMouse() -> void:
	if isAdding || isRemoveing:
		var pos := Vector2i.ZERO
		mutex.lock()
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
						if getCellv(pos).element == Cell.Elements.EMPTY:
							var cell := Cell.new(selectedElement)
							setCellv(pos, cell)
		mutex.unlock()

func vec2iDist(a: Vector2i, b: Vector2i) -> float:
	return sqrt(pow(a.x - b.x, 2.) + pow(a.y - b.y, 2.))

func getThreadBounds(index: int) -> Rect2:
	var threadWidth: int = width / threadCount
	return Rect2(threadWidth * index, 0., threadWidth, height)

func processThreadEven(index: int) -> void:
	Thread.set_thread_safety_checks_enabled(false)
	var time: int = 1000 / updatedFreq
	while true:
		#semaphoreEven.wait()
		OS.delay_msec(time)
		
		mutex.lock()
		var shouldExit = exitThread
		mutex.unlock()
		
		if shouldExit:
			break
		
		## DO SHIT!
		if Engine.get_physics_frames() % 2 == 0:
			processThread(index)

func processThreadOdd(index: int) -> void:
	Thread.set_thread_safety_checks_enabled(false)
	var time: int = 1000 / updatedFreq
	while true:
		#semaphoreOdd.wait()
		OS.delay_msec(time)
		
		mutex.lock()
		var shouldExit = exitThread
		mutex.unlock()
		
		if shouldExit:
			break
		
		## DO SHIT!
		if Engine.get_physics_frames() % 2 != 0:
			processThread(index)

func processThread(index: int) -> void:
	#var time := Time.get_ticks_msec()
	mutex.lock()
	var cellsLocal := cells.duplicate() #cellsToProcess
	#var idleRowSumsLocal := idleRowSums
	mutex.unlock()
	
	var cellsToPlace: Array[Cell] = []
	var cellsToPlacePos: Array[Vector2i] = []
	var cellsToErase: Array[Vector2i] = []
	
	var threadWidth: int = width / threadCount
	var threadX: int = threadWidth * index
	for y in range(height, 0, -1):
		y -= 1
		#if idleRowSumsLocal[y] == 0: # Skip empty rows (x axis)
			#continue
		for x in range(threadX, threadX + threadWidth):
			if !checkBounds(x, y):
				continue
			var cell: Cell = cellsLocal[y * width + x]
			if !cell:
				print("Thread ", index, ": Cell at (", x, y, ") is null!")
				continue
			
			if !cell.isMovible():
				continue
			
			if cell.element == Cell.Elements.SAND || cell.element == Cell.Elements.RAINBOW_DUST:
				var dx: int = x + (1 if randf() > .5 else -1)
				#var up: bool = checkBounds(pos.x, pos.y - 1) && !cellsLocal.has(Vector2i(pos.x, pos.y - 1))
				var down: bool = checkBounds(x, y + 1) && cellsLocal[(y + 1) * width + x].element == Cell.Elements.EMPTY #!cellsLocal.has(Vector2i(pos.x, pos.y + 1))
				var side: bool = checkBounds(dx, y) && cellsLocal[y * width + dx].element == Cell.Elements.EMPTY #!cellsLocal.has(Vector2i(dx, pos.y))
				var sided: bool = side && checkBounds(dx, y + 1) && cellsLocal[(y + 1) * width + dx].element == Cell.Elements.EMPTY #!cellsLocal.has(Vector2i(dx, pos.y + 1))
				
				if down:
					cellsToPlace.push_back(cell)
					cellsToPlacePos.push_back(Vector2i(x, y + 1))
					cellsToErase.push_back(Vector2i(x, y))
				elif sided:
					cellsToPlace.push_back(cell)
					cellsToPlacePos.push_back(Vector2i(dx, y + 1))
					cellsToErase.push_back(Vector2i(x, y))
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
	for pos in cellsToErase:
		eraseCellv(pos)
	
	for i in cellsToPlace.size():
		setCellv(cellsToPlacePos[i], cellsToPlace[i])
	mutex.unlock()
	#print("Updating thread %s took %s miliseconds" % [OS.get_thread_caller_id(), Time.get_ticks_msec() - time])

func _physics_process(_delta) -> void:
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
	#if Engine.get_physics_frames() % 2 == 0:
		#semaphoreEven.post()
	#else:
		#semaphoreOdd.post()
	
	if markPassShader:
		passToShader()
		#matrix.post()
		markPassShader = false

func passToShader() -> void:
	#var time := Time.get_ticks_msec()
	#image.fill(Color.BLACK)
	#for pos in cells.keys():
		#if !checkBounds(pos.x, pos.y):
			#continue
		#var color = cells.get(pos).getColor()
		#image.set_pixelv(pos, color)
	
	texture.update(image)
	colorRect.material.set_shader_parameter("tex", texture)
	#print("Passing to shader took %s miliseconds" % [Time.get_ticks_msec() - time])
