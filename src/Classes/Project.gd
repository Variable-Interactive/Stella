class_name Project
extends RefCounted

enum LegendAlign { ABOVE, TOP, CENTER, BOTTOM, BELOW, RIGHT, LEFT }

const alignment_string: Dictionary[LegendAlign, String] = {
	LegendAlign.ABOVE: "above",
	LegendAlign.TOP: "top",
	LegendAlign.CENTER: "center",
	LegendAlign.BOTTOM: "bottom",
	LegendAlign.BELOW: "below",
	LegendAlign.RIGHT: "right",
	LegendAlign.LEFT: "left",
}

var font_priorities := ["Helvetica", "TeX Gyre Heros", "Roboto"]
# General Properties
var project_name := "untitled":
	set(value):
		project_name = value
		var project_index := Global.projects.find(self)
		if project_index < Global.tabs.tab_count and project_index > -1:
			Global.tabs.set_tab_title(project_index, project_name)
var graph_title := ""
var last_save_path := ""
var x_label: String = ""
var y_label: String = ""
var font_name: String = ""
var font_bold: bool = true
var fallback_font_size: int = 12
var font_color :=Color.BLACK
var border_mode: float = 15
var border_width: float = 2.5
var border_color :=Color.BLACK
var background_color := Color.WHITE
var graph_size := Vector2(8.27, 8.27)
var graph_scale := Vector2.ONE
var full_range: bool = false
var x_range_min: float = -50
var x_range_max: float = 50
var y_range_min: float = -50
var y_range_max: float = 50

# Guides
var show_zero_axis := false
var hide_x_axis := false

# Legend
var legend_enabled := true
var legend_vertical := LegendAlign.TOP
var legend_horizontal := LegendAlign.RIGHT
var reverse_legend := false
var use_box := true
var legend_box_outline: float = 1.2
var legend_box_spacing: float = 1.2

var k_lines: Array[KLine] = []
var data_files: Array[DataFile] = []

# properties needed only while project is loaded up
var is_empty := true
var has_changed := false:
	set(value):
		has_changed = value
		if value:
			Global.tabs.set_tab_title(Global.tabs.current_tab, project_name + "(*)")
		else:
			Global.tabs.set_tab_title(Global.tabs.current_tab, project_name)
var last_render: Image
var size: Vector2i:
	get():
		if last_render: return last_render.get_size()
		return Vector2i.ZERO
## For every camera (currently there is 1)
var cameras_zoom: PackedVector2Array = [Vector2(0.15, 0.15)]
var cameras_offset: PackedVector2Array = [Vector2.ZERO]

class KLine:
	var label: String = ""
	var distance: float = 0

	func _init(k_label := "", k_distance := 0.0) -> void:
		label = k_label
		distance = k_distance
		if k_label.to_lower() == "g":
			k_label = "{/Symbol %s}" % k_label

	func serialize() -> Dictionary[float, String]:
		return {distance : label}


