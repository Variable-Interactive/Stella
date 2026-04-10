extends Control

signal save_file_dialog_opened(opened: bool)

enum FileMenu { NEW_PROJECT, OPEN_PROJECT, LOAD_DATA_FILE, SAVE_FILE, QUIT }

@onready var file_menu: PopupMenu = %File
@onready var open_project_dialog: FileDialog = %OpenProjectDialog
@onready var save_file_dialog: FileDialog = %SaveFileDialog
@onready var visual_format_option: HBoxContainer = %VisualFormatOption
@onready var canvas_camera: CanvasCamera = %CanvasCamera
@onready var camera_behavior_checkbox: CheckButton = %CameraBehaviorCheckbox


class CLI:
	static var args_list := {
		["-v", "--version"]: [CLI.print_version, "Prints current software version."],
		["--recipie"]: [CLI.load_stella, "[path] Loads the *.stella file containing plot instructions."],
		["--data", "-d"]: [CLI.load_data, "[path] Loads the *.dat file containing plot data."],
		["-xy"]: [CLI.set_columns, "[integer:integer] Sets x and y column for the last added data."],
		["--output", "-o"]:[CLI.quick_export, "[path] Name of output file (with extension .png, .png, .gnu or .birch)"],
		["--help", "-h", "-?"]: [CLI.generate_help, "Displays this help page."]
	}

	static func generate_help(_next_arg: String, _option_node):
		var commands_help := ""
		for command_group: Array in args_list.keys():
			commands_help += str(
				"[color=green][b]",
				var_to_str(command_group).replace("[", "").replace("]", "").replace('"', ""),
				"[/b][/color]",
				"\t\t".c_unescape(),
				args_list[command_group][1],
				"\n".c_unescape()
			)
		commands_help += "========================================================================="

		var help := str(
			(
				"""
=========================================================================\n
Help for Stella's CLI.

[b]USAGE[/b]:
	[b]{stella}[/b] [color=orange][SYSTEM OPTIONS][/color] -- [color=green][USER OPTIONS][/color] [FILES]...

Use -h in place of [SYSTEM OPTIONS] to see [SYSTEM OPTIONS].
Or use -h in place of [USER OPTIONS] to see [USER OPTIONS].

some useful [b][SYSTEM OPTIONS][/b] are:
[color=orange]--headless[/color]     Run in headless mode.
[color=orange]--quit[/color]         Close pixelorama after current command.


[b][USER OPTIONS][/b]:\n
(The terms in [ ] reflect the valid type for corresponding argument).

{command_help}

[b]Examples[/b]:

	[color=orange]{stella} --headless --quit -- -d TDOS.dat -xy 1:2 -o out.png[/color]
	This command will plot the 1st columm of [b]TDOS.dat[/b] file as x-axis and 2nd column as y-axis, and export result as PNG image. A gnu file will also be created.

	[color=orange]{stella} --headless --quit -- -d TDOS.dat -xy 1:2 -o out.pdf[/color]
	Same as above but output will be a pdf.

	[color=orange]{stella} --headless --quit -- --recipie plotter.stella -o out.pdf[/color]
	This loads up [b]plotter.stella[/b] project file and exports it. The data paths present in the project are treated as relative.
"""
				.format(
					{
						"stella": OS.get_executable_path().get_file(),
						"command_help": commands_help
					}
				)
			)
		)
		Global.debug_funny("I need serious help", "")
		Global.debug_funny("Sure, here you go :)")
		print_rich(help)

	## Dedicated place for command line args callables
	static func print_version(_next_arg: String, _option_node) -> void:
		Global.debug_funny(
			"What!?, you wish to know my age? well.. i'm currently %s"
			% ProjectSettings.get("application/config/version")
		)

	static func load_stella(stella_file_path: String, _option_node) -> void:
		if FileAccess.file_exists(stella_file_path):
			Global.debug_funny("Opening stella file named: %s." % stella_file_path.get_file())
			OpenSave.is_using_cli = true
			OpenSave.load_stella_file(stella_file_path)
			OpenSave.is_using_cli = false

	static func load_data(data_file_path: String, _option_node) -> void:
		if FileAccess.file_exists(data_file_path):
			var project := Global.projects[Global.current_project_index]
			Global.debug_funny("Added new data %s to project --> %s" % [data_file_path.get_file(), project.project_name])
			OpenSave.is_using_cli = true
			OpenSave.load_data_file(data_file_path)
			OpenSave.is_using_cli = false

	static func set_columns(next_arg: String, _option_node) -> void:
		var x_y_columns := next_arg.split(":", false)
		if x_y_columns.size() == 2:
			var x_col := int(x_y_columns[0])
			var y_col := int(x_y_columns[1])
			var project := Global.projects[Global.current_project_index]
			if not project.data_files.is_empty():
				var data_file := project.data_files[-1]
				var plot := Project.DataFile.PlotData.new(data_file)
				plot.x_column = x_col
				plot.y_column = y_col
				data_file.plot_lines.append(plot)

	static func quick_export(export_path: String, _option_node) -> void:
		Global.debug_funny("Hy, ah, i don't have much time, can export this real quick?", "")
		Global.debug_funny("Sure, give me a moment to look at the data")
		OpenSave.is_using_cli = true
		OpenSave.handle_file_save(export_path)
		OpenSave.is_using_cli = false


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

	var working_directory := ""
	for i in args.size():  # Handle the rest of the CLI arguments
		var arg := args[i]
		var next_argument := ""
		if i + 1 < args.size():
			next_argument = args[i + 1]
			if ["--recipie", "--data", "-d", "--output", "-o"].has(arg):
					var file_path := next_argument
					# if we think the file could be a potential relative path it can mean two things:
					# 1. The file is relative to executable
					# 2. The file is relative to the working directory.
					if file_path.is_relative_path():
						# we first try to convert it to be relative to executable
						file_path = OS.get_executable_path().get_base_dir().path_join(next_argument)
						if !FileAccess.file_exists(file_path):
							# it is not relative to executable so we have to convert it to an
							# absolute path instead (this is when file is relative to working directory)
							var pwd := OS.get_environment("PWD")
							if not working_directory.is_empty():
								pwd = working_directory
							file_path = pwd.path_join(next_argument)
					# Do one last failsafe to see everything is in order.
					if not ["--output", "-o"].has(arg):
						if FileAccess.file_exists(file_path):
							next_argument = file_path
					else:
						next_argument = file_path

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


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var logo = (
"""
#       ____  _       _ _
#      / ___|| |_ ___| | | __ _
#      \\___ \\| __/ _ \\ | |/ _` |
#       ___) | ||  __/ | | (_| |
#      |____/ \\__\\___|_|_|\\__,_|
""")
	print(logo.replace("#", ""))
	_setup_file_menu()

	# it is not relative to executable so we have to convert it to an
	# absolute path instead (this is when file is relative to working directory)
	var output = []
	var working_directory := OS.get_executable_path()
	match OS.get_name():
		"Linux":
			visual_format_option.visible = true
			output.append(OS.get_environment("PWD"))
	if output.size() > 0:
		working_directory = str(output[0]).strip_edges()
	open_project_dialog.current_dir = working_directory
	Global.import_data_dialog.current_dir = working_directory
	OpenSave.find_vaspkit_data_files(working_directory)
	Global.debug_funny("Hy, i'm Stella how may i help you today?")
	_handle_cmdline_arguments()
	get_window().files_dropped.connect(on_files_dropped)
	camera_behavior_checkbox.button_pressed = Global.camera_updates_range



