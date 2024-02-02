## https://en.wikipedia.org/wiki/Quadtree
class_name QuadTree
extends Resource

var boundary: Rect2
var capacity: int

var points: Array[Vector2i] = []

# Children
var northWest: QuadTree
var northEast: QuadTree
var southWest: QuadTree
var southEast: QuadTree

func _init(boundary: Rect2, capacity: int = 8):
	self.boundary = boundary
	self.capacity = capacity

func clear() -> void:
	if points.size() != 0:
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

func subdivide() -> void:
	var x := boundary.position.x
	var y := boundary.position.y
	var w := boundary.size.x / 2.
	var h := boundary.size.y / 2.
	
	northWest = QuadTree.new(Rect2(x, y, w, h), capacity)
	northEast = QuadTree.new(Rect2(x + w, y, w, h), capacity)
	southWest = QuadTree.new(Rect2(x, y + h, w, h), capacity)
	southEast = QuadTree.new(Rect2(x + w, y + h, w, h), capacity)
	
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
	for p in points.size():
		if range.has_point(points[p]):
			pointsInRange.append(points[p])
	
	# Terminate here, if there are no children
	if !northWest:
		return pointsInRange
	
	# Otherwise, add the point from the children
	pointsInRange.append_array(northWest.queryRange(range))
	pointsInRange.append_array(northEast.queryRange(range))
	pointsInRange.append_array(southWest.queryRange(range))
	pointsInRange.append_array(southEast.queryRange(range))
	
	return pointsInRange
