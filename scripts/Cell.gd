class_name Cell
extends Resource

@export var element: Elements = Elements.EMPTY
@export var visited: bool = false
#@export var color: Color = Color.BLACK

enum Elements
{
	EMPTY,
	SAND,
	GAS,
	WATER,
	STONE
}

func getColor() -> Color:
	var res: Color
	match element:
		Elements.SAND:
			res = Color.SANDY_BROWN
		Elements.GAS:
			res = Color.LIGHT_GRAY
		Elements.WATER:
			res = Color.CORNFLOWER_BLUE
		Elements.STONE:
			res = Color.DIM_GRAY
		_:
			return Color.BLACK
	res.v -= randf_range(.1, .3)
	return res

func getDensity() -> int: #0-100  0 being nothing
	match element:
		Elements.SAND:
			return 20
		Elements.GAS:
			return 5
		Elements.WATER:
			return 10
		Elements.STONE:
			return 50
		_:
			return 0

func isMovible() -> bool:
	match element:
		Elements.SAND:
			return true
		Elements.GAS:
			return true
		Elements.WATER:
			return true
		_:
			return false
