extends PanelContainer

var property_cooldown := Timer.new()
var zoom_displace_cooldown := Timer.new()
var _drag = false
@onready var data_properties: VBoxContainer = %DataProperties
@onready var project_properties: CollapsibleContainer = %ProjectProperties

@onready var title_line_edit: LineEdit = %TitleLineEdit
@onready var x_axis_line_edit: LineEdit = %XAxisLineEdit
@onready var y_axis_line_edit: LineEdit = %YAxisLineEdit
@onready var font_option_button: OptionButton = %FontOptionButton
@onready var bold_check_box: CheckBox = %FontBoldCheckBox
@onready var fallback_font_size_slider: ValueSlider = %FontSizeSlider
@onready var font_color_button: ColorPickerButton = %FontColorButton
@onready var border_mode_slider: ValueSlider = %BorderModeSlider
@onready var border_color_button: ColorPickerButton = %BorderColorButton
@onready var border_width_slider: ValueSlider = %BorderWidthSlider
@onready var bg_color_button: ColorPickerButton = %BgColorButton
@onready var size_slider: ValueSliderV2 = %SizeSlider
@onready var scale_slider: ValueSliderV2 = %ScaleSlider
@onready var full_domain_check_box: CheckBox = %FullDomainCheckBox
@onready var x_min_slider: ValueSlider = %XMinSlider
@onready var x_max_slider: ValueSlider = %XMaxSlider
@onready var y_min_slider: ValueSlider = %YMinSlider
@onready var y_max_slider: ValueSlider = %YMaxSlider
@onready var range_pos_slider: ValueSliderV2 = %RangePosSlider
@onready var range_size_slider: ValueSliderV2 = %RangeSizeSlider

# guides
@onready var zero_axis_check_box: CheckBox = %ZeroAxisCheckBox

# Legend
@onready var legend_enabled_check_box: CheckBox = %LegendEnabledCheckBox
@onready var vertical_option_button: OptionButton = %VerticalOptionButton
@onready var horizontal_option_button: OptionButton = %HorizontalOptionButton
@onready var reverse_check_box: CheckBox = %ReverseCheckBox
@onready var use_box_check_box: CheckBox = %UseBoxCheckBox

# Legend Box
@onready var box_option_container: GridContainer = %BoxOptionContainer
@onready var box_outline_slider: ValueSlider = %BoxOutlineSlider
@onready var box_spacing_slider: ValueSlider = %BoxSpacingSlider


func update_legend_align_options() -> void:
	vertical_option_button.add_item(
		Project.alignment_string[Project.LegendAlign.ABOVE].capitalize(), Project.LegendAlign.ABOVE
	)
	vertical_option_button.add_item(
		Project.alignment_string[Project.LegendAlign.TOP].capitalize(), Project.LegendAlign.TOP
	)
	vertical_option_button.add_item(
		Project.alignment_string[Project.LegendAlign.CENTER].capitalize(), Project.LegendAlign.CENTER
	)
	vertical_option_button.add_item(
		Project.alignment_string[Project.LegendAlign.BOTTOM].capitalize(), Project.LegendAlign.BOTTOM
	)
	vertical_option_button.add_item(
		Project.alignment_string[Project.LegendAlign.BELOW].capitalize(), Project.LegendAlign.BELOW
	)
	horizontal_option_button.add_item(
		Project.alignment_string[Project.LegendAlign.RIGHT].capitalize(), Project.LegendAlign.RIGHT
	)
	horizontal_option_button.add_item(
		Project.alignment_string[Project.LegendAlign.CENTER].capitalize(), Project.LegendAlign.CENTER
	)
	horizontal_option_button.add_item(
		Project.alignment_string[Project.LegendAlign.LEFT].capitalize(), Project.LegendAlign.LEFT
	)


