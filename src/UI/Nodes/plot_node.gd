class_name PlotLine
extends HBoxContainer

@onready var line_edit: LineEdit = %LineEdit
@onready var mode: OptionButton = %Mode
@onready var width: ValueSlider = %Width
@onready var columns: ValueSliderV2 = %Columns
@onready var color_picker_button: ColorPickerButton = %ColorPickerButton
var data_to_load_on_ready: Dictionary

func _ready() -> void:
	if data_to_load_on_ready:
		deserialize(data_to_load_on_ready)
		data_to_load_on_ready.clear()


func deserialize(data: Dictionary) -> void:
	line_edit.text = data.get("title", line_edit.text)
	width.value = data.get("width", width.value)
	columns.value.x = data.get("x_column", columns.value.x)
	columns.value.y = data.get("y_column", columns.value.y)
	color_picker_button.color = data.get("color", color_picker_button.color)


func serialize() -> Dictionary:
	return {
		"title": line_edit.text,
		"line_type": mode.get_item_text(%Mode.selected),
		"width": width.value,
		"x_column": int(columns.value.x),
		"y_column": int(columns.value.y),
		"color": color_picker_button.color,
	}


func _on_remove_pressed() -> void:
	if get_parent().get_child_count() > 1:
		queue_free()
