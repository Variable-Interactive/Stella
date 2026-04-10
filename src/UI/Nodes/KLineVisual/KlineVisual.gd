class_name KLineVisual
extends HBoxContainer

signal kline_removed
signal kline_label_changed(new_test: String)
signal kline_value_changed(new_value: float)

@onready var dist_slider: ValueSlider = %DistSlider
@onready var line_edit: LineEdit = %LineEdit


func _ready() -> void:
	line_edit.text_changed.connect(func(text): kline_label_changed.emit(text))
	dist_slider.value_changed.connect(func(value): kline_value_changed.emit(value))


func _on_remove_pressed() -> void:
	kline_removed.emit()
	queue_free()
