extends Node

var stella_extension := "stella"
var template_dir := "user://templates"

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

@onready var legend_vertical: OptionButton = %LegendVertical
@onready var legend_horizontal: OptionButton = %LegendHorizontal
@onready var use_box: CheckBox = %UseBox
@onready var box_options: HBoxContainer = %BoxOptions
@onready var legend_box_outline: ValueSlider = %LegendBoxOutline
@onready var legend_box_spacing: ValueSlider = %LegendBoxSpacing


@onready var size_slider: ValueSliderV2 = %SizeSlider
@onready var scale_slider: ValueSliderV2 = %ScaleSlider
@onready var border_outline_slider: ValueSliderV2 = %BorderOutlineSlider

@onready var open_dialog := $Dialogs/OpenDialog


class CLI:
	static var args_list := {
		["-v", "--version"]: [CLI.print_version, "Prints current parser version"],
		["--config"]: [CLI.load_stella, "Loads the stella file to plot"],
		["-pdf"]: [CLI.use_pdf, "Sets the export mode (uses png when disabled)"],
		["-e"]: [CLI.quick_export, "Immediately exports the loaded file"],
		["--help", "-h", "-?"]: [CLI.generate_help, "Displays this help page"]
	}

	static func generate_help(_next_arg: String, option_node):
		var help := str(
			(
				"""
=========================================================================\n
Help for stella's CLI.

Usage:
\t%s [SYSTEM OPTIONS] -- [USER OPTIONS] [FILES]...

Use -h in place of [SYSTEM OPTIONS] to see [SYSTEM OPTIONS].
Or use -h in place of [USER OPTIONS] to see [USER OPTIONS].

some useful [SYSTEM OPTIONS] are:
--headless     Run in headless mode.
--quit         Close pixelorama after current command.


[USER OPTIONS]:\n
(The terms in [ ] reflect the valid type for corresponding argument).

"""
				% OS.get_executable_path().get_file()
			)
		)
		for command_group: Array in args_list.keys():
			help += str(
				var_to_str(command_group).replace("[", "").replace("]", "").replace('"', ""),
				"\t\t".c_unescape(),
				args_list[command_group][1],
				"\n".c_unescape()
			)
		help += "========================================================================="
		option_node.debug_funny("I need serious help", "")
		option_node.debug_funny("Sure, here you go :)")
		print(help)

	## Dedicated place for command line args callables
	static func print_version(_next_arg: String, option_node) -> void:
		option_node.debug_funny(
			"What!?, you wish to know my age? well.. i'm currently %s"
			% ProjectSettings.get("application/config/version")
		)

	static func use_pdf(_next_arg: String, option_node) -> void:
		option_node.png_button.button_pressed = false


	static func load_stella(next_arg: String, option_node) -> void:
		var stella_file_path = option_node.open_dialog.current_dir.path_join(next_arg)
		if FileAccess.file_exists(stella_file_path):
			option_node.debug_funny("loading configuration from %s" % next_arg)
			var open_file := FileAccess.open(stella_file_path, FileAccess.READ)
			if FileAccess.get_open_error() == OK:
				var data_str := open_file.get_as_text()
				open_file.close()
				var data = str_to_var(data_str)
				if typeof(data) == TYPE_DICTIONARY:
					option_node.load_settings(data)
					# exception only gifted to CLI
					var output_path: String = data.get("output_plot_name", "OUTPUT.pdf")
					var file = output_path.get_file().split(".")[0]
					option_node.debug_funny("Okay, i've also set the file title to %s" % file)
					option_node.titlebar.text = file


	static func quick_export(_next_arg: String, option_node) -> void:
		option_node.debug_funny("Hy, ah, i don't have much time, can export this real quick?", "")
		option_node.debug_funny("Sure, give me a moment to look at the data")
		option_node.export()


func _exit_tree() -> void:
	debug_funny("Okay, got to go now... take care (waves hand). Bye!")

func _ready():
	var logo = (
"""
#       ____  _       _ _
#      / ___|| |_ ___| | | __ _
#      \\___ \\| __/ _ \\ | |/ _` |
#       ___) | ||  __/ | | (_| |
#      |____/ \\__\\___|_|_|\\__,_|
""")
	print(logo.replace("#", ""))
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
	find_data_files()
	debug_funny("Hy, i'm Stella how may i help you today?")
	_handle_cmdline_arguments()
	if file_path_edit.text == "":
		open_dialog.popup_centered()


func debug_funny(message, person := "Stella"):
	if person == "":
		if OS.has_environment("USER"):
			person = OS.get_environment("USER").capitalize()
		else:
			person = "User"
	print(person, ":        ", message)


