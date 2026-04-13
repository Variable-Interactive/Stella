extends PanelContainer


const REMOVE_TEXTURE := preload("res://assets/graphics/ui_icons/close.svg")

var _root_item: TreeItem
var _data_tree_items: Array[TreeItem] = []
var _current_data_name_filter: String = ""
var selected_data_idx: int = -1:
	set(value):
		selected_data_idx = value
		if selected_data_idx == -1:
			Global.properties_container.data_properties.data_file = null
		else:
			var data_files := Global.projects[Global.current_project_index].data_files
			Global.properties_container.data_properties.data_file = data_files[selected_data_idx]

@onready var data_tree: Tree = %DataTree
@onready var no_data_label: Label = %NoDataLabel


func _ready() -> void:
	# Tree View Signals
	data_tree.button_clicked.connect(_on_data_tree_button_clicked)
	data_tree.item_activated.connect(_on_data_tree_item_activated)
	data_tree.item_edited.connect(_on_data_tree_item_edited)
	data_tree.item_selected.connect(_on_data_tree_item_selected)
	update_data_tree()


func select_last_added() -> void:
	selected_data_idx = _data_tree_items.size() - 1
	_highlight_selected_data_in_tree()


func _on_data_tree_item_selected() -> void:
	var data_index = _data_tree_items.find(data_tree.get_selected())
	var data_files := Global.projects[Global.current_project_index].data_files
	if data_index >= 0 and data_index < data_files.size():
		selected_data_idx = data_index
	else:
		selected_data_idx = -1
	Global.properties_container.update_properties()


func remove_data_file(data_idx: int) -> void:
	var project := Global.projects[Global.current_project_index]
	selected_data_idx = -1
	project.data_files.remove_at(data_idx)
	Global.data_files_updated.emit()


func update_data_tree() -> void:
	var project := Global.projects[Global.current_project_index]
	data_tree.clear()
	no_data_label.visible = (project.data_files.size() == 0)
	_data_tree_items.clear()
	var root_item := data_tree.create_item()
	root_item.set_text(0, "Graph Root")
	_root_item = root_item
	for data_idx in project.data_files.size():
		_create_data_tree_item(data_idx, root_item)
	_highlight_selected_data_in_tree()
	Global.properties_container.call_deferred("update_properties")
	Global.update_plot.emit()


func _on_filter_by_name_line_edit_text_changed(new_text: String) -> void:
	_current_data_name_filter = new_text.strip_edges()
	_apply_search_filters()


func _apply_search_filters() -> void:
	var tree_item: TreeItem = data_tree.get_root().get_first_child()
	var results: Array[TreeItem] = []
	var should_reset := _current_data_name_filter.is_empty()
	while tree_item != null:  # Loop through Tree's TreeItems.
		if not _current_data_name_filter.is_empty():
			if _current_data_name_filter.is_subsequence_ofn(tree_item.get_text(0)):
				results.append(tree_item)
		if should_reset:
			tree_item.visible = true
		else:
			tree_item.collapsed = true
			tree_item.visible = false
		tree_item = tree_item.get_next_in_tree()
	var expanded: Array[TreeItem] = []
	for result in results:
		var item: TreeItem = result
		while item.get_parent():
			if expanded.has(item):
				break
			item.collapsed = false
			item.visible = true
			expanded.append(item)
			item = item.get_parent()
	if not results.is_empty():
		data_tree.scroll_to_item(results[0])
	_highlight_selected_data_in_tree()


func _highlight_selected_data_in_tree() -> void:
	if selected_data_idx > _data_tree_items.size():
		selected_data_idx = -1
	if selected_data_idx == -1:
		data_tree.deselect_all()
	else:
		data_tree.set_selected(_data_tree_items[selected_data_idx], 0)


func _create_data_tree_item(i: int, root_item: TreeItem) -> void:
	var tree_item := data_tree.create_item(root_item)
	var data_label := Global.projects[Global.current_project_index].data_files[i].data_label
	# TODO: Add an icon
	tree_item.set_text(0, data_label)
	tree_item.set_metadata(0, i)
	tree_item.add_button(0, REMOVE_TEXTURE, -1, false, "Delete")
	_data_tree_items.append(tree_item)


func _on_data_tree_item_activated() -> void:
	var item := data_tree.get_selected()
	if item and not item == _root_item:
		# Setting it to editable here shows line edit only on double click
		item.set_editable(0, true)
		data_tree.edit_selected()


func _on_data_tree_item_edited() -> void:
	var item := data_tree.get_edited()
	if item and not item == _root_item:
		var data_idx: int = item.get_metadata(0)
		var data_files := Global.projects[Global.current_project_index].data_files
		if data_idx < data_files.size():
			var new_name = item.get_text(0).strip_edges()
			if not new_name.is_empty():
				data_files[data_idx].data_label = new_name
			item.set_text(0, new_name)


func _on_data_tree_button_clicked(item: TreeItem, column: int, id: int, _mbi: int) -> void:
	var data_idx: int = item.get_metadata(column)
	if id == 0:  # Delete
		var data_files := Global.projects[Global.current_project_index].data_files
		if data_idx < data_files.size():
			remove_data_file(data_idx)


func _on_add_data_pressed() -> void:
	Global.import_data_dialog.popup_centered()
