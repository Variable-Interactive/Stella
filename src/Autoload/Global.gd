extends Node

signal update_plot
signal project_switched
signal data_files_updated
signal kline_list_updated

## The file path used for the [member config_cache] file.
const CONFIG_PATH := "user://config.ini"
const CACHE_DIR = "user://cache"

var _graph_update_qued := false

var projects: Array[Project] = []
var current_project_index: int = -1:
	set(value):
		current_project_index = value
		project_switched.emit()
var can_draw := true
var data_file_to_update: Project.DataFile

var fast_generate_mode := false
var base64_installed := false
var convert_installed := false

## The config file used to get/set preferences, tool settings etc.
var config_cache := ConfigFile.new()

# prefferences
var cross_cursor := true
var smooth_zoom := true
var integer_zoom := false
var camera_updates_range := true
var visual_format := OpenSave.Format.PNG:
	set(value):
		visual_format = value
		render_current_project_graph()
var open_gnuplotter := false
var gnu_button_press_timeout: int = 0

@onready var control := get_tree().current_scene as Control
## The project tabs bar. It has the [param Tabs.gd] script attached.
@onready var tabs: TabBar = control.find_child("TabBar")
@onready var canvas := control.find_child("Canvas") as Canvas
@onready var sprite := control.find_child("Sprite2D") as Sprite2D
@onready var data_tree = control.find_child("DataTreeContainer") as PanelContainer
@onready var properties_container = control.find_child("PropertiesContainer") as PanelContainer
@onready var kline_list = control.find_child("KlinesList") as PanelContainer
@onready var log_text_label := control.find_child("LogText") as RichTextLabel
@onready var import_data_dialog := control.find_child("ImportDataDialog") as FileDialog
@onready var klables_import_confirm: ConfirmationDialog = control.find_child("KlablesImportConfirmation")


func _init() -> void:
	# Load settings from the config file
	config_cache.load(CONFIG_PATH)


func _ready() -> void:
	call_deferred("load_preffeernces")
	var cache_folder := ProjectSettings.globalize_path(CACHE_DIR)
	if DirAccess.dir_exists_absolute(cache_folder):
		for file in DirAccess.get_files_at(cache_folder):
			DirAccess.remove_absolute(cache_folder.path_join(file))
	else:
		DirAccess.make_dir_recursive_absolute(cache_folder)
	# Boolean variable setting
	fast_generate_mode = _is_fast_generate_possible()
	base64_installed = _is_base64_installed()
	convert_installed = _is_convert_installed()
	Global.import_data_dialog.current_path = OS.get_executable_path()

	# Make initial empty project
	projects.append(Project.new())
	tabs.current_tab = projects.size() - 1

	# Basic connections
	data_files_updated.connect(data_tree.update_data_tree)
	kline_list_updated.connect(kline_list.update_list)
	update_plot.connect(_queue_render_current_project_graph)

	# Render the initial graph
	render_current_project_graph()


func load_preffeernces():
	# Load preferences from the config file
	if config_cache.has_section("preferences"):
		for pref in config_cache.get_section_keys("preferences"):
			if get(pref) == null:
				continue
			var value = config_cache.get_value("preferences", pref)
			set(pref, value)


func _is_fast_generate_possible() -> bool:
	return (
		_is_base64_installed()
		and (_is_convert_installed() if visual_format == OpenSave.Format.PDF else true)
	)


func _is_base64_installed() -> bool:
	var base64_executed := OS.execute("base64", ["--version"])
	if base64_executed == 0 or base64_executed == 1:
		return true
	return false


func _is_convert_installed() -> bool:
	var base64_executed := OS.execute("convert", ["--version"])
	if base64_executed == 0 or base64_executed == 1:
		return true
	return false


func debug_funny(message, person := "[color=green][b]Stella[/b][/color]") -> void:
	if person == "":
		if OS.has_environment("USER"):
			person = "[color=orange][b]" + OS.get_environment("USER").capitalize() + "[/b][/color]"
		else:
			person = "[color=orange][b]User[/b][/color]"
	print_rich(person, ":        ", message)


func _queue_render_current_project_graph() -> void:
	if not _graph_update_qued:
		call_deferred("render_current_project_graph")
		_graph_update_qued = true