func on_files_dropped(files: PackedStringArray):
	for file in files:
		OpenSave.handle_laoding_files(file)


func _on_file_menu_id_pressed(id: int):
	match id:
		FileMenu.NEW_PROJECT:
			Global.projects.append(Project.new())
			Global.tabs.current_tab = Global.projects.size() - 1
		FileMenu.OPEN_PROJECT:
			open_project_dialog.popup_centered()
		FileMenu.LOAD_DATA_FILE:
			Global.import_data_dialog.popup_centered()
		FileMenu.SAVE_FILE:
			var project := Global.projects[Global.current_project_index]
			if not project.last_save_path.get_base_dir().is_empty():
				save_file_dialog.current_dir = project.last_save_path.get_base_dir()
			save_file_dialog_opened.emit(true)
			save_file_dialog.popup_centered()
		FileMenu.QUIT:
			get_tree().quit()


func _on_save_file_dialog_cancelled() -> void:
	save_file_dialog_opened.emit(false)


func _on_open_project_dialog_file_selected(path: String) -> void:
	OpenSave.handle_laoding_files(path)


func _on_import_data_dialog_file_selected(path: String) -> void:
	OpenSave.load_data_file(path)


func _on_save_file_dialog_file_selected(path: String) -> void:
	save_file_dialog_opened.emit(false)
	OpenSave.handle_file_save(path)


func _setup_file_menu():
	file_menu.add_item("New Project...", FileMenu.NEW_PROJECT)
	file_menu.add_item("Export Project/Data...", FileMenu.SAVE_FILE)
	file_menu.add_item("Open Project (*.stella)...", FileMenu.OPEN_PROJECT)
	file_menu.add_item("Import data (*.dat)...", FileMenu.LOAD_DATA_FILE)
	file_menu.add_item("Quit", FileMenu.SAVE_FILE)
	file_menu.id_pressed.connect(_on_file_menu_id_pressed)


func _on_visual_format_toggle_toggled(toggled_on: bool) -> void:
	Global.visual_format = OpenSave.Format.PNG if !toggled_on else OpenSave.Format.PDF


func _on_clear_output_pressed() -> void:
	Global.log_text_label.text = ""


func _on_camera_behavior_checkbox_toggled(toggled_on: bool) -> void:
	Global.camera_updates_range = toggled_on
	if toggled_on:
		Global.canvas.camera_zoom()


func _exit_tree() -> void:
	if DisplayServer.get_name() == "headless":
		return
	Global.config_cache.save(Global.CONFIG_PATH)


func _on_save_button_pressed() -> void:
	_on_file_menu_id_pressed(FileMenu.SAVE_FILE)
