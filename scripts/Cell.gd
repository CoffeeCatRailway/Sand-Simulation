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