func _handle_cmdline_arguments() -> void:
	var args := OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	if args.is_empty():
		return

	# crreate a link of arg with callable
	var parse_dic := {}
	for command_group: Array in CLI.args_list.keys():
		for command: String in command_group:
			parse_dic[command] = CLI.args_list[command_group][0]
	for i in args.size():  # Handle the rest of the CLI arguments
		var arg := args[i]
		var next_argument := ""
		if i + 1 < args.size():
			next_argument = args[i + 1]
		if arg.begins_with("-") or arg.begins_with("--"):
			if arg in parse_dic.keys():
				var callable: Callable = parse_dic[arg]
				callable.call(next_argument, self)
			else:
				print("==========")
				print("Unknown option: %s" % arg)
				for compare_arg in parse_dic.keys():
					if arg.similarity(compare_arg) >= 0.4:
						print("Similar option: %s" % compare_arg)
				print("==========")
				break


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
	if plot_format == ".pdf":
		debug_funny("Okay..., you wish to use pdf, not my personal prefference but sure")
	var output_plot_name: String = data_file_path.get_base_dir().path_join(title + plot_format)
	var border: float = border_outline_slider.value.x
	var outline: float = border_outline_slider.value.y
	var plot_lines: Array[Dictionary] = []
	for line in plot_info.get_children():
		if line is PlotLine and not line.is_queued_for_deletion():
			plot_lines.append(line.serialize())
	var klines := {}
	for kline in k_line_container.get_children():
		if kline is KLine:
			klines.merge(kline.serialize())
	
	# Access the legend configuration
	var legend_setting := {}
	var horiz := legend_horizontal.get_item_text(legend_horizontal.selected)
	var vert := legend_vertical.get_item_text(legend_vertical.selected)
	legend_setting["align_v"] = vert
	legend_setting["align_h"] = horiz
	if use_box.button_pressed:
		legend_setting["use_box"] = true
		legend_setting["outline"] = legend_box_outline.value
		legend_setting["spacing"] = legend_box_spacing.value
	
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
		"k_lines": klines,
		"legend_config": legend_setting
	}


func export() -> void:
	# Path where the .plt file will be written
	var temp_gnu_path = file_path_edit.text.get_base_dir().path_join("PLOTSCRIPT.gnu")
	var file = FileAccess.open(temp_gnu_path, FileAccess.WRITE)
	var data := serialize()
	file.store_string(BandPlotter.generate_gnu(data))
	file.close()
	var stella_file := file_path_edit.text.get_base_dir().path_join("LASTPLOT.%s" % stella_extension)
	file = FileAccess.open(stella_file, FileAccess.WRITE)
	file.store_string(var_to_str(data))
	file.close()
	if file_path_edit.text.strip_edges():
		var template_name := file_path_edit.text.strip_edges().get_file().get_slice(".", 0)
		var template_path := template_dir.path_join(template_name + ".%s" % stella_extension)
		file = FileAccess.open(template_path, FileAccess.WRITE)
		file.store_string(var_to_str(data))
		file.close()

	# Execute gnuplot with the .plt file
	# (Note: "user://" maps to the app's writable directory, so we get absolute path)
	var abs_path = ProjectSettings.globalize_path(temp_gnu_path)
	var exit_code = OS.execute("gnuplot", [abs_path], [], true)
	if exit_code == OK:
		debug_funny("And Done! your graph is ready!")
	else:
		debug_funny("Ouch! gnuplot says the data has an error %s" % str(exit_code))


func load_settings(data: Dictionary) -> void:
	debug_funny("I see you have some settings from your last request. I'll set them for you :)")
	if file_path_edit.text == "":
		var data_file_path: String = data.get("data_file_path", "")
		if FileAccess.file_exists(data_file_path):
			file_path_edit.text = data_file_path
	var plot_lines: Array[Dictionary] = data.get("plot_lines", [])
	var title: String = data.get("title", titlebar.text)
	var x_label: String = data.get("x_label", "")
	var y_label: String = data.get("y_label", "")
	var size_value: Vector2 = data.get("size_value", Vector2(5.0, 6.0))
	var scale_value: Vector2 = data.get("scale_value", Vector2.ONE)
	var x_range: Vector2 = data.get("x_range", Vector2(0, 0))
	var y_range: Vector2 = data.get("y_range", Vector2(-2, 2))
	var output_plot_name: String = data.get("output_plot_name", "OUTPUT.pdf")
	var border: float = data.get("border", 15)
	var outline: float = data.get("outline", 2.5)
	var legend_setting: Dictionary = data.get("legend_config", {})
	# Set legend options
	var legend_v =  legend_setting.get("align_v", "top")
	var legend_h =  legend_setting.get("align_h", "right")
	for i in legend_horizontal.item_count:
		if legend_horizontal.get_item_text(i) == legend_h:
			legend_horizontal.select(i)
			break
	for i in legend_vertical.item_count:
		if legend_vertical.get_item_text(i) == legend_v:
			legend_vertical.select(i)
			break
	use_box.button_pressed = legend_setting.get("use_box", use_box.button_pressed)
	legend_box_outline.value = legend_setting.get("use_box", legend_box_outline.value)
	legend_box_spacing.value = legend_setting.get("spacing", legend_box_outline.value)

	for plot_line in plot_info.get_children():
		plot_line.queue_free()
	for plot_line in plot_lines:
		var new_line: PlotLine = preload("res://src/UI/Nodes/plot_node.tscn").instantiate()
		plot_info.add_child(new_line)
		new_line.deserialize(plot_line)
	titlebar.text = title
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
	var new_line: PlotLine = preload("res://src/UI/Nodes/plot_node.tscn").instantiate()
	var extrapolate := Vector2i.ZERO
	var should_extrapolate := false
	if plot_info.get_child_count() >= 2:
		should_extrapolate = true
		var last_line: PlotLine = plot_info.get_child(plot_info.get_child_count() - 1)
		var prev_line: PlotLine = plot_info.get_child(plot_info.get_child_count() - 2)
		extrapolate = Vector2i(2 * last_line.columns.value - prev_line.columns.value)
	plot_info.add_child(new_line)
	if should_extrapolate:
		new_line.columns.value = extrapolate
	
	var golden_angle := 137.508  # degrees — ensures uniform hue spacing
	var saturation := 0.6        # balanced saturation (0–1)
	var value := 0.9             # bright but not pure white

	var hue := fmod(plot_info.get_child_count() * golden_angle, 360.0) / 360.0
	new_line.color_picker_button.color = Color.from_hsv(hue, saturation, value)


