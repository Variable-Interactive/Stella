extends Node

@onready var file_path_edit: LineEdit = %FilePath
@onready var font_names: OptionButton = %FontNames
@onready var font_size: ValueSlider = %FontSize
@onready var titlebar: LineEdit = %Titlebar
@onready var x_label: LineEdit = %XLabel
@onready var y_label: LineEdit = %YLabel
@onready var range_slider: ValueSliderV2 = %RangeSlider
@onready var plot_info: VBoxContainer = %PlotInfo
@onready var k_line_container: VBoxContainer = %KLineContainer


@onready var size_slider: ValueSliderV2 = %SizeSlider
@onready var scale_slider: ValueSliderV2 = %ScaleSlider
@onready var border_outline_slider: ValueSliderV2 = %BorderOutlineSlider

@onready var open_dialog := $Dialogs/OpenDialog


func _ready():
	update_available_font_names()
	# it is not relative to executable so we have to convert it to an
	# absolute path instead (this is when file is relative to working directory)
	var output = []
	var working_directory := ""
	match OS.get_name():
		"Linux":
			OS.execute("pwd", [], output)
		"macOS":
			OS.execute("pwd", [], output)
		"Windows":
			OS.execute("cd", [], output)
	if output.size() > 0:
		working_directory = str(output[0]).strip_edges()
	open_dialog.current_dir = working_directory
	find_band_gap_file()


func serialize() -> Dictionary:
	var data_file_path := file_path_edit.text
	var title: String = titlebar.text
	var x_label: String = x_label.text
	var y_label: String = y_label.text
	var font: String = font_names.get_item_text(font_names.selected)
	var font_size: int = font_size.value
	var size_value: Vector2 = size_slider.value
	var scale_value: Vector2 = scale_slider.value
	var y_range: Vector2 = range_slider.value
	var output_plot_name: String = data_file_path.get_base_dir().path_join(title + ".pdf")
	var border: float = border_outline_slider.value.x
	var outline: float = border_outline_slider.value.y
	var plot_lines: Array[Dictionary] = []
	for line in plot_info.get_children():
		if line is PlotLine:
			plot_lines.append(line.serialize())
	var klines := {}
	for kline in k_line_container.get_children():
		if kline is KLine:
			klines.merge(kline.serialize())
	return {
		"data_file_path": data_file_path,
		"plot_lines": plot_lines,
		"title": title,
		"x_label": x_label,
		"y_label": y_label,
		"font": font,
		"font_size": font_size,
		"size_value": size_value,
		"scale_value": scale_value,
		"y_range": y_range,
		"output_plot_name": output_plot_name,
		"border": border,
		"outline": outline,
		"k_lines": klines
	}


func export() -> void:
	# Path where the .plt file will be written
	var temp_gnu_path = "user://band_plot.gnu"
	var file = FileAccess.open(temp_gnu_path, FileAccess.WRITE)
	var data := serialize()
	file.store_string(BandPlotter.generate_gnu(data))
	file.close()
	var g4v_file := file_path_edit.text.get_base_dir().path_join(titlebar.text + ".g4v")
	file = FileAccess.open(g4v_file, FileAccess.WRITE)
	file.store_string(var_to_str(data))
	file.close()

	# Execute gnuplot with the .plt file
	# (Note: "user://" maps to the app's writable directory, so we get absolute path)
	var abs_path = ProjectSettings.globalize_path(temp_gnu_path)
	var exit_code = OS.execute("gnuplot", [abs_path], [], true)
	print("gnuplot exited with code: ", exit_code)


func update_available_font_names() -> void:
	var system_fonts := OS.get_system_fonts()
	system_fonts.sort()
	for system_font_name in system_fonts:
		if system_font_name in font_names:
			continue
		font_names.add_item(system_font_name)


func _on_new_line_pressed() -> void:
	var new_line := preload("res://src/UI/Nodes/plot_node.tscn").instantiate()
	plot_info.add_child(new_line)


func _on_update_pressed() -> void:
	export()


func find_band_gap_file():
	var file_path = open_dialog.current_dir.path_join("BAND.dat")
	var label_path = open_dialog.current_dir.path_join("KLABELS")
	# Do one last failsafe to see everything is in order
	if FileAccess.file_exists(file_path):
		open_dialog.current_file = file_path
		file_path_edit.text = file_path
		# Get Labels
		if FileAccess.file_exists(label_path):
			var file := FileAccess.open(label_path, FileAccess.READ)
			if FileAccess.get_open_error() == OK:
				while not file.eof_reached():
					var line := file.get_line()
					if line.begins_with(" ") and line.strip_edges() != "":
						var k_line := line.split(" ", false)
						if k_line.size() == 2:
							var kline_node := preload("res://src/UI/Nodes/kline.tscn").instantiate()
							k_line_container.add_child(kline_node)
							kline_node.derialize({"distance": k_line[1], "label": k_line[0]})


func _on_open_dialog_file_selected(path: String) -> void:
	if path.get_extension() == "g4v":
		pass


func _on_new_k_line_pressed() -> void:
	var kline_node := preload("res://src/UI/Nodes/kline.tscn").instantiate()
	k_line_container.add_child(kline_node)
