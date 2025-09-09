extends OptionButton
class_name LengthButton

var data_boxes: Array[LineEdit]


func _ready() -> void:
	# Resolve data box references
	for i in range(8):
		data_boxes.append(get_parent().get_node("Data Box " + str(i + 1)))

	self.item_selected.connect(_update_data_boxes_visibility)

	# Initialise with only one data box visible (as Data length 1 selected by default)
	_update_data_boxes_visibility(0)


func _update_data_boxes_visibility(selected_index: int) -> void:
	var num_visible_boxes: int = selected_index + 1
	for i in range(len(data_boxes)):
		data_boxes[i].visible = (i < num_visible_boxes)