class DataFile:
	var file_path_local: String = ""  # Max Priority
	var file_path: String = ""  # Fallback
	var data_label: String = ""
	var plot_lines: Array[PlotData] = []
	var parent_project: Project

	class PlotData:
		const LINE_MODES: Array[Dictionary] = [
			{"Lines" : "lines"},
			{"Connected Line (Fisheye)" : "linespoints pt '◉' pi '-1'"},
			{"Connected Line (Circle)" : "linespoints pt 'o' pi '-1'"},
			{"Connected Line (Cross)": "linesp"},
			{"Fisheye" : "points pt '◉'"},
			{"Circle" : "points pt 'o'"},
			{"Cross" : "points"},
			{"Dots" : "dots"},
			{"Filled Curve" : "filledcurve"},
			{"Boxes" : "boxes"},
		]
		var _birch_update_queued = false
		var title: String = "Data Plot"
		var line_type: int = 0
		var width: float = 2
		var x_column: int = 1
		var y_column: int = 2
		var color := Color.GRAY
		var parent_data_file: DataFile
		# Birch settings
		var birch_enabled := false
		var birch_data_width: float = 3.0:
			set(value):
				birch_data_width = value
				_queue_update_birch()
		var primitive_cels: int = 1:
			set(value):
				primitive_cels = value
		var birch_lattice: float = 1:
			set(value):
				birch_lattice = value
				_queue_update_birch()
		var birch_energy: float = -100:
			set(value):
				birch_energy = value
				_queue_update_birch()
		var birch_modulo: float = 0.2:
			set(value):
				birch_modulo = value
				_queue_update_birch()
		var birch_modulo_prime: float = 0:
			set(value):
				birch_modulo_prime = value
				_queue_update_birch()
		var birch_prediction_data: String = ""
		var visible: bool = true
		var show_in_legend: bool = true

		func _init(data_file: DataFile, line_index: int = 0) -> void:
			parent_data_file = data_file
			var golden_angle := 137.508  # degrees — ensures uniform hue spacing
			var saturation := 0.6        # balanced saturation (0–1)
			var value := 0.9             # bright but not pure white
			var hue := fmod(line_index * golden_angle, 360.0) / 360.0
			color = Color.from_hsv(hue, saturation, value)

		func _queue_update_birch() -> void:
			if birch_enabled and not _birch_update_queued:
				call_deferred("_update_birch")
				_birch_update_queued = true

		func _update_birch():
			_birch_update_queued = false
			birch_prediction_data = BirchMurnaghan.generate_trial_data(
				birch_lattice,
				birch_energy,
				birch_modulo,
				birch_modulo_prime,
				birch_data_width,
				1  # In Editor view will always use i primitive cel per conventional cel.
			)

		func try_auto_fit_birch(itterations: int) -> void:
			if not parent_data_file:
				return
			parent_data_file.sync_local_global_paths()
			var file_path := parent_data_file.file_path.strip_edges()
			if file_path.is_empty():
				return
			if not FileAccess.file_exists(file_path):
				return
			var file := FileAccess.open(file_path, FileAccess.READ)
			if FileAccess.get_open_error() != OK:
				return
			var energies := []
			var latices := []
			while not file.eof_reached():
				var line := file.get_line()
				if line.strip_edges() != "":
					var info_array := line.split(",", false)
					if info_array.size() >= 2:
						var energy_value_str := info_array[-1].strip_edges()
						var lattice_value_str := info_array[-2].strip_edges()
						energies.append(Project.parse_scientific(energy_value_str))
						latices.append(float(lattice_value_str))
			var old_best_params := [birch_energy, birch_lattice, birch_modulo, birch_modulo_prime]
			var fitted_data := BirchMurnaghan.fit_birch(
				latices, energies, itterations, old_best_params
			)
			# Avoid emitting signal multiple times
			var old_birch_queue = _birch_update_queued
			_birch_update_queued = true
			birch_energy = fitted_data["ground_energy"]
			birch_lattice = fitted_data["optimum_lattice"]
			birch_modulo = fitted_data["bulk_modulo"]
			birch_modulo_prime = fitted_data["bulk_modulo_prime"]
			_birch_update_queued = old_birch_queue
			_update_birch()
			Global.update_plot.emit()

		func serialize() -> Dictionary:
			# Birch values
			var data := {}
			if birch_enabled:
				data.merge(
					{
						"birch_enabled": birch_enabled,
						"birch_lattice": birch_lattice,
						"primitive_cels": primitive_cels,
						"birch_energy": birch_energy,
						"birch_modulo": birch_modulo,
						"birch_modulo_prime": birch_modulo_prime,
						"birch_data_width": birch_data_width,
						"birch_prediction_data": birch_prediction_data,
					}
				)
			return data.merged(
				{
					"title": title,
					"line_type": line_type,
					"width": width,
					"x_column": x_column,
					"y_column": y_column,
					"color": color,
					"visible": visible,
					"show_in_legend": show_in_legend,
				}
			)

		func deserialize(data: Dictionary) -> void:
			title = data.get("title", title)
			var modes := []
			for i in LINE_MODES.size():
				modes.append(LINE_MODES[i].values()[0])
			line_type = data.get("line_type", line_type)
			width = data.get("width", width)
			x_column = data.get("x_column", x_column)
			y_column = data.get("y_column", y_column)
			color = data.get("color", color)
			visible = data.get("visible", visible)
			show_in_legend = data.get("show_in_legend", show_in_legend)

			birch_enabled = data.get("birch_enabled", birch_enabled)
			birch_lattice = data.get("birch_lattice", birch_lattice)
			primitive_cels = data.get("primitive_cels", primitive_cels)
			birch_energy = data.get("birch_energy", birch_energy)
			birch_modulo = data.get("birch_modulo", birch_modulo)
			birch_modulo_prime = data.get("birch_modulo_prime", birch_modulo_prime)
			birch_data_width = data.get("birch_data_width", birch_data_width)
			_update_birch()

	func _init(
		project: Project, f_path: String = "", label = "", lines: Array[PlotData] = []
	) -> void:
		parent_project = project
		file_path = f_path
		data_label = label
		if data_label.is_empty():
			data_label = file_path.get_file().trim_prefix(file_path.get_extension())
		plot_lines = lines

	func sync_local_global_paths() -> bool:
		var project_path := parent_project.last_save_path
		if not project_path.is_empty():
			# If Local path is valid, change the global path
			var local_to_global := project_path.get_base_dir().path_join(file_path_local)
			if FileAccess.file_exists(local_to_global):
				if file_path != local_to_global.simplify_path():
					file_path = local_to_global.simplify_path()
					return true
			elif FileAccess.file_exists(file_path):
				Global.debug_funny(
					"Failed to find [color=orange]{local_path}[/color], Defaulting to [color=orange]{global_path}[/color]"
					.format({"local_path": file_path_local, "global_path": file_path})
				)
				Global.debug_funny("Please make a data file at: [color=orange]%s[/color]" % local_to_global)
				file_path_local = OpenSave.get_relative_path(project_path, file_path)
		else:
			file_path_local = ""
		return false

	func deserialize(data: Dictionary) -> void:
		file_path = data.get("file_path", file_path)
		file_path_local = data.get("file_path_local", file_path_local)
		data_label = data.get("data_label", data_label)
		if data_label.is_empty():
			data_label = file_path.get_file().trim_prefix(file_path.get_extension())
		var plot_lines_data: Array[Dictionary] = data.get("plot_lines", [])
		var file_path_changed := sync_local_global_paths()
		for plot_data in plot_lines_data:
			var plot_line := PlotData.new(self)
			plot_line.deserialize(plot_data)
			if file_path_changed and plot_line.birch_enabled:
				Global.debug_funny(
					"Refreshing Birch data of %s > %s" % [
						data_label, plot_line.title
					]
				)
				plot_line.try_auto_fit_birch(2329)
			plot_lines.append(plot_line)

	func serialize() -> Dictionary:
		sync_local_global_paths()
		var plot_lines_data: Array[Dictionary] = []
		for plot_line: PlotData in plot_lines:
			plot_lines_data.append(plot_line.serialize())
		return {
			"file_path": file_path,
			"file_path_local": file_path_local,
			"data_label": data_label,
			"plot_lines": plot_lines_data
		}


