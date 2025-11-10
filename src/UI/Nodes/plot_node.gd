class_name PlotLine
extends HBoxContainer

@onready var plot_label: LineEdit = %PlotLabel
@onready var override_file: LineEdit = %Override
@onready var mode: OptionButton = %Mode
@onready var width: ValueSlider = %Width
@onready var columns: ValueSliderV2 = %Columns
@onready var color_picker_button: ColorPickerButton = %ColorPickerButton
@onready var collapse_override: Button = %CollapseOverride


func deserialize(data: Dictionary) -> void:
	plot_label.text = data.get("title", plot_label.text)
	override_file.text = data.get("override_file", override_file.text).strip_edges()
	if override_file.text.strip_edges() != "":
		override_file.visible = true
	width.value = data.get("width", width.value)
	columns.value.x = data.get("x_column", columns.value.x)
	columns.value.y = data.get("y_column", columns.value.y)
	color_picker_button.color = data.get("color", color_picker_button.color)


func serialize() -> Dictionary:
	return {
		"title": plot_label.text,
		"override_file": override_file.text,
		"line_type": mode.get_item_text(%Mode.selected),
		"width": width.value,
		"x_column": int(columns.value.x),
		"y_column": int(columns.value.y),
		"color": color_picker_button.color,
	}


func _on_remove_pressed() -> void:
	if get_parent().get_child_count() > 1:
		queue_free()


func _on_override_focus_exited() -> void:
	if override_file.text.strip_edges() == "":
		collapse_override.visible = true
		override_file.visible = false


func _on_collapse_override_pressed() -> void:
	collapse_override.visible = false
	override_file.visible = true
	override_file.grab_focus() 
