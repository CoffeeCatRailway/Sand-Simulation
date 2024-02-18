## https://en.wikipedia.org/wiki/Quadtree
class_name QuadTree
extends Resource

var boundary: Rect2
var capacity: int

var points: Array[Vector2i] = []

var parent: QuadTree

# Children
var northWest: QuadTree
var northEast: QuadTree
var southWest: QuadTree
var southEast: QuadTree

func _init(boundary: Rect2, capacity: int = 8, parent: QuadTree = null):
	self.boundary = boundary
	self.capacity = capacity
	self.parent = parent

func clear() -> void:
	if !points.is_empty():
		points.clear()
	
	if northWest:
		#northWest.free()
		#northEast.free()
		#southWest.free()
		#southEast.free()
		northWest = null
		northEast = null
		southWest = null
		southEast = null

func insert(point: Vector2i) -> bool:
	# Ignore objects that do not belong in this quad tree
	if !boundary.has_point(point):
		return false
	
	if points.has(point):
		return false
	
	# If there is space in this quad tree and if doesn't have subdivisions, add the object
	if points.size() < capacity && !northWest:
		points.append(point)
		return true
	
	# Otherwise, subdivide and then add the point to whichever node will accept it
	if !northWest:
		subdivide()
	
	# We have to add the points/data contained in this quad array to the new quads if we only want the last node to hold the data
	if northWest.insert(point): return true
	if northEast.insert(point): return true
	if southWest.insert(point): return true
	if southEast.insert(point): return true
	
	# Otherwise, the point cannot be inserted for some unkown reason (this should never happen)
	return false

func remove(point: Vector2i) -> bool:
	# Ignore objects that do not belong in this quad tree
	if !boundary.has_point(point):
		return false
	
	if points.has(point):
		points.erase(point)
		if points.size() <= capacity:
			merge()
		return true
	
	if northWest:
		if northWest.remove(point): return true
		if northEast.remove(point): return true
		if southWest.remove(point): return true
		if southEast.remove(point): return true
	
	return false

func canEmptyChildren() -> bool:
	var children := [northWest, northEast, southWest, southEast]
	for child in children:
		if !child || child.northWest || !child.points.is_empty():
			return false
	return true

func merge() -> void:
	if northWest && canEmptyChildren():
		northWest = null
		northEast = null
		southWest = null
		southEast = null
	
	if !points.is_empty():
		#print("Has points", points)
		return
	
	if northWest:
		var children := [northWest, northEast, southWest, southEast]
		for child in children:
			if child.northWest || !child.points.is_empty():
				return
	
	clear()
	if parent:
		parent.merge()

func subdivide() -> void:
	var x := boundary.position.x
	var y := boundary.position.y
	var w := boundary.size.x / 2.
	var h := boundary.size.y / 2.
	
	northWest = QuadTree.new(Rect2(x, y, w, h), capacity, self)
	northEast = QuadTree.new(Rect2(x + w, y, w, h), capacity, self)
	southWest = QuadTree.new(Rect2(x, y + h, w, h), capacity, self)
	southEast = QuadTree.new(Rect2(x + w, y + h, w, h), capacity, self)
	
	for p in points:
		northWest.insert(p)
		northEast.insert(p)
		southWest.insert(p)
		southEast.insert(p)
	points.clear()

func queryRange(range: Rect2) -> Array[Vector2i]:
	var pointsInRange: Array[Vector2i] = []
	
	# Automatically abort if the range does not intersect this quad
	if !boundary.intersects(range):
		return pointsInRange
	
	# Check objects at this quad level
	for p in points:
		if range.has_point(p):
			pointsInRange.append(p)
	
	# Terminate here, if there are no children
	if !northWest:
		return pointsInRange
	
	# Otherwise, add the point from the children
	pointsInRange.append_array(northWest.queryRange(range))
	pointsInRange.append_array(northEast.queryRange(range))
	pointsInRange.append_array(southWest.queryRange(range))
	pointsInRange.append_array(southEast.queryRange(range))
	
	return pointsInRange
