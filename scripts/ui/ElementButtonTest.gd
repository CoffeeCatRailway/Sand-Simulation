extends Control

func _on_btn_pressed(index: int) -> void:
	if index < 0 || index >= Cell.Elements.size():
		printerr("Element index out of bounds ", index)
		return
	print("Element ", Cell.Elements.keys()[index])
