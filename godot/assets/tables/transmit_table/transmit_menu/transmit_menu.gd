extends Window
class_name TransmitMenu

func _ready() -> void:
    self.close_requested.connect(self.hide)
    self.hide()
