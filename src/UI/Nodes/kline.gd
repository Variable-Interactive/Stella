class_name KLine
extends HBoxContainer

@onready var dist_slider: ValueSlider = $ValueSlider
@onready var line_edit: LineEdit = $LineEdit


func serialize() -> Dictionary:
	return {
		dist_slider.value: line_edit.text
	}


func derialize(data: Dictionary):
	line_edit.text = data.get("label", "XX")
	if line_edit.text.to_lower() == "g":
		line_edit.text = "{/Symbol %s}" % line_edit.text
	var distance = data.get("distance", 0.0)
	if typeof(distance) == TYPE_STRING:
		distance = str_to_var(distance)
		if typeof(distance) != TYPE_STRING:
			dist_slider.value = distance


func _on_remove_pressed() -> void:
	queue_free()
