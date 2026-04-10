extends PanelContainer

const KLINE_VISUAL = preload("res://src/UI/Nodes/KLineVisual/KlineVisual.tscn")

@onready var kline_container: VBoxContainer = %KlineContainer
@onready var hide_x_axis_check: CheckBox = $VBoxContainer/HideXAxisCheck
@onready var no_kline_label: Label = %NoKlineLabel


func _ready() -> void:
	hide_x_axis_check.toggled.connect(
		func (toggled_on):
			Global.projects[Global.current_project_index].hide_x_axis = toggled_on
			Global.update_plot.emit()
	)

func update_list():
	for child in kline_container.get_children():
		child.queue_free()
	var project: Project = Global.projects[Global.current_project_index]
	hide_x_axis_check.visible = (project.k_lines.size() > 0)
	no_kline_label.visible = (project.k_lines.size() == 0)
	hide_x_axis_check.set_pressed_no_signal(project.hide_x_axis)
	for i in project.k_lines.size():
		var k_line := project.k_lines[i]
		var kline_visual: KLineVisual = KLINE_VISUAL.instantiate()
		kline_container.add_child(kline_visual)
		kline_visual.line_edit.text = k_line.label
		kline_visual.dist_slider.set_value_no_signal_update_display(k_line.distance)
		kline_visual.kline_label_changed.connect(label_changed.bind(i))
		kline_visual.kline_value_changed.connect(value_changed.bind(i))
		kline_visual.kline_removed.connect(removed.bind(kline_visual))


func label_changed(value: String, index: int) -> void:
	if value.to_lower() == "g":
		value = "{/Symbol %s}" % value
	var project: Project = Global.projects[Global.current_project_index]
	if index < project.k_lines.size():
		project.k_lines[index].label = value
	Global.update_plot.emit()


func value_changed(value: float, index: int) -> void:
	var project: Project = Global.projects[Global.current_project_index]
	if index < project.k_lines.size():
		project.k_lines[index].distance = value
	Global.update_plot.emit()


func removed(kline_visual: KLineVisual) -> void:
	var index := kline_visual.get_index()
	var project: Project = Global.projects[Global.current_project_index]
	if index < project.k_lines.size():
		project.k_lines.remove_at(index)
	hide_x_axis_check.visible = (project.k_lines.size() > 0)
	no_kline_label.visible = (project.k_lines.size() == 0)
	Global.update_plot.emit()


func _on_add_button_pressed() -> void:
	var project: Project = Global.projects[Global.current_project_index]
	project.k_lines.append(Project.KLine.new())
	Global.kline_list_updated.emit()
	Global.update_plot.emit()