func render_current_project_graph(graph_destination := "", format := visual_format):
	_graph_update_qued = false
	log_text_label.text = ""
	graph_destination = graph_destination.strip_edges()
	var project := projects[current_project_index]
	project.has_changed = true
	var data := project.serialize()
	var cache_folder := ProjectSettings.globalize_path(CACHE_DIR)
	var is_file_making_avoidable = (
		base64_installed
		and (convert_installed if format == OpenSave.Format.PDF else true)
	)
	# Use PNG format for in-editor view (PDF format gets converted later)
	if graph_destination.is_empty():
		if not is_file_making_avoidable:  # Fallback to physical image saves
			graph_destination = cache_folder.path_join("graph.png")

	var gnu_script := GNUgenerator.generate_gnu(data, graph_destination, format)
	var gnu_code: String = gnu_script.get("code", "")
	var gnu_path_deps: PackedStringArray = gnu_script.get("deps", PackedStringArray())

	# Save a local copy of gnu code if we are doing an export through CLI
	if OpenSave.is_using_cli and not graph_destination.is_empty():
		var gnu_path := graph_destination.get_base_dir().path_join(
			graph_destination.get_file().get_slice(".", 0) + ".gnu"
		)
		var path_deps_local := PackedStringArray()
		var local_config_dir := gnu_path.get_base_dir().path_join(".stella")
		for dep_path in gnu_path_deps:
			if dep_path.get_base_dir() == cache_folder:
				DirAccess.make_dir_recursive_absolute(local_config_dir)
				DirAccess.copy_absolute(dep_path, local_config_dir.path_join(dep_path.get_file()))
				dep_path = local_config_dir.path_join(dep_path.get_file())
			path_deps_local.append(OpenSave.get_relative_path(gnu_path, dep_path))
		var file := FileAccess.open(gnu_path, FileAccess.WRITE)
		if FileAccess.get_open_error() == OK:
			file.store_string(gnu_code.format(Array(path_deps_local)))
			file.close()

	gnu_code = gnu_code.format(Array(gnu_path_deps))
	# Convert it to single line format
	var array: Array = gnu_code.split("\n", false)
	array = array.filter(func(line: String): return !line.strip_edges().begins_with("#"))
	gnu_code = "".join(PackedStringArray(array))
	gnu_code = gnu_code.replace("\\", "")

	# Run the gnuplot utility and obtain output
	var output = []
	var exit_code: int = OK
	var bytes := PackedByteArray()

	if graph_destination.is_empty():  # We need image for view IN editor.
		var cmd = "gnuplot -e \"%s\" | base64" % gnu_code
		if format == OpenSave.Format.PDF:
			cmd = "gnuplot -e \"%s\" | convert pdf:- png:- | base64" % gnu_code
		if open_gnuplotter:
			if (Time.get_ticks_msec() - gnu_button_press_timeout) > 1000:
				gnu_button_press_timeout = Time.get_ticks_msec()
				cmd = "gnuplot -persist -e \"%s\"" % gnu_code
				var open_dict := OS.execute_with_pipe("bash", ["-c", cmd], true)
				open_gnuplotter = false
				if not open_dict.is_empty():
					await get_tree().create_timer(1.0).timeout
					OS.kill(open_dict.get("pid"))
			return
		var dict := OS.execute_with_pipe("bash", ["-c", cmd])
		if not dict.is_empty():
			var base_64_array := PackedStringArray()
			var file := dict["stdio"] as FileAccess
			while true:
				var line := file.get_line()
				if line.is_empty():
					break
				base_64_array.append(line)
			bytes = Marshalls.base64_to_raw("\n".join(base_64_array))
			OS.kill(dict["pid"])
	else:
		exit_code = OS.execute("gnuplot", ["-e", gnu_code], output, true)

	log_text_label.text += "Execution State: %s\n" % error_string(exit_code)
	for text: String in output:
		if not text.is_empty():
			log_text_label.text += text + "\n"
	if exit_code == OK:
		# NOTE: if is_file_making_avoidable is true the we shall use the bytes array instead
		if graph_destination.is_empty() and not bytes.is_empty():
			var img := Image.new()
			img.load_png_from_buffer(bytes)
			project.last_render = img
		elif FileAccess.file_exists(graph_destination):
			match visual_format:
				OpenSave.Format.PNG:
					project.last_render = Image.load_from_file(graph_destination)
				OpenSave.Format.PDF:
					var graph_img_path = cache_folder.path_join("graph.png")
					var graph_pdf_path = cache_folder.path_join("graph.pdf")
					if FileAccess.file_exists(graph_pdf_path):
						log_text_label.text += "Converting PDF to PNG.\n"
						output.clear()
						OS.execute("convert", [graph_pdf_path, graph_img_path], output, true)
						for text: String in output:
							if not text.is_empty():
								log_text_label.text += text + "\n"
						graph_destination = graph_img_path
		canvas.queue_redraw()
