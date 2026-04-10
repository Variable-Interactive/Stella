extends TabBar

@onready var main := get_tree().current_scene
@onready var unsaved_changes_dialog: ConfirmationDialog = main.find_child("UnsavedChangesDialog")


func _ready() -> void:
	main.save_file_dialog_opened.connect(_disable_tabs)


func _input(_event: InputEvent) -> void:
	var tab_idx := current_tab
	if Input.is_action_just_released(&"next_project", true):
		tab_idx += 1
		if tab_idx >= tab_count:
			tab_idx = 0
	elif Input.is_action_just_released(&"previous_project", true):
		tab_idx -= 1
		if tab_idx < 0:
			tab_idx = tab_count - 1
	if tab_idx != current_tab:
		current_tab = tab_idx


func _on_Tabs_tab_changed(tab: int) -> void:
	Global.current_project_index = tab
	call_deferred("update_project_ui")


func update_project_ui():
	Global.data_tree.selected_data_idx = -1
	Global.data_files_updated.emit()
	Global.kline_list_updated.emit()
	Global.update_plot.emit()
	Global.canvas.camera_zoom()


func _on_tab_close_pressed(tab: int) -> void:
	if Global.projects.size() == 1:
		return

	if Global.projects[tab].has_changed:
		if !unsaved_changes_dialog.confirmed.is_connected(delete_tab):
			unsaved_changes_dialog.confirmed.connect(delete_tab.bind(tab))
		unsaved_changes_dialog.popup_centered_clamped()
	else:
		delete_tab(tab)


func _on_active_tab_rearranged(idx_to: int) -> void:
	var temp := Global.projects[Global.current_project_index]
	Global.projects.erase(temp)
	Global.projects.insert(idx_to, temp)


func _disable_tabs(should_disable: bool) -> void:
	for i in tab_count:
		set_tab_disabled(i, should_disable)


func delete_tab(tab: int) -> void:
	remove_tab(tab)
	Global.projects.remove_at(tab)
	if Global.current_project_index == tab:
		if tab > 0:
			Global.current_project_index -= 1
		else:
			Global.current_project_index = 0
	else:
		if tab < Global.current_project_index:
			Global.current_project_index -= 1
	if unsaved_changes_dialog.confirmed.is_connected(delete_tab):
		unsaved_changes_dialog.confirmed.disconnect(delete_tab)
