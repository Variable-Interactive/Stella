class_name CanvasCamera
extends Node2D

signal zoom_changed
signal rotation_changed
signal offset_changed

enum Cameras { MAIN, SECOND, SMALL }

const CAMERA_SPEED_RATE := 15.0

@export var index := Cameras.MAIN

var zoom := Vector2.ONE:
	set(value):
		zoom = value
		Global.projects[Global.current_project_index].cameras_zoom[index] = zoom
		zoom_changed.emit()
		_update_viewport_transform()
var offset := Vector2.ZERO:
	set(value):
		offset = value
		Global.projects[Global.current_project_index].cameras_offset[index] = offset
		offset_changed.emit()
		_update_viewport_transform()
var camera_screen_center := Vector2.ZERO
var zoom_in_max := Vector2(500, 500)
var zoom_out_max := Vector2(0.01, 0.01)
var viewport_container: SubViewportContainer
var mouse_pos := Vector2.ZERO
var drag := false
var zoom_slider: ValueSlider
var should_tween := true

@onready var viewport := get_viewport()


func _ready() -> void:
	viewport.size_changed.connect(_update_viewport_transform)
	Global.project_switched.connect(_project_switched)
	if not DisplayServer.is_touchscreen_available():
		set_process_input(false)
	if index == Cameras.MAIN:
		zoom_slider = Global.control.get_node("%ZoomSlider")
		zoom_slider.value_changed.connect(_zoom_slider_value_changed)
	zoom_changed.connect(_zoom_changed)
	viewport_container = get_viewport().get_parent()


func _input(event: InputEvent) -> void:
	get_window().gui_release_focus()
	if Global.camera_updates_range:
		return
	if not DisplayServer.is_touchscreen_available():
		get_window().gui_release_focus()
	if !Global.can_draw:
		drag = false
		return
	mouse_pos = viewport_container.get_local_mouse_position()
	if event.is_action_pressed(&"pan"):
		drag = true
	elif event.is_action_released(&"pan"):
		drag = false
	elif event.is_action_pressed(&"zoom_in", false, true):  # Wheel Up Event
		zoom_camera(1)
	elif event.is_action_pressed(&"zoom_out", false, true):  # Wheel Down Event
		zoom_camera(-1)

	elif event is InputEventMagnifyGesture:  # Zoom gesture on touchscreens
		var scale_factor := (event as InputEventMagnifyGesture).factor
		var zoom_strength := log(scale_factor) * 8.0
		zoom_camera(zoom_strength, event.position)
	elif event is InputEventPanGesture:
		# Pan gesture on touchscreens
		offset = offset + event.delta * 2.0 / zoom
	elif event is InputEventMouseMotion:
		if drag:
			offset = offset - event.relative / zoom
	else:
		var dir := Input.get_vector(&"camera_left", &"camera_right", &"camera_up", &"camera_down")
		if dir != Vector2.ZERO:
			offset = offset + (dir / zoom) * CAMERA_SPEED_RATE


func zoom_camera(dir: float, event_pos := mouse_pos) -> void:
	var viewport_size := viewport_container.size
	if Global.smooth_zoom:
		var zoom_margin := zoom * dir / 5
		var new_zoom := zoom + zoom_margin
		if Global.integer_zoom:
			new_zoom = (zoom + Vector2.ONE * dir).floor()
		if new_zoom < zoom_in_max && new_zoom > zoom_out_max:
			var new_offset := (
				offset
				+ (
					(-0.5 * viewport_size + event_pos)
					* (Vector2.ONE / zoom - Vector2.ONE / new_zoom)
				)
			)
			var tween := create_tween().set_parallel()
			tween.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
			tween.tween_property(self, "zoom", new_zoom, 0.05)
			tween.tween_property(self, "offset", new_offset, 0.05)
	else:
		var prev_zoom := zoom
		var zoom_margin := zoom * dir / 10
		if Global.integer_zoom:
			zoom_margin = (Vector2.ONE * dir).floor()
		if zoom + zoom_margin <= zoom_in_max:
			zoom += zoom_margin
		if zoom < zoom_out_max:
			if Global.integer_zoom:
				zoom = Vector2.ONE
			else:
				zoom = zoom_out_max
		offset = (
			offset
			+ (
				(-0.5 * viewport_size + event_pos)
				* (Vector2.ONE / prev_zoom - Vector2.ONE / zoom)
			)
		)


func zoom_100() -> void:
	zoom = Vector2.ONE
	offset = Global.projects[Global.current_project_index].size / 2.0


func fit_to_frame(size: Vector2) -> void:
	viewport_container = get_viewport().get_parent()
	var h_ratio := viewport_container.size.x / size.x
	var v_ratio := viewport_container.size.y / size.y
	var ratio := minf(h_ratio, v_ratio)
	if ratio == 0 or !viewport_container.visible:
		return
	# Temporarily disable integer zoom.
	var reset_integer_zoom := Global.integer_zoom
	if reset_integer_zoom:
		Global.integer_zoom = !Global.integer_zoom
	offset = size / 2

	ratio = clampf(ratio, 0.1, ratio)
	zoom = Vector2(ratio, ratio)
	if reset_integer_zoom:
		Global.integer_zoom = !Global.integer_zoom


## Updates the viewport's canvas transform, which is the area of the canvas that is
## currently visible. Called every time the camera's zoom, rotation or origin changes.
func _update_viewport_transform() -> void:
	if not is_instance_valid(viewport):
		return
	var zoom_scale := Vector2.ONE / zoom
	var viewport_size := get_viewport_rect().size
	var half_size := viewport_size * 0.5
	var screen_offset := -(half_size * zoom_scale) + offset
	var xform := Transform2D(0, zoom_scale, 0, screen_offset)
	camera_screen_center = xform * half_size
	viewport.canvas_transform = xform.affine_inverse()


func _zoom_changed() -> void:
	if index == Cameras.MAIN:
		should_tween = false
		zoom_slider.set_value_no_signal_update_display(zoom.x * 100.0)
		should_tween = true


func _zoom_slider_value_changed(value: float) -> void:
	if value <= 0:
		value = 1
	var new_zoom := Vector2(value, value) / 100.0
	if zoom.is_equal_approx(new_zoom):
		return
	if Global.smooth_zoom and should_tween:
		var tween := create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
		tween.tween_property(self, "zoom", new_zoom, 0.05)
	else:
		zoom = new_zoom


func _project_switched() -> void:
	var project := Global.projects[Global.current_project_index]
	offset = project.cameras_offset[index]
	zoom = project.cameras_zoom[index]


func _rotate_camera_around_point(degrees: float, point: Vector2) -> void:
	var angle := deg_to_rad(degrees)
	offset = (offset - point).rotated(angle) + point
