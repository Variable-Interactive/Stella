extends Node

@onready var file_path_edit: LineEdit = %FilePath
@onready var font_names: OptionButton = %FontNames
@onready var font_size_slider: ValueSlider = %FontSize
@onready var titlebar: LineEdit = %Titlebar
@onready var x_label_edit: LineEdit = %XLabel
@onready var y_label_edit: LineEdit = %YLabel
@onready var range_slider_x: ValueSliderV2 = %RangeSliderX
@onready var range_slider_y: ValueSliderV2 = %RangeSliderY
@onready var plot_info: VBoxContainer = %PlotInfo
@onready var k_line_container: VBoxContainer = %KLineContainer
@onready var png_button: CheckButton = %PngButton


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
	var x_label: String = x_label_edit.text
	var y_label: String = y_label_edit.text
	var font: String = font_names.get_item_text(font_names.selected)
	@warning_ignore("narrowing_conversion")
	var font_size: int = font_size_slider.value
	var size_value: Vector2 = size_slider.value
	var scale_value: Vector2 = scale_slider.value
	var x_range: Vector2 = range_slider_x.value
	var y_range: Vector2 = range_slider_y.value
	var plot_format := ".png" if png_button.button_pressed else ".pdf"
	var output_plot_name: String = data_file_path.get_base_dir().path_join(title + plot_format)
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
		"x_range": x_range,
		"y_range": y_range,
		"output_plot_name": output_plot_name,
		"border": border,
		"outline": outline,
		"k_lines": klines
	}


func export() -> void:
	# Path where the .plt file will be written
	var temp_gnu_path = file_path_edit.text.get_base_dir().path_join("PLOTSCRIPT.gnu")
	var file = FileAccess.open(temp_gnu_path, FileAccess.WRITE)
	var data := serialize()
	file.store_string(BandPlotter.generate_gnu(data))
	file.close()
	var stella_file := file_path_edit.text.get_base_dir().path_join("LASTPLOT.stella")
	file = FileAccess.open(stella_file, FileAccess.WRITE)
	file.store_string(var_to_str(data))
	file.close()

	# Execute gnuplot with the .plt file
	# (Note: "user://" maps to the app's writable directory, so we get absolute path)
	var abs_path = ProjectSettings.globalize_path(temp_gnu_path)
	var exit_code = OS.execute("gnuplot", [abs_path], [], true)
	print("gnuplot exited with code: ", exit_code)


func load_settings(data: Dictionary) -> void:
	var plot_lines: Array[Dictionary] = data.get("plot_lines", [])
	var x_label: String = data.get("x_label", "")
	var y_label: String = data.get("y_label", "")
	var size_value: Vector2 = data.get("size_value", Vector2(5.0, 6.0))
	var scale_value: Vector2 = data.get("scale_value", Vector2.ONE)
	var x_range: Vector2 = data.get("x_range", Vector2(0, 0))
	var y_range: Vector2 = data.get("y_range", Vector2(-2, 2))
	var output_plot_name: String = data.get("output_plot_name", "OUTPUT.pdf")
	var border: float = data.get("border", 15)
	var outline: float = data.get("outline", 2.5)
	for plot_line in plot_info.get_children():
		plot_line.queue_free()
	for plot_line in plot_lines:
		var new_line: PlotLine = preload("res://src/UI/Nodes/plot_node.tscn").instantiate()
		new_line.deserialize(plot_line)
		plot_info.add_child(new_line)
	x_label_edit.text = x_label
	y_label_edit.text = y_label
	size_slider.value = size_value
	scale_slider.value = scale_value
	range_slider_x.value = x_range
	range_slider_y.value = y_range
	png_button.button_pressed = (
		true if output_plot_name.get_extension().to_lower() == "png" else false
	)
	border_outline_slider.value = Vector2(border, outline)



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
	var band_file_path = open_dialog.current_dir.path_join("BAND.dat")
	var dos_file_path = open_dialog.current_dir.path_join("TDOS.dat")
	var stella_file_path = open_dialog.current_dir.path_join("LASTPLOT.stella")
	var label_path = open_dialog.current_dir.path_join("KLABELS")
	# Do one last failsafe to see everything is in order
	if FileAccess.file_exists(stella_file_path):
		var open_file := FileAccess.open(stella_file_path, FileAccess.READ)
		if FileAccess.get_open_error() == OK:
			var data_str := open_file.get_as_text()
			open_file.close()
			var data = str_to_var(data_str)
			if typeof(data) == TYPE_DICTIONARY:
				load_settings(data)
	if FileAccess.file_exists(band_file_path):
		open_dialog.current_file = band_file_path
		file_path_edit.text = band_file_path
		# Get Labels
		get_klabels(label_path)
	elif FileAccess.file_exists(dos_file_path):
		titlebar.text = "Total Density of State"
		x_label_edit.text = "E - E_f (eV)"
		y_label_edit.text = "DOS"
		open_dialog.current_file = dos_file_path
		file_path_edit.text = dos_file_path


func get_klabels(label_path: String):
	for node in k_line_container.get_children():
		if node is KLine:
			node.queue_free()
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
	if path.get_extension() == "stella":
		var open_file := FileAccess.open(path, FileAccess.READ)
		if FileAccess.get_open_error() == OK:
			var data_str := open_file.get_as_text()
			open_file.close()
			var data = str_to_var(data_str)
			if typeof(data) == TYPE_DICTIONARY:
				load_settings(data)
	if path.get_extension() == "dat":
		file_path_edit.text = path
		var label_path = open_dialog.current_dir.path_join("KLABELS")
		get_klabels(label_path)


func _on_new_k_line_pressed() -> void:
	var kline_node := preload("res://src/UI/Nodes/kline.tscn").instantiate()
	k_line_container.add_child(kline_node)


func _on_open_button_pressed() -> void:
	open_dialog.popup_centered()
