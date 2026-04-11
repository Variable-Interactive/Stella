extends Node

enum Format { PNG, PDF}

const STELLA_EXTENSION = "stella"
const PNG_EXTENSION = "png"
const PDF_EXTENSION = "pdf"
const GNU_EXTENSION = "gnu"
const DATA_EXTENSION = "dat"
const BIRCH_EXTENSION = "birch"

var is_using_cli := false
var is_exporting_image := false


func get_relative_path(from_path: String, to_path: String) -> String:
	var file_name := to_path.get_file()
	var from_parts = from_path.get_base_dir().simplify_path().split("/", false)
	var to_parts = to_path.get_base_dir().simplify_path().split("/", false)
	# Remove common prefix
	while from_parts.size() > 0 and to_parts.size() > 0 and from_parts[0] == to_parts[0]:
		from_parts.remove_at(0)
		to_parts.remove_at(0)

	var result = PackedStringArray()
	# Go up for remaining "from"
	for i in from_parts.size():
		result.append("..")
	# Then go down to target
	result += to_parts
	return "/".join(result).path_join(file_name)


func load_stella_file(file_path, as_template := false):
	var open_file := FileAccess.open(file_path, FileAccess.READ)
	if FileAccess.get_open_error() == OK:
		var data_str := open_file.get_as_text()
		open_file.close()
		var data: Dictionary = JSON.parse_string(data_str)
		if data:
			# convert string back to data
			for key in data:
				data.set(key, str_to_var(data[key]))
			if as_template:
				var project := Global.projects[Global.current_project_index]
				data.set("k_lines", {})
				var data_file_dict_old: Array[Dictionary] = data.get("data_files", [])
				var data_file_dict_new: Array[Dictionary] = []
				for data_entry: Dictionary in data_file_dict_old:
					for data_file: Project.DataFile in project.data_files:
						# Check if there is a data file with the same file type
						if (
							(data_entry.get("file_path", "") as String).get_file()
							== data_file.file_path.get_file()
						):
							if not data_file_dict_new.has(data_entry):
								# Prepare data file settings
								data_entry.erase("file_path")
								data_entry.erase("data_label")
								data_file_dict_new.append(data_entry)
				data.set("data_files", data_file_dict_new)
				project.deserialize(data)
			else:
				var project := Project.new(file_path, data)
				Global.projects.append(project)
				Global.tabs.current_tab = Global.projects.size() - 1
				await get_tree().process_frame
				project.project_name = file_path.uri_decode().get_file().trim_suffix("." + STELLA_EXTENSION)
				Global.canvas.camera_zoom()


func find_vaspkit_data_files(dir_path: String):
	var project: Project = Global.projects[Global.current_project_index]
	var band_file_path = dir_path.path_join("BAND.dat")
	var dos_file_path = dir_path.path_join("TDOS.dat")
	var label_path = dir_path.path_join("KLABELS")
	# Do one last failsafe to see everything is in order
	if FileAccess.file_exists(band_file_path):
		Global.import_data_dialog.current_file = band_file_path
		load_data_file(band_file_path)
		project.y_label = "K-Point Distance"
		project.y_label = "E - E_f (eV)"
		# Get Labels
		get_klabels(label_path)
	elif FileAccess.file_exists(dos_file_path):
		load_data_file(dos_file_path)
		Global.import_data_dialog.current_file = band_file_path
		project.graph_title = "Total Density of State"
		project.x_label = "E - E_f (eV)"
		project.y_label = "DOS"
	Global.properties_container.update_properties()


func load_data_file(file_path: String):
	var project: Project = Global.projects[Global.current_project_index]
	var file_path_local := ""
	if not project.last_save_path.is_empty():
		file_path_local = get_relative_path(project.last_save_path, file_path)
	if Global.data_file_to_update:
		Global.data_file_to_update.file_path = file_path
		Global.data_file_to_update.file_path_local = file_path_local
	else:
		project.data_files.append(Project.DataFile.new(project, file_path))
	Global.data_files_updated.emit()
	Global.data_tree.select_last_added()

	# Load up KLABELS if data file needs it.
	var label_path = file_path.get_base_dir().path_join("KLABELS")
	if FileAccess.file_exists(label_path):
		if is_using_cli:
			Global.debug_funny("I also found a KLABELS file, i assume you need it as well")
			import_klables(label_path)
		else:
			Global.klables_import_confirm.popup_centered()
			if Global.klables_import_confirm.confirmed.is_connected(import_klables):
				Global.klables_import_confirm.confirmed.disconnect(import_klables)
			Global.klables_import_confirm.confirmed.connect(import_klables.bind(label_path))
	project.is_empty = false
	Global.update_plot.emit()


func import_klables(label_path: String):
	var project: Project = Global.projects[Global.current_project_index]
	var k_lines := get_klabels(label_path)
	project.k_lines.append_array(k_lines)
	Global.kline_list_updated.emit()


func get_klabels(label_path: String) -> Array[Project.KLine]:
	var result: Array[Project.KLine] = []
	if FileAccess.file_exists(label_path):
		var file := FileAccess.open(label_path, FileAccess.READ)
		if FileAccess.get_open_error() == OK:
			while not file.eof_reached():
				var line := file.get_line()
				if line.begins_with(" ") and line.strip_edges() != "":
					var k_line := line.split(" ", false)
					if k_line.size() == 2:
						var kline := Project.KLine.new(k_line[0], float(k_line[1]))
						result.append(kline)
	return result


func handle_laoding_files(file_path: String):
	if file_path.get_extension().to_lower() == STELLA_EXTENSION:
		load_stella_file(file_path)

	if file_path.get_extension().to_lower() == DATA_EXTENSION:
		load_data_file(file_path)


