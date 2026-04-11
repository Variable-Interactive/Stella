extends VBoxContainer

enum SpecialPlots { STANDARD, BIRCH }
const PLOT_LINE_UI = preload("res://src/UI/PlotLineUI/PlotLineUI.tscn")

var data_file: Project.DataFile:
	set(value):
		data_file = value
		Global.properties_container.update_properties()

@onready var data_line_edit: LineEdit = %DataLineEdit
@onready var plot_lines_container: VBoxContainer = %PlotLinesContainer
@onready var special_plot_menu: MenuButton = %SpecialPlotMenu


func _ready() -> void:
	var special_menu_popup := special_plot_menu.get_popup()
	special_menu_popup.add_item("Standard Plot", SpecialPlots.STANDARD)
	special_menu_popup.add_item("Birch-Murnaghan", SpecialPlots.BIRCH)
	special_menu_popup.id_pressed.connect(_special_menu_popup_id_pressed)


func update_properties():
	visible = data_file != null
	for plot_ui in plot_lines_container.get_children():
		plot_ui.queue_free()
	if data_file:
		if data_file.file_path_local.is_empty():
			data_line_edit.text = data_file.file_path
		else:
			data_line_edit.text = data_file.file_path_local
		for plot_data: Project.DataFile.PlotData in data_file.plot_lines:
			var mode = SpecialPlots.BIRCH if plot_data.birch_enabled else SpecialPlots.STANDARD
			add_new_plot_ui(plot_data, mode)


func add_new_plot_ui(plot_data: Project.DataFile.PlotData, mode: SpecialPlots):
	var plot_line_ui := PLOT_LINE_UI.instantiate()
	plot_lines_container.add_child(plot_line_ui)
	plot_line_ui.mode = mode
	if !plot_data:
		plot_data = Project.DataFile.PlotData.new(data_file, plot_line_ui.get_index())
		data_file.plot_lines.append(plot_data)
		if mode == SpecialPlots.BIRCH:
			plot_data.birch_enabled = true
			plot_data.try_auto_fit_birch(1000000)
			plot_data.title = "Birch-Murnaghan Curve"
	plot_line_ui.plot_data = plot_data


func _on_change_file_button_pressed() -> void:
	Global.data_file_to_update = data_file
	var base_dir := data_line_edit.text.get_base_dir()
	if DirAccess.dir_exists_absolute(base_dir):
		Global.import_data_dialog.current_dir = base_dir
		Global.import_data_dialog.current_path = data_line_edit.text
	Global.import_data_dialog.popup_centered()


func _on_add_plot_pressed() -> void:
	add_new_plot_ui(null, SpecialPlots.STANDARD)
	Global.update_plot.emit()


func _special_menu_popup_id_pressed(id: int):
	match id:
		SpecialPlots.STANDARD:
			add_new_plot_ui(null, SpecialPlots.STANDARD)
		SpecialPlots.BIRCH:
			add_new_plot_ui(null, SpecialPlots.BIRCH)
