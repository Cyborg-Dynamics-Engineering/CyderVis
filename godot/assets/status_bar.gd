extends PanelContainer
class_name StatusBar


@export_category("Node References")
@export var godot_can_bridge: GodotCanBridge
@export var connection_label: Label


func _process(_delta: float) -> void:
    connection_label.text = _get_status_text()


func _get_status_text() -> String:
    if godot_can_bridge.is_alive():
        return "Connected to " + godot_can_bridge.get_interface()
    
    return "Disconnected"
