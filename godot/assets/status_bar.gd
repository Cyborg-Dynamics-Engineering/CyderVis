extends PanelContainer
class_name StatusBar

@export_category("Node References")
@export var godot_can_bridge: GodotCanBridge
@export var connection_label: Label
@export var bitrate_label: Label
@export var bus_loading_label: Label

const LOADING_UPDATE_PERIOD_S: float = 1.0
var update_timer_s: float = LOADING_UPDATE_PERIOD_S


func _ready() -> void:
	update_text()


func _process(delta: float) -> void:
	# Update bitrate and loading every second
	update_timer_s += delta
	if update_timer_s >= LOADING_UPDATE_PERIOD_S:
		bitrate_label.text = _get_bitrate_text()
		bus_loading_label.text = _get_busloading_text(update_timer_s)
		
		update_timer_s = 0


func update_text() -> void:
	connection_label.text = _get_status_text()
	bitrate_label.text = _get_bitrate_text()
	bus_loading_label.text = "Bus Loading: None"


func _get_status_text() -> String:
	if godot_can_bridge.is_alive():
		return "Connected to " + godot_can_bridge.get_interface()
	
	return "Disconnected"


func _get_bitrate_text() -> String:
	if godot_can_bridge.is_alive():
		if godot_can_bridge.get_bitrate() != 0:
			return "Bitrate: " + str(godot_can_bridge.get_bitrate())
	
	return "Bitrate: None"


func _get_busloading_text(period: float) -> String:
	if not godot_can_bridge.is_alive():
		return "Bus Loading: None"

	var bits_seen: int = godot_can_bridge.get_bus_bits()
	if bits_seen == 0:
		return "Bus Loading: None"
	
	var bitrate: int = godot_can_bridge.get_bitrate()
	if bitrate == 0:
		return "Bus Loading: None"
	
	var loading = (bits_seen / period) / bitrate
	return "Bus Loading: %.2f%%" % (loading * 100.0)