func _init(load_path: String = last_save_path, load_data: Dictionary = {}) -> void:
	last_save_path = load_path
	if not last_render:
		last_render = Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
		last_render.fill(Color.WHITE)
	if not load_data.is_empty():
		deserialize(load_data)
	var system_fonts := OS.get_system_fonts()
	for best_font in font_priorities:
		if system_fonts.has(best_font):
			font_name = best_font
			break
	Global.tabs.add_tab(project_name)


static func parse_scientific(s: String) -> float:
	s = s.strip_edges()
	if s.begins_with("-."):
		s = "-0" + s.substr(1)
	elif s.begins_with("."):
		s = "0" + s
	return float(s)


func serialize() -> Dictionary:
	if not FileAccess.file_exists(last_save_path):
		last_save_path = ""
	var kline_data: Dictionary[float, String] = {}
	for kline in k_lines:
		kline_data.merge(kline.serialize(), true)

	var data_files_array: Array[Dictionary] = []
	for dat_file: DataFile in data_files:
		dat_file.sync_local_global_paths()
		data_files_array.append(dat_file.serialize())

	var data := {
		# General Properties
		"last_save_path": last_save_path,
		"graph_title": graph_title,
		"x_label": x_label,
		"y_label": y_label,
		"font_name": font_name,
		"font_bold": font_bold,
		"fallback_font_size": fallback_font_size,
		"font_color": font_color,
		"border_mode": border_mode,
		"border_width": border_width,
		"border_color": border_color,
		"background_color": background_color,
		"graph_size": graph_size,
		"graph_scale": graph_scale,
		"show_zero_axis": show_zero_axis,
		"hide_x_axis": hide_x_axis,
		"full_range": full_range,
		"x_range_min": x_range_min,
		"x_range_max": x_range_max,
		"y_range_min": y_range_min,
		"y_range_max": y_range_max,
		"data_files": data_files_array,
		"k_lines": kline_data,
		"legend_enabled": legend_enabled,
		"legend_vertical": legend_vertical,
		"legend_horizontal": legend_horizontal,
		"reverse_legend": reverse_legend,
		"use_box": use_box,
		"legend_box_outline": legend_box_outline,
		"legend_box_spacing": legend_box_spacing,
	}
	return data


