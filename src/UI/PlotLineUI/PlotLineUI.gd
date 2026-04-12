extends HBoxContainer

enum Mode { STANDARD, BIRCH }
const LINE_MODES := Project.DataFile.PlotData.LINE_MODES

var plot_data: Project.DataFile.PlotData:
	set(value):
		plot_data = value
		update_ui()

var mode: Mode = Mode.STANDARD:
	set(value):
		mode = value
		birch_murnaghan.visible = (mode == Mode.BIRCH)
		if plot_data:
			plot_data.birch_enabled = (mode == Mode.BIRCH)

@onready var plot_line_options: CollapsibleContainer = %PlotLineOptions
@onready var plot_name_edit: LineEdit = %PlotNameEdit
@onready var plot_data_slider: ValueSliderV2 = %PlotDataSlider
@onready var line_mode_option: OptionButton = %LineModeOption
@onready var plot_line_width_slider: ValueSlider = %PlotLineWidthSlider
@onready var plot_color_button: ColorPickerButton = %PlotColorButton
@onready var visible_check_box: CheckBox = %VisibleCheckBox
@onready var show_legend_check_box: CheckBox = %ShowLegendCheckBox

@onready var birch_murnaghan: CollapsibleContainer = %BirchMurnaghan
@onready var birch_lattice_slider: ValueSlider = %BirchLatticeSlider
@onready var birch_volume_display: RichTextLabel = %BirchVolumeDisplay
@onready var primitive_cel_slider: ValueSlider = %PrimitiveCelSlider
@onready var birch_energy_slider: ValueSlider = %BirchEnergySlider
@onready var birch_bulk_modulo_slider: ValueSlider = %BirchBulkModuloSlider
@onready var birch_bulk_modulo_p_slider: ValueSlider = %BirchBulkModuloPSlider
@onready var data_width_slider: ValueSlider = %DataWidthSlider


func _ready() -> void:
	var birch_container_label: Label = birch_murnaghan.get("_label")
	if birch_container_label:
		birch_container_label.self_modulate = Color.ORANGE
	for i in LINE_MODES.size():
		line_mode_option.add_item(LINE_MODES[i].keys()[0], i)
	plot_name_edit.text_changed.connect(
		func (value: String):
			plot_data.title = value
			Global.update_plot.emit()
	)
	plot_data_slider.value_changed.connect(
		func (value: Vector2i):
			plot_data.x_column = value.x
			plot_data.y_column = value.y
			Global.update_plot.emit()
	)
	line_mode_option.item_selected.connect(
		func (index: int):
			plot_data.line_type = index
			Global.update_plot.emit()
	)
	plot_line_width_slider.value_changed.connect(
		func (value: float):
			plot_data.width = value
			Global.update_plot.emit()
	)
	plot_color_button.color_changed.connect(
		func (value: Color):
			plot_data.color = value
			var plot_line_label: Label = plot_line_options.get("_label")
			if plot_line_label:
				plot_line_label.self_modulate = plot_data.color
			Global.update_plot.emit()
	)
	visible_check_box.toggled.connect(
		func (value: bool):
			plot_data.visible = value
			Global.update_plot.emit()
	)
	show_legend_check_box.toggled.connect(
		func (value: bool):
			plot_data.show_in_legend = value
			Global.update_plot.emit()
	)
	birch_lattice_slider.value_changed.connect(
		func (value: float):
			plot_data.birch_lattice = value
			Global.update_plot.emit()
			# Units of a.u^3
			birch_volume_display.text = str(
				BirchMurnaghan.lattice_to_volume(value / pow(plot_data.primitive_cels, 1/3.0))
			)
	)
	primitive_cel_slider.value_changed.connect(
		func (value: int):
			plot_data.primitive_cels = value
			# Units of a.u^3
			birch_volume_display.text = str(
				BirchMurnaghan.lattice_to_volume(plot_data.birch_lattice / pow(value, 1/3.0))
			)
	)
	birch_energy_slider.value_changed.connect(
		func (value: float):
			plot_data.birch_energy = value
			Global.update_plot.emit()
	)
	birch_bulk_modulo_slider.value_changed.connect(
		func (value: float):
			plot_data.birch_modulo = value
			Global.update_plot.emit()
	)
	birch_bulk_modulo_p_slider.value_changed.connect(
		func (value: float):
			plot_data.birch_modulo_prime = value
			Global.update_plot.emit()
	)
	data_width_slider.value_changed.connect(
		func (value: float):
			plot_data.birch_data_width = value
			Global.update_plot.emit()
	)
	Global.update_plot.emit()


func update_ui() -> void: # update general properties
	if is_instance_valid(plot_data):
		plot_line_options.text = plot_data.title
		plot_name_edit.text = plot_data.title
		plot_data_slider.set_value_no_signal(Vector2i(plot_data.x_column, plot_data.y_column))
		line_mode_option.selected = plot_data.line_type
		plot_line_width_slider.set_value_no_signal_update_display(plot_data.width)
		plot_color_button.color = plot_data.color
		visible_check_box.set_pressed_no_signal(plot_data.visible)
		show_legend_check_box.set_pressed_no_signal(plot_data.show_in_legend)

		var plot_line_label: Label = plot_line_options.get("_label")
		if plot_line_label:
			plot_line_label.self_modulate = plot_data.color
		# Birch Settings
		birch_lattice_slider.set_value_no_signal_update_display(plot_data.birch_lattice)
		primitive_cel_slider.value = plot_data.primitive_cels
		birch_energy_slider.set_value_no_signal_update_display(plot_data.birch_energy)
		birch_bulk_modulo_slider.set_value_no_signal_update_display(plot_data.birch_modulo)
		birch_bulk_modulo_p_slider.set_value_no_signal_update_display(plot_data.birch_modulo_prime)
		data_width_slider.set_value_no_signal_update_display(plot_data.birch_data_width)


func try_auto_fit_birch(itterations: int) -> void:
	plot_data.try_auto_fit_birch(itterations)
	birch_lattice_slider.set_value_no_signal_update_display(plot_data.birch_lattice)
	primitive_cel_slider.value = plot_data.primitive_cels
	birch_energy_slider.set_value_no_signal_update_display(plot_data.birch_energy)
	birch_bulk_modulo_slider.set_value_no_signal_update_display(plot_data.birch_modulo)
	birch_bulk_modulo_p_slider.set_value_no_signal_update_display(plot_data.birch_modulo_prime)


func _on_remove_plot_button_pressed() -> void:
	Global.properties_container.data_properties.data_file.plot_lines.erase(plot_data)
	Global.update_plot.emit()
	queue_free()


func _on_plot_name_edit_text_changed(new_text: String) -> void:
	plot_line_options.text = new_text


func _on_flip_slider_pressed() -> void:
	plot_data_slider.value = Vector2(plot_data_slider.value.y, plot_data_slider.value.x)

func _on_recalculate_button_pressed() -> void:
	try_auto_fit_birch(2329)
