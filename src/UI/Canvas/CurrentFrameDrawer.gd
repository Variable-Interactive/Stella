extends Node2D


func _draw() -> void:
	# Placeholder so we can have a material here
	var graph_image := Global.projects[Global.current_project_index].last_render
	var graph_texture := ImageTexture.new()
	if graph_image and not graph_image.is_empty():
		graph_texture.set_image(graph_image)
	draw_texture(
		graph_texture,
		Vector2.ZERO
	)
