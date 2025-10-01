@tool
extends Control

var layout := VBoxContainer.new()

func _ready():
	name = "Legend"
	layout.position.x = 10
	layout.position.y = 20
	add_child(layout)

func update(labels, new_x_pos, new_y_pos):
	layout.position.x = new_x_pos
	layout.position.y = new_y_pos

	for child in layout.get_children():
		layout.remove_child(child)
		child.queue_free()
		
	for label in labels:
		var l = Label.new()
		l.text = label.name
		l.add_theme_color_override("font_color", label.color)
		layout.add_child(l)