func export_birch_energies(file_path: String):
	var results_dir := file_path.get_file().get_slice(".", 0)
	file_path = file_path.get_base_dir().path_join(results_dir)
	DirAccess.make_dir_recursive_absolute(file_path)
	var project := Global.projects[Global.current_project_index]
	for data_file: Project.DataFile in project.data_files:
		var dat_name := data_file.data_label.get_slice(".", 0)
		for plot_file: Project.DataFile.PlotData in data_file.plot_lines:
			if plot_file.birch_enabled:
				var birch_lattice_dat_name := "%s_%s_birch_lattice_energy_table%s" % [
					dat_name, plot_file.title, ".dat"
				]
				var birch_path = file_path.path_join(birch_lattice_dat_name)
				var birch_file = FileAccess.open(birch_path, FileAccess.WRITE)
				birch_file.store_string(
					BirchMurnaghan.generate_trial_data(
						plot_file.birch_lattice,
						plot_file.birch_energy,
						plot_file.birch_modulo,
						plot_file.birch_modulo_prime,
						plot_file.birch_data_width,
						plot_file.primitive_cels
					)
				)
				birch_file.close()
				var birch_vol_dat_name := "%s_%s_birch_volume_energy_table%s" % [
					dat_name, plot_file.title, ".dat"
				]
				birch_path = file_path.path_join(birch_vol_dat_name)
				birch_file = FileAccess.open(birch_path, FileAccess.WRITE)
				birch_file.store_string(
					BirchMurnaghan.generate_trial_data(
						plot_file.birch_lattice,
						plot_file.birch_energy,
						plot_file.birch_modulo,
						plot_file.birch_modulo_prime,
						plot_file.birch_data_width,
						plot_file.primitive_cels,
						true
					)
				)
				birch_file.close()
				var birch_info_name := "%s_%s_birch_report.%s" % [
					dat_name, plot_file.title, BIRCH_EXTENSION
				]
				var birch_info_path = file_path.path_join(birch_info_name)
				var birch_info_file = FileAccess.open(birch_info_path, FileAccess.WRITE)
				birch_info_file.store_line(
					"Cels per volume: %s" % str(plot_file.primitive_cels)
				)
				birch_info_file.store_line(
					"Conventional Lattice Constant: %s" % str(plot_file.birch_lattice)
				)
				birch_info_file.store_line("")
				birch_info_file.store_line(
					"NOTE: Assuming Primitive and Conventional cels have similar shape:"
				)
				birch_info_file.store_line(
					"	Primitive Lattice = Conventional Lattice / primitive_cels^(1/3)"
				)
				birch_info_file.store_line("")
				birch_info_file.store_line(
					"Minimum Volume (Conventional): %s" % str(
						BirchMurnaghan.lattice_to_volume(plot_file.birch_lattice)
					)
				)
				birch_info_file.store_line("")
				birch_info_file.store_line(
					"NOTE: Primitive Volume = Conventional Volume / primitive_cels"
				)
				birch_info_file.store_line("")
				birch_info_file.store_line(
					"Ground Energy: %s" % str(plot_file.birch_energy)
				)
				birch_info_file.store_line(
					"Ground Bulk Modulo: %s" % str(plot_file.birch_modulo)
				)
				birch_info_file.store_line(
					"Ground Bulk Modulo Derivative: %s" % str(plot_file.birch_modulo_prime)
				)
				birch_info_file.close()

# nstella.x86_64 --headless --quit -- -d Energies.dat -xy 1:2 -o out.png
func handle_file_save(file_path: String) -> void:
	var extension := file_path.get_extension().to_lower()
	var project := Global.projects[Global.current_project_index]

	# Use full range when using CLI, and range not defined
	# (if a recipie i-e. project file is not given, then project.last_save_path would be empty)
	if is_using_cli and project.last_save_path == "":
		Global.debug_funny("There isn't a recipie file, so i am using full domain.")
		project.full_range = true
	match extension:
		STELLA_EXTENSION, GNU_EXTENSION:
			var file := FileAccess.open(file_path, FileAccess.WRITE)
			if FileAccess.get_open_error() != OK:
				return
			if extension == STELLA_EXTENSION:
				project.project_name = file_path.uri_decode().get_file().trim_suffix("." + STELLA_EXTENSION)
				project.last_save_path = file_path
				var serialized_data := project.serialize()
				for key in serialized_data:
					serialized_data.set(key, var_to_str(serialized_data[key]))
				file.store_string(JSON.stringify(serialized_data, "\t"))
			elif extension == GNU_EXTENSION:
				var gnu_script := GNUgenerator.generate_gnu(
					project.serialize(), file_path, Global.visual_format
				)
				var gnu_path_deps: PackedStringArray = gnu_script.get("deps", PackedStringArray())
				var path_deps_local := PackedStringArray()
				var local_config_dir := file_path.get_base_dir().path_join(".stella")
				for dep_path in gnu_path_deps:
					if dep_path.get_base_dir() == ProjectSettings.globalize_path(Global.CACHE_DIR):
						DirAccess.make_dir_recursive_absolute(local_config_dir)
						DirAccess.copy_absolute(dep_path, local_config_dir.path_join(dep_path.get_file()))
						dep_path = local_config_dir.path_join(dep_path.get_file())
					path_deps_local.append(OpenSave.get_relative_path(file_path, dep_path))
				file.store_string(
					gnu_script.get("code", "").format(Array(path_deps_local))
				)
			file.close()
		PNG_EXTENSION:
			is_exporting_image = true
			Global.render_current_project_graph(file_path, Format.PNG)
			is_exporting_image = false
		PDF_EXTENSION:
			is_exporting_image = true
			Global.render_current_project_graph(file_path, Format.PDF)
			is_exporting_image = false
		BIRCH_EXTENSION:
			export_birch_energies(file_path)