func update_available_font_names() -> void:
	var system_fonts := OS.get_system_fonts()
	system_fonts.sort()
	font_option_button.clear()
	for system_font_name in system_fonts:
		font_option_button.add_item(system_font_name)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	property_cooldown.one_shot = true
	zoom_displace_cooldown.one_shot = true
	add_child(property_cooldown)
	add_child(zoom_displace_cooldown)
	property_cooldown.wait_time = 0.5
	update_available_font_names()
	update_legend_align_options()

	title_line_edit.text_changed.connect(_update_regular_property.bind("graph_title"))
	x_axis_line_edit.text_changed.connect(_update_regular_property.bind("x_label"))
	y_axis_line_edit.text_changed.connect(_update_regular_property.bind("y_label"))
	font_option_button.item_selected.connect(
		func(index):
			var project: Project = Global.projects[Global.current_project_index]
			project.font_name = font_option_button.get_item_text(index)
			Global.update_plot.emit()
	)
	font_option_button.fit_to_longest_item = false
	bold_check_box.toggled.connect(_update_regular_property.bind("font_bold"))
	fallback_font_size_slider.value_changed.connect(_update_regular_property.bind("fallback_font_size"))
	font_color_button.color_changed.connect(_update_regular_property.bind("font_color"))
	border_mode_slider.value_changed.connect(_update_regular_property.bind("border_mode"))
	border_width_slider.value_changed.connect(_update_regular_property.bind("border_width"))
	border_color_button.color_changed.connect(_update_regular_property.bind("border_color"))
	bg_color_button.color_changed.connect(_update_regular_property.bind("background_color"))
	size_slider.value_changed.connect(_update_regular_property.bind("graph_size"))
	scale_slider.value_changed.connect(_update_regular_property.bind("graph_scale"))
	zero_axis_check_box.toggled.connect(_update_regular_property.bind("show_zero_axis"))
	x_min_slider.value_changed.connect(_update_regular_property.bind("x_range_min"))
	x_max_slider.value_changed.connect(_update_regular_property.bind("x_range_max"))
	y_min_slider.value_changed.connect(_update_regular_property.bind("y_range_min"))
	y_max_slider.value_changed.connect(_update_regular_property.bind("y_range_max"))

	vertical_option_button.item_selected.connect(
		func(index):
			var project: Project = Global.projects[Global.current_project_index]
			project.legend_vertical = vertical_option_button.get_item_id(index) as Project.LegendAlign
			Global.update_plot.emit()
	)
	horizontal_option_button.item_selected.connect(
		func(index):
			var project: Project = Global.projects[Global.current_project_index]
			project.legend_horizontal = horizontal_option_button.get_item_id(index) as Project.LegendAlign
			Global.update_plot.emit()
	)
	legend_enabled_check_box.toggled.connect(_update_regular_property.bind("legend_enabled"))
	reverse_check_box.toggled.connect(_update_regular_property.bind("reverse_legend"))
	use_box_check_box.toggled.connect(_update_regular_property.bind("use_box"))
	box_outline_slider.value_changed.connect(_update_regular_property.bind("legend_box_outline"))
	box_spacing_slider.value_changed.connect(_update_regular_property.bind("legend_box_spacing"))
	update_properties()


func update_properties():
	# Show relavent properties
	project_properties.visible = (data_properties.data_file == null)
	data_properties.update_properties()

	var project: Project = Global.projects[Global.current_project_index]
	title_line_edit.text = project.graph_title
	x_axis_line_edit.text = project.x_label
	y_axis_line_edit.text = project.y_label
	for index in font_option_button.item_count:
		if font_option_button.get_item_text(index) == project.font_name:
			font_option_button.select(index)
			break
	bold_check_box.set_pressed_no_signal(project.font_bold)
	fallback_font_size_slider.set_value_no_signal_update_display(project.fallback_font_size)
	font_color_button.color = project.font_color
	border_mode_slider.set_value_no_signal_update_display(project.border_mode)
	border_width_slider.set_value_no_signal_update_display(project.border_width)
	border_color_button.color = project.border_color
	bg_color_button.color = project.background_color
	size_slider.set_value_no_signal(project.graph_size)
	scale_slider.set_value_no_signal(project.graph_scale)
	zero_axis_check_box.set_pressed_no_signal(project.show_zero_axis)
	full_domain_check_box.set_pressed_no_signal(project.full_range)
	x_min_slider.set_value_no_signal_update_display(project.x_range_min)
	x_max_slider.set_value_no_signal_update_display(project.x_range_max)
	y_min_slider.set_value_no_signal_update_display(project.y_range_min)
	y_max_slider.set_value_no_signal_update_display(project.y_range_max)

	legend_enabled_check_box.set_pressed_no_signal(project.legend_enabled)
	horizontal_option_button.select(horizontal_option_button.get_item_index(project.legend_horizontal))
	vertical_option_button.select(vertical_option_button.get_item_index(project.legend_vertical))
	reverse_check_box.set_pressed_no_signal(project.reverse_legend)
	use_box_check_box.set_pressed_no_signal(project.use_box)
	box_outline_slider.set_value_no_signal_update_display(project.legend_box_outline)
	box_spacing_slider.set_value_no_signal_update_display(project.legend_box_spacing)
	_on_range_changed()
	await get_tree().process_frame
	Global.control.camera_behavior_checkbox.button_pressed = not project.full_range
	Global.control.camera_behavior_checkbox.disabled = project.full_range


func _update_v2_property(value: Vector2, prop_x: String, prop_y: String) -> void:
	var project: Project = Global.projects[Global.current_project_index]
	if Global.fast_generate_mode:
		_property_cool_down_v2_timeout(project, value, prop_x, prop_y)
	else:
		if property_cooldown.timeout.is_connected(_property_cool_down_v2_timeout):
			property_cooldown.timeout.disconnect(_property_cool_down_v2_timeout)
		property_cooldown.timeout.connect(
			_property_cool_down_v2_timeout.bind(project, value, prop_x, prop_y)
		)
		property_cooldown.start()