func deserialize(data: Dictionary) -> void:
	graph_title = data.get("graph_title", graph_title)
	x_label = data.get("x_label", x_label)
	y_label = data.get("y_label", y_label)
	font_name = data.get("font_name", font_name)
	font_bold = data.get("font_bold", font_bold)
	fallback_font_size = data.get("fallback_font_size", fallback_font_size)
	font_color = data.get("font_color", font_color)
	border_mode = data.get("border_mode", border_mode)
	border_width = data.get("border_width", border_width)
	border_color = data.get("border_color", border_color)
	background_color = data.get("background_color", background_color)
	graph_size = data.get("graph_size", graph_size)
	graph_scale = data.get("graph_scale", graph_scale)
	show_zero_axis = data.get("show_zero_axis", show_zero_axis)
	hide_x_axis = data.get("hide_x_axis", hide_x_axis)
	full_range = data.get("full_range", full_range)
	x_range_min = data.get("x_range_min", x_range_min)
	x_range_max = data.get("x_range_max", x_range_max)
	y_range_min = data.get("y_range_min", y_range_min)
	y_range_max = data.get("y_range_max", y_range_max)
	legend_vertical = data.get("legend_vertical", legend_vertical)
	legend_horizontal = data.get("legend_horizontal", legend_horizontal)
	reverse_legend = data.get("reverse_legend", reverse_legend)
	use_box = data.get("use_box", use_box)
	legend_box_outline = data.get("legend_box_outline", legend_box_outline)
	legend_box_spacing = data.get("legend_box_spacing", legend_box_spacing)

	var kline_data: Dictionary[float, String] = data.get("k_lines", {})
	for kline_distance in kline_data.keys():
		k_lines.append(KLine.new(kline_data[kline_distance], kline_distance))
	Global.kline_list_updated.emit()

	var data_files_array: Array[Dictionary] = data.get("data_files", [])
	for dat_file_dict: Dictionary in data_files_array:
		var dat_file := DataFile.new(self)
		dat_file.deserialize(dat_file_dict)
		data_files.append(dat_file)
	Global.data_files_updated.emit()
	is_empty = false
