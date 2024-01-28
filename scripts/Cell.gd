class_name Cell
extends Resource

@export var type: Type = Type.EMPTY
@export var visited: bool = false
#@export var color: Color = Color.BLACK

enum Type
{
	EMPTY,
	SAND,
	GAS,
	WATER
}

func getColor() -> Color:
	match type:
		Type.SAND:
			return Color.SANDY_BROWN
		Type.GAS:
			return Color.LIGHT_GRAY
		Type.WATER:
			return Color.CORNFLOWER_BLUE
		_:
			return Color.BLACK

func getDensity() -> int: #0-100  0 being nothing
	match type:
		Type.SAND:
			return 20
		Type.GAS:
			return 5
		Type.WATER:
			return 10
		_:
			return 0