func _on_update_pressed() -> void:
	debug_funny("Can you update this plot real quick", "")
	debug_funny("Sure, give me a moment to look at the data")
	export()


func get_template_files() -> Dictionary:
	var templates := {}
	# Make a template directory
	var abs_template_dir := ProjectSettings.globalize_path(template_dir)
	if not DirAccess.dir_exists_absolute(abs_template_dir):
		DirAccess.make_dir_recursive_absolute(abs_template_dir)
	# Check template files
	var dir = DirAccess.open(abs_template_dir)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				if file_name.get_extension() == stella_extension:
					templates[file_name.get_slice(".", 0)] = abs_template_dir.path_join(file_name)
			file_name = dir.get_next()
	else:
		print("An error occurred when trying to access the path.")
	return templates


func find_data_files():
	var band_file_path = open_dialog.current_dir.path_join("BAND.dat")
	var dos_file_path = open_dialog.current_dir.path_join("TDOS.dat")
	var label_path = open_dialog.current_dir.path_join("KLABELS")
	var stella_loaded := false
	# Do one last failsafe to see everything is in order
	if FileAccess.file_exists(band_file_path):
		open_dialog.current_file = band_file_path
		file_path_edit.text = band_file_path
		# Get Labels
		get_klabels(label_path)
	elif FileAccess.file_exists(dos_file_path):
		if not stella_loaded:
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
			debug_funny("I see that the file has labels as well, loading them")
			while not file.eof_reached():
				var line := file.get_line()
				if line.begins_with(" ") and line.strip_edges() != "":
					var k_line := line.split(" ", false)
					if k_line.size() == 2:
						debug_funny(line)
						var kline_node := preload("res://src/UI/Nodes/kline.tscn").instantiate()
						k_line_container.add_child(kline_node)
						kline_node.derialize({"distance": k_line[1], "label": k_line[0]})


func _on_open_dialog_file_selected(path: String) -> void:
	if path.get_extension() == stella_extension:
		var open_file := FileAccess.open(path, FileAccess.READ)
		if FileAccess.get_open_error() == OK:
			var data_str := open_file.get_as_text()
			open_file.close()
			var data = str_to_var(data_str)
			if typeof(data) == TYPE_DICTIONARY:
				load_settings(data)
	if path.get_extension() == "dat":
		debug_funny("Please load the file %s" % path, "")
		file_path_edit.text = path
		var label_path = open_dialog.current_dir.path_join("KLABELS")
		debug_funny("Sure")
		get_klabels(label_path)
		var templates := get_template_files()
		var template_key := path.get_file().get_slice(".", 0)
		if templates.has(template_key):
			debug_funny("I see that there is a template for %s as well, i'll load it too" % template_key)
			var open_file := FileAccess.open(templates[template_key], FileAccess.READ)
			if FileAccess.get_open_error() == OK:
				var data_str := open_file.get_as_text()
				open_file.close()
				var data = str_to_var(data_str)
				if typeof(data) == TYPE_DICTIONARY:
					load_settings(data)


func _on_new_k_line_pressed() -> void:
	var kline_node := preload("res://src/UI/Nodes/kline.tscn").instantiate()
	k_line_container.add_child(kline_node)


func _on_open_button_pressed() -> void:
	open_dialog.popup_centered()


func _on_use_box_toggled(toggled_on: bool) -> void:
	box_options.visible = toggled_on
