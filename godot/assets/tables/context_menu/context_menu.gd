extends PanelContainer
class_name ContextMenu


@export_category("Node References")
@export var button_container: VBoxContainer

@onready var context_menu_button = preload("res://assets/tables/context_menu/context_menu_button.tscn")


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		var last_mouse_pos = get_global_mouse_position()
		if not get_global_rect().has_point(last_mouse_pos):
			hide()


func _set_position_clamped(new_pos: Vector2):
	var screen_size = get_viewport_rect().size
	position.x = clamp(new_pos.x, 0, screen_size.x - size.x)
	position.y = clamp(new_pos.y, 0, screen_size.y - size.y)


# Clears all buttons from the context menu
func clear_items() -> void:
	for button in button_container.get_children():
		button_container.remove_child(button)
		button.queue_free()


# Adds a button option to the context menu
func add_item(display_text: String, callback: Callable):
	var new_button := Button.new()
	new_button.text = display_text
	new_button.pressed.connect(callback)
	new_button.pressed.connect(hide)
	button_container.add_child(new_button)


# The ContextMenu will resize and show itself at the provided location
func appear(mouse_location: Vector2):
	size = get_combined_minimum_size()
	_set_position_clamped(mouse_location)
	show()
