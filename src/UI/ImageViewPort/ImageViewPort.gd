extends SubViewportContainer

@export var camera_path: NodePath

@onready var camera := get_node(camera_path) as CanvasCamera


func _ready() -> void:
	material = CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	mouse_entered.connect(_on_ViewportContainer_mouse_entered)
	mouse_exited.connect(_on_ViewportContainer_mouse_exited)


func _on_ViewportContainer_mouse_entered() -> void:
	camera.set_process_input(true)
	if Global.cross_cursor:
		Global.can_draw = true
		Input.set_default_cursor_shape(Input.CURSOR_CROSS)


func _on_ViewportContainer_mouse_exited() -> void:
	camera.set_process_input(false)
	camera.drag = false
	Global.can_draw = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
