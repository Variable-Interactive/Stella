class_name PlotLine
extends HBoxContainer


func serialize() -> Dictionary:
	return {
		"title": %LineEdit.text,
		"line_type": %Mode.get_item_text(%Mode.selected),
		"width": %Width.value,
		"x_column": int(%Columns.value.x),
		"y_column": int(%Columns.value.y),
		"color": %ColorPickerButton.color,
	}


func _on_remove_pressed() -> void:
	if get_parent().get_child_count() > 1:
		queue_free()
