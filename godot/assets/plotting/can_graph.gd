@tool
extends Graph2D
class_name CanGraph

@onready var _plot_elements: Dictionary = {}
@onready var _current_time_s: float = PLOT_HISTORY_SIZE_S

const PLOT_HISTORY_SIZE_S: float = 30.0


func _ready() -> void:
	# Run the Graph2D initialisation code
	super._ready()


func _process(_delta: float) -> void:
	_update_plot_limits()


# Must be called periodically to shift the x limit of the plot in real time
func update_current_time(new_time_s: float) -> void:
	_current_time_s = new_time_s


# Will add or remove a given plot element from being recorded and plotted
func toggle_plot_element(entry: ReceiveTable.ReceiveTableEntry, label: String) -> void:
	var element_id: String = get_element_id(entry, label)

	if _plot_elements.has(element_id):
		self.remove_plot_item(_plot_elements[element_id])
		_plot_elements.erase(element_id)
	else:
		_plot_elements[element_id] = self.add_plot_item(entry.formatted_can_id() + ": " + label, _generate_random_rgb_color(), 1.0)


# Returns true if we are currently recording and plotting this element
func has_plot_element(entry: ReceiveTable.ReceiveTableEntry, label: String) -> bool:
	return _plot_elements.has(get_element_id(entry, label))


# Adds a new data point to a plot element currently being plotted
func add_data_point(entry: ReceiveTable.ReceiveTableEntry, label: String, timestamp: float, value: float) -> void:
	_plot_elements[get_element_id(entry, label)].add_point(Vector2(timestamp, value))


# A 'plot element' consists of the CAN_ID the series comes from, concatenated with the data label
func get_element_id(entry: ReceiveTable.ReceiveTableEntry, label: String) -> String:
	return entry.formatted_can_id() + label


func _generate_random_rgb_color() -> Color:
	return Color(randf(), randf(), randf())


func _get_plot_range() -> float:
	var total_max_y: float = 0.0
	for element in _plot_elements.values():
		var element_max_y = _get_largest_y_magnitude(element._points)
		if element_max_y > total_max_y:
			total_max_y = element_max_y
	return total_max_y


func _get_largest_y_magnitude(packed_vector_array: PackedVector2Array) -> float:
	if packed_vector_array.is_empty():
		return NAN
	
	var max_y: float = 0.0

	for vector in packed_vector_array:
		if abs(vector.y) > max_y:
			max_y = abs(vector.y)

	return max_y


func _update_plot_limits() -> void:
	if not _plot_elements.is_empty():
		# Update the domain to show from PLOT_HISTORY_SIZE seconds ago to the current time
		const DOMAIN_OFFSET_S: float = 5.0
		self.x_min = _current_time_s + DOMAIN_OFFSET_S - PLOT_HISTORY_SIZE_S
		self.x_max = _current_time_s + DOMAIN_OFFSET_S
	
		# Update the range to contain the maximum value present in the plotted data
		const PLOT_RANGE_SCALE: float = 1.15
		self.y_min = - PLOT_RANGE_SCALE * _get_plot_range()
		self.y_max = PLOT_RANGE_SCALE * _get_plot_range()
