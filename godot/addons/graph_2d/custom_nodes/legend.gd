@tool
extends Control

var layout := VBoxContainer.new()


func _ready():
	name = "Legend"
	layout.position.x = 10
	layout.position.y = 20
	add_child(layout)


func update(labels: Array, new_x_pos: int, new_y_pos: int, max_width: int):
	layout.position.x = new_x_pos
	layout.position.y = new_y_pos

	for child in layout.get_children():
		layout.remove_child(child)
		child.queue_free()

	for label in labels:
		var l = Label.new()
		l.text = label.name
		l.add_theme_color_override("font_color", label.color)
		_update_label_font_size(l, max_width)

		layout.add_child(l)


static func _update_label_font_size(label: Label, width: int) -> void:
	const PADDING_PX: int = 10
	const MAX_FONT_SIZE: int = 14

	# Adjust name's font size (and potentially truncate string) to fit within the allowed width.
	var font_size = MAX_FONT_SIZE
	while ThemeDB.fallback_font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x > (width - PADDING_PX):
		font_size -= 1

	label.add_theme_font_size_override("font_size", font_size)