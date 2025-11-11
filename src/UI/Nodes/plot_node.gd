class_name PlotLine
extends HBoxContainer

@onready var plot_label: LineEdit = %PlotLabel
@onready var override_file: LineEdit = %Override
@onready var mode: OptionButton = %Mode
@onready var width: ValueSlider = %Width
@onready var columns: ValueSliderV2 = %Columns
@onready var color_picker_button: ColorPickerButton = %ColorPickerButton
@onready var collapse_override: Button = %CollapseOverride


var line_modes = [
	{"Lines" : "lines"},
	{"Connected Line (hollow PDF)" : "linespoints pt '◉' pi '-1'"},
	{"Connected Line (hollow PNG)" : "linespoints pt 'o' pi '-1'"},
	{"Circle" : "points pt 'o'"},
	{"Cross" : "points"},
	{"Cross connected": "linesp"},
	{"Dots" : "dots"},
	{"Filled Curve" : "filledcurve"},
	{"Boxes" : "boxes"},
]

func _ready() -> void:
	for i in line_modes.size():
		mode.add_item(line_modes[i].keys()[0], i)
	pass


func deserialize(data: Dictionary) -> void:
	plot_label.text = data.get("title", plot_label.text)
	override_file.text = data.get("override_file", override_file.text).strip_edges()
	if override_file.text.strip_edges() != "":
		override_file.visible = true
	var modes := []
	for i in line_modes.size():
		modes.append(line_modes[i].values()[0])
	var line_type = data.get("line_type", modes[0])
	mode.select(modes.find(line_type))
	width.value = data.get("width", width.value)
	columns.value.x = data.get("x_column", columns.value.x)
	columns.value.y = data.get("y_column", columns.value.y)
	color_picker_button.color = data.get("color", color_picker_button.color)


func serialize() -> Dictionary:
	return {
		"title": plot_label.text,
		"override_file": override_file.text,
		"line_type": line_modes[mode.selected].values()[0],
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
