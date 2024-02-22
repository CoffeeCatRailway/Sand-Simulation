extends Node2D

var thread: Thread
var thread1: Thread
var mutex: Mutex
var semaphore: Semaphore

var counter: int = 0
#var sharedCounter: int = 0

var exitThread: bool = false

func _ready():
	thread = Thread.new()
	thread1 = Thread.new()
	mutex = Mutex.new()
	semaphore = Semaphore.new()
	
	thread.start(threadProcess)
	print(thread.get_id())
	thread1.start(thread1Process)
	print(thread1.get_id())
	print("Main thread ", OS.get_thread_caller_id())

func _exit_tree() -> void:
	mutex.lock()
	exitThread = true
	mutex.unlock()
	
	semaphore.post()
	
	if thread.is_alive():
		thread.wait_to_finish()
	if thread1.is_alive():
		thread1.wait_to_finish()

func threadProcess() -> void:
	while true:
		semaphore.wait()
		
		mutex.lock()
		var shouldExit := exitThread
		mutex.unlock()
		
		if shouldExit:
			break
		
		print("Thread ", OS.get_thread_caller_id())
		mutex.lock()
		var counterLocal := counter + 1
		counter = counterLocal
		mutex.unlock()
		#somefunction()

func thread1Process() -> void:
	while true:
		semaphore.wait()
		
		mutex.lock()
		var shouldExit := exitThread
		mutex.unlock()
		
		if shouldExit:
			break
		
		print("Thread1 ", OS.get_thread_caller_id())
		#mutex.lock()
		counter += 1
		print("Thread1 ", counter)
		#mutex.unlock()
		#somefunction()

func somefunction() -> void:
	print("Thread ", OS.get_thread_caller_id())

func _process(delta):
	if Input.is_action_just_released("num1"):
		semaphore.post()
		print("Main thread ", counter)