func _property_cool_down_v2_timeout(project: Project, value: Vector2, prop_x: String, prop_y: String):
	if project != Global.projects[Global.current_project_index]:
		return
	var property_changed := false
	if project.get(prop_x) != value.x:
		property_changed = true
		project.set(prop_x, value.x)
	if project.get(prop_y) != value.y:
		property_changed = true
		project.set(prop_y, value.y)
	if property_changed:
		Global.update_plot.emit()


func _update_regular_property(value: Variant, property: String) -> void:
	var project: Project = Global.projects[Global.current_project_index]
	if Global.fast_generate_mode:
		_property_cool_down_timeout(project, value, property)
	else:
		if property_cooldown.timeout.is_connected(_property_cool_down_timeout):
			property_cooldown.timeout.disconnect(_property_cool_down_timeout)
		property_cooldown.timeout.connect(
			_property_cool_down_timeout.bind(project, value, property)
		)
		property_cooldown.start()


func _property_cool_down_timeout(project: Project, value: Variant, property: String):
	if project != Global.projects[Global.current_project_index]:
		return
	if project.get(property) != value:
		project.set(property, value)
		Global.update_plot.emit()
	box_option_container.visible = project.use_box


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pan"):
		_drag = true
	elif event.is_action_released(&"pan"):
		_drag = false
	if not Global.camera_updates_range:
		_drag = false
		return

	if not zoom_displace_cooldown.is_stopped():
		return
	var time = Time.get_ticks_msec()
	if !Global.can_draw or full_domain_check_box.button_pressed:
		return
	var camera: CanvasCamera = Global.control.canvas_camera
	var increment: Vector2 = Vector2(0.1, 0.1)
	if range_size_slider.value.x != 0 and range_size_slider.value.y != 0:
		increment = range_size_slider.value / 10.0
	increment = increment.snapped(Vector2(0.001, 0.001))

	var dir := Input.get_vector(&"camera_left", &"camera_right", &"camera_up", &"camera_down")
	if Input.is_action_pressed(&"zoom_in"):
		var new_zoom = Vector2(0.01, 0.01).max(range_size_slider.value - increment)
		range_size_slider.set_value_no_signal(new_zoom)
		range_pos_slider.value += increment / 2.0
		zoom_displace_cooldown.start()
	if Input.is_action_pressed(&"zoom_out"):
		var new_zoom = Vector2(0.01, 0.01).max(range_size_slider.value + increment)
		range_size_slider.set_value_no_signal(new_zoom)
		range_pos_slider.value -= increment / 2.0
		zoom_displace_cooldown.start()
	elif event is InputEventMouseMotion:
		if _drag:
			var project := Global.projects[Global.current_project_index]
			if project and project.size != Vector2i.ZERO:
				increment = (range_size_slider.value / Vector2(project.size)) * 32
			dir = Vector2(-event.relative.x, event.relative.y)
			range_pos_slider.value += dir.normalized() * increment
			zoom_displace_cooldown.start()
	else :
		if dir != Vector2.ZERO:
			dir.y = -dir.y
			range_pos_slider.value += dir.normalized() * increment
			zoom_displace_cooldown.start()
	time -= Time.get_ticks_msec()
	zoom_displace_cooldown.wait_time = maxf(0.05, time / 1000.0)


func _on_range_rect_sliders_value_changed(_value: Vector2) -> void:
	var r_pos := range_pos_slider.value
	var r_size := range_size_slider.value
	x_min_slider.set_value_no_signal_update_display(r_pos.x)
	x_max_slider.set_value_no_signal_update_display(r_pos.x + r_size.x)
	y_min_slider.set_value_no_signal_update_display(r_pos.y)
	y_max_slider.set_value_no_signal_update_display(r_pos.y + r_size.y)
	var project: Project = Global.projects[Global.current_project_index]
	project.x_range_max = x_max_slider.value
	project.x_range_min = x_min_slider.value
	project.y_range_max = y_max_slider.value
	project.y_range_min = y_min_slider.value
	Global.update_plot.emit()


func _on_range_changed(_value := 0.0) -> void:
	var start := Vector2(x_min_slider.value, y_min_slider.value)
	var end := Vector2(x_max_slider.value, y_max_slider.value)
	range_pos_slider.set_value_no_signal(start)
	range_size_slider.set_value_no_signal(abs(start - end))


func _on_full_domain_check_box_toggled(toggled_on: bool) -> void:
	var project: Project = Global.projects[Global.current_project_index]
	project.full_range = toggled_on
	Global.control.camera_behavior_checkbox.button_pressed = not toggled_on
	Global.control.camera_behavior_checkbox.disabled = toggled_on
	Global.update_plot.emit()
	#x_min_slider.editable = not toggled_on
	#x_max_slider.editable = not toggled_on
	#y_min_slider.editable = not toggled_on
	#y_max_slider.editable = not toggled_on
	#range_pos_slider.editable = not toggled_on
	#range_size_slider.editable = not toggled_on
