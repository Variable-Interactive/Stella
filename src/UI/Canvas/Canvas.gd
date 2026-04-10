class_name Canvas
extends Node2D

const CURSOR_SPEED_RATE := 6.0

var current_pixel := Vector2.ZERO

@onready var currently_visible_frame := $CurrentlyVisibleFrame as SubViewport
@onready var current_frame_drawer := $CurrentlyVisibleFrame/CurrentFrameDrawer as Node2D


func _ready() -> void:
	Global.project_switched.connect(queue_redraw)
	await get_tree().process_frame
	await get_tree().process_frame
	camera_zoom()


func _draw() -> void:
	var position_tmp := position
	var scale_tmp := scale

	# Get the graph image
	var graph_image := Global.projects[Global.current_project_index].last_render
	var graph_texture := ImageTexture.new()
	#if graph_image and not graph_image.is_empty():
	graph_texture = ImageTexture.create_from_image(graph_image)

	# for some reason the image is not updating if sprite is removed
	Global.sprite.texture = graph_texture

	draw_set_transform(position_tmp, rotation, scale_tmp)
	# Placeholder so we can have a material here
	draw_texture(graph_texture, Vector2.ZERO)
	currently_visible_frame.size = Global.projects[Global.current_project_index].size
	current_frame_drawer.queue_redraw()


func _input(_event: InputEvent) -> void:
	current_pixel = get_local_mouse_position()


func camera_zoom() -> void:
	for camera: CanvasCamera in get_tree().get_nodes_in_group("CanvasCameras"):
		camera.fit_to_frame(Global.projects[Global.current_project_index].size)
